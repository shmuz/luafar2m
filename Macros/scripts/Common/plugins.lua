-- started    : 2011-02-20
-- far2m port : 2023-01-11
-- forum      : https://forum.farmanager.com/viewtopic.php?t=13263

-- Settings
local macrokey     = "AltShiftF11"
local lua_explorer = "far2.lua_explorer"
-- /Settings

local OsWindows = package.config:sub(1,1)=="\\"
local F=far.Flags

local Data = {
  { BreakKey="F3";         command="showinfo";        help="Show plugin info";      os="lw"; },
  { BreakKey="Enter";      command="load";            help="Load plugin";           os="lw"; },
  { BreakKey="Ins";        command="forcedload";      help="Forced load plugin";    os="lw"; },
  { BreakKey="Del";        command="unload";          help="Unload plugin";         os="lw"; },
  { BreakKey="F8";         command="clearcache";      help="Clear plugin's cache";  os="l";  },
  {                                                                                 os="lw"; }, --help separator
  { BreakKey="CtrlEnter";  command="load_all";        help="Load all";              os="lw"; },
  { BreakKey="CtrlIns";    command="forcedload_all";  help="Forced load all";       os="lw"; },
  { BreakKey="CtrlDel";    command="unload_all";      help="Unload all";            os="lw"; },
  { BreakKey="F1";         command="showhelp";        help="Show help";             os="lw"; },
  { BreakKey="F24";        command=nil;               help=nil;                     os="lw"; },
}

local breakkeys = {}
local helpmessage = {}

for _,v in ipairs(Data) do
  if v.os:find(OsWindows and "w" or "l") then
    if v.BreakKey then
      if v.help then
        table.insert(helpmessage, ("%-16s%s"):format(v.BreakKey, v.help))
      end
      table.insert(breakkeys,v)
    else
      table.insert(helpmessage, "\1")
    end
  end
end
helpmessage = table.concat(helpmessage, "\n")

local function IsThisPlugin(pluginfo)
  if OsWindows then
    return export.GetGlobalInfo().Guid == pluginfo.GInfo.Guid --luacheck: no global
  else
    return far.GetPluginId() == pluginfo.GInfo.SysID --luacheck: no global
  end
end

local properties = {
  Title="Load/Unload Plugins", Bottom="F1 - help",
}

local last_module

local function GetFileName(name)
  return name:match(OsWindows and "[^\\]+$" or "[^/]+$");
end

local function SpecialMessage(text, title, flags)
  mf.postmacro(function()
      far.Message(text, title, nil, flags)
      Keys("F24") -- force rereading the plugins' data after the dialog was shown
    end)
end

local function Main()
  -- Get space for this script's data. Kept alive between the script's invocations.
  local ScriptId = "263e6208-e5b2-4bf7-8953-59da207279c7"
  local first
  if not rawget(_G, ScriptId) then
    rawset(_G, ScriptId, {})
    first = true
  end
  local Plugins = _G[ScriptId]

  if first then
    for _, handle in ipairs(far.GetPlugins()) do
      local info = far.GetPluginInformation(handle)
      info.handle = handle
      Plugins[info.ModuleName] = info
    end
  end

  while true do
    -- Update plugins' data with the fresh info.
    for modname,oldinfo in pairs(Plugins) do
      local handle = far.FindPlugin("PFM_MODULENAME", modname)
      if handle then
        local info = far.GetPluginInformation(handle)
        info.handle = handle
        Plugins[modname] = info
      else
        oldinfo.handle = nil
      end
    end

    -- Create menu items.
    local items = {}
    for _,v in pairs(Plugins) do
      local loaded = v.handle and (0 ~= bit64.band(v.Flags, F.FPF_LOADED))
      items[#items+1] = {
        text = (v.GInfo.Title ~= "" and v.GInfo.Title)
               or v.PInfo.PluginConfig.Strings[1]
               or v.PInfo.PluginMenu.Strings[1]
               or GetFileName(v.ModuleName);
        info = v;
        checked = loaded and "+" or not v.handle and "-" or nil;
      }
    end

    -- Sort menu items alphabetically.
    table.sort(items, function(a,b) return win.CompareString(a.text, b.text, nil, "cS") < 0 end)

    -- Find selection by module name (as item text may change after clearing plugin's cache)
    for i,v in ipairs(items) do
      if v.info.ModuleName == last_module then properties.SelectIndex=i; break; end
    end

    -- Run the menu
    local item, pos = far.Menu(properties, items, breakkeys)
    if not item then break end

    local command = item.BreakKey and item.command or "load"
    local mItem = items[pos]
    last_module = mItem.info.ModuleName

    if command == "showinfo" then
      if mItem.info.handle then
        local info = far.GetPluginInformation(mItem.info.handle)
        if info then
          require (lua_explorer)(info, "info")
        end
      end

    elseif command == "load" then
      far.LoadPlugin("PLT_PATH", last_module)

    elseif command == "forcedload" then
      far.ForcedLoadPlugin("PLT_PATH", last_module)

    elseif command == "unload" then
      if mItem.info.handle then
        if not IsThisPlugin(mItem.info) then
          far.UnloadPlugin(mItem.info.handle)
        else
          SpecialMessage("I'm running this script and cannot unload myself !!!", mItem.text, "w")
        end
      end

    elseif command == "clearcache" then
      far.ClearPluginCache("PLT_PATH", last_module) --luacheck: no global

    elseif command == "load_all" then
      for _,v in ipairs(items) do
        far.LoadPlugin("PLT_PATH", v.info.ModuleName)
      end

    elseif command == "forcedload_all" then
      for _,v in ipairs(items) do
        far.ForcedLoadPlugin("PLT_PATH", v.info.ModuleName)
      end

    elseif command == "unload_all" then
      for _,v in ipairs(items) do
        if v.info.handle then
          if not IsThisPlugin(v.info) then
            far.UnloadPlugin(v.info.handle)
          end
        end
      end

    elseif command == "showhelp" then
      SpecialMessage(helpmessage, "Help", "l")

    end
  end
end

Macro {
  id="B1C9D1B5-E4DE-4CEE-8766-CA8DA5FAE654";
  id="2FA3EDCC-4C53-43C3-8474-2433BF29EF02";
  description="Plugins Control";
  area="Common"; key=macrokey;
  action=Main;
}

