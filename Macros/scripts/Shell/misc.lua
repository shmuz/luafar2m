local F = far.Flags

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
  id="9DD36C3B-D9DD-4F3F-BBA2-66BEF7B2960E";
  description="Find an upper non-directory item";
  area="Shell"; key="CtrlShiftHome";
  action=function() JumpToNonDir() end;
}

Macro {
  id="32B7A847-4026-46F2-A329-870F060BBE16";
  description="Folders shortcuts";
  area="Shell"; key="RCtrl-";
  action=function()
    if mf.mainmenu then mf.mainmenu("foldershortcuts")
    else Keys("F9 Home 2*Right Enter End 4*Up Enter")
    end
  end;
}

Macro {
  id="C187DDC2-37A3-4DEC-82DB-5744B38AFA0F";
  description="Jump to home directory";
  area="Shell"; key="Ctrl`";
  action=function()
    panel.SetPanelDirectory(nil, 1, far.GetMyHome())
  end;
}

Macro {
  id="9521C765-240B-460F-BF25-1124FB0F89F9";
  description="Sync far2m dir with far2l or vice versa";
  area="Shell"; key="CtrlS";
  action=function()
    local home = far.GetMyHome()
    local dir = panel.GetPanelDirectory(nil, 1).Name
    if dir == "" then -- TmpPanel ?
      dir = APanel.Current:match("(.+)/")
      if dir == nil then return end
    end
    local dir2 = dir
    local far2l = home.."/far2l"
    local far2m = home.."/far2m"
    if dir:find("far2l") then
      if dir2 == dir then dir2 = dir:gsub(far2l.."/far2l/", far2m.."/far/") end
      if dir2 == dir then dir2 = dir:gsub(far2l.."/far2l$", far2m.."/far") end
      if dir2 == dir then dir2 = dir:gsub(far2l.."/",       far2m.."/") end
      if dir2 == dir then dir2 = dir:gsub(far2l.."$",       far2m) end
    elseif dir:find("far2m") then
      if dir2 == dir then dir2 = dir:gsub(far2m.."/far/",   far2l.."/far2l/") end
      if dir2 == dir then dir2 = dir:gsub(far2m.."/far$",   far2l.."/far2l") end
      if dir2 == dir then dir2 = dir:gsub(far2m.."/",       far2l.."/") end
      if dir2 == dir then dir2 = dir:gsub(far2m.."$",       far2l) end
    end
    if dir2 ~= dir and win.GetFileAttr(dir2) then
      panel.SetPanelDirectory(nil, 0, dir2)
      panel.RedrawPanel(nil, 0)
    end
  end;
}

Macro {
  id="2B18F035-9041-4CF3-A8B5-45DB42D2F187";
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
  id="4864CDEA-5BD9-459E-9A2C-3DBF73B0E3FA";
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

Macro {
  id="21B1195D-9010-402D-9279-AF2DAECE0533";
  description="Python sub-plugins";
  area="Shell Info QView Tree"; key="CtrlShiftP";
  action=function()
    local PluginId = 0x7E9585C2
    if not Plugin.Exist(PluginId) then
      far.Message("Plugin Python not loaded",nil,nil,"w")
      return
    end
    local menuitems = {}
    far.RecursiveSearch(far.InMyConfig("plugins/python"), "*.py",
      function(item,path)
        local name = item.FileName:sub(1,-4)
        table.insert(menuitems, {text=name; Name=name;})
      end)
    table.sort(menuitems, function(a1,a2) return a1.text < a2.text; end)
    local title = ("Python plugins (%d)"):format(#menuitems)
    local bottom="Enter: load"
    local  mi = far.Menu({ Title=title; Bottom=bottom; }, menuitems)
    if mi then
      Plugin.Command(PluginId, "load "..mi.Name)
    end
  end;
}

Macro {
  id="07B83FAA-C357-4787-8862-6A86B70E4F79";
  description="Open selected files in Editor";
  area="Shell"; key="CtrlAltK";
  action=function()
    local inf = panel.GetPanelInfo(nil,1)
    if 0 == bit64.band(inf.Flags, F.PFLAGS_REALNAMES) then
      far.Message("Cannot do that: PFLAGS_REALNAMES bit not set")
      return
    end
    local deselect = {}
    for i=1,inf.SelectedItemsNumber do
      local item = panel.GetSelectedPanelItem(nil,1,i)
      if not item.FileAttributes:find("d") then
        local n = nil
        n = editor.Editor(item.FileName,n,n,n,n,n,"EF_NONMODAL EF_IMMEDIATERETURN")
        if n == F.EEC_MODIFIED then
          table.insert(deselect, item.FileName)
        end
      end
    end
    actl.SetCurrentWindow(1) -- started in Shell, finish in Shell
    Panel.Select(0,0,2,table.concat(deselect,"\n"))
  end;
}

Macro {
  id="7A456FA9-6C37-4A8F-9D9E-EC253DC172D3";
  description="Close all open editors and viewers";
  area="Shell"; key="CtrlAltK";
  action=function()
    local wcount = actl.GetWindowCount()
    for k=wcount,1,-1 do -- reverse order
      local inf = actl.GetWindowInfo(k)
      if inf.Type == F.WTYPE_EDITOR then
        editor.Quit(inf.Id)
      elseif inf.Type == F.WTYPE_VIEWER then
        viewer.Quit(inf.Id)
      end
    end
  end;
}
