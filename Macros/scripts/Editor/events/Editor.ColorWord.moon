-- Original author: Vadim Yegorov (aka zg)
-- https://forum.farmanager.com/viewtopic.php?p=134436#p134436

-- Options
OptCaseSensitive=false
-- End of options

F=far.Flags
band,bor,lshift,rshift = bit64.band, bit64.bor, bit64.lshift, bit64.rshift
color = actl.GetColor "COL_EDITORTEXT"
color = bor lshift(band(color,0xF),4), rshift(color,4)
words={}

Macro
  area:"Editor"
  key:"F5"
  description:"Highlight Word Under Cursor"
  action:->
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

Event
  description:"Highlight Word Under Cursor"
  group:"EditorEvent"
  action:(id,event,param)->
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
            if curr==words[id] then editor.AddColor ii,jj,kk,"ECF_AUTODELETE",color
            pos=kk+1
    elseif event==F.EE_CLOSE then words[id]=nil
