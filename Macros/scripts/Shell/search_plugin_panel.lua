-- Started: 2020-08-01
-- Current limitations or problems:
--   (1) The search is line-based: no string containing '\r' or '\n' can be found.

local MacroKey = "ShiftF7"
local Title = "Search in plugin's panel"

local SETTINGS_KEY  = "shmuz"
local SETTINGS_NAME = "search_plugin_panel"

local F = far.Flags
local farhost = far.Host
local join = win.JoinPath

local function MySetDir(aHandle, aDir) -- that's what MultiArc understands
  if aDir:sub(1,1) == "/" then
    if not farhost.SetDirectory(aHandle, "/") then return end
  end
  for part in aDir:gmatch("[^/]+") do
    if not farhost.SetDirectory(aHandle, part) then return end
  end
  return true
end

-- The order must match one in corresponding combobox in dialog
local SA_FROM_CURRENT, SA_CURRENT_ONLY, SA_FROM_ROOT = 1, 2, 3 -- search areas
local ENC_UTF8, ENC_ALL = 1, 2 -- encodings

-- use instead of macro-API function Panel.SetPath()
local function SetPath(aHandle, aDir, aFileName)
  MySetDir(aHandle, aDir)
  panel.UpdatePanel(aHandle)
  local info = panel.GetPanelInfo(aHandle)
  local filepos = nil
  for k=1,info.ItemsNumber do
    local item = panel.GetPanelItem(aHandle, k)
    if item.FileName == aFileName then
      filepos = k; break
    end
  end
  panel.RedrawPanel(aHandle, filepos and {CurrentItem=filepos})
end

-- The function delimits lines by the following sequences (greedy): "\r\n", "\n\r", "\r", "\n".
local function getline(fp) -- iteraror
  local CHUNK = 4096
  return function()
    local acc = {}
    while true do
      local pos = fp:seek("cur")
      local str = fp:read(CHUNK)
      if str == nil then break end
      local fr, to, eol1, eol2 = string.find(str, "([\r\n])([\r\n]?)")
      if fr == nil then
        table.insert(acc, str)
      else
        if fr == CHUNK then -- process a corner case
          eol2 = fp:read(1) or eol2
          if (eol1=="\r" and eol2=="\n") or (eol1=="\n" and eol2=="\r") then
            to = to+1
          end
        end
        if eol1 == eol2 then to = to-1; end
        fp:seek("set", pos+to)
        table.insert(acc, string.sub(str, 1, fr-1))
        break
      end
    end
    return acc[1] and table.concat(acc)
  end
end

local function EscapeSearchPattern(pat)
  pat = string.gsub(pat, "[~!@#$%%^&*()%-+[%]{}\\|:;'\",<.>/?]", "\\%1")
  return pat
end

