-- Started: 2023-04-12
-- FAR version: far2m

local function CheckSymlink(_,data)
  data.SymlinkTarget = far.GetReparsePointInfo(APanel.Current)
  return data.SymlinkTarget
end

local function Goto(data)
  Plugin.Command(far.GetPluginId(), "goto:"..data.SymlinkTarget)
end

Macro {
  description="Show symlink target";
  area="Shell"; key="CtrlShiftL";
  condition=CheckSymlink;
  action=function(data)
    local Items = {
      {"DI_DOUBLEBOX",3,1,60,4, 0,0,0,0,"Symlink Target"},
      {"DI_EDIT",     5,2,58,2, 0,0,0,"DIF_READONLY",data.SymlinkTarget},
      {"DI_BUTTON",   5,3, 0,3, 0,0,0,"DIF_CENTERGROUP+DIF_DEFAULTBUTTON","&Goto"},
      {"DI_BUTTON",   5,3, 0,3, 0,0,0,"DIF_CENTERGROUP","Cancel"},
    }
    if 3 == far.Dialog(nil,-1,-1,64,6,nil,Items) then Goto(data) end
  end;
}

Macro {
  description="Go to symlink target";
  area="Shell"; key="CtrlPgDn";
  condition=CheckSymlink;
  action=Goto;
}
