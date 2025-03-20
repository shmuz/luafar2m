//---------------------------------------------------------------------------
#include <farplug-wide.h>
#include <lf_luafar.h>

extern int luaopen_lsqlite3(lua_State *L);

#ifndef LUAPLUG
#define LUAPLUG __attribute__ ((visibility ("default")))
#endif

int luaopen_sqlarc (lua_State *L)
{
  lua_getglobal(L, "package");
  lua_getfield(L, -1, "preload");
  lua_pushcfunction(L, luaopen_lsqlite3);
  lua_setfield(L, -2, "lsqlite3");
  lua_pop(L,2);
  return 0;
}
