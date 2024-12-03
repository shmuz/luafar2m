local LFHistory = 0xA745761D

local function condition() return Plugin.Exist(LFHistory) end

local function LFH_run(cmd) Plugin.Call(LFHistory, "own", cmd) end

Macro {
  id="B2C498EE-37D2-4162-86B0-ECB1C9B16CA4";
  description="LuaFAR History: commands";
  area="Shell Info QView Tree"; key="AltF8";
  condition=condition;
  action=function() LFH_run"commands" end;
}

Macro {
  id="A15B55FC-A36B-41EA-9110-96B441F74185";
  description="LuaFAR History: view/edit";
  area="Shell Editor Viewer"; key="AltF11";
  condition=condition;
  action=function() LFH_run"view" end;
}

Macro {
  id="C8CE32F4-48CF-45DA-91CA-07B521951516";
  description="LuaFAR History: folders";
  area="Shell"; key="AltF12";
  condition=condition;
  action=function() LFH_run"folders" end;
}

Macro {
  id="97F6E9E5-CD17-431D-826F-79EFC51F4ED3";
  description="LuaFAR History: locate file";
  area="Shell"; key="ShiftSpace";
  condition=condition;
  action=function() LFH_run"locate" end;
}
