-- luacheck: globals lfsearch
local ReqLuafarVersion = "2.9"
lfsearch = {}

-- CONFIGURATION : keep it at the file top !!
local Cfg = {
  --  Default script will be recompiled and run every time OpenPlugin/
  --  OpenFilePlugin are called: set true for debugging, false for normal use;
  ReloadDefaultScript = true,

  --  Reload lua libraries each time they are require()d:
  --  set true for libraries debugging, false for normal use;
  ReloadOnRequire = true,

  field_Main   = "main",
  field_Menu   = "menu",
  field_Config = "config",

  RegPath = "LuaFAR\\LF Search\\",
}

-- Upvalues --
local Sett     = require "far2.settings"
local Utils    = require "far2.utils"
local M        = require "lfs_message"
local MReplace = require "lfs_mreplace"

local SETTINGS_KEY  = "shmuz"
local SETTINGS_NAME = "plugin_lfsearch"
local F = far.Flags
local Field = Sett.field
local EditorAction
local History
local ModuleDir

local function SaveSettings()
  Sett.msave(SETTINGS_KEY, SETTINGS_NAME, History)
end

-- Set the defaults: prioritize safety and "least surprise".
local function NormDataOnFirstRun()
  local data = Field(_Plugin.History, Cfg.field_Main)
  data.bAdvanced          = false
  data.bDelEmptyLine      = false
  data.bDelNonMatchLine   = false
  data.bRepIsFunc         = false
  data.bSearchBack        = false
  --------------------------------
  --data = _Plugin.History["panels"] or {}       --TODO
  --data.sSearchArea        = "FromCurrFolder"   --TODO
end

local function Require (name)
  if Cfg.ReloadOnRequire then package.loaded[name] = nil; end
  return require(name)
end

local function InitUpvalues (_Plugin)
  EditorAction = Require("lfs_editmain").EditorAction
  History = _Plugin.History
  Field(History, Cfg.field_Config)
  ModuleDir = _Plugin.ModuleDir
end

local function MakeAddToMenu (Items)
  return function (aItemText, aFileName, aParam1, aParam2)
    local SepText = type(aItemText)=="string" and aItemText:match("^:sep:(.*)")
    if SepText then
      table.insert(Items, { text=SepText, separator=true })
    elseif type(aFileName)=="string" then
      table.insert(Items, { text=tostring(aItemText),
        filename=ModuleDir..aFileName, param1=aParam1, param2=aParam2 })
    end
  end
end

local function MakeMenuItems (aUserMenuFile)
  local items = {
    {text=M.MMenuFind,             action="search" },
    {text=M.MMenuReplace,          action="replace"},
    {text=M.MMenuRepeat,           action="repeat" },
    {text=M.MMenuRepeatRev,        action="repeat_rev"},
    {text=M.MMenuMultilineReplace, action="mreplace"},
    {text=M.MMenuConfig,           action="config" },
  }
  for i,v in ipairs(items) do
    v.text = "&"..i..". "..v.text
  end
  local Info = win.GetFileInfo(aUserMenuFile)
  if Info and not Info.FileAttributes:find("d") then
    local f = assert(loadfile(aUserMenuFile))
    local env = setmetatable( {AddToMenu=MakeAddToMenu(items)}, {__index=_G} )
    setfenv(f, env)()
  end
  return items
end

local function OpenFromMacro (aItem)
  local Op, Where, Cmd = aItem:match("^([%w_]+):([%w_]+):([%w_]+)")

  if Op=="own" then
    local area = far.MacroGetArea()
    local data = Field(History, Cfg.field_Main)
    data.fUserChoiceFunc = nil
    ----------------------------------------------------------------------------
    if Where=="editor" then
      if area == F.MACROAREA_EDITOR then
        if Cmd=="search" or Cmd=="replace" or Cmd=="config" then
          return EditorAction(Cmd, data, false) and true
        elseif Cmd=="repeat" or Cmd=="repeat_rev" then
          return EditorAction(Cmd, data, false) and false
        elseif Cmd=="mreplace" then
          return MReplace.ReplaceWithDialog(data, true) and true
        end
      end
    ----------------------------------------------------------------------------
    elseif Where=="panels" then
      if area==F.MACROAREA_SHELL or area==F.MACROAREA_TREEPANEL or
         area==F.MACROAREA_QVIEWPANEL or area==F.MACROAREA_INFOPANEL
      then
        if Cmd=="search" then
          local lib = Require("lfs_panels")
          return lib.SearchFromPanel(History) and true
        end
      end
    end
    ----------------------------------------------------------------------------
  end
end

local function export_OpenPlugin (From, Item)
  if not Utils.CheckLuafarVersion(ReqLuafarVersion, M.MMenuTitle) then
    return
  end

  if bit.band(From, F.OPEN_FROMMACRO) ~= 0 then
    if bit.band(From, F.OPEN_FROMMACROSTRING) ~= 0 then
      far.Timer(50, function(h) -- to avoid running from a macro
          h:Close()
          if OpenFromMacro(Item) then SaveSettings() end
        end)
    end
    return
  end

  if From == F.OPEN_EDITOR then
    local hMenu = Field(History, Cfg.field_Menu)
    local items = MakeMenuItems(ModuleDir.."_usermenu.lua")
    local ret, pos = far.Menu( {
      Flags = {FMENU_WRAPMODE=1, FMENU_AUTOHIGHLIGHT=1},
      Title = M.MMenuTitle,
      HelpTopic = "Contents",
      SelectIndex = hMenu.position,
    }, items)
    if ret then
      hMenu.position = pos
      if ret.action then
        local data = Field(History, Cfg.field_Main)
        data.fUserChoiceFunc = nil
        if ret.action == "mreplace" then
          MReplace.ReplaceWithDialog(data, true)
        else
          EditorAction (ret.action, data, false)
        end
      elseif ret.filename then
        assert(loadfile(ret.filename))(ret.param1, ret.param2)
      end
      SaveSettings()
    end

  elseif From == F.OPEN_PLUGINSMENU then
    local lib = Require("lfs_panels")
    if lib.SearchFromPanel(History) then
      SaveSettings()
    end
  end
end

local function export_GetPluginInfo()
  return {
    Flags = F.PF_EDITOR,
    PluginMenuStrings = { M.MMenuTitle },
    SysId = 0x10001,
  }
end

lfsearch.EditorAction = function(aOp, aData)
  assert(type(aOp)=="string", "arg #1: string expected")
  assert(type(aData)=="table", "arg #2: table expected")
  local newdata = {}
  for k,v in pairs(aData) do newdata[k] = v end
  return EditorAction(aOp, newdata, true)
end

lfsearch.MReplaceEditorAction = MReplace.EditorAction

local function SetExportFunctions()
  export.GetPluginInfo = export_GetPluginInfo
  export.OpenPlugin    = export_OpenPlugin
end

local function main()
  if not _Plugin then
    export.OnError = Utils.OnError
    _Plugin = {}
    _Plugin.ModuleDir = far.PluginStartupInfo().ModuleDir
    _Plugin.History = Sett.mload(SETTINGS_KEY, SETTINGS_NAME) or {}
    _Plugin.RegPath = Cfg.RegPath
    package.cpath = _Plugin.ModuleDir .. "?.dl;" .. package.cpath --TODO
    NormDataOnFirstRun()
  end
  SetExportFunctions()
  InitUpvalues(_Plugin)
  far.ReloadDefaultScript = Cfg.ReloadDefaultScript
end

main()
