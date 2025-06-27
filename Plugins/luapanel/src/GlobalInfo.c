#include <farplug-wide.h>

SHAREDSYMBOL void WINAPI GetGlobalInfoW(struct GlobalInfo *aInfo)
{
  struct VersionInfo Version = { 0,2,0,0 };
  aInfo->StructSize    = sizeof(*aInfo);
  aInfo->SysID         = 0x50F187DF;
  aInfo->Version       = Version;
  aInfo->Title         = L"Lua Panel";
  aInfo->Description   = L"Panel-mode Lua-state browser";
  aInfo->Author        = L"Shmuel Zeigerman";
  aInfo->UseMenuGuids  = 0;
}
//---------------------------------------------------------------------------

SHAREDSYMBOL int WINAPI GetMinFarVersionW(void)
{
  return MAKEFARVERSION(2,4);
}
//---------------------------------------------------------------------------
