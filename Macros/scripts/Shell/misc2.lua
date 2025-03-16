local SharedKey = "CtrlAltE"
local SharedId = "F2199E52-FE6D-45C0-B39B-8C06984EBBE1"

local Repos = {
  { dir="far2m";        sortpriority=49; },
  { dir="luafar2m";     sortpriority=48; },
  { dir="luafar-far2l"; sortpriority=47; },
  { dir="scite-config"; sortpriority=46; },
  { dir="mactest";      sortpriority=45; },
}

local function ShowDiff (aName)
  local dir = panel.GetPanelDirectory(nil, 1).Name
  panel.SetPanelDirectory(nil, 1, win.JoinPath(far.GetMyHome(), "repos", aName))
  local file = far.InMyTemp(aName) .. ".diff"
  local fp = io.popen("git diff >"..file)
  if fp then
    fp:close()
    Plugin.Command(far.GetPluginId(), "edit:[1,1]"..file)
  end
  panel.SetPanelDirectory(nil, 1, dir);
end

for _,repo in ipairs(Repos) do
  Macro {
    id=SharedId; key=SharedKey; sortpriority=repo.sortpriority;
    description = "git diff: " .. repo.dir;
    area="Shell";
    action=function() ShowDiff(repo.dir) end;
  }
end

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

