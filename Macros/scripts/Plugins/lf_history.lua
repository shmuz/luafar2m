local LFHistory = 0xA745761D

local function condition() return Plugin.Exist(LFHistory) end

local function LFH_run(cmd) Plugin.Call(LFHistory, "own", cmd) end

Macro {
  id="B2C498EE-37D2-4162-86B0-ECB1C9B16CA4";
  id="3D726FFF-DB3C-4E88-971A-970A33227923";
  description="LuaFAR History: commands";
  area="Shell Info QView Tree"; key="AltF8";
  condition=condition;
  action=function() LFH_run"commands" end;
}

Macro {
  id="A15B55FC-A36B-41EA-9110-96B441F74185";
  id="164B26C4-C008-4F5A-ADDC-EBC57DEC3E73";
  description="LuaFAR History: view/edit";
  area="Shell Editor Viewer"; key="AltF11";
  condition=condition;
  action=function() LFH_run"view" end;
}

Macro {
  id="C8CE32F4-48CF-45DA-91CA-07B521951516";
  id="2B65E5B4-BE72-4CF2-937C-F9AEBDC49519";
  description="LuaFAR History: folders";
  area="Shell"; key="AltF12";
  condition=condition;
  action=function() LFH_run"folders" end;
}

Macro {
  id="97F6E9E5-CD17-431D-826F-79EFC51F4ED3";
  id="0F64B391-174A-4181-B9F3-3CB3F9A70B1E";
  description="LuaFAR History: locate file";
  area="Shell"; key="ShiftSpace";
  condition=condition;
  action=function() LFH_run"locate" end;
}
