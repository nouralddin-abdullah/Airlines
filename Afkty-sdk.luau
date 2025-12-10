local Afkty = {}
Afkty.__index = Afkty
Afkty.Version = "2.0.0"
-- Services
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

-- State
local _state = {
    ws = nil,
    connected = false,
    authenticated = false,
    sessionId = nil,
    reconnectAttempts = 0,
    heartbeatThread = nil,
    messageQueue = {},
    lastStatus = nil,
    lastStatusTime = 0
}

-- Configuration with defaults
local _config = {
    serverUrl = nil,
    connectionKey = nil,
    autoReconnect = true,
    reconnectDelay = 5,
    maxReconnectAttempts = 10,
    heartbeatInterval = 10,
    debug = false,
    queueOfflineMessages = true,
    statusCooldown = 10,  -- Minimum seconds between status updates
    logBatchSize = 5,     -- Batch logs to reduce network calls
    logBatchDelay = 2     -- Seconds to wait before sending batched logs
}

-- Log batching
local _logBatch = {
    messages = {},
    timer = nil
}

-- Events
Afkty.Events = {
    Connected = Instance.new("BindableEvent"),
    Disconnected = Instance.new("BindableEvent"),
    Reconnecting = Instance.new("BindableEvent"),
    Command = Instance.new("BindableEvent"),
    Error = Instance.new("BindableEvent"),
    RateLimited = Instance.new("BindableEvent")
}

-- Public event connections
Afkty.OnConnected = Afkty.Events.Connected.Event
Afkty.OnDisconnected = Afkty.Events.Disconnected.Event
Afkty.OnReconnecting = Afkty.Events.Reconnecting.Event
Afkty.OnCommand = Afkty.Events.Command.Event
Afkty.OnError = Afkty.Events.Error.Event
Afkty.OnRateLimited = Afkty.Events.RateLimited.Event

--------------------------------------------------------------------------------
-- Internal Utilities
--------------------------------------------------------------------------------

local function log(level, msg)
    if _config.debug or level == "error" or level == "warn" then
        local prefix = ({
            info = "[Afkty]",
            warn = "[Afkty WARNING]",
            error = "[Afkty ERROR]",
            debug = "[Afkty DEBUG]"
        })[level] or "[Afkty]"
        print(prefix, msg)
    end
end

local function getWebSocket()
    -- Priority order for WebSocket implementations
    local implementations = {
        { check = function() return syn and syn.websocket end, get = function() return syn.websocket.connect end, name = "Synapse" },
        { check = function() return WebSocket end, get = function() return WebSocket.connect end, name = "WebSocket" },
        { check = function() return Fluxus and Fluxus.websocket end, get = function() return Fluxus.websocket.connect end, name = "Fluxus" },
        { check = function() return getgenv and getgenv().WebSocket end, get = function() return getgenv().WebSocket.connect end, name = "Environment" },
        { check = function() return websocket and websocket.connect end, get = function() return websocket.connect end, name = "Generic" }
    }
    
    for _, impl in ipairs(implementations) do
        local ok, hasIt = pcall(impl.check)
        if ok and hasIt then
            local ok2, ws = pcall(impl.get)
            if ok2 and ws then
                return ws, impl.name
            end
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

--------------------------------------------------------------------------------
-- Core Networking
--------------------------------------------------------------------------------

local function send(data)
    if not _state.ws then
        if _config.queueOfflineMessages and data.type ~= "heartbeat" then
            table.insert(_state.messageQueue, data)
            if #_state.messageQueue > 50 then
                table.remove(_state.messageQueue, 1)
            end
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
    
    for _, msg in ipairs(_state.messageQueue) do
        send(msg)
        task.wait(0.1) -- Prevent flooding
    end
    
    _state.messageQueue = {}
end

local function flushLogBatch()
    if #_logBatch.messages == 0 then return end
    
    for _, logMsg in ipairs(_logBatch.messages) do
        send({
            type = "log",
            message = logMsg.message,
            level = logMsg.level
        })
    end
    
    _logBatch.messages = {}
    _logBatch.timer = nil
end

