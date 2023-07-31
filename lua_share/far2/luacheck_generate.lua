-- Started: 2023-07-31
-- Goal: generate "luacheck_config.lua" for using with LuaCheck
-- Run Far w/out macros (far /m) to avoid contamination of globals then run this file from LuaMacro

assert(type(_G.mf) == "table", "Must be run by plugin LuaMacro")

local osWindows = string.sub(package.config, 1, 1) == "\\"

local exports = osWindows and [[
  "Analyse", "ClosePanel", "Compare", "Configure", "DeleteFiles", "ExitFAR",
  "GetContentData", "GetContentFields", "GetFiles", "GetFindData",
  "GetGlobalInfo", "GetOpenPanelInfo", "GetPluginInfo", "MakeDirectory", "OnError", "Open",
  "ProcessConsoleInput", "ProcessDialogEvent", "ProcessEditorEvent", "ProcessEditorInput",
  "ProcessHostFile", "ProcessPanelEvent", "ProcessPanelInput", "ProcessSynchroEvent",
  "ProcessViewerEvent", "PutFiles", "SetDirectory", "SetFindList", "SetStartupInfo",
]] or [[
  "ClosePlugin", "Compare", "Configure", "DeleteFiles", "ExitFAR", "GetCustomData",
  "GetFiles", "GetFindData", "GetOpenPluginInfo", "GetPluginInfo", "GetVirtualFindData",
  "MakeDirectory", "OnError", "OpenCommandLine", "OpenDialog", "OpenFilePlugin",
  "OpenFromMacro", "OpenPlugin", "OpenShortcut", "ProcessConsoleInput", "ProcessDialogEvent",
  "ProcessEditorEvent", "ProcessEditorInput", "ProcessEvent", "ProcessHostFile", "ProcessKey",
  "ProcessViewerEvent", "PutFiles", "SetDirectory", "SetFindList",
]]

local globals_luafar = osWindows and
  { "bit64", "editor", "far", "_luaplug", "panel", "regex", "utf8", "viewer", "win", }
  or
  { "actl", "bit64", "editor", "far", "_luaplug", "panel", "regex", "utf8", "viewer", "win", }

local globals_luamacro = {
  "Keys", "akey", "band", "bnot", "bor", "bxor", "eval", "exit", "lshift", "mmode", "msgbox",
  "print", "prompt", "rshift",
  "Macro",  "Event",  "MenuItem",  "CommandLine",  "PanelModule",  "ContentColumns",
  "NoMacro","NoEvent","NoMenuItem","NoCommandLine","NoPanelModule","NoContentColumns",
  "_filename",
  "APanel", "Area", "BM", "CmdLine", "Dlg", "Drv", "Editor", "Far", "Help", "Menu", "Mouse",
  "Object", "PPanel", "Panel", "Plugin", "Viewer", "mf",
}

local Tt = {}
local Insert = function(s) table.insert(Tt,s) end
local function NoCaseCmp(a,b) return a:lower() < b:lower() end

local function ProcessTable (Tbl, Name, Level)
  Level = (Level or 0) + 1
  Insert( ('\n[%-10s] = {'):format('"'..Name..'"') )
  Insert("fields = {")
  local arr = {} -- used for sorting (good for visual compare)
  for k in pairs(Tbl) do arr[#arr+1]=k end
  table.sort(arr, NoCaseCmp)
  for _,v in ipairs(arr) do
    if type(Tbl[v])=="table" then
      if not (Level==1 and v=="properties") then
        ProcessTable(Tbl[v],v,Level)
      end
    else
      Insert( ('"%s";'):format(v) )
    end
  end
  if Level==1 and type(Tbl.properties) == "table" then
    local props = Tbl.properties
    arr = {}
    for k in pairs(props) do arr[#arr+1]=k end
    table.sort(arr, NoCaseCmp)
    for _,v in ipairs(arr) do
      if type(v)=="table" then ProcessTable(props[v],v,Level)
      else Insert( ('"%s";'):format(v) )
      end
    end
  end
  Insert("};")
  Insert("};")
end

local function Generate (outname)
  assert(outname, "output file not specified")
  local fp = assert( io.open(outname, "w") )

  Insert("local luafar = {")
  Insert("globals = {")
  Insert("export = {")
  Insert("fields = {")
  Insert(exports)
  Insert("};")
  Insert("};")
  Insert("};")

  Insert("read_globals = {")
  table.sort(globals_luafar, NoCaseCmp)
  for _,name in ipairs(globals_luafar) do
    if type(_G[name])=="table" then ProcessTable(_G[name], name)
    else Insert( ('"%s";'):format(name) )
    end
  end
  Insert("};")
  Insert("};")

  Insert("\n\n")
  Insert("local luamacro = {")
  Insert("read_globals = {")
  table.sort(globals_luamacro, NoCaseCmp)
  for _,name in ipairs(globals_luamacro) do
    if type(_G[name])=="table" then ProcessTable(_G[name], name)
    else Insert( ('"%s";'):format(name) )
    end
  end
  Insert("};")
  Insert("};")
  Insert("\n\n")
  Insert("return { luafar=luafar; luamacro=luamacro; }")
  local str = table.concat(Tt)
  fp:write(str, "\n")
  fp:close()
end

return Generate
