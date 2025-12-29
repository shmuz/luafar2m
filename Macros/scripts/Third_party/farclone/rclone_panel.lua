-- rclone_panel.lua
-- Rclone remotes integration for Far Manager

-- Configuration (use \\ for paths in Windows)
local RclonePath = "C:\\Applications\\Utils\\rclone\\rclone.exe"  -- Path to rclone.exe
local ConfigPath = ""  -- Empty = use default rclone config location
local Timeout = 10  -- Server timeout in minutes

-- Server settings (SFTP protocol)
local ServPort = 2022
local ServPass = "rclone"
local RCPort = 5572

_G.G = _G.G or {}
G.rclone_server = G.rclone_server or { running = false, remote = nil }

local function executeRclone(args)
  local configArg = ConfigPath ~= "" 
    and string.format('--config "%s"', ConfigPath)
    or ""
  
  local command = string.format('"%s" %s %s', RclonePath, configArg, args)
  local handle = io.popen(command)
  local output = {}
  if handle then
    for line in handle:lines() do
      output[#output + 1] = line
    end
    handle:close()
  end
  return output
end

local function getRemotes()
  local remotes_raw = executeRclone("listremotes")
  local remotes = {}
  for _, remote in ipairs(remotes_raw) do
    local name = remote:match("^(.+):$") or remote
    if name ~= "" then
      table.insert(remotes, name)
    end
  end
  return remotes
end

local function isPortInUse(port)
  local handle = io.popen(string.format('netstat -an | find ":%d"', port))
  if handle then
    local output = handle:read("*a")
    handle:close()
    return output:find("LISTENING") ~= nil
  end
  return false
end

local function stopServer()
  if not G.rclone_server.running then
    return true
  end
  
  local cmd = string.format('curl -X POST http://127.0.0.1:%d/core/quit 2>nul', RCPort)
  os.execute(cmd)
  
  local maxWait = 10
  local waited = 0
  while (isPortInUse(ServPort) or isPortInUse(RCPort)) and waited < maxWait do
    win.Sleep(500)
    waited = waited + 1
  end
  
  G.rclone_server.running = false
  G.rclone_server.remote = nil
  
  return true
end

local function openNetBox(remoteName)
  -- Use remote name as username so NetBox shows "remoteName@127.0.0.1"
  local url = string.format("sftp://%s:%s@127.0.0.1:%d/", remoteName, ServPass, ServPort)
  
  mf.postmacro(function()
    Keys("Esc")
    print(url)
    Keys("Enter")
  end)
  
  return true
end

local function startServer(remoteName)
  if G.rclone_server.running and G.rclone_server.remote == remoteName then
    -- Server already running for this remote, ask to stop
    local result = far.Message(
      string.format("Server already running for: %s\n\nStop server?", remoteName),
      "Rclone",
      ";YesNo",
      "w"
    )
    
    if result == 1 then
      stopServer()
      -- NetBox will show disconnection, no need for extra message
    end
    return true
  end
  
  if G.rclone_server.running then
    local result = far.Message(
      string.format("Server running for: %s\n\nReconnect to: %s ?\n\n(Server will restart)", 
        G.rclone_server.remote, remoteName),
      "Switch Remote",
      ";YesNo",
      "w"
    )
    
    if result == 1 then
      stopServer()
      win.Sleep(500)
    else
      return false
    end
  end
  
  if isPortInUse(ServPort) or isPortInUse(RCPort) then
    far.Message(string.format("Ports %d or %d still in use!\n\nWait a moment and try again.", 
      ServPort, RCPort), "Port Conflict", "OK", "w")
    return false
  end
  
  local configArg = ConfigPath ~= "" 
    and string.format('--config "%s"', ConfigPath)
    or ""
  
  -- Use remote name as SFTP username for better identification in NetBox
  local cmd = string.format(
    'start /MIN "rclone_%s" "%s" %s serve sftp %s: --addr 127.0.0.1:%d --user %s --pass %s --rc --rc-addr 127.0.0.1:%d --rc-no-auth --vfs-cache-mode writes --timeout %dm',
    remoteName, RclonePath, configArg, remoteName, ServPort, remoteName, ServPass, RCPort, Timeout
  )
  
  os.execute(cmd)
  win.Sleep(1500)
  
  if not isPortInUse(ServPort) then
    far.Message("Failed to start server!", "Error", "OK", "w")
    return false
  end
  
  G.rclone_server.running = true
  G.rclone_server.remote = remoteName
  
  openNetBox(remoteName)
  
  return true
end

local function makeHotkey(index)
  if index >= 1 and index <= 9 then
    return tostring(index)
  elseif index == 10 then
    return "0"
  else
    return string.char(64 + index - 10)
  end
end

local function openRcloneConfig()
  local configArg = ConfigPath ~= "" 
    and string.format('--config "%s"', ConfigPath)
    or ""
  
  os.execute(string.format('start "Rclone Config" "%s" %s config', RclonePath, configArg))
end

Macro {
  id = "692846CB-53D8-43B2-A3C0-D180E65246B9",
  area = "Shell Info QView Tree",
  key = "LAltF1",
  description = "Rclone: Open left panel disk menu",
  priority = 60,
  action = function()
    if not APanel.Left then
      Keys("Tab")
    end
    Keys("AltF1")
  end
}

Macro {
  id = "B72092ED-1431-4747-9F9A-D9851D2CEF78",
  area = "Shell Info QView Tree",
  key = "LAltF2",
  description = "Rclone: Open right panel disk menu",
  priority = 60,
  action = function()
    if APanel.Left then
      Keys("Tab")
    end
    Keys("AltF2")
  end
}

MenuItem {
  menu = "Disks",
  guid = "51E74971-6C9A-469D-93CF-95B9B1E059AF",
  text = "Rclone Remotes",
  action = function(OpenFrom, Item)
    local remotes = getRemotes()
    
    if #remotes == 0 then
      far.Message("No remotes found!", "Error", "OK", "w")
      return
    end
    
    -- Build menu items with hotkeys and [running] marker
    local items = {}
    for i, remote in ipairs(remotes) do
      local hotkey = makeHotkey(i)
      local marker = (G.rclone_server.running and G.rclone_server.remote == remote) 
        and " [running]" 
        or ""
      table.insert(items, { 
        text = string.format("&%s. %s%s", hotkey, remote, marker),
        remote = remote
      })
    end
    
    -- Bottom hint - show F8 only when server is running
    local bottomHint = G.rclone_server.running 
      and "Shift+F4: Config  F8: Serv Stop"
      or "Shift+F4: Config"
    
    local menuProps = {
      Title = "Select Rclone Remote",
      Bottom = bottomHint,
      Flags = far.Flags.FMENU_WRAPMODE
    }
    
    local breakKeys = {
      { BreakKey = "SHIFTF4" },
      { BreakKey = "F8" },
    }
    
    local result = far.Menu(menuProps, items, breakKeys)
    
    if result then
      if result.BreakKey == "SHIFTF4" then
        openRcloneConfig()
      elseif result.BreakKey == "F8" then
        if G.rclone_server.running then
          stopServer()
          -- NetBox will show disconnection, no extra message needed
        end
      else
        startServer(result.remote)
      end
    end
  end
}

MenuItem {
  menu = "Plugins",
  area = "Shell",
  guid = "61F74971-7C9A-469D-93CF-95B9B1E059AF",
  text = "Stop Rclone Server",
  action = function()
    if G.rclone_server.running then
      local remote = G.rclone_server.remote
      stopServer()
      far.Message("Server stopped:\n" .. remote, "Rclone", "OK")
    else
      far.Message("No server running", "Rclone", "OK")
    end
  end
}

Event {
  description = "Stop Rclone server when leaving NetBox",
  group = "ShellEvent",
  action = function(Event, Param)
    if G.rclone_server.running and not APanel.Plugin then
      stopServer()
    end
  end
}

Event {
  description = "Stop Rclone server on Far exit",
  group = "ExitFAR",
  action = function()
    stopServer()
  end
}
