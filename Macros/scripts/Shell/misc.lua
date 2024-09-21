-- assuming "Show directories first" option is set
-- description="Find an upper non-directory item";
-- area="Shell"; key="CtrlShiftHome";
local function JumpToNonDir()
  local pInfo = panel.GetPanelInfo(nil, 1)
  if pInfo then
    local lower, upper = 1, pInfo.ItemsNumber
    while upper-lower >= 2 do -- binary search
      local curr = math.floor((lower+upper)/2)
      local item = panel.GetPanelItem(nil,1,curr)
      if item.FileAttributes:find("d") then lower = curr
      else upper = curr
      end
    end
    panel.RedrawPanel(nil,1,{ CurrentItem=upper; TopPanelItem=upper-8; })
  end
end

Macro {
  description="Find an upper non-directory item";
  area="Shell"; key="CtrlShiftHome";
  action=function() JumpToNonDir() end;
}

Macro {
  description="Folders shortcuts";
  area="Shell"; key="RCtrl-";
  action=function()
    if mf.mainmenu then mf.mainmenu("foldershortcuts")
    else Keys("F9 Home 2*Right Enter End 4*Up Enter")
    end
  end;
}

Macro {
  description="Jump to home directory";
  area="Shell"; key="Ctrl`";
  action=function()
    panel.SetPanelDirectory(nil, 1, os.getenv"HOME")
  end;
}

Macro {
  description="Sync far2m dir with far2l or vice versa";
  area="Shell"; key="CtrlS";
  action=function()
    local home = os.getenv("HOME")
    local dir = panel.GetPanelDirectory(nil, 1).Name
    if dir == "" then -- TmpPanel ?
      dir = APanel.Current:match("(.+)/")
      if dir == nil then return end
    end
    local dir2 = dir
    if dir:find("far2l") then
      if dir2 == dir then dir2 = dir:gsub(home.."/far2l/far2l/", home.."/far2m/far/") end
      if dir2 == dir then dir2 = dir:gsub(home.."/far2l/far2l$", home.."/far2m/far") end
      if dir2 == dir then dir2 = dir:gsub(home.."/far2l/",       home.."/far2m/") end
      if dir2 == dir then dir2 = dir:gsub(home.."/far2l$",       home.."/far2m") end
    elseif dir:find("far2m") then
      if dir2 == dir then dir2 = dir:gsub(home.."/far2m/far/",   home.."/far2l/far2l/") end
      if dir2 == dir then dir2 = dir:gsub(home.."/far2m/far$",   home.."/far2l/far2l") end
      if dir2 == dir then dir2 = dir:gsub(home.."/far2m/",       home.."/far2l/") end
      if dir2 == dir then dir2 = dir:gsub(home.."/far2m$",       home.."/far2l") end
    end
    if dir2 ~= dir and win.GetFileAttr(dir2) then
      panel.SetPanelDirectory(nil, 0, dir2)
      panel.RedrawPanel(nil, 0)
    end
  end;
}

Macro {
  description="Edit files in SciTE";
  area="Shell"; key="AltShiftF4";
  action=function()
    local files = {}
    local info = panel.GetPanelInfo(nil, 1)
    for k=1, info.SelectedItemsNumber do
      local item = panel.GetSelectedPanelItem(nil,1,k)
      if not item.FileAttributes:find("d") then
        files[#files+1] = item.FileName:gsub("[ ?*'\"\\]", "\\%0")
      end
    end
    if files[1] then
      files = table.concat(files, " ")
      os.execute("scite "..files.." &")
    end
  end;
}

-- Started: 2021-09-16
Macro {
  description="Scroll active panel";
  area="Shell"; key="CtrlShiftDown CtrlShiftUp";
  action=function()
    local top, cur
    local info = panel.GetPanelInfo(nil,1)
    if mf.akey(1)=="CtrlShiftDown" then
      top = info.TopPanelItem + 1
      cur = info.CurrentItem + 1
    else
      top = info.TopPanelItem - 1
      cur = info.CurrentItem - 1
    end
    panel.RedrawPanel(nil, 1, {TopPanelItem=top; CurrentItem=cur; })
  end;
}
