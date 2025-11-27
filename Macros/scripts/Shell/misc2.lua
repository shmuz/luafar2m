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

-- Search for an item having the typed char the most close to name's beginning
Macro {
  id="6F4A2EBD-FE21-4417-8AA7-451FDFB3B8F4";
  description="Quick search";
  area="Shell"; key="/LAlt\\S/";
  action=function()
    local ch = akey(1):sub(-1)
    local PI = panel.GetPanelInfo(nil,1)
    local patt = ("[%s%s]"):format(ch:upper(), ch:lower())
    local pos, offs
    for i = 0, PI.ItemsNumber-1 do
      local j = 1 + (i + PI.CurrentItem - 1) % PI.ItemsNumber
      local fname = Panel.Item(0,j,0)
      local fpos = fname:find("[^/]+$") -- to work in TmpPanel too
      local from = fname:find(patt, fpos)
      if from then
        if pos == nil or from < offs then
          pos, offs = j, from
        end
        if from == 1 then break end
      end
    end
    if pos then Panel.SetPosIdx(0, pos) end
    Keys("Alt*", ch:lower())
  end;
}

Macro {
  id="B25C0EBB-6412-4317-A197-33D40F9FB50C";
  description="diff: jump to source"; -- started: 2025-11-25
  area="Editor"; key="CtrlShiftG"; filemask="*.diff";
  priority=60; -- suppress "jump from Grep results" binded to the same key
  action=function()
    local EI = editor.GetInfo()
    local fname, lnum
    local minuses = 0
    for ln = EI.CurLine,1,-1 do
      local str = editor.GetString(nil,ln,3)
      if not lnum then
        local _lnum  = str:match("^@@.-%+(%d+)")
        if _lnum then
          lnum = tonumber(_lnum) + EI.CurLine - ln - 1 - minuses
        end
        local _minus = str:match("^%-")
        if _minus then
          minuses = minuses + 1
        end
      end
      fname = str:match("^%+%+%+%s+b/(.+)")
      if fname then break; end
    end
    if fname and lnum then
      local flags = "EF_NONMODAL EF_IMMEDIATERETURN EF_DISABLEHISTORY"
      fname = win.JoinPath(far.GetMyHome(), "repos", EI.FileName:match("([^/]+)%.[^.]*$"), fname)
      editor.Editor(fname, nil,nil,nil,nil,nil, flags, lnum)
    end
  end;
}