local function handleMessage(raw)
    local data = decode(raw)
    if not data then
        log("warn", "Received invalid JSON")
        return
    end
    
    local msgType = data.type
    
    if msgType == "connected" then
        _state.connected = true
        log("info", "Connected to server")
        
    elseif msgType == "authenticated" then
        _state.authenticated = true
        _state.sessionId = data.sessionId
        _state.reconnectAttempts = 0
        log("info", "Authenticated - Session: " .. tostring(data.sessionId))
        
        -- Start heartbeat
        if _state.heartbeatThread then
            task.cancel(_state.heartbeatThread)
        end
        _state.heartbeatThread = task.spawn(function()
            while _state.authenticated do
                task.wait(_config.heartbeatInterval)
                if _state.authenticated then
                    send({ type = "heartbeat" })
                end
            end
        end)
        
        -- Flush queued messages
        flushMessageQueue()
        
        Afkty.Events.Connected:Fire({
            sessionId = data.sessionId,
            message = data.message
        })
        
    elseif msgType == "pong" then
        -- Heartbeat acknowledged
        
    elseif msgType == "command" then
        log("info", "Command received: " .. tostring(data.command))
        Afkty.Events.Command:Fire({
            command = data.command,
            data = data.data
        })
        
    elseif msgType == "error" then
        local code = data.code or "SERVER_ERROR"
        local message = data.message or "Unknown error"
        
        if code == "RATE_LIMITED" then
            log("warn", "Rate limited: " .. message)
            Afkty.Events.RateLimited:Fire({ message = message })
        else
            log("error", message)
            Afkty.Events.Error:Fire({ code = code, message = message })
        end
    end
end

local function scheduleReconnect()
    if not _config.autoReconnect then return end
    
    if _state.reconnectAttempts >= _config.maxReconnectAttempts then
        log("error", "Max reconnection attempts reached")
        Afkty.Events.Error:Fire({
            code = "MAX_RECONNECT_ATTEMPTS",
            message = "Connection failed after " .. _config.maxReconnectAttempts .. " attempts"
        })
        return
    end
    
    _state.reconnectAttempts = _state.reconnectAttempts + 1
    local delay = math.min(_config.reconnectDelay * _state.reconnectAttempts, 30)
    
    log("info", string.format("Reconnecting in %ds (attempt %d/%d)", 
        delay, _state.reconnectAttempts, _config.maxReconnectAttempts))
    
    Afkty.Events.Reconnecting:Fire({
        attempt = _state.reconnectAttempts,
        maxAttempts = _config.maxReconnectAttempts,
        delay = delay
    })
    
    task.delay(delay, function()
        if not _state.connected then
            Afkty:Connect()
        end
    end)
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--[[
    Initialize the Afkty SDK
    
    @param options (table)
        serverUrl (string, required) - Backend WebSocket URL
        connectionKey (string, required) - Single-use auth key from API
        autoReconnect (boolean, default: true) - Auto reconnect on disconnect
        heartbeatInterval (number, default: 10) - Seconds between heartbeats
        maxReconnectAttempts (number, default: 10) - Max retry attempts
        debug (boolean, default: false) - Enable debug logging
    
    @return Afkty instance
]]
function Afkty:Init(options)
    assert(type(options) == "table", "Options must be a table")
    assert(type(options.serverUrl) == "string", "serverUrl is required")
    assert(type(options.connectionKey) == "string", "connectionKey is required")
    
    _config.serverUrl = options.serverUrl
    _config.connectionKey = options.connectionKey
    _config.autoReconnect = options.autoReconnect ~= false
    _config.heartbeatInterval = options.heartbeatInterval or 10
    _config.maxReconnectAttempts = options.maxReconnectAttempts or 10
    _config.debug = options.debug == true
    _config.queueOfflineMessages = options.queueOfflineMessages ~= false
    
    if options.statusCooldown then
        _config.statusCooldown = math.max(1, options.statusCooldown)
    end
    
    self:Connect()
    return self
end

--[[
    Connect to the Afkty server
    Called automatically by Init()
]]
function Afkty:Connect()
    if _state.connected then
        log("warn", "Already connected")
        return false
    end
    
    local wsConnect, wsType = getWebSocket()
    if not wsConnect then
        local msg = "WebSocket not supported. Supported executors: Synapse, Script-Ware, Fluxus, Wave, Seliware"
        log("error", msg)
        Afkty.Events.Error:Fire({
            code = "WEBSOCKET_NOT_SUPPORTED",
            message = msg
        })
        return false
    end
    
    log("info", "Connecting via " .. wsType .. "...")
    
    local ok, ws = pcall(wsConnect, _config.serverUrl)
    if not ok then
        log("error", "Connection failed: " .. tostring(ws))
        Afkty.Events.Error:Fire({
            code = "CONNECTION_FAILED",
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
            willReconnect = _config.autoReconnect
        })
        
        scheduleReconnect()
    end)
    
    -- Authenticate with server
    send({
        type = "connect",
        connectionKey = _config.connectionKey,
        gameInfo = getGameInfo()
    })
    
    return true
end

