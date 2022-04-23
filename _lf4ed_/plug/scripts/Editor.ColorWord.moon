-- Original author: Vadim Yegorov (aka zg)
-- https://forum.farmanager.com/viewtopic.php?p=134436#p134436

-- Options
OptCaseSensitive=true
-- End of options

F=far.Flags
band,bor,lshift,rshift = bit.band, bit.bor, bit.lshift, bit.rshift
color = far.AdvControl(F.ACTL_GETCOLOR, F.COL_EDITORTEXT)
color = bor lshift(band(color,0xF),4), rshift(color,4)
words={}

-- Color Word Under Cursor
AddToMenu "e", nil, "F5", ->
  ei=editor.GetInfo!
  id=ei.EditorID
  if words[id] then words[id]=nil
  else
    pos=ei.CurPos
    line=editor.GetString!.StringText
    if pos<=line\len()+1
      slab=pos>1 and line\sub(1,pos-1)\match('[%w_]+$') or ""
      tail=line\sub(pos)\match('^[%w_]+') or ""
      if slab~="" or tail~="" then words[id]=OptCaseSensitive and slab..tail or (slab..tail)\lower!
  editor.Redraw!

AddEvent "EditorEvent", (event,param) ->
  id=editor.GetInfo().EditorID
  if event==F.EE_REDRAW
    if words[id]
      ei=editor.GetInfo id
      start,finish=ei.TopScreenLine,math.min ei.TopScreenLine+ei.WindowSizeY,ei.TotalLines
      for ii=start,finish
        line,pos=editor.GetString(ii).StringText,1
        while true
          jj,kk,curr=line\find("([%w_]+)",pos)
          if not jj then break
          if not OptCaseSensitive then curr=curr\lower!
          if curr==words[id] then editor.AddColor ii,jj,kk,color
          pos=kk+1
  elseif event==F.EE_CLOSE then words[id]=nil
