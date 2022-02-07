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

PSInfo Info;
struct FarStandardFunctions FSF;
lua_State* LS;
TPluginData PluginData;
//---------------------------------------------------------------------------

// This function must have __cdecl calling convention, it is not `LUAPLUG'.
int _export luaopen_luaplug (lua_State *L)
{
  LF_InitLuaState(L, &Info, FUNC_OPENLIBS, ENV_PREFIX);
  return 0;
}
//---------------------------------------------------------------------------

static LONG_PTR WINAPI DlgProc(HANDLE hDlg, int Msg, int Param1, LONG_PTR Param2)
{
  return LF_DlgProc(LS, hDlg, Msg, Param1, Param2);
}

void LUAPLUG SetStartupInfoW(const PSInfo *aInfo)
{
  Info = *aInfo;
  FSF = *aInfo->FSF;
  Info.FSF = &FSF;
  PluginData.Info = &Info;
  PluginData.DlgProc = DlgProc;

  if (!LS && LF_LuaOpen(&PluginData, FUNC_OPENLIBS, ENV_PREFIX)) //includes opening "far" library
    LS = PluginData.MainLuaState;

  if (LS && !LF_RunDefaultScript(LS))  {
    LF_LuaClose(&PluginData);
    LS = NULL;
  }
}
//---------------------------------------------------------------------------

void LUAPLUG GetPluginInfoW(struct PluginInfo *Info)
{
  if(LS) LF_GetPluginInfo (LS, Info);
}
//---------------------------------------------------------------------------

