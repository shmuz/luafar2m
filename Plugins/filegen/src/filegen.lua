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

local pat_cmdline = regex.new ([[
  ^ \s* (\d+) (?:\s+(\d+))? (?:\s|$)
]], "ix")

function export.Open(OpenFrom, Guid, Item)
  if OpenFrom == F.OPEN_COMMANDLINE then
    local n,d = pat_cmdline:match(Item)
    if n then
      return { numfiles=tonumber(n); numdirs=tonumber(d) or 0; }
    end
  end
end

function export.GetFindData (object, handle, OpMode)
  --if band(OpMode, F.OPM_FIND) ~= 0 then return end
  local data = {}
  for k=1,object.numfiles do
    data[k] = { FileName = "File"..k; }
  end
  for k=1,object.numdirs do
    data[k+object.numfiles] = { FileName = "Dir"..k; FileAttributes="d"; }
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
