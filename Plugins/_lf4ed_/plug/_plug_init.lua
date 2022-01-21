local modulepath = far.PluginStartupInfo().ModuleName:match(".+/").."?.lua"
local commonpath = os.getenv("FARHOME").."/Plugins/_luafar_/lua_share/?.lua"

package.path = ("%s;%s;%s"):format(modulepath, commonpath, package.path)
