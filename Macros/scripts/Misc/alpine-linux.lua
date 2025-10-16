-- Started: 2025-10-16
-- This file is intended for use on Alpine Linux (which lacks many key combinations).

local ok = win.uname().version:upper():find("ALPINE")
if not ok then return end

--------------------------------
local CommonKey = "CtrlShiftL"
--------------------------------

Macro {
  description="History: commands";
  sortpriority=100;
  area="Shell Info QView Tree"; key=CommonKey;
  action=function()
    if 0 ~= mf.eval("AltF8", 2) then Keys("AltF8") end
  end;
}
Macro {
  description="History: view/edit";
  sortpriority=95;
  area="Shell Info QView Tree Editor Viewer"; key=CommonKey;
  action=function()
    if 0 ~= mf.eval("AltF11", 2) then Keys("AltF11") end
  end;
}
Macro {
  description="History: folders";
  sortpriority=90;
  area="Shell Info QView Tree"; key=CommonKey;
  action=function()
    if 0 ~= mf.eval("AltF12", 2) then Keys("AltF12") end
  end;
}
Macro {
  description="Same Folder";
  sortpriority=85;
  area="Shell"; key=CommonKey;
  action=function()
    Keys(APanel.Left and "AltF2 Enter" or "AltF1 Enter")
  end;
}
Macro {
  description="Plugins configuration";
  sortpriority=80;
  area="Shell Info QView Tree"; key=CommonKey;
  action=function() Keys("AltShiftF9") end;
}
Macro {
  description="Plugins load/unload";
  sortpriority=75;
  area="Common"; key=CommonKey;
  action=function() mf.eval("AltShiftF11", 2) end;
}
Macro {
  description="Post macro";
  sortpriority=70;
  area="Common"; key=CommonKey;
  action=function() mf.eval("CtrlShiftM", 2) end;
}
Macro {
  description="Location (Left)";
  sortpriority=60;
  area="Shell Info QView Tree"; key=CommonKey;
  action=function() Keys("AltF1") end;

}
Macro {
  description="Location (Right)";
  sortpriority=50;
  area="Shell Info QView Tree"; key=CommonKey;
  action=function() Keys("AltF2") end;
}
Macro {
  description="TESTS";
  sortpriority=45;
  area="Shell"; key=CommonKey;
  action=function() mf.eval("CtrlShiftF12", 2) end;
}
