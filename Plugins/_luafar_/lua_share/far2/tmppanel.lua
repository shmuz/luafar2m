-- tmppanel.lua

local M = require "tmpp_message"

local Package = {}

-- UPVALUES : keep them above all function definitions !!
local _Su     = require "sysutils"
local _Dialog = require "far2.dialog"

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
local OptMeta = { __index = Opt }
local Env = {}
local EnvMeta = { __index = Env }
local TmpPanelBase = {} -- "class" TmpPanelBase

local _Message = far.Message -- functions
local band, bor = bit.band, bit.bor

-- variables
local _F = far.Flags

-- constants
local COMMONPANELSNUMBER = 10
local BOM_UTF16LE = "\255\254"
local BOM_UTF8 = "\239\187\191"

local function LTrim(s) return s:match "^%s*(.*)" end
local function RTrim(s) return s:match "(.-)%s*$" end
local function Trim(s) return s:match "^%s*(.-)%s*$" end
local function Unquote(s) return (s:gsub("\"", "")) end
local function ExtractFileName(s) return s:match "[^\\:]*$" end
local function ExtractFileDir(s) return s:match ".*\\" or "" end
local function ExtractFileExt(s) return s:match "%.[^.\\]+$" or "" end
local function AddEndSlash(s) return (s:gsub("\\?$", "\\", 1)) end
local function TruncStr(s, maxlen)
  local len = s:len()
  return len <= maxlen and s or s:sub(1,6) .. "..." .. s:sub (len - maxlen + 10)
end

local function ExpandEnvironmentStr (str)
  return ( str:gsub("%%([^%%]*)%%", win.GetEnv) )
end

local function ShowTable (tbl, title)
  title = title or "Table View"
  local t, i = {}, 0
  for k,v in pairs(tbl) do
    i = i + 1
    t[i] = tostring(k) .. " = " .. tostring(v)
  end
  far.Message (table.concat(t, "\n"), title, "Ok", "l")
end


local function IsDirectory (PanelItem)
  return PanelItem.FileAttributes:find"d" and true
end


-- File lists are supported in the following formats:
-- (a) UTF-16LE with BOM, (b) UTF-8 with BOM, (c) OEM.
local function ReadFileList (filename)
  local list = {}
  local hFile = io.open (filename, "rb")
  if hFile then
    local text = hFile:read("*a")
    hFile:close()
    if text then
      local strsub = string.sub
      if strsub(text, 1, 3) == BOM_UTF8 then
        text = strsub(text, 4)
      elseif strsub(text, 1, 2) == BOM_UTF16LE then
        text = win.Utf16ToUtf8(strsub(text, 3))
      else -- (OEM assumed)
        text = win.OemToUtf8(text)
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

  if p:match "^\\\\%.\\%a%:$" or
     isDevice(p, "\\\\.\\PhysicalDrive") or
     isDevice(p, "\\\\.\\cdrom") then
    return { FileName = p, FileAttributes = "a"; }
  end

  if p:find "%S" and not p:find "[?*]" and p ~= "\\" and p ~= ".." then
    local q = p:gsub("\\$", "")
    local data = win.GetFileInfo(q)
    if data then
      data.FileName = p
      data.PackSize    = data.FileSize,
      data.Description = "One of my files",
      data.Owner       = "Joe Average",
      --data.UserData  = numline,
      --data.Flags     = { selected=true, },
      return data
    end
  end
end


local function IsCurrentFileCorrect (Handle)
  local fname = panel.GetCurrentPanelItem(Handle, 1).FileName
  local correct = (fname == "..") or (CheckForCorrect(fname) and true)
  return correct, fname
end


