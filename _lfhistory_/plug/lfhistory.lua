-- coding: UTF-8
-- luacheck: globals _Plugin

far.ReloadDefaultScript = true
package.loaded["far2.custommenu"] = nil

local SETTINGS_KEY  = "lfhistory"
local SETTINGS_NAME = "settings"

local IniFile    = require "inifile"
local custommenu = require "far2.custommenu"
local Utils      = require "far2.utils"
local Sett       = require "far2.settings"
local M          = require "lfh_message"
local F          = far.Flags
local Field      = Sett.field

local DefaultCfg = {
  bDynResize  = true,
  bAutoCenter = true,
  bDirectSort = true,
  iSizeCmd    = 1000,
  iSizeView   = 1000,
  iSizeFold   = 1000,
  HighTextColor    = 0x3A,
  SelHighTextColor = 0x0A,
}

local cfgView = {
  PluginHistoryType = "view",
  FarFileName = "view.hst",
  FarHistoryType = "SavedViewHistory",
  title = "mTitleView",
  brkeys = {
    "F3", "F4",
    "CtrlEnter", "CtrlNumEnter", "RCtrlEnter", "RCtrlNumEnter",
    "ShiftEnter", "ShiftNumEnter",
    "CtrlPgUp", "RCtrlPgUp", "CtrlPgDn", "RCtrlPgDn",
  },
  maxItemsKey = "iSizeView",
}

local cfgCommands = {
  PluginHistoryType = "commands",
  FarFileName = "commands.hst",
  FarHistoryType = "SavedHistory",
  title = "mTitleCommands",
  brkeys = {
    "CtrlEnter", "RCtrlEnter", "CtrlNumEnter", "RCtrlNumEnter",
    "ShiftEnter", "ShiftNumEnter",
  },
  maxItemsKey = "iSizeCmd",
}

local cfgFolders = {
  PluginHistoryType  = "folders",
  FarFileName = "folders.hst",
  FarHistoryType = "SavedFolderHistory",
  title = "mTitleFolders",
  brkeys = {
    "CtrlEnter", "RCtrlEnter", "CtrlNumEnter", "RCtrlNumEnter",
    "ShiftEnter", "ShiftNumEnter",
  },
  maxItemsKey = "iSizeFold",
}

local cfgLocateFile = {
  PluginHistoryType  = "locatefile",
  title = "mTitleLocateFile",
  brkeys = {
    "F3", "F4",
    "CtrlEnter", "RCtrlEnter", "CtrlNumEnter", "RCtrlNumEnter",
  },
  bDynResize = true,
}

local function GetBoolConfigValue(Cfg, Key)
  if Cfg[Key] ~= nil then return Cfg[Key] else return DefaultCfg[Key] end
end

local function GetFileAttrEx(fname)
  return win.GetFileAttr(fname)
end

local function IsCtrlEnter (key)
  return key=="CtrlEnter" or key=="RCtrlEnter" or key=="CtrlNumEnter" or key=="RCtrlNumEnter"
end

local function IsCtrlPgUp (key) return key=="CtrlPgUp" or key=="RCtrlPgUp" end

local function IsCtrlPgDn (key) return key=="CtrlPgDn" or key=="RCtrlPgDn" end

local function ExecuteFromCmdLine(str, newwindow)
  panel.SetCmdLine(str)
  far.MacroPost(newwindow and "Keys('ShiftEnter')" or "Keys('Enter')")
end

local function GetTimeString (filetime)
  if filetime then
    local ft = win.FileTimeToLocalFileTime(filetime)
    ft = ft and win.FileTimeToSystemTime(ft)
    if ft then
      return ("%04d-%02d-%02d %02d:%02d:%02d"):format(
        ft.wYear,ft.wMonth,ft.wDay,ft.wHour,ft.wMinute,ft.wSecond)
    end
  end
  return M.mTimestampMissing
end

local function TellFileNotExist (fname)
  far.Message(('%s:\n"%s"'):format(M.mFileNotExist, fname), M.mError, M.mOk, "w")
end

local function TellFileIsDirectory (fname)
  far.Message(('%s:\n"%s"'):format(M.mFileIsDirectory, fname), M.mError, M.mOk, "w")
end

