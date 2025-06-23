-- Started     : 2025-05-01
-- Action      : convert a MoonScript file to Lua
-- Portability : far3 (>= 3878), far2m
-- Plugin      : LuaMacro, LF4Ed, LF Search, LF History
-- Run this file from File associations:
--   far3  --> luas: @%FARPROFILE%\Macros\util\moon2lua.lua [[!\!.!]]
--   far2m --> luas: @~/repos/luafar2m/Macros/util/moon2lua.lua "!.!"

local dirsep = package.config:sub(1,1)
local no_ext = ("(.+)%.[^.DIRSEP]+$"):gsub("DIRSEP", dirsep)

require "moonscript" -- needed for plugins other than LuaMacro
local to_lua = (require"moonscript.base").to_lua

local fullpath = ...
local fp = assert(io.open(fullpath))
local str = fp:read("*all")
fp:close()
str = assert(to_lua(str))

local newpath = (fullpath:match(no_ext) or fullpath) .. ".lua"
if win.GetFileAttr(newpath) then
  if 1 ~= far.Message(newpath.." exists. Overwrite?","Confirm","Yes;No","w") then return end
end
fp = assert(io.open(newpath,"w"))
fp:write("-- luacheck: ignore 612 (trailing space)\n")
fp:write("-- luacheck: ignore 631 (line is too long)\n")
fp:write(str,"\n")
fp:close()

panel.UpdatePanel(nil,1)
panel.RedrawPanel(nil,1)
