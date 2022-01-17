//---------------------------------------------------------------------------
#include <windows.h>
#include <dlfcn.h> //dlclose
#include "luafar.h"
#include "util.h"
#include "ustring.h"

extern void Log(const char* str);
extern const char* VirtualKeyStrings[256];
extern void LF_Error(lua_State *L, const wchar_t* aMsg);

// "Collector" is a Lua table referenced from the Plugin Object table by name.
// Collector contains an array of lightuserdata which are pointers to new[]'ed
// chars.
const char COLLECTOR_FD[]  = "Collector_FindData";
const char COLLECTOR_FVD[] = "Collector_FindVirtualData";
const char COLLECTOR_OPI[] = "Collector_OpenPluginInfo";
const char COLLECTOR_PI[]  = "Collector_PluginInfo";
const char KEY_OBJECT[]    = "Object";

// taken from lua.c v5.1.2
int traceback (lua_State *L) {
  lua_getfield(L, LUA_GLOBALSINDEX, "debug");
  if (!lua_istable(L, -1)) {
    lua_pop(L, 1);
    return 1;
  }
  lua_getfield(L, -1, "traceback");
  if (!lua_isfunction(L, -1)) {
    lua_pop(L, 2);
    return 1;
  }
  lua_pushvalue(L, 1);  /* pass error message */
  lua_pushinteger(L, 2);  /* skip this function and traceback */
  lua_call(L, 2, 1);  /* call debug.traceback */
  return 1;
}

// taken from lua.c v5.1.2 (modified)
int docall (lua_State *L, int narg, int nret) {
  int status;
  int base = lua_gettop(L) - narg;  /* function index */
  lua_pushcfunction(L, traceback);  /* push traceback function */
  lua_insert(L, base);  /* put it under chunk and args */
  status = lua_pcall(L, narg, nret, base);
  lua_remove(L, base);  /* remove traceback function */
  /* force a complete garbage collection in case of errors */
  if (status != 0) lua_gc(L, LUA_GCCOLLECT, 0);
  return status;
}

// if the function is successfully retrieved, it's on the stack top; 1 is returned
// else 0 returned (and the stack is unchanged)
int GetExportFunction(lua_State* L, const char* FuncName)
{
  lua_getglobal(L, "export");
  lua_getfield(L, -1, FuncName);
  if (lua_isfunction(L, -1))
    return lua_remove(L,-2), 1;
  else
    return lua_pop(L,2), 0;
}

int pcall_msg (lua_State* L, int narg, int nret)
{
  // int status = lua_pcall(L, narg, nret, 0);
  int status = docall (L, narg, nret);
  if (status != 0) {
    int status2 = 1;
    if (GetExportFunction(L, "OnError")) {
      lua_insert(L,-2);
      status2 = lua_pcall(L,1,0,0);
    }
    if (status2 != 0) {
      LF_Error (L, check_utf8_string(L, -1, NULL));
      lua_pop (L, 1);
    }
  }
  return status;
}

inline void PushPluginTable (lua_State* L, HANDLE hPlugin)
{
  lua_rawgeti(L, LUA_REGISTRYINDEX, (INT_PTR)hPlugin);
}

void PushPluginPair (lua_State* L, HANDLE hPlugin)
{
  lua_rawgeti(L, LUA_REGISTRYINDEX, (INT_PTR)hPlugin);
  lua_getfield(L, -1, KEY_OBJECT);
  lua_remove(L, -2);
  lua_pushinteger(L, (INT_PTR)hPlugin);
}

void CreatePluginInfoCollector (lua_State* L)
{
  lua_newtable(L);
  lua_setfield(L, LUA_REGISTRYINDEX, COLLECTOR_PI);
}

void DestroyPluginInfoCollector(lua_State* L)
{
  lua_pushnil(L);
  lua_setfield(L, LUA_REGISTRYINDEX, COLLECTOR_PI);
}

void DestroyCollector(lua_State* L, HANDLE hPlugin, const char* Collector)
{
  PushPluginTable(L, hPlugin);      //+1: Tbl
  lua_pushnil(L);                   //+2
  lua_setfield(L, -2, Collector);   //+1
  lua_pop(L,1);                     //+0
}

// the value is on stack top (-1)
// collector table is under the index 'pos' (this index cannot be a pseudo-index)
const wchar_t* _AddStringToCollector(lua_State *L, int pos)
{
  if (lua_isstring(L,-1)) {
    const wchar_t* s = check_utf8_string (L, -1, NULL);
    lua_rawseti(L, pos, lua_objlen(L, pos) + 1);
    return s;
  }
  lua_pop(L,1);
  return NULL;
}

// input table is on stack top (-1)
// collector table is under the index 'pos' (this index cannot be a pseudo-index)
const wchar_t* AddStringToCollectorField(lua_State *L, int pos, const char* key)
{
  lua_getfield(L, -1, key);
  return _AddStringToCollector(L, pos);
}

// input table is on stack top (-1)
// collector table is under the index 'pos' (this index cannot be a pseudo-index)
const wchar_t* AddStringToCollectorSlot(lua_State *L, int pos, int key)
{
  lua_pushinteger (L, key);
  lua_gettable(L, -2);
  return _AddStringToCollector(L, pos);
}