#ifdef EXPORT_OPENPLUGIN
HANDLE LUAPLUG OpenPluginW(int OpenFrom, INT_PTR Item)
{
  return LS ? LF_OpenPlugin(LS, OpenFrom, Item) : INVALID_HANDLE_VALUE;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_OPENFILEPLUGIN
HANDLE LUAPLUG OpenFilePluginW(const wchar_t *Name, const unsigned char *Data,
  int DataSize, int OpMode)
{
  return LS ? LF_OpenFilePlugin(LS, OpenFrom, Item) : INVALID_HANDLE_VALUE;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_GETFINDDATA
int LUAPLUG GetFindDataW(HANDLE hPlugin, struct PluginPanelItem **pPanelItem,
                        int *pItemsNumber, int OpMode)
{
  return LS ? LF_GetFindData(LS, hPlugin, pPanelItem, pItemsNumber, OpMode) : FALSE;
}
//---------------------------------------------------------------------------

void LUAPLUG FreeFindDataW(HANDLE hPlugin, struct PluginPanelItem *PanelItem,
                         int ItemsNumber)
{
  if(LS) LF_FreeFindData(LS, hPlugin, PanelItem, ItemsNumber);
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_CLOSEPLUGIN
void LUAPLUG ClosePluginW(HANDLE hPlugin)
{
  if(LS) LF_ClosePlugin(LS, hPlugin);
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_GETFILES
int LUAPLUG GetFilesW(HANDLE hPlugin, struct PluginPanelItem *PanelItem,
  int ItemsNumber, int Move, const wchar_t **DestPath, int OpMode)
{
  return LS ? LF_GetFiles(LS,hPlugin,PanelItem,ItemsNumber,Move,DestPath,OpMode) : 0;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_GETOPENPLUGININFO
void LUAPLUG GetOpenPluginInfoW(HANDLE hPlugin, struct OpenPluginInfo *Info)
{
  if(LS) LF_GetOpenPluginInfo(LS, hPlugin, Info);
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_EXITFAR
void LUAPLUG ExitFARW()
{
  if(LS) {
    LF_ExitFAR(LS);
    LF_LuaClose(&PluginData);
    LS = NULL;
  }
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_MAYEXITFAR
int LUAPLUG MayExitFARW()
{
  return LS ? LF_MayExitFAR(LS) : 1;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_COMPARE
int LUAPLUG CompareW(HANDLE hPlugin, const struct PluginPanelItem *Item1,
                    const struct PluginPanelItem *Item2, unsigned int Mode)
{
  return LS ? LF_Compare(LS, hPlugin, Item1, Item2, Mode) : 0;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_CONFIGURE
int LUAPLUG ConfigureW(int ItemNumber)
{
  return LS ? LF_Configure(LS, ItemNumber) : FALSE;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_DELETEFILES
int LUAPLUG DeleteFilesW(HANDLE hPlugin, struct PluginPanelItem *PanelItem,
  int ItemsNumber, int OpMode)
{
  return LS ? LF_DeleteFiles(LS, hPlugin, PanelItem, ItemsNumber, OpMode) : FALSE;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_GETVIRTUALFINDDATA
int LUAPLUG GetVirtualFindDataW(HANDLE hPlugin,
  struct PluginPanelItem **pPanelItem, int *pItemsNumber, const wchar_t *Path)
{
  if(LS) return LF_GetVirtualFindData(LS,hPlugin,pPanelItem,pItemsNumber,Path);
  return FALSE;
}

void LUAPLUG FreeVirtualFindDataW(HANDLE hPlugin,
  struct PluginPanelItem *PanelItem, int ItemsNumber)
{
  if(LS) LF_FreeVirtualFindData(LS, hPlugin, PanelItem, ItemsNumber);
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_MAKEDIRECTORY
int LUAPLUG MakeDirectoryW(HANDLE hPlugin, const wchar_t **Name, int OpMode)
{
  return LS ? LF_MakeDirectory(LS, hPlugin, Name, OpMode) : 0;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_PROCESSEVENT
int LUAPLUG ProcessEventW(HANDLE hPlugin, int Event, void *Param)
{
  return LS ? LF_ProcessEvent(LS, hPlugin, Event, Param) : FALSE;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_PROCESSHOSTFILE
int LUAPLUG ProcessHostFileW(HANDLE hPlugin, struct PluginPanelItem *PanelItem,
  int ItemsNumber, int OpMode)
{
  return LS ? LF_ProcessHostFile(LS, hPlugin, PanelItem, ItemsNumber, OpMode) : FALSE;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_PROCESSKEY
int LUAPLUG ProcessKeyW(HANDLE hPlugin, int Key, unsigned int ControlState)
{
  return LS ? LF_ProcessKey(LS, hPlugin, Key, ControlState) : FALSE;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_PUTFILES
int LUAPLUG PutFilesW(HANDLE hPlugin, struct PluginPanelItem *PanelItem,
  int ItemsNumber, int Move, const wchar_t *SrcPath, int OpMode)
{
  return LS ? LF_PutFiles(LS, hPlugin, PanelItem, ItemsNumber, Move, OpMode) : 0;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_SETDIRECTORY
int LUAPLUG SetDirectoryW(HANDLE hPlugin, const wchar_t *Dir, int OpMode)
{
  return LS ? LF_SetDirectory(LS, hPlugin, Dir, OpMode) : FALSE;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_SETFINDLIST
int LUAPLUG SetFindListW(HANDLE hPlugin, const struct PluginPanelItem *PanelItem, int ItemsNumber)
{
  return LS ? LF_SetFindList(LS, hPlugin, PanelItem, ItemsNumber) : FALSE;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_GETMINFARVERSION
int LUAPLUG GetMinFarVersionW (void)
{
  return MINFARVERSION;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_PROCESSEDITORINPUT
int LUAPLUG ProcessEditorInputW(const INPUT_RECORD *Rec)
{
  return LS ? LF_ProcessEditorInput(LS, Rec) : 0;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_PROCESSEDITOREVENT
int LUAPLUG ProcessEditorEventW(int Event, void *Param)
{
  return LS ? LF_ProcessEditorEvent(LS, Event, Param) : 0;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_PROCESSVIEWEREVENT
int LUAPLUG ProcessViewerEventW(int Event, void *Param)
{
  return LS ? LF_ProcessViewerEvent(LS, Event, Param) : 0;
}
#endif
//---------------------------------------------------------------------------

//exported unconditionally to enable far.Timer's work
int LUAPLUG ProcessSynchroEventW(int Event, void *Param)
{
  return LS ? LF_ProcessSynchroEvent(LS, Event, Param) : 0;
}
//---------------------------------------------------------------------------

#ifdef EXPORT_PROCESSDIALOGEVENT
int LUAPLUG ProcessDialogEventW(int Event, void *Param)
{
  return LS ? LF_ProcessDialogEvent(LS, Event, Param) : 0;
}
#endif
//---------------------------------------------------------------------------

#ifdef EXPORT_GETCUSTOMDATA
int LUAPLUG GetCustomDataW(const wchar_t *FilePath, wchar_t **CustomData)
{
  return LS ? LF_GetCustomData(LS, FilePath, CustomData) : 0;
}

void LUAPLUG FreeCustomDataW(wchar_t *CustomData)
{
  if(LS) LF_FreeCustomData(LS, CustomData);
}
#endif
//---------------------------------------------------------------------------
