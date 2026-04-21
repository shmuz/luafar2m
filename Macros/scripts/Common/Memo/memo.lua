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

local ThisDir = (...):match(".+/")
local F = far.Flags
local Data
local EditorId
local FullScreen

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

local function NormIndex(idx)
  return idx >= 1 and idx <= MEMO_COUNT and idx or 1
end

local function LoadData()
  Data = mf.mload(DB_Key, DB_Name) or {}
  for i=1,MEMO_COUNT do
    local tt = Data[i] or {}
    tt.FileName = tt.FileName or ("memo-%02d.txt"):format(i)
    Data[i] = tt
  end
  -- Validation
  Data.CurIndex = NormIndex(Data.CurIndex or 1)
end

local function SaveData()
  mf.msave(DB_Key, DB_Name, Data)
end

local function GetFileName(index)
  return Data[index].FileName
end

local function GetMemoFilePath(index)
  local attr = win.GetFileAttr(MemoDir)
  if attr and attr:find("d") then
    local fname = GetFileName(index)
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
  local filepath = GetMemoFilePath(Data.CurIndex)
  if filepath then
    local content = hDlg:GetText(POS_MEMO)
    SaveFileContent(filepath, content)
  end
end

local function UpdateTitle(hDlg, index)
  local ei = editor.GetInfo(EditorId)
  local mark = (0 == bit64.band(ei.CurState, F.ECSTATE_MODIFIED)) and "" or "*"
  local title = ("[%s%d] %s"):format(mark, index, GetFileName(index))
  hDlg:SetText(POS_TITLE, title)
end

-- Save current memo to external file
local function SaveMemoAs(hDlg)
  -- Default: memo-01.txt ... memo-10.txt in home directory
  local Name = GetFileName(Data.CurIndex)
  local Path = win.JoinPath(far.GetMyHome(), Name)
  local destPath = far.InputBox(nil, "Save Memo", "Enter destination path:", "MemoSave",
                                Path, nil, nil, "FIB_NONE")
  if destPath and CheckFileOverwrite(destPath) then
    SaveFileContent(destPath, hDlg:GetText(POS_MEMO))
  end
end

local function RenameMemo(hDlg)
  local Name = GetFileName(Data.CurIndex)
  local DestName = far.InputBox(nil, "Rename Memo", "Enter file name without path:", "MemoRename",
                                Name, nil, nil, "FIB_NONE")
  if DestName then
    local name = DestName:match("[^/]+$")
    if name then
      local fullname = win.JoinPath(MemoDir, name)
      if CheckFileOverwrite(fullname) then
        local content = hDlg:GetText(POS_MEMO)
        SaveFileContent(fullname, content)
        Data[Data.CurIndex].FileName = name
        return true
      end
    end
  end
end

local function InitActions(hDlg)
  local filepath = GetMemoFilePath(Data.CurIndex)
  if not filepath then
    return false
  end
  EditorId = hDlg:GetMemoEditId(POS_MEMO)
  editor.SetVirtualFileName(EditorId, filepath)

  local content = LoadFileContent(filepath)
  hDlg:SetText(POS_MEMO, content)
  editor.SetSavedState(EditorId, true)
  local tt = Data[Data.CurIndex]
  editor.SetPosition(EditorId, tt.CurLine, tt.CurPos)

  UpdateTitle(hDlg, Data.CurIndex)
  UpdateIndicator(hDlg, Data.CurIndex)
  return true
end

local function CloseActions(hDlg, switching)
  -- save the memo being left (and its data)
  local info = editor.GetInfo(EditorId)
  local tt = Data[Data.CurIndex]
  tt.CurLine, tt.CurPos = info.CurLine, info.CurPos
  if 0 ~= bit64.band(info.CurState, F.ECSTATE_MODIFIED) then
    SaveCurrentMemo(hDlg)
  end
  -- switch index
  Data.CurIndex = switching or Data.CurIndex
  SaveData()
end

