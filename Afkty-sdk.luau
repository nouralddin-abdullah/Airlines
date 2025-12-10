local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local Afkty = {}
Afkty.__index = Afkty

-- Internal state
local _ws = nil
local _connected = false
local _authenticated = false
local _reconnectAttempts = 0
local _heartbeatThread = nil
local _config = {
  serverUrl = nil,
  connectionKey = nil,
  autoReconnect = true,
  reconnectDelay = 5,
  maxReconnectAttempts = 10,
  heartbeatInterval = 10,
  debug = false
}

-- Events
Afkty.Events = {
  Connected = Instance.new("BindableEvent"),
  Disconnected = Instance.new("BindableEvent"),
  Command = Instance.new("BindableEvent"),
  Error = Instance.new("BindableEvent")
}

-- Internal logging
local function log(level, message)
  if _config.debug or level == "error" then
    print(string.format("[Afkty][%s] %s", level:upper(), message))
  end
end

-- Detect WebSocket implementation
local function getWebSocketImpl()
  if syn and syn.websocket and syn.websocket.connect then
    return syn.websocket.connect, "Synapse"
  elseif WebSocket and WebSocket.connect then
    return WebSocket.connect, "Generic"
  elseif Fluxus and Fluxus.websocket then
    return Fluxus.websocket.connect, "Fluxus"
  elseif getgenv().WebSocket then
    return getgenv().WebSocket.connect, "Environment"
  end
  return nil, nil
end

-- Get executor name
local function getExecutor()
  if identifyexecutor then
    local name, version = identifyexecutor()
    return version and (name .. " " .. version) or name
  end
  return "Unknown"
end

-- Get game info
local function getGameInfo()
  local success, productInfo = pcall(function()
    return MarketplaceService:GetProductInfo(game.PlaceId)
  end)
  
  return {
    name = success and productInfo.Name or "Unknown",
    placeId = game.PlaceId,
    jobId = game.JobId,
    executor = getExecutor()
  }
end

-- JSON encode with error handling
local function encode(data)
  local success, result = pcall(function()
    return HttpService:JSONEncode(data)
  end)
  return success and result or nil
end

-- JSON decode with error handling
local function decode(str)
  local success, result = pcall(function()
    return HttpService:JSONDecode(str)
  end)
  return success and result or nil
end

--[[
  Initialize the SDK
  
  @param options table
    - serverUrl: string (required) - WebSocket server URL
    - connectionKey: string (required) - Authentication key from API
    - autoReconnect: boolean (default: true) - Auto reconnect on disconnect
    - heartbeatInterval: number (default: 10) - Seconds between heartbeats
    - debug: boolean (default: false) - Enable debug logging
  
  @return Afkty instance
]]
function Afkty:Init(options)
  assert(type(options) == "table", "Options table required")
  assert(options.serverUrl, "serverUrl is required")
  assert(options.connectionKey, "connectionKey is required")
  
  _config.serverUrl = options.serverUrl
  _config.connectionKey = options.connectionKey
  _config.autoReconnect = options.autoReconnect ~= false
  _config.heartbeatInterval = options.heartbeatInterval or 10
  _config.maxReconnectAttempts = options.maxReconnectAttempts or 10
  _config.debug = options.debug or false
  
  self:Connect()
  return self
end

--[[
  Connect to the server
  Called automatically by Init()
]]
function Afkty:Connect()
  if _connected then
    log("warn", "Already connected")
    return
  end
  
  local wsConnect, wsType = getWebSocketImpl()
  if not wsConnect then
    log("error", "WebSocket not supported by this executor")
    self.Events.Error:Fire({ 
      code = "WEBSOCKET_NOT_SUPPORTED",
      message = "Executor does not support WebSocket connections"
    })
    return
  end
  
  log("info", "Connecting via " .. wsType)
  
  local success, connection = pcall(wsConnect, _config.serverUrl)
  if not success then
    log("error", "Connection failed: " .. tostring(connection))
    self.Events.Error:Fire({ 
      code = "CONNECTION_FAILED",
      message = tostring(connection)
    })
    self:_scheduleReconnect()
    return
  end
  
  _ws = connection
  
  _ws.OnMessage:Connect(function(message)
    self:_handleMessage(message)
  end)
  
  _ws.OnClose:Connect(function()
    log("info", "Connection closed")
    local wasAuthenticated = _authenticated
    _connected = false
    _authenticated = false
    
    if _heartbeatThread then
      task.cancel(_heartbeatThread)
      _heartbeatThread = nil
    end
    
    self.Events.Disconnected:Fire({ wasAuthenticated = wasAuthenticated })
    self:_scheduleReconnect()
  end)
  
  -- Authenticate
  self:_send({
    type = "connect",
    connectionKey = _config.connectionKey,
    gameInfo = getGameInfo()
  })
end

