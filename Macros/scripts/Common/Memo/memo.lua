-- Start date    :  2026-02-27
-- Original      :  C++ far2l plugin "Memo" by "stpork" (https://github.com/stpork)
-- License       :  GNU GPL (as the original plugin)
-- Far2m plugin  :  LuaMacro

local DB_Key  = "shmuz"
local DB_Name = "Memo"
local MemoDir = far.InMyConfig("plugins/luafar/memo_files")

local MEMO_COUNT = 10
local POS_TITLE = 1     -- Dialog title
local POS_MEMO  = 2     -- Main memo editor (DI_MEMOEDIT)
local POS_INDICATOR = 3 -- Page indicator at bottom

-- These are used as keys in saved data
local CURIDX  = "CurIndex"
local SWITCHK = "SwitchKeys"
local FULLSCR = "FullScreenKeys"

local ThisDir = (...):match(".+/")
local F = far.Flags
local mData
local mEditorId
local mFullScreen

local function ErrMsg(fmt, ...)
  far.Message(fmt:format(...), "Error", nil, "w")
end

local SwitchKeyList = {
  { Text= "Alt+0...9"        ; pattern= "^Alt[0-9]$"; },
  { Text= "Ctrl+0...9"       ; pattern= "^Ctrl[0-9]$"; },
  { Text= "Alt+Shift+0...9"  ; pattern= "^AltShift[0-9]$"; },
  { Text= "Ctrl+Shift+0...9" ; pattern= "^CtrlShift[0-9]$"; },
  { Text= "Ctrl+Alt+0...9"   ; pattern= "^CtrlAlt[0-9]$"; },
}

local function MatchSwitchMemoPattern(key)
  return key:match(SwitchKeyList[mData[SWITCHK]].pattern)
end

local FullScreenKeyList = {
  { Text= "F5"       ; key= "F5"; },
  { Text= "Alt+F5"   ; key= "AltF5"; },
  { Text= "Shift+F5" ; key= "ShiftF5"; },
}

local function MatchFullScreenPattern(key)
  return key == FullScreenKeyList[mData[FULLSCR]].key
end

local function CheckFileOverwrite(fname)
  local attr = win.GetFileAttr(fname)
  if attr and attr:find("d") then
    far.Message(("\"%s\" is a directory"):format(fname))
    return false
  elseif attr then
    local msg = ("File \"%s\" already exists. Overwrite?"):format(fname)
    return 1 == far.Message(msg, "Confirm", "Yes;No", "w")
  else
    return true
  end
end

local function Normalize(val, low, high, default)
  val = math.floor(tonumber(val) or default)
  return val >= low and val <= high and val or default
end

local function LoadData()
  local data = mf.mload(DB_Key, DB_Name) or {}
  for i=1,MEMO_COUNT do
    local tt = data[i] or {}
    tt.FileName = tt.FileName or ("memo-%02d.txt"):format(i)
    data[i] = tt
  end
  -- Normalization
  data[CURIDX]  = Normalize(data[CURIDX],  1, MEMO_COUNT, 1)
  data[SWITCHK] = Normalize(data[SWITCHK], 1, #SwitchKeyList, 1)
  data[FULLSCR] = Normalize(data[FULLSCR], 1, #FullScreenKeyList, 1)
  return data
end

local function SaveData(data)
  mf.msave(DB_Key, DB_Name, data)
end

local function GetFileName()
  local index = mData[CURIDX]
  return mData[index].FileName
end

local function GetMemoFilePath()
  local attr = win.GetFileAttr(MemoDir)
  if attr and attr:find("d") then
    local fname = GetFileName()
    return win.JoinPath(MemoDir, fname)
  end
  ErrMsg("Directory \"%s\" does not exist", MemoDir)
  return nil
end

local function LoadFileContent(path)
  local fp = io.open(path)
  if fp then
    if fp:read(3) ~= "\239\187\191" then -- UTF-8 BOM
      fp:seek("set", 0)
    end
    local content = fp:read("*all") or ""
    fp:close()
    return content
  end
  return ""
end

local function SaveFileContent(path, content)
  local tmp = path .. ".tmp"
  local fp, err = io.open(tmp, "wb")
  if not fp then
    ErrMsg("Can't write \"%s\": %s", tmp, tostring(err))
    return false
  end

  fp:write(content)
  fp:close()

  -- Atomic replace on most filesystems
  local ok, renErr = win.MoveFile(tmp, path, "r") -- "r"==MOVEFILE_REPLACE_EXISTING
  if not ok then
    win.DeleteFile(tmp)
    ErrMsg("Can't replace \"%s\": %s", path, tostring(renErr))
    return false
  end
  return true
end

local function UpdateIndicator(hDlg)
  local cnt = 1
  local dot = utf8.char(0x2022)
  local indic = (dot.."1"):rep(MEMO_COUNT)..dot
  indic = indic:gsub("1", function()
      local c = (cnt == mData[CURIDX] and "[&%d]" or " %d "):format(cnt % 10)
      cnt = cnt + 1
      return c
    end)
  hDlg:SetText(POS_INDICATOR, indic)
end

-- Save current memo content to file
local function SaveCurrentMemo(hDlg)
  local filepath = GetMemoFilePath()
  if filepath then
    local content = hDlg:GetText(POS_MEMO)
    SaveFileContent(filepath, content)
  end
end

local function UpdateTitle(hDlg)
  local ei = editor.GetInfo(mEditorId)
  local W = ei.WindowSizeX
  local mark = (0 == bit64.band(ei.CurState, F.ECSTATE_MODIFIED)) and "" or "*"
  local fileinfo = ("[%s%d] %s"):format(mark, mData[CURIDX], GetFileName())
  local lineinfo = ("Line %3d/%d | Col %3d"):format(ei.CurLine, ei.TotalLines, ei.CurTabPos)
  local title = fileinfo
  local len = fileinfo:len() + lineinfo:len()
  if len <= W - 2 then
    title = fileinfo .. (" "):rep(W - 2 - len) .. lineinfo
  end
  hDlg:SetText(POS_TITLE, title)
end

-- Save current memo to external file
local function SaveMemoAs(hDlg)
  -- Default: memo-01.txt ... memo-10.txt in home directory
  local Name = GetFileName()
  local Path = win.JoinPath(far.GetMyHome(), Name)
  local destPath = far.InputBox(nil, "Save Memo", "Enter destination path:", "MemoSave",
                                Path, nil, nil, "FIB_NONE")
  if destPath and CheckFileOverwrite(destPath) then
    SaveFileContent(destPath, hDlg:GetText(POS_MEMO))
  end
end

local function RenameMemo(hDlg)
  local Name = GetFileName()
  local DestName = far.InputBox(nil, "Rename Memo", "Enter file name without path:", "MemoRename",
                                Name, nil, nil, "FIB_NONE")
  if DestName then
    local name = DestName:match("[^/]+$")
    if name then
      local fullname = win.JoinPath(MemoDir, name)
      if CheckFileOverwrite(fullname) then
        local content = hDlg:GetText(POS_MEMO)
        SaveFileContent(fullname, content)
        local index = mData[CURIDX]
        mData[index].FileName = name
        return true
      end
    end
  end
end

local function InitActions(hDlg)
  local filepath = GetMemoFilePath()
  if not filepath then
    return false
  end
  mEditorId = hDlg:GetMemoEditId(POS_MEMO)
  editor.SetVirtualFileName(mEditorId, filepath)

  local content = LoadFileContent(filepath)
  hDlg:SetText(POS_MEMO, content)
  editor.SetSavedState(mEditorId, true)
  local index = mData[CURIDX]
  local tt = mData[index]
  editor.SetPosition(mEditorId, tt.CurLine, tt.CurPos)

  UpdateTitle(hDlg)
  UpdateIndicator(hDlg)
  return true
end

local function CloseActions(hDlg, newindex)
  -- save the memo being left (and its data)
  local info = editor.GetInfo(mEditorId)
  local index = mData[CURIDX]
  local tt = mData[index]
  tt.CurLine, tt.CurPos = info.CurLine, info.CurPos
  if 0 ~= bit64.band(info.CurState, F.ECSTATE_MODIFIED) then
    SaveCurrentMemo(hDlg)
  end
  -- switch index
  mData[CURIDX] = newindex or mData[CURIDX]
  SaveData(mData)
end

local function CalcDialogSize()
  local scrRect = actl.GetFarRect()
  local scrWidth, scrHeight = 80, 25
  if scrRect then
    scrWidth = scrRect.Right - scrRect.Left + 1
    scrHeight = scrRect.Bottom - scrRect.Top + 1
  end
  return {
    X = mFullScreen and scrWidth  or math.max(43, scrWidth-22);
    Y = mFullScreen and scrHeight or math.max(5, scrHeight-12);
  }
end

local function Resize(hDlg)
  local dlgSize = CalcDialogSize()
  hDlg:EnableRedraw(false)
  hDlg:ResizeDialog(nil, dlgSize)
  hDlg:MoveDialog(1, {X=-1; Y=-1}) -- center on screen
  hDlg:SetItemPosition(POS_TITLE,     { Left=1; Top=0;           Right=dlgSize.X-2; Bottom=0 })
  hDlg:SetItemPosition(POS_MEMO,      { Left=1; Top=1;           Right=dlgSize.X-2; Bottom=dlgSize.Y-2 })
  hDlg:SetItemPosition(POS_INDICATOR, { Left=1; Top=dlgSize.Y-1; Right=dlgSize.X-2; Bottom=dlgSize.Y-1 })
  UpdateTitle(hDlg)
  hDlg:EnableRedraw(true)
end

local function OpenConfigDialog()
  local sd = require "far2.simpledialog"
  local Items = {
    { tp="dbox"; text="Configuration"; },

    { tp="text"; text="Keys for memo selection:"; },
    { tp="combobox"; list=SwitchKeyList; dropdown=1; name=SWITCHK; val=mData[SWITCHK]; },
    { tp="text"; text="Key for full screen toggling:"; },
    { tp="combobox"; list=FullScreenKeyList; dropdown=1; name=FULLSCR; val=mData[FULLSCR]; },

    { tp="sep"; },
    { tp="butt"; default=1; centergroup=1; text="OK"; },
    { tp="butt"; cancel=1; centergroup=1; text="Cancel"; },
  }
  local Dlg = sd.New(Items)
  local Out = Dlg:Run()
  if Out then
    mData[SWITCHK] = Out[SWITCHK]
    mData[FULLSCR] = Out[FULLSCR]
    SaveData(mData)
  end
end

-- Create and run the memo dialog
local function OpenMemoDialog()
  win.CreateDir(MemoDir)
  mData = LoadData()

  local dlgSize = CalcDialogSize()
  local Items = {
    { F.DI_TEXT,     1, 0, dlgSize.X, 0,             nil, nil, nil, nil, ""},
    { F.DI_MEMOEDIT, 1, 1, dlgSize.X-2, dlgSize.Y-2, nil, nil, nil, nil, ""},
    { F.DI_TEXT,     1, dlgSize.Y-1, dlgSize.X, 0,   nil, nil, nil, F.DIF_CENTERTEXT, ""},
  }

  local newIndex
  local wasError

  local function DlgProc(hDlg, Msg, Param1, Param2)
    if Msg == F.DN_INITDIALOG then
      if not InitActions(hDlg) then
        wasError = true; hDlg:Close()
      end

    elseif Msg == F.DN_KEY then
      if Param1 == POS_MEMO then
        local key = far.KeyToName(Param2)

        if key == "ShiftF2" then -- Save As
          SaveMemoAs(hDlg)

        elseif key == "ShiftF6" then -- Rename
          if RenameMemo(hDlg) then
            newIndex = mData[CURIDX]
            hDlg:Close() -- update highlighting as the extension may have changed
          end

        elseif key == "F9" or key == "AltShiftF9" then
          OpenConfigDialog()

        elseif MatchFullScreenPattern(key) then
          mFullScreen = not mFullScreen
          Resize(hDlg)

        -- Switch memo
        elseif MatchSwitchMemoPattern(key) then
          local idx = tonumber(key:match("[0-9]"))
          newIndex = (idx == 0) and 10 or idx
          hDlg:Close() -- update highlighting as the extension may have changed

        else
          return nil -- tell Far the key wasn't processed

        end
        return true -- tell Far the key was processed
      end

    elseif Msg == F.DN_MOUSECLICK then
      if Param1 == POS_INDICATOR then
        local R = hDlg:GetDlgRect()                 -- Dialog rectangle.
        local DW = R.Right - R.Left + 1             -- Dialog width.
        local IW = MEMO_COUNT*4 + 1                 -- Indicators width.
        local X = Param2.MousePositionX - R.Left    -- Relative click X position.
        local X0 = math.floor((DW - IW) / 2)        -- The X of the 1-st indicator left edge.
        local index = math.ceil((X - X0) / 4)       -- Each indicator occupies 4 cells.
        if index >= 1 and index <= MEMO_COUNT then
          newIndex = index
          hDlg:Close() -- update highlighting as the extension may have changed
        end
      end

    elseif Msg == F.DN_CLOSE then
      if not wasError then CloseActions(hDlg, newIndex) end

    elseif Msg == F.DN_RESIZECONSOLE then
      Resize(hDlg)

    end
  end

  local Flags = F.FDLG_KEEPCONSOLETITLE
  local HelpTopic = "<"..ThisDir..">Contents"
  far.Dialog(nil, -1, -1, dlgSize.X, dlgSize.Y, HelpTopic, Items, Flags, DlgProc)
  return newIndex
end

Event {
  group="EditorEvent";
  description="Memo editor: update title";
  action=function(id, event, param)
    if id == mEditorId and event == F.EE_REDRAW then
      local wi = actl.GetWindowInfo()
      if wi and wi.Type == F.WTYPE_DIALOG then
        UpdateTitle(wi.Id)
      end
    end
  end;
}

Macro {
  id="D27C6B7D-0343-42D4-A339-1ACEF32E142C";
  description="Memo application";
  area="Common"; key="CtrlAltM";
  action=function()
    -- use mf.acall to avoid seeing "P" in the upper left screen corner
    mFullScreen = false
    mf.acall(
      function()
        while OpenMemoDialog() do end
      end)
  end;
}