local function GetDialogData()
  local SimpleDialog = require "far2.simpledialog"
  local Settings     = require "far2.settings"

  local Items = {
    guid="B98F9DBF-4298-4DC1-8769-9295A8A55181";
    {tp="dbox"; text=Title;                                              },
    {tp="text"; text="&File mask:";                                      },
    {tp="edit"; hist="Masks",uselasthistory=1,       name="sFileMask";   },
    {tp="text"; text="&Search for:";                                     },
    {tp="edit"; hist="SearchText",uselasthistory=1,  name="sSearchPat";  },
    {tp="chbox"; text="Re&gular expression",         name="bRegExpr";    },
    {tp="chbox"; text="&Case sensitive",             name="bCaseSens";   },
    {tp="chbox"; text="&Whole words",                name="bWholeWords"; },
    {tp="sep";                                                           },
    {tp="text"; text="E&ncodings:";                                      },
    {tp="combobox"; dropdown=1; ystep=0; x1=16;  name="iEncoding";
      list = { [ENC_UTF8] = {Text="UTF-8"             };
               [ENC_ALL ] = {Text="UTF-8 + OEM + ANSI"}; };              },
    {tp="sep";                                                           },
    {tp="text"; text="Searc&h area:";                                    },
    {tp="combobox"; dropdown=1; ystep=0; x1=18;  name="iSearchArea";
      list = { [SA_FROM_CURRENT] = {Text="From the current folder"};
               [SA_CURRENT_ONLY] = {Text="The current folder only"};
               [SA_FROM_ROOT   ] = {Text="From the root folder"   }; };  },
    {tp="sep";                                                           },
    {tp="butt"; text="OK";     centergroup=1; default=1;                 },
    {tp="butt"; text="Cancel"; centergroup=1; cancel=1;                  },
  }
  local dlg = SimpleDialog.New(Items)
  local Pos, Elem = dlg:Indexes()

  local function EnableControls(hDlg)
    local is_regex = hDlg:GetCheck(Pos.bRegExpr) == 1
    hDlg:Enable(Pos.bWholeWords, is_regex and 0 or 1)
    if is_regex then hDlg:SetCheck(Pos.bWholeWords, 0); end
  end

  local closeaction = function(hDlg, Par1, tOut)
    if tOut.sFileMask == "" then
      far.Message("File mask is empty",Title,nil,"w"); return 0
    end
    local sPat = tOut.sSearchPat
    if sPat ~= "" then
      if not tOut.bRegExpr then sPat = EscapeSearchPattern(sPat); end
      local ok,msg = pcall(regex.new, sPat)
      if not ok then far.Message(msg,Title,nil,"w"); return 0; end
    end
  end

  Items.proc = function(hDlg, Msg, Par1, Par2)
    if Msg == F.DN_INITDIALOG then
      EnableControls(hDlg)
    elseif Msg == F.DN_BTNCLICK then
      if Par1 == Pos.bRegExpr then
        EnableControls(hDlg)
      end
    elseif Msg == F.DN_CLOSE then
      return closeaction(hDlg, Par1, Par2)
    end
  end

  -- load data
  local data = Settings.mload(SETTINGS_KEY, SETTINGS_NAME) or {}
  -- initialize dialog
  Elem.bRegExpr.val = data.bRegExpr
  Elem.bCaseSens.val = data.bCaseSens
  Elem.bWholeWords.val = data.bWholeWords
  Elem.iEncoding.list.SelectIndex = data.iEncoding or 1
  Elem.iSearchArea.list.SelectIndex = data.iSearchArea or 1
  -- run dialog
  data = dlg:Run()
  -- save data and return
  if data then Settings.msave(SETTINGS_KEY, SETTINGS_NAME, data); end
  return data
end

local function ConfirmEscape() -- 16...25 microsec
  local ret = false
  if win.ExtractKey() == "ESCAPE" then
    local hScreen, hScreen2 = far.SaveScreen(), nil
    local msg = "Operation has been interrupted.\nDo you really want to cancel it?"
    if 1 == far.Message(msg, Title, ";YesNo", "w") then
      ret = true
      hScreen2 = far.SaveScreen()
    end
    far.RestoreScreen(hScreen)
    if hScreen2 then far.RestoreScreen(hScreen2) end
    far.Text()
  end
  return ret
end

local function FindOEM(rr, str)
  return rr:findW(win.MultiByteToWideChar(str, win.GetOEMCP()))
end

local function FindANSI(rr, str)
  return rr:findW(win.MultiByteToWideChar(str, win.GetACP()))
end

local function ShowProgress(aOut)
  local msg = ("Please wait...\nFound: %d/%d file(s)"):format(aOut.nFoundFiles, aOut.nTotalFiles)
  far.Message(msg, Title, "")
end

-- @param aData table
--   .iEncoding     integer
--   .iSearchArea   integer
--   .sFileMask     string
--   .sTmpDir       string
--   .uRegex        userdata
local function ProcessDir (aHandle, aDir, aData, aOut)
  if not MySetDir(aHandle, aDir) then
    -- far.Message("could not set directory:\n"..aDir,nil,nil,"w")
    return
  end
  ShowProgress(aOut)

  -- fill lists
  local dlist, flist, freelist = {}, {}, {}
  local curlist = { dir=aDir }
  local dirItems = farhost.GetFindData(aHandle)
