-- lfs_panels.lua
-- luacheck: globals _Plugin

local M         = require "lfs_message"
local libCommon = require "lfs_common"
local libReader = require "reader"
local sd        = require "far2.simpledialog"

local libTmpPanel = require "far2.tmppanel"
libTmpPanel.SetMessageTable(M) -- message localization support

local CheckSearchArea    = libCommon.CheckSearchArea
local CreateSRFrame      = libCommon.CreateSRFrame
local DisplaySearchState = libCommon.DisplaySearchState
local GetSearchAreas     = libCommon.GetSearchAreas
local IndexToSearchArea  = libCommon.IndexToSearchArea
local NewUserBreak       = libCommon.NewUserBreak
local ProcessDialogData  = libCommon.ProcessDialogData
local SaveCodePageCombo  = libCommon.SaveCodePageCombo

local Excl_Key = "sExcludeDirs"

local F = far.Flags
local bor, band, bxor = bit64.bor, bit64.band, bit64.bxor
local MultiByteToWideChar = win.MultiByteToWideChar

local dirsep = package.config:sub(1,1)

local TmpPanelDefaults = {
  CopyContents             = 0,
  ReplaceMode              = true,
  NewPanelForSearchResults = true,
  ColumnTypes              = "NR,S",
  ColumnWidths             = "0,8",
  StatusColumnTypes        = "NR,SC,D,T",
  StatusColumnWidths       = "0,8,0,5",
  FullScreenPanel          = false,
  StartSorting             = "12,0", -- sort by full name
  PreserveContents         = true,
}

local KEY_INS     = F.KEY_INS
local KEY_NUMPAD0 = F.KEY_NUMPAD0
local KEY_SPACE   = F.KEY_SPACE

local function SwapEndian (str)
  return (string.gsub(str, "(.)(.)(.)(.)", "%4%3%2%1"))
end

local function ConfigDialog()
  local aData = _Plugin.History["tmppanel"]
  local W1 = 33
  local DC = (5+W1) + 2

  local Items = {
    width = (5+W1)*2 + 2;
    help = "SearchResultsPanel";
    { tp="dbox";  text=M.MConfigTitleTmpPanel;   },
    { tp="text";  text=M.MColumnTypes;           },
    { tp="edit";  name="ColumnTypes";  width=W1; },
    { tp="text";  text=M.MColumnWidths;          },
    { tp="edit";  name="ColumnWidths"; width=W1; },
    { tp="text";  text=M.MStartSorting;          },
    { tp="edit";  name="StartSorting"; width=W1; },

    { tp="text";  text=M.MStatusColumnTypes;  x1=DC; y1=2; },
    { tp="edit";  name="StatusColumnTypes";   x1=DC;       },
    { tp="text";  text=M.MStatusColumnWidths; x1=DC;       },
    { tp="edit";  name="StatusColumnWidths";  x1=DC;       },
    { tp="chbox"; name="FullScreenPanel";  text=M.MFullScreenPanel;  x1=DC; ystep=2; },
    { tp="chbox"; name="PreserveContents"; text=M.MPreserveContents; x1=DC; },
    { tp="sep"; },

    { tp="butt"; centergroup=1; text=M.MOk; default=1;    },
    { tp="butt"; centergroup=1; text=M.MCancel; cancel=1; },
    { tp="butt"; centergroup=1; text=M.MBtnDefaults; btnnoclose=1; name="reset"; },
  }
  local Pos = sd.Indexes(Items)

  Items[Pos.reset].action = function(hDlg,Par1,Par2)
    for i,v in ipairs(Items) do
      if v.name then
        local val = TmpPanelDefaults[v.name]
        if val ~= nil then
          if     v.tp == "edit"  then hDlg:SetText(i, val)
          elseif v.tp == "chbox" then hDlg:SetCheck(i, val)
          end
        end
      end
    end
  end

  sd.LoadData (aData, Items)
  local out = sd.Run(Items)
  if out then
    sd.SaveData (out, aData)
    return true
  end
end

