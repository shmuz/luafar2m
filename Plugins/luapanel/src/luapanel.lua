-- started: 2015-07-16
--------------------------------------------------------------------------------
--  _G [false] = true
--  _G [true]  = false
--  _G [{}]    = "aaa"
--------------------------------------------------------------------------------
-- luacheck: new_globals Settings

far.ReloadDefaultScript = true

local F = far.Flags
local Title = "Lua Panel"
local VK = win.GetVirtualKeys()
local band = bit64.band

local Settings = {
  LastPanelMode = ("1"):byte();
  LastSortMode  = F.SM_NAME;
  LastSortOrder = 0;
}

local PluginMenuGuid1 = win.Uuid("8127E2DF-C01C-46B9-8E5D-056EFBB0AAF7")

function export.GetPluginInfo()
  return {
    CommandPrefix = "luapanel",
    Flags = 0,
    PluginMenuGuids   = PluginMenuGuid1,
    PluginMenuStrings = { Title },
  }
end

local function OpenShortcut(Item)
  local obj = { CurDir="", {table = _G} }
  local curtable = _G
  for name in Item:gmatch("[^.]+") do
    curtable = curtable[name]
    if curtable then
      obj.CurDir = (obj.CurDir=="") and name or obj.CurDir.."."..name
      table.insert(obj, {table=curtable})
    else
      break
    end
  end
  return obj
end

local function OpenCommandLine(Item)
  local obj = { CurDir="", {table = _G} }
  local str = Item:match("^%s*(.-)%s*$") -- trim whitespace from both sides
  local v = _G[str]
  if type(v) == "table" then
    obj.CurDir = str
    table.insert(obj, {table = v})
  end
  return obj
end

function export.Open (OpenFrom, _Id, Item)
  if OpenFrom == F.OPEN_SHORTCUT then
    return OpenShortcut(Item)
  elseif OpenFrom == F.OPEN_COMMANDLINE then
    return OpenCommandLine(Item)
  elseif OpenFrom == F.OPEN_PLUGINSMENU then
    return { CurDir="", {table = _G} }
  end
end

--
-- @param object contains a list (stack) of tables; stack top is of interest now.
--
function export.GetFindData (object, handle, OpMode)
  --if band(OpMode, F.OPM_FIND) ~= 0 then return end
  local data = {}
  local curr = object[#object] -- get stack top
  for k,v in pairs(curr.table) do
    local str
    local tp = type(v)
    if tp == "string" then
      str = '"'..v..'"'
    elseif tp == "number" and v == math.floor(v) then
      str = ("%-11s : 0x%X"):format(tostring(v), v)
    else
      str = tostring(v)
    end
    table.insert(data, {
      FileName = tostring(k);
      FileAttributes = tp=="table" and "d" or "";
      CustomColumnData = { str };
      UserData = { element=v };
    })
  end
  return data
end

local PanelModes do
  local m1 = {
    ColumnTypes = "N,C0",
    ColumnWidths = "40%,60%",
    ColumnTitles = { "Key","Value" },
    StatusColumnTypes = "N",
    StatusColumnWidths = "0",
    FullScreen = false,
  }
  local m2 = {
    ColumnTypes = "N,C0",
    ColumnWidths = "30%,70%",
    ColumnTitles = { "Key","Value" },
    StatusColumnTypes = "N",
    StatusColumnWidths = "0",
    FullScreen = true,
  }
  PanelModes = { m2,m1,m2, m1,m2,m1, m2,m1,m2, m1 }
end

function export.GetOpenPanelInfo (obj, handle)
  return {
    Flags            = F.OPIF_ADDDOTS,
  --CurDir           = obj.CurDir,
    PanelTitle       = obj.CurDir=="" and Title or Title..": "..obj.CurDir,
    PanelModesArray  = PanelModes,
    PanelModesNumber = 10,
    StartPanelMode   = Settings.LastPanelMode,
    StartSortMode    = Settings.LastSortMode,
    StartSortOrder   = Settings.LastSortOrder,
    ShortcutData     = obj.CurDir,
  }
end

function export.ProcessPanelEvent (object, handle, Event, Param)
  if Event == F.FE_IDLE then
    panel.UpdatePanel(handle,nil,true)
    panel.RedrawPanel(handle)
  elseif Event == F.FE_CHANGEVIEWMODE then
    local info = panel.GetPanelInfo(handle)
    Settings.LastPanelMode = tostring(info.ViewMode):byte()
  end
end

function export.ProcessKey (object, handle, Key, ControlState)
  if band(Key, F.PKF_PREPROCESS) ~= 0 then
    return false
  end

  local A = (0 ~= band(ControlState, F.PKF_ALT))
  local C = (0 ~= band(ControlState, F.PKF_CONTROL))
  local S = (0 ~= band(ControlState, F.PKF_SHIFT))

  if not (A or C or S) and Key == VK.RETURN then
    local item = panel.GetCurrentPanelItem(handle)
    if item.FileName == ".." then  -- try to "return" to the parent table
      if #object > 1 then
        local info = object[#object].info
        object[#object] = nil -- pop the element off the stack
        object.CurDir = object.CurDir:match("(.+)%..+") or ""
        panel.UpdatePanel(handle)
        panel.RedrawPanel(handle, nil, info)
        return true
      end
    else  -- try to "enter" a table
      local curr = item.UserData and item.UserData.element
      if type(curr) == "table" then
        object[#object+1] = { table=curr, info=panel.GetPanelInfo(handle) }
        object.CurDir = object.CurDir=="" and item.FileName or object.CurDir.."."..item.FileName
        panel.UpdatePanel(handle)
        panel.RedrawPanel(handle, nil, {CurrentItem=1})
        return true
      end
    end
  end
end
