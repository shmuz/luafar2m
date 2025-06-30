#include <farplug-wide.h>

SHAREDSYMBOL void WINAPI GetGlobalInfoW(struct GlobalInfo *aInfo)
{
  struct VersionInfo Version = { 3,1,2,0 };
  aInfo->StructSize    = sizeof(*aInfo);
  aInfo->SysID         = 0xE2500D1C;
  aInfo->Version       = Version;
  aInfo->Title         = L"LuaFAR Temp. Panel";
  aInfo->Description   = L"A Lua clone of TmpPanel plugin";
  aInfo->Author        = L"Far Group, Shmuel Zeigerman";
  aInfo->UseMenuGuids  = 1;
}
//---------------------------------------------------------------------------

SHAREDSYMBOL int WINAPI GetMinFarVersionW(void)
{
  return MAKEFARVERSION(2,4);
}
//---------------------------------------------------------------------------
