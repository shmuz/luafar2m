-- Start date    :  2026-02-27
-- Original      :  C++ far2l plugin "Memo" by "stpork" (https://github.com/stpork)
-- License       :  GNU GPL (as the original plugin)
-- Far plugin    :  LuaMacro

local DB_Key  = "shmuz"
local DB_Name = "Memo"
local MemoDir = far.InMyConfig("plugins/luafar/memo_files")

local MEMO_COUNT  = 10
local POS_TITLE = 1     -- Dialog title
local POS_MEMO  = 2     -- Main memo editor (DI_MEMOEDIT)
local POS_INDICATOR = 3 -- Page indicator at bottom

local F = far.Flags
local Data

local function NormIndex(idx)
  return idx >= 1 and idx <= MEMO_COUNT and idx or 1
end

local function LoadData()
  Data = mf.mload(DB_Key, DB_Name) or {}
  -- Validation
  Data.CurIndex = NormIndex(Data.CurIndex or 1)
end

local function SaveData()
  mf.msave(DB_Key, DB_Name, Data)
end

local function MakeFileName(index)
  return index <= 5 and ("memo-%02d.txt"):format(index) or ("memo-%02d.lua"):format(index)
end

-- Get memo file path: memo-01.txt ... memo-10.txt
local function GetMemoFilePath(index)
  local attr = win.GetFileAttr(MemoDir)
  if attr and attr:find("d") then
    local fname = MakeFileName(index)
    return win.JoinPath(MemoDir, fname)
  end
  local msg = ("Directory \"%s\" does not exist"):format(MemoDir)
  far.Message(msg, "Error", nil, "w")
  return nil
end

-- Load file content
local function LoadFileContent(path)
  local fp = io.open(path)
  if fp then
    local content = fp:read("*all")
    fp:close()
    return content
  end
  return ""
end

-- Save file content
local function SaveFileContent(path, content)
  local fp = io.open(path, "w")
  if fp then
    fp:write(content)
    fp:close()
  end
end

local function UpdateIndicator(hDlg, index)
  index = NormIndex(index)
  local cnt = 1
  local dot = utf8.char(0x2022)
  local indic = (dot.."1"):rep(MEMO_COUNT)..dot
  indic = indic:gsub("1", function()
      local c = (cnt == index and "[&%d]" or " %d "):format(cnt % MEMO_COUNT)
      cnt = cnt + 1
      return c
    end)
  hDlg:SetText(POS_INDICATOR, indic)
end

-- Save current memo content to file
local function SaveCurrentMemo(hDlg)
  local content = hDlg:GetText(POS_MEMO)
  local filepath = GetMemoFilePath(Data.CurIndex)
  if filepath then
    SaveFileContent(filepath, content)
  end
end

local function UpdateTitle(hDlg, index)
  local title = MakeFileName(index)
  hDlg:SetText(POS_TITLE, title)
end

-- Save current memo to external file (F2/Shift+F2)
local function SaveMemoAs(hDlg)
  -- Default: memo-01.txt ... memo-10.txt in home directory
  local memoNum = Data.CurIndex
  local defaultName = MakeFileName(memoNum)
  local defaultPath = win.JoinPath(far.GetMyHome(), defaultName)
  local destPath = far.InputBox(nil, "Save Memo", "Enter destination path:", "MemoSave",
                                defaultPath, nil, nil, "FIB_NONE")
  if destPath then
    SaveFileContent(destPath, hDlg:GetText(POS_MEMO))
  end
end

-- Create and run the memo dialog
local function OpenMemoDialog()
  win.CreateDir(MemoDir)
  LoadData()

  -- Get console size for dialog dimensions
  local screenRect = actl.GetFarRect()
  local screenWidth = 80
  local screenHeight = 25
  if screenRect then
    screenWidth = screenRect.Right - screenRect.Left + 1
    screenHeight = screenRect.Bottom - screenRect.Top + 1
  end

  local dlgWidth = math.max(43, screenWidth - 22)
  local dlgHeight = math.max(5, screenHeight - 12)

  local Items = {
    { F.DI_TEXT,     1, 0, dlgWidth, 0,             nil, nil, nil, F.DIF_CENTERTEXT, ""},
    { F.DI_MEMOEDIT, 1, 1, dlgWidth-2, dlgHeight-2, nil, nil, nil, nil, ""},
    { F.DI_TEXT,     1, dlgHeight-1, dlgWidth, 0,   nil, nil, nil, F.DIF_CENTERTEXT, ""},
  }
  local switching

  local function DlgProc(hDlg, Msg, Param1, Param2)
    if Msg == F.DN_INITDIALOG then
      local editor_id = hDlg:GetMemoEditId(POS_MEMO)
      local filepath = GetMemoFilePath(Data.CurIndex)
      editor.SetVirtualFileName(editor_id, filepath)
      if filepath then
        local content = LoadFileContent(filepath)
        hDlg:SetText(POS_MEMO, content)
      end
      UpdateTitle(hDlg, Data.CurIndex)
      UpdateIndicator(hDlg, Data.CurIndex)

    elseif Msg == F.DN_KEY then
      if Param1 == POS_MEMO then
        local key = far.KeyToName(Param2)

        -- F2/Shift+F2: Save As
        if key == "F2" or key == "ShiftF2" then
          SaveMemoAs(hDlg)
        end

        -- Ctrl+0-9 or Alt+0-9: switch memo
        if key:match("^Ctrl[0-9]$") or key:match("^Alt[0-9]$") then
          local idx = tonumber(key:match("[0-9]"))
          switching = (idx == 0) and 10 or idx
          -- Reopen the dialog in order to recreate MemoEdit and make highlighting
          -- plugins to use the syntax corresponding to the new file extension.
          hDlg:Close()
        end
      end

    elseif Msg == F.DN_CLOSE then
      SaveCurrentMemo(hDlg)
      Data.CurIndex = switching or Data.CurIndex
      SaveData()

    end
  end

  far.Dialog(nil, -1, -1, dlgWidth, dlgHeight, nil, Items, nil, DlgProc)
  return switching
end

Macro {
  id="D27C6B7D-0343-42D4-A339-1ACEF32E142C";
  description="A replica of Memo plugin";
  area="Common"; key="CtrlAltM";
  action=function()
    while OpenMemoDialog() do end
  end;
}