--require "far2.lua_explorer"(dirItems,"dirItems")
  for _,v in ipairs(dirItems) do
    if v.FileAttributes:find("d") then
      if v.FileName~="." and v.FileName~=".." then
        table.insert(dlist, v)
        table.insert(freelist, v)
      end
    else
      if far.ProcessName("PN_CMPNAMELIST", aData.sFileMask, v.FileName, "PN_SKIPPATH") then
        table.insert(flist, v)
      else
        table.insert(freelist, v)
      end
    end
  end

  local stop = nil

  -- search in lists
  if aData.uRegex then
    local res = farhost.GetFiles(aHandle, flist, false, aData.sTmpDir,
      bit64.bor(F.OPM_FIND,F.OPM_SILENT)) -- F.OPM_NONE
    if res ~= 0 then
      local rr = aData.uRegex
      for _,v in ipairs(flist) do
        if stop then
          table.insert(freelist, v)
        else
          local found = nil
          local fullname = join(aData.sTmpDir, v.FileName)
          local fp = io.open(fullname, "rb")
          if fp then
            local count, Period = 0, 10 -- check for Esc every Period lines
            for line in getline(fp) do
              count = count+1
              if count % Period == 0 then
                count = 0
                if ConfirmEscape() then
                  stop=true; break;
                end
              end
              if rr:find(line) -- UTF-8
                or aData.iEncoding==ENC_ALL and (FindOEM(rr,line) or FindANSI(rr,line))
              then
                found = true; break
              end
            end
            fp:close()
          end
          win.SetFileAttr(fullname, "")
          win.DeleteFile(fullname)
          if found then
            table.insert(curlist, v)
            aOut.nFoundFiles = aOut.nFoundFiles + 1
          else
            table.insert(freelist, v)
          end
          aOut.nTotalFiles = aOut.nTotalFiles + 1
          ShowProgress(aOut)
        end
      end
    else -- farhost.GetFiles() returned 0
      for _,v in ipairs(flist) do table.insert(freelist,v); end
    end
  else -- search by mask only not by content
    for _,v in ipairs(flist) do table.insert(curlist, v); end
    aOut.nFoundFiles = aOut.nFoundFiles + #curlist
    aOut.nTotalFiles = aOut.nTotalFiles + #curlist
    ShowProgress(aOut)
  end

  if curlist[1] then table.insert(aOut, curlist); end

  if not stop and aData.iSearchArea ~= SA_CURRENT_ONLY then -- recurse
    for _,v in ipairs(dlist) do
      if ProcessDir (aHandle, join(aDir, v.FileName), aData, aOut) then
        stop=true; break;
      end
    end
  end

--###  farhost.FreeUserData(aHandle, freelist)
  return stop
end