local function GoToFile (Target, PanelNumber)
  local Dir  = Unquote (Trim (ExtractFileDir (Target)))
  if Dir ~= "" then
    panel.SetPanelDir (nil, PanelNumber, Dir)
  end

  local PInfo = assert(panel.GetPanelInfo (nil, PanelNumber))
  local Name = Unquote (Trim (ExtractFileName (Target))):upper()
  for i=1, PInfo.ItemsNumber do
    local item = panel.GetPanelItem (nil, PanelNumber, i)
    if Name == ExtractFileName (item.FileName):upper() then
      panel.RedrawPanel (nil, PanelNumber, { CurrentItem=i, TopPanelItem=i })
      return
    end
  end
end


local function SortListCmp (Item1, Item2)
  return Item1:upper() < Item2:upper()
end


local function ShowMenuFromList (Name)
  local list = ReadFileList (Name)
  local menuitems, breakkeys = {}, {}
  for _, line in ipairs(list) do
    local TMP = ExpandEnvironmentStr(line)
    local part1, part2 = ParseParam(TMP)
    if part1 == "-" then
      table.insert(menuitems, {separator=true})
    else
      local menuline = TruncStr(part1 or part2, 67)
      table.insert (menuitems, {text=menuline, action=part2})
    end
  end
  table.insert(breakkeys, {BreakKey="S+RETURN"}) -- Shift+Enter

  local Title = ExtractFileName(Name):gsub("%.[^.]+$", "")
  Title = TruncStr(Title, 64)
  local Item, Position = far.Menu(
    { Flags = "FMENU_WRAPMODE", Title = Title, HelpTopic = "Contents",
      Bottom = #menuitems.." lines" },
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
        panel.SetPanelDir (nil, 1, Item.action)
      else
        bShellExecute = true
      end
    else
      panel.SetCmdLine (nil, Item.action)
    end
  end
  if bShellExecute then
    _Su.ShellExecute (nil, "open", Item.action, nil, nil, "SW_SHOW")
  end
end
--------------------------------------------------------------------------------

function Package.ListExportedFunctions()
  local t = {}
  for _, name in ipairs {
        "GetFindData", "GetOpenPluginInfo", "PutFiles", "SetDirectory",
        "ProcessEvent", "ProcessKey", "SetFindList", "ClosePlugin", } do
      t[name] = TmpPanelBase[name]
  end
  return t
end


function Package.NewEnv (aEnv)
  local self = aEnv or {}

  self.Opt = self.Opt or {}
  for k,v in pairs(Opt) do
    if self.Opt[k]==nil then self.Opt[k]=v end
  end
  self.OptMeta = { __index = self.Opt }
  self.LastSearchResultsPanel = self.LastSearchResultsPanel or 1
  self.StartupOptCommonPanel = self.Opt.CommonPanel
  self.StartupOptFullScreenPanel = self.Opt.FullScreenPanel

  if not self.CommonPanels then
    self.CommonPanels = {}
    for i=1,COMMONPANELSNUMBER do self.CommonPanels[i] = {} end
    self.CurrentCommonPanel = 1
  end

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
    local panel = self:NewPanel()
    panel:ProcessList (list, panel.Opt.ReplaceMode)
    return panel
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


function Env:ProcessPanelSwitchMenu()
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
    table.insert(menuitems, { text=menuline })
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
  local panel = {
    Env = self,
    LastOwnersRead = false,
    LastLinksRead = false,
    UpdateNeeded = true
  }

  panel.Opt = setmetatable({}, self.OptMeta)
  if aOptions then
    for k,v in pairs(aOptions) do panel.Opt[k] = v end
  end

  if self.StartupOptCommonPanel then
    panel.Index = self.CurrentCommonPanel
    panel.Items = TmpPanelBase.RefItems
    panel.ReplaceFiles = TmpPanelBase.ReplaceRefFiles
  else
    panel.Files = {}
    panel.Items = TmpPanelBase.OwnItems
    panel.ReplaceFiles = TmpPanelBase.ReplaceOwnFiles
  end
  return setmetatable (panel, { __index = TmpPanelBase })
end


function Env:OpenFilePlugin (Name, Data)
  if Name then
    for mask in self.Opt.Mask:gmatch "[^,]+" do
      if far.CmpName(mask, Name, true) then
        if self.Opt.MenuForFilelist then
          ShowMenuFromList(Name)
          break
        else
          local Panel = self:NewPanel()
          Panel:ProcessList (ReadFileList(Name), self.Opt.ReplaceMode)
          return Panel
        end
      end
    end
  end
end


function Env:OpenPlugin (OpenFrom, Item)
  -- if IsOldFAR then return nil end
  --  GetOptions (PluginRootKey)

  self.StartupOpenFrom = OpenFrom
  if OpenFrom == _F.OPEN_COMMANDLINE then
    local newOpt = setmetatable({}, OptMeta)
    local ParamsTable = {
      safe="SafeModePanel", replace="ReplaceMode", menu="MenuForFilelist",
      full="FullScreenPanel" }

    local argv = Item
    while #argv > 0 do
      local switch, param, rest = argv:match "^%s*([+-])(%S*)(.*)"
      if not switch then break end
      argv = rest
      param = param:lower()
      if ParamsTable[param] then
        newOpt[ParamsTable[param]] = (switch == "+")
      else
        local digit = param:sub(1,1):match "%d"
        if digit then
          self.CurrentCommonPanel = tonumber(digit) + 1
        end
      end
    end

    argv = Trim(argv)
    if #argv > 0 then
      if argv:sub(1,1) == "<" then
        argv = argv:sub(2)
        return self:OpenPanelFromOutput (argv)
      else
        argv = Unquote(argv)
        local TMP = ExpandEnvironmentStr(argv)
        local TmpPanelDir = ExtractFileDir(far.PluginStartupInfo().ModuleName)
        local PathName = _Su.SearchPath (TmpPanelDir, TMP) or
                         _Su.SearchPath (nil, TMP)
        if PathName then
          if newOpt.MenuForFilelist then
            ShowMenuFromList (PathName)
            return nil
          else
            local Panel = self:NewPanel(newOpt)
            Panel:ProcessList (ReadFileList(PathName), newOpt.ReplaceMode)
            return Panel
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
  local DIALOG_WIDTH = 78
  local DIALOG_HEIGHT = 22
  local DC = math.floor(DIALOG_WIDTH/2-1)

  local D = _Dialog.NewDialog()

  D._                = {"DI_DOUBLEBOX", 3,1,DIALOG_WIDTH-4,DIALOG_HEIGHT-2, 0,0,0,0, M.MConfigTitle}
  D.AddToDisksMenu   = {"DI_CHECKBOX",  5,2,0,0, 0,0,0,0, M.MConfigAddToDisksMenu}
  D.AddToPluginsMenu = {"DI_CHECKBOX", DC,2,0,0, 0,0,0,0, M.MConfigAddToPluginsMenu}
  D.separator        = {"DI_TEXT",      5,4,0,0, 0,0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, 0,""}

  D.CommonPanel     = {"DI_CHECKBOX",  5,5,0,0, 0,0,0,0, M.MConfigCommonPanel}
  D.SafeModePanel   = {"DI_CHECKBOX",  5,6,0,0, 0,0,0,0, M.MSafeModePanel}
--D.AnyInPanel      = {"DI_CHECKBOX",  5,7,0,0, 0,0,0,0, M.MAnyInPanel}
  D.CopyContents    = {"DI_CHECKBOX",  5,7,0,0, 0,0,"DIF_3STATE",0, M.MCopyContents}
  D.ReplaceMode     = {"DI_CHECKBOX", DC,5,0,0, 0,0,0,0, M.MReplaceInFilelist}
  D.MenuForFilelist = {"DI_CHECKBOX", DC,6,0,0, 0,0,0,0, M.MMenuForFilelist}
  D.NewPanelForSearchResults = {"DI_CHECKBOX", DC,7,0,0, 0,0,0,0, M.MNewPanelForSearchResults}
  D.SavePanels      = {"DI_CHECKBOX", DC,8,0,0, 0,0,0,0, M.MSavePanelsOnFarExit}
  D.separator       = {"DI_TEXT",      5,9,0,0, 0,0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, 0,""}

  D._                  = {"DI_TEXT",  5,10,0,0,   0,0,0,0, M.MColumnTypes}
  D.ColumnTypes        = {"DI_EDIT",  5,11,36,11, 0,0,0,0, ""}
  D._                  = {"DI_TEXT",  5,12,0,0,   0,0,0,0, M.MColumnWidths}
  D.ColumnWidths       = {"DI_EDIT",  5,13,36,13, 0,0,0,0, ""}
  D._                  = {"DI_TEXT", DC,10,0,0,   0,0,0,0, M.MStatusColumnTypes}
  D.StatusColumnTypes  = {"DI_EDIT", DC,11,72,11, 0,0,0,0, ""}
  D._                  = {"DI_TEXT", DC,12,0,0,   0,0,0,0, M.MStatusColumnWidths}
  D.StatusColumnWidths = {"DI_EDIT", DC,13,72,13, 0,0,0,0, ""}
  D.FullScreenPanel    = {"DI_CHECKBOX",  5,14,0,0,   0,0,0,0, M.MFullScreenPanel}
  D.separator          = {"DI_TEXT",  5,15,0,0, 0,0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, 0,""}

  D._         = {"DI_TEXT",   5,16,0,0,   0,0,0,0, M.MMask}
  D.Mask      = {"DI_EDIT",   5,17,36,17, 0,0,0,0, ""}
  D._         = {"DI_TEXT",  DC,16,0,0,   0,0,0,0, M.MPrefix}
  D.Prefix    = {"DI_EDIT",  DC,17,72,17, 0,0,0,0, ""}
  D.separator = {"DI_TEXT",   5,18,0,0, 0,0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, 0,""}

  D.btnOk     = {"DI_BUTTON", 0,19,0, 0,  0, 0,  "DIF_CENTERGROUP", 1, M.MOk}
  D.btnCancel = {"DI_BUTTON", 0,19,0, 0,  0, 0,  "DIF_CENTERGROUP", 0, M.MCancel}

  for k,v in pairs (self.Opt) do
    if D[k] then
      if D[k].Type == "DI_CHECKBOX" then
        D[k].Selected = v==true and 1 or tonumber(v) or 0
      elseif D[k].Type == "DI_EDIT" then
        D[k].Data = v
      end
    end
  end

  local ret = far.Dialog (-1, -1, DIALOG_WIDTH, DIALOG_HEIGHT, "Config", D)
  if ret ~= D.btnOk.id then return false end

  for k,v in pairs (self.Opt) do
    if D[k] then
      if D[k].Type == "DI_CHECKBOX" then
        self.Opt[k] = D[k].Selected~=0 and D[k].Selected
      elseif D[k].Type == "DI_EDIT" then
        self.Opt[k] = Trim (D[k].Data)
      end
    end
  end

  if self.StartupOptFullScreenPanel ~= self.Opt.FullScreenPanel or
    self.StartupOptCommonPanel ~= self.Opt.CommonPanel
  then
    far.Message (M.MConfigNewOption, M.MTempPanel, M.MOk)
  end
  return true
end
--------------------------------------------------------------------------------

function TmpPanelBase:OwnItems() return self.Files end
function TmpPanelBase:RefItems() return self.Env.CommonPanels[self.Index] end
function TmpPanelBase:ReplaceOwnFiles(Table) self.Files = Table end
function TmpPanelBase:ReplaceRefFiles(Table)
  self.Env.CommonPanels[self.Index] = Table
end


function TmpPanelBase:ClosePlugin (Handle)
  collectgarbage "collect"
end


function TmpPanelBase:ProcessList (aList, aReplaceMode)
  if aReplaceMode then self:ReplaceFiles {} end
  local items = self:Items()
  for _,v in ipairs(aList) do
    local dir, name = v:match("^(.*[\\/])(.*)$")
    if not dir then dir, name = ".", v end
    far.FarRecursiveSearch(dir, name, function(_, fullname)
        if fullname:sub(-1) ~= "." then items[#items+1] = fullname end
        return true
      end)
  end
end


function TmpPanelBase:UpdateItems (ShowOwners, ShowLinks)
--~   if not self.UpdateNeeded or #self:Items() == 0 then
--~     self.UpdateNeeded = true
--~     return
--~   end

  local hScreen = far.SaveScreen()
  _Message (M.MTempUpdate, M.MTempPanel, "")

  self.LastOwnersRead = ShowOwners
  self.LastLinksRead = ShowLinks
  self.RemoveTable = {}
  local PanelItems = {}
  local items = self:Items()
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
  far.RestoreScreen(hScreen)
  return PanelItems
end


function TmpPanelBase:ProcessRemoveKey (Handle)
  local tb_out, tb_dict = {}, {}
  local PInfo = assert(panel.GetPanelInfo (Handle, 1))
  for i=1, PInfo.SelectedItemsNumber do
    local item = panel.GetSelectedPanelItem (Handle, 1, i)
    tb_dict[item.FileName] = true
  end
  for _,v in ipairs(self:Items()) do
    if not tb_dict[v] then
      table.insert (tb_out, v)
    end
  end
  self:ReplaceFiles (tb_out)

  panel.UpdatePanel (Handle, 1, true)
  panel.RedrawPanel (Handle, 1)

  PInfo = assert(panel.GetPanelInfo (Handle, 0))
  if PInfo.PanelType == _F.PTYPE_QVIEWPANEL then
    panel.UpdatePanel (Handle, 0, true)
    panel.RedrawPanel (Handle, 0)
  end
end


function TmpPanelBase:SaveListFile (Path)
  local hFile = io.open (Path, "wb")
  if hFile then
    local NEWLINE = win.Utf8ToUtf16("\n")
    hFile:write(BOM_UTF16LE)
    for _,v in ipairs(self:Items()) do
      hFile:write (win.Utf8ToUtf16(v), NEWLINE)
    end
    hFile:close()
  else
    _Message ("", M.MError, nil, "we")
  end
end


function TmpPanelBase:ProcessSaveListKey (Handle)
  if #self:Items() == 0 then return end

  -- default path: opposite panel directory\panel<index>.<mask extension>
  local CurDir = panel.GetPanelDir(Handle, 0)
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
      "TmpPanel.SaveList", ListPath, nil, nil, _F.FIB_BUTTONS)
  if ListPath then
    self:SaveListFile (ListPath)
    panel.UpdatePanel (Handle, 0, true)
    panel.RedrawPanel (Handle, 0)
  end
end


do
  local VK = win.GetVirtualKeys()
  local C, A, S = _F.PKF_CONTROL, _F.PKF_ALT, _F.PKF_SHIFT
  local PREPROCESS = _F.PKF_PREPROCESS

  function TmpPanelBase:ProcessKey (Handle, Key, ControlState)
    if band(Key, PREPROCESS) ~= 0 then
      return false
    end

    if ControlState == 0 and Key == VK.F1 then
      far.ShowHelp (far.PluginStartupInfo().ModuleName, nil,
        bor (_F.FHELP_USECONTENTS, _F.FHELP_NOSHOWERROR))
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
          local currItem = assert(panel.GetCurrentPanelItem (Handle, 1))
          if IsDirectory (currItem) then
            panel.SetPanelDir (nil, 2, CurFileName)
          else
            GoToFile(CurFileName, 2)
          end
          panel.RedrawPanel (nil, 2)
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
          local index = self.Env:ProcessPanelSwitchMenu()
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


function TmpPanelBase:RemoveDuplicates ()
  local items = self:Items()
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


function TmpPanelBase:CommitPutFiles (hRestoreScreen)
  far.RestoreScreen (hRestoreScreen)
end


function TmpPanelBase:PutFiles (Handle, PanelItems, Move, OpMode)
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


function TmpPanelBase:BeginPutFiles()
  self.SelectedCopyContents = self.Opt.CopyContents
  local hScreen = far.SaveScreen()
  _Message (M.MTempSendFiles, M.MTempPanel, "")
  return hScreen
end


function TmpPanelBase:PutOneFile (PanelItem)
  local CurName = PanelItem.FileName
  PanelItem = CheckForCorrect(CurName)
  if not PanelItem then return false end

  local NameOnly = not CurName:match("\\")
  CurName = PanelItem.FileName
  if NameOnly then
    CurName = AddEndSlash (far.GetCurrentDirectory()) .. CurName
  end
  local items = self:Items()
  items[#items+1] = CurName

  if self.SelectedCopyContents ~= 0 and NameOnly and IsDirectory(PanelItem) then
    if self.SelectedCopyContents == 2 then
      local res = _Message (M.MCopyContentsMsg, M.MWarning,
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


function TmpPanelBase:GetFindData (Handle, OpMode)
  self:RemoveDuplicates()
  local types = panel.GetColumnTypes (Handle, 1)
  local PanelItems = self:UpdateItems (IsOwnersDisplayed (types), IsLinksDisplayed (types))
  return PanelItems
end


function TmpPanelBase:RemoveMarkedItems()
  if next(self.RemoveTable) then
    local tb = {}
    local items = self:Items()
    for i,v in ipairs(items) do
      if not self.RemoveTable[i] then table.insert (tb, v) end
    end
    self.RemoveTable = nil
    self:ReplaceFiles (tb)
  end
end


function TmpPanelBase:ProcessEvent (Handle, Event, Param)
  if Event == _F.FE_CHANGEVIEWMODE then
    local types = panel.GetColumnTypes (Handle, 1)
    local UpdateOwners = IsOwnersDisplayed (types) and not self.LastOwnersRead
    local UpdateLinks = IsLinksDisplayed (types) and not self.LastLinksRead
    if UpdateOwners or UpdateLinks then
      self:UpdateItems (UpdateOwners, UpdateLinks)
      panel.UpdatePanel (Handle, 1, true)
      panel.RedrawPanel (Handle, 1)
    end
  end
  return false
end


local OPIF_SAFE_FLAGS, OPIF_COMMON_FLAGS do
  local f = _F
  OPIF_SAFE_FLAGS = bor (f.OPIF_USEFILTER, f.OPIF_USESORTGROUPS,
                  f.OPIF_USEHIGHLIGHTING, f.OPIF_ADDDOTS, f.OPIF_SHOWNAMESONLY)
  OPIF_COMMON_FLAGS = bor (OPIF_SAFE_FLAGS, f.OPIF_REALNAMES,
                  f.OPIF_EXTERNALGET, f.OPIF_EXTERNALDELETE)
end

function TmpPanelBase:GetOpenPluginInfo (Handle)
  -----------------------------------------------------------------------------
  --far.Message"GetOpenPluginInfo" --> this crashes FAR if enter then exit viewer/editor
                                   --  on a file in the emulated file system
  -----------------------------------------------------------------------------
  local Info = {
    Flags = self.Opt.SafeModePanel and OPIF_SAFE_FLAGS or OPIF_COMMON_FLAGS,
    Format = M.MTempPanel,
    CurDir = "",
  }
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
  if self.Env.StartupOpenFrom == _F.OPEN_COMMANDLINE then
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


function TmpPanelBase:SetDirectory (Handle, Dir, OpMode)
  if 0 == band(OpMode, _F.OPM_FIND) then
    panel.ClosePlugin (Handle, (Dir ~= "\\" and Dir or nil))
    return true
  end
end


function TmpPanelBase:SetFindList (Handle, PanelItems)
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


function TmpPanelBase:SwitchToPanel (Handle, Index)
  if Index and Index ~= self.Index then
    self.Env.CurrentCommonPanel = Index
    self.Index = self.Env.CurrentCommonPanel
    panel.UpdatePanel(Handle, 1, true)
    panel.RedrawPanel(Handle, 1)
  end
end


return Package
