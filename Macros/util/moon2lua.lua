-- moon2lua.lua

local fullpath = ...
local to_lua = (require"moonscript.base").to_lua

local fp = assert(io.open(fullpath))
local str = fp:read("*all")
fp:close()
str = assert(to_lua(str))

local newpath = (fullpath:match("(.+)%.[^./]+$") or fullpath) .. ".lua"
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
