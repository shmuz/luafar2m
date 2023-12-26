#include <farplug-wide.h>

SHAREDSYMBOL void WINAPI EXP_NAME(GetGlobalInfo)(struct GlobalInfo *aInfo)
{
  struct VersionInfo Version = { 3,9,3,0 };
  aInfo->StructSize    = sizeof(*aInfo);
  aInfo->SysID         = 0x6F332978;
  aInfo->Version       = Version;
  aInfo->Title         = L"LuaFAR for Editor";
  aInfo->Description   = L"A host for scripts and script packets";
  aInfo->Author        = L"Shmuel Zeigerman";
}
