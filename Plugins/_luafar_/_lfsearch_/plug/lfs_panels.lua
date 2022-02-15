-- lfs_panels.lua

local M           = require "lfs_message"
local far2_dialog = require "far2.dialog"
local luarepl     = require "luarepl"
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
  local aData = aHistory:field("TmpPanel")
  local WIDTH, HEIGHT = 78, 13
  local DC = math.floor(WIDTH/2-1)

  local D = far2_dialog.NewDialog()
  D._           = {"DI_DOUBLEBOX", 3,1,WIDTH-4,HEIGHT-2, 0,0,0,0, M.MConfigTitleTmpPanel}
  D._           = {"DI_TEXT",    5, 2, 0,0,  0,0,0,0, M.MColumnTypes}
  D.ColT        = {"DI_EDIT",    5, 3,36,3,  0,0,0,0, ""}
  D._           = {"DI_TEXT",    5, 4, 0,0,  0,0,0,0, M.MColumnWidths}
  D.ColW        = {"DI_EDIT",    5, 5,36,5,  0,0,0,0, ""}
  D._           = {"DI_TEXT",   DC, 2, 0,0,  0,0,0,0, M.MStatusColumnTypes}
  D.StatT       = {"DI_EDIT",   DC, 3,72,3,  0,0,0,0, ""}
  D._           = {"DI_TEXT",   DC, 4, 0,0,  0,0,0,0, M.MStatusColumnWidths}
  D.StatW       = {"DI_EDIT",   DC, 5,72,5,  0,0,0,0, ""}
  D._           = {"DI_TEXT",    5, 6, 0,0,  0,0,0,0, M.MTmpPanelMacro}
  D.Macro       = {"DI_EDIT",    5, 7,36,5,  0,0,0,0, ""}
  D.Full        = {"DI_CHECKBOX",5, 8, 0,0,  0,0,0,0, M.MFullScreenPanel}
  D._           = {"DI_TEXT",    5, 9, 0,0,  0,0,{DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, 0,""}
  D.btnOk       = {"DI_BUTTON",  0,10, 0,0,  0,0,"DIF_CENTERGROUP", 1, M.MOk}
  D.btnCancel   = {"DI_BUTTON",  0,10, 0,0,  0,0,"DIF_CENTERGROUP", 0, M.MCancel}
  D.btnDefaults = {"DI_BUTTON",  0,10, 0,0,  0,0,"DIF_CENTERGROUP", 0, M.MBtnDefaults}

  local function DlgProc (hDlg, msg, param1, param2)
    if msg == F.DN_CLOSE then
      if param1 == D.btnDefaults.id then
        far2_dialog.LoadDataDyn (hDlg, D, TmpPanelDefaults)
        return 0
      end
    end
  end

  far2_dialog.LoadData (D, aData)
  local ret = far.Dialog(-1, -1, WIDTH, HEIGHT, "SearchResultsPanel", D, 0, DlgProc)
  if ret == D.btnOk.id then
    far2_dialog.SaveData (D, aData)
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
  for i,v in ipairs(items) do
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
  for k,v in ipairs(pages) do
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
    RootFolderItem.Text = M.MSaRootFolder .. panel.GetPanelDir(1):match("/[^/]*")
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

local searchGuid  = win.Uuid("3CD8A0BB-8583-4769-BBBC-5B6667D13EF9")
local replaceGuid = win.Uuid("F7118D4A-FBC3-482E-A462-0167DF7CC346")

local function PanelDialog (aHistory, aReplace, aHelpTopic)
  local dataMain = aHistory:field("main")
  local dataPanels = aHistory:field("panels")
  local D = far2_dialog.NewDialog()
  local Frame = luarepl.CreateSRFrame(D, dataMain, false)
  ------------------------------------------------------------------------------
  D.dblbox      = {"DI_DOUBLEBOX",3, 1,72, 0, 0, 0, 0, 0, M.MTitlePanels}
  D.lab         = {"DI_TEXT",     5, 2, 0, 0, 0, 0, 0, 0, M.MFileMask}
  D.sFileMask   = {"DI_EDIT",
                  M.MFileMask:len()+5, 2,70, 6, 0, "Masks", {DIF_HISTORY=1,DIF_USELASTHISTORY=1}, 0, ""}
  ------------------------------------------------------------------------------
  local Y = Frame:InsertInDialog(aReplace, 4)
  ------------------------------------------------------------------------------
  D.sep         = {"DI_TEXT",     5, Y, 0, 0, 0, 0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, 0, ""}
  Y = Y + 1
  D.lab         = {"DI_TEXT",     5, Y, 0,0, 0, 0, 0, 0, M.MCodePages}
  Y = Y + 1
  D.cmbCodePage = {"DI_COMBOBOX", 5, Y,70,0, 0, GetCodePages(dataPanels),
                                         {DIF_DROPDOWNLIST=1}, 0, "", _noauto=1}
  Y = Y + 1
  D.lab         = {"DI_TEXT",     5, Y, 0,0, 0, 0, 0, 0, M.MSearchArea}
  Y = Y + 1
  D.cmbSearchArea={"DI_COMBOBOX", 5, Y,36,0, 0, GetSearchAreas(dataPanels),
                                         {DIF_DROPDOWNLIST=1}, 0, "", _noauto=1}
  D.bSearchFolders ={"DI_CHECKBOX",40,Y-1,0,0,  0,0,0,0, M.MSearchFolders}
  D.bSearchSymLinks={"DI_CHECKBOX",40, Y, 0,0,  0,0,0,0, M.MSearchSymLinks}
  Y = Y + 1
  D.sep         = {"DI_TEXT",     5, Y, 0,0, 0, 0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1},  0, ""}
  Y = Y + 1
  D.btnOk       = {"DI_BUTTON",   0, Y, 0,0, 0, 0, "DIF_CENTERGROUP", 1, M.MOk}
  D.btnCancel   = {"DI_BUTTON",   0, Y, 0,0, 0, 0, "DIF_CENTERGROUP", 0, M.MCancel}
