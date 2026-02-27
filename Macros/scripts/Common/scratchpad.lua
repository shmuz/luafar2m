-- Start date : 2026-02-27
-- Original   : C++ far2l plugin "Memo" by "stpork" (https://github.com/stpork)
-- License    : GNU GPL (as the original plugin)

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

-- Load last selected memo index from state.ini
local function LoadLastMemoIndex()
  local data = mf.mload(DB_Key, DB_Name) or {}
  CurrentMemo = data.LastMemo or 1
  if CurrentMemo < 1 or CurrentMemo > MEMO_COUNT then
    CurrentMemo = 1
  end
  return CurrentMemo
end

-- Save last selected memo index to state.ini
local function SaveLastMemoIndex(index)
  mf.msave(DB_Key, DB_Name, { LastMemo=index; })
end

-- Load file content as wide string (UTF-8 -> wchar_t)
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

local function GetIndicatorWithX(targetMemo)
  if targetMemo < 1 or targetMemo > MEMO_COUNT then targetMemo = 1; end

  local cnt = 1
  local dot = utf8.char(0x2022)
  local indic = (dot.."1"):rep(MEMO_COUNT)..dot
  indic = indic:gsub("1", function()
      local c = (cnt == targetMemo and "[&%d]" or " %d "):format(cnt % MEMO_COUNT)
      cnt = cnt + 1
      return c
    end)
  return indic
end

-- Update indicator text to show current page
local function ShowXInIndicator(hDlg, targetMemo)
  hDlg:SetText(POS_INDICATOR, GetIndicatorWithX(targetMemo))
end

-- Get text from memo editor via dialog messages
local function GetMemoText(hDlg)
  return hDlg:GetText(POS_MEMO)
end

-- Save current memo content to file
local function SaveCurrentMemo(hDlg)
  local content = GetMemoText(hDlg)
  SaveFileContent(GetMemoFilePath(CurrentMemo), content)
end

-- Switch to different memo - saves current, loads new, updates UI
local function SwitchToMemo(hDlg, newMemo)
  if newMemo < 1 or newMemo > MEMO_COUNT or newMemo == CurrentMemo then
    return
  end

  SaveCurrentMemo(hDlg)  -- Auto-save before switching

  CurrentMemo = newMemo;
  local newContent = LoadFileContent(GetMemoFilePath(newMemo));
  hDlg:SetText(POS_MEMO, newContent)

  -- Update title: "Memo" -> "Memo - 1", etc.
  local title = ("[ Memo - %d ]"):format(newMemo)
  hDlg:SetText(POS_TITLE, title)

  ShowXInIndicator(hDlg, newMemo)
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
    return SaveFileContent(destPath, GetMemoText(hDlg))
  end

  return false
end

-- Create and run the memo dialog
local function OpenMemoDialog()
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
    { tp="text"; text="Memo";  x1=1; y1=0; x2=dlgWidth-2; centertext=1;    },
    { tp="memo"; text=content; x1=1; y1=1; x2=dlgWidth-4; y2=dlgHeight-4;  },
    { tp="text"; text=GetIndicatorWithX(CurrentMemo);
                     x1=1; x2=dlgWidth-2; centertext=1;                    },
  }

  -- Dialog procedure - handles keyboard and close events
  -- DN_KEY: intercepts keys for memo switching
  -- DN_CLOSE: saves content and state
  function Items.proc(hDlg, Msg, Param1, Param2)
    if Msg == "EVENT_KEY" then
      if Param1 == POS_MEMO then
        local key = Param2

        -- ESC closes dialog - DN_CLOSE will save
        if key == "Esc" then
          hDlg:Close()
          return true
        end

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
      SaveLastMemoIndex(CurrentMemo)

    end
  end

  local sd = require "far2.simpledialog"
  local Dlg = sd.New(Items)
  Dlg:Run()
end

local function main()
  MemoDir = far.InMyConfig("plugins/luafar/memo_files")
  win.CreateDir(MemoDir)
  OpenMemoDialog()
end

Macro {
  id="D27C6B7D-0343-42D4-A339-1ACEF32E142C";
  description="A replica of Memo plugin";
  area="Common"; key="CtrlAltM";
  flags="";
  -- priority=50; condition=function(key) end;
  action=function() main() end;
}
