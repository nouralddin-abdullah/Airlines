--[[
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                           AFKTY SDK v3.0.0                                 ║
    ║                                                                           ║
    ║  The complete SDK for connecting Roblox scripts to AFKTY alert system     ║
    ║                                                                           ║
    ║  Features:                                                                ║
    ║  • Permanent authentication (hubKey + userToken)                          ║
    ║  • Auto-reconnect with exponential backoff                                ║
    ║  • Dead Man's Switch (automatic crash detection)                          ║
    ║  • Real-time status updates                                               ║
    ║  • Custom notifications and critical alerts                               ║
    ║  • Log batching for performance                                           ║
    ║  • Rate limit handling                                                    ║
    ║                                                                           ║
    ║  Docs: https://afkty-docs.vercel.app                                     ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
]]

local Afkty = {}
Afkty.__index = Afkty
Afkty.Version = "3.0.0"

-- Services
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

-- ============================================================================
-- ERROR CODES (match server error codes)
-- ============================================================================

Afkty.ErrorCodes = {
    -- Authentication errors
    INVALID_HUB_KEY = "INVALID_HUB_KEY",
    HUB_NOT_APPROVED = "HUB_NOT_APPROVED",
    HUB_SUSPENDED = "HUB_SUSPENDED",
    INVALID_USER_TOKEN = "INVALID_USER_TOKEN",
    USER_SUSPENDED = "USER_SUSPENDED",
    
    -- Connection errors
    WEBSOCKET_NOT_SUPPORTED = "WEBSOCKET_NOT_SUPPORTED",
    CONNECTION_FAILED = "CONNECTION_FAILED",
    CONNECTION_TIMEOUT = "CONNECTION_TIMEOUT",
    MAX_RECONNECT_ATTEMPTS = "MAX_RECONNECT_ATTEMPTS",
    
    -- Message errors
    RATE_LIMITED = "RATE_LIMITED",
    INVALID_PARAMS = "INVALID_PARAMS",
    
    -- Other
    NOT_CONNECTED = "NOT_CONNECTED",
    NOT_INITIALIZED = "NOT_INITIALIZED"
}

-- ============================================================================
-- INTERNAL STATE
-- ============================================================================

local _state = {
    ws = nil,
    connected = false,
    authenticated = false,
    sessionId = nil,
    hubName = nil,
    username = nil,
    reconnectAttempts = 0,
    heartbeatThread = nil,
    messageQueue = {},
    lastStatus = nil,
    lastStatusTime = 0,
    isShuttingDown = false
}


local SERVER_URL = "wss://afkty.toastyhub.fun/ws"

local STATUS_COOLDOWN = 5

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local _config = {
    -- Required
    hubKey = nil,           -- Hub's API key (from hub developer)
    userToken = nil,        -- User's personal token (from AFKTY app)
    
    -- Behavior
    autoReconnect = true,
    reconnectDelay = 3,              -- Initial delay in seconds
    maxReconnectDelay = 60,          -- Max delay between retries
    maxReconnectAttempts = 20,       -- 0 = infinite
    heartbeatInterval = 10,          -- Seconds between heartbeats
    connectionTimeout = 15,          -- Seconds to wait for auth
    
    -- Features
    debug = false,
    queueOfflineMessages = true,
    maxQueueSize = 100,
    logBatchSize = 10,
    logBatchDelay = 2
}

-- ============================================================================
-- LOG BATCHING
-- ============================================================================

local _logBatch = {
    messages = {},
    timer = nil
}

-- ============================================================================
-- EVENTS
-- ============================================================================

Afkty.Events = {
    Connected = Instance.new("BindableEvent"),
    Disconnected = Instance.new("BindableEvent"),
    Reconnecting = Instance.new("BindableEvent"),
    Authenticated = Instance.new("BindableEvent"),
    Command = Instance.new("BindableEvent"),
    Error = Instance.new("BindableEvent"),
    RateLimited = Instance.new("BindableEvent")
}

-- Public event connections
Afkty.OnConnected = Afkty.Events.Connected.Event
Afkty.OnDisconnected = Afkty.Events.Disconnected.Event
Afkty.OnReconnecting = Afkty.Events.Reconnecting.Event
Afkty.OnAuthenticated = Afkty.Events.Authenticated.Event
Afkty.OnCommand = Afkty.Events.Command.Event
Afkty.OnError = Afkty.Events.Error.Event
Afkty.OnRateLimited = Afkty.Events.RateLimited.Event

-- ============================================================================
-- INTERNAL UTILITIES
-- ============================================================================

