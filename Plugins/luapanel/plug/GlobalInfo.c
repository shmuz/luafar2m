#include <farplug-wide.h>

SHAREDSYMBOL void WINAPI EXP_NAME(GetGlobalInfo)(struct GlobalInfo *aInfo)
{
  struct VersionInfo Version = { 0,2,0,0 };
  aInfo->StructSize    = sizeof(*aInfo);
  aInfo->SysID         = 0x50F187DF;
  aInfo->Version       = Version;
  aInfo->Title         = L"Lua Panel";
  aInfo->Description   = L"Panel-mode Lua-state browser";
  aInfo->Author        = L"Shmuel Zeigerman";
}
