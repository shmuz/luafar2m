#include "reg.h"

HKEY CreateRegKey(HKEY hRoot, wchar_t *RootKey, wchar_t *Key);
HKEY OpenRegKey(HKEY hRoot, wchar_t *RootKey, wchar_t *Key);

void SetRegKeyStr(HKEY hRoot, wchar_t *RootKey, wchar_t *Key, wchar_t *ValueName, wchar_t *ValueData)
{
  HKEY hKey=CreateRegKey(hRoot, RootKey, Key);
  WINPORT(RegSetValueEx)(hKey, ValueName, 0, REG_SZ, (BYTE*)ValueData,
                 sizeof(wchar_t) * (wcslen(ValueData) + 1));
  WINPORT(RegCloseKey)(hKey);
}


void SetRegKeyDword(HKEY hRoot, wchar_t *RootKey, wchar_t *Key, wchar_t *ValueName, DWORD ValueData)
{
  HKEY hKey=CreateRegKey(hRoot, RootKey, Key);
  WINPORT(RegSetValueEx)(hKey, ValueName, 0, REG_DWORD, (BYTE *)&ValueData, sizeof(DWORD));
  WINPORT(RegCloseKey)(hKey);
}


void SetRegKeyArr(HKEY hRoot, wchar_t *RootKey, wchar_t *Key, wchar_t *ValueName, BYTE *ValueData, DWORD ValueSize)
{
  HKEY hKey=CreateRegKey(hRoot, RootKey, Key);
  WINPORT(RegSetValueEx)(hKey, ValueName, 0, REG_BINARY, ValueData, ValueSize);
  WINPORT(RegCloseKey)(hKey);
}


int GetRegKeyStr(HKEY hRoot, wchar_t *RootKey, wchar_t *Key, wchar_t *ValueName, wchar_t *ValueData, wchar_t *Default, DWORD DataSize)
{
  HKEY hKey=OpenRegKey(hRoot, RootKey, Key);
  DWORD Type;
  int ExitCode=WINPORT(RegQueryValueEx)(hKey, ValueName, 0, &Type, (BYTE*)ValueData, &DataSize);
  WINPORT(RegCloseKey)(hKey);
  if (hKey==NULL || ExitCode!=ERROR_SUCCESS)
  {
    wcscpy(ValueData, Default);
    return(FALSE);
  }
  return(TRUE);
}


int GetRegKeyInt(HKEY hRoot, wchar_t *RootKey, wchar_t *Key, wchar_t *ValueName, int *ValueData, DWORD Default)
{
  HKEY hKey=OpenRegKey(hRoot, RootKey, Key);
  DWORD Type, Size=sizeof(ValueData);
  int ExitCode=WINPORT(RegQueryValueEx)(hKey, ValueName, 0, &Type, (BYTE *)ValueData, &Size);
  WINPORT(RegCloseKey)(hKey);
  if (hKey==NULL || ExitCode!=ERROR_SUCCESS)
  {
    *ValueData=Default;
    return(FALSE);
  }
  return(TRUE);
}


int GetRegKeyDword(HKEY hRoot, wchar_t *RootKey, wchar_t *Key, wchar_t *ValueName, DWORD Default)
{
  int ValueData;
  GetRegKeyInt(hRoot, RootKey, Key, ValueName, &ValueData, Default);
  return(ValueData);
}


int GetRegKeyArr(HKEY hRoot, wchar_t *RootKey, wchar_t *Key, wchar_t *ValueName, BYTE *ValueData, BYTE *Default, DWORD DataSize)
{
  HKEY hKey=OpenRegKey(hRoot, RootKey, Key);
  DWORD Type;
  int ExitCode=WINPORT(RegQueryValueEx)(hKey, ValueName, 0, &Type, ValueData, &DataSize);
  WINPORT(RegCloseKey)(hKey);
  if (hKey==NULL || ExitCode!=ERROR_SUCCESS)
  {
    if (Default!=NULL)
      memcpy(ValueData, Default, DataSize);
    else
      memset(ValueData, 0, DataSize);
    return(FALSE);
  }
  return(TRUE);
}


void DeleteRegKey(HKEY hRoot, wchar_t *RootKey, wchar_t *Key)
{
  wchar_t FullKeyName[512];
  wcscpy(FullKeyName, RootKey);
  if (*Key) {
    wcscat(FullKeyName, L"\\");
    wcscat(FullKeyName, Key);
  }
  WINPORT(RegDeleteKey)(hRoot, FullKeyName);
}


HKEY CreateRegKey(HKEY hRoot, wchar_t *RootKey, wchar_t *Key)
{
  HKEY hKey;
  DWORD Disposition;
  wchar_t FullKeyName[512];
  wcscpy(FullKeyName, RootKey);
  if (*Key) {
    wcscat(FullKeyName, L"\\");
    wcscat(FullKeyName, Key);
  }
  WINPORT(RegCreateKeyEx)(hRoot, FullKeyName, 0, NULL, 0, KEY_WRITE, NULL,
                  &hKey, &Disposition);
  return(hKey);
}


HKEY OpenRegKey(HKEY hRoot, wchar_t *RootKey, wchar_t *Key)
{
  HKEY hKey;
  wchar_t FullKeyName[512];
  wcscpy(FullKeyName, RootKey);
  if (*Key) {
    wcscat(FullKeyName, L"\\");
    wcscat(FullKeyName, Key);
  }
  if (WINPORT(RegOpenKeyEx)(hRoot, FullKeyName, 0, KEY_QUERY_VALUE, &hKey)!=ERROR_SUCCESS)
    return(NULL);
  return(hKey);
}

