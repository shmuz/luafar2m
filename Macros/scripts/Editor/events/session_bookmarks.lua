------------------------------------------------------------------------------------------------
-- Started              : 2016-11-11
-- Author               : Shmuel Zeigerman
-- Portability          : far3 (>= 4834), far2m
-- Far plugin           : Either LuaMacro or LF4Ed (?)
-- Published            : http://forum.farmanager.com/viewtopic.php?p=141574#p141574
------------------------------------------------------------------------------------------------

local F = far.Flags
if not F.ECF_AUTODELETE then
  return
end
local colorFlags = F.ECF_AUTODELETE + (F.ECF_TABMARKFIRST or 0) +
    (F.ECF_TABMARKCURRENT or 0) -- luacheck: ignore 143 (undefined field)

-------- Settings --------
local Color = 0xCF
local ColorPriority = 500
--------------------------

Event {
  description="EE_REDRAW: session Bookmarks";
  group="EditorEvent";
  action=function(EditorId, Event, Param)
    if Event==F.EE_REDRAW then
      local Arr = editor.GetSessionBookmarks(EditorId)
      if Arr and Arr[1] then
        local Info = editor.GetInfo(EditorId)
        for _,v in ipairs(Arr) do
          editor.AddColor(EditorId,v.Line,Info.LeftPos,Info.LeftPos,colorFlags,Color,ColorPriority)
        end
      end
    end
  end
}

local function SetPosition(bm)
  editor.SetPosition(nil, bm.Line, bm.Cursor, nil, bm.Line-bm.ScreenLine+1, bm.LeftPos)
end

local function Goto(forward)
  local Info = editor.GetInfo()
  local Arr = editor.GetSessionBookmarks()
  if not (Info and Arr and Arr[1]) then return end
  for i,v in ipairs(Arr) do v.index=i end
  table.insert(Arr, {Line=Info.CurLine + (forward and 0.5 or -0.5)})
  table.sort(Arr, function(a,b) return a.Line < b.Line end)
  for i,v in ipairs(Arr) do
    if not v.index then
      local bm = Arr[ forward and (i<#Arr and i+1 or 1) or (i>1 and i-1 or #Arr) ]
      SetPosition(bm)
      break
    end
  end
end

local function BookmarksMenu()
  local Info = editor.GetInfo()
  local properties = {Title="Bookmarks", Bottom="Keys: Enter Del Esc", Flags=F.FMENU_AUTOHIGHLIGHT+F.FMENU_WRAPMODE}
  local bkeys = {{BreakKey="DELETE"}}
  while Info do
    local Arr = editor.GetSessionBookmarks()
    if not Arr then break end
    for i,v in ipairs(Arr) do v.index=i end
    table.sort(Arr, function(a,b) return a.Line < b.Line end)
    local items = {}
    for i,v in ipairs(Arr) do
      local ch = i<10 and i or i<36 and string.char(i+55)
      ch =  (ch and ch..". " or "") .. editor.GetString(nil,v.Line,3)
      items[i] = { text=ch; bm=v }
    end
    local v,pos = far.Menu(properties, items, bkeys)
    if not v then break end
    if v.BreakKey=="DELETE" then
      if items[pos] then editor.DeleteSessionBookmark(nil, items[pos].bm.index) end
    else
      SetPosition(v.bm); break
    end
  end
end

Macro {
  id="DF2550D0-D97B-4209-ADCC-66545A65B4F9";
  description="Session Bookmarks: add or delete a bookmark";
  area="Editor"; key="ShiftF9";
  action=function()
    local Info = editor.GetInfo()
    local Arr = editor.GetSessionBookmarks()
    if not (Info and Arr) then return end
    local deleted
    for i,v in ipairs(Arr) do
      if v.Line == Info.CurLine then editor.DeleteSessionBookmark(nil,i); deleted=true; end
    end
    if not deleted then editor.AddSessionBookmark() end
  end;
}
Macro {
  id="028A8FB3-4566-4666-931B-793DB697A13D";
  description="Session Bookmarks: clear all bookmarks";
  area="Editor"; key="CtrlShiftF9";
  action=function() editor.ClearSessionBookmarks() end;
}
Macro {
  id="AA75EA37-72A3-43E9-B7CE-DC3249789E61";
  description="Session Bookmarks: next bookmark";
  area="Editor"; key="ShiftF6";
  action=function() Goto(true) end;
}
Macro {
  id="383239DE-C327-4477-A6FD-85761F422473";
  description="Session Bookmarks: previous bookmark";
  area="Editor"; key="CtrlF6";
  action=function() Goto(false) end;
}
Macro {
  id="AD2F4DC2-F059-4462-80B0-090303429152";
  description="Session Bookmarks: menu";
  area="Editor"; key="F9";
  action=BookmarksMenu;
}
