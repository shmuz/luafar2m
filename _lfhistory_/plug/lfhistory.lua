-- coding: UTF-8
-- luacheck: globals _Plugin

far.ReloadDefaultScript = true
package.loaded["far2.custommenu"] = nil
package.loaded["lfh_config"] = nil

local SETTINGS_KEY  = ("%08X"):format(far.GetPluginId())
local SETTINGS_NAME = "settings"

local IniFile    = require "inifile"
local Custommenu = require "far2.custommenu"
local Utils      = require "far2.utils"
local Sett       = require "far2.settings"
local Config     = require "lfh_config"
local M          = require "lfh_message"
local F          = far.Flags
local Field      = Sett.field

local DefaultCfg = {
  bDynResize        = true,
  bAutoCenter       = true,
  bShowDates        = true,
  bKeepSelectedItem = false,
  bDirectSort       = true,
  HighTextColor     = 0x3A,
  SelHighTextColor  = 0x0A,
  iDateFormat       = 2,
  view = {
    iSize        = 1000;
    lastpattern  = nil;
    last_time    = 0;
    searchmethod = "dos";
    xlat         = false;
    exclude      = {};
  },
  commands = {
    iSize        = 1000;
    lastpattern  = nil;
    last_time    = 0;
    searchmethod = "dos";
    xlat         = false;
    exclude      = {};
  },
  folders = {
    iSize        = 1000;
    lastpattern  = nil;
    last_time    = 0;
    searchmethod = "dos";
    xlat         = false;
    exclude      = {};
  },
  locatefile = {
    iSize        = nil;
    lastpattern  = nil;
    last_time    = nil;
    searchmethod = "dos";
    xlat         = false;
    exclude      = nil;
    bDynResize   = true;
  },
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
}

local cfgLocateFile = {
  PluginHistoryType = "locatefile",
  title = "mTitleLocateFile",
  brkeys = {
    "F3", "F4",
    "CtrlEnter", "RCtrlEnter", "CtrlNumEnter", "RCtrlNumEnter",
  },
}

local DateFormats = {
  false,         -- don't show dates
  "%Y-%m-%d",    -- 2023-07-04
  "%Y-%m-%d %a", -- 2023-07-04 Tue
  "%x",          -- 04/07/23
  "%x %a",       -- 04/07/23 Tue
}

local function ConfigValue(Cfg, Key)
  if Cfg[Key] ~= nil then return Cfg[Key] end
  return _Plugin.Cfg[Key]
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
  far.MacroPost(newwindow and "Keys('ShiftEnter')" or "Keys('Enter')",
    "KMFLAGS_ENABLEOUTPUT") -- this flag was not needed until some FAR change between 09-12 Aug-23
    -- (without this flag there are panels drawn on the console upon Ctrl-O press)
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

local function FindFile (fname)
  local attr = GetFileAttrEx(fname)
  if attr and not attr:find"d" then
    local dir, name = fname:match("^(.*/)(.*)$")
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