local function LocateFile (fname)
  local attr = GetFileAttrEx(fname)
  if attr and not attr:find"d" then
    local dir, name = fname:match("^(.*/)([^/]*)$")
    if panel.SetPanelDirectory(1, dir) then
      local pinfo = panel.GetPanelInfo(1)
      for i=1, pinfo.ItemsNumber do
        local item = panel.GetPanelItem(1, i)
        if item.FileName == name then
          local rect = pinfo.PanelRect
          local hheight = math.floor((rect.bottom - rect.top - 4) / 2)
          local topitem = pinfo.TopPanelItem
          panel.RedrawPanel(1, { CurrentItem = i,
            TopPanelItem = i>=topitem and i<topitem+hheight and topitem or
                           i>hheight and i-hheight or 0 })
          return true
        end
      end
    end
  end
  return false
end

-- Баг позиционирования на файл при возвращении в меню из модального редактора;
-- причина описана здесь: http://forum.farmanager.com/viewtopic.php?p=136358#p136358
local function RedrawAll_Workaround_b4545 (list)
  local f = list.OnResizeConsole
  list.OnResizeConsole = function() end
  actl.RedrawAll()
  list.OnResizeConsole = f
end

local function SortListItems (list, bDirectSort, hDlg)
  _Plugin.Cfg.bDirectSort = bDirectSort
  if bDirectSort then
    list.selalign = "bottom"
    list:Sort(function(a,b) return (a.time or 0) < (b.time or 0) end)
  else
    list.selalign = "top"
    list:Sort(function(a,b) return (a.time or 0) > (b.time or 0) end)
  end
  if hDlg then
    list:ChangePattern(hDlg, list.pattern)
  end
end

local function GetListKeyFunction (HistTypeConfig, HistTypeData)
  return function (self, hDlg, key, Item)
    -----------------------------------------------------------------------------------------------
    if key=="CtrlI" or key=="RCtrlI" then
      if HistTypeConfig==cfgCommands or HistTypeConfig==cfgView or HistTypeConfig==cfgFolders then
        SortListItems(self, not _Plugin.Cfg.bDirectSort, hDlg)
      end
      return "done"
    elseif key=="F3" or key=="F4" or key=="AltF3" or key=="AltF4" then
      if not Item then
        return "done"
      end
      if HistTypeConfig==cfgView or HistTypeConfig==cfgLocateFile then
        local fname = HistTypeConfig==cfgView and Item.text or Item.text:sub(2)
        if HistTypeConfig==cfgLocateFile then
          if not fname:find("/") then
            local Name = self.items.PanelDirectory and self.items.PanelDirectory.Name
            if Name and Name ~= "" then
              fname = Name:find("/$") and Name..fname or Name.."/"..fname
            end
          end
        end
        local attr = GetFileAttrEx(fname)
        if not attr then
          TellFileNotExist(fname)
          return "done"
        elseif attr:find("d") then
          TellFileIsDirectory(fname)
          return "done"
        elseif key == "AltF3" then
          viewer.Viewer(fname)
          RedrawAll_Workaround_b4545(self)
          return "done"
        elseif key == "AltF4" then
          editor.Editor(fname)
          RedrawAll_Workaround_b4545(self)
          return "done"
        end
      end
    -----------------------------------------------------------------------------------------------
    elseif key == "F7" then
      if HistTypeConfig ~= cfgLocateFile then
        if Item then
          local timestring = GetTimeString(Item.time)
          if timestring then
            far.Message(Item.text, timestring, ";Ok")
          end
        end
      end
      return "done"
    -----------------------------------------------------------------------------------------------
    elseif key == "CtrlF8" or key == "RCtrlF8" then
      if HistTypeConfig == cfgFolders or HistTypeConfig == cfgView then
        far.Message(M.mPleaseWait, "", "")
        self:DeleteNonexistentItems(hDlg,
            function(t) return t.text:find("^%w%w+:") -- some plugin's prefix
                               or GetFileAttrEx(t.text) or t.checked end,
            function(n) return 1 == far.Message((M.mDeleteItemsQuery):format(n),
                        M.mDeleteNonexistentTitle, ";YesNo", "w") end)
        hDlg:Redraw()
      end
      return "done"
    -----------------------------------------------------------------------------------------------
    elseif key == "F9" then
      local s = HistTypeData.lastpattern
      if s and s ~= "" then self:ChangePattern(hDlg,s) end
      return "done"
    -----------------------------------------------------------------------------------------------
    elseif key=="CtrlDel" or key=="RCtrlDel" or key=="CtrlNumDel" or key=="RCtrlNumDel" then
      if HistTypeConfig ~= cfgLocateFile then
        self:DeleteNonexistentItems(hDlg,
            function(t) return t.checked end,
            function(n) return 1 == far.Message((M.mDeleteItemsQuery):format(n),
                        M.mDeleteItemsTitle, ";YesNo", "w") end)
        hDlg:Redraw()
      end
      return "done"
    -----------------------------------------------------------------------------------------------
    elseif key=="ShiftDel" or key=="ShiftNumDel" then
      if HistTypeConfig == cfgLocateFile then return "done" end
    -----------------------------------------------------------------------------------------------
    elseif key=="Enter" or key=="NumEnter" or key=="ShiftEnter" or key=="ShiftNumEnter" then
      if not Item then
        return "done"
      end
      if HistTypeConfig==cfgView then
        local attr = GetFileAttrEx(Item.text)
        if not attr then
          TellFileNotExist(Item.text)
          return "done"
        elseif attr:find("d") then
          TellFileIsDirectory(Item.text)
          return "done"
        end
      end
    -----------------------------------------------------------------------------------------------
    end

    for _,v in ipairs(HistTypeConfig.brkeys) do
      if key == v then return "break" end
    end
  end
