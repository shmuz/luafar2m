-- Encoding: UTF-8
-- tmppanel.lua

local sd = require "far2.simpledialog"

local Package = {}

-- The default message table
local M = {
  MOk                         = "Ok";
  MCancel                     = "Cancel";
  MError                      = "Error";
  MWarning                    = "Warning";
  MTempPanel                  = "LuaFAR Temp. Panel";
  MTempPanelTitleNum          = " %sLuaFAR Temp. Panel [%d] ";
  MDiskMenuString             = "temporary (LuaFAR)";
  MF7                         = "Remove";
  MAltShiftF12                = "Switch";
  MAltShiftF2                 = "SavLst";
  MAltShiftF3                 = "Goto";
  MTempUpdate                 = "Updating temporary panel contents";
  MTempSendFiles              = "Sending files to temporary panel";
  MSwitchMenuTxt              = "Total files:";
  MSwitchMenuTitle            = "Available temporary panels";
  MConfigTitle                = "LuaFAR Temporary Panel";
  MConfigAddToDisksMenu       = "Add to &Disks menu";
  MConfigAddToPluginsMenu     = "Add to &Plugins menu";
  MConfigCommonPanel          = "Use &common panel";
  MSafeModePanel              = "&Safe panel mode";
  MReplaceInFilelist          = "&Replace files with file list";
  MMenuForFilelist            = "&Menu from file list";
  MCopyContents               = "Copy folder c&ontents";
  MFullScreenPanel            = "F&ull screen mode";
  MColumnTypes                = "Column &types";
  MColumnWidths               = "Column &widths";
  MStatusColumnTypes          = "Status line column t&ypes";
  MStatusColumnWidths         = "Status l&ine column widths";
  MMask                       = "File masks for the file &lists:";
  MPrefix                     = "Command line pre&fix:";
  MConfigNewOption            = "New settings will become active after FAR restart";
  MNewPanelForSearchResults   = "&New panel for search results";
  MListFilePath               = "Save file list as";
  MCopyContentsMsg            = "Copy folder contents?";
  MSavePanelsOnFarExit        = "Sa&ve panels on FAR exit";
}

-- This function should be called if message localization support is needed
function Package.SetMessageTable(msg_tbl) M = msg_tbl; end

local F  = far.Flags
local band, bor = bit64.band, bit64.bor

-- constants
local COMMONPANELSNUMBER = 10
local BOM_UTF16LE = "\255\254"
local BOM_UTF8 = "\239\187\191"

local Opt = {
  AddToDisksMenu            = true,
  AddToPluginsMenu          = true,
  CommonPanel               = true,
  SafeModePanel             = false,
  CopyContents              = 2,
  ReplaceMode               = true,
  MenuForFilelist           = true,
  NewPanelForSearchResults  = true,
  FullScreenPanel           = false,
  ColumnTypes               = "N,S",
  ColumnWidths              = "0,8",
  StatusColumnTypes         = "NR,SC,D,T",
  StatusColumnWidths        = "0,8,0,5",
  Mask                      = "*.tmp2",
  Prefix                    = "tmp2",
  SavePanels                = true, --> new
}

local Env, Panel = {}, {}
local EnvMeta = { __index = Env }

local function LTrim(s) return s:match "^%s*(.*)" end
local function Trim(s) return s:match "^%s*(.-)%s*$" end
local function Unquote(s) return (s:gsub("\"", "")) end
local function ExtractFileName(s) return s:match "[^/]*$" end
local function ExtractFileDir(s) return s:match ".*/" or "" end
local function AddEndSlash(s) return (s:gsub("/?$", "/", 1)) end
local function TruncStr(s, maxlen)
  local len = s:len()
  return len <= maxlen and s or s:sub(1,6) .. "..." .. s:sub (len - maxlen + 10)
end

local function ExpandEnvironmentStr (str)
  return ( str:gsub("%%([^%%]*)%%", win.GetEnv) )
end

local function IsDirectory (PanelItem)
  return PanelItem.FileAttributes:find"d" and true
end


