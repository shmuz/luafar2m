local lfhistory=0xA745761D

Macro {
  description="LF History: Commands";
  area="Shell"; key="AltF8";
  condition=function() return Plugin.Exist(lfhistory) end;
  action=function() Plugin.Call(lfhistory, "own", "commands") end;
}

Macro {
  description="LF History: View/Edit";
  area="Shell Editor Viewer"; key="AltF11";
  condition=function() return Plugin.Exist(lfhistory) end;
  action=function() Plugin.Call(lfhistory, "own", "view") end;
}

Macro {
  description="LF History: Folders";
  area="Shell"; key="AltF12";
  condition=function() return Plugin.Exist(lfhistory) end;
  action=function() Plugin.Call(lfhistory, "own", "folders") end;
}

Macro {
  description="LF History: Locate file";
  area="Shell"; key="ShiftSpace";
  condition=function() return Plugin.Exist(lfhistory) end;
  action=function() Plugin.Call(lfhistory, "own", "locate") end;
}