local function ShowItemInfo (aItem, aConfig)
  local strTime = GetTimeString(aItem.time)
  if strTime then
    local sd = require "far2.simpledialog"
    local data = aConfig==cfgView and "File:"
      or aConfig==cfgCommands     and "Command:"
      or aConfig==cfgFolders      and "Folder:"
                                   or "Data:"
    local arr = {}
    arr[#arr+1] = {tp="dbox"; text="Information"; }
    arr[#arr+1] = {tp="text"; text=data; }
    arr[#arr+1] = {tp="edit"; text=aItem.text; readonly=1; }
    arr[#arr+1] = {tp="text"; text="Time:"; }
    arr[#arr+1] = {tp="edit"; text=strTime; readonly=1; }
    if aItem.extra then
      arr[#arr+1] = {tp="text"; text="Directory:"; }
      arr[#arr+1] = {tp="edit"; text=aItem.extra; readonly=1; }
    end
    arr[#arr+1] = {tp="sep"; }
    arr[#arr+1] = {tp="butt"; text=M.mOk; default=1; centergroup=1; }

    sd.New(arr):Run()
  end
end

local function GetListKeyFunction (aConfig, aData)
  return function (self, hDlg, key, Item)
    -----------------------------------------------------------------------------------------------
    if key=="CtrlI" or key=="RCtrlI" then
      if aConfig==cfgCommands or aConfig==cfgView or aConfig==cfgFolders then
        SortListItems(self, not _Plugin.Cfg.bDirectSort, hDlg)
      end
      return "done"
    elseif key=="F3" or key=="F4" or key=="AltF3" or key=="AltF4" then
      if not Item then
        return "done"
      end
      if aConfig==cfgView or aConfig==cfgLocateFile then
        local fname = aConfig==cfgView and Item.text or Item.FileName
        if aConfig==cfgLocateFile then
          if not fname:find("/") then
            local Name = self.items.PanelDirectory
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
          return "done"
        elseif key == "AltF4" then
          editor.Editor(fname)
          return "done"
        end
      end
    -----------------------------------------------------------------------------------------------
    elseif key == "F7" then
      if aConfig ~= cfgLocateFile then
        if Item then
          ShowItemInfo(Item, aConfig)
        end
      end
      return "done"
    -----------------------------------------------------------------------------------------------
    elseif key == "CtrlF8" or key == "RCtrlF8" then
      if aConfig == cfgFolders or aConfig == cfgView then
        far.Message(M.mPleaseWait, "", "")
        self:DeleteNonexistentItems(hDlg,
            function(t) return t.text:find("^%w%w+:") -- some plugin's prefix
                               or GetFileAttrEx(t.text) or t.checked end,
            function(n) return 1 == far.Message((M.mDeleteItemsQuery):format(n),
                        M.mDeleteNonexistentTitle, ";YesNo", "w") end)
        hDlg:send("DM_REDRAW")
      end
      return "done"
    -----------------------------------------------------------------------------------------------
    elseif key == "F9" then
      local s = aData.lastpattern
      if s and s ~= "" then self:ChangePattern(hDlg,s) end
      return "done"
    -----------------------------------------------------------------------------------------------
    elseif key=="CtrlDel" or key=="RCtrlDel" or key=="CtrlNumDel" or key=="RCtrlNumDel" then
      if aConfig ~= cfgLocateFile then
        self:DeleteNonexistentItems(hDlg,
            function(t) return t.checked end,
            function(n) return 1 == far.Message((M.mDeleteItemsQuery):format(n),
                        M.mDeleteItemsTitle, ";YesNo", "w") end)
        hDlg:send("DM_REDRAW")
      end
      return "done"
    -----------------------------------------------------------------------------------------------
    elseif key=="ShiftDel" or key=="ShiftNumDel" then
      if aConfig == cfgLocateFile then return "done" end
    -----------------------------------------------------------------------------------------------
    elseif key=="Enter" or key=="NumEnter" or key=="ShiftEnter" or key=="ShiftNumEnter" then
      if not Item then
        return "done"
      end
      if aConfig==cfgView then
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

    for _,v in ipairs(aConfig.brkeys) do
      if key == v then return "break" end
    end
  end
end

function cfgView.CanClose (_list, item, breakkey)
  if item and (IsCtrlPgUp(breakkey) or IsCtrlPgDn(breakkey)) and not FindFile(item.text) then
    TellFileNotExist(item.text)
    return false
  end
  return true
end

function cfgFolders.CanClose (_list, item, breakkey)
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

local function MakeMenuParams (aConfig, aData, aItems)
  local Cfg = _Plugin.Cfg
  local dateformat = DateFormats[Cfg.iDateFormat]

  local menuProps = {
    DialogId      = win.Uuid("d853e243-6b82-4b84-96cd-e733d77eeaa1"),
    Flags         = {FMENU_WRAPMODE=1},
    HelpTopic     = "Contents",
    Title         = M[aConfig.title],
    SelectIndex   = #aItems,
  }

  local listProps = {
    ----debug         = true,
    autocenter    = Cfg.bAutoCenter,
    resizeW       = ConfigValue(aData, "bDynResize"),
    resizeH       = ConfigValue(aData, "bDynResize"),
    resizeScreen  = true,
    col_highlight = Cfg.HighTextColor,
    col_selectedhighlight = Cfg.SelHighTextColor,
    selalign      = "bottom",
    selignore     = not Cfg.bKeepSelectedItem,
    searchmethod  = aData.searchmethod or "dos",
    filterlines   = true,
    xlat          = aData.xlat,
    showdates     = aConfig ~= cfgLocateFile and dateformat,
    dateformat    = dateformat,
  }
  local list = Custommenu.NewList(listProps, aItems)
  list.keyfunction = GetListKeyFunction(aConfig, aData)
  list.CanClose = aConfig.CanClose
  return menuProps, list
end

local function SaveHistory (hst_name, hst)
  if hst_name then
    Sett.msave(SETTINGS_KEY, hst_name, hst)
  end
  Sett.msave(SETTINGS_KEY, SETTINGS_NAME, _Plugin.Cfg) -- _Plugin.Cfg.bDirectSort
end

local function get_history (aConfig, aData)
  local menu_items, map = {}, {}

  -- add plugin database items
  local hst = Sett.mload(SETTINGS_KEY, aConfig.PluginHistoryType) or {}
  local plugin_items = Field(hst, "items")
  for _,v in ipairs(plugin_items) do
    if v.text and not map[v.text] then
      table.insert(menu_items, v)
      map[v.text] = v
    end
  end

  -- add Far database items
  local exclude = {}
  for _,v in ipairs(aData.exclude) do
    if v.text ~= "" then
      local ok, rx = pcall(regex.new, v.text)
      if ok then table.insert(exclude, rx) end
    end
  end
  local function IsExclusion(name)
    for _,rx in ipairs(exclude) do
      if rx:find(name) then return true; end -- don't use rx:match() here!
    end
  end

  local last_time = aData.last_time or 0

  local file = far.InMyConfig("history/" .. aConfig.FarFileName)
  local ini = IniFile.New(file, "nocomment")
  if ini then
    local function ProcessCfgString (aKey, aTarget)
      local lines = ini:GetString(aConfig.FarHistoryType, aKey)
      if lines then
        lines = lines:gsub("\\(.)", { ["\\"]="\\"; n="\n"; t="\t"; })
        for text in lines:gmatch("[^\n]+") do
          table.insert(aTarget, text)
        end
      end
    end

    local far_lines, far_times, far_extras = {}, {}, {}
    ProcessCfgString("Lines", far_lines)
    ProcessCfgString("Extras", far_extras)

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
      local extra = far_extras[i]
      local item = map[name]
      if item then -- an existing item
        if item.time < fartime then
          item.time = fartime
          item.extra = extra
        end
      else -- a new item
        if fartime >= last_time then -- if this is not a deleted item
          if not IsExclusion(name) then
            item = { text=name; time=fartime; extra=extra; }
            table.insert(menu_items, item)
            map[name] = item
          end
        end
      end
    end
  end

  aData.last_time = win.GetSystemTimeAsFileTime()

  if #menu_items > aData.iSize then
    -- sort menu items: oldest records go first
    table.sort(menu_items, function(a,b) return (a.time or 0) < (b.time or 0) end)

    -- remove excessive items; leave checked items;
    local i = 1
    while (#menu_items >= i) and (#menu_items > aData.iSize) do
      if menu_items[i].checked then i = i+1 -- leave the item
      else table.remove(menu_items, i)      -- remove the item
      end
    end
  end

  -- execute the menu
  local menuProps, list = MakeMenuParams(aConfig, aData, menu_items)
  SortListItems(list, _Plugin.Cfg.bDirectSort, nil)
  local item, itempos = Custommenu.Menu(menuProps, list)
  aData.searchmethod = list.searchmethod
  aData.xlat = list.xlat
  hst["items"] = list.items
  if item and list.pattern ~= "" then
    aData.lastpattern = list.pattern
  end
  SaveHistory(aConfig.PluginHistoryType, hst)
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
  local item, key = get_history(cfgCommands, _Plugin.Cfg.commands)
  if item and IsCmdLineAvail() then
    if IsCtrlEnter(key) then
      panel.SetCmdLine(item.text)
    else
      ExecuteFromCmdLine(item.text, key ~= nil)
    end
  end
end

local function folders_history()
  get_history(cfgFolders, _Plugin.Cfg.folders)
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
  local item, key = get_history(cfgView, _Plugin.Cfg.view)

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

local function LocateFile()
  local info = panel.GetPanelInfo(1)
  if not (info and info.PanelType==F.PTYPE_FILEPANEL) then return end

  local items = { PanelInfo=info; PanelDirectory=panel.GetPanelDirectory(1); }
  for k=1,info.ItemsNumber do
    local v = panel.GetPanelItem(1,k)
    local prefix = v.FileAttributes:find("d") and "/" or ""
    items[k] = {text=prefix..v.FileName; FileName=v.FileName; }
  end

  local aData = _Plugin.Cfg.locatefile
  local menuProps, list = MakeMenuParams(cfgLocateFile, aData, items)
  list.searchstart = 2

  local item, itempos = Custommenu.Menu(menuProps, list)
  aData.searchmethod = list.searchmethod
  aData.xlat = list.xlat
  if item and list.pattern ~= "" then
    aData.lastpattern = list.pattern
  end
  SaveHistory(nil)

  if item then
    if item.BreakKey then
      local data = items[itempos].FileName
      if IsCtrlEnter(item.BreakKey) then panel.SetCmdLine(data)
      elseif item.BreakKey == "F3" then CallViewer(data)
      elseif item.BreakKey == "F4" then CallEditor(data)
      end
    else
      panel.RedrawPanel(1,{CurrentItem=itempos})
    end
  end
end

local function GetCommandTable()
  local _, commandTable = Utils.LoadUserMenu("_usermenu.lua")
  return commandTable
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
  Config.ConfigMenu()
end

local function OpenFromMacro (Args)
  local Op = Args[1]
  if Op=="code" or Op=="file" then
    return Utils.OpenMacro(Args, nil, nil, M.mPluginTitle)
  elseif Op=="command" then
    return Utils.OpenMacro(Args, GetCommandTable(), nil, M.mPluginTitle)
  elseif Op=="own" then
    if     Args[2] == "commands" then commands_history()
    elseif Args[2] == "view"     then view_history()
    elseif Args[2] == "folders"  then folders_history()
    elseif Args[2] == "locate"   then LocateFile()
    elseif Args[2] == "config"   then export.Configure()
    end
  end
end

function export.Open (From, Item)
  if From == F.OPEN_COMMANDLINE then
    return Utils.OpenCommandLine(Item, GetCommandTable(), nil, M.mPluginTitle)

  elseif From == F.OPEN_FROMMACRO then
    return OpenFromMacro(Item)

  elseif From==F.OPEN_PLUGINSMENU or From==F.OPEN_EDITOR or From==F.OPEN_VIEWER then
    local properties = {
      Title=M.mPluginTitle, HelpTopic="Contents", Flags="FMENU_WRAPMODE",
    }
    local allitems = {
      { text=M.mMenuCommands,   action=commands_history; areas="p";   },
      { text=M.mMenuView,       action=view_history;     areas="epv"; },
      { text=M.mMenuFolders,    action=folders_history;  areas="p";   },
      { text=M.mMenuConfig,     action=export.Configure; areas="epv"; },
      { text=M.mMenuLocateFile, action=LocateFile;       areas="p";   },
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

local function FillDefaults (trg, src, guard)
  guard = guard or {} -- handle cyclic references
  for k,v in pairs(src) do
    if trg[k] == nil then
      if type(v) == "table" then
        if guard[v] then
          trg[k] = guard[v]
        else
          local t = {}
          trg[k] = t
          guard[v] = t
          FillDefaults(t, v, guard)
        end
      else
        trg[k] = v
      end
    elseif type(trg[k]) == "table" then
      if type(v)=="table" and guard[v]==nil then
        guard[v] = trg[k]
        FillDefaults(trg[k], v, guard)
      end
    end
  end
end

local function InitConfigModule()
  Config.Init {
    SaveHistory = SaveHistory;
    DateFormats = DateFormats;
  }
end

do
  if not _Plugin then
    _Plugin = {}
    _Plugin.Cfg = Sett.mload(SETTINGS_KEY, SETTINGS_NAME) or {}
  end
  FillDefaults(_Plugin.Cfg, DefaultCfg)
  InitConfigModule()
  export.OnError = Utils.OnError
end
