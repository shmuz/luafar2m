#include "ustring.h"
#include "luafar.h"

/* Taken from Lua 5.1; modified to work with Unicode filenames. */
/* ------------------------------------------------------------ */
/*
** {======================================================
** Load functions
** =======================================================
*/

typedef struct LoadF {
  int extraline;
  FILE *f;
  char buff[LUAL_BUFFERSIZE];
} LoadF;


static const char *getF (lua_State *L, void *ud, size_t *size) {
  LoadF *lf = (LoadF *)ud;
  (void)L;
  if (lf->extraline) {
    lf->extraline = 0;
    *size = 1;
    return "\n";
  }
  if (feof(lf->f)) return NULL;
  *size = fread(lf->buff, 1, sizeof(lf->buff), lf->f);
  return (*size > 0) ? lf->buff : NULL;
}


static int errfile (lua_State *L, const char *what, int fnameindex) {
  const char *serr = strerror(errno);
  const char *filename = lua_tostring(L, fnameindex) + 1;
  lua_pushfstring(L, "cannot %s %s: %s", what, filename, serr);
  lua_remove(L, fnameindex);
  return LUA_ERRFILE;
}

/* }====================================================== */

// Taken from Lua 5.1
static int load_aux (lua_State *L, int status) {
  if (status == 0)  /* OK? */
    return 1;
  else {
    lua_pushnil(L);
    lua_insert(L, -2);  /* put before error message */
    return 2;  /* return nil plus error message */
  }
}

// Taken from Lua 5.1 (luaL_gsub) and modified
const wchar_t *LF_Gsub (lua_State *L, const wchar_t *s, const wchar_t *p,
                        const wchar_t *r)
{
  const wchar_t *wild;
  size_t l = wcslen(p);
  size_t l2 = sizeof(wchar_t) * wcslen(r);
  luaL_Buffer b;
  luaL_buffinit(L, &b);
  while ((wild = wcsstr(s, p)) != NULL) {
    luaL_addlstring(&b, (const char*)s, sizeof(wchar_t) * (wild - s));  /* push prefix */
    luaL_addlstring(&b, (const char*)r, l2);  /* push replacement in place of pattern */
    s = wild + l;  /* continue after `p' */
  }
  luaL_addlstring(&b, (const char*)s, sizeof(wchar_t) * wcslen(s));  /* push last suffix */
  luaL_addlstring(&b, "\0\0", 2);  /* push L'\0' */
  luaL_pushresult(&b);
  return (const wchar_t*) lua_tostring(L, -1);
}