--D.btnConfig   = {"DI_BUTTON",   0, Y, 0,0, 0, 0, "DIF_CENTERGROUP", 0, M.MDlgBtnConfig} -- TODO
  D.dblbox.Y2   = Y+1
  ------------------------------------------------------------------------------
  local function DlgProc (hDlg, msg, param1, param2)
    if msg == F.DN_INITDIALOG then
      hDlg:SetComboboxEvent(D.cmbCodePage.id, F.CBET_KEY)
      local t = {}
      for i,v in ipairs(D.cmbCodePage.ListItems) do
        if v.CodePage then
          t.Index, t.Data = i, v.CodePage
          hDlg:ListSetData(D.cmbCodePage.id, t)
        end
      end
      D.sFileMask:SetText(hDlg, dataPanels.sFileMask or "")
      D.bSearchFolders:SetCheck(hDlg, dataPanels.bSearchFolders)
      D.bSearchSymLinks:SetCheck(hDlg, dataPanels.bSearchSymLinks)

    elseif msg == F.DN_KEY then
      if param1 == D.cmbCodePage.id then
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
    elseif msg == F.DN_GETDIALOGINFO then
      return aReplace and replaceGuid or searchGuid
    elseif msg == F.DN_CLOSE then
      if D.btnConfig and param1 == D.btnConfig.id then
        hDlg:ShowDialog(0)
        ConfigDialog(aHistory)
        hDlg:ShowDialog(1)
        hDlg:SetFocus(D.btnOk.id)
        return 0
      elseif param1 == D.btnOk.id then
        if not D.sFileMask:GetText(hDlg):find("%S") then
          far.Message(M.MInvalidFileMask, M.MError, ";Ok", "w")
          return 0
        end
        ------------------------------------------------------------------------
        local pos = hDlg:ListGetCurPos(D.cmbCodePage.id)
        dataPanels.iCodePage = D.cmbCodePage.ListItems[pos.SelectPos].CodePage
        ------------------------------------------------------------------------
        local pos = hDlg:ListGetCurPos(D.cmbSearchArea.id)
        dataPanels.iSearchArea = pos.SelectPos
        ------------------------------------------------------------------------
        D.sFileMask:SaveText(hDlg, dataPanels)
        D.bSearchFolders:SaveCheck(hDlg, dataPanels)
        D.bSearchSymLinks:SaveCheck(hDlg, dataPanels)
      end
      --------------------------------------------------------------------------
      -- store selected code pages no matter what user pressed: OK or Esc.
      dataPanels.SelectedCodePages = {}
      local info = hDlg:ListInfo(D.cmbCodePage.id)
      for i=1,info.ItemsNumber do
        local item = hDlg:ListGetItem(D.cmbCodePage.id, i)
        if 0 ~= bit.band(item.Flags, F.LIF_CHECKED) then
          local t = hDlg:ListGetData(D.cmbCodePage.id, i)
          if t then dataPanels.SelectedCodePages[t] = true end
        end
      end
      --------------------------------------------------------------------------
    end
    return Frame:DlgProc(hDlg, msg, param1, param2)
  end

  local dataTP = aHistory:field("TmpPanel")
  for k,v in pairs(TmpPanelDefaults) do
    if dataTP[k] == nil then dataTP[k] = v end
  end
  far2_dialog.LoadData(D, dataMain)
  Frame:OnDataLoaded(dataMain, false)
  local ret = far.Dialog(-1, -1, 76, Y+3, aHelpTopic, D, 0, DlgProc)
  if ret < 0 or ret == D.btnCancel.id then return "cancel" end
  return (ret == D.btnOk.id) and (aReplace and "replace" or "search"),
         Frame.close_params
