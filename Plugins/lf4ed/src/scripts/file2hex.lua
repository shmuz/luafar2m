-- Goal     : Convert file contents to HEX
-- Started  : 2018-08-19 (by Shmuel Zeigerman)
-- Tested   : x86; x64; unicode file names;
-- See also : 0003638: LuaFAR: проверить имплементацию file:rawhandle (https://bugs.farmanager.com/view.php?id=3638)

if not jit then return end -- LuaJIT required

-- Begin settings
---- local Shortcut = "CtrlShiftF2"
-- End settings

local ffi=require 'ffi'
local C=ffi.C
ffi.cdef[[
  typedef struct { int a; } FILE;
  size_t fread(void*,size_t,size_t,FILE*);
  size_t fwrite(const void*,size_t,size_t,FILE*);
  FILE* fopen(const char*, const char*);
  int fclose(FILE*);
]]

local F = far.Flags
local band, rshift = bit64.band, bit64.rshift

local function ShowProgress(Title, Size)
  if Size then
    if win.ExtractKey()=="ESCAPE" and 1==far.Message("Break the operation?",Title,"&Yes;&No","w") then
      return true
    end
    far.Message(math.floor(Size/0x100000).." MB", Title, "")
  else
    far.Message("Working, please wait...", Title, "")
    far.AdvControl("ACTL_REDRAWALL")
  end
end

--  description="Convert file contents to HEX";
--  area="Shell"; key=Shortcut;
--  flags="NoPluginPanels NoFolders";
local function File2Hex()
  local info = panel.GetPanelInfo(nil, 1)
  if band(info.Flags, F.PFLAGS_PLUGIN) ~= 0 then return end

  local item = panel.GetCurrentPanelItem(nil, 1)
  if item.FileAttributes:find("d") then return end

  local Title = "Convert file contents to HEX";
  local dir = panel.GetPanelDirectory(nil, 1)
  local name_in = dir.."/"..item.FileName
  local name_out = name_in..".hex"
  local f_in =assert(C.fopen(name_in, "rb"))
  local f_out=assert(C.fopen(name_out, "wb"))
  local ibufsize = 0x10000
  local ibuf=ffi.new("unsigned char[?]", ibufsize)
  local obuf=ffi.new("unsigned char[?]", 2*ibufsize)
  for cnt=0,math.huge do
    if ShowProgress(Title, cnt*ibufsize) then
      break
    end
    local n = C.fread(ibuf, 1, ibufsize, f_in)
    if n == 0 then break end
    for i=0,tonumber(n-1) do
      local low = band(ibuf[i],0xf)
      local high = rshift(ibuf[i],4)
      obuf[i+i]   = high<10 and high+48 or high+55
      obuf[i+i+1] = low<10  and low+48  or low+55
    end
    C.fwrite(obuf, 1, n+n, f_out)
  end
  C.fclose(f_out)
  C.fclose(f_in)
  panel.UpdatePanel(nil, 1)
  far.AdvControl("ACTL_REDRAWALL")
end

AddCommand("file2hex", File2Hex)
