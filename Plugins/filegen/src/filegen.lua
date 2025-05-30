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
  }
end

function export.Open(OpenFrom, Guid, text)
  if OpenFrom == F.OPEN_COMMANDLINE then
    local out = {}
    local args =  { far.SplitCmdLine(text) }
    for k,v in ipairs(args) do
      local key, val = v:match("^%s*(%w+)%s*=(.+)$")
      if key == "fnum" or key == "dnum" then out[key] = tonumber(val)
      elseif key == "fname" or key == "dname" then out[key] = val
      end
    end
    return out
  end
end

function export.GetFindData (obj, handle, OpMode)
  --if band(OpMode, F.OPM_FIND) ~= 0 then return end

  local fname = obj.fname or "File-{1}"
  local dname = obj.dname or "Dir-{1}"
  local fnum = obj.fnum or 0
  local dnum = obj.dnum or 0

  local data = {}
  for k=1,fnum do
    data[k] = {
      FileName = fname:reformat(k);
    }
  end
  for k=1,dnum do
    data[k+fnum] = {
      FileName = dname:reformat(k);
      FileAttributes="d";
    }
  end
  return data
end

function export.GetOpenPanelInfo (object, handle)
  return {
    Flags            = OpenPanelInfoFlags,
    PanelTitle       = Title,
  }
end

function export.ProcessPanelEvent (object, handle, Event, Param)
  if Event == F.FE_IDLE then
    ---- Don't call UpdatePanel here as with huge number of files it
    ---- causes big processor load and delayed response to keystrokes.
    -- panel.UpdatePanel(handle,nil,true)
    -- panel.RedrawPanel(handle)
  end
end
