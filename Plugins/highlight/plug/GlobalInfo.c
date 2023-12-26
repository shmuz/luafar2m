#include <farplug-wide.h>

SHAREDSYMBOL void WINAPI EXP_NAME(GetGlobalInfo)(struct GlobalInfo *aInfo)
{
  struct VersionInfo Version = { 0,6,0,0 };
  aInfo->StructSize    = sizeof(*aInfo);
  aInfo->SysID         = 0xF6138DC9;
  aInfo->Version       = Version;
  aInfo->Title         = L"Highlight";
  aInfo->Description   = L"Syntax highlighter for editor";
  aInfo->Author        = L"Shmuel Zeigerman";
}
