-- http://forum.farmanager.com/viewtopic.php?p=141574#p141574

-------- Settings --------
local Color = 0xCF
--------------------------

local F = far.Flags
local colorFlags = F.ECF_AUTODELETE

Event {
  description="EE_REDRAW: session Bookmarks";
  group="EditorEvent";
  action=function(EditorId, Event, Param)
    if Event==F.EE_REDRAW then
      local Arr = editor.GetStackBookmarks()
      if Arr and Arr[1] then
        local Info = editor.GetInfo()
        for _,v in ipairs(Arr) do
          editor.AddColor(v.Line,Info.LeftPos,Info.LeftPos,Color,colorFlags)
        end
      end
    end
  end
}

local function SetPosition(bm, info) -- info is currently not used
  editor.SetPosition(bm.Line, bm.Cursor, nil, bm.Line-bm.ScreenLine+1, bm.LeftPos)
end

local function Goto(forward)
  local Info = editor.GetInfo()
  local Arr = editor.GetStackBookmarks()
  if not (Info and Arr and Arr[1]) then return end
  for i,v in ipairs(Arr) do v.index=i end
  table.insert(Arr, {Line=Info.CurLine + (forward and 0.5 or -0.5)})
  table.sort(Arr, function(a,b) return a.Line < b.Line end)
  for i,v in ipairs(Arr) do
    if not v.index then
      local bm = Arr[ forward and (i<#Arr and i+1 or 1) or (i>1 and i-1 or #Arr) ]
      SetPosition(bm, Info)
      break
    end
  end
end

local function BookmarksMenu()
  local Info = editor.GetInfo()
  local properties = {Title="Bookmarks", Bottom="Keys: Enter Del Esc", Flags=F.FMENU_AUTOHIGHLIGHT+F.FMENU_WRAPMODE}
  local bkeys = {{BreakKey="DELETE"}}
  while Info do
    local Arr = editor.GetStackBookmarks() or {}
    for i,v in ipairs(Arr) do v.index=i end
    table.sort(Arr, function(a,b) return a.Line < b.Line end)
    local items = {}
    for i,v in ipairs(Arr) do
      local ch = i<10 and i or i<36 and string.char(i+55)
      ch =  (ch and ch..". " or "") .. editor.GetString(v.Line,2)
      items[i] = { text=ch; bm=v }
    end
    local v,pos = far.Menu(properties, items, bkeys)
    if not v then break end
    if v.BreakKey=="DELETE" then
      if items[pos] then editor.DeleteStackBookmark(items[pos].bm.index) end
    else
      SetPosition(v.bm, Info); break
    end
  end
end

Macro {
  description="Session Bookmarks: add or delete a bookmark";
  area="Editor"; key="ShiftF9";
  action=function()
    local Info = editor.GetInfo()
    local Arr = editor.GetStackBookmarks() or {}
    local deleted
    for i,v in ipairs(Arr) do
      if v.Line == Info.CurLine then editor.DeleteStackBookmark(i); deleted=true; end
    end
    if not deleted then editor.AddStackBookmark() end
  end;
}
Macro {
  description="Session Bookmarks: clear all bookmarks";
  area="Editor"; key="CtrlShiftF9";
  action=function() editor.ClearStackBookmarks() end;
}
Macro {
  description="Session Bookmarks: next bookmark";
  area="Editor"; key="ShiftF6";
  action=function() Goto(true) end;
}
Macro {
  description="Session Bookmarks: previous bookmark";
  area="Editor"; key="CtrlF6";
  action=function() Goto(false) end;
}
Macro {
  description="Session Bookmarks: menu";
  area="Editor"; key="F9";
  action=BookmarksMenu;
}
