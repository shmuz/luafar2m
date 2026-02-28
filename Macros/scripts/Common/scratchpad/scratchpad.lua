-- Start date    :  2026-02-27
-- Original      :  C++ far2l plugin "Memo" by "stpork" (https://github.com/stpork)
-- License       :  GNU GPL (as the original plugin)
-- Far plugin    :  LuaMacro

local DB_Key  = "shmuz"
local DB_Name = "Memo"

local MEMO_COUNT  = 10
local POS_TITLE = 1     -- Dialog title
local POS_MEMO  = 2     -- Main memo editor (DI_MEMOEDIT)
local POS_INDICATOR = 3 -- Page indicator at bottom

local F = far.Flags
local MemoDir
local CurrentMemo -- Current memo index (1-10)

-- Get memo file path: memo-01.txt ... memo-10.txt
local function GetMemoFilePath(index)
  local attr = win.GetFileAttr(MemoDir)
  if attr and attr:find("d") then
    local fname = ("memo-%02d.txt"):format(index)
    return win.JoinPath(MemoDir, fname)
  end
  local msg = ("Directory \"%s\" does not exist"):format(MemoDir)
  far.Message(msg, "Error", nil, "w")
  return nil
end

-- Load last selected memo index
local function LoadLastMemoIndex()
  local data = mf.mload(DB_Key, DB_Name) or {}
  CurrentMemo = data.LastMemo or 1
  if CurrentMemo < 1 or CurrentMemo > MEMO_COUNT then
    CurrentMemo = 1
  end
  return CurrentMemo
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
  if index < 1 or index > MEMO_COUNT then
    index = 1
  end
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
  local filepath = GetMemoFilePath(CurrentMemo)
  if filepath then
    SaveFileContent(filepath, content)
  end
end

-- Update title: "Memo - 1", etc.
local function UpdateTitle(hDlg, index)
  local title = ("[ Memo - %d ]"):format(index)
  hDlg:SetText(POS_TITLE, title)
end

-- Switch to different memo - saves current, loads new, updates UI
local function SwitchToMemo(hDlg, index)
  if index >= 1 and index <= MEMO_COUNT and index ~= CurrentMemo then
    local filepath = GetMemoFilePath(index)
    if filepath then
      SaveCurrentMemo(hDlg)  -- Auto-save before switching
      CurrentMemo = index
      UpdateTitle(hDlg, index)
      local content = LoadFileContent(filepath)
      hDlg:SetText(POS_MEMO, content)
      UpdateIndicator(hDlg, index)
    end
  end
end

-- Save current memo to external file (F2/Shift+F2)
local function SaveMemoAs(hDlg)
  -- Default: memo-01.txt ... memo-10.txt in home directory
  local memoNum = CurrentMemo
  local defaultName = ("memo-%02d.txt"):format(memoNum)
  local defaultPath = win.JoinPath(far.GetMyHome(), defaultName)
  local destPath = far.InputBox(nil, "Save Memo", "Enter destination path:", "MemoSave",
                                defaultPath, nil, nil, "FIB_NONE")
  if destPath then
    SaveFileContent(destPath, hDlg:GetText(POS_MEMO))
  end
end

-- Create and run the memo dialog
local function OpenMemoDialog()
  MemoDir = far.InMyConfig("plugins/luafar/memo_files")
  win.CreateDir(MemoDir)
  CurrentMemo = LoadLastMemoIndex()

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

  local function DlgProc(hDlg, Msg, Param1, Param2)
    if Msg == F.DN_INITDIALOG then
      local filepath = GetMemoFilePath(CurrentMemo)
      if filepath then
        local content = LoadFileContent(filepath)
        hDlg:SetText(POS_MEMO, content)
      end
      UpdateTitle(hDlg, CurrentMemo)
      UpdateIndicator(hDlg, CurrentMemo)

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
          idx = (idx == 0) and 10 or idx
          if idx <= MEMO_COUNT then
            SwitchToMemo(hDlg, idx)
          end
        end
      end

    elseif Msg == F.DN_CLOSE then
      SaveCurrentMemo(hDlg)
      mf.msave(DB_Key, DB_Name, { LastMemo=CurrentMemo; })

    end
  end

  far.Dialog(nil, -1, -1, dlgWidth, dlgHeight, nil, Items, nil, DlgProc)
end

Macro {
  id="D27C6B7D-0343-42D4-A339-1ACEF32E142C";
  description="A replica of Memo plugin";
  area="Common"; key="CtrlAltM";
  action=function() OpenMemoDialog() end;
}
