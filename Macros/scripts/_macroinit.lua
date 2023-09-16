local run = select(2, ...)
if run ~= 1 then return end

local home = os.getenv("HOME")
local plugins = home.."/luafar2m"

-- load plugins
if os.getenv("FARHOME") == home.."/far2m/_build/install" then
  far.RecursiveSearch(plugins, "*.far-plug-wide",
    function(_, fullpath)
      far.LoadPlugin("PLT_PATH", fullpath)
    end, "FRS_RECUR")
end