local function CalcDialogSize()
  local scrRect = actl.GetFarRect()
  local scrWidth, scrHeight = 80, 25
  if scrRect then
    scrWidth = scrRect.Right - scrRect.Left + 1
    scrHeight = scrRect.Bottom - scrRect.Top + 1
  end
  return {
    X = FullScreen and scrWidth  or math.max(43, scrWidth-22);
    Y = FullScreen and scrHeight or math.max(5, scrHeight-12);
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
  hDlg:EnableRedraw(true)
end

-- Create and run the memo dialog
local function OpenMemoDialog()
  win.CreateDir(MemoDir)
  LoadData()

  local dlgSize = CalcDialogSize()
  local Items = {
    { F.DI_TEXT,     1, 0, dlgSize.X, 0,             nil, nil, nil, nil, ""},
    { F.DI_MEMOEDIT, 1, 1, dlgSize.X-2, dlgSize.Y-2, nil, nil, nil, nil, ""},
    { F.DI_TEXT,     1, dlgSize.Y-1, dlgSize.X, 0,   nil, nil, nil, F.DIF_CENTERTEXT, ""},
  }

  local switching
  local wasError

  local function DlgProc(hDlg, Msg, Param1, Param2)
    if Msg == F.DN_INITDIALOG then
      if not InitActions(hDlg) then
        wasError = true; hDlg:Close()
      end

    elseif Msg == F.DN_KEY then
      if Param1 == POS_MEMO then
        local key = far.KeyToName(Param2)

        if key == "F1" then
          far.ShowHelp(ThisDir, "Contents", F.FHELP_CUSTOMPATH)

        elseif key == "ShiftF2" then -- Save As
          SaveMemoAs(hDlg)

        elseif key == "ShiftF6" then -- Rename
          if RenameMemo(hDlg) then
            switching = Data.CurIndex
            hDlg:Close() -- update highlighting as the extension may have changed
          end

        elseif key == "F5" then
          FullScreen = not FullScreen
          Resize(hDlg)

        -- Alt+0-9: switch memo
        elseif key:match("^Alt[0-9]$") then
          local idx = tonumber(key:match("[0-9]"))
          switching = (idx == 0) and 10 or idx
          hDlg:Close() -- update highlighting as the extension may have changed

        end
      end

    elseif Msg == F.DN_MOUSECLICK then
      if Param1 == POS_INDICATOR then
        local R = hDlg:GetDlgRect()                 -- Dialog rectangle.
        local DW = R.Right - R.Left + 1             -- Dialog width.
        local IW = 41                               -- Indicators width.
        local X = Param2.MousePositionX - R.Left    -- Relative click X position.
        local X0 = math.floor((DW - IW) / 2)        -- The X of the 1-st indicator left edge.
        local Which = math.ceil((X - X0) / 4)       -- Each indicator occupies 4 cells.
        if Which >= 1 and Which <= 10 then
          switching = Which
          hDlg:Close() -- update highlighting as the extension may have changed
        end
      end

    elseif Msg == F.DN_CLOSE then
      if not wasError then CloseActions(hDlg, switching) end

    elseif Msg == F.DN_RESIZECONSOLE then
      Resize(hDlg)

    end
  end

  far.Dialog(nil, -1, -1, dlgSize.X, dlgSize.Y, nil, Items, nil, DlgProc)
  return switching
end

Event {
  group="EditorEvent";
  description="Memo editor changed";
  action=function(id, event, param)
    if id == EditorId and event == F.EE_REDRAW and param == F.EEREDRAW_CHANGE then
      local wi = actl.GetWindowInfo()
      if wi and wi.Type == F.WTYPE_DIALOG then
        UpdateTitle(wi.Id, Data.CurIndex)
      end
    end
  end;
}

Macro {
  id="D27C6B7D-0343-42D4-A339-1ACEF32E142C";
  description="A replica of Memo plugin";
  area="Common"; key="CtrlAltM";
  action=function()
    -- use mf.acall to avoid seeing "P" in the upper left screen corner
    FullScreen = false
    mf.acall(function() while OpenMemoDialog() do end end)
  end;
}
