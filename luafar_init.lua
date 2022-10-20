local inf = far.PluginStartupInfo()
local luafar = inf.ShareDir:match("^/usr/.-/luafar") or os.getenv("HOME").."/luafar2l"
local lua_share = luafar.."/lua_share"

package.path = ("%s/?.lua;%s/?.lua;%s"):format(inf.ShareDir, lua_share, package.path)
package.cpath = inf.ModuleDir.."/?.so;".. package.cpath
