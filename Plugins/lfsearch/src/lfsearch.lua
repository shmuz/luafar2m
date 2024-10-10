-- lfsearch.lua
-- luacheck: globals lfsearch _Plugin

local SETTINGS_KEY  = ("%08X"):format(far.GetPluginId())
local SETTINGS_NAME = "settings"
local F = far.Flags
local M -- forward declaration
local MenuFlags = bit64.bor(F.FMENU_WRAPMODE, F.FMENU_AUTOHIGHLIGHT)
_G.lfsearch = {}


local function SetDefaultIfNil(tbl, field, dflt)
  if tbl[field] == nil then tbl[field] = dflt end
end


-- Set the defaults: prioritize safety and "least surprise".
local function LoadDataOnFirstRun()
  local Sett = require "far2.settings"
  local history = Sett.mload(SETTINGS_KEY, SETTINGS_NAME) or {}
  for _,key in ipairs {"config","main","menu","panels.menu","persistent","presets","rename","tmppanel"} do
    Sett.field(history, key)
  end

  local data = history["main"]
  local pers = history["persistent"]
  local setval = function(name, dflt)
    if data[name]==nil or not pers[name] then data[name]=dflt; end
  end
  setval("bAdvanced"          , false)
  setval("bConfirmReplace"    , true)
  setval("bDelEmptyLine"      , false)
  setval("bDelNonMatchLine"   , false)
  setval("bGrepInverseSearch" , false)
  setval("bInverseSearch"     , false)
  setval("bMultiPatterns"     , false)
  setval("bRepIsFunc"         , false)
  setval("bSearchBack"        , false)
  setval("bUseDirFilter"      , false)
  setval("bUseFileFilter"     , false)
  setval("sSearchArea"        , "FromCurrFolder")

  data = history["config"]
  SetDefaultIfNil (data, "EditorHighlightColor",    0xCF)
  SetDefaultIfNil (data, "GrepLineNumMatchColor",   0xA0)
  SetDefaultIfNil (data, "GrepLineNumContextColor", 0x80)
  SetDefaultIfNil (data, "bForceScopeToBlock",      true)
  SetDefaultIfNil (data, "bSelectFound",            true)
  SetDefaultIfNil (data, "bShowSpentTime",          true)

  return history
end


local function PersistentDialog()
  local sd = require "far2.simpledialog"
  local items = {
      width = 0;
      guid="325E21EA-0E78-4FF8-A800-8710896CE606";
      help="PersistentSettings";
    {tp="dbox";  text=M.MDlgPersistentSettings; },
    {tp="chbox"; name="bAdvanced"         ; text=M.MDlgAdvanced          ; },
    {tp="chbox"; name="bConfirmReplace"   ; text=M.MDlgConfirmReplace    ; },
    {tp="chbox"; name="bDelEmptyLine"     ; text=M.MDlgDelEmptyLine      ; },
    {tp="chbox"; name="bDelNonMatchLine"  ; text=M.MDlgDelNonMatchLine   ; },
    {tp="chbox"; name="bGrepInverseSearch"; text=M.MDlgGrepInverseSearch ; },
    {tp="chbox"; name="bInverseSearch"    ; text=M.MDlgInverseSearch     ; },
    {tp="chbox"; name="bMultiPatterns"    ; text=M.MDlgMultiPatterns     ; },
    {tp="chbox"; name="bRepIsFunc"        ; text=M.MDlgRepIsFunc         ; },
    {tp="chbox"; name="bSearchBack"       ; text=M.MDlgReverseSearch     ; },
    {tp="chbox"; name="bUseDirFilter"     ; text=M.MDlgUseDirFilter      ; },
    {tp="chbox"; name="bUseFileFilter"    ; text=M.MDlgUseFileFilter     ; },
    {tp="chbox"; name="sSearchArea"       ; text=M.MDlgSearchArea        ; },
    {tp="sep"; },
    {tp="butt"; default=1; centergroup=1; text=M.MOk;     },
    {tp="butt"; cancel=1;  centergroup=1; text=M.MCancel; },
  }
  for _,v in ipairs(items) do
    if v.text and v.name then
      v.text=v.text:gsub("&",""):gsub(":$","")
      v.text = ("%-30s(%s)"):format(v.text, v.name)
    end
  end

  local pers = _Plugin.History["persistent"]
  local dlg = sd.New(items)
  dlg:LoadData(pers)
  local out = dlg:Run()
  if out then
    dlg:SaveData(out, pers)
    _Plugin.History:save()
  end
end


local function FirstRunActions()
  local history = LoadDataOnFirstRun()

  _Plugin = {
    DialogHistoryPath = "LuaFAR Search\\",
    OriginalRequire = require,
    History = history,
    Repeat = {},
    FileList = nil,
  }
end


