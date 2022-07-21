local F = far.Flags
local Title ="Demo panel in LuaMacro"
local mod = {}

mod.Info = {
  Guid = win.Uuid("715E5E90-DEB9-470A-84CE-7CF8D92A7B05"); -- mandatory field
  Author       = "Shmuel Zeigerman";
  StartDate    = "2018-03-13";
}

local function FileToObject(FileName)
  FileName = far.ConvertPath(FileName, "CPM_FULL")
  local fp = io.open(FileName)
  if fp then
    local obj = { HostFile=FileName; List={} }
    for line in fp:lines() do
      line = line:gsub("\r", "")
      table.insert(obj.List, {FileName=line})
    end
    fp:close()
    return obj
  end
end

function mod.OpenFilePlugin (Name, Data, OpMode)
  if Name and Name:sub(-5):lower() == ".abcd" then
    return FileToObject(Name)
  end
end

function mod.OpenPlugin(OpenFrom, Item)
  if OpenFrom == F.OPEN_SHORTCUT then
    return FileToObject(Item.HostFile)
  elseif OpenFrom == F.OPEN_FINDLIST then -- luacheck: ignore
    -- If we uncomment the line "return {}", then this module will be
    -- used instead of TmpPanel for displaying search results.
    ---- return {}
  end
end

function mod.GetFindData(object, handle, OpMode)
  return object.List
end

function mod.GetOpenPluginInfo(object, handle)
  return {
    HostFile = object.HostFile;
    PanelTitle = Title;
    ShortcutData = "";
    StartSortMode = F.SM_UNSORTED;
    StartSortOrder = 0;
    Flags = bit64.bor(0, F.OPIF_ADDDOTS);
  }
end

function mod.SetFindList (object, handle, Items)
  object.List = Items
  return true
end

if false then
  function mod.ProcessPanelInput (object, handle, Rec)
    if not (Rec.EventType==F.KEY_EVENT and Rec.KeyDown) then return; end
    local vcode  = Rec.VirtualKeyCode
    local cstate = Rec.ControlKeyState
    local nomods = cstate == 0 -- luacheck: no unused
  --local alt    = cstate == F.LEFT_ALT_PRESSED  or cstate == F.RIGHT_ALT_PRESSED
    local ctrl   = cstate == F.LEFT_CTRL_PRESSED or cstate == F.RIGHT_CTRL_PRESSED
    local shift  = cstate == F.SHIFT_PRESSED

    local Name = far.InputRecordToName(Rec)
    --if Name == "ShiftF2" then return true; end
    --if Name == "F11" then return true; end

    far.Show(vcode,cstate,ctrl,shift,Name)
  end
end

MenuItem {
  description = Title;
  menu   = "Plugins";
  area   = "Shell";
  guid   = "5E1ECBD6-F6E1-4A02-AC90-DB49DB6E350C";
  text   = Title;
  action = function(OpenFrom, Item)
    return mod, FileToObject(APanel.Current)
  end;
}

CommandLine {
  description = Title;
  prefixes = "abcd";
  action = function(prefix,text)
    if text then return mod, FileToObject(text); end
  end;
}

PanelModule(mod)
