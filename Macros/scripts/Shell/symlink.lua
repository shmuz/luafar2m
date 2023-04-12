local function CheckSymlink(_,data)
  data.SymlinkTarget = far.GetReparsePointInfo(APanel.Current)
  return data.SymlinkTarget
end

Macro {
  description="Show symlink target";
  area="Shell"; key="CtrlShiftL";
  condition=CheckSymlink;
  action=function(data)
    local Items = {
      {"DI_DOUBLEBOX",3,1,60,3, 0,0,0,0,"Symlink Target"},
      {"DI_EDIT",     5,2,58,2, 0,0,"DIF_READONLY",0,data.SymlinkTarget},
    }
    far.Dialog(-1,-1,64,5,nil,Items)
  end;
}

Macro {
  description="Go to symlink target";
  area="Shell"; key="CtrlPgDn";
  condition=CheckSymlink;
  action=function(data)
    Plugin.Command(far.GetPluginId(), "goto:"..data.SymlinkTarget)
  end;
}
