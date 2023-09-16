local run = select(2, ...)
if run ~= 1 then return end

local home = os.getenv("HOME")
local luafar = home.."/luafar2m"

-- load plugins
if os.getenv("FARHOME") == home.."/far2m/_build/install" then
  far.RecursiveSearch(luafar, "*.far-plug-wide",
    function(_, fullpath)
      far.LoadPlugin("PLT_PATH", fullpath)
    end, "FRS_RECUR")
end
