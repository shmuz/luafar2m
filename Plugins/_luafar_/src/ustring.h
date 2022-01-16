#ifndef _USTRING_H
#define _USTRING_H

#include <windows.h>

#ifdef __cplusplus
extern "C" {
#endif

#include <lua.h>
#include <lauxlib.h>

void pusherrorcode (lua_State *L, int error);
void pusherror (lua_State *L);
int  SysErrorReturn (lua_State *L);

BOOL   GetBoolFromTable   (lua_State *L, const char* key);
BOOL   GetOptBoolFromTable(lua_State *L, const char* key, BOOL dflt);
int    GetOptIntFromArray (lua_State *L, int key, int dflt);
int    GetOptIntFromTable (lua_State *L, const char* key, int dflt);
double GetOptNumFromTable (lua_State *L, const char* key, double dflt);
void   PutBoolToTable     (lua_State *L, const char* key, int num);
void   PutIntToArray      (lua_State *L, int key, int val);
void   PutIntToTable      (lua_State *L, const char *key, int val);
void   PutLStrToTable     (lua_State *L, const char* key, const void* str, size_t len);
void   PutNumToTable      (lua_State *L, const char* key, double num);
void   PutStrToArray      (lua_State *L, int key, const char* str);
void   PutStrToTable      (lua_State *L, const char* key, const char* str);
void   PutWStrToArray     (lua_State *L, int key, const wchar_t* str, int numchars);
void   PutWStrToTable     (lua_State *L, const char* key, const wchar_t* str, int numchars);

wchar_t* check_utf8_string (lua_State *L, int pos, int* pTrgSize);
wchar_t* utf8_to_utf16 (lua_State *L, int pos, int* pTrgSize);
const wchar_t* opt_utf8_string (lua_State *L, int pos, const wchar_t* dflt);
wchar_t* oem_to_utf16 (lua_State *L, int pos, int* pTrgSize);
char* push_utf8_string (lua_State* L, const wchar_t* str, int numchars);
char* push_oem_string (lua_State* L, const wchar_t* str, int numchars);

int ustring_EnumSystemCodePages (lua_State *L);
int ustring_GetACP (lua_State* L);
int ustring_GetCPInfo (lua_State *L);
int ustring_GetDriveType (lua_State *L);
int ustring_GetLogicalDriveStrings (lua_State *L);
int ustring_GetOEMCP (lua_State* L);
int ustring_MultiByteToWideChar (lua_State *L);
int ustring_OemToUtf8 (lua_State *L);
int ustring_Utf16ToUtf8 (lua_State *L);
int ustring_Utf8ToOem (lua_State *L);
int ustring_Utf8ToUtf16 (lua_State *L);
int ustring_Uuid(lua_State* L);

#ifdef __cplusplus
}
#endif

#ifdef __cplusplus
inline wchar_t* check_utf8_string (lua_State *L, int pos) {
  return check_utf8_string(L, pos, NULL);
}

inline wchar_t* utf8_to_utf16 (lua_State *L, int pos) {
  return utf8_to_utf16(L, pos, NULL);
}

inline char* push_utf8_string (lua_State* L, const wchar_t* str) {
  return push_utf8_string(L, str, -1);
}

inline void PutWStrToArray(lua_State *L, int key, const wchar_t* str) {
  PutWStrToArray(L, key, str, -1);
}

inline void PutWStrToTable(lua_State *L, const char* key, const wchar_t* str) {
  PutWStrToTable(L, key, str, -1);
}
#endif

#endif // #ifndef _USTRING_H