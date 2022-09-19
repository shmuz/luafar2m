------------------------------------------------------------------------------
-- Highlight --
------------------------------------------------------------------------------
local Guid = 0xF6138DC9

Macro {
  description="Highlight: Select Syntax menu";
  area="Editor"; key="CtrlShift8";
  condition=function() return Plugin.Exist(Guid) end;
  action = function() Plugin.Call(Guid, "own", "SelectSyntax") end;
}

Macro {
  description="Highlight: Highlight Extra";
  area="Editor"; key="CtrlShift9";
  condition=function() return Plugin.Exist(Guid) end;
  action = function() Plugin.Call(Guid, "own", "HighlightExtra") end;
}

Macro {
  description="Highlight: Settings dialog";
  area="Editor"; key="CtrlShift-";
  condition=function() return Plugin.Exist(Guid) end;
  action = function() Plugin.Call(Guid, "own", "Settings") end;
}