-- Internal message handler
function Afkty:_handleMessage(raw)
  local data = decode(raw)
  if not data then
    log("warn", "Invalid message received")
    return
  end
  
  local msgType = data.type
  
  if msgType == "connected" then
    _connected = true
    log("info", "Connected to server")
    
  elseif msgType == "authenticated" then
    _authenticated = true
    _reconnectAttempts = 0
    log("info", "Authenticated - Session: " .. (data.sessionId or "unknown"))
    self:_startHeartbeat()
    self.Events.Connected:Fire({
      sessionId = data.sessionId,
      message = data.message
    })
    
  elseif msgType == "pong" then
    -- Heartbeat acknowledged
    
  elseif msgType == "command" then
    log("info", "Command: " .. tostring(data.command))
    self.Events.Command:Fire({
      command = data.command,
      data = data.data
    })
    
  elseif msgType == "error" then
    log("error", data.message or "Unknown error")
    self.Events.Error:Fire({
      code = data.code or "SERVER_ERROR",
      message = data.message
    })
  end
end

-- Internal send function
function Afkty:_send(data)
  if not _ws then
    return false
  end
  
  local encoded = encode(data)
  if not encoded then
    log("error", "Failed to encode message")
    return false
  end
  
  local success = pcall(function()
    _ws:Send(encoded)
  end)
  
  return success
end

-- Internal heartbeat loop
function Afkty:_startHeartbeat()
  if _heartbeatThread then
    task.cancel(_heartbeatThread)
  end
  
  _heartbeatThread = task.spawn(function()
    while _authenticated do
      task.wait(_config.heartbeatInterval)
      if _authenticated then
        self:_send({ type = "heartbeat" })
      end
    end
  end)
end

-- Internal reconnection handler
function Afkty:_scheduleReconnect()
  if not _config.autoReconnect then
    return
  end
  
  if _reconnectAttempts >= _config.maxReconnectAttempts then
    log("error", "Max reconnection attempts reached")
    self.Events.Error:Fire({
      code = "MAX_RECONNECT_ATTEMPTS",
      message = "Failed to reconnect after " .. _config.maxReconnectAttempts .. " attempts"
    })
    return
  end
  
  _reconnectAttempts = _reconnectAttempts + 1
  local delay = math.min(_config.reconnectDelay * _reconnectAttempts, 30)
  
  log("info", string.format("Reconnecting in %ds (attempt %d/%d)", 
    delay, _reconnectAttempts, _config.maxReconnectAttempts))
  
  task.delay(delay, function()
    if not _connected then
      self:Connect()
    end
  end)
end

--[[
  Send a log message to the mobile app
  
  @param message string - Log message
  @param level string (optional) - Log level: "info", "warn", "error", "debug"
  
  @return boolean - Success
]]
function Afkty:Log(message, level)
  assert(type(message) == "string", "Message must be a string")
  
  return self:_send({
    type = "log",
    message = message,
    level = level or "info"
  })
end

--[[
  Update status displayed on mobile app
  
  @param status string - Status text
  @param data table (optional) - Additional data
  
  @return boolean - Success
]]
function Afkty:SetStatus(status, data)
  assert(type(status) == "string", "Status must be a string")
  
  return self:_send({
    type = "status",
    status = status,
    data = data or {}
  })
end

--[[
  Send a notification to the mobile app
  Triggers a push notification if FCM is configured
  
  @param title string - Notification title
  @param message string - Notification body
  
  @return boolean - Success
]]
function Afkty:Notify(title, message)
  assert(type(title) == "string", "Title must be a string")
  assert(type(message) == "string", "Message must be a string")
  
  return self:_send({
    type = "notify",
    title = title,
    message = message
  })
end

--[[
  Disconnect from the server
  
  @param reason string (optional) - Disconnect reason
]]
function Afkty:Disconnect(reason)
  _config.autoReconnect = false
  
  if _heartbeatThread then
    task.cancel(_heartbeatThread)
    _heartbeatThread = nil
  end
  
  if _ws then
    self:_send({
      type = "disconnect",
      reason = reason or "Manual disconnect"
    })
    
    task.wait(0.3)
    pcall(function() _ws:Close() end)
    _ws = nil
  end
  
  _connected = false
  _authenticated = false
  log("info", "Disconnected: " .. (reason or "Manual disconnect"))
end

--[[
  Check if connected and authenticated
  
  @return boolean
]]
function Afkty:IsConnected()
  return _authenticated
end

--[[
  Get current configuration
  
  @return table
]]
function Afkty:GetConfig()
  return {
    serverUrl = _config.serverUrl,
    autoReconnect = _config.autoReconnect,
    heartbeatInterval = _config.heartbeatInterval,
    debug = _config.debug
  }
end

-- Cleanup on player leaving
Players.LocalPlayer.AncestryChanged:Connect(function(_, parent)
  if not parent then
    Afkty:Disconnect("Player left game")
  end
end)

return Afkty
