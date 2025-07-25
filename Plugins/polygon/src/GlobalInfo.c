#include <farplug-wide.h>

SHAREDSYMBOL void WINAPI GetGlobalInfoW(struct GlobalInfo *aInfo)
{
  struct VersionInfo Version = { 1,9,0,0 };
  aInfo->StructSize    = sizeof(*aInfo);
  aInfo->SysID         = 0xD4BC5EA7;
  aInfo->Version       = Version;
  aInfo->Title         = L"Polygon";
  aInfo->Description   = L"Plugin for viewing and editing SQLite3 database files";
  aInfo->Author        = L"Artem Senichev, Shmuel Zeigerman";
  aInfo->UseMenuGuids  = 1;
}
//---------------------------------------------------------------------------

SHAREDSYMBOL int WINAPI GetMinFarVersionW(void)
{
  return MAKEFARVERSION(2,4);
}
//---------------------------------------------------------------------------
