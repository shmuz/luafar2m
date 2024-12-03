Macro {
  id="CAD5CC2C-2BE8-47C4-8308-6F4D6C03194F";
  description="Smart ShiftHome/ShiftEnd";
  area="Editor"; key="ShiftHome ShiftEnd";
  action=function()
    local info, str = editor.GetInfo(), editor.GetString()
    local to
    if akey(1) == "ShiftHome" then
      to = str.StringText:find("%S") or 1
      if to == info.CurPos then to = 1 end
    else
      to = str.StringLength + 1
    end
    editor.SetPosition(nil,nil,to)
    local fr = info.CurPos
    if fr > to then fr,to = to,fr end
    local a1, a2 = str.SelStart, str.SelEnd
    if a1>0 and a2>0 then -- if selection only on this line
      if a1==to then to=a2+1                          -- merge the two parts
      elseif a2==fr-1 then fr=a1                      -- ditto
      elseif a1>=fr and a1<to and a2==to-1 then to=a1 -- remove a common part
      elseif a1<=fr and a2==to-1 then fr,to=a1,fr     -- ditto
      elseif a1==fr and a2<to-1 then fr=a2+1          -- ditto
      end
    end
    local tp = to==fr and "BTYPE_NONE" or "BTYPE_STREAM"
    editor.Select(nil, tp, nil, fr, to-fr, 1)
    editor.Redraw()
  end;
}
