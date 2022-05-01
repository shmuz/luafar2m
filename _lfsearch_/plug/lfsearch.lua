-- luacheck: globals lfsearch

local F = far.Flags
local ReqLuafarVersion = "2.9"
_G.lfsearch = {}

local RegPath       = "LuaFAR\\LF Search\\"
local SETTINGS_KEY  = "shmuz"
local SETTINGS_NAME = "plugin_lfsearch"


-- Set the defaults: prioritize safety and "least surprise".
local function NormDataOnFirstRun()
  local data = _Plugin.History["main"]
  data.bAdvanced          = false
  data.bDelEmptyLine      = false
  data.bDelNonMatchLine   = false
  data.bRepIsFunc         = false
  data.bSearchBack        = false
  data.bUseFileFilter     = false
  --------------------------------
  --data = _Plugin.History["panels"] or {}       --TODO
  --data.sSearchArea        = "FromCurrFolder"   --TODO
end


local function FirstRunActions()
  local Sett  = require "far2.settings"
  local hist = Sett.mload(SETTINGS_KEY, SETTINGS_NAME) or {}
  Sett.field(hist, "config")
  Sett.field(hist, "main")
  Sett.field(hist, "menu")
  _Plugin = {
    ModuleDir = far.PluginStartupInfo().ModuleDir;
    OriginalRequire = require;
    History = hist;
    Repeat = {};
    RegPath = RegPath;
  }
  NormDataOnFirstRun()
end


local FirstRun = not _Plugin
if FirstRun then FirstRunActions() end


local libUtils   = require "far2.utils"
local Sett       = require "far2.settings"
local EditMain   = require "lfs_editmain"
local Editors    = require "lfs_editors"
local M          = require "lfs_message"
local MReplace   = require "lfs_mreplace"
local Panels     = require "lfs_panels"

local History      = _Plugin.History
local ModuleDir    = _Plugin.ModuleDir
local EditorAction = EditMain.EditorAction


local function SaveSettings()
  Sett.msave(SETTINGS_KEY, SETTINGS_NAME, History)
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


local function ForcedRequire (name)
  package.loaded[name] = nil
  return _Plugin.OriginalRequire(name)
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


local function OpenFromMacro (Op, Where, Cmd)
  if Op=="own" then
    local area = far.MacroGetArea()
    local data = History["main"]
    data.fUserChoiceFunc = nil
    ----------------------------------------------------------------------------
    if Where=="editor" then
      if area == F.MACROAREA_EDITOR then
        if Cmd=="search" or Cmd=="searchword" or Cmd=="searchword_rev" or Cmd=="replace" or Cmd=="config" then
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
          return Panels.SearchFromPanel(data) and true
        end
      end
    end
    ----------------------------------------------------------------------------
  end
end


export.OnError = libUtils.OnError
export.ProcessEditorEvent = Editors.ProcessEditorEvent


function export.OpenPlugin (aFrom, aItem)
  if not libUtils.CheckLuafarVersion(ReqLuafarVersion, M.MMenuTitle) then
    return
  end

  if bit.band(aFrom, F.OPEN_FROMMACRO) ~= 0 then
    if bit.band(aFrom, F.OPEN_FROMMACROSTRING) ~= 0 then
      local Op, Where, Cmd = aItem:match("^([%w_]+):([%w_]+):([%w_]+)")
      if Op then
        if Cmd=="search" or Cmd=="replace" or Cmd=="mreplace" then
          far.Timer(50, function(h) -- operations with a dialog: avoid running from a macro
              h:Close()
              if OpenFromMacro(Op, Where, Cmd) then SaveSettings() end
            end)
        else -- no dialog: execute directly from macro
          if OpenFromMacro(Op, Where, Cmd) then SaveSettings() end
        end
      end
    end
    return
  end

  if aFrom == F.OPEN_EDITOR then
    local hMenu = History["menu"]
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
        local data = History["main"]
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

  elseif aFrom == F.OPEN_COMMANDLINE then
    local _, commandTable = libUtils.LoadUserMenu("_usermenu.lua")
    return libUtils.OpenCommandLine(aItem, commandTable, nil)

  elseif aFrom == F.OPEN_PLUGINSMENU then
    local data = History["main"]
    if Panels.SearchFromPanel(data) then
      SaveSettings()
    end
  end
end


function export.GetPluginInfo()
  return {
    Flags = F.PF_EDITOR;
    PluginMenuStrings = { M.MMenuTitle };
    SysId = 0x10001;
    CommandPrefix = "lfs";
  }
end


lfsearch.MReplaceEditorAction = MReplace.EditorAction
lfsearch.MReplaceDialog = MReplace.ReplaceWithDialog


function lfsearch.EditorAction (aOp, aData)
  assert(type(aOp)=="string", "arg #1: string expected")
  assert(type(aData)=="table", "arg #2: table expected")
  local newdata = {}
  for k,v in pairs(aData) do newdata[k] = v end
  return EditorAction(aOp, newdata, true)
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


function lfsearch.SearchFromPanel (data)
  return Panels.SearchFromPanel(data)
end
