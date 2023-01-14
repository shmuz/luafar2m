-- started    : 2011-02-20
-- far2l port : 2023-01-11

local F=far.Flags

local breakkeys = {
  { BreakKey="RETURN", command="load",       success="Loaded",       fail="Failed to load" },
  { BreakKey="INSERT", command="forcedload", success="Force-loaded", fail="Failed to force-load" },
  { BreakKey="DELETE", command="unload",     success="Unloaded",     fail="Failed to unload" },
}

local properties = {
  Title="Load/Unload Plugins", Bottom="Enter=load, Ins=force-load, Del=unload",
}

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
        text = v.PInfo.PluginMenu[1] or v.PInfo.PluginConfig[1] or v.ModuleName:match("[^/]+$");
        info = v;
        checked  = loaded and "+" or not v.handle and "-" or nil;
      }
    end

    -- Sort menu items alphabetically.
    table.sort(items,
      function(a,b) return win.CompareString(a.text, b.text, nil, "cS") < 0 end)

    local item, pos = far.Menu(properties, items, breakkeys)
    if not item then break end
    properties.SelectIndex = pos
    local bItem = item.BreakKey and item or breakkeys[1]
    local mItem = items[pos]
    local result
    if bItem.command == "load" then
      mItem.handle = far.LoadPlugin("PLT_PATH", mItem.info.ModuleName)
      result = mItem.handle and true
      mItem.grayed = not result
    elseif bItem.command == "forcedload" then
      mItem.handle = far.ForcedLoadPlugin("PLT_PATH", mItem.info.ModuleName)
      result = mItem.handle and true
      mItem.grayed = not result
    elseif bItem.command == "unload" then
      if mItem.info.handle then
        if far.GetPluginId() ~= mItem.info.GInfo.SysID then
          far.UnloadPlugin(mItem.info.handle)
        else
          mf.postmacro(far.Message, "I'm running this script and cannot unload myself !!!", mItem.text, nil, "w")
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

