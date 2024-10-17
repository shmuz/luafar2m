-- started: 2023-09-19
-- far2m only

local F = far.Flags

local data = mf.mload("shmuz", "FarMenuPositions") or {}

local PlugMenuArea = "Shell"

Macro {
  description="Plugin Menu Remember Pos";
  area="Menu"; key="Enter NumEnter";
  condition=function(key) return Menu.Id == far.Guids.PluginsMenuId end;
  action=function()
    data[PlugMenuArea] = Menu.Value
    Keys(akey(1))
  end;
}

Macro {
  description="Config Menu Remember Pos";
  area="Menu"; key="Enter NumEnter";
  condition=function(key) return Menu.Id == far.Guids.PluginsConfigMenuId end;
  action=function()
    data.Config = Menu.Value
    Keys(akey(1))
  end;
}

Macro {
  description="Plugin Menu Select Pos";
  area="Shell Editor Viewer"; key="F11";
  action=function()
    PlugMenuArea = Area.Current
    local V = data[Area.Current]
    Keys("F11")
    if V then Menu.Select(V, 0) end
  end;
}

Macro {
  description="Config Menu Select Pos";
  area="Shell"; key="AltShiftF9";
  action=function()
    local V = data.Config
    Keys("AltShiftF9")
    if V then Menu.Select(V, 0) end
  end;
}

Event {
  description="Save menu positions";
  group="ExitFAR";
  action=function() mf.msave("shmuz", "FarMenuPositions", data) end;
}
