-- Started: 2023-04-12
-- FAR version: far2m

local F = far.Flags

local function CheckSymlink(_,data)
  data.SymlinkTarget = far.GetReparsePointInfo(APanel.Current)
  return data.SymlinkTarget
end

local function Goto(data)
  Plugin.Command(far.GetPluginId(), "goto:"..data.SymlinkTarget)
end

Macro {
  id="42E5CEE2-0A93-44B9-981C-C1C580558A32";
  id="8BD14D95-695C-4C9B-B82E-CA881F16D481";
  description="Show symlink target";
  area="Shell"; key="CtrlShiftL";
  condition=CheckSymlink;
  action=function(data)
    local Items = {
      {"DI_DOUBLEBOX",3,1,60,4, 0,0,0, 0, "Symlink Target"},
      {"DI_EDIT",     5,2,58,2, 0,0,0, F.DIF_READONLY, data.SymlinkTarget},
      {"DI_BUTTON",   5,3, 0,3, 0,0,0, F.DIF_CENTERGROUP+F.DIF_DEFAULTBUTTON, "&Goto"},
      {"DI_BUTTON",   5,3, 0,3, 0,0,0, F.DIF_CENTERGROUP, "Cancel"},
    }
    if 3 == far.Dialog(nil,-1,-1,64,6,nil,Items) then Goto(data) end
  end;
}

Macro {
  id="71FE4598-4B1C-41DD-A1A0-B02B6DFE6BF6";
  id="0B450832-FD3F-404D-A281-0529823684B3";
  description="Go to symlink target";
  area="Shell"; key="CtrlPgDn";
  condition=CheckSymlink;
  action=Goto;
}