-- File lists are supported in the following formats:
-- (a) UTF-16LE with BOM, (b) UTF-8 with BOM, (c) UTF-8.
local function ListFromFile (aFileName)
  local list = {}
  local hFile = io.open (aFileName, "rb")
  if hFile then
    local text = hFile:read("*a")
    hFile:close()
    if text then
      local strsub = string.sub
      if strsub(text, 1, 3) == BOM_UTF8 then
        text = strsub(text, 4)
      elseif strsub(text, 1, 2) == BOM_UTF16LE then
        text = win.Utf16ToUtf8(strsub(text, 3))
      -- else -- default is UTF-8
        -- do nothing
      end
      for line in text:gmatch("[^\n\r]+") do
        table.insert(list, line)
      end
    end
  end
  return list
end


local function IsOwnersDisplayed (ColumnTypes)
  for word in ColumnTypes:gmatch "[^,]+" do
    if word == "O" then return true end
  end
end


local function IsLinksDisplayed (ColumnTypes)
  for word in ColumnTypes:gmatch "[^,]+" do
    if word == "LN" then return true end
  end
end


local function ParseParam (str)
  local parm, str2 = str:match "^%|(.*)%|(.*)"
  if parm then
    return parm, LTrim(str2)
  end
  return nil, str
end


local function isDevice (FileName, dev_begin)
  local len = dev_begin:len()
  return FileName:sub(1, len):upper() == dev_begin:upper() and
         FileName:sub(len+1):match("%d+$") and true
end


local function CheckForCorrect (Name)
  Name = ExpandEnvironmentStr(Name)
  local _, p = ParseParam (Name)
  if p:match [[^\\%.\%a%:$]]
      or isDevice(p, [[\\.\PhysicalDrive]])
      or isDevice(p, [[\\.\cdrom]]) then
    return { FileName = p, FileAttributes = "a" }
  end

  if p:find "%S" and not p:find "[?*]" and p ~= "\\" and p ~= ".." then
    local q = p:gsub("/$", "")
    local PanelItem = win.GetFileInfo(q)
    if PanelItem then
      PanelItem.FileName = p
      PanelItem.PackSize    = PanelItem.FileSize
      PanelItem.Description = "One of my files"
      PanelItem.Owner       = "Joe Average"
    --PanelItem.UserData  = numline
    --PanelItem.Flags     = { selected=true, }
      return PanelItem
    end
  end
end


local function IsCurrentFileCorrect (Handle)
  local fname = panel.GetCurrentPanelItem(Handle).FileName
  local correct = (fname == "..") or (CheckForCorrect(fname) and true)
  return correct, fname
end


local function GoToFile (Target, PanelNumber)
  local Dir  = Unquote (Trim (ExtractFileDir (Target)))
  if Dir ~= "" then
    panel.SetPanelDirectory (PanelNumber, Dir)
  end

  local PInfo = assert(panel.GetPanelInfo (PanelNumber))
  local Name = Unquote (Trim (ExtractFileName (Target))):upper()
  for i=1, PInfo.ItemsNumber do
    local item = panel.GetPanelItem (PanelNumber, i)
    if Name == ExtractFileName (item.FileName):upper() then
      panel.RedrawPanel (PanelNumber, { CurrentItem=i, TopPanelItem=i })
      return
    end
  end
end


local function SortListCmp (Item1, Item2)
  return Item1:upper() < Item2:upper()
end


