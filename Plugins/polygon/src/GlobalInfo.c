#include <farplug-wide.h>

SHAREDSYMBOL void WINAPI GetGlobalInfoW(struct GlobalInfo *aInfo)
{
  aInfo->StructSize    = sizeof(*aInfo);
  aInfo->MinFarVersion = MAKEFARVERSION2(2,9,0,0);
  aInfo->Version       = MAKEFARVERSION2(1,9,0,0);
  aInfo->SysID         = 0xD4BC5EA7;
  aInfo->Title         = L"Polygon";
  aInfo->Description   = L"Plugin for viewing and editing SQLite3 database files";
  aInfo->Author        = L"Artem Senichev, Shmuel Zeigerman";
  aInfo->UseMenuGuids  = 1;
}
