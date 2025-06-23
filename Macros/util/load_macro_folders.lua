--------------------------------------------------------------------------------
-- WARNING: DO NOT RUN THIS SCRIPT ON FOLDERS WHICH CONTENT IS UNKNOWN TO YOU!!!
--------------------------------------------------------------------------------

-- Started     : 2021-02-27
-- Action      : load macros from folders selected on the Active Panel
-- Portability : far3 (>= 4068), far2m
-- Plugin      : LuaMacro, LF4Ed, LF Search, LF History
-- Use for     : (*) debugging; (*) evaluating 3-rd party macros; (*) ...
-- Run this file from User Menu:
--   far3  --> luas: @%farprofile%\Macros\util\load_macro_folders.lua
--   far2m --> luas: dofile(far.InMyConfig("Macros/util/load_macro_folders.lua"))

local dirsep = package.config:sub(1,1)
local osWin = (dirsep == "\\")

local Title = "Load macros from folders"

if osWin then
  if 4068 > select(4, far.AdvControl("ACTL_GETFARMANAGERVERSION", true)) then
    far.Message("This action requires Far 3.0.4068 or later", Title, nil, "w")
    return
  end
end

local info = panel.GetPanelInfo(nil,1)
local tt = {}
for k=1,info.SelectedItemsNumber do
  local item = panel.GetSelectedPanelItem(nil,1,k)
  if item.FileAttributes:find("d") then
    table.insert(tt,item.FileName)
  end
end
if tt[1] then
  table.sort(tt)
  local list = table.concat(tt, "\n")
  local caption = "Load macros from folders?"
  if 2 == far.Message(list, caption, "&No;&Yes", "lw") then
    local paths = table.concat(tt, ";")
    far.MacroLoadAll(paths)
  end
else
  far.Message("No folders selected", Title)
end
