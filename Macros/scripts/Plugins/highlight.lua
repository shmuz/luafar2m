------------------------------------------------------------------------------
-- Highlight --
------------------------------------------------------------------------------
local Guid = 0xF6138DC9

Macro {
  id="565500E7-F890-4D85-9A00-A9E0E10FA1C8";
  description="Highlight: Select Syntax menu";
  area="Editor"; key="CtrlShift8";
  condition=function() return Plugin.Exist(Guid) end;
  action = function() Plugin.Call(Guid, "own", "SelectSyntax") end;
}

Macro {
  id="CFFA7850-C6FC-484F-BEE5-072D3DBD01B9";
  description="Highlight: Highlight Extra";
  area="Editor"; key="CtrlShift9";
  condition=function() return Plugin.Exist(Guid) end;
  action = function() Plugin.Call(Guid, "own", "HighlightExtra") end;
}

Macro {
  id="215ECCC1-1E5B-4FB7-B6F4-D4A8AE124B67";
  description="Highlight: Settings dialog";
  area="Editor"; key="CtrlShift-";
  condition=function() return Plugin.Exist(Guid) end;
  action = function() Plugin.Call(Guid, "own", "Settings") end;
}
