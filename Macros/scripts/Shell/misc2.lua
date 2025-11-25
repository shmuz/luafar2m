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

Macro {
  id="B25C0EBB-6412-4317-A197-33D40F9FB50C";
  description="diff: jump to source"; -- started: 2025-11-25
  area="Editor"; key="CtrlShiftG"; filemask="*.diff";
  priority=60; -- suppress "jump from Grep results" binded to the same key
  action=function()
    local EI = editor.GetInfo()
    local rootname = win.JoinPath(far.GetMyHome(), "repos", EI.FileName:match("([^/]+)%.[^.]*$"))
    local fname, lnum
    local minuses = 0
    for ln = EI.CurLine,1,-1 do
      local str = editor.GetString(nil,ln,3)
      local _minus = str:match("^%-")
      local _lnum  = str:match("^@@.-%+(%d+)")
      local _fname = str:match("^%+%+%+%s+b/(.+)")
      if _minus then minuses = minuses + 1 end
      if _lnum then lnum = tonumber(_lnum) + EI.CurLine - ln - 1 - minuses; end
      if _fname then fname = _fname; break; end
    end
    if not (fname and lnum) then return end
    local flags = "EF_NONMODAL EF_IMMEDIATERETURN EF_DISABLEHISTORY"
    fname = win.JoinPath(rootname, fname)
    editor.Editor(fname, nil,nil,nil,nil,nil, flags, lnum)
  end;
}
