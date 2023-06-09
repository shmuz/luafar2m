-- started    : 2011-02-20
-- far2m port : 2023-01-11

local OsWindows = package.config:sub(1,1)=="\\"
local F=far.Flags

local breakkeys = {
  { BreakKey="Enter";    command="load";       },
  { BreakKey="Ins";      command="forcedload"; },
  { BreakKey="Del";      command="unload";     },
  { BreakKey="CtrlDel";  command="clearcache"; },
  { BreakKey="F3";       command="showinfo";   },
}

local properties = {
  Title="Load/Unload Plugins", Bottom="Enter=load, Ins=force-load, Del=unload",
}

local last_module

local function GetFileName(name)
  return name:match(OsWindows and "[^\\]+$" or "[^/]+$");
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

    if command == "load" then
      far.LoadPlugin("PLT_PATH", last_module)

    elseif command == "forcedload" then
      far.ForcedLoadPlugin("PLT_PATH", last_module)

    elseif command == "clearcache" then
      far.ClearPluginCache("PLT_PATH", last_module)

    elseif command == "unload" then
      if mItem.info.handle then
        if far.GetPluginId() ~= mItem.info.GInfo.SysID then
          far.UnloadPlugin(mItem.info.handle)
        else
          mf.postmacro(far.Message, "I'm running this script and cannot unload myself !!!", mItem.text, nil, "w")
        end
      end

    elseif command == "showinfo" then
      if mItem.info.handle then
        local info = far.GetPluginInformation(mItem.info.handle)
        if info then
          require "far2.lua_explorer" (info, "info")
        end
      end

    end
  end
end

Macro {
  description="Plugins Control";
  area="Common"; key="CtrlShiftF11";
  action=Main;
}

