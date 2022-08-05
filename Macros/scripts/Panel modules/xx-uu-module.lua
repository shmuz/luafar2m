local F = far.Flags
local mod = {}

mod.Info = {
  Guid = win.Uuid("D03DCEC0-6048-41AA-8417-D60766D5A2E6"); -- mandatory field
  Version      = "0.1.0";
  Title        = "XX/UU extractor";
  Description  = "A module for extracting/viewing/running XX- and UU-encoded files";
  Author       = "Shmuel Zeigerman";
  StartDate    = "2019-12-20";
  Dependencies = "Far2L (my fork); bin2text.so;";
  LinuxPortStartDate = "2022-08-05";
}

local function ExtractFileName(str)
  return string.match(str, "^begin[^%S\n]+%d+[^%S\n]+([^\n]+)")
end

local function FileToObject(HostFile)
  HostFile = far.ConvertPath(HostFile, "CPM_FULL")
  local fp = io.open(HostFile)
  if not fp then return end
  local ok, bin2text = pcall(require, "bin2text")
  if ok then
    local xx, uu = bin2text.xx, bin2text.uu
    local line = fp:read("*l") -- read the 1-st line
    local FileName = line and ExtractFileName(line)
    if FileName then
      line = fp:read("*l") -- read the 2-nd line
      local _, xxerr = xx.decode(line)
      local _, uuerr = uu.decode(line)
      local Lib = (xxerr==0) and xx or (uuerr==0) and uu
      local object = Lib and {
        HostFile = HostFile;
        FileName = FileName;
        Lib = Lib;
        Title = (Lib==xx) and "XX-encode" or "UU-encode";
      }
      fp:close()
      return object
    end
  end
  fp:close()
end

local function CreateArchive()
  local sd = require "far2.simpledialog"
  local fname = far.GetCurrentDirectory().."/FileName1"
  local Items = {
    {tp="dbox";  text="Create archive";                 },
    {tp="text";  text="&File name:";                    },
    {tp="edit";  name="filename"; text=fname;           },
    {tp="rbutt"; name="uu"; text="&UU-encode"; val=1;   },
    {tp="rbutt"; name="xx"; text="&XX-encode";          },
    {tp="sep";                                          },
    {tp="butt"; centergroup=1; default=1; text="OK";    },
    {tp="butt"; centergroup=1; cancel=1; text="Cancel"; },
  }
  local data = sd.Run(Items)
  if data and data.filename:find("%S") then
    local lib = require "bin2text"
    return data.uu and {
      HostFile=data.filename..".uue"; Lib=lib.uu; Title="UU-encode";
    }
    or {
      HostFile=data.filename..".xxe"; Lib=lib.xx; Title="XX-encode";
    }
  end
end

function mod.OpenFilePlugin (Name, Data, OpMode)
  if Name == nil then -- ShiftF1
    return -- CreateArchive()
  else
    local target = ExtractFileName(Data)
    if target then return FileToObject(Name) end
  end
end

function mod.OpenPlugin(OpenFrom, Data)
  if OpenFrom == F.OPEN_SHORTCUT then
    return FileToObject(Data)
  end
end

function mod.GetFindData(object, handle, OpMode)
  local host = win.GetFileInfo(object.HostFile)
  local ret = nil
  if host then
    if host.FileSize >= 10e6 then -- calculate approximate file size
      ret = { {FileName=object.FileName, FileSize=host.FileSize*3/4*60/62} }
    else -- calculate exact file size
      local fp = io.open(object.HostFile)
      if fp then
        local decode = object.Lib.decode
        local FileSize = 0
        fp:read("*l") -- skip the first line
        for line in fp:lines() do
          local chunk = decode(line)
          FileSize = FileSize + #chunk
          if chunk == "" then break end
        end
        fp:close()
        ret = { {FileName=object.FileName, FileSize=FileSize} }
      end
    end
  end
  if ret then object.FileSize=ret[1].FileSize; end
  return ret
end

function mod.GetOpenPluginInfo(object, handle)
  return {
    HostFile = object.HostFile;
    PanelTitle = object.Title;
    ShortcutData = "";
    StartSortMode = F.SM_UNSORTED;
    StartSortOrder = 0;
    --Flags = bit64.bor(F.OPIF_SHORTCUT, F.OPIF_ADDDOTS);
    Flags = F.OPIF_ADDDOTS
  }
