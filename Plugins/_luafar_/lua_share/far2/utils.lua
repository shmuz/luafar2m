-- utils.lua --

local history = require "history"
local Package = {}
local F = far.Flags
local PluginDir = far.PluginStartupInfo().ModuleName:match(".*[\\/]")
local dirsep = package.config:sub(1,1)

function Package.CheckLuafarVersion (reqVersion, msgTitle)
  local v1, v2 = far.LuafarVersion(true)
  local r1, r2 = reqVersion:match("^(%d+)%.(%d+)")
  r1, r2 = tonumber(r1), tonumber(r2)
  if (v1 > r1) or (v1 == r1 and v2 >= r2) then return true end
  far.Message(
    ("LuaFAR %s or newer is required\n(loaded version is %s)")
    :format(reqVersion, far.LuafarVersion()),
    msgTitle, ";Ok", "w")
  return false
end

local function OnError (msg)
  local tPaths = { PluginDir }
  for dir in package.path:gmatch("[^;]+") do
    tPaths[#tPaths+1] = dir:gsub("[^\\/]+$", "")
  end

  local function repair(str)
    for _, dir in ipairs(tPaths) do
      local part1, part2 = str, ""
      while true do
        local p1, p2 = part1:match("(.*[\\/])(.+)")
        if not p1 then break end
        part1, part2 = p1, p2..part2
        if part1 == dir:sub(-part1:len()) then
          return dir .. str:sub(-part2:len())
        end
      end
    end
  end

  local jumps, buttons = {}, "&OK"
  msg = tostring(msg):gsub("[^\n]+",
    function(line)
      line = line:gsub("^\t", ""):gsub("(.-)%:(%d+)%:(%s*)",
        function(file, numline, space)
          if #jumps < 9 then
            local file2 = file:sub(1,3) ~= "..." and file or repair(file:sub(4))
            if file2 then
              local name = file2:match('^%[string "(.*)"%]$')
              if not name or name=="all text" or name=="selection" then
                jumps[#jumps+1] = { file=file2, line=tonumber(numline) }
                buttons = buttons .. ";[J&" .. (#jumps) .. "]"
                return ("\16[J%d]:%s:%s:%s"):format(#jumps, file, numline, space)
              end
            end
          end
          return "[?]:" .. file .. ":" .. numline .. ":" .. space
        end)
      return line
    end)
  collectgarbage "collect"
  local caption = ("Error [used: %d Kb]"):format(collectgarbage "count")
  local ret = far.Message(msg, caption, buttons, "wl")
  if ret <= 1 then return end
  ret = ret - 1 -- skip the leftmost button "OK"

  local file, line = jumps[ret].file, jumps[ret].line
  local luaScript = file=='[string "all text"]' or file=='[string "selection"]'
  if not luaScript then
    local trgInfo
    for i=1,far.AdvControl("ACTL_GETWINDOWCOUNT") do
      local wInfo = far.AdvControl("ACTL_GETWINDOWINFO", i)
      if wInfo.Type==F.WTYPE_EDITOR and
        wInfo.Name:gsub("/",dirsep) == file:gsub("/",dirsep)
      then
        trgInfo = wInfo
        if wInfo.Current then break end
      end
    end
    if trgInfo then
      if not trgInfo.Current then
        far.AdvControl("ACTL_SETCURRENTWINDOW", trgInfo.Pos)
        far.AdvControl("ACTL_COMMIT")
      end
    else
      editor.Editor(file, nil,nil,nil,nil,nil, {EF_NONMODAL=1,EF_IMMEDIATERETURN=1})
    end
  end

  local eInfo = editor.GetInfo()
  if eInfo then
    if file == '[string "selection"]' then
      local startsel = eInfo.BlockType~=F.BTYPE_NONE and eInfo.BlockStartLine or 0
      line = line + startsel
    end
    local offs = math.floor(eInfo.WindowSizeY / 2)
    editor.SetPosition(line, 1, 1, line>offs and line-offs or 0)
    editor.Redraw()
  end
end

function Package.InitPlugin (workDir)
  export.OnError = OnError

  local plugin = {}
  plugin.ModuleDir = PluginDir
  plugin.WorkDir = assert(os.getenv("HOME")).."/.config/far2l/plugins/lf4ed/"..workDir
  --assert(win.CreateDir(plugin.WorkDir, true))
  os.execute(("mkdir -p '%s'"):format(plugin.WorkDir))
  plugin.History = history.new(plugin.WorkDir.."/mplugin.data")
  return plugin
end

return Package

