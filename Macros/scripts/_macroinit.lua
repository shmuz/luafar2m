local path1 = os.getenv("HOME").."/luafar2l"

-- add lua_share to package.path
if not package.path:find("/lua_share/") then
  package.path = package.path..";"..path1.."/lua_share/?.lua"
end

-- load plugins
if not os.getenv("FARHOME"):find("^/usr") then
  far.RecursiveSearch(path1, "*.far-plug-wide",
    function(_, fullpath)
      far.LoadPlugin("PLT_PATH", fullpath)
    end, "FRS_RECUR")
end
