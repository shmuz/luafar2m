-- started: 2023-09-19
-- far2m only

local F = far.Flags
local PlugValue = {}
local CfgValue

Macro {
  description="Plugin Menu Remember Pos";
  area="Menu"; key="Enter NumEnter";
  condition=function(key) return Menu.Id == far.Guids.PluginsMenuId end;
  action=function()
    local area, winfo = nil, actl.GetWindowInfo()
    if winfo then
      if     winfo.Type == F.WTYPE_PANELS then area = "Shell"
      elseif winfo.Type == F.WTYPE_EDITOR then area = "Editor"
      elseif winfo.Type == F.WTYPE_VIEWER then area = "Viewer"
      end
    end
    if area then PlugValue[area] = Menu.Value end
    Keys(akey(1))
  end;
}

Macro {
  description="Config Menu Remember Pos";
  area="Menu"; key="Enter NumEnter";
  condition=function(key) return Menu.Id == far.Guids.PluginsConfigMenuId end;
  action=function()
    CfgValue = Menu.Value
    Keys(akey(1))
  end;
}

Macro {
  description="Plugin Menu Select Pos";
  area="Shell Editor Viewer"; key="F11";
  action=function()
    local V = PlugValue[Area.Current]
    Keys("F11")
    if V then Menu.Select(V, 0) end
  end;
}

Macro {
  description="Config Menu Select Pos";
  area="Shell"; key="AltShiftF9";
  action=function()
    Keys("AltShiftF9")
    if CfgValue then Menu.Select(CfgValue, 0) end
  end;
}
