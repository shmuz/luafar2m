-- https://forum.farmanager.com/viewtopic.php?p=180760#p180760

local F = far.Flags

local function Main(mode)
  local hDlg = far.AdvControl(F.ACTL_GETWINDOWINFO).Id
  if hDlg == 0 then return end
  local idx = hDlg:send(F.DM_GETFOCUS)
  local Text = hDlg:send(F.DM_GETTEXT, idx)
  local Sel = hDlg:send(F.DM_GETSELECTION, idx)
  local CursorPos = hDlg:send(F.DM_GETEDITPOSITION, idx)
  local SelText = Text:sub(Sel.BlockStartPos, Sel.BlockStartPos+Sel.BlockWidth-1)
  if mode == "lower" then
    SelText = SelText:lower();
  elseif mode == "UPPER" then
    SelText = SelText:upper();
  elseif mode == "Title" then
    SelText = SelText:gsub("(%w)(%w*)", function(a,b) return utf8.upper(a)..utf8.lower(b) end);
  end
  if Sel.BlockWidth > 0 then
    Text = Text:sub(1, Sel.BlockStartPos-1)..SelText..Text:sub(Sel.BlockStartPos+Sel.BlockWidth)
  else
    Text = SelText
  end
  hDlg:send(F.DM_SETTEXT, idx, Text)
  hDlg:send(F.DM_SETEDITPOSITION, idx, CursorPos)
end

MenuItem {
  description = "DialogText: lower case";
  menu = "Plugins";
  area = "Dialog";
  guid = "F00B6015-D546-446D-B375-143C632AE041";
  text = function() return "Change Case: lower" end;
  action = function() Main("lower") end;
}

MenuItem {
  description = "DialogText: UPPER CASE";
  menu = "Plugins";
  area = "Dialog";
  guid = "818CD69A-8EEE-4972-9EE7-AE86FCD79B9D";
  text = function() return "Change Case: UPPER" end;
  action = function() Main("UPPER") end;
}

MenuItem {
  description = "DialogText: Title Case";
  menu = "Plugins";
  area = "Dialog";
  guid = "5D39AFBD-5EC7-45BF-BA2A-062D36BC5A67";
  text = function() return "Change Case: Title" end;
  action = function() Main("Title") end;
}