// collector table is under the index 'pos' (this index cannot be a pseudo-index)
void* AddBufToCollector(lua_State *L, int pos, size_t size)
{
  if (pos < 0) --pos;
  void* t = lua_newuserdata(L, size);
  memset (t, 0, size);
  lua_rawseti(L, pos, lua_objlen(L, pos) + 1);
  return t;
}

// -- a table is on stack top
// -- its field 'field' is an array of strings
// -- 'cpos' - collector stack position
const wchar_t** CreateStringsArray(lua_State* L, int cpos, const char* field,
                                   int *numstrings)
{
  const wchar_t **buf = NULL;
  lua_getfield(L, -1, field);
  if(lua_istable(L, -1)) {
    int n = lua_objlen(L, -1);
    if (numstrings) *numstrings = n;
    if (n > 0) {
      int i;
      buf = (const wchar_t**)AddBufToCollector(L, cpos, (n+1) * sizeof(wchar_t*));
      for (i=0; i < n; i++)
        buf[i] = AddStringToCollectorSlot(L, cpos, i+1);
      buf[n] = NULL;
    }
  }
  lua_pop(L, 1);
  return buf;
}

// input table is on stack top (-1)
// collector table is one under the top (-2)
void FillPluginPanelItem (lua_State *L, struct PluginPanelItem *pi)
{
  pi->FindData.dwFileAttributes = GetAttrFromTable(L);
  pi->FindData.ftCreationTime   = GetFileTimeFromTable(L, "CreationTime");
  pi->FindData.ftLastAccessTime = GetFileTimeFromTable(L, "LastAccessTime");
  pi->FindData.ftLastWriteTime  = GetFileTimeFromTable(L, "LastWriteTime");
  pi->FindData.nFileSize = GetFileSizeFromTable(L, "FileSize");
  pi->FindData.lpwszFileName = (wchar_t*)AddStringToCollectorField(L,-2,"FileName");

  pi->Flags = GetOptIntFromTable(L, "Flags", 0);
  pi->Flags &= ~PPIF_USERDATA; // prevent far.exe from treating UserData as pointer,
                               // and from copying the data being pointed to.
  pi->NumberOfLinks = GetOptIntFromTable(L, "NumberOfLinks", 0);
  pi->Description = (wchar_t*)AddStringToCollectorField(L, -2, "Description");
  pi->Owner = (wchar_t*)AddStringToCollectorField(L, -2, "Owner");
  pi->UserData = GetOptIntFromTable(L, "UserData", -1);
}

// Two known values on the stack top: Tbl (at -2) and FindData (at -1).
// Both are popped off the stack on return.
void FillFindData(lua_State* L, struct PluginPanelItem **pPanelItems,
  int *pItemsNumber, const char* Collector)
{
  int numLines = lua_objlen(L,-1);
  lua_newtable(L);                           //+3  Tbl,FindData,Coll
  lua_pushvalue(L,-1);                       //+4: Tbl,FindData,Coll,Coll
  lua_setfield(L, -4, Collector);            //+3: Tbl,FindData,Coll
  struct PluginPanelItem *ppi = (struct PluginPanelItem *)
    malloc(sizeof(struct PluginPanelItem) * numLines);
  memset(ppi, 0, numLines*sizeof(struct PluginPanelItem));
  int i, num = 0;
  for (i=1; i<=numLines; i++) {
    lua_pushinteger(L, i);                   //+4
    lua_gettable(L, -3);                     //+4: Tbl,FindData,Coll,FindData[i]
    if (lua_istable(L,-1)) {
      FillPluginPanelItem(L, ppi+num);
      ++num;
    }
    lua_pop(L,1);                            //+3
  }
  lua_pop(L,3);                              //+0
  *pItemsNumber = num;
  *pPanelItems = ppi;
}

int LF_GetFindDataW(lua_State* L, HANDLE hPlugin, struct PluginPanelItem **pPanelItem,
                   int *pItemsNumber, int OpMode)
{
  if (GetExportFunction(L, "GetFindData")) {   //+1: Func
    PushPluginPair(L, hPlugin);                //+3: Func,Pair
    lua_pushinteger(L, OpMode);                //+4: Func,Pair,OpMode
    if (!pcall_msg(L, 3, 1)) {                 //+1: FindData
      if (lua_istable(L, -1)) {
        PushPluginTable(L, hPlugin);           //+2: FindData,Tbl
        lua_insert(L, -2);                     //+2: Tbl,FindData
        FillFindData(L, pPanelItem, pItemsNumber, COLLECTOR_FD);
        return TRUE;
      }
      lua_pop(L,1);
    }
  }
  return FALSE;
}

void LF_FreeFindDataW(lua_State* L, HANDLE hPlugin, struct PluginPanelItem *PanelItems,
                     int ItemsNumber)
{
  (void)ItemsNumber;
  DestroyCollector(L, hPlugin, COLLECTOR_FD);
  free(PanelItems);
}
//---------------------------------------------------------------------------

int LF_GetVirtualFindDataW (lua_State* L, HANDLE hPlugin,
  struct PluginPanelItem **pPanelItem, int *pItemsNumber, const wchar_t *Path)
{
  if (GetExportFunction(L, "GetVirtualFindData")) {      //+1: Func
    PushPluginPair(L, hPlugin);                          //+3: Func,Pair
    push_utf8_string(L, Path, -1);                       //+4: Func,Pair,Path
    if (!pcall_msg(L, 3, 1)) {                           //+1: FindData
      if (lua_istable(L, -1)) {
        PushPluginTable(L, hPlugin);                     //+2: FindData,Tbl
        lua_insert(L, -2);                               //+2: Tbl,FindData
        FillFindData(L, pPanelItem, pItemsNumber, COLLECTOR_FVD);
        return TRUE;
      }
      lua_pop(L,1);
    }
  }
  return FALSE;
}