local FirstRun = not _Plugin
if FirstRun then FirstRunActions() end
local History = _Plugin.History


local libUtils   = require "far2.utils"
local Common     = require "lfs_common"
local EditMain   = require "lfs_editmain"
local Editors    = require "lfs_editors"
M                = require "lfs_message"
local MReplace   = require "lfs_mreplace"
local Panels     = require "lfs_panels"
local Rename     = require "lfs_rename"
local Sett       = require "far2.settings"


local function SaveSettings()
  Sett.msave(SETTINGS_KEY, SETTINGS_NAME, History)
end
_Plugin.SaveSettings = SaveSettings


local function ForcedRequire (name)
  package.loaded[name] = nil
  return _Plugin.OriginalRequire(name)
end


local function OpenFromEditor (userItems)
  local hMenu = History["menu"]
  local items = {
    { text=M.MMenuFind,             action="search",         save=true  },
    { text=M.MMenuReplace,          action="replace",        save=true  },
    { text=M.MMenuRepeat,           action="repeat",         save=false },
    { text=M.MMenuRepeatRev,        action="repeat_rev",     save=false },
    { text=M.MMenuFindWord,         action="searchword",     save=false },
    { text=M.MMenuFindWordRev,      action="searchword_rev", save=false },
    { text=M.MMenuMultilineReplace, action="mreplace",       save=true  },
    { text=M.MMenuToggleHighlight,  action="togglehighlight",save=false },
    { text=M.MMenuConfig,           action="config",         save=true  },
  }
  for k,v in ipairs(items) do v.text=k..". "..v.text end

  local nOwnItems = #items
  libUtils.AddMenuItems(items, userItems, M)
  local item, pos = far.Menu(
    { Title=M.MMenuTitle, HelpTopic="EditorMenu", SelectIndex=hMenu.position, Flags=MenuFlags}, items)
  if not item then return end
  hMenu.position = pos

  if pos <= nOwnItems then
    local data = History["main"]
    data.fUserChoiceFunc = nil
    local ret

    if item.action == "togglehighlight" then
      Editors.ToggleHighlight()
    elseif item.action == "mreplace" then
      ret = MReplace.ReplaceWithDialog(data, true)
    else
      ret = EditMain.EditorAction(item.action, data, false)
    end

    if ret and item.save then
      SaveSettings()
    end
  else
    libUtils.RunUserItem(item, item.arg)
    SaveSettings()
  end
end


local function GUI_SearchFromPanels (data)
  local tFileList, bCancel = Panels.SearchFromPanel(data, true, false)
  if tFileList then -- the dialog was not cancelled
    if tFileList[1] then
      local panel = Panels.CreateTmpPanel(tFileList)
      SaveSettings()
      return panel
    else -- no files were found
      if bCancel or 1==far.Message(M.MNoFilesFound,M.MMenuTitle,M.MButtonsNewSearch) then
        return GUI_SearchFromPanels(data)
      end
      SaveSettings()
    end
  end
end


local function OpenFromPanels (userItems)
  local hMain = History["main"]
  local hMenu = History.panels.menu

  local items = {
    {text=M.MMenuFind,     action="find"},
    {text=M.MMenuReplace,  action="replace"},
    {text=M.MMenuGrep,     action="grep"},
    {text=M.MMenuRename,   action="rename"},
    {text=M.MMenuTmpPanel, action="tmppanel"},
  }
  for k,v in ipairs(items) do v.text=k..". "..v.text end

  local nOwnItems = #items
  libUtils.AddMenuItems(items, userItems, M)
  local item, pos = far.Menu(
    { Title=M.MMenuTitle, HelpTopic="OperInPanels", SelectIndex=hMenu.position, Flags=MenuFlags }, items)
  if not item then return end
  hMenu.position = pos

  if pos <= nOwnItems then
    if item.action == "find" then
      return GUI_SearchFromPanels(hMain)
    elseif item.action == "replace" then
      Panels.ReplaceFromPanel(hMain, true, false)
    elseif item.action == "grep" then
      Panels.GrepFromPanel(hMain, true, false)
    elseif item.action == "rename" then
      Rename.main()
    elseif item.action == "tmppanel" then
      return Panels.CreateTmpPanel(_Plugin.FileList or {}, History["tmppanel"])
    end
  else
    libUtils.RunUserItem(item, item.arg)
  end
end


