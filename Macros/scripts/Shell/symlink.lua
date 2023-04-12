local function CheckSymlink(_,data)
  data.SymlinkTarget = far.GetReparsePointInfo(APanel.Current)
  return data.SymlinkTarget
end

Macro {
  description="Copy symlink target";
  area="Shell"; key="CtrlShiftL";
  condition=CheckSymlink;
  action=function(data)
    far.CopyToClipboard(data.SymlinkTarget)
  end;
}

Macro {
  description="Go to symlink target";
  area="Shell"; key="CtrlShiftL";
  condition=CheckSymlink;
  action=function(data)
    Plugin.Command(far.GetPluginId(), "goto:"..data.SymlinkTarget)
  end;
}
