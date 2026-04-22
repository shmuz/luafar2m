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

-- These are used as keys in saved data
local CURIDX = "CurIndex"
local SWK    = "SwitchKeys"

local ThisDir = (...):match(".+/")
local F = far.Flags
local Data
local EditorId
local FullScreen

local SwitchKeys = {
  { Text= "Alt  + 0...9"         ;  pattern= "^Alt[0-9]$"; },
  { Text= "Ctrl + 0...9"         ;  pattern= "^Ctrl[0-9]$"; },
  { Text= "Alt  + Shift + 0...9" ;  pattern= "^AltShift[0-9]$"; },
  { Text= "Ctrl + Shift + 0...9" ;  pattern= "^CtrlShift[0-9]$"; },
  { Text= "Ctrl + Alt   + 0...9" ;  pattern= "^CtrlAlt[0-9]$"; },
}

local function MatchSwitchPattern(key)
  return key:match(SwitchKeys[Data[SWK]].pattern)
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

local function NormIndex(idx)
  return idx >= 1 and idx <= MEMO_COUNT and idx or 1
end

local function LoadData()
  local data = mf.mload(DB_Key, DB_Name) or {}
  for i=1,MEMO_COUNT do
    local tt = data[i] or {}
    tt.FileName = tt.FileName or ("memo-%02d.txt"):format(i)
    data[i] = tt
  end
  -- Validation
  data[CURIDX] = NormIndex(data[CURIDX] or 1)
  -- Validation
  local idx = math.floor(tonumber(data[SWK]) or 1)
  data[SWK] = (idx >= 1 and idx <= #SwitchKeys) and idx or 1

  return data
end

local function SaveData(data)
  mf.msave(DB_Key, DB_Name, data)
end

local function GetFileName()
  local index = Data[CURIDX]
  return Data[index].FileName
end

local function GetMemoFilePath()
  local attr = win.GetFileAttr(MemoDir)
  if attr and attr:find("d") then
    local fname = GetFileName()
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

local function UpdateIndicator(hDlg)
  local index = NormIndex(Data[CURIDX])
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
  local filepath = GetMemoFilePath()
  if filepath then
    local content = hDlg:GetText(POS_MEMO)
    SaveFileContent(filepath, content)
  end
end

local function UpdateTitle(hDlg)
  local ei = editor.GetInfo(EditorId)
  local W = ei.WindowSizeX
  local mark = (0 == bit64.band(ei.CurState, F.ECSTATE_MODIFIED)) and "" or "*"
  local fileinfo = ("[%s%d] %s"):format(mark, Data[CURIDX], GetFileName())
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
        local index = Data[CURIDX]
        Data[index].FileName = name
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
  EditorId = hDlg:GetMemoEditId(POS_MEMO)
  editor.SetVirtualFileName(EditorId, filepath)

  local content = LoadFileContent(filepath)
  hDlg:SetText(POS_MEMO, content)
  editor.SetSavedState(EditorId, true)
  local index = Data[CURIDX]
  local tt = Data[index]
  editor.SetPosition(EditorId, tt.CurLine, tt.CurPos)

  UpdateTitle(hDlg)
  UpdateIndicator(hDlg)
  return true
end

local function CloseActions(hDlg, switching)
  -- save the memo being left (and its data)
  local info = editor.GetInfo(EditorId)
  local index = Data[CURIDX]
  local tt = Data[index]
  tt.CurLine, tt.CurPos = info.CurLine, info.CurPos
  if 0 ~= bit64.band(info.CurState, F.ECSTATE_MODIFIED) then
    SaveCurrentMemo(hDlg)
  end
  -- switch index
  Data[CURIDX] = switching or Data[CURIDX]
  SaveData(Data)
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
  UpdateTitle(hDlg)
  hDlg:EnableRedraw(true)
end

local function OpenConfigDialog()
  local sd = require "far2.simpledialog"
  local Items = {
    { tp="dbox"; text="Configuration"; },
    { tp="text"; text="Keys for memo selection:"; },
    { tp="combobox"; list=SwitchKeys; dropdown=1; name=SWK; val=Data[SWK]; },
    { tp="sep"; },
    { tp="butt"; default=1; centergroup=1; text="OK"; },
    { tp="butt"; cancel=1; centergroup=1; text="Cancel"; },
  }
  local Dlg = sd.New(Items)
  local Out = Dlg:Run()
  if Out then
    Data[SWK] = Out[SWK]
    SaveData(Data)
  end
end

-- Create and run the memo dialog
local function OpenMemoDialog()
  win.CreateDir(MemoDir)
  Data = LoadData()

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

        if key == "ShiftF2" then -- Save As
          SaveMemoAs(hDlg)

        elseif key == "ShiftF6" then -- Rename
          if RenameMemo(hDlg) then
            switching = Data[CURIDX]
            hDlg:Close() -- update highlighting as the extension may have changed
          end

        elseif key == "F5" then
          FullScreen = not FullScreen
          Resize(hDlg)
          return true -- for not toggling the ShowWhiteSpace option caused by F5

        elseif key == "F9" or key == "AltShiftF9" then
          OpenConfigDialog()
          return true

        -- Switch memo
        elseif MatchSwitchPattern(key) then
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

  local Flags = F.FDLG_KEEPCONSOLETITLE
  local HelpTopic = "<"..ThisDir..">Contents"
  far.Dialog(nil, -1, -1, dlgSize.X, dlgSize.Y, HelpTopic, Items, Flags, DlgProc)
  return switching
end

Event {
  group="EditorEvent";
  description="Memo editor: update title";
  action=function(id, event, param)
    if id == EditorId and event == F.EE_REDRAW then
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
    FullScreen = false
    mf.acall(
      function()
        while OpenMemoDialog() do end
      end)
  end;
}
