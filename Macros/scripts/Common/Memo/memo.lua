-- Start date    :  2026-02-27
-- Original      :  C++ far2l plugin "Memo" by "stpork" (https://github.com/stpork)
-- License       :  GNU GPL (as the original plugin)
-- Portability   :  far2m, Linux only
-- Far plugin    :  LuaMacro

local Eng = {
  ButtonCancel        = "Cancel";
  ButtonOk            = "OK";
  ButtonsNoYes        = "&No;&Yes";
  CannotRead          = "Can't read";
  CannotReplace       = "Can't replace";
  CannotWrite         = "Can't write file";
  ConfigFullScreenKey = "Key for full screen toggling:";
  ConfigSelectKeys    = "Keys for memo selection:";
  ConfigTitle         = "Configuration";
  ConfirmTitle        = "Confirm";
  ErrGetEditorInfo    = "Error: could not retrieve editor info";
  Error               = "Error";
  ErrSaveContinue     = "Cannot save the current memo. Continue anyway?";
  IsDirectory         = "is a directory";
  OverwritePrompt     = "File \"%s\" already exists. Overwrite?";
  RenameFailMsg       = "Can't rename";
  RenameNoPath        = "Enter file name only, no path allowed";
  RenamePrompt        = "Enter file name without path:";
  RenameTitle         = "Rename Memo";
  SavePrompt          = "Enter destination path:";
  SaveTitle           = "Save Memo";
  StatusColumn        = "Col";
  StatusLine          = "Line";
}

local Rus = {
  ButtonCancel        = "Отмена";
  ButtonOk            = "OK";
  ButtonsNoYes        = "&Нет;&Да";
  CannotRead          = "Не могу прочитать";
  CannotReplace       = "Не могу заменить";
  CannotWrite         = "Не могу записать файл";
  ConfigFullScreenKey = "Ключ для полноэкранного режима:";
  ConfigSelectKeys    = "Ключи для переключения мемо:";
  ConfigTitle         = "Конфигурация";
  ConfirmTitle        = "Подтверждение";
  ErrGetEditorInfo    = "Ошибка: не могу получить данные редактора";
  Error               = "Ошибка";
  ErrSaveContinue     = "Не могу сохранить текущее мемо. Продолжить тем не менее?";
  IsDirectory         = "является директорией";
  OverwritePrompt     = "Файл \"%s\" уже существует. Перезаписать?";
  RenameFailMsg       = "Не могу переименовать";
  RenameNoPath        = "Введите только имя файла, без пути";
  RenamePrompt        = "Введите имя файла без пути:";
  RenameTitle         = "Переименовать Мемо";
  SavePrompt          = "Введите путь назначения:";
  SaveTitle           = "Сохранить Мемо";
  StatusColumn        = "Кол";
  StatusLine          = "Стр";
}

local DB_Key  = "shmuz"
local DB_Name = "Memo"
local MemoDir = far.InMyConfig("plugins/luafar/memo_files")
local MainDialogId = "37316E1D-A58E-40CE-9593-15E86984930C"
local ConfigDialogId = "F2912E1A-64E7-49D4-83D4-D3093E4D91E2"
local DirSep = package.config:sub(1,1)

local MEMO_COUNT = 10
local POS_TITLE, POS_MEMO, POS_INDICATOR = 1,2,3 -- dialog item positions

-- These are used as keys in saved data
local KEY_CURIDX  = "CurIndex"
local KEY_SWITCH  = "SwitchKeys"
local KEY_FULLSCR = "FullScreenKeys"

local HelpTopic = ("<%s>Contents"):format((...):match(".+"..DirSep)) -- (...) is pathname of this script
local BOM = "\239\187\191" -- UTF-8 BOM
local F = far.Flags
local M

local mData
local mEditorId
local mFullScreen
local mUseBom
local m_hDlg

local function ErrMsg(fmt, ...)
  far.Message(fmt:format(...), M.Error, M.ButtonOk, "w")
end

local SwitchKeyList = {
  { Text= "Alt+0...9"        ; pattern= "^Alt[0-9]$"; },
  { Text= "Ctrl+0...9"       ; pattern= "^Ctrl[0-9]$"; },
  { Text= "Alt+Shift+0...9"  ; pattern= "^AltShift[0-9]$"; },
  { Text= "Ctrl+Shift+0...9" ; pattern= "^CtrlShift[0-9]$"; },
  { Text= "Ctrl+Alt+0...9"   ; pattern= "^CtrlAlt[0-9]$"; },
}

local function MatchSwitchMemoPattern(key)
  return key:match(SwitchKeyList[mData[KEY_SWITCH]].pattern)
end

local FullScreenKeyList = {
  { Text= "F5"       ; key= "F5"; },
  { Text= "Alt+F5"   ; key= "AltF5"; },
  { Text= "Shift+F5" ; key= "ShiftF5"; },
}

local function MatchFullScreenPattern(key)
  return key == FullScreenKeyList[mData[KEY_FULLSCR]].key
end

local function CheckFileOverwrite(fname)
  local attr = win.GetFileAttr(fname)
  if attr and attr:find("d") then
    ErrMsg("\"%s\" %s", fname, M.IsDirectory)
    return false
  elseif attr then
    local msg = M.OverwritePrompt:format(fname)
    return 1 == far.Message(msg, M.ConfirmTitle, ";YesNo", "w")
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
  data[KEY_CURIDX]  = Normalize(data[KEY_CURIDX],  1, MEMO_COUNT, 1)
  data[KEY_SWITCH]  = Normalize(data[KEY_SWITCH], 1, #SwitchKeyList, 1)
  data[KEY_FULLSCR] = Normalize(data[KEY_FULLSCR], 1, #FullScreenKeyList, 1)
  return data
end

local function SaveData(data)
  mf.msave(DB_Key, DB_Name, data)
end

local function GetCurFileName()
  local index = mData[KEY_CURIDX]
  return mData[index].FileName
end

local function GetCurFilePath()
  return win.JoinPath(MemoDir, GetCurFileName())
end

local function LoadFileContent(path)
  mUseBom = false
  local fp, err = io.open(path)
  if not fp then
    if win.GetFileAttr(path) then
      ErrMsg("%s \"%s\": %s", M.CannotRead, path, tostring(err))
    end
    return ""
  end

  mUseBom = (fp:read(#BOM) == BOM)
  if not mUseBom then
    fp:seek("set", 0)
  end
  local content = fp:read("*all") or ""
  fp:close()
  return content
end

local function SaveFileContent(path, content, useBom)
  local tmp = path .. ".tmp"
  local fp, err = io.open(tmp, "wb")
  if not fp then
    ErrMsg("%s: %s", M.CannotWrite, tostring(err))
    return false
  end

  if useBom then fp:write(BOM) end
  fp:write(content)
  fp:close()

  -- Atomic replace on most filesystems
  local ok, renErr = win.MoveFile(tmp, path, "r") -- "r"==MOVEFILE_REPLACE_EXISTING
  if not ok then
    win.DeleteFile(tmp)
    ErrMsg("%s \"%s\": %s", M.CannotReplace, path, tostring(renErr))
    return false
  end
  return true
end

local function UpdateIndicator(hDlg)
  local dot = utf8.char(0x2022)
  local indic = dot
  for k=1,MEMO_COUNT do
    indic = (k == mData[KEY_CURIDX] and "%s[&%d]%s" or "%s %d %s"):format(indic, k % 10, dot)
  end
  hDlg:SetText(POS_INDICATOR, indic)
end

-- Save current memo content to file
local function SaveCurrentMemo(hDlg)
  local filepath = GetCurFilePath()
  local content = hDlg:GetText(POS_MEMO)
  return SaveFileContent(filepath, content, mUseBom)
end

local function UpdateTitle(hDlg)
  local EI = editor.GetInfo(mEditorId)
  if EI then
    local W = EI.WindowSizeX
    local mark = (0 == bit64.band(EI.CurState, F.ECSTATE_MODIFIED)) and "" or "*"
    local fileinfo = ("[%s%d] %s"):format(mark, mData[KEY_CURIDX], GetCurFileName())
    local lineinfo = ("%s %3d/%d | %s %3d")
        :format(M.StatusLine, EI.CurLine, EI.TotalLines, M.StatusColumn, EI.CurTabPos)
    local title = fileinfo
    local len = fileinfo:len() + lineinfo:len()
    if len <= W - 2 then
      title = fileinfo .. (" "):rep(W - 2 - len) .. lineinfo
    end
    hDlg:SetText(POS_TITLE, title)
  else
    hDlg:SetText(POS_TITLE, M.ErrGetEditorInfo)
  end
end

-- Save current memo to external file
local function SaveMemoAs(hDlg)
  -- Default: memo-01.txt ... memo-10.txt in home directory
  local InitText = win.JoinPath(far.GetMyHome(), GetCurFileName())
  local Dest = far.InputBox(nil, M.SaveTitle, M.SavePrompt, "MemoSave",
                            InitText, nil, nil, "FIB_NONE")
  if Dest then
    local filename = win.ExpandEnv(Dest)
    if CheckFileOverwrite(filename) then
      SaveFileContent(filename, hDlg:GetText(POS_MEMO), mUseBom)
    end
  end
end

local function RenameMemo(hDlg)
  local DestName = far.InputBox(nil,
      M.RenameTitle,          -- title
      M.RenamePrompt,         -- prompt
      "MemoRename",           -- history name
      GetCurFileName(),       -- initial input text
      nil, nil, "FIB_NONE")   -- maxlength, helptopic, flags

  if not DestName then return end

  if DestName:find(DirSep) then
    ErrMsg(M.RenameNoPath)
    return
  end

  local src = GetCurFilePath()
  local trg = win.JoinPath(MemoDir, DestName)
  local ok, err = win.MoveFile(src, trg)
  if not ok then
    ErrMsg("%s \"%s\": %s", M.RenameFailMsg, GetCurFileName(), tostring(err))
    return
  end

  local index = mData[KEY_CURIDX]
  mData[index].FileName = DestName
  SaveData(mData)
  editor.SetVirtualFileName(mEditorId, GetCurFilePath())
  editor.Reparse(mEditorId)
  editor.Redraw()
end

local function InitActions(hDlg)
  local filepath = GetCurFilePath()
  editor.SetVirtualFileName(mEditorId, filepath)
  local content = LoadFileContent(filepath)
  hDlg:SetText(POS_MEMO, content)
  editor.SetSavedState(mEditorId, true)
  local index = mData[KEY_CURIDX]
  local tt = mData[index]

  -- Direct call of editor.SetPosition() or editor.Redraw() during DN_INITDIALOG
  -- result in drawing the editor content on the window below (e.g. on panels, editor, etc.)
  -- *** It can be seen when dragging the Memo dialog by mouse or by CtrlF5.
  -- *** mf.postmacro solves that problem.
  mf.postmacro(editor.SetPosition, mEditorId, tt.CurLine, tt.CurPos)

  UpdateTitle(hDlg)
  UpdateIndicator(hDlg)
end

local function CloseActions(hDlg, newIndex)
  local info = editor.GetInfo(mEditorId)
  if 0 ~= bit64.band(info.CurState, F.ECSTATE_MODIFIED) then
    if not SaveCurrentMemo(hDlg) then
      if 2 ~= far.Message( M.ErrSaveContinue, M.Error, M.ButtonsNoYes, "w") then
        return false
      end
    end
  end
  -- get params of the current memo
  local index = mData[KEY_CURIDX]
  local item = mData[index]
  item.CurLine, item.CurPos = info.CurLine, info.CurPos
  -- update the index
  mData[KEY_CURIDX] = newIndex
  SaveData(mData)
  return true
end

local function SwitchTo(hDlg, newindex)
  if newindex == mData[KEY_CURIDX] then return end
  if not CloseActions(hDlg, newindex) then return end
  InitActions(hDlg)
  editor.Reparse(mEditorId)
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
    { tp="dbox"; text=M.ConfigTitle; },

    { tp="text"; text=M.ConfigSelectKeys; },
    { tp="combobox"; list=SwitchKeyList; dropdown=1; name=KEY_SWITCH; val=mData[KEY_SWITCH]; },
    { tp="text"; text=M.ConfigFullScreenKey; },
    { tp="combobox"; list=FullScreenKeyList; dropdown=1; name=KEY_FULLSCR; val=mData[KEY_FULLSCR]; },

    { tp="sep"; },
    { tp="butt"; default=1; centergroup=1; text=M.ButtonOk; },
    { tp="butt"; cancel=1; centergroup=1; text=M.ButtonCancel; },
  }
  local Dlg = sd.New(Items)
  local Out = Dlg:Run()
  if Out then
    mData[KEY_SWITCH] = Out[KEY_SWITCH]
    mData[KEY_FULLSCR] = Out[KEY_FULLSCR]
    SaveData(mData)
  end
end

local function OpenMemoDialog()
  local dlgSize = CalcDialogSize()
  local Items = {
    { F.DI_TEXT,     1, 0, dlgSize.X, 0,             nil, nil, nil, nil, ""},
    { F.DI_MEMOEDIT, 1, 1, dlgSize.X-2, dlgSize.Y-2, nil, nil, nil, nil, ""},
    { F.DI_TEXT,     1, dlgSize.Y-1, dlgSize.X, 0,   nil, nil, nil, F.DIF_CENTERTEXT, ""},
  }

  local function DlgProc(hDlg, Msg, Param1, Param2)
    if Msg == F.DN_INITDIALOG then
      mEditorId = hDlg:GetMemoEditId(POS_MEMO)
      InitActions(hDlg)

    elseif Msg == F.DN_KEY then
      if Param1 == POS_MEMO then
        local key = far.KeyToName(Param2)

        if key == "Tab" then
          editor.ProcessKey(mEditorId, Param2)

        elseif key == "ShiftF2" then -- Save As
          SaveMemoAs(hDlg)

        elseif key == "ShiftF6" then -- Rename
          RenameMemo(hDlg)

        elseif key == "F9" or key == "AltShiftF9" then
          OpenConfigDialog()

        elseif MatchFullScreenPattern(key) then
          mFullScreen = not mFullScreen
          Resize(hDlg)

        -- Switch memo by a key combination
        elseif MatchSwitchMemoPattern(key) then
          local index = tonumber(key:match("[0-9]"))
          if index == 0 then index = 10 end
          SwitchTo(hDlg, index)

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
          SwitchTo(hDlg, index)
          return true
        end

      elseif Param1 == POS_TITLE then
        if Param2.EventFlags == F.DOUBLE_CLICK then
          mFullScreen = not mFullScreen
          Resize(hDlg)
          return true
        end
      end

    elseif Msg == F.DN_CLOSE then
      if not CloseActions(hDlg, mData[KEY_CURIDX]) then
        return 0 -- don't close the dialog
      end

    elseif Msg == F.DN_RESIZECONSOLE then
      Resize(hDlg)

    end
  end

  local ok, msg = win.CreateDir(MemoDir, true)
  if not ok then
    ErrMsg("%s", msg); return
  end

  mData = LoadData()
  m_hDlg =
      far.DialogInit(win.Uuid(MainDialogId), -1, -1, dlgSize.X, dlgSize.Y, HelpTopic, Items,
      F.FDLG_KEEPCONSOLETITLE, DlgProc)
  far.DialogRun(m_hDlg)
  far.DialogFree(m_hDlg)
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
    M = win.GetEnv("FARLANG") == "Russian" and Rus or Eng
    mFullScreen = false
    mf.acall(OpenMemoDialog) -- use mf.acall to avoid seeing "P" in the upper left screen corner
  end;
}
