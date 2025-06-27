#include <farplug-wide.h>

SHAREDSYMBOL void WINAPI GetGlobalInfoW(struct GlobalInfo *aInfo)
{
  struct VersionInfo Version = { 0,6,0,0 };
  aInfo->StructSize    = sizeof(*aInfo);
  aInfo->SysID         = 0xF6138DC9;
  aInfo->Version       = Version;
  aInfo->Title         = L"Highlight";
  aInfo->Description   = L"Syntax highlighter for editor";
  aInfo->Author        = L"Shmuel Zeigerman";
  aInfo->UseMenuGuids  = 0;
}
//---------------------------------------------------------------------------

SHAREDSYMBOL int WINAPI GetMinFarVersionW(void)
{
  return MAKEFARVERSION(2,4);
}
//---------------------------------------------------------------------------
