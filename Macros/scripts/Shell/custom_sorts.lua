do return end
if not (bit and jit and Panel.LoadCustomSortMode) then return end

local ffi=require'ffi'
local C=ffi.C
local band,bor = bit.band,bit.bor
local tonumber = tonumber
local CompareStringFlags = bor(C.NORM_IGNORECASE, C.SORT_STRINGSORT)
local FILE_ATTRIBUTE_DIRECTORY = 0x0010
local DOT, BS = string.byte("."), string.byte("\\")
local F = far.Flags

--------------------------------------------------------------------------------
-- Helper functions.
--------------------------------------------------------------------------------

ffi.cdef[[
wchar_t* wcschr(const wchar_t*, wchar_t);
wchar_t* wcsrchr(const wchar_t*, wchar_t);
__int64 _wtoi64(const wchar_t*);
]]

local function isDir (p)
  return 0 ~= band(tonumber(p.FileAttributes), FILE_ATTRIBUTE_DIRECTORY)
end

local function cmpName (name1, name2)
  return -2 + C.WINPORT_CompareString(C.LOCALE_USER_DEFAULT, CompareStringFlags, name1, -1, name2, -1)
end

local function getName (fullname)
  local bs = C.wcsrchr(fullname,BS)
  return bs ~= nil and bs+1 or fullname
end

local function getExt (name)
  local ext = C.wcsrchr(name,DOT)
  if ext ~= nil then
    local bs = C.wcschr(ext,BS)
    if bs~=nil then ext=nil end
  end
  return ext
end

local function cmpTime (ft1, ft2)
  return
    ft1.dwHighDateTime < ft2.dwHighDateTime and -1 or
    ft1.dwHighDateTime > ft2.dwHighDateTime and  1 or
    ft1.dwLowDateTime  < ft2.dwLowDateTime  and -1 or
    ft1.dwLowDateTime  > ft2.dwLowDateTime  and  1 or 0
end

local function cmpSize (s1, s2)
  return s1<s2 and -1 or s1>s2 and 1 or 0
end

local function CompareByName(p1,p2,opt)
  local ext1, ext2 = getExt(p1.FileName), getExt(p2.FileName)
  local len1 = ext1~=nil and ext1-p1.FileName or -1
  local len2 = ext2~=nil and ext2-p2.FileName or -1
  return -2 + C.WINPORT_CompareString(C.LOCALE_USER_DEFAULT, CompareStringFlags, p1.FileName, len1, p2.FileName, len2)
end

--------------------------------------------------------------------------------
-- Custom sort modes.
-------------------------------------------------------------------------------
local SortModes = {
  Name      = { mode=1; Indicator="иИ";  InvertByDefault=nil;  key="CtrlShiftF3";
                Description="Sort by name";
                Compare = CompareByName; };

  Extension = { mode=2; Indicator="рР";  InvertByDefault=nil;  key="CtrlShiftF4";
                Description="Sort by extension" };

  WrTime    = { mode=3; Indicator="зЗ";  InvertByDefault=true; key="CtrlShiftF5";
                Description="Sort by write time";
                Compare = function(p1,p2,opt) return cmpTime(p1.LastWriteTime, p2.LastWriteTime) end };

  Size      = { mode=4; Indicator="аА";  InvertByDefault=true; key="CtrlShiftF6";
                Description="Sort by size";
                Compare = function(p1,p2,opt) return cmpSize(p1.FileSize, p2.FileSize) end };

  Unsorted  = { mode=5; Indicator="нН";  InvertByDefault=nil;  key="CtrlShiftF7";
                Description="Sort Unsorted";
                Compare = function(p1,p2,opt) return p1.Position - p2.Position end };

  CrTime    = { mode=6; Indicator="сС";  InvertByDefault=true; key="CtrlShiftF8";
                Description="Sort by creation time";
                Compare = function(p1,p2,opt) return cmpTime(p1.CreationTime, p2.CreationTime) end };

  AccTime   = { mode=7; Indicator="дД";  InvertByDefault=true; key="CtrlShiftF9";
                Description="Sort by access time";
                Compare = function(p1,p2,opt) return cmpTime(p1.LastAccessTime, p2.LastAccessTime) end };

  Descript  = { mode=8; Indicator="оО";  InvertByDefault=nil;  key="CtrlShiftF10";
                Description="Sort by description";
                Compare=function(p1,p2,opt) return cmpName(p1.Description or "\0", p2.Description) or "\0" end; };

  Owner     = { mode=9; Indicator="вВ";  InvertByDefault=nil;  key="CtrlShiftF11";
                Description="Sort by owner";
                Compare = function(p1,p2,opt) return cmpName(p1.Owner or "\0", p2.Owner) or "\0" end; };

  ChTime    = { mode=10; Indicator="мМ";  InvertByDefault=true; key="CtrlAltF3";
                Description="Sort by change time";
                Compare = function(p1,p2,opt) return cmpTime(p1.ChangeTime, p2.ChangeTime) end };

  AllocSize = { mode=11; Indicator="/\\"; InvertByDefault=true; key="CtrlAltF3";
                Description="Sort by allocated size";
                Compare = function(p1,p2,opt) return cmpSize(p1.AllocationSize, p2.AllocationSize) end };

  NumLinks  = { mode=12; Indicator="лЛ";  InvertByDefault=true; key="CtrlAltF3";
                Description="Sort by number of hard links";
                Compare = function(p1,p2,opt) return p1.NumberOfLinks - p2.NumberOfLinks; end };

  FullName  = { mode=13; Indicator="/\\"; InvertByDefault=nil;  key="CtrlAltF3";
                Description="Sort by full name";
                Compare = function(p1,p2,opt) return cmpName(p1.FileName, p2.FileName) end };

  Mode26May = { mode=14; Indicator="@#";  InvertByDefault=nil;  key="CtrlAltF3";
                Description="Sort directories by name, files by write time" };
}

do
local FoldersByName
SortModes.Extension.InitSort =
  function(opt)
    FoldersByName = "false"==Far.Cfg_Get("Panel","SortFolderExt")
  end
SortModes.Extension.Compare =
  function (p1,p2,opt)
    if FoldersByName then
      if isDir(p1) then
        return isDir(p2) and cmpName(p1.FileName, p2.FileName) or -1
      end
      if isDir(p2) then return 1 end
    end
    local ext1, ext2 = getExt(p1.FileName), getExt(p2.FileName)
    return ext1==nil and (ext2==nil and 0 or -1) or ext2==nil and 1 or cmpName(ext1, ext2)
  end
end

SortModes.Mode26May.Compare =
  function(p1,p2,opt)
    if isDir(p1) and isDir(p2) then return cmpName(getName(p1.FileName),getName(p2.FileName)) end
    return cmpTime(p2.LastWriteTime, p1.LastWriteTime)
  end

local function LoadAll (SortModesTable)
  local SM_USER = F.SM_USER or 1e5
  local arr = {}
  for k,v in pairs(SortModesTable) do
    table.insert(arr,v)
  end
  table.sort(arr, function(a,b) return a.mode < b.mode end)
  for _,v in ipairs(arr) do
    local mode = SM_USER + v.mode
    Panel.LoadCustomSortMode(mode, v)
    Macro {
      area="Shell"; key=v.key; description=v.Description;
      action=function() Panel.SetCustomSortMode(mode) end;
    }
  end
end

LoadAll(SortModes)
