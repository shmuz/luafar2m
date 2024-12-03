-- started: 2023-09-19
-- far2m only

local F = far.Flags

local data = mf.mload("shmuz", "FarMenuPositions") or {}

local PlugMenuArea = "Shell"

Macro {
  id="E5958B2C-B2AD-4526-9745-CCD9A428F847";
  id="C6DADA5F-2AEC-4041-8609-F3AFBF1B5D2A";
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
  id="5CBD67A2-14AC-488B-91F8-080E232304DE";
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
  id="3C61EE39-4E37-4F53-AAC6-F0469DAA4FD2";
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
  id="D10F0D17-5073-4F09-AC62-71125F43994D";
  id="A133EE02-8E67-4B7C-976C-4155173558B5";
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