void LF_FreeVirtualFindDataW(lua_State* L, HANDLE hPlugin,
  struct PluginPanelItem *PanelItem, int ItemsNumber)
{
  (void)ItemsNumber;
  DestroyCollector(L, hPlugin, COLLECTOR_FVD);
  free(PanelItem);
}

// PanelItem table should be on Lua stack top
void UpdateFileSelection(lua_State* L, struct PluginPanelItem *PanelItem,
  int ItemsNumber)
{
  int i;
  for (i=0; i<ItemsNumber; i++) {
    lua_rawgeti(L, -1, i+1);           //+1
    if(lua_istable(L,-1)) {
      lua_getfield(L,-1,"Flags");      //+2
      if(lua_istable(L,-1)) {
        lua_getfield(L,-1,"selected"); //+3
        if(lua_toboolean(L,-1))
          PanelItem[i].Flags |= PPIF_SELECTED;
        else
          PanelItem[i].Flags &= ~PPIF_SELECTED;
        lua_pop(L,1);       //+2
      }
      lua_pop(L,1);         //+1
    }
    lua_pop(L,1);           //+0
  }
}
//---------------------------------------------------------------------------

int LF_GetFilesW (lua_State* L, HANDLE hPlugin, struct PluginPanelItem *PanelItem,
  int ItemsNumber, int Move, const wchar_t **DestPath, int OpMode)
{
  if (GetExportFunction(L, "GetFiles")) {      //+1: Func
    PushPanelItems(L, PanelItem, ItemsNumber); //+2: Func,Item
    lua_insert(L,-2);                          //+2: Item,Func
    PushPluginPair(L, hPlugin);                //+4: Item,Func,Pair
    lua_pushvalue(L,-4);                       //+5: Item,Func,Pair,Item
    lua_pushboolean(L, Move);
    push_utf8_string(L, *DestPath, -1);
    lua_pushinteger(L, OpMode);        //+8: Item,Func,Pair,Item,Move,Dest,OpMode
    int ret = pcall_msg(L, 6, 2);      //+3: Item,Res,Dest
    if (ret == 0) {
      if (lua_isstring(L,-1)) {
        *DestPath = check_utf8_string(L,-1,NULL);
        lua_setfield(L, LUA_REGISTRYINDEX, "GetFiles.DestPath"); // protect from GC
      }
      else
        lua_pop(L,1);                  //+2: Item,Res
      ret = lua_tointeger(L,-1);
      lua_pop(L,1);                    //+1: Item
      UpdateFileSelection(L, PanelItem, ItemsNumber);
      return lua_pop(L,1), ret;
    }
    return lua_pop(L,1), 0;
  }
  return 0;
}
//---------------------------------------------------------------------------

// return FALSE only if error occurred
BOOL CheckReloadDefaultScript (lua_State *L)
{
  // reload default script?
  lua_getglobal(L, "far");
  lua_getfield(L, -1, "ReloadDefaultScript");
  int reload = lua_toboolean(L, -1);
  lua_pop (L, 2);
  return !reload || LF_RunDefaultScript(L);
}

// -- an object (any non-nil value) is on stack top;
// -- a new table is created, the object is put into it under the key KEY_OBJECT;
// -- the table is put into the registry, and reference to it is obtained;
// -- the function pops the object and returns the reference;
INT_PTR RegisterObject (lua_State* L)
{
  lua_newtable(L);               //+2: Obj,Tbl
  lua_pushvalue(L,-2);           //+3: Obj,Tbl,Obj
  lua_setfield(L,-2,KEY_OBJECT); //+2: Obj,Tbl
  int ref = luaL_ref(L, LUA_REGISTRYINDEX); //+1: Obj
  lua_pop(L,1);                  //+0
  return ref;
}

HANDLE LF_OpenFilePluginW(lua_State* L, const wchar_t *aName,
  const unsigned char *aData, int aDataSize, int OpMode)
{
  if (!CheckReloadDefaultScript(L))
    return INVALID_HANDLE_VALUE;

  if (GetExportFunction(L, "OpenFilePlugin")) {           //+1
    if(aName) {
      push_utf8_string(L, aName, -1);                     //+2
      lua_pushlstring(L, (const char*)aData, aDataSize);  //+3
    }
    else {
      lua_pushnil(L); lua_pushnil(L);
    }
    lua_pushinteger(L, OpMode);
    if (!pcall_msg(L, 3, 1)) {
      if (lua_type(L,-1) == LUA_TNUMBER && lua_tointeger(L,-1) == -2) {
        lua_pop(L,1);
        return (HANDLE)(-2);
      }
      if (lua_toboolean(L, -1))                           //+1
        return (HANDLE)RegisterObject(L);                 //+0
      lua_pop (L, 1);                                     //+0
    }
  }
  return INVALID_HANDLE_VALUE;
}
//---------------------------------------------------------------------------