-- @param aData table
--   .bCaseSens     boolean
--   .bRegExpr      boolean
--   .bWholeWords   boolean
--   .iEncoding     integer
--   .iSearchArea   integer
--   .sFileMask     string
--   .sSearchPat    string
local function Find (aData)
  local PI = panel.GetPanelInfo(nil, 1)
  local handle = PI and PI.PluginHandle
  if not handle then return; end

  -- Preparations
  local curdir = panel.GetPanelDirectory(handle)
  if not curdir:find("^/") then curdir = "/"..curdir; end
  local startdir = (aData.iSearchArea==SA_FROM_ROOT) and "/" or curdir
  local tmpdir = far.InMyTemp("Far-" .. win.Uuid("L"):sub(1,8))
  if aData.sSearchPat ~= "" then
    local patt = aData.sSearchPat
    if not aData.bRegExpr then
      patt = EscapeSearchPattern(patt)
      if aData.bWholeWords then patt = "\\b"..patt.."\\b"; end
    end
    aData.uRegex = assert(regex.new(patt, aData.bCaseSens and "" or "i"), "invalid regex")
    aData.sTmpDir = tmpdir
    assert(win.CreateDir(tmpdir), "cannot create a temporary directory")
  end

  -- Action
  local foundlist, freelist = { nFoundFiles=0, nTotalFiles=0 }, {}
  ProcessDir(handle, startdir, aData, foundlist)

  --Cleaning up
  MySetDir(handle, curdir) -- restore plugin's directory

  actl.RedrawAll() -- clear progress window (not required under Far3)

  -- Message to the user
  if foundlist.nFoundFiles > 0 then
    local rect = far.AdvControl("ACTL_GETFARRECT")
    local height = rect.Bottom - rect.Top + 1
    local title = ("%d/%d file(s) found"):format(foundlist.nFoundFiles, foundlist.nTotalFiles)
    local props = { Title=title; MaxHeight=height-8; Bottom="F3:view, F4:edit, CtrlPgUp:goto"}
    local displaylist = {}
    for _,tdir in ipairs(foundlist) do
      for _,v in ipairs(tdir) do
        table.insert(displaylist, {text=join(tdir.dir, v.FileName); dir=tdir.dir; item=v} )
        table.insert(freelist,v)
      end
    end
    while true do
      local item, pos = far.Menu(props, displaylist, "F3 F4 CtrlPgUp")
      if not (item and pos>0) then break; end -- pos == 0 when all items are filtered out
      props.SelectIndex = pos
      local menuitem = displaylist[pos]
      local need_update = nil
      if item.BreakKey == "F3" or item.BreakKey == nil then
        MySetDir(handle, menuitem.dir)
        local filename = join(tmpdir, menuitem.item.FileName)
        local res = farhost.GetFiles(handle, {menuitem.item}, false, tmpdir,
          bit64.bor(F.OPM_FIND,F.OPM_SILENT))
        if res ~= 0 then
          viewer.Viewer(filename, menuitem.text, nil,nil,nil,nil, bit64.bor(F.VF_DISABLEHISTORY))
        end
        win.DeleteFile(filename)
        MySetDir(handle, curdir) -- restore plugin's directory
      elseif item.BreakKey == "F4" then
        MySetDir(handle, menuitem.dir)
        local filename = join(tmpdir, menuitem.item.FileName)
        local res = farhost.GetFiles(handle, {menuitem.item}, false, tmpdir,
          bit64.bor(F.OPM_FIND,F.OPM_SILENT))
        if res ~= 0 then
          if editor.Editor(filename, menuitem.text, nil,nil,nil,nil, bit64.bor(F.EF_DISABLEHISTORY))
             == F.EEC_MODIFIED
          then
            local finfo = win.GetFileInfo(filename)
            if finfo then
              farhost.PutFiles(handle, {finfo}, false, tmpdir, F.OPM_SILENT)
              need_update = true
            end
          end
        end
        win.DeleteFile(filename)
        MySetDir(handle, curdir) -- restore plugin's directory
        if need_update then
          panel.UpdatePanel(handle)
          panel.RedrawPanel(handle)
        end
      elseif item.BreakKey == "CtrlPgUp" then
        -- Panel.SetPath(0, menuitem.dir, menuitem.item.FileName) -- it works but it's macro-API
        SetPath(handle, menuitem.dir, menuitem.item.FileName)
        break
      end
    end
  elseif foundlist.nTotalFiles > 0 then
    far.Message("No files containing the given search pattern", nil,nil,"w")
  else
    far.Message("No files matching the given file mask", nil,nil,"w")
  end

--###  farhost.FreeUserData(handle, freelist)
  win.RemoveDir(tmpdir) -- remove temporary directory
end

Macro {
  description=Title;
  area="Shell"; key=MacroKey;
  flags="NoFilePanels";
  action=function()
    local data = GetDialogData()
    if data then Find(data); end
  end;
}
