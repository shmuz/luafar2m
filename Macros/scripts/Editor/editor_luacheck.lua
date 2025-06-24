------------------------------------------------------------------------------------------------
-- Started:                 2020-09-13
-- Author:                  Shmuel Zeigerman
-- Language:                Lua 5.1
-- Portability:             far3 (>= 3300), far2m
-- Far plugin:              LuaMacro, LF4Editor
-- Depends on:              Lua module 'luacheck'
------------------------------------------------------------------------------------------------

-------- Settings
local MacroKey = "CtrlShiftF7"
local Title    = "Luacheck in editor"
-------- /Settings

local dirsep = package.config:sub(1,1)
local osWin = (dirsep == "\\")

local OptFileName = ".luacheckrc"
local MenuMaxHeight = 5

local F = far.Flags

local menuflags = bit64.bor(F.FMENU_SHOWAMPERSAND, F.FMENU_WRAPMODE,
  F.FMENU_SHOWSHORTBOX or 0, F.FMENU_NODRAWSHADOW or 0)

local function traverse(path)
  local pattern = ("^(.*SEP).-SEP"):gsub("SEP", dirsep)
  return function(_, curpath)
    return curpath:match(pattern)
  end, nil, path..dirsep
end

-- @param field : "globals", "read_globals", etc., i.e. fields used in .luacheckrc files
-- @param ...   : tables - "libraries" read from .luacheckrc files
local function merge_field(field, ...)
  local trg = {}
  for k=1,select("#", ...) do
    local lib = select(k, ...)
    local src = lib and lib[field]
    if src then
      for m,v in pairs(src) do trg[m]=v; end
    end
  end
  return trg
end

local function GetConfig()
  if osWin then
    return require "far2.luacheck_config"
  else
    return dofile(win.JoinPath(far.GetMyHome(), "luacheck_config.lua")) -- luacheck: ignore 143 (undef. field GetMyHome)
  end
end

local function GetOptions()
  local options = {}
  local edtname = editor.GetFileName()
  if edtname then
    for dir in traverse(edtname) do
      local f = loadfile(dir..OptFileName)
      if f then
        local env = {}
        setfenv(f, env)("far") -- the argument tells the config. file it is run from Far environment
        if env.luafar or env.lf4ed or env.luamacro then
          local cfg = GetConfig()
          local luafar = env.luafar and cfg.luafar
          local lf4 = env.lf4ed and cfg.lf4ed
          local luamacro = env.luamacro and cfg.luamacro
          for _,field in ipairs {"globals","read_globals"} do
            options[field] = merge_field(field, luafar, lf4, luamacro)
          end
          env.luafar, env.lf4ed, env.luamacro = nil, nil, nil
        end
        for k,v in pairs(env) do options[k]=v; end
        break
      end
    end
  end
  return options
end

local function GetEditorText()
  local einfo = editor.GetInfo()
  local arr = {}
  for i=1,einfo.TotalLines do
    arr[i] = editor.GetString(nil,i).StringText
  end
  return table.concat(arr,"\n")
end

local function CheckEditor()
  local luacheck = require "luacheck"
  local report = luacheck.get_report(GetEditorText())
  report = luacheck.process_reports({report}, GetOptions())
  -- create menu items
  local maxlen = 0
  local items = {}
  for i,v in ipairs(report[1]) do
    local str = ("[%s] %s"):format(v.code, luacheck.get_message(v))
    items[i] = {text=str; info=v;}
    maxlen = math.max(maxlen, str:len())
  end
  -- show either the menu or the success message
  if #items > 0 then
    local props = {
      Title = "Luacheck "..luacheck._VERSION;
      Bottom = ("%d warnings, %d errors, %d fatals"):format(report.warnings,report.errors,report.fatals);
      Flags = menuflags;
      MaxHeight = math.min(#items, MenuMaxHeight);
      SelectIndex = 1;
    }
    local brkeys = { -- scroll the menu + update editor position and selection
      {BreakKey="DOWN"}, {BreakKey="UP"}, {BreakKey="LEFT"}, {BreakKey="RIGHT"},
      {BreakKey="HOME"}, {BreakKey="END"},
    }

    local function show_found()
      local R = far.AdvControl("ACTL_GETFARRECT")
      props.Y = (R.Bottom-R.Top+1) - (props.MaxHeight+3)
      props.X = (R.Right-R.Left+1) - (maxlen+6)
      local info = items[props.SelectIndex].info
      local topline = math.max(1, info.line - 10)
      editor.SetPosition(nil, info.line, info.column, nil, topline)
      editor.Select(nil, "BTYPE_STREAM", info.line, info.column, info.end_column-info.column+1, 1)
      editor.Redraw() -- required for Far < 3.0.4813 (and makes no change for newer builds)
    end

    -- menu loop
    while true do
      show_found()
      local item,pos = far.Menu(props, items, brkeys)
      if item then
        local bk = item.BreakKey
        if bk=="DOWN" then
          props.SelectIndex = pos == #items and 1 or pos+1
        elseif bk=="UP" then
          props.SelectIndex = pos == 1 and #items or pos-1
        elseif bk=="LEFT" or bk=="HOME" then
          props.SelectIndex = 1
        elseif bk=="RIGHT" or bk=="END" then
          props.SelectIndex = #items
        else -- Enter pressed
          props.SelectIndex = pos
          show_found()
          break
        end
      else
        break
      end
    end
  else
    far.Message("OK", "Luacheck", "")
    win.Sleep(600)
    editor.Redraw()
  end
end

if Macro then
  Macro {
    id="80C371AF-8850-428A-A0AA-D8DD166796D8";
    description=Title;
    area="Editor"; key=MacroKey; filemask="*.lua";
    action=function() CheckEditor() end;
  }
else
  CheckEditor()
end
