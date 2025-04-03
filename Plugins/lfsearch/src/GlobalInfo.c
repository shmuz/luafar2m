#include <farplug-wide.h>

SHAREDSYMBOL void WINAPI GetGlobalInfoW(struct GlobalInfo *aInfo)
{
  struct VersionInfo Version = { 3,48,1,0 };
  aInfo->StructSize    = sizeof(*aInfo);
  aInfo->SysID         = 0x8E11EA75;
  aInfo->Version       = Version;
  aInfo->Title         = L"LuaFAR Search";
  aInfo->Description   = L"Plugin for search and replace";
  aInfo->Author        = L"Shmuel Zeigerman";
}
//---------------------------------------------------------------------------

SHAREDSYMBOL int WINAPI GetMinFarVersionW(void)
{
  return MAKEFARVERSION(2,4);
}
//---------------------------------------------------------------------------
