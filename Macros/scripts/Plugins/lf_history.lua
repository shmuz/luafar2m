local LFHistory = 0xA745761D

local function condition() return Plugin.Exist(LFHistory) end

local function LFH_run(cmd) Plugin.Call(LFHistory, "own", cmd) end

Macro {
  description="LuaFAR History: commands";
  area="Shell Info QView Tree"; key="AltF8";
  condition=condition;
  action=function() LFH_run"commands" end;
}

Macro {
  description="LuaFAR History: view/edit";
  area="Shell Editor Viewer"; key="AltF11";
  condition=condition;
  action=function() LFH_run"view" end;
}

Macro {
  description="LuaFAR History: folders";
  area="Shell"; key="AltF12";
  condition=condition;
  action=function() LFH_run"folders" end;
}

Macro {
  description="LuaFAR History: locate file";
  area="Shell"; key="ShiftSpace";
  condition=condition;
  action=function() LFH_run"locate" end;
}
