-- Started     : 2021-10-08
-- Action      : show PATH environment variable in readable form
-- Portability : far3 (>= 3300), far2m
-- Plugin      : LuaMacro, LF4Ed, LF Search, LF History
-- Run this file from User Menu:
--   far3  --> luas: @%farprofile%\Macros\util\show_path.lua
--   far2m --> luas: dofile(far.InMyConfig("Macros/util/show_path.lua"))

local dirsep = package.config:sub(1,1)
local osWin = (dirsep == "\\")
local pathsep = osWin and ";" or ":"
local pattern = ("[^SEP\n]+"):gsub("SEP", pathsep)

local t = {}
for p in win.GetEnv("PATH"):gmatch(pattern) do
  t[#t+1] = {text=p;}
end
local title = ("PATH (%d)"):format(#t)
local el = far.Menu({Title=title; Bottom="Enter to cd" }, t)
if el then
  panel.SetPanelDirectory(nil, 1, el.text)
end
