-- started: 2013-10-30
--------------------------------------------------------------------------------
-- luacheck: new_globals Settings

far.ReloadDefaultScript = true

local SETTINGS_KEY  = ("%08X"):format(far.GetPluginId())
local SETTINGS_NAME = "settings"

local Sett = require "far2.settings"

local F = far.Flags
local Title = "Macro Panel"
local VK = win.GetVirtualKeys()
local band, bor = bit64.band, bit64.bor
local LStricmp = far.LStricmp

local LoadSettings, SaveSettings, SettingsAreLoaded do
  function LoadSettings()
    _G.Settings = Sett.mload(SETTINGS_KEY, SETTINGS_NAME) or {
        LastPanelMode = ("1"):byte();
        LastSortMode  = F.SM_NAME;
        LastSortOrder = 0;
      }
  end

  function SaveSettings()
    Sett.msave(SETTINGS_KEY, SETTINGS_NAME, Settings)
  end

  function SettingsAreLoaded()
    return Settings and Settings.LastPanelMode ~= nil
  end
end

if not SettingsAreLoaded() then
  LoadSettings()
end

local OpenPanelInfoFlags = bor(F.OPIF_ADDDOTS, 0)

local P_AREA,P_GROUP,P_KEY,P_FILENAME,P_STARTLINE,P_FILEMASK = 1,1,2,3,4,5

-- @param fname     : full file name
-- @param whatpanel : 0=passive, 1=active (default)
-- @return          : true if the file has been located
local function LocateFile (fname, whatpanel)
  whatpanel = whatpanel or 1
  local attr = win.GetFileAttr(fname)
  if attr and not attr:find"d" then
    local dir, name = fname:match("^(.*/)([^/]*)$")
    if panel.SetPanelDirectory(whatpanel, dir) then
      local pinfo = panel.GetPanelInfo(whatpanel)
      for i=1, pinfo.ItemsNumber do
        local item = panel.GetPanelItem(whatpanel, i)
        if item.FileName == name then
          local rect = pinfo.PanelRect
          local hheight = math.floor((rect.bottom - rect.top - 4) / 2)
          local topitem = pinfo.TopPanelItem
          panel.RedrawPanel(whatpanel, { CurrentItem = i,
            TopPanelItem = i>=topitem and i<topitem+hheight and topitem or
                           i>hheight and i-hheight or 0 })
          return true
        end
      end
    end
  end
  return false
end

function export.GetPluginInfo()
  return {
    CommandPrefix = "mp",
    Flags = 0,
    PluginConfigStrings = { Title },
    PluginMenuStrings = { Title },
  }
end

local pat_cmdline = regex.new ([[
  ^ \s* (?: (macros | m) | (events | e) )
  (?: \s+(\S+) (?: \s+(\S+) (?: \s+(\S+) )? )? )? (?: \s | $)
]], "ix")

function export.Open(OpenFrom, _ItemNumber, Item)
-- local t1=os.clock()
-- for k=1,1000 do export.GetFindData({type="macros"},nil,nil) end
-- far.Message(os.clock()-t1)

  if OpenFrom == F.OPEN_PLUGINSMENU then
    local menuitem = far.Menu({Title=Title},
      { {text="&1. Show macros",type="macros"}, {text="&2. Show events",type="events"} })
    if menuitem then return { type=menuitem.type } end

  elseif OpenFrom == F.OPEN_COMMANDLINE then
    local macros, events, f1, f2, f3 = pat_cmdline:match(Item)
    if macros or events then
      f1, f2, f3 = f1 and regex.new(f1,"i"), f2 and regex.new(f2,"i"), f3 and regex.new(f3,"i")
      return { type=macros and "macros" or "events", f1=f1, f2=f2, f3=f3 }
    end

  elseif OpenFrom == F.OPEN_SHORTCUT then
    return { type=Item.ShortcutData }

  end
end

function export.Configure()
  far.Message("Nothing to configure as yet", Title)
end

