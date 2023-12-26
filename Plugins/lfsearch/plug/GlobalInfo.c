#include <farplug-wide.h>

SHAREDSYMBOL void WINAPI EXP_NAME(GetGlobalInfo)(struct GlobalInfo *aInfo)
{
  struct VersionInfo Version = { 3,45,5,0 };
  aInfo->StructSize    = sizeof(*aInfo);
  aInfo->SysID         = 0x8E11EA75;
  aInfo->Version       = Version;
  aInfo->Title         = L"LuaFAR Search";
  aInfo->Description   = L"Plugin for search and replace";
  aInfo->Author        = L"Shmuel Zeigerman";
}
