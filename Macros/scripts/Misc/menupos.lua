-- started: 2023-09-19
-- far2m only

local F = far.Flags

local data = mf.mload("shmuz", "FarMenuPositions") or {}

local PlugMenuArea = "Shell"

Macro {
  id="E5958B2C-B2AD-4526-9745-CCD9A428F847";
  description="Plugin Menu Remember Pos";
  area="Menu"; key="Enter NumEnter";
  condition=function(key) return Menu.Id == far.Guids.PluginsMenuId end;
  action=function()
    data[PlugMenuArea] = Menu.Value
    Keys(akey(1))
  end;
}

Macro {
  id="41832CDA-195F-40DE-845B-53111627EE19";
  description="Config Menu Remember Pos";
  area="Menu"; key="Enter NumEnter";
  condition=function(key) return Menu.Id == far.Guids.PluginsConfigMenuId end;
  action=function()
    data.Config = Menu.Value
    Keys(akey(1))
  end;
}

Macro {
  id="592C27DF-1812-4789-9880-7CAC0EF670B5";
  description="Plugin Menu Select Pos";
  area="Common"; key="F11";
  action=function()
    PlugMenuArea = Area.Current
    local V = data[Area.Current]
    Keys("F11")
    if V then Menu.Select(V, 0) end
  end;
}

Macro {
  id="D10F0D17-5073-4F09-AC62-71125F43994D";
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