end

function cfgView.CanClose (self, item, breakkey)
  if item and (IsCtrlPgUp(breakkey) or IsCtrlPgDn(breakkey)) and not LocateFile(item.text) then
    TellFileNotExist(item.text)
    return false
  end
  return true
end

function cfgFolders.CanClose (self, item, breakkey)
  if not item then
    return true
  end
  ----------------------------------------------------------------------------
  if IsCtrlEnter(breakkey) then
    panel.SetCmdLine(item.text)
    return true
  end
  ----------------------------------------------------------------------------
  if panel.SetPanelDirectory(breakkey==nil and 1 or 0, item.text) then
    return true
  end
  ----------------------------------------------------------------------------
  local GetNextPath = function(s) return s:match("(.*/).+") end
  if not GetNextPath(item.text) then -- check before asking user
    far.Message(item.text, M.mPathNotFound, nil, "w")
    return false
  end
  ----------------------------------------------------------------------------
  if 1 ~= far.Message(item.text.."\n"..M.mJumpToNearestFolder, M.mPathNotFound, ";YesNo", "w") then
    return false
  end
  ----------------------------------------------------------------------------
  local path = item.text
  while true do
    local nextpath = GetNextPath(path)
    if nextpath then
      if panel.SetPanelDirectory(breakkey==nil and 1 or 0, nextpath) then
        return true
      end
      path = nextpath
    else
      far.Message(path, M.mPathNotFound, nil, "w")
      return false
    end
  end
end

local function MakeMenuParams (aHistTypeConfig, aHistTypeData, aItems)
  local Cfg = _Plugin.Cfg
  local menuProps = {
    DialogId      = win.Uuid("d853e243-6b82-4b84-96cd-e733d77eeaa1"),
    Flags         = {FMENU_WRAPMODE=1},
    HelpTopic     = "Contents",
    Title         = M[aHistTypeConfig.title],
    SelectIndex   = #aItems,
  }
  local listProps = {
    autocenter    = Cfg.bAutoCenter,
    resizeW       = GetBoolConfigValue(aHistTypeConfig, "bDynResize"),
    resizeH       = GetBoolConfigValue(aHistTypeConfig, "bDynResize"),
    resizeScreen  = true,
    col_highlight = Cfg.HighTextColor,
    col_selectedhighlight = Cfg.SelHighTextColor,
    selalign      = "bottom",
    selignore     = true,
    searchmethod  = aHistTypeData.searchmethod or "dos",
    filterlines   = true,
    xlat          = aHistTypeData.xlat,
  }
  local list = custommenu.NewList(listProps, aItems)
  list.keyfunction = GetListKeyFunction(aHistTypeConfig, aHistTypeData)
  list.CanClose = aHistTypeConfig.CanClose
  return menuProps, list
end

local function GetMaxItems (aConfig)
  return _Plugin.Cfg[aConfig.maxItemsKey]
end

local function DelayedSaveHistory (hst_name, hst, delay)
  far.Timer(delay, function(h)
    h:Close()
    Sett.msave(SETTINGS_KEY, hst_name, hst)
    Sett.msave(SETTINGS_KEY, SETTINGS_NAME, _Plugin.Cfg) -- _Plugin.Cfg.bDirectSort
  end)
end