function export.GetFindData (object, handle, OpMode)
  --if band(OpMode, F.OPM_FIND) ~= 0 then return end
  local sequence = [[
    local idx, kind = ...
    while true do
      local m = mf.GetMacroCopy(idx)
      if not m then return 0 end
      if kind == "macros" then
        if m.area and not m.disabled then
          local startline = m.FileName and m.action and debug.getinfo(m.action,"S").linedefined or 1
          return idx, m.description, m.area, m.key, m.index, m.FileName, startline, m.filemask
        end
      elseif kind == "events" then
        if m.group and not m.disabled then
          local startline = m.FileName and m.action and debug.getinfo(m.action,"S").linedefined or 1
          return idx, m.description, m.group, m.index, m.FileName, startline, m.filemask
        end
      end
      idx = idx+1
    end
  ]]
  local data = {}
  local objtype = object.type
  local idx = 1
  while true do
    local t = far.MacroExecute(sequence, nil, idx, objtype)
    if not t then -- error occured: do not create panel
      far.Message("Can not retrieve "..objtype, Title, nil, "w")
      return
    end
    if t[1]==0 then return data end -- end indicator
    if objtype == "macros" then
      local description, area, key, index, filename, startline, filemask = unpack(t, 2, t.n)
      if description==nil or description=="" then
        description = ("[index = %d]"):format(index)
      end
      if  (not object.f1 or object.f1:find(description)) and
          (not object.f2 or object.f2:find(area)) and
          (not object.f3 or object.f3:find(key))
      then
        filemask = filemask or ""
        data[#data+1] = { FileName=description, CustomColumnData = { area,key,filename,startline,filemask } }
      end
    elseif objtype == "events" then
      local description, group, index, filename, startline, filemask = unpack(t, 2, t.n)
      if description==nil or description=="" then
        description = ("[index = %d]"):format(index)
      end
      if  (not object.f1 or object.f1:find(description)) and
          (not object.f2 or object.f2:find(group))
      then
        data[#data+1] = { FileName=description, CustomColumnData = { group,"",filename,startline,filemask } }
      end
    end
    idx = t[1] + 1
  end
end

local MacroPanelModes do
  local m1 = {
    ColumnTypes = "N,C0,C1",
    ColumnWidths = "50%,0,0",
    ColumnTitles = { "Description","Area","Key" },
    StatusColumnTypes = "N",
    StatusColumnWidths = "0",
    FullScreen = false,
  }
  local m2 = {
    ColumnTypes = "N,C0,C1,C4",
    ColumnWidths = "45%,15%,0,15%",
    ColumnTitles = { "Description","Area","Key","Filemask" },
    StatusColumnTypes = "N",
    StatusColumnWidths = "0",
    FullScreen = true,
  }
  MacroPanelModes = { m2,m1,m2, m1,m2,m1, m2,m1,m2, m1 }
end

local EventPanelModes do
  local m1 = {
    ColumnTypes = "N,C0",
    ColumnWidths = "60%,0",
    ColumnTitles = { "Description", "Group" },
    StatusColumnTypes = "N",
    StatusColumnWidths = "0",
    FullScreen = false,
  }
  local m2 = {
    ColumnTypes = "N,C0,C4",
    ColumnWidths = "0,20%,20%",
    ColumnTitles = { "Description","Group","Filemask" },
    StatusColumnTypes = "N",
    StatusColumnWidths = "0",
    FullScreen = true,
  }
  EventPanelModes = { m2,m1,m2, m1,m2,m1, m2,m1,m2, m1 }
end

function export.GetOpenPanelInfo (object, handle)
--far.MacroPost[[print"."]]
  return {
    Flags            = OpenPanelInfoFlags,
    PanelTitle       = ("%s (%s)"):format(Title, object.type),
    PanelModesArray  = object.type=="macros" and MacroPanelModes or EventPanelModes,
    PanelModesNumber = 10,
    StartPanelMode   = Settings.LastPanelMode,
    StartSortMode    = Settings.LastSortMode,
    StartSortOrder   = Settings.LastSortOrder,
    ShortcutData     = object.type,
  }
end

function export.Compare (object, handle, Item1, Item2, Mode)
  local r
  if object.type == "macros" then
    if Mode == F.SM_EXT then
      r = LStricmp(Item1.CustomColumnData[P_AREA], Item2.CustomColumnData[P_AREA])
      if r ~= 0 then return r end
      r = LStricmp(Item1.FileName, Item2.FileName)
      if r ~= 0 then return r end
      return LStricmp(Item1.CustomColumnData[P_KEY], Item2.CustomColumnData[P_KEY])
    elseif Mode == F.SM_MTIME then
      r = LStricmp(Item2.CustomColumnData[P_KEY], Item1.CustomColumnData[P_KEY]) -- order changed on purpose
      if r ~= 0 then return r end
      r = LStricmp(Item2.FileName, Item1.FileName)
      if r ~= 0 then return r end
      return LStricmp(Item2.CustomColumnData[P_AREA], Item1.CustomColumnData[P_AREA])
    else
      r = LStricmp(Item1.FileName, Item2.FileName)
      if r ~= 0 then return r end
      r = LStricmp(Item1.CustomColumnData[P_AREA], Item2.CustomColumnData[P_AREA])
      if r ~= 0 then return r end
      return LStricmp(Item1.CustomColumnData[P_KEY], Item2.CustomColumnData[P_KEY])
    end

  elseif object.type == "events" then
    if Mode == F.SM_EXT then
      r = LStricmp(Item1.CustomColumnData[P_GROUP], Item2.CustomColumnData[P_GROUP])
      if r ~= 0 then return r end
      return LStricmp(Item1.FileName, Item2.FileName)
    else
      r = LStricmp(Item1.FileName, Item2.FileName)
      if r ~= 0 then return r end
      return LStricmp(Item1.CustomColumnData[P_GROUP], Item2.CustomColumnData[P_GROUP])
    end
  end

end

function export.ProcessPanelEvent (object, handle, Event, Param)
  if Event == F.FE_IDLE then
    panel.UpdatePanel(handle,true)
    panel.RedrawPanel(handle)
  elseif Event == F.FE_CHANGEVIEWMODE then
    local info = panel.GetPanelInfo(handle)
    Settings.LastPanelMode = tostring(info.ViewMode):byte()
--elseif Event == F.FE_CHANGESORTPARAMS then
--  local info = panel.GetPanelInfo(handle)
--  Settings.LastSortMode = info.SortMode
--  Settings.LastSortOrder = band(info.Flags,F.PFLAGS_REVERSESORTORDER)==0 and 0 or 1
  end
end

function export.ProcessKey (object, handle, Key, ControlState)
  if band(Key, F.PKF_PREPROCESS) ~= 0 then
    return false
  end

  local A = (0 ~= band(ControlState, F.PKF_ALT))
  local C = (0 ~= band(ControlState, F.PKF_CONTROL))
  local S = (0 ~= band(ControlState, F.PKF_SHIFT))

  -- suppress the silly Far error message
  if not (A or C or S) and Key == VK.F7 then
    return true
  end

  -- F3:view or F4:edit macrofile
  if not (A or C or S) and (Key==VK.F3 or Key==VK.CLEAR or Key==VK.F4) then
    local item = panel.GetCurrentPanelItem(handle)
    local cdata = item.CustomColumnData
    if cdata and cdata[P_FILENAME] then
      local flags = bor(F.EF_NONMODAL, F.EF_IMMEDIATERETURN, F.EF_ENABLE_F6)
      local ret = editor.Editor(cdata[P_FILENAME], nil,nil,nil,nil,nil, flags, cdata[P_STARTLINE])
      if Key ~= VK.F4 and ret == F.EEC_MODIFIED then
        --editor.SetPosition(nil, { TopScreenLine = math.max(1,startline-4) })
        far.MacroPost[[Keys"F6"]] -- a trick for proper setting position in viewer
      end
    end

  -- AltShiftF3: go to macrofile in passive panel
  elseif (A and not C and S) and Key == VK.F3 then
    local item = panel.GetCurrentPanelItem(handle)
    local cdata = item.CustomColumnData
    if cdata and cdata[P_FILENAME] then
      if LocateFile(cdata[P_FILENAME], 0) then
        panel.SetActivePanel(0)
      end
      return true
    end

  -- CtrlPgUp: go to macrofile in active panel
  elseif (not A and C and not S) and (Key==VK.PRIOR or Key==VK.NUMPAD9) then
    local item = panel.GetCurrentPanelItem(handle)
    local cdata = item.CustomColumnData
    if cdata and cdata[P_FILENAME] then
      LocateFile(cdata[P_FILENAME], 1)
      return true
    end

  end
end

function export.GetFiles (object, handle, PanelItems, Move, DestPath, OpMode)
  -- quick view
  if 0 ~= band(OpMode, F.OPM_QUICKVIEW) then
    local item = PanelItems[1]
    local cdata = item.CustomColumnData
    if cdata and cdata[P_FILENAME] then
      return win.CopyFile(cdata[P_FILENAME], DestPath.."/"..item.FileName) and 1 or 0
    end
  end
end

function export.ClosePanel (object, handle)
  SaveSettings()
end
