local inf = far.PluginStartupInfo()
local sdir = inf.ShareDir
local path1 = sdir .. "?.lua"
local path2 = sdir:gsub("[^/]+/[^/]+/$", "lua_share/?.lua") -- don't use ../..

package.path = ("%s;%s;%s"):format(path1, path2, package.path)
package.cpath = inf.ModuleDir.."?.so;".. package.cpath

