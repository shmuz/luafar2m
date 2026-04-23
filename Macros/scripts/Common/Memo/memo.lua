-- Start date    :  2026-02-27
-- Original      :  C++ far2l plugin "Memo" by "stpork" (https://github.com/stpork)
-- License       :  GNU GPL (as the original plugin)
-- Portability   :  far2m, Linux only
-- Far plugin    :  LuaMacro

local DB_Key  = "shmuz"
local DB_Name = "Memo"
local MemoDir = far.InMyConfig("plugins/luafar/memo_files")
local MainDialogId = "37316E1D-A58E-40CE-9593-15E86984930C"
local ConfigDialogId = "F2912E1A-64E7-49D4-83D4-D3093E4D91E2"

local MEMO_COUNT = 10
local POS_TITLE = 1     -- Dialog title
local POS_MEMO  = 2     -- Main memo editor (DI_MEMOEDIT)
local POS_INDICATOR = 3 -- Page indicator at bottom
local QUIT = "quit"

-- These are used as keys in saved data
local CURIDX  = "CurIndex"
local SWITCHK = "SwitchKeys"
local FULLSCR = "FullScreenKeys"

local ThisDir = (...):match(".+/")
local BOM = "\239\187\191" -- UTF-8 BOM
local F = far.Flags

local mData
local mEditorId
local mFullScreen
local mUseBom
local m_hDlg

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
    ErrMsg("\"%s\" is a directory", fname)
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

local function GetCurFileName()
  local index = mData[CURIDX]
  return mData[index].FileName
end

local function GetCurFilePath()
  return win.JoinPath(MemoDir, GetCurFileName())
end

local function LoadFileContent(path)
  mUseBom = false
  local fp = io.open(path)
  if fp then
    mUseBom = (fp:read(#BOM) == BOM)
    if not mUseBom then
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

  if mUseBom then fp:write(BOM) end
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
  local dot = utf8.char(0x2022)
  local indic = dot
  for k=1,MEMO_COUNT do
    indic = (k == mData[CURIDX] and "%s[&%d]%s" or "%s %d %s"):format(indic, k % 10, dot)
  end
  hDlg:SetText(POS_INDICATOR, indic)
end

-- Save current memo content to file
local function SaveCurrentMemo(hDlg)
  local filepath = GetCurFilePath()
  local content = hDlg:GetText(POS_MEMO)
  return SaveFileContent(filepath, content)
end

local function UpdateTitle(hDlg)
  local EI = editor.GetInfo(mEditorId)
  if EI then
    local W = EI.WindowSizeX
    local mark = (0 == bit64.band(EI.CurState, F.ECSTATE_MODIFIED)) and "" or "*"
    local fileinfo = ("[%s%d] %s"):format(mark, mData[CURIDX], GetCurFileName())
    local lineinfo = ("Line %3d/%d | Col %3d"):format(EI.CurLine, EI.TotalLines, EI.CurTabPos)
    local title = fileinfo
    local len = fileinfo:len() + lineinfo:len()
    if len <= W - 2 then
      title = fileinfo .. (" "):rep(W - 2 - len) .. lineinfo
    end
    hDlg:SetText(POS_TITLE, title)
  else
    hDlg:SetText(POS_TITLE, "Error: could not retrieve editor info")
  end
end

-- Save current memo to external file
local function SaveMemoAs(hDlg)
  -- Default: memo-01.txt ... memo-10.txt in home directory
  local Name = GetCurFileName()
  local Path = win.JoinPath(far.GetMyHome(), Name)
  local destPath = far.InputBox(nil, "Save Memo", "Enter destination path:", "MemoSave",
                                Path, nil, nil, "FIB_NONE")
  if destPath and CheckFileOverwrite(destPath) then
    SaveFileContent(destPath, hDlg:GetText(POS_MEMO))
  end
end

local function RenameMemo(hDlg)
  local DestName = far.InputBox(nil,
      "Rename Memo",                   -- title
      "Enter file name without path:", -- prompt
      "MemoRename",                    -- history name
      GetCurFileName(),                -- initial input text
      nil, nil, "FIB_NONE")            -- maxlength, helptopic, flags

  if not DestName then return false end

  if DestName:find("/") then
    ErrMsg("Only file name may be entered here, no path allowed")
    return false
  end

  local src = GetCurFilePath()
  local trg = win.JoinPath(MemoDir, DestName)
  local ok, err = win.MoveFile(src, trg)
  if not ok then
    ErrMsg("Can't rename \"%s\": %s", src, tostring(err))
    return false
  end

  local index = mData[CURIDX]
  mData[index].FileName = DestName
  return true
end

local function InitActions(hDlg)
  local filepath = GetCurFilePath()
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
end

local function CloseActions(hDlg, newIndex)
  local info = editor.GetInfo(mEditorId)
  if not info then
    ErrMsg("Could not retrieve editor info. Exiting.")
    return QUIT
  end

  if 0 ~= bit64.band(info.CurState, F.ECSTATE_MODIFIED) then
    if not SaveCurrentMemo(hDlg) then
      if 2 ~= far.Message("Error occurred. Continue anyway?", "Error", "&No;&Yes", "w") then
        return false
      end
    end
  end
  -- get params of the current memo
  local index = mData[CURIDX]
  local item = mData[index]
  item.CurLine, item.CurPos = info.CurLine, info.CurPos
  -- update the index
  if newIndex then
    mData[CURIDX] = newIndex
  end
  SaveData(mData)
  return true
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
    guid = ConfigDialogId;
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

local function OpenMemoDialog()
  local ok, msg = win.CreateDir(MemoDir, true)
  if not ok then ErrMsg("%s", msg); return; end

  mData = LoadData()

  local dlgSize = CalcDialogSize()
  local Items = {
    { F.DI_TEXT,     1, 0, dlgSize.X, 0,             nil, nil, nil, nil, ""},
    { F.DI_MEMOEDIT, 1, 1, dlgSize.X-2, dlgSize.Y-2, nil, nil, nil, nil, ""},
    { F.DI_TEXT,     1, dlgSize.Y-1, dlgSize.X, 0,   nil, nil, nil, F.DIF_CENTERTEXT, ""},
  }

  local newIndex

  local function DlgProc(hDlg, Msg, Param1, Param2)
    if Msg == F.DN_INITDIALOG then
      InitActions(hDlg)

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

        -- Switch memo by a key combination
        elseif MatchSwitchMemoPattern(key) then
          local idx = tonumber(key:match("[0-9]"))
          newIndex = (idx == 0) and 10 or idx
          hDlg:Close() -- update highlighting as the extension may have changed

        else
          return nil -- tell Far the key wasn't processed

        end
        return true -- tell Far the key was processed
      end

    -- Switch memo by a mouse click
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
      local ret = CloseActions(hDlg, newIndex)
      if ret == QUIT then
        newIndex = nil
      elseif not ret then
        newIndex = nil
        return 0 -- don't close the dialog
      end

    elseif Msg == F.DN_RESIZECONSOLE then
      Resize(hDlg)

    end
  end

  local Flags = F.FDLG_KEEPCONSOLETITLE
  local HelpTopic = "<"..ThisDir..">Contents"
  local hDlg = far.DialogInit(win.Uuid(MainDialogId), -1, -1, dlgSize.X, dlgSize.Y,
                              HelpTopic, Items, Flags, DlgProc)
  m_hDlg = hDlg
  far.DialogRun(hDlg)
  far.DialogFree(hDlg)
  return newIndex
end

Event {
  group="EditorEvent";
  description="Memo editor: update title";
  action=function(id, event, param)
    if id == mEditorId and event == F.EE_REDRAW then
      UpdateTitle(m_hDlg)
    end
  end;
}

Macro {
  id="D27C6B7D-0343-42D4-A339-1ACEF32E142C";
  description="Memo application";
  area="Shell QView Info Tree Editor Viewer"; key="AltShiftM";
  action=function()
    mFullScreen = false
    mf.acall(    -- use mf.acall to avoid seeing "P" in the upper left screen corner
      function()
        while OpenMemoDialog() do end
      end)
  end;
}
