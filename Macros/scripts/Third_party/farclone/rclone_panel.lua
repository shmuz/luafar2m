-- rclone_panel.lua
-- Rclone remotes integration for Far Manager
-- Original project: https://github.com/phanex/farclone/

local osWin = package.config:sub(1,1) == "\\"
local F = far.Flags
local NetBoxGuid = win.Uuid("42E4AEB1-A230-44F4-B33C-F195BB654931")
local NetRocksID = 0xAE8CE351

-- Configuration
local RclonePath =  -- Path to rclone.exe
    osWin and "rclone" -- may be full path, e.g. "C:\\Applications\\Utils\\rclone\\rclone.exe"
    or "rclone"
local ConfigPath = ""  -- Empty = use default rclone config location
local Timeout = 10  -- Server timeout in minutes

-- Server settings (SFTP protocol)
local ServPort = 2022
local ServPass = "rclone"
local RCPort = 5572

-- luacheck: new globals G (non-standard/undefined global variable G)
_G.G = _G.G or {}
G.rclone_server = G.rclone_server or { running = false, remote = nil }

local function makeConfigArg()
  return ConfigPath == "" and "" or ('--config "%s"'):format(ConfigPath)
end

local function executeRclone(args)
  local configArg = makeConfigArg()
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

local function makeStartServerCommand(remoteName)
  -- Use remote name as SFTP username for better identification in NetBox
  local args = {
    ('"%s"'):format(RclonePath),
    makeConfigArg(),
    ("serve sftp %s:"):format(remoteName),
    ("--addr 127.0.0.1:%d"):format(ServPort),
    "--user", remoteName,
    "--pass", ServPass,
    "--rc", -- stands for "remote control"
    ("--rc-addr 127.0.0.1:%d"):format(RCPort),
    "--rc-no-auth",
    "--vfs-cache-mode writes",
    ("--timeout %dm"):format(Timeout)
  }
  local cmd = table.concat(args, " ")

  if osWin then
    cmd = ('start /MIN "rclone_%s" %s'):format(remoteName, cmd)
  else
    cmd = cmd..' &'
  end

  return cmd
end

local function startServer(remoteName)
  if G.rclone_server.running and G.rclone_server.remote == remoteName then
    local action = "open"

    local info = panel.GetPanelInfo(nil, 1)
    if (info.OwnerGuid == NetBoxGuid) or (info.OwnerID == NetRocksID) then
      local msg = ("Server already running for: %s\n\nStop server?"):format(remoteName)
      action = far.Message(msg, "Rclone", ";YesNo", "w") == 1 and "stop" or "none"
    end

    if action == "open" then
      openNetBox(remoteName)
    elseif action == "stop" then
      stopServer() -- NetBox will show disconnection, no need for extra message
    end

    return true
  end

  if G.rclone_server.running then
    local msg = ("Server running for: %s\n\nReconnect to: %s ?\n\n(Server will restart)")
        : format(G.rclone_server.remote, remoteName)
    if 1 == far.Message(msg, "Switch Remote", ";YesNo", "w") then
      stopServer()
      win.Sleep(500)
    else
      return false
    end
  end

  if isPortInUse(ServPort) or isPortInUse(RCPort) then
    local msg = ("Ports %d or %d still in use!\n\nWait a moment and try again.")
        : format(ServPort, RCPort)
    far.Message(msg, "Port Conflict", "OK", "w")
    return false
  end

  local cmd = makeStartServerCommand(remoteName)
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
  local configArg = makeConfigArg()

  if osWin then
    local cmd = ('start "Rclone Config" "%s" %s config'):format(RclonePath, configArg)
    os.execute(cmd)
  else
    local cmd = ('"%s" %s config'):format(RclonePath, configArg)
    far.Execute(cmd) -- luacheck: ignore (accessing undefined field)
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