end

local function GetTmpPanelSettings()
  local t = {}
  for k in pairs(TmpPanelRegVars) do t[k] = win.GetRegKey("HKCU", TmpPanelRegKey, k) end
  return t
end

local function ChangeTmpPanelSettings (aHistory)
  local data = aHistory:field("TmpPanel")
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
  local panelDir = panel.GetPanelDir(1) or ""
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
  local dataMain = aHistory:field("main")
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
  local dataPanels = aHistory:field("panels")
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
  local itemList, flags = MakeItemList(panelInfo, area)
  if dataPanels.bSearchSymLinks then
    flags=bit.bor(flags, F.FRS_SCANSYMLINK)
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
  local tOut, cnt = {}, 0
  far.Message((" "):rep(WID).."\n"..M.MFilesFound.."0", TITLE, "")
  --===========================================================================
  local function ProcessFile(fdata, fullname)
    ---------------------------------------------------------------------------
    if win.ExtractKey()=="ESCAPE" and ConfirmEsc() then return true end
    local len = fullname:len()
    local s = len<=WID and fullname..(" "):rep(WID-len) or
              fullname:sub(1,W1).. "..." .. fullname:sub(-W2)
    far.Message(s.."\n"..M.MFilesFound..cnt, TITLE, "")
    ---------------------------------------------------------------------------
    local found = true
    if fdata.FileAttributes:find("d") then
      if (not dataPanels.bSearchFolders) or (dataMain.sSearchPat ~= "") then
        return false
      end
    else found = (dataMain.sSearchPat == "")
    end
    ---------------------------------------------------------------------------
    if not found then
      local fp = io.open(fullname, "rb")
      if not fp then return false end
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
    ---------------------------------------------------------------------------
    if found then cnt = cnt+1; tOut[cnt] = fullname; end
    return false
    ---------------------------------------------------------------------------
  end
  --===========================================================================

  for _, item in ipairs(itemList) do
    local fdata = win.GetFileInfo(item)
    -- note: fdata can be nil for root directories
    local isFile = fdata and not fdata.FileAttributes:find("d")
    ---------------------------------------------------------------------------
    if isFile or ((area == saFromCurrFolder or area == saOnlyCurrFolder)
                  and panelInfo.Plugin) then
      ProcessFile(fdata, item)
    end
    if not isFile and not (area == saOnlyCurrFolder and panelInfo.Plugin) then
      far.RecursiveSearch(item, dataPanels.sFileMask, ProcessFile, flags)
    end
    ---------------------------------------------------------------------------
    if userbreak then break end
  end

  if cnt > 0 then
    local fname = _Plugin.WorkDir .. dirsep .. "$tmp$.tmp"
    local fpOut = assert(io.open(fname, "wb"))
    for _, fullname in ipairs(tOut) do
      fpOut:write(fullname, "\n")
    end
    fpOut:close()
    -- run temporary panel from the command line
    local tp_settings = GetTmpPanelSettings()
    local prefix = tp_settings.Prefix or "tmp"
--~     local usercfg = ChangeTmpPanelSettings(aHistory)
    local cmd = ("%s: -menu %s"):format(prefix, fname)
    panel.SetCmdLine (cmd)
    actl.PostKeySequence {F.KEY_ENTER}
     far.Timer(1000,
       function(h)
         h:Close()
         win.DeleteFile(fname)
---         RestoreTmpPanelSettings(tp_settings)
       end)
  else
    actl.RedrawAll()
    if userbreak or 1==far.Message(M.MNoFilesFound,M.MMenuTitle,M.MButtonsNewSearch) then
      return SearchFromPanel(aHistory)
    end
  end
end

return SearchFromPanel
