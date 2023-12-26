#include <farplug-wide.h>

SHAREDSYMBOL void WINAPI EXP_NAME(GetGlobalInfo)(struct GlobalInfo *aInfo)
{
  struct VersionInfo Version = { 3,12,2,0 };
  aInfo->StructSize    = sizeof(*aInfo);
  aInfo->SysID         = 0xA745761D;
  aInfo->Version       = Version;
  aInfo->Title         = L"LuaFAR History";
  aInfo->Description   = L"History of commands, files and folders";
  aInfo->Author        = L"Shmuel Zeigerman";
}