void LF_GetOpenPluginInfoW(lua_State* L, HANDLE hPlugin, struct OpenPluginInfo *aInfo)
{
  aInfo->StructSize = sizeof (struct OpenPluginInfo);
  if (!GetExportFunction(L, "GetOpenPluginInfo"))    //+1
    return;

  PushPluginPair(L, hPlugin);                        //+3
  if(pcall_msg(L, 2, 1) != 0)
    return;

  if(lua_isstring(L,-1) && !strcmp("reuse", lua_tostring(L,-1))) {
    PushPluginTable(L, hPlugin);                     //+2: reuse,Tbl
    lua_getfield(L, -1, COLLECTOR_OPI);              //+3: reuse,Tbl,Coll
    if (!lua_istable(L,-1)) {    // collector either not set, or destroyed
      lua_pop(L,3);
      return;
    }
    lua_rawgeti(L,-1,1);                             //+4: reuse,Tbl,Coll,OPI
    struct OpenPluginInfo *Info = (struct OpenPluginInfo*)lua_touserdata(L,-1);
    *aInfo = *Info;
    lua_pop(L,4);
    return;
  }
  if(!lua_istable(L, -1)) {                          //+1: Info
    lua_pop(L, 1);
    LF_Error(L, L"GetOpenPluginInfo should return a table");
    return;
  }
  DestroyCollector(L, hPlugin, COLLECTOR_OPI);
  PushPluginTable(L, hPlugin);                       //+2: Info,Tbl
  lua_newtable(L);                                   //+3: Info,Tbl,Coll
  int cpos = lua_gettop (L);  // collector stack position
  lua_pushvalue(L,-1);                               //+4: Info,Tbl,Coll,Coll
  lua_setfield(L, -3, COLLECTOR_OPI);                //+3: Info,Tbl,Coll
  lua_pushvalue(L,-3);                               //+4: Info,Tbl,Coll,Info
  //---------------------------------------------------------------------------
  // First element in the collector; can be retrieved on later calls;
  struct OpenPluginInfo *Info =
    (struct OpenPluginInfo*) AddBufToCollector(L, cpos, sizeof(struct OpenPluginInfo));
  //---------------------------------------------------------------------------
  Info->StructSize = sizeof (struct OpenPluginInfo);
  Info->Flags      = GetOptIntFromTable(L, "Flags", 0);
  Info->HostFile   = AddStringToCollectorField(L, cpos, "HostFile");
  Info->CurDir     = AddStringToCollectorField(L, cpos, "CurDir");
  Info->Format     = AddStringToCollectorField(L, cpos, "Format");
  Info->PanelTitle = AddStringToCollectorField(L, cpos, "PanelTitle");
  //---------------------------------------------------------------------------
  lua_getfield(L, -1, "InfoLines");
  lua_getfield(L, -2, "InfoLinesNumber");
  if (lua_istable(L,-2) && lua_isnumber(L,-1)) {
    int InfoLinesNumber = lua_tointeger(L, -1);
    lua_pop(L,1);                         //+5: Info,Tbl,Coll,Info,Lines
    if (InfoLinesNumber > 0 && InfoLinesNumber <= 100) {
      int i;
      struct InfoPanelLine *pl = (struct InfoPanelLine*)
        AddBufToCollector(L, cpos, InfoLinesNumber * sizeof(struct InfoPanelLine));
      Info->InfoLines = pl;
      Info->InfoLinesNumber = InfoLinesNumber;
      for (i=0; i<InfoLinesNumber; ++i,++pl,lua_pop(L,1)) {
        lua_pushinteger(L, i+1);
        lua_gettable(L, -2);
        if(lua_istable(L, -1)) {          //+6: Info,Tbl,Coll,Info,Lines,Line
          pl->Text = AddStringToCollectorField(L, cpos, "Text");
          pl->Data = AddStringToCollectorField(L, cpos, "Data");
          pl->Separator = GetOptIntFromTable(L, "Separator", 0);
        }
      }
    }
    lua_pop(L,1);
  }
  else lua_pop(L, 2);
  //---------------------------------------------------------------------------
  Info->DescrFiles = CreateStringsArray(L, cpos, "DescrFiles", &Info->DescrFilesNumber);
  //---------------------------------------------------------------------------
  lua_getfield(L, -1, "PanelModesArray");
  lua_getfield(L, -2, "PanelModesNumber");
  if (lua_istable(L,-2) && lua_isnumber(L,-1)) {
    int PanelModesNumber = lua_tointeger(L, -1);
    lua_pop(L,1);                               //+5: Info,Tbl,Coll,Info,Modes
    if (PanelModesNumber > 0 && PanelModesNumber <= 100) {
      int i;
      struct PanelMode *pm = (struct PanelMode*)
        AddBufToCollector(L, cpos, PanelModesNumber * sizeof(struct PanelMode));
      Info->PanelModesArray = pm;
      Info->PanelModesNumber = PanelModesNumber;
      for (i=0; i<PanelModesNumber; ++i,++pm,lua_pop(L,1)) {
        lua_pushinteger(L, i+1);
        lua_gettable(L, -2);
        if(lua_istable(L, -1)) {                //+6: Info,Tbl,Coll,Info,Modes,Mode
          pm->ColumnTypes  = (wchar_t*)AddStringToCollectorField(L, cpos, "ColumnTypes");
          pm->ColumnWidths = (wchar_t*)AddStringToCollectorField(L, cpos, "ColumnWidths");
          pm->FullScreen   = (int)GetOptBoolFromTable(L, "FullScreen", FALSE);
          pm->DetailedStatus  = GetOptIntFromTable(L, "DetailedStatus", 0);
          pm->AlignExtensions = GetOptIntFromTable(L, "AlignExtensions", 0);
          pm->CaseConversion  = (int)GetOptBoolFromTable(L, "CaseConversion", FALSE);
          pm->StatusColumnTypes  = (wchar_t*)AddStringToCollectorField(L, cpos, "StatusColumnTypes");
          pm->StatusColumnWidths = (wchar_t*)AddStringToCollectorField(L, cpos, "StatusColumnWidths");
          pm->ColumnTitles = (const wchar_t* const*)CreateStringsArray(L, cpos, "ColumnTitles", NULL);
        }
      }
    }
    lua_pop(L,1);
  }
  else lua_pop(L, 2);
  //---------------------------------------------------------------------------
  Info->StartPanelMode = GetOptIntFromTable(L, "StartPanelMode", 0);
  Info->StartSortMode  = GetOptIntFromTable(L, "StartSortMode", 0);
  Info->StartSortOrder = GetOptIntFromTable(L, "StartSortOrder", 0);
  //---------------------------------------------------------------------------
  lua_getfield (L, -1, "KeyBar");
  if (lua_istable(L, -1)) {
    size_t i;
    int j;
    struct KeyBarTitles *kbt = (struct KeyBarTitles*)
      AddBufToCollector(L, cpos, sizeof(struct KeyBarTitles));
    Info->KeyBar = kbt;
    struct { const char* key; wchar_t** trg; } pairs[] = {
      {"Titles",          kbt->Titles},
      {"CtrlTitles",      kbt->CtrlTitles},
      {"AltTitles",       kbt->AltTitles},
      {"ShiftTitles",     kbt->ShiftTitles},
      {"CtrlShiftTitles", kbt->CtrlShiftTitles},
      {"AltShiftTitles",  kbt->AltShiftTitles},
      {"CtrlAltTitles",   kbt->CtrlAltTitles},
    };
    for (i=0; i < sizeof(pairs)/sizeof(pairs[0]); i++) {
      lua_getfield (L, -1, pairs[i].key);
      if (lua_istable (L, -1)) {
        for (j=0; j<12; j++)
          pairs[i].trg[j] = (wchar_t*)AddStringToCollectorSlot(L, cpos, j+1);
      }
      lua_pop (L, 1);
    }
  }
  lua_pop(L,1);
  //---------------------------------------------------------------------------
  Info->ShortcutData = AddStringToCollectorField (L, cpos, "ShortcutData");
  //---------------------------------------------------------------------------
  lua_pop(L,4);
  *aInfo = *Info;
}
//---------------------------------------------------------------------------