local function DoOpenFromMacro (args, commandTable)
  local Op, Where, Cmd = unpack(args)

  if Op=="code" or Op=="file" or Op=="command" then
    return libUtils.OpenMacro(args, commandTable, nil, M.MMenuTitle)

  elseif Op=="own" then
    local area = far.MacroGetArea()
    local data = History["main"]
    data.fUserChoiceFunc = nil

    if Where=="editor" then
      if area == F.MACROAREA_EDITOR then
        if Cmd=="search" or Cmd=="searchword" or Cmd=="searchword_rev" or Cmd=="replace" or Cmd=="config" then
          return EditMain.EditorAction(Cmd, data, false) and true
        elseif Cmd=="repeat" or Cmd=="repeat_rev" then
          return EditMain.EditorAction(Cmd, data, false) and false
        elseif Cmd=="mreplace" then
          return MReplace.ReplaceWithDialog(data, true) and true
        end
      end

    elseif Where=="panels" then
      if area==F.MACROAREA_SHELL or area==F.MACROAREA_TREEPANEL or
         area==F.MACROAREA_QVIEWPANEL or area==F.MACROAREA_INFOPANEL
      then
        if Cmd == "search" then
          local pan = GUI_SearchFromPanels(data)
          return pan and { pan, type="panel" }
        elseif Cmd == "replace" then
          Panels.ReplaceFromPanel(data, true, false)
        elseif Cmd == "grep" then
          Panels.GrepFromPanel(data, true, false)
        elseif Cmd == "rename" then
          Rename.main()
        elseif Cmd == "panel" then
          local pan = Panels.CreateTmpPanel(_Plugin.FileList or {}, History["tmppanel"])
          return { [1]=pan; type="panel" }
        end
      end
    end

  end
end


export.OnError = libUtils.OnError
export.ProcessEditorEvent = Editors.ProcessEditorEvent


local function OpenCommandLine (aItem)
  local _, commandTable = libUtils.LoadUserMenu("_usermenu.lua")
  return libUtils.OpenCommandLine(aItem, commandTable, nil, M.MMenuTitle)
end


local function OpenFromMacro (aItem)
  local _, commandTable = libUtils.LoadUserMenu("_usermenu.lua")
  local val = DoOpenFromMacro(aItem, commandTable)
  if val then
    SaveSettings()
    return val
  end
end


function export.Open (aFrom, _aId, aItem)
  local userItems = libUtils.LoadUserMenu("_usermenu.lua")
  if     aFrom == F.OPEN_PLUGINSMENU then return OpenFromPanels(userItems.panels)
  elseif aFrom == F.OPEN_EDITOR      then return OpenFromEditor(userItems.editor)
  elseif aFrom == F.OPEN_COMMANDLINE then return OpenCommandLine(aItem)
  elseif aFrom == F.OPEN_FROMMACRO   then return OpenFromMacro(aItem)
  end
end


function export.GetPluginInfo()
  return {
    CommandPrefix = "lfs",
    Flags = F.PF_EDITOR,
    PluginMenuStrings = { M.MMenuTitle },
    PluginConfigStrings = { M.MMenuTitle },
  }
end


function export.Configure (Guid) -- luacheck: no unused args
  local properties = {
    Flags = MenuFlags,
    Title = M.MConfigMenuTitle,
    HelpTopic = "Contents",
  }
  local items = {
    { text=M.MConfigTitleEditor;   action=Common.EditorConfigDialog; },
    { text=M.MConfigTitleTmpPanel; action=Panels.ConfigDialog;       },
    { text=M.MConfigTitleCommon;   action=Common.ConfigDialog;       },
    { text=M.MDlgPersistentSettings; action=PersistentDialog;        },
  }
  local userItems = libUtils.LoadUserMenu("_usermenu.lua")
  libUtils.AddMenuItems(items, userItems.config, M)
  while true do
    local item, pos = far.Menu(properties, items)
    if not item then break end
    if pos <= #items then
      item.action()
    else
      libUtils.RunUserItem(item, item.arg)
    end
    properties.SelectIndex = pos
  end
end


lfsearch.MReplaceEditorAction = MReplace.EditorAction
lfsearch.MReplaceDialog = MReplace.ReplaceWithDialog


function lfsearch.EditorAction (aOp, aData, aSaveData)
  assert(type(aOp)=="string", "arg #1: string expected")
  assert(type(aData)=="table", "arg #2: table expected")
  local newdata = {}; for k,v in pairs(aData) do newdata[k] = v end
  local nFound, nReps = EditMain.EditorAction(aOp, newdata, true)
  if aSaveData and nFound then
    History["main"] = newdata
  end
  return nFound, nReps
end


function lfsearch.SetDebugMode (On)
  if On then
    require = ForcedRequire -- luacheck: allow defined (require)
    far.ReloadDefaultScript = true
  else
    require = _Plugin.OriginalRequire
    far.ReloadDefaultScript = false
  end
end


function lfsearch.SearchFromPanel (data, bWithDialog)
  return Panels.SearchFromPanel(data, bWithDialog, true)
end


function lfsearch.ReplaceFromPanel (data, bWithDialog)
  return Panels.ReplaceFromPanel(data, bWithDialog, true)
end


do
  Panels.InitTmpPanel()
end
