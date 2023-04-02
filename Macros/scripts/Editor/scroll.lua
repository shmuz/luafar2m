-- http://forum.farmanager.com/viewtopic.php?t=9239&p=135906#p126786

local function BottomScreenLine(EI)
  return EI.TopScreenLine + EI.WindowSizeY - 1
end

Macro {
  description="Editor: Scroll Up";
  area="Editor"; key="CtrlUp MsWheelUp";
  action=function()
    local EI = editor.GetInfo()
    if EI.TopScreenLine > 1 then
      Keys("CtrlUp")
      if EI.CurLine < BottomScreenLine(EI) then Keys("Down") end
    end
  end;
}

Macro {
  description="Editor: Scroll Down";
  area="Editor"; key="CtrlDown MsWheelDown";
  action=function()
    local EI = editor.GetInfo()
    if EI.TotalLines > BottomScreenLine(EI) then
      Keys("CtrlDown")
      if EI.CurLine > EI.TopScreenLine then Keys("Up") end
    end
  end;
}

Macro {
  description="Editor: Scroll Right";
  area="Editor"; key="Ctrl'";
  action=function()
    local EI = editor.GetInfo()
    EI.CurTabPos = EI.CurTabPos==EI.LeftPos and EI.CurTabPos+1 or nil
    EI.LeftPos, EI.CurPos = EI.LeftPos+1, nil
    editor.SetPosition(nil,EI)
  end;
}

Macro {
  description="Editor: Scroll Left";
  area="Editor"; key="Ctrl;";
  action=function()
    local EI = editor.GetInfo()
    if EI.LeftPos > 1 then
      local ScrBar = Editor.Set(15,-1)~=0 and EI.TotalLines>EI.WindowSizeY
      local ClientSizeX = EI.WindowSizeX - (ScrBar and 1 or 0)
      if EI.CurTabPos-EI.LeftPos+1 == ClientSizeX then EI.CurTabPos = EI.CurTabPos-1 end
      EI.LeftPos, EI.CurPos = EI.LeftPos-1, nil
      editor.SetPosition(nil,EI)
    end
  end;
}