--[[
    Send a log message to the mobile app
    Logs are batched to reduce network traffic
    
    @param message (string) - Log message
    @param level (string, optional) - "info", "warn", "error", "debug"
    @return boolean - Success
]]
function Afkty:Log(message, level)
    if type(message) ~= "string" then
        message = tostring(message)
    end
    
    level = level or "info"
    
    -- Add to batch
    table.insert(_logBatch.messages, {
        message = message,
        level = level
    })
    
    -- Start batch timer if not running
    if not _logBatch.timer then
        _logBatch.timer = task.delay(_config.logBatchDelay, flushLogBatch)
    end
    
    -- Flush immediately if batch is full
    if #_logBatch.messages >= _config.logBatchSize then
        if _logBatch.timer then
            pcall(task.cancel, _logBatch.timer)
        end
        flushLogBatch()
    end
    
    return true
end

--[[
    Send log immediately without batching
    Use for important messages that need instant delivery
    
    @param message (string) - Log message
    @param level (string, optional) - "info", "warn", "error", "debug"
    @return boolean - Success
]]
function Afkty:LogNow(message, level)
    if type(message) ~= "string" then
        message = tostring(message)
    end
    
    return send({
        type = "log",
        message = message,
        level = level or "info"
    })
end

--[[
    Update status displayed on mobile app
    Includes built-in cooldown to prevent rate limiting
    
    @param status (string) - Status text
    @param data (table, optional) - Additional data
    @param force (boolean, optional) - Bypass cooldown
    @return boolean - Success
]]
function Afkty:SetStatus(status, data, force)
    if type(status) ~= "string" then
        status = tostring(status)
    end
    
    local now = os.clock()
    
    -- Check cooldown unless forced
    if not force and _state.lastStatus == status then
        return false -- Same status, skip
    end
    
    if not force and (now - _state.lastStatusTime) < _config.statusCooldown then
        log("debug", "Status update skipped (cooldown)")
        return false
    end
    
    _state.lastStatus = status
    _state.lastStatusTime = now
    
    return send({
        type = "status",
        status = status,
        data = data or {}
    })
end

--[[
    Send a push notification to mobile app
    Rate limited: 5 per minute
    
    @param title (string) - Notification title
    @param message (string) - Notification body
    @return boolean - Success
]]
function Afkty:Notify(title, message)
    assert(type(title) == "string", "title must be a string")
    assert(type(message) == "string", "message must be a string")
    
    return send({
        type = "notify",
        title = title,
        message = message
    })
end

--[[
    Send a CRITICAL ALERT to mobile app with alarm sound
    Use for important events like kicks, bans, crashes
    Rate limited: 5 per minute (shared with Notify)
    
    @param reason (string) - Alert reason/message
    @param title (string, optional) - Custom alert title
    @return boolean - Success
]]
function Afkty:Alert(reason, title)
    assert(type(reason) == "string", "reason must be a string")
    
    return send({
        type = "alert",
        reason = reason,
        title = title or "🚨 CRITICAL ALERT"
    })
end

--[[
    Disconnect from the server
    
    @param reason (string, optional) - Disconnect reason
]]
function Afkty:Disconnect(reason)
    _config.autoReconnect = false
    reason = reason or "Manual disconnect"
    
    -- Flush pending logs
    flushLogBatch()
    
    if _state.heartbeatThread then
        pcall(task.cancel, _state.heartbeatThread)
        _state.heartbeatThread = nil
    end
    
    if _state.ws then
        send({
            type = "disconnect",
            reason = reason
        })
        
        task.wait(0.2)
        pcall(function() _state.ws:Close() end)
        _state.ws = nil
    end
    
    _state.connected = false
    _state.authenticated = false
    _state.sessionId = nil
    
    log("info", "Disconnected: " .. reason)
end

--[[
    Check connection status
    @return boolean - True if connected and authenticated
]]
function Afkty:IsConnected()
    return _state.authenticated == true
end

--[[
    Get current session ID
    @return string|nil - Session ID or nil if not connected
]]
function Afkty:GetSessionId()
    return _state.sessionId
end

--[[
    Get SDK version
    @return string - Version string
]]
function Afkty:GetVersion()
    return Afkty.Version
end

--[[
    Get connection info
    @return table - Connection details
]]
function Afkty:GetInfo()
    return {
        version = Afkty.Version,
        connected = _state.connected,
        authenticated = _state.authenticated,
        sessionId = _state.sessionId,
        serverUrl = _config.serverUrl,
        reconnectAttempts = _state.reconnectAttempts,
        queuedMessages = #_state.messageQueue
    }
end

--------------------------------------------------------------------------------
-- Auto-cleanup
--------------------------------------------------------------------------------

-- Disconnect when player leaves
local player = Players.LocalPlayer
if player then
    player.AncestryChanged:Connect(function(_, parent)
        if not parent then
            Afkty:Disconnect("Player left game")
        end
    end)
end

return Afkty
