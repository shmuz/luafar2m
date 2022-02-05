-------------------------------------------------------------------------------
-- Requirements: Lua 5.1, FAR 1.70.
-------------------------------------------------------------------------------

-- CONFIGURATION : keep it at the file top !!
local Cfg = {
  ReloadDefaultScript = true, -- Default script will be recompiled and run every time
                              -- OpenPlugin/OpenFilePlugin are called: set true for
                              -- debugging, false for normal use;

  ReloadOnRequire = true, -- Reload lua libraries each time they are require()d:
                          -- set true for libraries debugging, false for normal use;

  UseStrict = true, -- Use require 'strict'
}

-- UPVALUES : keep them above all function definitions !!
local Utils = require "far2.utils"
local F = far.Flags
local History, Env

local function Require (name)
  package.loaded[name] = nil
  return require (name)
end

function export.OpenPlugin (From, Item)
  if From == F.OPEN_PLUGINSMENU then
    return Env:OpenPlugin (From, Item)

  elseif From == F.OPEN_DISKMENU or From == F.OPEN_FINDLIST then
    return Env:NewPanel()

  else
    return Env:OpenPlugin(From, Item)
  end
end

function export.OpenFilePlugin (Name, Data)
  return Env:OpenFilePlugin (Name, Data)
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
  History.Data.Env = Env
  History:save()
end

local function InitUpvalues (_Plugin)
  History = _Plugin.History

  if Cfg.UseStrict then require "strict" end
  Require = Cfg.ReloadOnRequire and Require or require
  -----------------------------------------------------------------------------
  far.ReloadDefaultScript = Cfg.ReloadDefaultScript
  -----------------------------------------------------------------------------
  local tmppanel = Require "far2.tmppanel"
  far.tmppanel = far.tmppanel or tmppanel
  far.tmppanel.Env = tmppanel.NewEnv (far.tmppanel.Env or History:field("Env"))
  Env = far.tmppanel.Env
  for name, func in pairs (tmppanel.ListExportedFunctions()) do
    export[name] = func
  end
end

local function main()
  if not _Plugin then
    _Plugin = Utils.InitPlugin("LuaFAR TmpPanel")
  end
  InitUpvalues(_Plugin)
end

main()
