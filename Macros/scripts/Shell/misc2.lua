local SharedKey = "CtrlAltE"

local function ShowDiff (aName)
  local dir = panel.GetPanelDirectory(1)
  panel.SetPanelDirectory(1, os.getenv("HOME").."/"..aName)
  local file = "/tmp/"..aName..".diff"
  local fp = io.popen("git diff >"..file)
  if fp then
    fp:close()
    Plugin.Command(far.GetPluginId(), "edit:[1,1]"..file)
  end
  panel.SetPanelDirectory(1, dir);
end

Macro {
  description = "git diff: far2m";
  area="Shell"; key=SharedKey; sortpriority=48;
  action=function() ShowDiff("far2m") end;
}

Macro {
  description = "git diff: luafar2m";
  area="Shell"; key=SharedKey; sortpriority=46;
  action=function() ShowDiff("luafar2m") end;
}

Macro {
  description = "Generate luacheck_config.lua";
  area="Shell"; key=SharedKey; sortpriority=44;
  action=function()
    local trg = os.getenv("FARHOME").."/Plugins/luafar/lua_share/luacheck_config.lua"
    require("far2.luacheck_generate")(trg)
    far.Message("Done")
  end
}