HANDLE LF_OpenPluginW (lua_State* L, int OpenFrom, INT_PTR Item)
{
  if (!CheckReloadDefaultScript(L) || !GetExportFunction(L, "OpenPlugin"))
    return INVALID_HANDLE_VALUE;

  lua_pushinteger(L, OpenFrom);

  if (OpenFrom & OPEN_FROMMACRO) {
    int op_macro = OpenFrom & OPEN_FROMMACRO_MASK & ~OPEN_FROMMACRO;
    if (op_macro == 0)
      lua_pushinteger(L, Item);
    else if (op_macro == OPEN_FROMMACROSTRING)
      push_utf8_string(L, (const wchar_t*)Item, -1);
    else
      lua_pushinteger(L, Item);
  }
  else {
    if (OpenFrom==OPEN_SHORTCUT || OpenFrom==OPEN_COMMANDLINE)
      push_utf8_string(L, (const wchar_t*)Item, -1);
    else if (OpenFrom==OPEN_DIALOG) {
      struct OpenDlgPluginData *data = (struct OpenDlgPluginData*)Item;
      lua_createtable(L, 0, 2);
      PutIntToTable(L, "ItemNumber", data->ItemNumber);
      NewDialogData(L, NULL, data->hDlg, FALSE);
      lua_setfield(L, -2, "hDlg");
    }
    else
      lua_pushinteger(L, Item);
  }

  if (pcall_msg(L, 2, 1) == 0) {
    if (lua_type(L,-1) == LUA_TNUMBER && lua_tointeger(L,-1) == 0) {
      lua_pop(L,1);
      return (HANDLE) 0; // unload plugin
    }
    if (lua_toboolean(L, -1))            //+1: Obj
      return (HANDLE) RegisterObject(L); //+0
    lua_pop(L,1);
  }
  return INVALID_HANDLE_VALUE;
}

void LF_ClosePluginW(lua_State* L, HANDLE hPlugin)
{
  if (GetExportFunction(L, "ClosePlugin")) { //+1: Func
    PushPluginPair(L, hPlugin);              //+3: Func,Pair
    pcall_msg(L, 2, 0);
  }
  DestroyCollector(L, hPlugin, COLLECTOR_OPI);
  luaL_unref(L, LUA_REGISTRYINDEX, (INT_PTR)hPlugin);
}

int LF_CompareW(lua_State* L, HANDLE hPlugin, const struct PluginPanelItem *Item1,
               const struct PluginPanelItem *Item2, unsigned int Mode)
{
  int res = -2; // default FAR compare function should be used
  if (GetExportFunction(L, "Compare")) { //+1: Func
    PushPluginPair(L, hPlugin);          //+3: Func,Pair
    PushPanelItem(L, Item1);             //+4
    PushPanelItem(L, Item2);             //+5
    lua_pushinteger(L, Mode);            //+6
    if (0 == pcall_msg(L, 5, 1)) {       //+1
      res = lua_tointeger(L,-1);
      lua_pop(L,1);
    }
  }
  return res;
}

