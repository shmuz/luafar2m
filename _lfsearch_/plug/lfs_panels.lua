-- lfs_panels.lua

local M      = require "lfs_message"
local Common = require "lfs_common"
local sd     = require "far2.simpledialog"
local Sett   = require "far2.settings"
local field = Sett.field

local Excl_Key = "sExcludeDirs"

local F = far.Flags
local dirsep = package.config:sub(1,1)

local TmpPanelRegKey = "Plugins\\TmpPanel"
local TmpPanelRegVars = {
  Full=true, ColT=true, ColW=true, StatT=true, StatW=true, Contens=true,
  Mode=true, NewP=true, Prefix=true,
}
local TmpPanelDefaults = {
  ColT  = "NR,S",
  ColW  = "0,8",
  StatT = "NR,SC,D,T",
  StatW = "0,8,0,5",
  Full  = false,
  Macro = "CtrlF12 $Rep(12) Down $End +"
}

local KEY_INS     = F.KEY_INS
local KEY_NUMPAD0 = F.KEY_NUMPAD0
local KEY_SPACE   = F.KEY_SPACE

-- search area
local saFromCurrFolder, saOnlyCurrFolder, saSelectedItems, saRootFolder, saPathFolders = 1,2,3,4,5

local function ConfigDialog (aHistory)
  local aData = field(aHistory, "TmpPanel")
  local WIDTH = 78
  local DC = math.floor(WIDTH/2-1)

  local Items = {
    width = WIDTH;
    help = "SearchResultsPanel";
    { tp="dbox"; text=M.MConfigTitleTmpPanel; },
    { tp="text"; text=M.MColumnTypes;  },
    { tp="edit"; name="ColT"; x2=DC-2; },
    { tp="text"; text=M.MColumnWidths; },
    { tp="edit"; name="ColW"; x2=DC-2; },

    { tp="text"; text=M.MStatusColumnTypes;  x1=DC; ystep=-3; },
    { tp="edit"; name="StatT";               x1=DC; },
    { tp="text"; text=M.MStatusColumnWidths; x1=DC; },
    { tp="edit"; name="StatW";               x1=DC; },
    { tp="text"; text=M.MTmpPanelMacro;             },
    { tp="edit"; name="Macro"; x2=DC-2;             },

    { tp="chbox"; name="Full"; text=M.MFullScreenPanel; },
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
  local Selected = aData.SelectedCodePages or {}
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
    { Text = M.MAllCodePages },
    ---------------------------------------------------------------------------
    { Text = M.MSystemCodePages,  Flags = F.LIF_SEPARATOR },
    { CodePage = win.GetOEMCP() },
    { CodePage = win.GetACP() },
    ---------------------------------------------------------------------------
    { Text = M.MUnicodeCodePages, Flags = F.LIF_SEPARATOR },
    { CodePage = 1200, Text = makeline(1200, "UTF-16 (Little endian)") },
    { CodePage = 1201, Text = makeline(1201, "UTF-16 (Big endian)") },
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
      if Selected[v.CodePage] then v.Flags = bit.bor(v.Flags or 0, F.LIF_CHECKED) end
      if v.CodePage == aData.iCodePage then
        v.Flags = bit.bor(v.Flags or 0, F.LIF_SELECTED)
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
        if Selected[v] then
          item.Flags = bit.bor(item.Flags or 0, F.LIF_CHECKED)
        end
        if item.CodePage == aData.iCodePage then
          item.Flags = bit.bor(item.Flags or 0, F.LIF_SELECTED)
          items.SelectIndex = nil
        end
      end
    end
  end

  return items
end

local function GetSearchAreas(dataPanels)
  local Info = panel.GetPanelInfo(1)
  local RootFolderItem = {}
  if Info.PanelType == F.PTYPE_FILEPANEL and not Info.Plugin then
    RootFolderItem.Text = M.MSaRootFolder .. panel.GetPanelDirectory(1):match("/[^/]*")
  else
    RootFolderItem.Text = M.MSaRootFolder
    RootFolderItem.Flags = F.LIF_GRAYED
  end

  local T = {
    [saFromCurrFolder] = { Text = M.MSaFromCurrFolder },
    [saOnlyCurrFolder] = { Text = M.MSaOnlyCurrFolder },
    [saSelectedItems]  = { Text = M.MSaSelectedItems },
    [saRootFolder]     = RootFolderItem,
    [saPathFolders]    = { Text = M.MSaPathFolders },
  }
  local idx = dataPanels.iSearchArea or 1
  if (idx < 1) or (idx > #T) or (T[idx].Flags == F.LIF_GRAYED) then
    idx = 1
  end
  T.SelectIndex = idx
  return T
end

local searchGuid  = "3CD8A0BB-8583-4769-BBBC-5B6667D13EF9"
local replaceGuid = "F7118D4A-FBC3-482E-A462-0167DF7CC346"

local function PanelDialog (aHistory, aReplace, aHelpTopic)
  local insert = table.insert
  local dataMain = field(aHistory, "main")
  local dataPanels = field(aHistory, "panels")
  local Items = {
    width = 76;
    help = aHelpTopic;
    guid = aReplace and replaceGuid or searchGuid;
  }
  local Frame = Common.CreateSRFrame(Items, dataMain, false)
  ------------------------------------------------------------------------------
  insert(Items, { tp="dbox"; text=M.MTitlePanels; })
  insert(Items, { tp="text"; text=M.MFileMask; })
  insert(Items, { tp="edit"; name="sFileMask"; hist="Masks"; uselasthistory=1; y1=""; x1=5+M.MFileMask:len(); })
  insert(Items, { tp="text"; text=" "; }) -- blank line
  ------------------------------------------------------------------------------
  Frame:InsertInDialog(aReplace)
  ------------------------------------------------------------------------------
  insert(Items, { tp="sep"; })
  insert(Items, { tp="text"; text=M.MCodePages; })
  insert(Items, { tp="combobox"; name="cmbCodePage"; list=GetCodePages(dataPanels); dropdownlist=1; noauto=1; })
  insert(Items, { tp="text"; text=M.MSearchArea; })
  insert(Items, { tp="combobox"; name="cmbSearchArea"; list=GetSearchAreas(dataPanels); x2=36; dropdownlist=1; noauto=1; })
  insert(Items, { tp="chbox"; name="bSearchFolders"; text=M.MSearchFolders; ystep=-1; x1=40; })
  insert(Items, { tp="chbox"; name="bSearchSymLinks"; text=M.MSearchSymLinks; x1=40; })
  insert(Items, { tp="sep"; })
  insert(Items, { tp="butt"; centergroup=1; text=M.MOk; default=1; name="btnOk"; })
  insert(Items, { tp="butt"; centergroup=1; text=M.MCancel; cancel=1; })
  insert(Items, { tp="butt"; centergroup=1; text=M.MBtnDirFilter; name="btnConfig"; }) --TODO
  ------------------------------------------------------------------------------
  local Pos,Elem = sd.Indexes(Items)

  local function SetBtnFilterText(hDlg)
    hDlg:SetText(Pos.btnConfig, M.MBtnDirFilter..(dataPanels[Excl_Key] and "*" or ""))
  end

  function Items.proc (hDlg, msg, param1, param2)
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
      hDlg:SetText  (Pos.sFileMask, dataPanels.sFileMask or "")
      hDlg:SetCheck (Pos.bSearchFolders, dataPanels.bSearchFolders)
      hDlg:SetCheck (Pos.bSearchSymLinks, dataPanels.bSearchSymLinks)

    elseif msg == F.DN_KEY then
      if param1 == Pos.cmbCodePage then
        if param2==KEY_INS or param2==KEY_NUMPAD0 or param2==KEY_SPACE then
          local pos = hDlg:ListGetCurPos(param1)
          if pos.SelectPos ~= 1 then -- if not "All code pages"
            local item = hDlg:ListGetItem(param1, pos.SelectPos)
            item.Flags = bit.bxor(item.Flags, F.LIF_CHECKED)
            item.Index = pos.SelectPos
            hDlg:ListUpdate(param1, item)
          end
        end
      end
    elseif msg == F.DN_CLOSE then
      if Pos.btnConfig and param1 == Pos.btnConfig then
        hDlg:ShowDialog(0)
        --ConfigDialog(aHistory) --TODO
        if DirFilterDialog(dataPanels) then
          SetBtnFilterText(hDlg)
        end
        hDlg:ShowDialog(1)
        hDlg:SetFocus(Pos.btnOk)
        return 0
      elseif param1 == Pos.btnOk then
        if not hDlg:GetText(Pos.sFileMask):find("%S") then
          far.Message(M.MInvalidFileMask, M.MError, ";Ok", "w")
          return 0
        end
        ------------------------------------------------------------------------
        local pos = hDlg:ListGetCurPos(Pos.cmbCodePage)
        dataPanels.iCodePage = Elem.cmbCodePage.list[pos.SelectPos].CodePage
        ------------------------------------------------------------------------
        pos = hDlg:ListGetCurPos(Pos.cmbSearchArea)
        dataPanels.iSearchArea = pos.SelectPos
        ------------------------------------------------------------------------
        dataPanels.sFileMask = hDlg:GetText(Pos.sFileMask)
        dataPanels.bSearchFolders = hDlg:GetCheck(Pos.bSearchFolders)
        dataPanels.bSearchSymLinks = hDlg:GetCheck(Pos.bSearchSymLinks)
      end
      --------------------------------------------------------------------------
      -- store selected code pages no matter what user pressed: OK or Esc.
      dataPanels.SelectedCodePages = {}
      local info = hDlg:ListInfo(Pos.cmbCodePage)
      for i=1,info.ItemsNumber do
        local item = hDlg:ListGetItem(Pos.cmbCodePage, i)
        if 0 ~= bit.band(item.Flags, F.LIF_CHECKED) then
          local t = hDlg:ListGetData(Pos.cmbCodePage, i)
          if t then dataPanels.SelectedCodePages[t] = true end
        end
      end
      --------------------------------------------------------------------------
    end
    return Frame:DlgProc(hDlg, msg, param1, param2)
  end

  local dataTP = field(aHistory, "TmpPanel")
  for k,v in pairs(TmpPanelDefaults) do
    if dataTP[k] == nil then dataTP[k] = v end
  end
  sd.LoadData(dataMain, Items)
  Frame:OnDataLoaded(dataMain, false)
  local out = sd.Run(Items)
  if not out then return "cancel" end
  return aReplace and "replace" or "search", Frame.close_params
end

local function GetTmpPanelSettings()
  local t = {}
  for k in pairs(TmpPanelRegVars) do t[k] = win.GetRegKey("HKCU", TmpPanelRegKey, k) end
  return t
end

local function ChangeTmpPanelSettings (aHistory)
  local data = field(aHistory, "TmpPanel")
  for k,v in pairs(data) do
    if TmpPanelRegVars[k] then
      local typ = type(v)
      if typ ~= "string" then
        typ, v = "dword", (v==true) and 1 or (v==false) and 0 or v
      end
      win.SetRegKey("HKCU", TmpPanelRegKey, k, typ, v)
    end
  end
  win.SetRegKey("HKCU", TmpPanelRegKey, "Contens", "dword", 0) -- Copy folder contents
  win.SetRegKey("HKCU", TmpPanelRegKey, "Mode", "dword", 1) -- Replace files with file list
  win.SetRegKey("HKCU", TmpPanelRegKey, "NewP", "dword", 1) -- New panel for search results
  return data
end

local function RestoreTmpPanelSettings (data)
  for k,v in pairs(data) do
    local typ = type(v) == "number" and "dword" or "string"
    win.SetRegKey("HKCU", TmpPanelRegKey, k, typ, v)
  end
end

local function MakeItemList (panelInfo, area)
  local realNames = (bit.band(panelInfo.Flags, F.PFLAGS_REALNAMES) ~= 0)
  local panelDir = panel.GetPanelDirectory(1) or ""
  local itemList, flags = {}, F.FRS_RECUR

  if area == saFromCurrFolder or area == saOnlyCurrFolder then
    if realNames then
      if panelInfo.Plugin then
        for i=1, panelInfo.ItemsNumber do
          local item = panel.GetPanelItem(1, i)
          local name = item.FileName
          if name ~= ".." and name ~= "." then itemList[#itemList+1] = name end
        end
      else
        itemList[1] = panelDir
      end
      if area == saOnlyCurrFolder then
        flags = 0
      end
    end

  elseif area == saSelectedItems then
    if realNames then
      local curdir_slash = panelInfo.Plugin and "" or panelDir:gsub(dirsep.."?$", dirsep, 1)
      for i=1, panelInfo.SelectedItemsNumber do
        local item = panel.GetSelectedPanelItem(1, i)
        itemList[#itemList+1] = curdir_slash .. item.FileName
      end
    end

  elseif area == saRootFolder then
    itemList[1] = panelDir:match("/[^/]*")

  elseif area == saPathFolders then
    flags = 0
    local path = win.GetEnv("PATH")
    if path then path:gsub("[^:]+", function(c) itemList[#itemList+1]=c end) end
  end
  return itemList, flags
end

local function SearchFromPanel (aHistory)
  local sOperation, tParams = PanelDialog(aHistory, false, "OperInPanels")
  if sOperation == "cancel" then return end

  -- take care of the future "repeat" operations in the Editor
  local dataMain = field(aHistory, "main")
  dataMain.sLastOp = "search"
  dataMain.bSearchBack = false
  ----------------------------------------------------------------------------
  local WID = 60
  local W1 = 3
  local W2 = WID - W1 - 3
  local TITLE = M.MTitleSearching
  local Regex = tParams.Regex
  local BLOCKLEN, OVERLAP = 32*1024, -1024
  ----------------------------------------------------------------------------
  local codePages
  local dataPanels = field(aHistory, "panels")
  local storedPages = dataPanels.SelectedCodePages
  if dataPanels.iCodePage then
    codePages = { dataPanels.iCodePage }
  elseif storedPages and next(storedPages) then
    codePages = {}
    for k in pairs(storedPages) do table.insert(codePages, k) end
  else
    codePages = { win.GetOEMCP(), win.GetACP(), 1200, 1201, 65000, 65001 }
  end
  ----------------------------------------------------------------------------
  local panelInfo = panel.GetPanelInfo(1)
  local area = dataPanels.iSearchArea or 1
  if area < 1 or area > 7 then area = 1 end
  local bRecurse, bSymLinks
  local itemList, flags = MakeItemList(panelInfo, area)
  if dataPanels.bSearchSymLinks then
    bSymLinks = true
  end
  if bit.band(flags, F.FRS_RECUR) ~= 0 then
    bRecurse = true
  end
  -----------------------------------------------------------------------------
  local userbreak
  local function ConfirmEsc()
    if 1 == far.Message(M.MConfirmCancel, M.MInterrupted, ";YesNo", "w") then
      userbreak = true; return true
    end
  end
  local function ConfirmEsc2()
    local r = far.Message(M.MConfirmCancel, M.MInterrupted, M.MButtonsCancelOnFile, "w")
    if r==1 then userbreak = true end
    return r==1 or r==2
  end
  local tOut, cnt, nShow = {}, 0, 0
  far.Message((" "):rep(WID).."\n"..M.MFilesFound.."0", TITLE, "")
  --===========================================================================

  local function ShowProgress(fullname)
    local len = fullname:len()
    local s = len<=WID and fullname..(" "):rep(WID-len) or
              fullname:sub(1,W1).. "..." .. fullname:sub(-W2)
    far.Message(s.."\n"..M.MFilesFound..cnt, TITLE, "")
  end
  --===========================================================================

  local function ProcessFile(fdata, fullname, mask_incl, mask_excl, mask_dirs)
    ---------------------------------------------------------------------------
    if win.ExtractKey()=="ESCAPE" and ConfirmEsc() then return true end
    ---------------------------------------------------------------------------
    nShow = nShow + 1
    if nShow % 32 == 0 then ShowProgress(fullname) end
    ---------------------------------------------------------------------------
    local mask_ok = far.ProcessName(mask_incl, fdata.FileName, F.PN_CMPNAMELIST+F.PN_SKIPPATH) and
      not (mask_excl and far.ProcessName(mask_excl, fdata.FileName, F.PN_CMPNAMELIST+F.PN_SKIPPATH))
    ---------------------------------------------------------------------------
    if fdata.FileAttributes:find("d") then
      if mask_ok and dataPanels.bSearchFolders and dataMain.sSearchPat == "" then
        cnt = cnt+1
        tOut[cnt] = fullname
      end
      ---------------------------------------------------------------------------
      if mask_dirs and far.ProcessName(mask_dirs, fullname, F.PN_CMPNAMELIST+F.PN_SKIPPATH) then
        return
      end
      ---------------------------------------------------------------------------
      if bRecurse then
        if bSymLinks or not fdata.FileAttributes:find("e") then
          return far.RecursiveSearch(fullname, "*", ProcessFile, 0, mask_incl, mask_excl, mask_dirs)
        end
      end
      return
    end
    ---------------------------------------------------------------------------
    if not mask_ok then return end
    ---------------------------------------------------------------------------
    local found = dataMain.sSearchPat == ""
    if not found then
      local fp = io.open(fullname, "rb")
      if fp then
        ShowProgress(fullname)
        local str = ""
        repeat
          if win.ExtractKey() == "ESCAPE" and ConfirmEsc2() then
            fp:close(); return userbreak
          end
          if #str == BLOCKLEN then fp:seek("cur", OVERLAP) end
          str = fp:read(BLOCKLEN)
          if not str then break end
          for _, cp in ipairs(codePages) do
            local s
            if cp == 1200 or cp == 65001 then s = str
            elseif cp == 1201 then s = string.gsub(str, "(.)(.)", "%2%1")
            else s = win.MultiByteToWideChar(str, cp)--, cp==65000 and "" or "e")
            end
            if s and cp ~= 65001 then s = win.Utf16ToUtf8(s) end
            if s then
              local ok, start = pcall(Regex.find, Regex, s)
              if ok and start then found = true break end
            end
          end
        until found
        fp:close()
      end
    end
    ---------------------------------------------------------------------------
    if found then cnt = cnt+1; tOut[cnt] = fullname; end
    ---------------------------------------------------------------------------
  end
  --===========================================================================

  for _, item in ipairs(itemList) do
    local fdata = win.GetFileInfo(item)
    -- note: fdata can be nil for root directories
    local isFile = fdata and not fdata.FileAttributes:find("d")
    ---------------------------------------------------------------------------
    if isFile or ((area==saFromCurrFolder or area==saOnlyCurrFolder) and panelInfo.Plugin) then
      ProcessFile(fdata, item, "*")
    end
    if not isFile and not (area == saOnlyCurrFolder and panelInfo.Plugin) then
      local mask_incl, mask_excl = dataPanels.sFileMask:match("(.-)|(.*)")
      if mask_incl then
        if mask_incl=="" then mask_incl = "*" end
        if mask_excl=="" then mask_excl = nil end
      else
        mask_incl = dataPanels.sFileMask
      end
      far.RecursiveSearch(item, "*", ProcessFile, 0, mask_incl, mask_excl, dataPanels[Excl_Key])
    end
    ---------------------------------------------------------------------------
    if userbreak then break end
  end

  if cnt > 0 then
    local fname = "/tmp/lfsearch.found.files"
    local fpOut = assert(io.open(fname, "wb"))
    for _, fullname in ipairs(tOut) do
      fpOut:write(fullname, "\n")
    end
    fpOut:close()
    -- run temporary panel from the command line
    local tp_settings = GetTmpPanelSettings()
    local prefix = tp_settings.Prefix or "tmp"
--~ local usercfg = ChangeTmpPanelSettings(aHistory)
    local cmd = ("%s: -menu %s"):format(prefix, fname)
    panel.SetCmdLine (cmd)
    actl.PostKeySequence {F.KEY_ENTER}
    far.Timer(1000,
      function(h)
        h:Close()
        win.DeleteFile(fname)
---     RestoreTmpPanelSettings(tp_settings)
      end)
  else
    actl.RedrawAll()
    if userbreak or 1==far.Message(M.MNoFilesFound,M.MMenuTitle,M.MButtonsNewSearch) then
      return SearchFromPanel(aHistory)
    end
  end
end

return SearchFromPanel
