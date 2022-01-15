//---------------------------------------------------------------------------
#include <windows.h>
#include "lua.h"
#include "luafar.h"

#define LUAPLUG _export

// define the minimum FAR version required by the plugin
#ifndef MINFARVERSION
#define MINFARVERSION MAKEFARVERSION(2,0,1420)
#endif

#ifdef FUNC_OPENLIBS
extern int FUNC_OPENLIBS (lua_State*);
#else
#define FUNC_OPENLIBS NULL
#endif

#ifndef ENV_PREFIX
# ifdef _WIN64
#  define ENV_PREFIX "LUAFAR64"
# else
#  define ENV_PREFIX "LUAFAR"
# endif
#endif

struct PluginStartupInfo Info;
struct FarStandardFunctions FSF;
lua_State* LS;
void* dlopen_handle;
//---------------------------------------------------------------------------

// This function must have __cdecl calling convention, it is not `LUAPLUG'.
int _export luaopen_luaplug (lua_State *L)
{
  LF_InitLuaState(L, &Info, FUNC_OPENLIBS, ENV_PREFIX);
  return 0;
}
//---------------------------------------------------------------------------

void LUAPLUG SetStartupInfoW(const struct PluginStartupInfo *aInfo)
{
  Info = *aInfo;
  FSF = *aInfo->FSF;
  Info.FSF = &FSF;
  if (!LS)
    LS = LF_LuaOpen(&Info, FUNC_OPENLIBS, ENV_PREFIX, &dlopen_handle); //includes opening "far" library
  if (LS) {
    if (LF_RunDefaultScript(LS) == FALSE) {
      LF_LuaClose(LS, dlopen_handle);
      LS = NULL;
    }
  }
}
//---------------------------------------------------------------------------

void LUAPLUG GetPluginInfoW(struct PluginInfo *Info)
{
  if(LS) LF_GetPluginInfoW (LS, Info);
}
//---------------------------------------------------------------------------

