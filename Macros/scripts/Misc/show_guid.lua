Macro {
  id="A4956445-6F20-48A0-956E-E6BAA86F6646";
  description="Show dialog/menu ID";
  area="Dialog Menu Disks UserMenu";  key="CtrlG";
  action=function()
    local Id = Area.Dialog and Dlg.Id or Menu.Id
    local quotId = '"' .. Id .. '"'
    local fullname, text
    for name,guid in pairs(far.Guids or {}) do
      if guid == Id then
        fullname = "far.Guids." .. name
        break
      end
    end
    if fullname then
      local res = far.Message(fullname.."\n"..Id, "", "Copy &Name;Copy &GUID;Cancel")
      text = res==1 and fullname or res==2 and quotId
    else
      local res = far.Message(Id, "", "Copy &GUID;Cancel")
      text = res==1 and quotId
    end
    if text then far.CopyToClipboard(text) end
  end;
}
