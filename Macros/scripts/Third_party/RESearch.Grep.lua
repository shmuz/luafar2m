-- RESearch.Grep.lua
-- v1.4.2.1
-- Comfortable Grep text from files by search pattern to editor
-- ![RESearch Grep](http://i.piccy.info/i9/23f14ef428e4f1d2f1fc1937da2a549c/1442294013/13901/950058/1.png)
-- Press AltG, MacroBrowserAlt.lua file will be opened in the editor and the cursor will be set to this position on hDlg.
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

local function OpenEditor(fname, line, col)
  return editor.Editor(fname,nil,nil,nil,nil,nil,EFlags,line,col)
end

local function GetFileName(l)
  -- [1] /home/shmuel/luafar2m/_build/install/lf4ed/plug/wrap.lua : 3
  return regex.match(l,'^\\[\\d+?\\] (.+?)(?: : \\d+)?$')
end

local function GInfo()
  local ei=editor.GetInfo()
  local y,x,p = ei.CurLine, ei.CurPos, ei.LeftPos
  local l,i,f = editor.GetString(nil,y).StringText, y, nil
  local n,s = l:match('^(%d-)[-:](.+)$')
  for j = ei.CurLine,1,-1 do
    f = GetFileName(editor.GetString(nil,j).StringText)
    if f then i = j; break; end
  end
  return f,l,y,x,p,n,s,i
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
    local f,l,y,x,p,n = GInfo()
    if f then
      if n then
        OpenEditor(f, tonumber(n), x-#n-1)
        editor.SetPosition(nil, tonumber(n), x-#n-1, nil, nil, p-#n)
      else
        OpenEditor(f,1,1)
        editor.SetPosition(nil,1,1)
      end
    end
  end;
}

Macro {
  description="Grep:  Save this line in this file";
  area="Editor"; key=MacroKey; filemask="*.tmp";
  action=function()
    local f,l,y,x,p,n,s = GInfo()
    if n then
      editor.SetPosition(nil,y,x,nil,nil,p)
      if f then
        OpenEditor(f, tonumber(n), x-#n-1)
        editor.SetString(nil,n,s)
        if not editor.SaveFile() then
          far.Message(f,"Warning! File is not saved - blocked?")
        else
          editor.Quit()
        end
      end
    end
  end;
}

Macro {
  description="Grep:  Save all lines in this file";
  area="Editor"; key=MacroKey; filemask="*.tmp";
  action=function()
    local t,i = {},select(8,GInfo())
    for j=i,editor.GetInfo().TotalLines do
      local l=editor.GetString(nil,j).StringText
      local y,s = l:match('^(%d-)[-:](.+)$')
      if y and s and t.filename then
        table.insert(t, {y=y; s=s})
      else
        local f = GetFileName(l)
        if f then
          if t[1] then
            break
          end
          t.filename = f
        end
      end
    end
    if t[1] then FileSave(t) end
  end;
}

Macro {
  description="Grep:  Save all lines in all files";
  area="Editor"; key=MacroKey; filemask="*.tmp";
  action=function()
    local t={}
    for j=1,editor.GetInfo().TotalLines do
      local l=editor.GetString(nil,j).StringText
      local y,s = l:match('^(%d-)[-:](.+)$')
      if y and s and t.filename then
        table.insert(t, {y=y; s=s})
      else
        local f = GetFileName(l)
        if f then
          if t[1] then FileSave(t); t={}; end
          t.filename = f
        end
      end
    end
    if t[1] then FileSave(t) end
  end;
}
