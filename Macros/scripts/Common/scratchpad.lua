-- Start date    :  2026-02-27
-- Original      :  C++ far2l plugin "Memo" by "stpork" (https://github.com/stpork)
-- License       :  GNU GPL (as the original plugin)
-- Far plugin    :  LuaMacro
-- Dependencies  :  Lua module far2.simpledialog

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
  local fname = ("memo-%02d.txt"):format(index)
  return win.JoinPath(MemoDir, fname)
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
  local ok = false
  local fp = io.open(path, "w")
  if fp then
    fp:write(content)
    ok = (fp:seek() == #content)
    fp:close()
  end
  return ok
end

local function GetIndicator(index)
  if index < 1 or index > MEMO_COUNT then index = 1; end

  local cnt = 1
  local dot = utf8.char(0x2022)
  local indic = (dot.."1"):rep(MEMO_COUNT)..dot
  indic = indic:gsub("1", function()
      local c = (cnt == index and "[&%d]" or " %d "):format(cnt % MEMO_COUNT)
      cnt = cnt + 1
      return c
    end)
  return indic
end

-- Save current memo content to file
local function SaveCurrentMemo(hDlg)
  local content = hDlg:GetText(POS_MEMO)
  local filepath = GetMemoFilePath(CurrentMemo)
  SaveFileContent(filepath, content)
end

-- Update title: "Memo - 1", etc.
local function UpdateTitle(hDlg, index)
  local title = ("[ Memo - %d ]"):format(index)
  hDlg:SetText(POS_TITLE, title)
end

-- Switch to different memo - saves current, loads new, updates UI
local function SwitchToMemo(hDlg, index)
  if index >= 1 and index <= MEMO_COUNT and index ~= CurrentMemo then
    SaveCurrentMemo(hDlg)  -- Auto-save before switching
    CurrentMemo = index
    UpdateTitle(hDlg, index)
    local content = LoadFileContent(GetMemoFilePath(index))
    hDlg:SetText(POS_MEMO, content)
    hDlg:SetText(POS_INDICATOR, GetIndicator(index))
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
  return destPath and SaveFileContent(destPath, hDlg:GetText(POS_MEMO))
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

  local dlgWidth = screenWidth - 20
  local dlgHeight = screenHeight - 10

  local content = LoadFileContent(GetMemoFilePath(CurrentMemo))

  local Items = {
    width = dlgWidth;
    { tp="text"; x1=1; y1=0; x2=dlgWidth-2; centertext=1; },
    { tp="memo"; x1=1; y1=1; x2=dlgWidth-4; y2=dlgHeight-4; text=content; },
    { tp="text"; x1=1; x2=dlgWidth-2; centertext=1; text=GetIndicator(CurrentMemo); },
  }

  -- Dialog procedure - handles keyboard and close events
  -- DN_KEY: intercepts keys for memo switching
  -- DN_CLOSE: saves content and state
  function Items.proc(hDlg, Msg, Param1, Param2)
    if Msg == F.DN_INITDIALOG then
      UpdateTitle(hDlg, CurrentMemo)

    elseif Msg == "EVENT_KEY" then
      if Param1 == POS_MEMO then
        local key = Param2

        -- F2/Shift+F2: Save As
        if key == "F2" or key == "ShiftF2" then
          SaveMemoAs(hDlg)
          return true
        end

        -- Ctrl+0-9 or Alt+0-9: switch memo
        if key:match("^Ctrl[0-9]$") or key:match("^Alt[0-9]$") then
          local idx = tonumber(key:match("[0-9]"))
          idx = (idx == 0) and 10 or idx
          if idx <= MEMO_COUNT then
            SwitchToMemo(hDlg, idx)
            return true
          end
        end
      end

    elseif Msg == F.DN_CLOSE or Msg == "EVENT_CANCEL" then
      SaveCurrentMemo(hDlg)
      mf.msave(DB_Key, DB_Name, { LastMemo=CurrentMemo; })

    end
  end

  local sd = require "far2.simpledialog"
  local Dlg = sd.New(Items)
  Dlg:Run()
end

Macro {
  id="D27C6B7D-0343-42D4-A339-1ACEF32E142C";
  description="A replica of Memo plugin";
  area="Common"; key="CtrlAltM";
  action=function() OpenMemoDialog() end;
}
