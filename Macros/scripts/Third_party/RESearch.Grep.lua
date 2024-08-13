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

local F = far.Flags
local EFlags = bit64.bor(F.EF_NONMODAL,F.EF_IMMEDIATERETURN,F.EF_OPENMODE_USEEXISTING)

local function GetFileName(l)
  -- [1] /home/shmuel/luafar2m/_build/install/lf4ed/plug/wrap.lua : 3
  return regex.match(l,'^\\[\\d+?\\] (.+?)(?:\\s*:|$)')
end

local function GInfo()
  local ei=editor.GetInfo()
  local y,x,p = ei.CurLine,ei.CurPos,ei.LeftPos
  local l,i,f = editor.GetString(nil,y).StringText,y
  local n,s = l:match('^(%d-)[-:](.+)$')
  repeat
    i,f = i-1,GetFileName(editor.GetString(nil,i).StringText)
  until f or i==-1
  return f,l,y,x,p,n,s,i
end

local function FileSave(t)
  editor.Editor(t[1][1],nil,nil,nil,nil,nil,EFlags)
  for j=2,#t do
    local StringEOL=editor.GetString(nil,t[j][1]).StringEOL
    editor.SetString(nil,t[j][1],t[j][2],StringEOL)
  end
  if not editor.SaveFile() then
    far.Message(t[1][1],"Warning! File is not saved - blocked?")
  else
    editor.Quit()
  end
end

Macro {
  area="Editor"; key="AltG";
  description="Grep:  Goto this line in this file";
  filemask="/\\w+\\.tmp$/i";
  action=function()
    local f,l,y,x,p,n,s = GInfo()
    if f then
      if n then
        editor.Editor(f,nil,nil,nil,nil,nil,EFlags,tonumber(n),x-#n-1)
        editor.SetPosition(nil,tonumber(n),x-#n-1,_,_,p-#n)
      else
        editor.Editor(f,nil,nil,nil,nil,nil,EFlags,1,1)
        editor.SetPosition(nil,1,1)
      end
    end
  end;
}

Macro {
  area="Editor"; key="AltG";
  description="Grep:  Save this line in this file";
  filemask="/\\w+\\.tmp$/i";
  action=function()
    local f,l,y,x,p,n,s = GInfo()
    if n then
      editor.SetPosition(nil,y,x,_,_,p)
      if f then
        editor.Editor(f,nil,nil,nil,nil,nil,EFlags,tonumber(n),x-#n-1)
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
  area="Editor"; key="AltG";
  description="Grep:  Save all lines in this file";
  filemask="/\\w+\\.tmp$/i";
  action=function()
    local t,i = {},select(8,GInfo())
    for j=i,editor.GetInfo().TotalLines do
      local l=editor.GetString(nil,j).StringText
      local y,s = l:match('^(%d-)[-:](.+)$')
      if y and s and #t>=1
      then table.insert(t,{y,s})
      else
        local f=GetFileName(l)
        if f then
          if #t>1 then FileSave(t) t={} break end
          t[1]={f,nil}
        end
      end
    end
    if #t>1 then FileSave(t) end
  end;
}

Macro {
  area="Editor"; key="AltG";
  description="Grep:  Save all lines in all files";
  filemask="/\\w+\\.tmp$/i";
  action=function()
    local t={}
    far.Show(editor.GetInfo().TotalLines)
    for j=1,editor.GetInfo().TotalLines do
      far.Show(j, editor.GetString(nil,j).StringText)
      local l=editor.GetString(nil,j).StringText
      local y,s = l:match('^(%d-)[-:](.+)$')
      if y and s and #t>=1
      then
        table.insert(t,{y,s})
      else
        local f=GetFileName(l)
        if f then
          if #t>1 then FileSave(t) t={} end
          t[1]={f,nil}
        end
      end
    end
    if #t>1 then FileSave(t) end
  end;
}
