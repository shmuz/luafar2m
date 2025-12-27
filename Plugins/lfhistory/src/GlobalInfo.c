#include <farplug-wide.h>

SHAREDSYMBOL void WINAPI GetGlobalInfoW(struct GlobalInfo *aInfo)
{
  struct VersionInfo Version = { 3,14,0,0 };
  aInfo->StructSize    = sizeof(*aInfo);
  aInfo->SysID         = 0xA745761D;
  aInfo->Version       = Version;
  aInfo->Title         = L"LuaFAR History";
  aInfo->Description   = L"History of commands, files and folders";
  aInfo->Author        = L"Shmuel Zeigerman";
  aInfo->UseMenuGuids  = 1;
}
//---------------------------------------------------------------------------

SHAREDSYMBOL int WINAPI GetMinFarVersionW(void)
{
  return MAKEFARVERSION(2,4);
}
//---------------------------------------------------------------------------
