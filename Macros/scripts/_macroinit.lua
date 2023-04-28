local run = select(2, ...)
if run ~= 1 then return end

local home = os.getenv("HOME")
local installed = far.PluginStartupInfo().ShareDir:match("^/usr/.-/luafar")
local luafar = installed or home.."/luafar2l"

-- add lua_share to package.path
if not package.path:find("/lua_share/") then
  package.path = luafar.."/lua_share/?.lua;"..package.path
end

-- load plugins
if os.getenv("FARHOME") == home.."/far2m/_build/install" then
  far.RecursiveSearch(luafar, "*.far-plug-wide",
    function(_, fullpath)
      far.LoadPlugin("PLT_PATH", fullpath)
    end, "FRS_RECUR")
end