int LF_ConfigureW(lua_State* L, int ItemNumber)
{
  int res = FALSE;
  if (GetExportFunction(L, "Configure")) { //+1: Func
    lua_pushinteger(L, ItemNumber);
    if(0 == pcall_msg(L, 1, 1)) {        //+1
      res = lua_toboolean(L,-1);
      lua_pop(L,1);
    }
  }
  return res;
}

int LF_DeleteFilesW(lua_State* L, HANDLE hPlugin, struct PluginPanelItem *PanelItem,
  int ItemsNumber, int OpMode)
{
  int res = FALSE;
  if (GetExportFunction(L, "DeleteFiles")) {   //+1: Func
    PushPluginPair(L, hPlugin);                //+3: Func,Pair
    PushPanelItems(L, PanelItem, ItemsNumber); //+4
    lua_pushinteger(L, OpMode);                //+5
    if(0 == pcall_msg(L, 4, 1))    {           //+1
      res = lua_toboolean(L,-1);
      lua_pop(L,1);
    }
  }
  return res;
}

// far.MakeDirectory returns 2 values:
//    a) status (an integer; in accordance to FAR API), and
//    b) new directory name (a string; optional)
int LF_MakeDirectoryW (lua_State* L, HANDLE hPlugin, const wchar_t **Name, int OpMode)
{
  int res = 0;
  if (GetExportFunction(L, "MakeDirectory")) { //+1: Func
    PushPluginPair(L, hPlugin);                //+3: Func,Pair
    push_utf8_string(L, *Name, -1);            //+4
    lua_pushinteger(L, OpMode);                //+5
    if(0 == pcall_msg(L, 4, 2)) {              //+2
      res = lua_tointeger(L,-2);
      if (res == 1 && lua_isstring(L,-1)) {
        *Name = check_utf8_string(L,-1,NULL);
        lua_pushvalue(L, -1);
        lua_setfield(L, LUA_REGISTRYINDEX, "MakeDirectory.Name"); // protect from GC
      }
      else if (res != -1)
        res = 0;
      lua_pop(L,2);
    }
  }
  return res;
}

int LF_ProcessEventW(lua_State* L, HANDLE hPlugin, int Event, void *Param)
{
  int res = FALSE;
  if (GetExportFunction(L, "ProcessEvent")) { //+1: Func
    PushPluginPair(L, hPlugin);        //+3
    lua_pushinteger(L, Event);         //+4
    if (Event == FE_CHANGEVIEWMODE || Event == FE_COMMAND)
      push_utf8_string(L, (wchar_t*)Param, -1); //+5
    else
      lua_pushnil(L);                  //+5
    if(0 == pcall_msg(L, 4, 1))  {     //+1
      res = lua_toboolean(L,-1);
      lua_pop(L,1);                    //+0
    }
  }
  return res;
}

int LF_ProcessHostFileW(lua_State* L, HANDLE hPlugin, struct PluginPanelItem *PanelItem,
  int ItemsNumber, int OpMode)
{
  if (GetExportFunction(L, "ProcessHostFile")) {   //+1: Func
    PushPanelItems(L, PanelItem, ItemsNumber); //+2: Func,Item
    lua_insert(L,-2);                  //+2: Item,Func
    PushPluginPair(L, hPlugin);        //+4: Item,Func,Pair
    lua_pushvalue(L,-4);               //+5: Item,Func,Pair,Item
    lua_pushinteger(L, OpMode);        //+6: Item,Func,Pair,Item,OpMode
    int ret = pcall_msg(L, 4, 1);      //+2: Item,Res
    if (ret == 0) {
      ret = lua_toboolean(L,-1);
      lua_pop(L,1);                    //+1: Item
      UpdateFileSelection(L, PanelItem, ItemsNumber);
      return lua_pop(L,1), ret;
    }
    lua_pop(L,1);
  }
  return FALSE;
}

int LF_ProcessKeyW(lua_State* L, HANDLE hPlugin, int Key,
  unsigned int ControlState)
{
  if (GetExportFunction(L, "ProcessKey")) {   //+1: Func
    PushPluginPair(L, hPlugin);        //+3: Func,Pair
    lua_pushinteger(L, Key);           //+4
    lua_pushinteger(L, ControlState);  //+5
    if (pcall_msg(L, 4, 1) == 0)    {  //+1: Res
      int ret = lua_toboolean(L,-1);
      return lua_pop(L,1), ret;
    }
  }
  return FALSE;
}

int LF_PutFilesW(lua_State* L, HANDLE hPlugin, struct PluginPanelItem *PanelItems,
  int ItemsNumber, int Move, int OpMode)
{
  if (GetExportFunction(L, "PutFiles")) {   //+1: Func
    PushPanelItems(L, PanelItems, ItemsNumber); //+2: Func,Items
    lua_insert(L,-2);                  //+2: Items,Func
    PushPluginPair(L, hPlugin);        //+4: Items,Func,Pair
    lua_pushvalue(L,-4);               //+5: Items,Func,Pair,Item
    lua_pushboolean(L, Move);          //+6: Items,Func,Pair,Item,Move
    lua_pushinteger(L, OpMode);        //+7: Items,Func,Pair,Item,Move,OpMode
    int ret = pcall_msg(L, 5, 1);      //+2: Items,Res
    if (ret == 0) {
      ret = lua_tointeger(L,-1);
      lua_pop(L,1);                    //+1: Items
      UpdateFileSelection(L, PanelItems, ItemsNumber);
      return lua_pop(L,1), ret;
    }
    lua_pop(L,1);
  }
  return 0;
}