local function DirFilterDialog (aData)
  local Items = {
    guid = "92E8DEC3-ACE2-4E1F-B6A5-AF447EDE21B8";
    help = "DirFilter";
    width = 76;
    --help = "SearchResultsPanel";
    { tp="dbox"; text=M.MDirFilterTitle; },
    { tp="text"; text=M.MExcludeDirsLabel; },
    { tp="edit"; name=Excl_Key; hist="LFS_Excl_Dirs"},
    { tp="sep"; },
    { tp="butt"; text=M.MOk; default=1; centergroup=1; },
    { tp="butt"; text=M.MCancel; cancel=1; centergroup=1; },
  }
  sd.LoadData(aData, Items)
  local out = sd.Run(Items)
  if out then
    local s = out[Excl_Key]:match("^%s*(.-)%s*$")
    out[Excl_Key] = (s ~= "") and s -- false is OK, nil is not as it does not erase the existing value
    sd.SaveData(out, aData)
    return true
  end
end

local function GetCodePages (aData)
  local Checked = {}
  if aData.tCheckedCodePages then
    for _,v in ipairs(aData.tCheckedCodePages) do Checked[v]=true end
  end
  local delim = ("").char(9474)
  local function makeline(codepage, name)
    return ("%5d %s %s"):format(codepage, delim, name)
  end
  local function split_cpname (cpname)
    local cp, text = cpname:match("^(%d+)%s+%((.+)%)$")
    if cp then return tonumber(cp), text end
  end

  local items = {
    SelectIndex = 1,
    { Text = M.MDefaultCodePages, CodePage = -1 },
    { Text = M.MCheckedCodePages, CodePage = -2 },
    ---------------------------------------------------------------------------
    { Text = M.MSystemCodePages,  Flags = F.LIF_SEPARATOR },
    { CodePage = win.GetOEMCP() },
    { CodePage = win.GetACP() },
    ---------------------------------------------------------------------------
    { Text = M.MUnicodeCodePages, Flags = F.LIF_SEPARATOR },
    { CodePage = 61200, Text = makeline(61200, "UTF-32 (Little endian)") },
    { CodePage = 61201, Text = makeline(61201, "UTF-32 (Big endian)") },
    { CodePage = 65000 },
    { CodePage = 65001 },
    ---------------------------------------------------------------------------
    { Text = M.MOtherCodePages,   Flags = F.LIF_SEPARATOR },
  }

  -- Fill predefined code pages
  local used = {}
  for _,v in ipairs(items) do
    if v.CodePage then
      used[v.CodePage] = true
      local info = win.GetCPInfo(v.CodePage)
      if info then
        local num, name = split_cpname(info.CodePageName)
        v.Text = num and makeline(num,name) or makeline(v.CodePage,info.CodePageName)
      end
      if Checked[v.CodePage] then v.Flags = bor(v.Flags or 0, F.LIF_CHECKED) end
      if v.CodePage == aData.iSelectedCodePage then
        v.Flags = bor(v.Flags or 0, F.LIF_SELECTED)
        items.SelectIndex = nil
      end
    end
  end

  -- Add code pages found in the system
  local pages = assert(win.EnumSystemCodePages())
  for i,v in ipairs(pages) do pages[i]=tonumber(v) end
  table.sort(pages)
  for _,v in ipairs(pages) do
    if not used[v] then
      local info = win.GetCPInfo(v)
      if info and info.MaxCharSize == 1 then
        local num, name = split_cpname(info.CodePageName)
        local item = { CodePage=v }
        item.Text = num and makeline(num,name) or makeline(v,info.CodePageName)
        items[#items+1] = item
        if Checked[v] then
          item.Flags = bor(item.Flags or 0, F.LIF_CHECKED)
        end
        if v == aData.iSelectedCodePage then
          item.Flags = bor(item.Flags or 0, F.LIF_SELECTED)
          items.SelectIndex = nil
        end
      end
    end
  end

  return items
end

local searchGuid  = "3CD8A0BB-8583-4769-BBBC-5B6667D13EF9"
local replaceGuid = "F7118D4A-FBC3-482E-A462-0167DF7CC346"
local grepGuid    = "74D7F486-487D-40D0-9B25-B2BB06171D86"

local function PanelDialog  (aOp, aData, aScriptCall)
  local insert = table.insert
  local Items = {
    width = 76;
    help = "OperInPanels";
    guid = aOp=="search" and searchGuid or aOp=="replace" and replaceGuid or grepGuid;
  }
  local Frame = CreateSRFrame(Items, aData, false)
  ------------------------------------------------------------------------------
  insert(Items, { tp="dbox"; text=M.MTitlePanels; })
  insert(Items, { tp="text"; text=M.MFileMask; })
  insert(Items, { tp="edit"; name="sFileMask"; hist="Masks"; uselasthistory=1; })
  ------------------------------------------------------------------------------
  Frame:InsertInDialog(true, aOp)
  ------------------------------------------------------------------------------
  local X2 = 40 + M.MDlgUseFileFilter:gsub("&",""):len() + 5
  insert(Items, { tp="sep"; })
  insert(Items, { tp="text"; text=M.MDlgCodePages; })
  insert(Items, { tp="combobox"; name="cmbCodePage"; list=GetCodePages(aData); dropdownlist=1; noauto=1; })
  insert(Items, { tp="text"; text=M.MSearchArea; })
  insert(Items, { tp="combobox"; name="cmbSearchArea"; list=GetSearchAreas(aData); x2=36; dropdownlist=1; noauto=1; })
  insert(Items, { tp="chbox"; name="bSearchFolders"; text=M.MSearchFolders; ystep=-1; x1=40; })
  insert(Items, { tp="chbox"; name="bSearchSymLinks"; text=M.MSearchSymLinks;   x1=40; })
  insert(Items, { tp="chbox"; name="bUseFileFilter";  text=M.MDlgUseFileFilter; x1=40; })
  insert(Items, { tp="butt";  name="btnFileFilter";   text=M.MDlgBtnFileFilter; x1=X2; y1=""; btnnoclose=1; })
  insert(Items, { tp="sep"; })
  insert(Items, { tp="butt"; centergroup=1; text=M.MOk; default=1; name="btnOk";        })
  insert(Items, { tp="butt"; centergroup=1; text=M.MBtnDirFilter;  name="btnDirFilter"; btnnoclose=1; })
  insert(Items, { tp="butt"; centergroup=1; text=M.MDlgBtnPresets; name="btnPresets";   btnnoclose=1; })
  insert(Items, { tp="butt"; centergroup=1; text=M.MDlgBtnConfig;  name="btnConfig";    btnnoclose=1; })
  insert(Items, { tp="butt"; centergroup=1; text=M.MCancel; cancel=1; })
  ------------------------------------------------------------------------------
  local Pos,Elem = sd.Indexes(Items)

  local function SetBtnFilterText(hDlg)
    hDlg:SetText(Pos.btnDirFilter, M.MBtnDirFilter..(aData[Excl_Key] and "*" or ""))
  end

  function Items.proc (hDlg, msg, param1, param2)
    local NeedCallFrame = true
    --------------------------------------------------------------------------------------
    if msg == F.DN_INITDIALOG then
      SetBtnFilterText(hDlg)
      hDlg:SetComboboxEvent(Pos.cmbCodePage, F.CBET_KEY)
      local t = {}
      for i,v in ipairs(Elem.cmbCodePage.list) do
        if v.CodePage then
          t.Index, t.Data = i, v.CodePage
          hDlg:ListSetData(Pos.cmbCodePage, t)
        end
      end
      hDlg:SetText  (Pos.sFileMask,       aData.sFileMask or "")
      hDlg:SetCheck (Pos.bSearchFolders,  aData.bSearchFolders)
      hDlg:SetCheck (Pos.bSearchSymLinks, aData.bSearchSymLinks)
      hDlg:SetCheck (Pos.bUseFileFilter,  aData.bUseFileFilter)
      hDlg:Enable   (Pos.btnFileFilter,   aData.bUseFileFilter)
    --------------------------------------------------------------------------------------
    elseif msg == F.DN_BTNCLICK then
      if param1 == Pos.bUseFileFilter then
        hDlg:Enable(Pos.btnFileFilter, hDlg:GetCheck(Pos.bUseFileFilter))
      elseif param1 == Pos.btnFileFilter then
        local filter = far.CreateFileFilter(1, "FFT_FINDFILE")
        if filter and filter:OpenFiltersMenu() then aData.FileFilter = filter end
      elseif param1 == Pos.btnPresets then
        Frame:DoPresets(hDlg)
        hDlg:SetFocus(Pos.btnOk)
      elseif param1 == Pos.btnDirFilter then
        hDlg:ShowDialog(0)
        if DirFilterDialog(aData) then
          SetBtnFilterText(hDlg)
        end
        hDlg:ShowDialog(1)
        hDlg:SetFocus(Pos.btnOk)
      elseif param1 == Pos.btnConfig then
        hDlg:ShowDialog(0)
        ConfigDialog()
        hDlg:ShowDialog(1)
        hDlg:SetFocus(Pos.btnOk)
      end
    --------------------------------------------------------------------------------------
    elseif msg == F.DN_KEY then
      if param1 == Pos.cmbCodePage then
        if param2==KEY_INS or param2==KEY_NUMPAD0 or param2==KEY_SPACE then
          local pos = hDlg:ListGetCurPos(param1)
          if pos.SelectPos > 2 then -- if not ("Default code pages" or "Checked code pages")
            local item = hDlg:ListGetItem(param1, pos.SelectPos)
            item.Flags = bxor(item.Flags, F.LIF_CHECKED)
            item.Index = pos.SelectPos
            hDlg:ListUpdate(param1, item)
          end
        end
      end
    --------------------------------------------------------------------------------------
    elseif msg == F.DN_CLOSE then
      if param1 == Pos.btnOk then
        if not hDlg:GetText(Pos.sFileMask):find("%S") then
          far.Message(M.MInvalidFileMask, M.MError, ";Ok", "w")
          return 0
        end
        ------------------------------------------------------------------------
        local pos = hDlg:ListGetCurPos(Pos.cmbCodePage)
        aData.iSelectedCodePage = Elem.cmbCodePage.list[pos.SelectPos].CodePage
        ------------------------------------------------------------------------
        pos = hDlg:ListGetCurPos(Pos.cmbSearchArea)
        aData.sSearchArea = IndexToSearchArea(pos.SelectPos)
        ------------------------------------------------------------------------
        aData.sFileMask       = hDlg:GetText(Pos.sFileMask)
        aData.bSearchFolders  = hDlg:GetCheck(Pos.bSearchFolders)
        aData.bSearchSymLinks = hDlg:GetCheck(Pos.bSearchSymLinks)
        aData.bUseFileFilter  = hDlg:GetCheck(Pos.bUseFileFilter)
      end
      --------------------------------------------------------------------------
      -- store selected code pages no matter what user pressed: OK or Esc.
      if Pos.cmbCodePage then
        SaveCodePageCombo(hDlg, Pos.cmbCodePage, Elem.cmbCodePage.list, aData, param1==Pos.btnOk)
      end
      --------------------------------------------------------------------------
    end
    if NeedCallFrame then
      return Frame:DlgProc(hDlg, msg, param1, param2)
    end
  end

  local dataTP = _Plugin.History.tmppanel
  for k,v in pairs(TmpPanelDefaults) do
    if dataTP[k] == nil then dataTP[k] = v end
  end
  sd.LoadData(aData, Items)
  Frame:OnDataLoaded(aData, false)
  return sd.Run(Items) and Frame.close_params
end

local function MakeItemList (panelInfo, searchArea)
  local bRealNames = (band(panelInfo.Flags, F.PFLAGS_REALNAMES) ~= 0)
  local panelDir = panel.GetPanelDirectory(1) or ""
  local itemList, flags = {}, F.FRS_RECUR

  if searchArea == "FromCurrFolder" or searchArea == "OnlyCurrFolder" then
    if bRealNames then
      if panelInfo.Plugin then
        for i=1, panelInfo.ItemsNumber do
          local name = panel.GetPanelItem(1, i).FileName
          if name ~= ".." and name ~= "." then
            itemList[#itemList+1] = name
          end
        end
      else
        itemList[1] = panelDir
      end
      if searchArea == "OnlyCurrFolder" then
        flags = 0
      end
    end

  elseif searchArea == "SelectedItems" then
    if bRealNames then
      local curdir_slash = panelInfo.Plugin and "" or panelDir:gsub(dirsep.."?$", dirsep, 1)
      for i=1, panelInfo.SelectedItemsNumber do
        local item = panel.GetSelectedPanelItem(1, i)
        itemList[#itemList+1] = curdir_slash .. item.FileName
      end
    end

  elseif searchArea == "RootFolder" then
    itemList[1] = panelDir:match("/[^/]*")

  elseif searchArea == "PathFolders" then
    flags = 0
    local path = win.GetEnv("PATH")
    if path then path:gsub("[^:]+", function(c) itemList[#itemList+1]=c end) end
  end
  return itemList, flags
end

local function GetActiveCodePages (aData)
  if aData.iSelectedCodePage then
    if aData.iSelectedCodePage > 0 then
      return { aData.iSelectedCodePage }
    elseif aData.iSelectedCodePage == -2 then
      local t = aData.tCheckedCodePages
      if t and t[1] then return t end
    end
  end
  return { win.GetOEMCP(), win.GetACP(), 61200, 61201, 65000, 65001 }
end

local function CheckBoms (str)
  if str then
    local find = string.find
    if     find(str, "^%z%z\254\255") then return { 61201 }, 4 -- UTF32BE
    elseif find(str, "^\255\254%z%z") then return { 61200 }, 4 -- UTF32LE
    elseif find(str, "^%+/v[89+/]")   then return { 65000 }, 4 -- UTF7
    elseif find(str, "^\239\187\191") then return { 65001 }, 3 -- UTF8
    end
  end
end

local function SearchFromPanel (aData, aWithDialog, aScriptCall)
  local tParams
  if aWithDialog then
    tParams = PanelDialog("search", aData, aScriptCall)
  else
    tParams = ProcessDialogData(aData, false, false, true)
  end
  if not tParams then return end
  ----------------------------------------------------------------------------

  -- take care of the future "repeat" operations in the Editor
  aData.sLastOp = "search"
  aData.bSearchBack = false
  ----------------------------------------------------------------------------
  local activeCodePages = GetActiveCodePages(aData)
  local userbreak = NewUserBreak()
  local tFoundFiles, nTotalFiles = {}, 0
  local Regex = tParams.Regex
  local Find = Regex.find
  local bTextSearch = (tParams.tMultiPatterns and tParams.tMultiPatterns.NumPatterns > 0) or
                      (not tParams.tMultiPatterns and tParams.sSearchPat ~= "")
  local bAcceptFolders = aData.bSearchFolders and not bTextSearch
  local reader = bTextSearch and assert(libReader.new(4*1024*1024)) -- (default = 4 MiB)

  local panelInfo = panel.GetPanelInfo(1)
  local area = CheckSearchArea(aData.sSearchArea) -- can throw error
  local itemList, flags = MakeItemList(panelInfo, area)
  local bRecurse = band(flags, F.FRS_RECUR) ~= 0
  local bSymLinks = aData.bSearchSymLinks

  -----------------------------------------------------------------------------
  local function Search_ProcessFile(fdata, fullname, file_filter, mask_files, mask_dirs)
    ---------------------------------------------------------------------------
    if file_filter and not file_filter:IsFileInFilter(fdata) then return end
    ---------------------------------------------------------------------------
    local mask_ok = far.ProcessName(F.PN_CMPNAMELIST, mask_files, fdata.FileName, F.PN_SKIPPATH)
    ---------------------------------------------------------------------------
    if fdata.FileAttributes:find("d") then
      if mask_ok and bAcceptFolders then
        nTotalFiles = nTotalFiles + 1
        table.insert(tFoundFiles, fullname)
      end

      if bRecurse then
        local skip = mask_dirs and far.ProcessName(F.PN_CMPNAMELIST, mask_dirs, fdata.FileName, F.PN_SKIPPATH)
                     or not bSymLinks and fdata.FileAttributes:find("e")
        if not skip then
          return far.RecursiveSearch(fullname, "*", Search_ProcessFile, 0, file_filter, mask_files, mask_dirs)
        end
      end

      return DisplaySearchState(fullname, #tFoundFiles, nTotalFiles, 0, userbreak) and "break"
    end
    ---------------------------------------------------------------------------
    if not mask_ok then return end
    nTotalFiles = nTotalFiles + 1
    if not bTextSearch then table.insert(tFoundFiles, fullname) end
    if DisplaySearchState(fullname, #tFoundFiles, nTotalFiles, 0, userbreak) then return "break" end
    if not bTextSearch then return end
    if not reader:openfile(fullname) then return end
    ---------------------------------------------------------------------------
    local str = reader:get_next_overlapped_chunk()
    local currCodePages, len = CheckBoms(str)
    if currCodePages then
      str = string.sub(str, len+1)
    else
      currCodePages = activeCodePages
    end
    ---------------------------------------------------------------------------
    local found, stop
    local tPlus, uMinus, uUsual
    if tParams.tMultiPatterns then
      local t = tParams.tMultiPatterns
      uMinus, uUsual = t.Minus, t.Usual -- copy; do not modify the original table fields!
      tPlus = {}; for k,v in pairs(t.Plus) do tPlus[k]=v end -- copy; do not use the original table directly!
    end

    while str do
      if userbreak:ConfirmEscape("in_file") then
        reader:closefile()
        return userbreak.fullcancel and "break"
      end
      for _, cp in ipairs(currCodePages) do
        local s = (cp == 61200 or cp == 65001) and str or
                  (cp == 61201) and SwapEndian(str) or
                  MultiByteToWideChar(str, cp)
        if s then
          if cp ~= 65001 then
            s = win.Utf32ToUtf8(s)
          end
          if s then
            local ok, start
            if tPlus == nil then
              ok, start = pcall(Find, Regex, s)
              if ok and start then found = true; break; end
            else
              if uMinus then
                ok, start = pcall(Find, uMinus, s)
                if ok and start then
                  stop=true; break
                end
              end
              for pattern in pairs(tPlus) do
                ok, start = pcall(Find, pattern, s)
                if ok and start then tPlus[pattern]=nil end
              end
              if uUsual then
                ok, start = pcall(Find, uUsual, s)
                if ok and start then uUsual=nil end
              end
              if not (next(tPlus) or uMinus or uUsual) then
                found=true; break
              end
            end
          end
        end
      end
      if found or stop then
        break
      end
      if fdata.FileSize >= 0x100000 then
        local pos = reader:ftell()
        DisplaySearchState(fullname, #tFoundFiles, nTotalFiles, pos/fdata.FileSize)
      end
      if #str > 0x100000 then
        str = nil; collectgarbage("collect") -- luacheck: ignore (overwritten before use)
      end
      str = reader:get_next_overlapped_chunk()
    end
    if tPlus then
      found = found or not (stop or next(tPlus) or uUsual)
    end
    if not found ~= not tParams.bInverseSearch then
      table.insert(tFoundFiles, fullname)
    end
    reader:closefile()
  end

  local hScreen = far.SaveScreen()
  DisplaySearchState("", 0, 0, 0)

  local FileFilter = tParams.FileFilter
  if FileFilter then FileFilter:StartingToFilter() end
  for _, item in ipairs(itemList) do
    local fdata = win.GetFileInfo(item)
    -- note: fdata can be nil for root directories
    local isFile = fdata and not fdata.FileAttributes:find("d")
    ---------------------------------------------------------------------------
    if isFile or ((area=="FromCurrFolder" or area=="OnlyCurrFolder") and panelInfo.Plugin) then
      Search_ProcessFile(fdata, item, FileFilter, "*")
    end
    if not isFile and not (area == "OnlyCurrFolder" and panelInfo.Plugin) then
      far.RecursiveSearch(item, "*", Search_ProcessFile, 0, FileFilter, aData.sFileMask, aData[Excl_Key])
    end
    ---------------------------------------------------------------------------
    if userbreak.fullcancel then break end
  end

  far.RestoreScreen(hScreen)
  return tFoundFiles, userbreak.fullcancel
end

local function CreateTmpPanel (tFileList, tData)
  tFileList = tFileList or {}
  local t = {}
  t.Opt = setmetatable({}, { __index=tData or TmpPanelDefaults })
  t.Opt.CommonPanel = false
  t.Opt.Mask = "*.temp" -- make possible to reopen saved panels with the standard TmpPanel plugin
  local env = libTmpPanel.NewEnv(t)
  local panel = env:NewPanel()
  panel:ReplaceFiles(tFileList)
  return panel
end

local function InitTmpPanel()
  local history = _Plugin.History["tmppanel"]
  for k,v in pairs(TmpPanelDefaults) do
    if history[k] == nil then history[k] = v end
  end

  libTmpPanel.PutExportedFunctions(export)
  export.SetFindList = nil

  local tpGetOpenPluginInfo = export.GetOpenPluginInfo
  export.GetOpenPluginInfo = function (Panel, Handle)
    local hist = _Plugin.History["tmppanel"]
    local Info = tpGetOpenPluginInfo (Panel, Handle)
    local a,b = hist.StartSorting:match("(%d+)%s*,%s*(%d+)")
    Info.StartSortMode, Info.StartSortOrder = tonumber(a), tonumber(b) -- w/o tonumber() it crashes Far
    for _,mode in pairs(Info.PanelModesArray) do
      mode.FullScreen = hist.FullScreenPanel
    end
    return Info
  end

  export.ClosePlugin = function(object, handle)
    local hist = _Plugin.History["tmppanel"]
    if hist.PreserveContents then
      _Plugin.FileList = object:GetItems()
      _Plugin.FileList.NoDuplicates = true
    else
      _Plugin.FileList = nil
    end
  end
end

return {
  CreateTmpPanel  = CreateTmpPanel;
  InitTmpPanel    = InitTmpPanel;
  SearchFromPanel = SearchFromPanel;
}
