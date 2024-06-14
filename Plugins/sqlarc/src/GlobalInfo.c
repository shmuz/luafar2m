#include <farplug-wide.h>

SHAREDSYMBOL void WINAPI GetGlobalInfoW(struct GlobalInfo *aInfo)
{
  struct VersionInfo Version = { 0,1,0,0 };
  aInfo->StructSize    = sizeof(*aInfo);
  aInfo->SysID         = 0xF309DDDB;
  aInfo->Version       = Version;
  aInfo->Title         = L"Sqlarc";
  aInfo->Description   = L"Sqlarc, plugin for Far Manager";
  aInfo->Author        = L"Shmuel Zeigerman";
}
//---------------------------------------------------------------------------

SHAREDSYMBOL int WINAPI GetMinFarVersionW(void)
{
  return MAKEFARVERSION(2,4);
}
//---------------------------------------------------------------------------
