------------------------------------------------------------------------------
-- Highlight --
------------------------------------------------------------------------------

local Guid = 0xF6138DC9
if not Plugin.Exist(Guid) then return end

Macro {
  description="Highlight: Select Syntax menu";
  area="Editor"; key="CtrlShift8";
  action = function() Plugin.Call(Guid, "own", "SelectSyntax") end;
}

Macro {
  description="Highlight: Highlight Extra";
  area="Editor"; key="CtrlShift9";
  action = function() Plugin.Call(Guid, "own", "HighlightExtra") end;
}

Macro {
  description="Highlight: Settings dialog";
  area="Editor"; key="CtrlShift-";
  action = function() Plugin.Call(Guid, "own", "Settings") end;
}
