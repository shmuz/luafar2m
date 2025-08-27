local SharedKey = "CtrlAltE"
local SharedId = "F2199E52-FE6D-45C0-B39B-8C06984EBBE1"

local function ShowDiff (aName)
  local dir = panel.GetPanelDirectory(nil, 1).Name
  panel.SetPanelDirectory(nil, 1, win.JoinPath(far.GetMyHome(), "repos", aName))
  local file = far.InMyTemp(aName) .. ".diff"
  local fp = io.popen("git diff >"..file)
  if fp then
    fp:close()
    local flags = "EF_NONMODAL EF_IMMEDIATERETURN EF_DISABLEHISTORY EF_DELETEONLYFILEONCLOSE"
    editor.Editor(file,nil,nil,nil,nil,nil,flags)
    editor.SetPosition(nil,1,1)
  end
  panel.SetPanelDirectory(nil, 1, dir);
end

local Repos = {
  { dir="far2m";        spr=49; },
  { dir="luafar2m";     spr=48; },
  { dir="luafar-far2l"; spr=47; },
  { dir="scite-config"; spr=46; },
  { dir="mactest";      spr=45; },
}

for _,repo in ipairs(Repos) do
  Macro {
    id=SharedId; key=SharedKey; sortpriority=repo.spr;
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

