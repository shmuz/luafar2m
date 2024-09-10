-- RESearch.Grep.lua
-- v1.4.2.1
-- Comfortable Grep text from files by search pattern to editor
-- Actions:
-- 1. Grep:  Goto this line in this file
-- 2. Grep:  Save this line in this file
-- 3. Grep:  Save all lines in this file
-- 4. Grep:  Save all lines in all files
-- Required: plugin RESearch or LFSearch
-- Keys: AltG
-- Url: https://forum.ru-board.com/topic.cgi?forum=5&topic=49572&start=2600#19
-- Author's Github repository: https://github.com/z0hm/far-scripts

local MacroKey = "AltG"

local F = far.Flags
local EFlags = bit64.bor(F.EF_NONMODAL, F.EF_IMMEDIATERETURN, F.EF_OPENMODE_USEEXISTING, F.EF_DISABLEHISTORY)
local LinePattern = '^(%d-)[-:](.+)$'

local function OpenEditor(fname, line, col)
  return editor.Editor(fname,nil,nil,nil,nil,nil,EFlags,line,col)
end

local function GetFileName(l)
  -- [1] /home/shmuel/luafar2m/_build/install/lf4ed/plug/wrap.lua : 3
  local s = l:match("^%[%d+%] (.*)")
  if s then
    return s:match("(.*) : %d+$") or s
  end
end

local function GInfo()
  local ei = editor.GetInfo()
  local y,x,p = ei.CurLine, ei.CurPos, ei.LeftPos
  local l,i,f = editor.GetString(nil,y).StringText, y, nil
  local n,s = l:match(LinePattern)
  for j = ei.CurLine,1,-1 do
    f = GetFileName(editor.GetString(nil,j).StringText)
    if f then i = j; break; end
  end
  return {
    CurLine     = y;
    CurPos      = x;
    FNameLNum   = i;
    LeftPos     = p;
    TargetFName = f;
    TargetLNum  = n;
    TargetLStr  = s;
  }
end

local function FileSave(t)
  OpenEditor(t.filename)
  for _, line in ipairs(t) do
    local StringEOL = editor.GetString(nil, line.y).StringEOL
    editor.SetString(nil, line.y, line.s, StringEOL)
  end
  if not editor.SaveFile() then
    far.Message(t.filename, "Warning! File is not saved - blocked?")
  else
    editor.Quit()
  end
end

Macro {
  description="Grep:  Goto this line in this file";
  area="Editor"; key=MacroKey; filemask="*.tmp";
  action=function()
    local inf = GInfo()
    if inf.TargetFName then
      local n,x,p = inf.TargetLNum, inf.CurPos, inf.LeftPos
      if n then
        OpenEditor(inf.TargetFName, tonumber(n), x-#n-1)
        editor.SetPosition(nil, tonumber(n), x-#n-1, nil, nil, p-#n)
      else
        OpenEditor(inf.TargetFName,1,1)
      end
    end
  end;
}

Macro {
  description="Grep:  Save this line in this file";
  area="Editor"; key=MacroKey; filemask="*.tmp";
  action=function()
    local inf = GInfo()
    local n,s,x = inf.TargetLNum, inf.TargetLStr, inf.CurPos
    if inf.TargetFName and n then
      OpenEditor(inf.TargetFName, tonumber(n), x-#n-1)
      editor.SetString(nil,n,s)
      if not editor.SaveFile() then
        far.Message(inf.TargetFName, "Warning! File is not saved - blocked?")
      else
        editor.Quit()
      end
    end
  end;
}

Macro {
  description="Grep:  Save all lines in this file";
  area="Editor"; key=MacroKey; filemask="*.tmp";
  action=function()
    local inf = GInfo()
    if inf.TargetFName then
      local t = { filename=inf.TargetFName }
      for j=inf.FNameLNum+1, editor.GetInfo().TotalLines do
        local l=editor.GetString(nil,j).StringText
        local y,s = l:match(LinePattern)
        if y then
          table.insert(t, {y=y; s=s})
        elseif GetFileName(l) then
          break
        end
      end
      if t[1] then FileSave(t) end
    end
  end;
}

Macro {
  description="Grep:  Save all lines in all files";
  area="Editor"; key=MacroKey; filemask="*.tmp";
  action=function()
    local t = {}
    local info = editor.GetInfo()
    for j=1,info.TotalLines do
      local l = editor.GetString(info.EditorID, j).StringText
      local f = GetFileName(l)
      if f then
        if t[1] then
          FileSave(t)
          t = {}
        end
        t.filename = f
      elseif t.filename then
        local y,s = l:match(LinePattern)
        if y then
          table.insert(t, {y=y; s=s})
        end
      end
    end
    if t[1] then FileSave(t) end
  end;
}