local function log(level, msg)
    if _config.debug or level == "error" or level == "warn" then
        local prefix = ({
            info = "[Afkty]",
            warn = "[Afkty ⚠]",
            error = "[Afkty ❌]",
            debug = "[Afkty 🔍]",
            success = "[Afkty ✓]"
        })[level] or "[Afkty]"
        print(prefix, msg)
    end
end

local function getWebSocket()
    -- Standard UNC (Unified Naming Convention) - most executors use this
    if websocket and websocket.connect then
        return websocket.connect, "UNC"
    end
    
    -- Fallback implementations for specific executors
    if syn and syn.websocket and syn.websocket.connect then
        return syn.websocket.connect, "Synapse"
    end
    
    if WebSocket and WebSocket.connect then
        return WebSocket.connect, "WebSocket"
    end
    
    if Fluxus and Fluxus.websocket and Fluxus.websocket.connect then
        return Fluxus.websocket.connect, "Fluxus"
    end
    
    if wave and wave.websocket and wave.websocket.connect then
        return wave.websocket.connect, "Wave"
    end
    
    -- Check global environment
    if getgenv then
        local env = getgenv()
        if env and env.WebSocket and env.WebSocket.connect then
            return env.WebSocket.connect, "Environment"
        end
    end
    
    return nil, nil
end

local function getExecutor()
    local ok, name, version = pcall(function()
        if identifyexecutor then
            return identifyexecutor()
        end
        return "Unknown", nil
    end)
    
    if ok and name then
        return version and (name .. " " .. version) or name
    end
    return "Unknown"
end

local function getGameInfo()
    local gameName = "Unknown"
    
    pcall(function()
        local info = MarketplaceService:GetProductInfo(game.PlaceId)
        gameName = info.Name
    end)
    
    return {
        name = gameName,
        placeId = game.PlaceId,
        jobId = game.JobId or "",
        executor = getExecutor(),
        timestamp = os.time()
    }
end

local function encode(data)
    local ok, result = pcall(HttpService.JSONEncode, HttpService, data)
    return ok and result or nil
end

local function decode(str)
    local ok, result = pcall(HttpService.JSONDecode, HttpService, str)
    return ok and result or nil
end

-- ============================================================================
-- NETWORKING
-- ============================================================================

local function send(data)
    if not _state.ws then
        if _config.queueOfflineMessages and data.type ~= "heartbeat" then
            table.insert(_state.messageQueue, data)
            if #_state.messageQueue > _config.maxQueueSize then
                table.remove(_state.messageQueue, 1)
            end
            log("debug", "Queued message: " .. data.type)
        end
        return false
    end
    
    local encoded = encode(data)
    if not encoded then
        log("error", "Failed to encode message")
        return false
    end
    
    local ok = pcall(function()
        _state.ws:Send(encoded)
    end)
    
    return ok
end

