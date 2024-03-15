// 2012-02-05 : started
// 2024-03-14 : use WinPort file API instead of stdio.h due to fopen failures (Permission denied)

#include <windows.h>
#include <stdlib.h>
#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif
#include <lua.h>
#include <lauxlib.h>
#ifdef __cplusplus
}
#endif

/* Lua versions: 5.1 to 5.4 */
#if LUA_VERSION_NUM > 501
  #define luaL_register(L,n,l)	(luaL_setfuncs(L,l,0))
#endif

wchar_t* check_utf8_string (lua_State *L, int pos, size_t* pTrgSize); // luafar.so

#define CHUNK 0x4000 // 16 Kib

static const char ReaderType[] = "LFSearch.ChunkReader";

static BOOL GetFileOffset(HANDLE fp, LONGLONG *offset)
{
  LARGE_INTEGER liDistanceToMove, liFileOffset;
  liDistanceToMove.QuadPart = 0;
  BOOL Ok = WINPORT(SetFilePointerEx)(fp, liDistanceToMove, &liFileOffset, FILE_CURRENT);
  if (Ok)
    *offset = liFileOffset.QuadPart;
  return Ok;
}

typedef struct {
  HANDLE fp;      // FILE object
  size_t overlap; // number of CHUNKs in overlap (this value does not change after initialization)
  size_t top;     // number of CHUNKs currently read
  char *data;     // allocated memory buffer
} TReader;

static int NewReader (lua_State *L)
{
  TReader* ud = (TReader*)lua_newuserdata(L, sizeof(TReader));
  memset(ud, 0, sizeof(TReader));
  ud->fp = INVALID_HANDLE_VALUE;
  ud->overlap = luaL_checkinteger(L, 1) / 2 / CHUNK;
  if (ud->overlap == 0) ud->overlap = 1;
  ud->data = (char*) malloc(ud->overlap * 2 * CHUNK);
  if (ud->data == NULL) return 0;
  luaL_getmetatable(L, ReaderType);
  lua_setmetatable(L, -2);
  return 1;
}

static TReader* GetReader (lua_State *L, int pos)
{
  return (TReader*) luaL_checkudata(L, pos, ReaderType);
}

static TReader* CheckReader (lua_State *L, int pos)
{
  TReader* ud = (TReader*) luaL_checkudata(L, pos, ReaderType);
  if (ud->data == NULL)
    luaL_argerror(L, pos, "attempt to access a deleted reader");
  return ud;
}

static TReader* CheckReaderWithFile (lua_State *L, int pos)
{
  TReader* ud = CheckReader(L, pos);
  if (ud->fp == INVALID_HANDLE_VALUE)
    luaL_argerror(L, pos, "attempt to access a closed reader file");
  return ud;
}

static int Reader_getnextchunk (lua_State *L)
{
  TReader *ud = CheckReaderWithFile(L, 1);
  size_t M = ud->overlap;
  size_t N = M * 2;
  size_t top = ud->top;
  DWORD tail = 0;
  LONGLONG offset;
  BOOL firstread;

  if (!GetFileOffset(ud->fp, &offset))
    return 0;
  firstread = (0 == offset);

  if (top == N) {
    memcpy(ud->data, ud->data + M*CHUNK, M*CHUNK);
    ud->top = top = M;
  }
  while (top < N) {
    BOOL Ok = WINPORT(ReadFile)(ud->fp, ud->data + top*CHUNK, CHUNK, &tail, NULL);
    if (!Ok || tail == 0)
      return 0;
    else if (tail == CHUNK) {
      tail = 0;
      ++top;
    }
    else
      break;
  }
  if (top == ud->top && tail == 0)
  {
    if (firstread)
      { lua_pushstring(L, ""); return 1; }
    else
      return 0;
  }
  ud->top = top;
  lua_pushlstring(L, ud->data, ud->top * CHUNK + tail);
  return 1;
}

static int Reader_delete (lua_State *L)
{
  TReader *ud = GetReader(L, 1);
  if (ud->fp != INVALID_HANDLE_VALUE) {
    WINPORT(CloseHandle)(ud->fp);
    ud->fp = INVALID_HANDLE_VALUE;
  }
  if (ud->data) {
    free(ud->data);
    ud->data = NULL;
  }
  return 0;
}

static int Reader_ftell (lua_State *L)
{
  TReader *ud = CheckReaderWithFile(L, 1);
  LONGLONG offset = 0;
  GetFileOffset(ud->fp, &offset);
  lua_pushnumber(L, offset);
  return 1;
}

static int Reader_closefile (lua_State *L)
{
  TReader *ud = CheckReader(L, 1);
  if (ud->fp != INVALID_HANDLE_VALUE) {
    WINPORT(CloseHandle)(ud->fp);
    ud->fp = INVALID_HANDLE_VALUE;
    lua_pushinteger(L, 1);
  }
  else
    lua_pushinteger(L, 0);
  return 1;
}

static int Reader_openfile (lua_State *L)
{
  int ret = 0;
  TReader *ud = CheckReader(L, 1);

  if (ud->fp != INVALID_HANDLE_VALUE)
    WINPORT(CloseHandle)(ud->fp);

  ud->fp = WINPORT(CreateFile) (
    check_utf8_string(L, 2, NULL),
    FILE_READ_DATA,
    FILE_SHARE_READ + FILE_SHARE_WRITE,
    NULL,
    OPEN_EXISTING,
    FILE_FLAG_SEQUENTIAL_SCAN,
    NULL);

  if (ud->fp != INVALID_HANDLE_VALUE) {
    ud->top = 0;
    ret = 1;
  }
  lua_pushboolean(L, ret);
  return 1;
}

static int Reader_getsize (lua_State *L)
{
  TReader *ud = CheckReader(L, 1);
  lua_pushnumber(L, ud->overlap * 2 * CHUNK);
  return 1;
}

static const luaL_Reg funcs[] = {
  { "new", NewReader },
  { NULL, NULL }
};

// When the word 'static' was missing here it took me more than
// 10 work hours to debug why this library didn't work on Linux
// from LuaFAR plugins.
static const luaL_Reg methods[] = {
  { "__gc",      Reader_delete },
  { "closefile", Reader_closefile },
  { "delete",    Reader_delete },
  { "ftell",     Reader_ftell },
  { "openfile",  Reader_openfile },
  { "get_next_overlapped_chunk", Reader_getnextchunk },
  { "getsize",   Reader_getsize },
  { NULL, NULL }
};

int luaopen_reader (lua_State *L)
{
#ifdef EMBED
  int luafar_openlibs(lua_State*);
  luafar_openlibs(L);
#endif
  luaL_newmetatable(L, ReaderType);
  luaL_register(L, NULL, methods);
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");

  luaL_register(L, "lfs_reader", funcs);
  return 0;
}