int LF_SetDirectoryW(lua_State* L, HANDLE hPlugin, const wchar_t *Dir, int OpMode)
{
  if (GetExportFunction(L, "SetDirectory")) {   //+1: Func
    PushPluginPair(L, hPlugin);        //+3: Func,Pair
    push_utf8_string(L, Dir, -1);      //+4: Func,Pair,Dir
    lua_pushinteger(L, OpMode);        //+5: Func,Pair,Dir,OpMode
    int ret = pcall_msg(L, 4, 1);      //+1: Res
    if (ret == 0) {
      ret = lua_toboolean(L,-1);
      return lua_pop(L,1), ret;
    }
  }
  return FALSE;
}

int LF_SetFindListW(lua_State* L, HANDLE hPlugin, const struct PluginPanelItem *PanelItems,
  int ItemsNumber)
{
  if (GetExportFunction(L, "SetFindList")) {    //+1: Func
    PushPluginPair(L, hPlugin);                 //+3: Func,Pair
    PushPanelItems(L, PanelItems, ItemsNumber); //+4: Func,Pair,Items
    int ret = pcall_msg(L, 3, 1);               //+1: Res
    if (ret == 0) {
      ret = lua_toboolean(L,-1);
      return lua_pop(L,1), ret;
    }
  }
  return FALSE;
}

void LF_LuaClose(lua_State* L, void* dlopen_handle)
{
  DestroyPluginInfoCollector(L);
  lua_close(L);
  dlclose(dlopen_handle);
}

void LF_ExitFARW(lua_State* L)
{
  DestroyPluginInfoCollector(L);
  if (GetExportFunction(L, "ExitFAR"))   //+1: Func
    pcall_msg(L, 0, 0);                  //+0
}

void LF_GetPluginInfoW(lua_State* L, struct PluginInfo *aPI)
{
  aPI->StructSize = sizeof (struct PluginInfo);
  if (!GetExportFunction(L, "GetPluginInfo"))    //+1
    return;
  if (pcall_msg(L, 0, 1) != 0)
    return;
  if (!lua_istable(L, -1)) {
    lua_pop(L,1);
    return;
  }
  //--------------------------------------------------------------------------
  DestroyPluginInfoCollector (L);
  CreatePluginInfoCollector (L);
  lua_getfield(L, LUA_REGISTRYINDEX, COLLECTOR_PI);  //+2: Info,Coll
  int cpos = lua_gettop(L);  // collector position
  lua_pushvalue(L, -2);                              //+3: Info,Coll,Info
  //--------------------------------------------------------------------------
  struct PluginInfo *PI = (struct PluginInfo*)
    AddBufToCollector (L, cpos, sizeof(struct PluginInfo));
  PI->StructSize = sizeof (struct PluginInfo);
  //--------------------------------------------------------------------------
  PI->Flags = GetOptIntFromTable (L, "Flags", 0);
  PI->Reserved = GetOptIntFromTable (L, "SysId", 0);
  //--------------------------------------------------------------------------
  PI->DiskMenuStrings = CreateStringsArray (L, cpos, "DiskMenuStrings", &PI->DiskMenuStringsNumber);
  PI->PluginMenuStrings = CreateStringsArray (L, cpos, "PluginMenuStrings", &PI->PluginMenuStringsNumber);
  PI->PluginConfigStrings = CreateStringsArray (L, cpos, "PluginConfigStrings", &PI->PluginConfigStringsNumber);
  PI->CommandPrefix = AddStringToCollectorField(L, cpos, "CommandPrefix");
  //--------------------------------------------------------------------------
  lua_pop(L, 3);
  *aPI = *PI;
}

int LF_ProcessEditorInputW (lua_State* L, const INPUT_RECORD *Rec)
{
  if (!GetExportFunction(L, "ProcessEditorInput"))   //+1: Func
    return 0;
  lua_newtable(L);                   //+2: Func,Tbl
  PutNumToTable(L, "EventType", Rec->EventType);
  if (Rec->EventType==KEY_EVENT || Rec->EventType==FARMACRO_KEY_EVENT) {
    PutBoolToTable(L, "bKeyDown",          Rec->Event.KeyEvent.bKeyDown);
    PutNumToTable(L,  "wRepeatCount",      Rec->Event.KeyEvent.wRepeatCount);

    int vKey = Rec->Event.KeyEvent.wVirtualKeyCode & 0xff;
    const char* s = VirtualKeyStrings[vKey] ? VirtualKeyStrings[vKey] : "";
    PutStrToTable(L, "wVirtualKeyCode", s);

    PutNumToTable(L,  "wVirtualScanCode",  Rec->Event.KeyEvent.wVirtualScanCode);
    PutNumToTable(L,  "AsciiChar",         Rec->Event.KeyEvent.uChar.AsciiChar);
    PutNumToTable(L,  "UnicodeChar",       Rec->Event.KeyEvent.uChar.UnicodeChar);
    PutNumToTable(L,  "dwControlKeyState", Rec->Event.KeyEvent.dwControlKeyState);
  }
  else if (Rec->EventType == MOUSE_EVENT) {
    PutMouseEvent(L, &Rec->Event.MouseEvent, TRUE);
  }
  else if (Rec->EventType == WINDOW_BUFFER_SIZE_EVENT) {
    PutNumToTable(L, "dwSizeX", Rec->Event.WindowBufferSizeEvent.dwSize.X);
    PutNumToTable(L, "dwSizeY", Rec->Event.WindowBufferSizeEvent.dwSize.Y);
  }
  else if (Rec->EventType == MENU_EVENT) {
    PutNumToTable(L, "dwCommandId", Rec->Event.MenuEvent.dwCommandId);
  }
  else if (Rec->EventType == FOCUS_EVENT) {
    PutBoolToTable(L, "bSetFocus", Rec->Event.FocusEvent.bSetFocus);
  }
  int ret = pcall_msg(L, 1, 1);      //+1: Res
  if (ret == 0) {
    ret = lua_toboolean(L,-1);
    return lua_pop(L,1), ret;
  }
  return 0;
}

