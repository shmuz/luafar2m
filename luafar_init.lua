local inf = far.PluginStartupInfo()
local path1 = inf.ShareDir .. "/?.lua"
local path2 = os.getenv("HOME").."/luafar2l/lua_share/?.lua"

package.path = ("%s;%s;%s"):format(path1, path2, package.path)
package.cpath = inf.ModuleDir.."/?.so;".. package.cpath
