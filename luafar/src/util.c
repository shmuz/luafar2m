#include "ustring.h"
#include "util.h"

// stack[-2] - table
// stack[-1] - value
int luaLF_SlotError (lua_State *L, int key, const char* expected_typename)
{
  return luaL_error (L,
    "bad field [%d] in table stackpos=%d (%s expected got %s)",
    key, abs_index(L,-2), expected_typename, luaL_typename(L,-1));
}

// stack[-2] - table
// stack[-1] - value
int luaLF_FieldError (lua_State *L, const char* key, const char* expected_typename)
{
  return luaL_error (L,
    "bad field '%s' in table stackpos=%d (%s expected got %s)",
    key, abs_index(L,-2), expected_typename, luaL_typename(L,-1));
}

int GetIntFromArray(lua_State *L, int index)
{
  lua_pushinteger(L, index);
  lua_gettable(L, -2);
  if (!lua_isnumber (L,-1))
    return luaLF_SlotError (L, index, "number");
  int ret = lua_tointeger(L, -1);
  lua_pop(L, 1);
  return ret;
}

uint64_t GetFileSizeFromTable(lua_State *L, const char *key)
{
  uint64_t size;
  lua_getfield(L, -1, key);
  if (lua_isnumber(L, -1))
    size = (uint64_t) lua_tonumber(L, -1);
  else
    size = 0;
  lua_pop(L, 1);
  return size;
}

FILETIME GetFileTimeFromTable(lua_State *L, const char *key)
{
  FILETIME ft;
  lua_getfield(L, -1, key);
  if (lua_isnumber(L, -1)) {
    long long tm = (long long) lua_tonumber(L, -1);
    tm *= 10000; // convert ms units to 100ns ones
    ft.dwHighDateTime = tm / 0x100000000ll;
    ft.dwLowDateTime  = tm % 0x100000000ll;
  }
  else
    ft.dwLowDateTime = ft.dwHighDateTime = 0;
  lua_pop(L, 1);
  return ft;
}

void PutFileTimeToTable(lua_State *L, const char* key, FILETIME ft)
{
  LARGE_INTEGER li;
  li.LowPart = ft.dwLowDateTime;
  li.HighPart = ft.dwHighDateTime;
  PutNumToTable(L, key, li.QuadPart/10000); // convert 100ns units to 1ms ones
}

int DecodeAttributes(const char* str)
{
  int attr = 0;
  const char* p;
  for(p=str; *p; p++) {
    if      (*p == 'a' || *p == 'A') attr |= FILE_ATTRIBUTE_ARCHIVE;
    else if (*p == 'r' || *p == 'R') attr |= FILE_ATTRIBUTE_READONLY;
    else if (*p == 'h' || *p == 'H') attr |= FILE_ATTRIBUTE_HIDDEN;
    else if (*p == 's' || *p == 'S') attr |= FILE_ATTRIBUTE_SYSTEM;
    else if (*p == 'd' || *p == 'D') attr |= FILE_ATTRIBUTE_DIRECTORY;
    else if (*p == 'c' || *p == 'C') attr |= FILE_ATTRIBUTE_COMPRESSED;
    else if (*p == 'o' || *p == 'O') attr |= FILE_ATTRIBUTE_OFFLINE;
    else if (*p == 't' || *p == 'T') attr |= FILE_ATTRIBUTE_TEMPORARY;
  }
  return attr;
}

int GetAttrFromTable(lua_State *L)
{
  int attr = 0;
  lua_getfield(L, -1, "FileAttributes");
  if (lua_isstring(L, -1))
    attr = DecodeAttributes(lua_tostring(L, -1));
  lua_pop(L, 1);
  return attr;
}

void PushAttrString(lua_State *L, int attr)
{
  char buf[32], *p = buf;
  if (attr & FILE_ATTRIBUTE_ARCHIVE)             *p++ = 'a';
  if (attr & FILE_ATTRIBUTE_COMPRESSED)          *p++ = 'c';
  if (attr & FILE_ATTRIBUTE_DIRECTORY)           *p++ = 'd';
  if (attr & FILE_ATTRIBUTE_REPARSE_POINT)       *p++ = 'e';
  if (attr & FILE_ATTRIBUTE_HIDDEN)              *p++ = 'h';
  if (attr & FILE_ATTRIBUTE_NOT_CONTENT_INDEXED) *p++ = 'i';
  if (attr & FILE_ATTRIBUTE_ENCRYPTED)           *p++ = 'n';
  if (attr & FILE_ATTRIBUTE_OFFLINE)             *p++ = 'o';
  if (attr & FILE_ATTRIBUTE_SPARSE_FILE)         *p++ = 'p';
  if (attr & FILE_ATTRIBUTE_READONLY)            *p++ = 'r';
  if (attr & FILE_ATTRIBUTE_SYSTEM)              *p++ = 's';
  if (attr & FILE_ATTRIBUTE_TEMPORARY)           *p++ = 't';
  if (attr & FILE_ATTRIBUTE_NO_SCRUB_DATA)       *p++ = 'u';
  if (attr & FILE_ATTRIBUTE_VIRTUAL)             *p++ = 'v';
  lua_pushlstring(L, buf, p-buf);
}

void PutAttrToTable(lua_State *L, int attr)
{
  PushAttrString(L, attr);
  lua_setfield(L, -2, "FileAttributes");
}