end

function mod.GetFiles(object, handle, PanelItems, Move, DestPath, OpMode)
  local target = nil
  local fname = PanelItems[1].FileName

  if bit64.band(OpMode, F.OPM_SILENT) == 0 then -- confirmation needed
    target = far.InputBox("Extract", "Extract \""..fname.."\" to:",nil,DestPath)
    if not target then return 0; end
  end

  target = far.ConvertPath(target or DestPath, "CPM_FULL")
  local attr = win.GetFileAttr(target)
  if attr then
    if attr:find("d") then target=target.."/"..fname; end
  else -- target does not exist
    local dir = target:match(".*/")
    win.CreateDir(dir)
  end

  local ret = 0
  local fp_in, fp_out, userbreak
  attr = win.GetFileAttr(target)
  if not attr or 1==far.Message("Target file already exists. Overwrite?", "Confirm", ";YesNo", "w") then
    fp_in = io.open(object.HostFile)
    if fp_in then
      fp_out = io.open(target, "wb")
      if fp_out then
        local decode = object.Lib.decode
        local cache, copied, numerr = {n=0}, 0, 0
        fp_in:read("*l") -- skip the first line
        far.Message("0.0 %", object.Title, "")
        for line in fp_in:lines() do
          local chunk, nerr = decode(line) -- beware: this function returns 2 values
          numerr = numerr + nerr
          cache.n = cache.n + 1
          cache[cache.n] = chunk
          if chunk == "" or cache.n == 23300 then -- 45*23300 = approx. 1 megabyte
            local block = table.concat(cache, "", 1, cache.n)
            cache.n = 0
            fp_out:write(block)
            copied = copied + #block
            local msg = ("%.1f %%"):format(copied*100/object.FileSize)
            far.Message(msg, object.Title, "")
            if win.ExtractKey()=="ESCAPE" and
               1==far.Message("Break the operation?", object.Title, ";YesNo", "w")
            then
              userbreak=true; break
            end
          end
          if chunk == "" then break end
        end
        ret = 1
        if not userbreak and numerr ~= 0 then
          far.Message(numerr.." error(s) occured", object.Title, nil, "w")
        end
      end
    end
  end
  if fp_out then
    fp_out:close()
    if userbreak then win.DeleteFile(target) end
  end
  if fp_in then fp_in:close() end
  return ret
end

-- encfile(fname_in, fname_out [,firstline] [,callback])
-- @fname_in  : input file name
-- @fname_out : output file name
-- @firstline : first line of output file; optional
-- @callback  : function; optional
-- @returns   : true (if success)
--              nil,errormessage,errorcode (if failure)
--
function mod.PutFiles(object, handle, Items, Move, OpMode)
  local is_edit = (bit64.band(OpMode,F.OPM_EDIT) ~= 0)
  if is_edit or not win.GetFileAttr(object.HostFile)
    or 1==far.Message("Are you sure to overwrite the archive content?", object.Title, ";YesNo", "w")
  then
    local callback = function(size)
      local msg = ("%d MB copied"):format(size/0x100000)
      far.Message(msg, object.Title, "")
    end
    -- local SrcPath = object.HostFile:match("(.*)/") or "."
    local SrcPath = "."
    if object.Lib.encfile(SrcPath.."/"..Items[1].FileName, object.HostFile, nil, callback) then
      if not is_edit then
        object.FileName = Items[1].FileName
      end
      return 1
    else
      far.Message("Failed to update the archive", object.Title, nil, "w")
    end
  end
  return 0
end

PanelModule(mod)

NoMenuItem {
  description = mod.Info.Title;                     -- string (optional field)
  menu   = "Plugins";                               -- string
  area   = "Shell";                                 -- string (optional field)
  guid   = "10E7E1A7-004C-4239-B06A-AA59FD227BB5";  -- string
  text   = mod.Info.Title;                          -- string, or function
  action = function(OpenFrom,Item)                  -- function
    return mod, FileToObject(APanel.Current)
  end;
}
