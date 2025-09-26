-------------------------------------------------------------------------------
-- luacheck: globals _Plugin

-- CONFIGURATION : keep it at the file top !!
local Cfg = {
  ReloadDefaultScript = true, -- Default script will be recompiled and run every time
                              -- Open is called: set true for
                              -- debugging, false for normal use;

  ReloadOnRequire = true, -- Reload lua libraries each time they are require()d:
                          -- set true for libraries debugging, false for normal use;
}

-- UPVALUES : keep them above all function definitions !!
local SETTINGS_KEY  = nil
local SETTINGS_NAME = "settings"

local Sett  = require "far2.settings"
local Utils = require "far2.utils"

local F = far.Flags
local field = Sett.field
local History, Env

local function Require (name)
  package.loaded[name] = nil
  return require (name)
end

function export.Open (From, _Id, Item)
  if From == F.OPEN_ANALYSE then
    return Env:Open(From, Item)

  elseif From == F.OPEN_COMMANDLINE then
    return Env:Open(From, Item)

  elseif From == F.OPEN_PLUGINSMENU then
    return Env:Open(From, Item)

  elseif From == F.OPEN_DISKMENU or From == F.OPEN_FINDLIST then
    return Env:NewPanel()

  end
end

function export.Analyse (Data)
  return Env:Analyse (Data)
end

function export.GetPluginInfo()
  local Info = Env:GetPluginInfo()
  --Info.Flags.preload = true
  return Info
end

function export.Configure (ItemNumber)
  return Env:Configure()
end

function export.ExitFAR()
  Env:ExitFAR()
  History.Env = Env
  Sett.msave(SETTINGS_KEY, SETTINGS_NAME, History)
end

local function InitUpvalues (plugin)
  History = plugin.History
  Require = Cfg.ReloadOnRequire and Require or require
  far.ReloadDefaultScript = Cfg.ReloadDefaultScript
  local tp = Require "far2.tmppanel"
  tp.SetMessageTable(require "tmpp_message") -- message localization support
  plugin.tmppanel = plugin.tmppanel or tp
  plugin.tmppanel.Env = tp.NewEnv (plugin.tmppanel.Env or field(History, "Env"))
  Env = plugin.tmppanel.Env
  for _, name in ipairs {
    "ClosePanel",
    "GetFindData",
    "GetOpenPanelInfo",
    "ProcessPanelEvent",
    "ProcessKey",
    "PutFiles",
    "SetDirectory",
    "SetFindList" }
  do
    export[name] = tp.Panel[name]
  end
  tp.Panel.ConfigFunction = export.Configure
end

local function main()
  if not _Plugin then
    export.OnError = Utils.OnError
    _Plugin = {}
    _Plugin.ShareDir = far.PluginStartupInfo().ShareDir
    _Plugin.History = Sett.mload(SETTINGS_KEY, SETTINGS_NAME) or {}
  end
  InitUpvalues(_Plugin)
end

main()
