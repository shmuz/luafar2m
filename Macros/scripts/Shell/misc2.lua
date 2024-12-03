local SharedKey = "CtrlAltE"

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
  id="A7618020-A10A-495F-9A0B-E6446E8C4FE2";
  id="9E3AB982-24A9-4E57-AB62-3D0269E8BD07";
  description = "git diff: far2m";
  area="Shell"; key=SharedKey; sortpriority=48;
  action=function() ShowDiff("far2m") end;
}

Macro {
  id="3A6AB140-F371-427C-83E0-91163C630859";
  id="EB3268DF-FC7B-4547-B884-9D2D96F55D17";
  description = "git diff: luafar2m";
  area="Shell"; key=SharedKey; sortpriority=47;
  action=function() ShowDiff("luafar2m") end;
}

Macro {
  id="EDD8EDEE-3AB9-44F5-A53C-AD56D07EC72C";
  id="9D8FFD00-D334-40B6-B361-E7A97DA3A3DB";
  description = "git diff: luafar-far2l";
  area="Shell"; key=SharedKey; sortpriority=46.5;
  action=function() ShowDiff("luafar-far2l") end;
}

Macro {
  id="8E850BD6-45C8-4A1E-8E2C-A800E995C4E5";
  id="8AF9A67D-25E9-472A-9A04-D3D5525A510A";
  description = "git diff: scite-config";
  area="Shell"; key=SharedKey; sortpriority=46;
  action=function() ShowDiff("scite-config") end;
}

Macro {
  id="5613CA58-E45D-4231-8860-0826212298CA";
  id="CFA70B2D-F2E3-4F09-B4B1-885B03C81F4C";
  description = "Generate luacheck_config.lua";
  area="Shell"; key=SharedKey; sortpriority=44;
  action=function()
    local trg = far.GetMyHome().."/luacheck_config.lua"
    require("far2.luacheck_generate")(trg)
    far.Message("Done")
  end
}

Macro {
  id="6F4A2EBD-FE21-4417-8AA7-451FDFB3B8F4";
  id="A7B3D046-A0A1-4EB0-86FB-02A3DEE7A283";
  description="Quick search";
  area="Shell"; key="/LAlt\\S/";
  action=function()
    local ch = akey(1):sub(-1)
    Keys("Alt*", ch)
  end;
}

