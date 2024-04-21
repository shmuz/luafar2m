-- Original author : ivank
-- Original URL    : https://forum.farmanager.com/viewtopic.php?p=177806#p177806

-- Current author : Shmuel Zeigerman
-- Changes:
--   1. Show in editor only file names to be renamed <source> rather than <"source" "source">
--   2. Add an option to remove trailing spaces

---- OPTIONS -------------------------------------------------------------------
local Opt_RemoveTrailingSpaces = true
---- /OPTIONS ------------------------------------------------------------------

local dirsep = package.config:sub(1,1)
local FarVer = dirsep == "\\" and 3 or 2
local F = far.Flags

-- Check if a file or directory exists in this path
local function FileExists(file)
  return win.GetFileAttr(file) ~= nil
end

local function GetPanelItems()
  local panInfo = panel.GetPanelInfo(nil, 1)
  local cnt = panInfo.SelectedItemsNumber
  if cnt > 0 then
    local files = {}
    local idx = {}
    local dir = FarVer==3 and panel.GetPanelDirectory(nil, 1).Name or nil
    for i = 1, cnt do
      files[i] = panel.GetSelectedPanelItem(nil, 1, i).FileName
      idx[i] = i
    end
    return {
      Dir = dir,      -- panel's directory
      Count = cnt,    -- number of items (current or selected)
      Files = files,  -- current or selected item(s)
      Idx = idx       -- selected indexes or nil
    }
  end
end

local function ClearPanelSelection(idx)
  if idx then
    panel.ClearSelection(nil, 1, idx)
    panel.RedrawPanel(nil, 1)
  end
end

local function SaveFilelistToTmpFile(filelist)
  local content = table.concat(filelist, "\n")
  local tmpFileName = far.MkTemp()
  local tmpFile = io.open(tmpFileName, "w")
  if tmpFile then
    tmpFile:write(content, "\n")
    tmpFile:close()
    return tmpFileName
  end
end

local function OpenFileInEditor(filename)
  local res = editor.Editor(filename, nil, nil, nil, nil, nil,
              F.EF_DISABLEHISTORY + (F.EF_DISABLESAVEPOS or 0), 1, 1, 65001)
  if res == F.EEC_OPEN_ERROR then
    far.Message(("Unable to open in editor: %s"):format(filename), "Error", nil, "w")
  end
  return res
end

local function ReadScript(filename)
  local lines = {}
  local tmpFile = io.open(filename, "r")
  if tmpFile then
    for str in tmpFile:lines() do
      table.insert(lines, str)
    end
    tmpFile:close()
  end
  return lines
end

local function RenameFiles(SrcList, TrgList, panelDir)
  local errorCount = 0
  local errorsText = {}
  for i, line in ipairs(TrgList) do
    local file1 = SrcList[i]
    if file1 == nil then
      break
    end
    local file2 = Opt_RemoveTrailingSpaces and line:gsub("%s+$","") or line
    local skipFlag = false
    local renResult = true
    local renError = ""
    if file2 == "" then
      renResult = nil
      renError = "skip line (empty)"
      skipFlag = true
    end
    if not skipFlag and file1 ~= file2 then
      if FarVer == 3 then -- Windows
        if panelDir == "" then panelDir = win.GetEnv("TEMP") end
        if win.SetCurrentDir(panelDir) then
          renResult, renError = win.MoveFile(file1, file2)
          if renError then renError = renError:gsub("\n", " "):gsub("\r", "") end
        else
          renResult = nil
          renError = "SetCurrentDir(" .. panelDir .. ") error"
        end
      else -- Linux
        if not FileExists(file2) then
          renResult, renError = os.rename(file1, file2)
        else
          renResult = nil
          renError = file2 .. ": File exists"
        end
      end
    end
    if renResult == nil then
      local txt = "error: " .. line .. " [line " .. i .. "][" .. renError .. "]"
      table.insert(errorsText, txt)
      errorCount = errorCount + 1
    end
  end
  return errorCount, errorsText
end

local function ShowError(errorsText)
  local tmpFileName = SaveFilelistToTmpFile(errorsText)
  if tmpFileName then
    OpenFileInEditor(tmpFileName)
    os.remove(tmpFileName)
  end
end

local function Main()
  local items = GetPanelItems()
  if not items then
    far.Message("No files selected", "Error", ";OK")
    return
  end
  local tmpFileName = SaveFilelistToTmpFile(items.Files)
  if not tmpFileName then
    far.Message("Unable to create temp file", "Error", nil, "w")
    return
  end
  if OpenFileInEditor(tmpFileName) == F.EEC_MODIFIED then
    local trgList = ReadScript(tmpFileName)
    local errorCount, errorsText = RenameFiles(items.Files, trgList, items.Dir)
    if errorCount > 0 then
      ShowError(errorsText)
    end
  end
  os.remove(tmpFileName)
  ClearPanelSelection(items.Idx)
  panel.UpdatePanel(nil, 1)
  panel.RedrawPanel(nil, 1)
end

if MenuItem then
  MenuItem {
    description = "BatchRenLua";
    menu   = "Plugins";
    area   = "Shell";
    guid   = "BD698A4C-7398-41A5-A69C-5E0D2085E23F";
    text   = function() return "Batch rename files" end;
    action = function() Main() end;
  }
else
  return Main
end
