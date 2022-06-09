-- Started: 2016-03-18

if not jit  then return end -- LuaJIT required

local ffi = require "ffi"
local C, F = ffi.C, far.Flags

-- <settings> --
local SortMode = (F.SM_USER or 1e5) + 500
local DialogId = "770027D6-F00B-40C3-8EF4-6BE836280B22"
local DBKey, DBName = "shmuz", "sort_by_regex"
-- </settings> --

local Info = ffi.cast("const struct PluginStartupInfo*", far.CPluginStartupInfo())
local RegExpControl = Info.RegExpControl

-- struct RegExpMatch
-- {
--   int start;
--   int end;
-- };

-- struct RegExpSearch
-- {
--   const wchar_t *Text;
--   int Position;
--   int Length;
--   struct RegExpMatch *Match;
--   int Count;
--   void *Reserved;
-- };

local function CreateRS()
  local RS = ffi.new("struct RegExpSearch")
  local rsm = ffi.new("struct RegExpMatch[1]")
  RS.Match = rsm
  RS.Position = 0
  RS.Count = 1
  return RS, rsm
end

local Handle
local RS1, rsm1 = CreateRS()
local RS2, rsm2 = CreateRS()

local function GetRegex(sSearchPat, bCaseSens)
  local tmpHandle = ffi.new("HANDLE[1]")
  if 0 ~= RegExpControl(nil, F.RECTL_CREATE, ffi.cast("LONG_PTR", tmpHandle)) then
    ffi.gc(tmpHandle, function(h) RegExpControl(h[0], F.RECTL_FREE, 0) end)
    sSearchPat = "/"..sSearchPat.."/"
    if not bCaseSens then sSearchPat = sSearchPat.."i"; end
    local Pat16 = win.Utf8ToUtf16(sSearchPat) .. "\0\0\0"
    if 0 ~= RegExpControl(tmpHandle[0], F.RECTL_COMPILE, ffi.cast("LONG_PTR",Pat16)) then
      return tmpHandle
    end
  end
end

local function GetRegexFromDialog()
  local Items = {
    guid = DialogId;
    width = 73;
    {tp="dbox"; text="Sort by regular expression";         },
    {tp="text"; text="Re&gular expression:";               },
    {tp="edit"; hist="SortSearchText";  name="sSearchPat"; },
    {tp="chbox"; text="&Case sensitive"; name="bCaseSens"; },
    {tp="sep";                                             },
    {tp="butt"; text="OK",     centergroup=1, default=1;   },
    {tp="butt"; text="Cancel", centergroup=1, cancel=1;    },
  }

  Items.closeaction = function(hDlg, Param1, tOut)
    local tmpHandle = GetRegex(tOut.sSearchPat, tOut.bCaseSens)
    if tmpHandle then
      Handle = tmpHandle
      mf.msave(DBKey, DBName, {sSearchPat=tOut.sSearchPat; bCaseSens=tOut.bCaseSens})
    else
      far.Message("Invalid regex", "Error", nil, "w")
      return 0 -- do not close dialog
    end
  end

  local sDialog = require("far2.simpledialog")
  local _, Elem = sDialog.Indexes(Items)
  local data = mf.mload(DBKey, DBName)
  if data then
    Elem.sSearchPat.val = data.sSearchPat
    Elem.bCaseSens.val = data.bCaseSens
  end
  return sDialog.Run(Items) and true
end

local data = mf.mload(DBKey, DBName) or {}
Handle = GetRegex(data.sSearchPat or "", data.bCaseSens)

Panel.LoadCustomSortMode (SortMode, {
  Description = "&1. Sort by Regex";
  Indicator = "zZ";
  Condition = function() return Handle; end;
  Compare = function(p1,p2,opt)
    -- protect values from garbage collection (i.e. make them upvalues) --
    rsm1, rsm2 = rsm1, rsm2
    ----------------------------------------------------------------------
    RS1.Text, RS1.Length = p1.FileName, C.wcslen(p1.FileName)
    RS2.Text, RS2.Length = p2.FileName, C.wcslen(p2.FileName)

    local ret1 = RegExpControl(Handle[0], F.RECTL_SEARCHEX, ffi.cast("LONG_PTR", ffi.cast("void*", RS1)))
    local ret2 = RegExpControl(Handle[0], F.RECTL_SEARCHEX, ffi.cast("LONG_PTR", ffi.cast("void*", RS2)))
    if ret1 == ret2 and ret1 ~= 0 then
      return tonumber(RS1.Match[0].start - RS2.Match[0].start)
    else
      return tonumber(ret2 - ret1)
    end
  end;
})

Macro {
  description="Sort by Regex with dialog";
  area="Shell"; key="CtrlShiftX";
  action=function()
    if GetRegexFromDialog() then Panel.SetCustomSortMode(SortMode,0,"direct"); end
  end;
}

Macro {
  description="Sort by Last Regex";
  area="Shell"; key="CtrlX"; -- НУЖНО ЗАМЕНИТЬ ЭТОТ ШОРТКАТ, ИБО ПЕРЕКРЫВАЕТ ВЫЗОВ ИСТОРИИ КОМСТРОКИ
  action=function()
    Panel.SetCustomSortMode(SortMode,0,"auto")
  end;
}
