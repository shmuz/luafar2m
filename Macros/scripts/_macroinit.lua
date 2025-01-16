local run = select(2, ...)
if run ~= 1 then return end

local repos = far.GetMyHome().."/repos"
local plugins = repos.."/luafar2m/_build/install"

-- load plugins
if os.getenv("FARHOME") == repos.."/far2m/_build/install" then
  far.RecursiveSearch(plugins, "*.far-plug-wide",
    function(_, fullpath)
      far.LoadPlugin("PLT_PATH", fullpath)
    end, "FRS_RECUR")
end
