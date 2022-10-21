local installed = far.PluginStartupInfo().ShareDir:match("^/usr/.-/luafar")
local luafar = installed or os.getenv("HOME").."/luafar2l"
local run = select(2, ...)

-- add lua_share to package.path
if run == 1 and not package.path:find("/lua_share/") then
  package.path = luafar.."/lua_share/?.lua;"..package.path
end

-- load plugins
if run == 1 and not installed then
  far.RecursiveSearch(luafar, "*.far-plug-wide",
    function(_, fullpath)
      far.LoadPlugin("PLT_PATH", fullpath)
    end, "FRS_RECUR")
end
