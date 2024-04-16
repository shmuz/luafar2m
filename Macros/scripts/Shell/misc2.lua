local SharedKey = "CtrlAltE"

local function ShowDiff (aName)
  local dir = panel.GetPanelDirectory(nil, 1)
  panel.SetPanelDirectory(nil, 1, win.JoinPath(os.getenv("HOME"), aName))
  local file = far.InMyTemp(aName) .. ".diff"
  local fp = io.popen("git diff >"..file)
  if fp then
    fp:close()
    Plugin.Command(far.GetPluginId(), "edit:[1,1]"..file)
  end
  panel.SetPanelDirectory(nil, 1, dir);
end

Macro {
  description = "git diff: far2m";
  area="Shell"; key=SharedKey; sortpriority=48;
  action=function() ShowDiff("far2m") end;
}

Macro {
  description = "git diff: luafar2m";
  area="Shell"; key=SharedKey; sortpriority=47;
  action=function() ShowDiff("luafar2m") end;
}

Macro {
  description = "git diff: luafar-far2l";
  area="Shell"; key=SharedKey; sortpriority=46.5;
  action=function() ShowDiff("luafar-far2l") end;
}

Macro {
  description = "git diff: scite-config";
  area="Shell"; key=SharedKey; sortpriority=46;
  action=function() ShowDiff("scite-config") end;
}

Macro {
  description = "Generate luacheck_config.lua";
  area="Shell"; key=SharedKey; sortpriority=44;
  action=function()
    local trg = win.JoinPath(os.getenv("FARHOME"), "Plugins/luafar/lua_share/luacheck_config.lua")
    require("far2.luacheck_generate")(trg)
    far.Message("Done")
  end
}

Macro {
  description="Quick search";
  area="Shell"; key="/LAlt\\S/";
  action=function()
    local ch = akey(1):sub(-1)
    Keys("Alt*", ch)
  end;
}

