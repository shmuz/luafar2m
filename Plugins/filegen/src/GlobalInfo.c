#include <farplug-wide.h>

SHAREDSYMBOL void WINAPI GetGlobalInfoW(struct GlobalInfo *aInfo)
{
  struct VersionInfo Version = { 0,0,0,1 };
  aInfo->StructSize    = sizeof(*aInfo);
  aInfo->SysID         = 0x907CBCBA;
  aInfo->Version       = Version;
  aInfo->Title         = L"Pseudo file generator";
  aInfo->Description   = L"Pseudo file generator";
  aInfo->Author        = L"Shmuel Zeigerman";
}
//---------------------------------------------------------------------------

SHAREDSYMBOL int WINAPI GetMinFarVersionW(void)
{
  return MAKEFARVERSION(2,4);
}
//---------------------------------------------------------------------------