local function flushMessageQueue()
    if #_state.messageQueue == 0 then return end
    
    log("debug", "Flushing " .. #_state.messageQueue .. " queued messages")
    
    local queue = _state.messageQueue
    _state.messageQueue = {}
    
    for _, msg in ipairs(queue) do
        send(msg)
        task.wait(0.05)
    end
end

local function flushLogBatch()
    if #_logBatch.messages == 0 then return end
    
    local messages = _logBatch.messages
    _logBatch.messages = {}
    _logBatch.timer = nil
    
    for _, logMsg in ipairs(messages) do
        send({
            type = "log",
            message = logMsg.message,
            level = logMsg.level
        })
    end
end

-- ============================================================================
-- MESSAGE HANDLING
-- ============================================================================

local function handleMessage(raw)
    local data = decode(raw)
    if not data then
        log("warn", "Received invalid JSON")
        return
    end
    
    local msgType = data.type
    
    if msgType == "connected" then
        _state.connected = true
        log("debug", "WebSocket connected, authenticating...")
        
    elseif msgType == "authenticated" then
        _state.authenticated = true
        _state.sessionId = data.sessionId
        _state.hubName = data.hub and data.hub.name
        _state.username = data.user and data.user.username
        _state.reconnectAttempts = 0
        
        log("success", "Authenticated!")
        log("info", "  Session: " .. tostring(data.sessionId))
        log("info", "  Hub: " .. tostring(_state.hubName))
        log("info", "  User: " .. tostring(_state.username))
        
        if data.user and not data.user.hasDevices then
            log("warn", "No devices registered! Alerts won't be received.")
            log("warn", "Register a device in the AFKTY mobile app.")
        end
        
        -- Start heartbeat
        if _state.heartbeatThread then
            pcall(task.cancel, _state.heartbeatThread)
        end
        
        _state.heartbeatThread = task.spawn(function()
            while _state.authenticated and not _state.isShuttingDown do
                task.wait(_config.heartbeatInterval)
                if _state.authenticated then
                    send({ type = "heartbeat" })
                end
            end
        end)
        
        -- Flush queued messages
        flushMessageQueue()
        
        Afkty.Events.Authenticated:Fire({
            sessionId = data.sessionId,
            hubName = _state.hubName,
            username = _state.username
        })
        
        Afkty.Events.Connected:Fire({
            sessionId = data.sessionId
        })
        
    elseif msgType == "pong" then
        -- Heartbeat acknowledged
        log("debug", "Heartbeat OK")
        
    elseif msgType == "command" then
        log("info", "Command received: " .. tostring(data.command))
        Afkty.Events.Command:Fire({
            command = data.command,
            data = data.data
        })
        
    elseif msgType == "error" then
        local code = data.code or "UNKNOWN_ERROR"
        local message = data.message or "Unknown error"
        
        log("error", code .. ": " .. message)
        
        if code == "RATE_LIMITED" then
            Afkty.Events.RateLimited:Fire({
                message = message
            })
        else
            Afkty.Events.Error:Fire({
                code = code,
                message = message
            })
            
            -- Fatal auth errors - don't retry
            if code == Afkty.ErrorCodes.INVALID_HUB_KEY or
               code == Afkty.ErrorCodes.HUB_SUSPENDED or
               code == Afkty.ErrorCodes.INVALID_USER_TOKEN or
               code == Afkty.ErrorCodes.USER_SUSPENDED then
                _config.autoReconnect = false
                log("error", "Fatal authentication error. Auto-reconnect disabled.")
            end
        end
        
    elseif msgType == "disconnected" then
        log("info", "Server acknowledged disconnect")
    end
end

-- ============================================================================
-- RECONNECTION LOGIC
-- ============================================================================

local function scheduleReconnect()
    if not _config.autoReconnect or _state.isShuttingDown then
        return
    end
    
    if _config.maxReconnectAttempts > 0 and _state.reconnectAttempts >= _config.maxReconnectAttempts then
        log("error", "Max reconnection attempts reached (" .. _config.maxReconnectAttempts .. ")")
        Afkty.Events.Error:Fire({
            code = Afkty.ErrorCodes.MAX_RECONNECT_ATTEMPTS,
            message = "Connection failed after " .. _config.maxReconnectAttempts .. " attempts"
        })
        return
    end
    
    _state.reconnectAttempts = _state.reconnectAttempts + 1
    
    -- Exponential backoff with jitter
    local delay = math.min(
        _config.reconnectDelay * (2 ^ (_state.reconnectAttempts - 1)),
        _config.maxReconnectDelay
    )
    delay = delay + (math.random() * 2) -- Add 0-2 seconds jitter
    
    log("info", string.format("Reconnecting in %.1fs (attempt %d%s)", 
        delay, 
        _state.reconnectAttempts,
        _config.maxReconnectAttempts > 0 and ("/" .. _config.maxReconnectAttempts) or ""
    ))
    
    Afkty.Events.Reconnecting:Fire({
        attempt = _state.reconnectAttempts,
        maxAttempts = _config.maxReconnectAttempts,
        delay = delay
    })
    
    task.delay(delay, function()
        if not _state.connected and not _state.isShuttingDown then
            Afkty:Connect()
        end
    end)
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--[[
    Initialize the AFKTY SDK
    
    @param options (table)
        hubKey (string, required) - Hub's API key (provided by script developer)
        userToken (string, required) - User's personal token (from AFKTY app)
        
        autoReconnect (boolean, default: true) - Auto reconnect on disconnect
        heartbeatInterval (number, default: 10) - Seconds between heartbeats
        maxReconnectAttempts (number, default: 20) - Max retry attempts (0 = infinite)
        debug (boolean, default: false) - Enable debug logging
    
    @return Afkty instance
    
    @example
        Afkty:Init({
            hubKey = "hub_live_xxx",        -- From script developer
            userToken = "ABC123",           -- Your 6-character key
            debug = true
        })
]]
function Afkty:Init(options)
    assert(type(options) == "table", "Options must be a table")
    assert(type(options.hubKey) == "string", "hubKey is required (get from script developer)")
    assert(type(options.userToken) == "string", "userToken is required (get from AFKTY app)")
    
    -- Validate hub key format
    if not options.hubKey:match("^hub_live_") then
        log("warn", "hubKey should start with 'hub_live_' - check if correct")
    end
    
    -- Apply config
    _config.hubKey = options.hubKey
    _config.userToken = options.userToken
    
    _config.autoReconnect = options.autoReconnect ~= false
    _config.heartbeatInterval = options.heartbeatInterval or 10
    _config.maxReconnectAttempts = options.maxReconnectAttempts or 20
    _config.debug = options.debug == true
    _config.queueOfflineMessages = options.queueOfflineMessages ~= false
    
    log("info", "AFKTY SDK v" .. Afkty.Version .. " initializing...")
    
    self:Connect()
    return self
end

--[[
    Connect to the AFKTY server
    Called automatically by Init()
]]
function Afkty:Connect()
    if _state.connected or _state.isShuttingDown then
        log("warn", "Already connected or shutting down")
        return false
    end
    
    local wsConnect, wsType = getWebSocket()
    if not wsConnect then
        local msg = "WebSocket not supported. Supported: Synapse, Script-Ware, Fluxus, Wave, Seliware"
        log("error", msg)
        Afkty.Events.Error:Fire({
            code = Afkty.ErrorCodes.WEBSOCKET_NOT_SUPPORTED,
            message = msg
        })
        return false
    end
    
    log("info", "Connecting via " .. wsType .. "...")
    
    local ok, ws = pcall(wsConnect, SERVER_URL)
    if not ok then
        log("error", "Connection failed: " .. tostring(ws))
        Afkty.Events.Error:Fire({
            code = Afkty.ErrorCodes.CONNECTION_FAILED,
            message = tostring(ws)
        })
        scheduleReconnect()
        return false
    end
    
    _state.ws = ws
    
    ws.OnMessage:Connect(handleMessage)
    
    ws.OnClose:Connect(function()
        log("info", "Connection closed")
        local wasAuthenticated = _state.authenticated
        
        _state.ws = nil
        _state.connected = false
        _state.authenticated = false
        _state.sessionId = nil
        
        if _state.heartbeatThread then
            pcall(task.cancel, _state.heartbeatThread)
            _state.heartbeatThread = nil
        end
        
        Afkty.Events.Disconnected:Fire({
            wasAuthenticated = wasAuthenticated,
            willReconnect = _config.autoReconnect and not _state.isShuttingDown
        })
        
        if not _state.isShuttingDown then
            scheduleReconnect()
        end
    end)
    
    -- Authenticate with hub key + user token
    send({
        type = "connect",
        hubKey = _config.hubKey,
        userToken = _config.userToken,
        gameInfo = getGameInfo()
    })
    
    -- Connection timeout
    task.delay(_config.connectionTimeout, function()
        if _state.connected and not _state.authenticated then
            log("error", "Authentication timeout")
            Afkty.Events.Error:Fire({
                code = Afkty.ErrorCodes.CONNECTION_TIMEOUT,
                message = "Server did not authenticate in time"
            })
            if _state.ws then
                pcall(function() _state.ws:Close() end)
            end
        end
    end)
    
    return true
end

--[[
    Send a log message to the mobile app
    Logs are batched automatically for performance
    
    @param message (string) - The log message
    @param level (string, optional) - "info", "warn", "error", "debug"
]]
function Afkty:Log(message, level)
    level = level or "info"
    
    table.insert(_logBatch.messages, {
        message = tostring(message),
        level = level
    })
    
    -- Start batch timer if not running
    if not _logBatch.timer then
        _logBatch.timer = task.delay(_config.logBatchDelay, flushLogBatch)
    end
    
    -- Force flush if batch is full
    if #_logBatch.messages >= _config.logBatchSize then
        if _logBatch.timer then
            pcall(task.cancel, _logBatch.timer)
        end
        flushLogBatch()
    end
end

--[[
    Send a log immediately without batching
    Use for critical messages
    
    @param message (string) - The log message
    @param level (string, optional) - "info", "warn", "error", "debug"
]]
function Afkty:LogNow(message, level)
    send({
        type = "log",
        message = tostring(message),
        level = level or "info"
    })
end

--[[
    Update the status displayed on the mobile app
    Has built-in cooldown to prevent spam (5 seconds minimum)
    
    @param status (string) - Status text (e.g., "Farming Zone 1")
    @param data (table, optional) - Additional data
]]
function Afkty:SetStatus(status, data)
    local now = os.time()
    
    if (now - _state.lastStatusTime) < STATUS_COOLDOWN then
        log("debug", "Status update throttled (cooldown)")
        return false
    end
    
    _state.lastStatus = status
    _state.lastStatusTime = now
    
    send({
        type = "status",
        status = tostring(status),
        data = data
    })
    
    return true
end

--[[
    Send a push notification to the mobile app
    Rate limited to 5 per minute
    
    @param title (string) - Notification title
    @param message (string) - Notification body
]]
function Afkty:Notify(title, message)
    if not title or not message then
        log("warn", "Notify requires title and message")
        return false
    end
    
    send({
        type = "notify",
        title = tostring(title),
        message = tostring(message)
    })
    
    return true
end

--[[
    Send a CRITICAL ALERT with alarm sound
    Use for important events like kicks, bans, crashes
    Rate limited to 5 per minute
    
    @param reason (string) - Why the alert was triggered
    @param title (string, optional) - Custom title
]]
function Afkty:Alert(reason, title)
    if not reason then
        log("warn", "Alert requires a reason")
        return false
    end
    
    send({
        type = "alert",
        reason = tostring(reason),
        title = title
    })
    
    log("info", "Critical alert sent: " .. tostring(reason))
    return true
end

--[[
    Disconnect from the server
    Stops auto-reconnect
    
    @param reason (string, optional) - Disconnect reason
]]
function Afkty:Disconnect(reason)
    _state.isShuttingDown = true
    _config.autoReconnect = false
    
    if _state.heartbeatThread then
        pcall(task.cancel, _state.heartbeatThread)
        _state.heartbeatThread = nil
    end
    
    -- Flush remaining logs
    flushLogBatch()
    
    if _state.ws then
        send({
            type = "disconnect",
            reason = reason or "Script disconnected"
        })
        
        task.delay(0.5, function()
            if _state.ws then
                pcall(function() _state.ws:Close() end)
            end
        end)
    end
    
    log("info", "Disconnected: " .. (reason or "Manual disconnect"))
end

--[[
    Check if connected and authenticated
    
    @return boolean
]]
function Afkty:IsConnected()
    return _state.connected and _state.authenticated
end

--[[
    Get the current session ID
    
    @return string or nil
]]
function Afkty:GetSessionId()
    return _state.sessionId
end

--[[
    Get connection info
    
    @return table
]]
function Afkty:GetInfo()
    return {
        version = Afkty.Version,
        connected = _state.connected,
        authenticated = _state.authenticated,
        sessionId = _state.sessionId,
        hubName = _state.hubName,
        username = _state.username,
        reconnectAttempts = _state.reconnectAttempts,
        queuedMessages = #_state.messageQueue
    }
end

--[[
    Get the last status sent
    
    @return string or nil
]]
function Afkty:GetStatus()
    return _state.lastStatus
end

-- ============================================================================
-- UTILITY WRAPPERS FOR COMMON USE CASES
-- ============================================================================

--[[
    Wrap a function with error handling that sends alerts on crash
    
    @param fn (function) - Function to wrap
    @param alertTitle (string, optional) - Alert title on error
    @return function - Wrapped function
]]
function Afkty:WrapWithAlert(fn, alertTitle)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            self:Alert(tostring(err), alertTitle or "Script Error")
        end
        return ok, err
    end
end

--[[
    Run a function and send alert if it errors
    
    @param fn (function) - Function to run
    @param alertTitle (string, optional) - Alert title on error
    @return boolean, any - Success status and result/error
]]
function Afkty:SafeCall(fn, alertTitle)
    local ok, result = pcall(fn)
    if not ok then
        self:Alert(tostring(result), alertTitle or "Script Error")
    end
    return ok, result
end

--[[
    Simple setup for hub users - provide your key and the hub's key
    
    @param userKey (string) - Your 6-character connection key from the AFKTY app
    @param hubKey (string) - Hub API key (REQUIRED - provided by the script developer)
    
    @example
        local AFKTY = loadstring(game:HttpGet("..."))()
        AFKTY.SetUserKey("ABC123", "hub_live_xxx")
]]
function Afkty.SetUserKey(userKey, hubKey)
    assert(type(userKey) == "string" and #userKey > 0, "User key is required")
    assert(type(hubKey) == "string" and hubKey:match("^hub_live_"), "Hub key is required (get from script developer)")
    
    log("info", "Starting with key: " .. userKey:sub(1, 2) .. "****")
    
    return Afkty:Init({
        hubKey = hubKey,
        userToken = userKey,
        autoReconnect = true,
        debug = false
    })
end

-- ============================================================================
-- AUTO-DISCONNECT ON PLAYER LEAVING (Client-compatible)
-- ============================================================================

local player = Players.LocalPlayer
if player then
    -- Detect when player is removed from game
    player.AncestryChanged:Connect(function(_, parent)
        if not parent and _state.connected then
            Afkty:Disconnect("Player left game")
        end
    end)
end

-- ============================================================================
-- RETURN SDK
-- ============================================================================

return Afkty
