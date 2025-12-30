-- rclone_panel.lua
-- Rclone remotes integration for Far Manager
-- Original project: https://github.com/phanex/farclone/

local osWin = package.config:sub(1,1) == "\\"
local F = far.Flags

-- Configuration (use \\ for paths in Windows)
local RclonePath =  -- Path to rclone.exe
    osWin and "C:\\Applications\\Utils\\rclone\\rclone.exe"
    or "rclone"
local ConfigPath = ""  -- Empty = use default rclone config location
local Timeout = 10  -- Server timeout in minutes

-- Server settings (SFTP protocol)
local ServPort = 2022
local ServPass = "rclone"
local RCPort = 5572

-- luacheck: ignore 112 113 (non-standard/undefined global variable G)
_G.G = _G.G or {}
G.rclone_server = G.rclone_server or { running = false, remote = nil }

local function executeRclone(args)
  local configArg = ConfigPath ~= ""
    and ('--config "%s"'):format(ConfigPath) or ""

  local command = ('"%s" %s %s'):format(RclonePath, configArg, args)
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
  local fmt = osWin and 'netstat -an | find ":%d"' or 'netstat -an | grep %d'
  local handle = io.popen(fmt:format(port))
  if handle then
    local output = handle:read("*a")
    handle:close()
    return output:find(osWin and "LISTENING" or "LISTEN") ~= nil
  end
  return false
end

local function stopServer()
  if not G.rclone_server.running then
    return
  end

  local nul = osWin and 'nul' or '/dev/null'
  local cmd = ('curl -X POST http://127.0.0.1:%d/core/quit 2>%s'):format(RCPort, nul)
  os.execute(cmd)

  local maxWait = 5000 -- msec
  local waited = 0
  while (isPortInUse(ServPort) or isPortInUse(RCPort)) and waited < maxWait do
    win.Sleep(100)
    waited = waited + 100
  end

  G.rclone_server.running = false
  G.rclone_server.remote = nil
end

local function openNetBox(remoteName)
  -- Use remote name as username so NetBox shows "remoteName@127.0.0.1"
  local url = ("sftp://%s:%s@127.0.0.1:%d/"):format(remoteName, ServPass, ServPort)

  mf.postmacro(function()
    Keys("Esc")
    print(url)
    Keys("Enter")
  end)
end

local function startServer(remoteName)
  if G.rclone_server.running and G.rclone_server.remote == remoteName then
    -- Server already running for this remote, ask to stop
    local result = far.Message(
      ("Server already running for: %s\n\nStop server?"):format(remoteName),
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
      ("Server running for: %s\n\nReconnect to: %s ?\n\n(Server will restart)"):format(
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
    far.Message(("Ports %d or %d still in use!\n\nWait a moment and try again."):
      format(ServPort, RCPort), "Port Conflict", "OK", "w")
    return false
  end

  local configArg = ConfigPath ~= ""
    and ('--config "%s"'):format(ConfigPath) or ""

  -- Use remote name as SFTP username for better identification in NetBox
  local fmt = '"%s" %s serve sftp %s: --addr 127.0.0.1:%d --user %s --pass %s --rc'..
              ' --rc-addr 127.0.0.1:%d --rc-no-auth --vfs-cache-mode writes --timeout %dm'

  if osWin then
    fmt = ('start /MIN "rclone_%s" %s'):format(remoteName, fmt)
  else
    fmt = fmt..' &'
  end

  local cmd = fmt:format(RclonePath, configArg, remoteName, ServPort,
                         remoteName, ServPass, RCPort, Timeout)
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
    and ('--config "%s"'):format(ConfigPath) or ""

  if osWin then
    local cmd = ('start "Rclone Config" "%s" %s config'):format(RclonePath, configArg)
    os.execute(cmd)
  else
    local cmd = ('"%s" %s config'):format(RclonePath, configArg)
    far.Execute(cmd)
  end
end

local function Main()
  local remotes = getRemotes()

  if #remotes == 0 then
    far.Message("No remotes found!", "Error", "OK", "w")
    return
  end

  -- Show the top-level menu only if the server is running
  if G.rclone_server.running then
    local _,pos = far.Menu({Title="Rclone"}, {{text="&Remotes"}, {text="&Stop Server"}})
    if pos == nil then
      return
    elseif pos == 2 then
      local remote = G.rclone_server.remote
      stopServer()
      far.Message("Server stopped:\n" .. remote, "Rclone", "OK")
      return
    end
  end

  -- Build menu items with hotkeys and [running] marker
  local items = {}
  for i, remote in ipairs(remotes) do
    local hotkey = makeHotkey(i)
    local marker = (G.rclone_server.running and G.rclone_server.remote == remote)
      and " [running]" or ""
    table.insert(items, {
      text = ("&%s. %s%s"):format(hotkey, remote, marker),
      remote = remote
    })
  end

  -- Bottom hint - show F8 only when server is running
  local bottomHint = G.rclone_server.running
    and "Shift+F4: Config  F8: Stop Server"
    or "Shift+F4: Config"

  local menuProps = {
    Title = "Select Rclone Remote",
    Bottom = bottomHint,
    Flags = F.FMENU_WRAPMODE
  }

  local breakKeys = "ShiftF4 F8"

  local result = far.Menu(menuProps, items, breakKeys)

  if result then
    if result.BreakKey == "ShiftF4" then
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

MenuItem {
  menu = "Plugins";
  area = "Shell";
  guid = "51E74971-6C9A-469D-93CF-95B9B1E059AF";
  text = "farclone";
  action = Main;
}

Event {
  description = "Stop Rclone server on Far exit";
  group = "ExitFAR";
  action = function(reload)
    if not reload then
      stopServer()
    end
  end;
}
