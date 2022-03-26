local plugpath = far.PluginStartupInfo().ModuleName:match("(.+)/")
local path1 = plugpath .. "/?.lua"
local path2 = plugpath:gsub("/[^/]+/[^/]+$", "/lua_share/?.lua") -- don't use ../..

package.path = ("%s;%s;%s"):format(path1, path2, package.path)
package.nounload = {
  moonscript = true;
  luacheck = true;
}
