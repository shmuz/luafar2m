#include <farplug-wide.h>

SHAREDSYMBOL void WINAPI GetGlobalInfoW(struct GlobalInfo *aInfo)
{
  struct VersionInfo Version = { 0,11,0,0 };
  aInfo->StructSize    = sizeof(*aInfo);
  aInfo->SysID         = 0x50B1ABE5;
  aInfo->Version       = Version;
  aInfo->Title         = L"Macro2Lua converter";
  aInfo->Description   = L"Converter from macro language to Lua";
  aInfo->Author        = L"Shmuel Zeigerman";
  aInfo->UseMenuGuids  = 1;
}
//---------------------------------------------------------------------------

SHAREDSYMBOL int WINAPI GetMinFarVersionW(void)
{
  return MAKEFARVERSION(2,4);
}
//---------------------------------------------------------------------------