local function get_history (aConfig)
  local menu_items, map = {}, {}

  -- add plugin database items
  local hst = Sett.mload(SETTINGS_KEY, aConfig.PluginHistoryType) or {}
  local plugin_items = Field(hst, "items")
  local settings = Field(hst, "settings")
  for _,v in ipairs(plugin_items) do
    if v.text and not map[v.text] then
      table.insert(menu_items, v)
      map[v.text] = v
    end
  end

  -- add Far database items
  local last_time = settings.last_time or 0

  local file = far.InMyConfig("history/" .. aConfig.FarFileName)
  local ini = IniFile.New(file, "nocomment")
  if ini then
    local far_lines, far_times = {}, {}

    local lines = ini:GetString(aConfig.FarHistoryType, "Lines")
    if lines then
      lines = lines:gsub("\\(.)", { ["\\"]="\\"; n="\n"; t="\t"; })
      for text in lines:gmatch("[^\n]+") do
        table.insert(far_lines, text)
      end
    end

    local times = ini:GetString(aConfig.FarHistoryType, "Times")
    if times then
      local i = 0
      for a,b,c,d,e,f,g,h in times:gmatch("(%x%x)(%x%x)(%x%x)(%x%x)(%x%x)(%x%x)(%x%x)(%x%x)") do
        i = i + 1
        if far_lines[i] == nil then break end
        local low  = tonumber(d..c..b..a, 16)
        local high = tonumber(h..g..f..e, 16)
        local time = math.floor((low + 2^32*high) / 10000)
        table.insert(far_times, time)
      end
    end

    for i,name in ipairs(far_lines) do
      local fartime = far_times[i] or 0
      local item = map[name]
      if item then
        if item.time < fartime then
          item.time = fartime
        end
      else
        if fartime >= last_time then
          item = { text=name; time=fartime; }
          table.insert(menu_items, item)
          map[name] = item
        end
      end
    end
  end

  settings.last_time = win.GetSystemTimeAsFileTime()

  local maxitems = GetMaxItems(aConfig)
  if #menu_items > maxitems then
    -- sort menu items: oldest records go first
    table.sort(menu_items, function(a,b) return (a.time or 0) < (b.time or 0) end)

    -- remove excessive items; leave checked items;
    local i = 1
    while (#menu_items >= i) and (#menu_items > maxitems) do
      if menu_items[i].checked then i = i+1 -- leave the item
      else table.remove(menu_items, i)      -- remove the item
      end
    end
  end

  -- execute the menu
  local menuProps, list = MakeMenuParams(aConfig, settings, menu_items)
  SortListItems(list, _Plugin.Cfg.bDirectSort, nil)
  local item, itempos = custommenu.Menu(menuProps, list)
  settings.searchmethod = list.searchmethod
  settings.xlat = list.xlat
  hst["items"] = list.items
  if item and list.pattern ~= "" then
    settings.lastpattern = list.pattern
  end
  DelayedSaveHistory(aConfig.PluginHistoryType, hst, 200)
  if item then
    return menu_items[itempos], item.BreakKey
  end
end

local function IsCmdLineAvail()
  local ar = far.MacroGetArea()
  return ar==F.MACROAREA_SHELL or ar==F.MACROAREA_INFOPANEL or
         ar==F.MACROAREA_QVIEWPANEL or ar==F.MACROAREA_TREEPANEL
end

local function commands_history()
  local item, key = get_history(cfgCommands)
  if item and IsCmdLineAvail() then
    if IsCtrlEnter(key) then
      panel.SetCmdLine(item.text)
    else
      ExecuteFromCmdLine(item.text, key ~= nil)
    end
  end
end

local function folders_history()
  get_history(cfgFolders)
end

local function CallViewer (fname, disablehistory)
  local flags = {VF_NONMODAL=1, VF_IMMEDIATERETURN=1, VF_ENABLE_F6=1, VF_DISABLEHISTORY=disablehistory}
  viewer.Viewer(fname, nil, nil, nil, nil, nil, flags)
end

local function CallEditor (fname, disablehistory)
  local flags = {EF_NONMODAL=1, EF_IMMEDIATERETURN=1, EF_ENABLE_F6=1, EF_DISABLEHISTORY=disablehistory}
  editor.Editor(fname, nil, nil, nil, nil, nil, flags)
end

local function view_history()
  local item, key = get_history(cfgView)

  if not item then return end
  local fname = item.text

  local shift_enter = (key=="ShiftEnter" or key=="ShiftNumEnter")

  if IsCtrlEnter(key) then
    panel.SetCmdLine(fname)

  elseif key == nil or shift_enter or IsCtrlPgDn(key) then
    if item.typ == "V" then CallViewer(fname, shift_enter)
    else CallEditor(fname, shift_enter)
    end

  elseif key == "F3" then CallViewer(fname, false)
  elseif key == "F4" then CallEditor(fname, false)
  end
  return key
end

local function LocateFile2()
  local info = panel.GetPanelInfo(1)
  if not (info and info.PanelType==F.PTYPE_FILEPANEL) then return end

  local items = { PanelInfo=info; PanelDirectory=panel.GetPanelDirectory(1); }
  for k=1,info.ItemsNumber do
    local v = panel.GetPanelItem(1,k)
    local prefix = v.FileAttributes:find("d") and "/" or " "
    items[k] = {text=prefix..v.FileName}
  end

  local hst = Sett.mload(SETTINGS_KEY, cfgLocateFile.PluginHistoryType) or {}
  local settings = Field(hst, "settings")

  local menuProps, list = MakeMenuParams(cfgLocateFile, settings, items)
  list.searchstart = 2

  local item, itempos = custommenu.Menu(menuProps, list)
  settings.searchmethod = list.searchmethod
  settings.xlat = list.xlat
  if item and list.pattern ~= "" then
    settings.lastpattern = list.pattern
  end
  DelayedSaveHistory(cfgLocateFile.PluginHistoryType, hst, 200)

  if item then
    if item.BreakKey then
      local data = items[itempos].text:sub(2)
      if IsCtrlEnter(item.BreakKey) then panel.SetCmdLine(data)
      elseif item.BreakKey == "F3" then CallViewer(data)
      elseif item.BreakKey == "F4" then CallEditor(data)
      end
    else
      panel.RedrawPanel(1,{CurrentItem=itempos})
    end
  end
end

function export.GetPluginInfo()
  return {
    CommandPrefix = "lfh",
    Flags = bit64.bor(F.PF_EDITOR, F.PF_VIEWER),
    PluginConfigStrings = { M.mPluginTitle },
    PluginMenuStrings = { M.mPluginTitle },
  }
end

function export.Configure()
  local dlg = require "lfh_config"
  if dlg(_Plugin.Cfg) then
    Sett.msave(SETTINGS_KEY, SETTINGS_NAME, _Plugin.Cfg)
  end
end

function export.OpenFromMacro (Args)
  local Op = Args[1]
  if Op=="code" or Op=="file" or Op=="command" then
    local _, commandTable = Utils.LoadUserMenu("_usermenu.lua")
    return Utils.OpenMacro(Args, commandTable, nil, M.mPluginTitle)
  elseif Op=="own" then
    if     Args[2] == "commands" then commands_history()
    elseif Args[2] == "view"     then view_history()
    elseif Args[2] == "folders"  then folders_history()
    elseif Args[2] == "locate"   then LocateFile2()
    elseif Args[2] == "config"   then export.Configure()
    end
  end
end

function export.OpenCommandLine (aItem)
  local _, commandTable = Utils.LoadUserMenu("_usermenu.lua")
  return Utils.OpenCommandLine(aItem, commandTable, nil, M.mPluginTitle)
end

function export.OpenPlugin (From, Item)
  if From==F.OPEN_PLUGINSMENU or From==F.OPEN_EDITOR or From==F.OPEN_VIEWER then
    local properties = {
      Title=M.mPluginTitle, HelpTopic="Contents", Flags="FMENU_WRAPMODE",
    }
    local allitems = {
      { text=M.mMenuCommands,   action=commands_history; areas="p";   },
      { text=M.mMenuView,       action=view_history;     areas="epv"; },
      { text=M.mMenuFolders,    action=folders_history;  areas="p";   },
      { text=M.mMenuConfig,     action=export.Configure; areas="epv"; },
      { text=M.mMenuLocateFile, action=LocateFile2;      areas="p";   },
    }
    local items = {}
    for _,v in ipairs(allitems) do
      if From==F.OPEN_PLUGINSMENU and v.areas:find("p") or
         From==F.OPEN_EDITOR      and v.areas:find("e") or
         From==F.OPEN_VIEWER      and v.areas:find("v")
      then
        table.insert(items, v)
        v.text = "&"..#items..". "..v.text
      end
    end
    local item = far.Menu(properties, items)
    if item then
      item.action()
    end
  end
end

if not _Plugin then
  _Plugin = {}
  _Plugin.Cfg = Sett.mload(SETTINGS_KEY, SETTINGS_NAME) or {}
  setmetatable(_Plugin.Cfg, {__index = DefaultCfg})
  export.OnError = Utils.OnError
end