local function ShowMenuFromFile (FileName)
  local list = ListFromFile(FileName,false)
  local menuitems = {}
  for i, line in ipairs(list) do
    line = ExpandEnvironmentStr(line)
    local part1, part2 = ParseParam(line)
    if part1 == "-" then
      menuitems[i] = { separator=true }
    else
      local menuline = TruncStr(part1 or part2, 67)
      menuitems[i] = { text=menuline, action=part2 }
    end
  end
  local breakkeys = { {BreakKey="S+RETURN"}, } -- Shift+Enter

  local Title = ExtractFileName(FileName):gsub("%.[^.]+$", "")
  Title = TruncStr(Title, 64)
  local Item, Position = far.Menu(
    { Flags="FMENU_WRAPMODE", Title=Title, HelpTopic="Contents", Bottom=#menuitems.." lines" },
    menuitems, breakkeys)
  if not Item then return end

  local bShellExecute
  if Item.BreakKey then
    bShellExecute = true
    Item = menuitems[Position]
  else
    local panelitem = CheckForCorrect (Item.action)
    if panelitem then
      if IsDirectory (panelitem) then
        panel.SetPanelDirectory (1, Item.action)
      else
        bShellExecute = true
      end
    else
      panel.SetCmdLine (Item.action)
    end
  end
  --### if bShellExecute then
  --###   _Su.ShellExecute (nil, "open", Item.action, nil, nil, "SW_SHOW")
  --### end
end


function Package.PutExportedFunctions (tab)
  for _, name in ipairs {
        "GetFindData", "GetOpenPluginInfo", "PutFiles", "SetDirectory",
        "ProcessEvent", "ProcessKey", "SetFindList", "ClosePlugin", }
  do
    tab[name] = Panel[name]
  end
end


-- Создать новое окружение, или воссоздать из истории /?/
function Package.NewEnv (aEnv)
  local self = aEnv or {}

  -- создать или воссоздать опции для окружения
  self.Opt = self.Opt or {}
  for k,v in pairs(Opt) do -- скопировать отсутствующие опции
    if self.Opt[k]==nil then self.Opt[k]=v end
  end
  self.OptMeta = { __index = self.Opt } -- метатаблица для будущего наследования

  -- инициализировать некоторые переменные
  self.LastSearchResultsPanel = self.LastSearchResultsPanel or 1
  self.StartupOptCommonPanel = self.Opt.CommonPanel
  self.StartupOptFullScreenPanel = self.Opt.FullScreenPanel

  -- если нет "общих" панелей - создать их
  if not self.CommonPanels then
    self.CommonPanels = {}
    for i=1,COMMONPANELSNUMBER do self.CommonPanels[i] = {} end
    self.CurrentCommonPanel = 1
  end

  -- установить наследование функций от базового окружения
  return setmetatable (self, EnvMeta)
end
--------------------------------------------------------------------------------


function Env:OpenPanelFromOutput (command)
  local h = io.popen (command, "rt")
  if h then
    local list = {}
    for line in h:lines() do
      table.insert (list, line)
    end
    h:close()
    local newpanel = self:NewPanel()
    newpanel:ProcessList (list, newpanel.Opt.ReplaceMode)
    return newpanel
  end
end


function Env:GetPluginInfo()
  local opt = self.Opt
  local Info = {}
  Info.Flags = 0
  -- Info.Flags.preload = true
  Info.CommandPrefix = opt.Prefix;
  if opt.AddToPluginsMenu then
    Info.PluginMenuStrings = { M.MTempPanel }
  end
  if opt.AddToDisksMenu then
    Info.DiskMenuStrings = { M.MDiskMenuString }
  end
  Info.PluginConfigStrings = { M.MTempPanel }
  return Info
end


function Env:SelectPanelFromMenu()
  local txt = M.MSwitchMenuTxt
  local fmt1 = "&%s. %s %d"
  local menuitems = {}
  for i = 1, COMMONPANELSNUMBER do
    local menuline
    if i <= 10 then
      menuline = fmt1:format(i-1, txt, #self.CommonPanels[i])
    elseif i <= 36 then
      menuline = fmt1:format(string.char(("A"):byte()+i-11), txt, #self.CommonPanels[i])
    else
      menuline = ("   %s %d"):format(txt, #self.CommonPanels[i])
    end
    menuitems[i] = { text=menuline }
  end

  local Item, Position = far.Menu( {
    Flags = {FMENU_AUTOHIGHLIGHT=1, FMENU_WRAPMODE=1},
    Title = M.MSwitchMenuTitle, HelpTopic = "Contents",
    SelectIndex = self.CurrentCommonPanel,
  }, menuitems)
  return Item and Position
end


function Env:FindSearchResultsPanel()
  for i,v in ipairs(self.CommonPanels) do
    if #v == 0 then return i end
  end
  -- no panel is empty - use least recently used index
  local index = self.LastSearchResultsPanel
  self.LastSearchResultsPanel = self.LastSearchResultsPanel + 1
  if self.LastSearchResultsPanel > #self.CommonPanels then
    self.LastSearchResultsPanel = 1
  end
  return index
end


function Env:NewPanel (aOptions)
  local newpanel = {
    Env = self,
    LastOwnersRead = false,
    LastLinksRead = false,
    UpdateNeeded = true
  }

  newpanel.Opt = setmetatable({}, self.OptMeta)
  if aOptions then
    for k,v in pairs(aOptions) do newpanel.Opt[k] = v end
  end

  if self.StartupOptCommonPanel then
    newpanel.Index = self.CurrentCommonPanel
    newpanel.GetItems = Panel.GetRefItems
    newpanel.ReplaceFiles = Panel.ReplaceRefFiles
  else
    newpanel.Files = {}
    newpanel.GetItems = Panel.GetOwnItems
    newpanel.ReplaceFiles = Panel.ReplaceOwnFiles
  end
  return setmetatable (newpanel, { __index = Panel })
end


function Env:OpenFilePlugin (Name, Data)
  if Name then
    for mask in self.Opt.Mask:gmatch "[^,]+" do
      if far.CmpName(mask, Name, true) then
        if self.Opt.MenuForFilelist then
          ShowMenuFromFile(Name)
          break
        else
          local pan = self:NewPanel()
          pan:ProcessList (ListFromFile(Name), self.Opt.ReplaceMode)
          pan.HostFile = Name
          return pan
        end
      end
    end
  end
end


function Env:OpenPlugin (OpenFrom, Item)
  -- if IsOldFAR then return nil end
  --  GetOptions (PluginRootKey)

  self.StartupOpenFrom = OpenFrom
  if OpenFrom == F.OPEN_COMMANDLINE then
    local newOpt = setmetatable({}, {__index=self.Opt})
    local ParamsTable = {
      safe="SafeModePanel", replace="ReplaceMode", menu="MenuForFilelist",
      full="FullScreenPanel" }

    local argv = Item
    while argv ~= "" do
      local switch, param, rest = argv:match "^%s*([+%-])(%S*)(.*)"
      if not switch then break end
      argv = rest
      param = param:lower()
      if ParamsTable[param] then
        newOpt[ParamsTable[param]] = (switch == "+")
      else
        local digit = param:match "^%d"
        if digit then
          self.CurrentCommonPanel = tonumber(digit) + 1
        end
      end
    end

    argv = Trim(argv)
    if argv ~= "" then
      if argv:sub(1,1) == "<" then
        argv = argv:sub(2)
        return self:OpenPanelFromOutput (argv)
      else
        argv = Unquote(argv)
        local PathName = ExpandEnvironmentStr(argv)
        local attr = win.GetFileAttr(PathName)
        if attr and not attr:find("d") then
          if newOpt.MenuForFilelist then
            ShowMenuFromFile (PathName)
            return nil
          else
            local pan = self:NewPanel(newOpt)
            pan:ProcessList (ListFromFile(PathName), newOpt.ReplaceMode)
            pan.HostFile = PathName
            return pan
          end
        else return
        end
      end
    end
  end
  return self:NewPanel()
end


function Env:ExitFAR()
  if not self.Opt.SavePanels then
    self.CommonPanels = nil
    self.CurrentCommonPanel = nil
  end
end


function Env:Configure()
  local width = 78
  local DC = math.floor(width/2-1)

  local Items = {
    width = width;
    help = "Config";
    {tp="dbox"; text=M.MConfigTitle; },
    {tp="chbox"; name="AddToDisksMenu"; text=M.MConfigAddToDisksMenu; },
    {tp="chbox"; name="AddToPluginsMenu"; y1=""; x1=DC; text=M.MConfigAddToPluginsMenu; },
    {tp="sep"; ystep=2; },
    ------------------------------------------------------------------------------------------------
    {tp="chbox"; name="CommonPanel";    text=M.MConfigCommonPanel; },
    {tp="chbox"; name="SafeModePanel";  text=M.MSafeModePanel; },
--  {tp="chbox"; name="AnyInPanel"; text=M.MAnyInPanel; },
    {tp="chbox"; name="CopyContents"; tristate=1; text=M.MCopyContents; };
    {tp="chbox"; name="ReplaceMode";              x1=DC; ystep=-2; text=M.MReplaceInFilelist; },
    {tp="chbox"; name="MenuForFilelist";          x1=DC; text=M.MMenuForFilelist; },
    {tp="chbox"; name="NewPanelForSearchResults"; x1=DC; text=M.MNewPanelForSearchResults; },
    {tp="chbox"; name="SavePanels";               x1=DC; text=M.MSavePanelsOnFarExit; },
    {tp="sep"; },
    ------------------------------------------------------------------------------------------------
    {tp="text"; text=M.MColumnTypes;          },
    {tp="edit"; name="ColumnTypes";  x2=DC-2; },
    {tp="text"; text=M.MColumnWidths;         },
    {tp="edit"; name="ColumnWidths"; x2=DC-2; },
    {tp="text"; x1=DC; ystep=-3; text=M.MStatusColumnTypes; },
    {tp="edit"; x1=DC; name="StatusColumnTypes";   },
    {tp="text"; x1=DC; text=M.MStatusColumnWidths; },
    {tp="edit"; x1=DC; name="StatusColumnWidths";  },
    {tp="chbox"; name="FullScreenPanel"; text=M.MFullScreenPanel; },
    {tp="sep"; },
    ------------------------------------------------------------------------------------------------
    {tp="text"; text=M.MMask;         },
    {tp="edit"; name="Mask"; x2=DC-2; },
    {tp="text"; x1=DC; ystep=-1; text=M.MPrefix; },
    {tp="edit"; x1=DC; name="Prefix"; },
    {tp="sep"; },
    ------------------------------------------------------------------------------------------------
    {tp="butt"; text=M.MOk;     centergroup=1; default=1; },
    {tp="butt"; text=M.MCancel; centergroup=1; cancel=1;  },
  }
  sd.LoadData(self.Opt, Items)

  local out = sd.Run(Items)
  if out then
    sd.SaveData(out, self.Opt)

    if self.StartupOptCommonPanel ~= self.Opt.CommonPanel then
      far.Message (M.MConfigNewOption, M.MTempPanel, M.MOk)
    end
    return true
  end
end


function Panel:GetOwnItems()
  return self.Files
end


function Panel:GetRefItems()
  return self.Env.CommonPanels[self.Index]
end


function Panel:ReplaceOwnFiles (Table)
  self.Files = Table
end


function Panel:ReplaceRefFiles(Table)
  self.Env.CommonPanels[self.Index] = Table
end


function Panel:ClosePlugin (Handle)
  collectgarbage "collect"
end


function Panel:ProcessList (aList, aReplaceMode)
  if aReplaceMode then self:ReplaceFiles {} end
  local items = self:GetItems()
  for _,v in ipairs(aList) do
    local dir, name = v:match("^(.*[\\/])(.*)$")
    if not dir then dir, name = ".", v end
    far.RecursiveSearch(dir, name,
      function(_, fullname)
        if fullname:sub(-1) ~= "." then items[#items+1] = fullname end
      end)
  end
end


function Panel:UpdateItems (ShowOwners, ShowLinks)
--~   if not self.UpdateNeeded or #self:GetItems() == 0 then
--~     self.UpdateNeeded = true
--~     return
--~   end

  local hScreen = #self:GetItems() >= 1000 and far.SaveScreen()
  if hScreen then far.Message(M.MTempUpdate, M.MTempPanel, "") end

  self.LastOwnersRead = ShowOwners
  self.LastLinksRead = ShowLinks
  self.RemoveTable = {}
  local PanelItems = {}
  local items = self:GetItems()
  for i,v in ipairs(items) do
    local panelitem = CheckForCorrect (v)
    if panelitem then
      table.insert (PanelItems, panelitem)
    else
      self.RemoveTable[i] = true
    end
  end
  self:RemoveMarkedItems()

  if ShowOwners or ShowLinks then
    for _,v in ipairs(PanelItems) do
      if ShowOwners then
        v.Owner = far.GetFileOwner(nil, v.FileName)
      end
      if ShowLinks then
        v.NumberOfLinks = far.GetNumberOfLinks(v.FileName)
      end
    end
  end
  if hScreen then far.RestoreScreen(hScreen) end
  return PanelItems
end


function Panel:ProcessRemoveKey (Handle)
  local tb_out, tb_dict = {}, {}
  local PInfo = assert(panel.GetPanelInfo (Handle))
  for i=1, PInfo.SelectedItemsNumber do
    local item = panel.GetSelectedPanelItem (Handle, i)
    tb_dict[item.FileName] = true
  end
  for _,v in ipairs(self:GetItems()) do
    if not tb_dict[v] then
      table.insert (tb_out, v)
    end
  end
  self:ReplaceFiles (tb_out)

  panel.UpdatePanel (Handle, true)
  panel.RedrawPanel (Handle)

  PInfo = assert(panel.GetPanelInfo (0))
  if PInfo.PanelType == F.PTYPE_QVIEWPANEL then
    panel.UpdatePanel (0, true)
    panel.RedrawPanel (0)
  end
end


function Panel:SaveListFile (Path)
  local hFile = io.open (Path, "wb")
  if hFile then
    for _,v in ipairs(self:GetItems()) do
      hFile:write (v, "\n")
    end
    hFile:close()
  else
    far.Message ("", M.MError, nil, "we")
  end
end


function Panel:ProcessSaveListKey (Handle)
  if #self:GetItems() == 0 then return end

  -- default path: opposite panel directory\panel<index>.<mask extension>
  local CurDir = panel.GetPanelDirectory(0)
  local ListPath = AddEndSlash (CurDir) .. "panel"
  if self.Index then
    ListPath = ListPath .. (self.Index - 1)
  end

  local ExtBuf = self.Opt.Mask:gsub(",.*", "")
  local ext = ExtBuf:match "%..-$"
  if ext and not ext:match "[*?]" then
    ListPath = ListPath .. ext
  end

  ListPath = far.InputBox (M.MTempPanel, M.MListFilePath,
      "TmpPanel.SaveList", ListPath, nil, nil, F.FIB_BUTTONS)
  if ListPath then
    self:SaveListFile (ListPath)
    panel.UpdatePanel (0, true)
    panel.RedrawPanel (0)
  end
end


do
  local VK = win.GetVirtualKeys()
  local C, A, S = F.PKF_CONTROL, F.PKF_ALT, F.PKF_SHIFT
  local PREPROCESS = F.PKF_PREPROCESS

  function Panel:ProcessKey (Handle, Key, ControlState)
    if band(Key, PREPROCESS) ~= 0 then
      return false
    end

    if ControlState == 0 and Key == VK.F1 then
      far.ShowHelp (far.PluginStartupInfo().ModuleName, nil,
        bor (F.FHELP_USECONTENTS, F.FHELP_NOSHOWERROR))
      return true
    end

    if ControlState == bor(A,S) and Key == VK.F9 then
       if export.Configure then export.Configure(0) end
       return true
    end

    if ControlState == bor(A,S) and Key == VK.F3 then
      local Ok, CurFileName = IsCurrentFileCorrect (Handle)
      if Ok then
        if CurFileName ~= ".." then
          local currItem = assert(panel.GetCurrentPanelItem (Handle))
          if IsDirectory (currItem) then
            panel.SetPanelDirectory (0, CurFileName)
          else
            GoToFile(CurFileName, 0)
          end
          panel.RedrawPanel (0)
          return true
        end
      end
    end

    if ControlState ~= C and (Key==VK.F3 or Key==VK.F4 or Key==VK.F5 or
                              Key==VK.F6 or Key==VK.F8) then
      if not IsCurrentFileCorrect (Handle) then
        return true
      end
    end

    if self.Opt.SafeModePanel and ControlState == C and Key == VK.PRIOR then
      local Ok, CurFileName = IsCurrentFileCorrect(Handle)
      if Ok and CurFileName ~= ".." then
        GoToFile(CurFileName, 1)
        return true
      end
      if CurFileName == ".." then
        panel.ClosePlugin(Handle, ".")
        return true
      end
    end

    if ControlState == 0 and Key == VK.F7 then
      self:ProcessRemoveKey (Handle)
      collectgarbage "collect"
      return true
    elseif ControlState == bor(A,S) and Key == VK.F2 then
      self:ProcessSaveListKey()
      return true
    else
      if self.Env.StartupOptCommonPanel and ControlState == bor(A,S) then
        if Key == VK.F12 then
          local index = self.Env:SelectPanelFromMenu()
          if index then
            self:SwitchToPanel (Handle, index)
          end
          return true
        elseif Key >= VK["0"] and Key <= VK["9"] then
          self:SwitchToPanel (Handle, Key - VK["0"] + 1)
          return true
        end
      end
    end
    return false
  end
end


function Panel:RemoveDuplicates ()
  local items = self:GetItems()
  local pat = "[\\/ ]+$"
  for _,v in ipairs(items) do
--far.Message(type(v))
    v = v:gsub(pat, "")
  end
  table.sort(items, SortListCmp)
  self.RemoveTable = {}
  for i = 1, #items - 1 do
    if items[i]:upper() == items[i+1]:upper() then
      self.RemoveTable[i] = true
    end
  end
  self:RemoveMarkedItems()
end


function Panel:CommitPutFiles (hRestoreScreen)
  far.RestoreScreen (hRestoreScreen)
end


function Panel:PutFiles (Handle, PanelItems, Move, OpMode)
  self.UpdateNeeded = true
  local hScreen = self:BeginPutFiles()
  for _,v in ipairs (PanelItems) do
    if not self:PutOneFile(v) then
      self:CommitPutFiles (hScreen)
      return false
    end
  end
  collectgarbage "collect"
  self:CommitPutFiles (hScreen)
  return true
end


function Panel:BeginPutFiles()
  self.SelectedCopyContents = self.Opt.CopyContents
  local hScreen = far.SaveScreen()
  far.Message (M.MTempSendFiles, M.MTempPanel, "")
  return hScreen
end


function Panel:PutOneFile (PanelItem)
  local CurName = PanelItem.FileName
  PanelItem = CheckForCorrect(CurName)
  if not PanelItem then return false end

  local NameOnly = not CurName:match("/")
  CurName = PanelItem.FileName
  if NameOnly then
    CurName = AddEndSlash (far.GetCurrentDirectory()) .. CurName
  end
  local items = self:GetItems()
  items[#items+1] = CurName

  if self.SelectedCopyContents ~= 0 and NameOnly and IsDirectory(PanelItem) then
    if self.SelectedCopyContents == 2 then
      local res = far.Message (M.MCopyContentsMsg, M.MWarning,
                            "Yes;No", "", "Config")
      self.SelectedCopyContents = (res == 1) and 1 or 0
    end
    if self.SelectedCopyContents ~= 0 then
      local DirPanelItems = far.GetDirList (CurName)
      if DirPanelItems then
        for _, v in ipairs (DirPanelItems) do
          items[#items+1] = v.FileName
        end
      else
        self:ReplaceFiles {}
        return false
      end
    end
  end
  return true
end


function Panel:GetFindData (Handle, OpMode)
--### far.Show("GetFindData")
  self:RemoveDuplicates()
  local types = panel.GetColumnTypes (Handle)
  local PanelItems = self:UpdateItems (IsOwnersDisplayed (types), IsLinksDisplayed (types))
  return PanelItems
end


function Panel:RemoveMarkedItems()
  if next(self.RemoveTable) then
    local tb = {}
    local items = self:GetItems()
    for i,v in ipairs(items) do
      if not self.RemoveTable[i] then table.insert (tb, v) end
    end
    self.RemoveTable = nil
    self:ReplaceFiles (tb)
  end
end


function Panel:ProcessEvent (Handle, Event, Param)
  if Event == F.FE_CHANGEVIEWMODE then
    local types = panel.GetColumnTypes (Handle)
    local UpdateOwners = IsOwnersDisplayed (types) and not self.LastOwnersRead
    local UpdateLinks = IsLinksDisplayed (types) and not self.LastLinksRead
    if UpdateOwners or UpdateLinks then
      self:UpdateItems (UpdateOwners, UpdateLinks)
      panel.UpdatePanel (Handle, true)
      panel.RedrawPanel (Handle)
    end
  end
  return false
end


local OPIF_SAFE_FLAGS, OPIF_COMMON_FLAGS do
  local f = F
  OPIF_SAFE_FLAGS = bor (f.OPIF_USEFILTER, f.OPIF_USESORTGROUPS,
                  f.OPIF_USEHIGHLIGHTING, f.OPIF_ADDDOTS, f.OPIF_SHOWNAMESONLY)
  OPIF_COMMON_FLAGS = bor (OPIF_SAFE_FLAGS, f.OPIF_REALNAMES,
                  f.OPIF_EXTERNALGET, f.OPIF_EXTERNALDELETE)
end

function Panel:GetOpenPluginInfo (Handle)
  -----------------------------------------------------------------------------
  --far.Message"GetOpenPluginInfo" --> this crashes FAR if enter then exit viewer/editor
                                   --  on a file in the emulated file system
  -----------------------------------------------------------------------------
  local Info = {
    Flags = self.Opt.SafeModePanel and OPIF_SAFE_FLAGS or OPIF_COMMON_FLAGS,
    Format = M.MTempPanel,
    CurDir = "",
  }
  if self.HostFile then
    local cur = panel.GetCurrentPanelItem(1)
    if cur and cur.FileName==".." then Info.HostFile=self.HostFile; end
  end
  -----------------------------------------------------------------------------
  local TitleMode = self.Opt.SafeModePanel and "(R) " or ""
  if self.Index then
    Info.PanelTitle = M.MTempPanelTitleNum : format(TitleMode, self.Index-1)
  else
    Info.PanelTitle = (" %s%s ") : format(TitleMode, M.MTempPanel)
  end
  -----------------------------------------------------------------------------
  local mode = {
    ColumnTypes = self.Opt.ColumnTypes,
    ColumnWidths = self.Opt.ColumnWidths,
    StatusColumnTypes = self.Opt.StatusColumnTypes,
    StatusColumnWidths = self.Opt.StatusColumnWidths,
    CaseConversion = true,
  }
  if self.Env.StartupOpenFrom == F.OPEN_COMMANDLINE then
    mode.FullScreen = self.Opt.FullScreenPanel
  else
    mode.FullScreen = self.Env.StartupOptFullScreenPanel
  end
  Info.PanelModesArray = { [5] = mode }
  Info.PanelModesNumber = 10
  Info.StartPanelMode = ("4"):byte()
  -----------------------------------------------------------------------------
  Info.KeyBar = {
    Titles = { [7] = M.MF7 },
    AltShiftTitles = { [2] = M.MAltShiftF2, [3] = M.MAltShiftF3,
      [12] = self.Env.StartupOptCommonPanel and M.MAltShiftF12 }
  }
  -----------------------------------------------------------------------------
  return Info
end


function Panel:SetDirectory (Handle, Dir, OpMode)
  if 0 == band(OpMode, F.OPM_FIND) then
    panel.ClosePlugin (Handle, (Dir ~= "/" and Dir or nil))
    return true
  end
end


function Panel:SetFindList (Handle, PanelItems)
  local hScreen = self:BeginPutFiles()
  if self.Index and self.Opt.NewPanelForSearchResults then
    self.Env.CurrentCommonPanel = self.Env:FindSearchResultsPanel()
    self.Index = self.Env.CurrentCommonPanel
  end
  local newfiles = {}
  for i,v in ipairs(PanelItems) do
    newfiles[i] = v.FileName
  end
  self:ReplaceFiles (newfiles)
  self:CommitPutFiles (hScreen)
  self.UpdateNeeded = true
  return true
end


function Panel:SwitchToPanel (Handle, Index)
  if Index and Index ~= self.Index then
    self.Env.CurrentCommonPanel = Index
    self.Index = self.Env.CurrentCommonPanel
    panel.UpdatePanel(Handle, true)
    panel.RedrawPanel(Handle)
  end
end


return Package
