-- started: 2014-01-07
--------------------------------------------------------------------------------
far.ReloadDefaultScript = true

local F = far.Flags
local Title = "File generator"

local OpenPanelInfoFlags = bit64.bor(F.OPIF_ADDDOTS)

local PluginMenuGuid1   = win.Uuid("8DEBE183-0BD7-4223-BDF3-41325A7E24C8")
local PluginConfigGuid1 = win.Uuid("CF6F0F3B-0814-4CB9-B8D2-E5CAD986B4F2")

function export.GetPluginInfo()
  return {
    CommandPrefix = "fgen",
    Flags = 0,
    -- PluginConfigGuids   = PluginConfigGuid1,
    -- PluginConfigStrings = { Title },
    -- PluginMenuGuids   = PluginMenuGuid1,
    -- PluginMenuStrings = { Title },
  }
end

function export.Open(OpenFrom, Guid, text)
  if OpenFrom == F.OPEN_COMMANDLINE then
    local fnum  = regex.match(text, [[ \b FNUM  = (\d+) \b ]], nil, "xi")
    local dnum  = regex.match(text, [[ \b DNUM  = (\d+) \b ]], nil, "xi")
    local fname = regex.match(text, [[ \b FNAME = (\S+)    ]], nil, "xi")
    local dname = regex.match(text, [[ \b DNAME = (\S+)    ]], nil, "xi")
    local fext  = regex.match(text, [[ \b FEXT  = (\S+)    ]], nil, "xi")
    local dext  = regex.match(text, [[ \b DEXT  = (\S+)    ]], nil, "xi")
    return {
      fnum = tonumber(fnum) or 0;
      dnum = tonumber(dnum) or 0;
      fname = fname;
      dname = dname;
      fext = fext;
      dext = dext;
    }
  end
end

function export.GetFindData (obj, handle, OpMode)
  --if band(OpMode, F.OPM_FIND) ~= 0 then return end

  local fname = obj.fname or "File"
  local dname = obj.dname or "Dir"
  local fext = obj.fext and "."..obj.fext or ""
  local dext = obj.dext and "."..obj.dext or ""
  local data = {}
  for k=1,obj.fnum do
    data[k] = {
      FileName = fname..k..fext;
    }
  end
  for k=1,obj.dnum do
    data[k+obj.fnum] = {
      FileName = dname..k..dext;
      FileAttributes="d";
    }
  end
  return data
end

function export.GetOpenPanelInfo (object, handle)
--far.MacroPost[[print"."]]
  return {
    Flags            = OpenPanelInfoFlags,
    PanelTitle       = Title,
  }
end

function export.ProcessPanelEvent (object, handle, Event, Param)
  if Event == F.FE_IDLE then
    panel.UpdatePanel(handle,nil,true)
    panel.RedrawPanel(handle)
  end
end