#ifdef EXPORT_OPENPLUGINW
HANDLE LUAPLUG OpenPluginW(int OpenFrom, INT_PTR Item)
{
  if(LS) return LF_OpenPluginW(LS, OpenFrom, Item);
  return INVALID_HANDLE_VALUE;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_OPENFILEPLUGINW
HANDLE LUAPLUG OpenFilePluginW(const wchar_t *Name, const unsigned char *Data,
  int DataSize, int OpMode)
{
  if(LS) return LF_OpenFilePluginW(LS, Name, Data, DataSize, OpMode);
  return INVALID_HANDLE_VALUE;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_GETFINDDATAW
int LUAPLUG GetFindDataW(HANDLE hPlugin, struct PluginPanelItem **pPanelItem,
                        int *pItemsNumber, int OpMode)
{
  if(LS) return LF_GetFindDataW(LS, hPlugin, pPanelItem, pItemsNumber, OpMode);
  return FALSE;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_FREEFINDDATAW
void LUAPLUG FreeFindDataW(HANDLE hPlugin, struct PluginPanelItem *PanelItem,
                         int ItemsNumber)
{
  if(LS) LF_FreeFindDataW(LS, hPlugin, PanelItem, ItemsNumber);
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_CLOSEPLUGINW
void LUAPLUG ClosePluginW(HANDLE hPlugin)
{
  if(LS) LF_ClosePluginW(LS, hPlugin);
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_GETFILESW
int LUAPLUG GetFilesW(HANDLE hPlugin, struct PluginPanelItem *PanelItem,
  int ItemsNumber, int Move, const wchar_t **DestPath, int OpMode)
{
  if(LS)
    return LF_GetFilesW(LS,hPlugin,PanelItem,ItemsNumber,Move,DestPath,OpMode);
  return 0;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_GETOPENPLUGININFOW
void LUAPLUG GetOpenPluginInfoW(HANDLE hPlugin, struct OpenPluginInfo *Info)
{
  if(LS) LF_GetOpenPluginInfoW(LS, hPlugin, Info);
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_EXITFARW
void LUAPLUG ExitFARW()
{
  if(LS) {
    LF_ExitFARW(LS);
    LF_LuaClose(LS, dlopen_handle);
    LS = NULL;
  }
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_COMPAREW
int LUAPLUG CompareW(HANDLE hPlugin, const struct PluginPanelItem *Item1,
                    const struct PluginPanelItem *Item2, unsigned int Mode)
{
  if(LS) return LF_CompareW(LS, hPlugin, Item1, Item2, Mode);
  return 0;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_CONFIGUREW
int LUAPLUG ConfigureW(int ItemNumber)
{
  if(LS) return LF_ConfigureW(LS, ItemNumber);
  return FALSE;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_DELETEFILESW
int LUAPLUG DeleteFilesW(HANDLE hPlugin, struct PluginPanelItem *PanelItem,
  int ItemsNumber, int OpMode)
{
  if(LS) return LF_DeleteFilesW(LS, hPlugin, PanelItem, ItemsNumber, OpMode);
  return FALSE;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_FREEVIRTUALFINDDATAW
void LUAPLUG FreeVirtualFindDataW(HANDLE hPlugin,
  struct PluginPanelItem *PanelItem, int ItemsNumber)
{
  if(LS) LF_FreeVirtualFindDataW(LS, hPlugin, PanelItem, ItemsNumber);
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_GETVIRTUALFINDDATAW
int LUAPLUG GetVirtualFindDataW(HANDLE hPlugin,
  struct PluginPanelItem **pPanelItem, int *pItemsNumber, const wchar_t *Path)
{
  if(LS) return LF_GetVirtualFindDataW(LS,hPlugin,pPanelItem,pItemsNumber,Path);
  return FALSE;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_MAKEDIRECTORYW
int LUAPLUG MakeDirectoryW(HANDLE hPlugin, const wchar_t **Name, int OpMode)
{
  if(LS) return LF_MakeDirectoryW(LS, hPlugin, Name, OpMode);
  return 0;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_PROCESSEVENTW
int LUAPLUG ProcessEventW(HANDLE hPlugin, int Event, void *Param)
{
  if(LS) return LF_ProcessEventW(LS, hPlugin, Event, Param);
  return FALSE;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_PROCESSHOSTFILEW
int LUAPLUG ProcessHostFileW(HANDLE hPlugin, struct PluginPanelItem *PanelItem,
  int ItemsNumber, int OpMode)
{
  if(LS) return LF_ProcessHostFileW(LS, hPlugin, PanelItem, ItemsNumber, OpMode);
  return FALSE;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_PROCESSKEYW
int LUAPLUG ProcessKeyW(HANDLE hPlugin, int Key, unsigned int ControlState)
{
  if(LS) return LF_ProcessKeyW(LS, hPlugin, Key, ControlState);
  return FALSE;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_PUTFILESW
int LUAPLUG PutFilesW(HANDLE hPlugin, struct PluginPanelItem *PanelItem,
  int ItemsNumber, int Move, const wchar_t *SrcPath, int OpMode)
{
  if(LS) return LF_PutFilesW(LS, hPlugin, PanelItem, ItemsNumber, Move, OpMode);
  return 0;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_SETDIRECTORYW
int LUAPLUG SetDirectoryW(HANDLE hPlugin, const wchar_t *Dir, int OpMode)
{
  if(LS) return LF_SetDirectoryW(LS, hPlugin, Dir, OpMode);
  return FALSE;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_SETFINDLISTW
int LUAPLUG SetFindListW(HANDLE hPlugin, const struct PluginPanelItem *PanelItem,
  int ItemsNumber)
{
  if(LS) return LF_SetFindListW(LS, hPlugin, PanelItem, ItemsNumber);
  return FALSE;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_GETMINFARVERSIONW
int LUAPLUG GetMinFarVersionW (void)
{
  return MINFARVERSION;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_PROCESSEDITORINPUTW
int LUAPLUG ProcessEditorInputW(const INPUT_RECORD *Rec)
{
  if(LS) return LF_ProcessEditorInputW(LS, Rec);
  return 0;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_PROCESSEDITOREVENTW
int LUAPLUG ProcessEditorEventW(int Event, void *Param)
{
  if(LS) return LF_ProcessEditorEventW(LS, Event, Param);
  return 0;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_PROCESSVIEWEREVENTW
int LUAPLUG ProcessViewerEventW(int Event, void *Param)
{
  if(LS) return LF_ProcessViewerEventW(LS, Event, Param);
  return 0;
}
#endif
//---------------------------------------------------------------------------

//exported unconditionally to enable far.Timer's work
int LUAPLUG ProcessSynchroEventW(int Event, void *Param)
{
  if(LS) return LF_ProcessSynchroEventW(LS, Event, Param);
  return 0;
}
//---------------------------------------------------------------------------

#ifdef EXPORT_PROCESSDIALOGEVENTW
int LUAPLUG ProcessDialogEventW(int Event, void *Param)
{
  if(LS) return LF_ProcessDialogEventW(LS, Event, Param);
  return 0;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_GETCUSTOMDATAW
int LUAPLUG GetCustomDataW(const wchar_t *FilePath, wchar_t **CustomData)
{
  if(LS) return LF_GetCustomDataW(LS, FilePath, CustomData);
  return 0;
}

void LUAPLUG FreeCustomDataW(wchar_t *CustomData)
{
  if(LS) LF_FreeCustomDataW(LS, CustomData);
}
#endif
//---------------------------------------------------------------------------

