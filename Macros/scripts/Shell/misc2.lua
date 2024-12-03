local SharedKey = "CtrlAltE"
local SharedId = "F2199E52-FE6D-45C0-B39B-8C06984EBBE1"

local function ShowDiff (aName)
  local dir = panel.GetPanelDirectory(nil, 1).Name
  panel.SetPanelDirectory(nil, 1, win.JoinPath(far.GetMyHome(), aName))
  local file = far.InMyTemp(aName) .. ".diff"
  local fp = io.popen("git diff >"..file)
  if fp then
    fp:close()
    Plugin.Command(far.GetPluginId(), "edit:[1,1]"..file)
  end
  panel.SetPanelDirectory(nil, 1, dir);
end

Macro {
  id=SharedId; key=SharedKey; sortpriority=48;
  description = "git diff: far2m";
  area="Shell";
  action=function() ShowDiff("far2m") end;
}

Macro {
  id=SharedId; key=SharedKey; sortpriority=47;
  description = "git diff: luafar2m";
  area="Shell";
  action=function() ShowDiff("luafar2m") end;
}

Macro {
  id=SharedId; key=SharedKey; sortpriority=46.5;
  description = "git diff: luafar-far2l";
  area="Shell";
  action=function() ShowDiff("luafar-far2l") end;
}

Macro {
  id=SharedId; key=SharedKey; sortpriority=46;
  description = "git diff: scite-config";
  area="Shell";
  action=function() ShowDiff("scite-config") end;
}

Macro {
  id=SharedId;  key=SharedKey; sortpriority=44;
  description = "Generate luacheck_config.lua";
  area="Shell";
  action=function()
    local trg = far.GetMyHome().."/luacheck_config.lua"
    require("far2.luacheck_generate")(trg)
    far.Message("Done")
  end
}

Macro {
  id="6F4A2EBD-FE21-4417-8AA7-451FDFB3B8F4";
  description="Quick search";
  area="Shell"; key="/LAlt\\S/";
  action=function()
    local ch = akey(1):sub(-1)
    Keys("Alt*", ch)
  end;
}

