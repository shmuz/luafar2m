#include <farplug-wide.h>

SHAREDSYMBOL void WINAPI EXP_NAME(GetGlobalInfo)(struct GlobalInfo *aInfo)
{
  struct VersionInfo Version = { 1,8,2,0 };
  aInfo->StructSize    = sizeof(*aInfo);
  aInfo->SysID         = 0xD4BC5EA7;
  aInfo->Version       = Version;
  aInfo->Title         = L"Polygon";
  aInfo->Description   = L"Plugin for viewing and editing SQLite3 database files";
  aInfo->Author        = L"Artem Senichev, Shmuel Zeigerman";
}