int LF_ProcessEditorEventW (lua_State* L, int Event, void *Param)
{
  int ret = 0;
  if (GetExportFunction(L, "ProcessEditorEvent"))  { //+1: Func
    lua_pushinteger(L, Event);  //+2;
    switch(Event) {
      case EE_CLOSE:
      case EE_GOTFOCUS:
      case EE_KILLFOCUS:
        lua_pushinteger(L, *(int*)Param); break;
      case EE_REDRAW:
        lua_pushinteger(L, (INT_PTR)Param); break;
      default:
        lua_pushnil(L); break;
    }
    if (pcall_msg(L, 2, 1) == 0) {    //+1
      if (lua_isnumber(L,-1)) ret = lua_tointeger(L,-1);
      lua_pop(L,1);
    }
  }
  return ret;
}

int LF_ProcessViewerEventW (lua_State* L, int Event, void* Param)
{
  int ret = 0;
  if (GetExportFunction(L, "ProcessViewerEvent"))  { //+1: Func
    lua_pushinteger(L, Event);
    switch(Event) {
      case VE_GOTFOCUS:
      case VE_KILLFOCUS:
      case VE_CLOSE:  lua_pushinteger(L, *(int*)Param); break;
      default:        lua_pushnil(L); break;
    }
    if (pcall_msg(L, 2, 1) == 0) {      //+1
      if (lua_isnumber(L,-1)) ret = lua_tointeger(L,-1);
      lua_pop(L,1);
    }
  }
  return ret;
}

int LF_ProcessDialogEventW (lua_State* L, int Event, void *Param)
{
  int ret = 0;
  if (GetExportFunction(L, "ProcessDialogEvent"))  { //+1: Func
    struct FarDialogEvent *fde = (struct FarDialogEvent*) Param;
    lua_pushinteger(L, Event); //+2
    lua_createtable(L, 0, 5);  //+3
    NewDialogData(L, NULL, fde->hDlg, FALSE);
    lua_setfield(L, -2, "hDlg"); //+3
    PutIntToTable(L, "Msg", fde->Msg);
    PutIntToTable(L, "Param1", fde->Param1);
    PutIntToTable(L, "Param2", fde->Param2);
    PutIntToTable(L, "Result", fde->Result);
    if (pcall_msg(L, 2, 2) == 0) {  //+2
      ret = lua_isnumber(L,-2) ? lua_tointeger(L,-2) : lua_toboolean(L,-2);
      if (ret != 0)
        fde->Result = lua_tointeger(L,-1);
      lua_pop(L,2);
    }
  }
  return ret;
}

int LF_ProcessSynchroEventW (lua_State* L, int Event, void *Param)
{
  if (Event == SE_COMMONSYNCHRO) {
    TTimerData *td = (TTimerData*)Param;
    if (!td->needDelete) {
      lua_rawgeti(L, LUA_REGISTRYINDEX, td->funcRef); //+1: Func
      if (lua_type(L, -1) == LUA_TFUNCTION) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, td->objRef); //+2: Obj
        pcall_msg(L, 1, 0);  //+0
      }
      else lua_pop(L, 1);
    }
    else {
      luaL_unref(L, LUA_REGISTRYINDEX, td->objRef);
      luaL_unref(L, LUA_REGISTRYINDEX, td->funcRef);
      luaL_unref(L, LUA_REGISTRYINDEX, td->threadRef);
    }
  }
  return 0;
}

int LF_GetCustomDataW(lua_State* L, const wchar_t *FilePath, wchar_t **CustomData)
{
  if (GetExportFunction(L, "GetCustomData"))  { //+1: Func
    push_utf8_string(L, FilePath, -1);  //+2
    if (pcall_msg(L, 1, 1) == 0) {  //+1
      if (lua_isstring(L, -1)) {
        const wchar_t* p = utf8_to_utf16(L, -1, NULL);
        if (p) {
          *CustomData = wcsdup(p);
          lua_pop(L, 1);
          return TRUE;
        }
      }
      lua_pop(L, 1);
    }
  }
  return FALSE;
}

void  LF_FreeCustomDataW(lua_State* L, wchar_t *CustomData)
{
  (void) L;
  if (CustomData) free(CustomData);
}

