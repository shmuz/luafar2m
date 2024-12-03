-- http://forum.farmanager.com/viewtopic.php?t=9239&p=135906#p126786

local function BottomScreenLine(EI)
  return EI.TopScreenLine + EI.WindowSizeY - 1
end

Macro {
  id="A1F46DC8-D3CC-46C9-8A81-D03C16E92395";
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
  id="66116298-EBCC-4BA3-ACE4-82D6CE68C991";
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
  id="3EE94338-2F2F-430D-9092-EACD31E4A53C";
  description="Editor: Scroll Right";
  area="Editor"; key="Ctrl'";
  action=function()
    local EI = editor.GetInfo()
    EI.LeftPos = EI.LeftPos + 1
    if EI.CurTabPos < EI.LeftPos then
      EI.CurPos = EI.CurPos + 1
    end
    EI.CurTabPos = nil
    editor.SetPosition(nil, EI)
  end;
}

Macro {
  id="8B43B142-AF05-4C22-BB57-6D8273EE6CFE";
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
