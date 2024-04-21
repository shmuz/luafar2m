local dirsep = package.config:sub(1,1)
local FarVer = dirsep == "\\" and 3 or 2
local F = far.Flags

-- Check if a file or directory exists in this path
function FileExists(file)
  local ok, err, code = os.rename(file, file)
  if not ok then
    if code == 13 then
      -- Permission denied, but it exists
      return true
    end
  end
  return ok, err
end

local function GetPanelItems()
  local files = {}
  local idx = nil
  local dir = panel.GetPanelDirectory(nil, 1).Name
  local cnt = APanel.SelCount
  if cnt == 0 then  -- no selected items
    cnt = 1
    files[1] = panel.GetCurrentPanelItem(nil, 1).FileName
  else
    idx = {}
    for i = 1, cnt do
      files[i] = panel.GetSelectedPanelItem(nil, 1, i).FileName
      idx[i] = i
    end
  end
  return {
    Dir = dir,      -- panel's directory
    Count = cnt,    -- number of items (current or selected)
    Files = files,  -- current or selected item(s)
    Idx = idx       -- selected indexes or nil
  }
end

local function ClearPanelSelection(idx)
  if idx ~= nil then
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
  return ""
end

local function OpenFileInEditor(filename, pos)
  local pos = pos or 1
  local res = editor.Editor(filename, nil, nil, nil, nil, nil, F.EF_DISABLEHISTORY + (F.EF_DISABLESAVEPOS or 0), 1, pos, 65001)
  if res == F.EEC_OPEN_ERROR then
    far.Message(("Unable to open in editor: %s"):format(filename), "Error", nil, "w")
  end
  return res
end

local function ReadScript(filename)
  local content = ""
  local tmpFile = io.open(filename, "r")
  if tmpFile then
    content = tmpFile:read("*all")
    tmpFile:close()
  end
  local lines = {}
  for str in string.gmatch(content, "([^\n]+)") do
    table.insert(lines, str)
  end
  return lines
end

local function RenameFiles(lines, panelDir, mode)
  local errorCount = 0
  local errorsText = {}
  local pos1, pos2, pos3, pos4
  local file1, file2
  local renResult, renError
  local stopFlag
  for i, l in ipairs(lines) do
    stopFlag = false
    renResult = ""
    renError = ""
    pos1 = string.find(l, '"')
    if pos1 then pos2 = string.find(l, '"', pos1 + 1) end
    if pos2 then pos3 = string.find(l, '"', pos2 + 1) end
    if pos3 then pos4 = string.find(l, '"', pos3 + 1) end
    if not (pos1 and pos2 and pos3 and pos4) then
      renResult = nil
      renError = "skip line (too few quotes)"
      stopFlag = true
    else
      file1 = string.sub(l, pos1 + 1, pos2 - 1)
      file2 = string.sub(l, pos3 + 1, pos4 - 1)
    end
    if not stopFlag and ((not (file1 and file2)) or file1 == "" or file2 == "") then
      renResult = nil
      renError = "skip line (error in file name)"
      stopFlag = true
    end
    if not stopFlag and file1 ~= file2 then
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
    local txt
    if renResult == nil then
      txt = "error: " .. l .. " [line " .. i .. "][" .. renError .. "]"
      table.insert(errorsText, txt)
      errorCount = errorCount + 1
    else
      txt = "ok: " .. l .. " [line " .. i .. "]"
    end
  end
  return errorCount, errorsText
end

local function ShowError(errorsText)
  local tmpFileName = SaveFilelistToTmpFile(errorsText)
  OpenFileInEditor(tmpFileName)
  if tmpFileName ~= "" then
    os.remove(tmpFileName)
  end
end

local function Main(cmd)
  local renameLines = {}
  local tmpFileName = ""
  local maxWidth = 0
  local items = GetPanelItems()
  if items.Count == 1 then
    if items.Files[1] == ".." or items.Files[1] == "." then
      far.Message("No files selected", "Error", ";OK")
      return -1
    end
  end
  for i = 1, items.Count do
    maxWidth = (maxWidth > items.Files[i]:len()) and maxWidth or items.Files[i]:len()
  end
  for i = 1, items.Count do
    spaceCount = maxWidth - items.Files[i]:len() + 1
    renameLines[i] = '"' .. items.Files[i] .. '"'
    for j = 1, spaceCount do
      renameLines[i] = renameLines[i] .. " "
    end
    renameLines[i] = renameLines[i] .. '"' .. items.Files[i] .. '"'
  end
  tmpFileName = SaveFilelistToTmpFile(renameLines)
  if tmpFileName == "" then
    far.Message("Unable to create temp file", "Error", nil, "w")
    return -1
  end
  local lines = {}
  if OpenFileInEditor(tmpFileName, maxWidth + 5) == F.EEC_MODIFIED then
    lines = ReadScript(tmpFileName)
    errorCount, errorsText = RenameFiles(lines, items.Dir)
    if errorCount > 0 then
      ShowError(errorsText)
    end
  end
  if tmpFileName ~= "" then
    os.remove(tmpFileName)
  end
  ClearPanelSelection(items.Idx)
  panel.UpdatePanel(nil, 1)
  panel.RedrawPanel(nil, 1)
end

MenuItem {
  description = "BatchRenLua";
  menu   = "Plugins";
  area   = "Shell";
  guid   = "BD698A4C-7398-41A5-A69C-5E0D2085E23F";
  text   = function() return "Batch rename files (Lua)" end;
  action = function() Main() end;
}
