local plugpath = far.PluginStartupInfo().ModuleName:match("(.+)/")
local path1 = plugpath .. "/?.lua"
local path2 = plugpath .. "/../../lua_share/?.lua"

package.path = ("%s;%s;%s"):format(path1, path2, package.path)
