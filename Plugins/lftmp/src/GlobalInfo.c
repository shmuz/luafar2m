#include <farplug-wide.h>

SHAREDSYMBOL void WINAPI GetGlobalInfoW(struct GlobalInfo *aInfo)
{
  aInfo->StructSize    = sizeof(*aInfo);
  aInfo->MinFarVersion = MAKEFARVERSION2(2,9,0,0);
  aInfo->Version       = MAKEFARVERSION2(3,1,2,0);
  aInfo->SysID         = 0xE2500D1C;
  aInfo->Title         = L"LuaFAR Temp. Panel";
  aInfo->Description   = L"A Lua clone of TmpPanel plugin";
  aInfo->Author        = L"Far Group, Shmuel Zeigerman";
  aInfo->UseMenuGuids  = 1;
}
