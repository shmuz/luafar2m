-------- Settings
local Title    = "ShellCheck in editor"
local Info = { --luacheck: no unused
  Author        = "Shmuel Zeigerman";
  Guid          = "E32B39F6-12F5-4F4E-B582-C7166812AA62";
  MinFarVersion = "3.0.3300";
  Started       = "2024-08-30";
  Title         = Title;
}
-------- /Settings

local OptFileName = ".luacheckrc"
local MenuMaxHeight = 8
local SelectLen = 4

local F = far.Flags

local menuflags = bit64.bor(F.FMENU_SHOWAMPERSAND,F.FMENU_WRAPMODE)
--if FarBuild >= 5505 then
--  menuflags = bit64.bor(menuflags, F.FMENU_SHOWSHORTBOX, F.FMENU_NODRAWSHADOW)
--end

local function traverse(path)
  return function(_, curpath)
    return curpath:match("^(.*/).-/")
  end, nil, path.."/"
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

local function GetOptions()
  local options = {}
--  local edtname = editor.GetFileName()
--  if edtname then
--    for dir in traverse(edtname) do
--      local f = loadfile(dir..OptFileName)
--      if f then
--        local env = {}
--        setfenv(f, env)("far") -- the argument tells the config. file it is run from Far environment
--        if env.luafar or env.lf4ed or env.luamacro then
--          local cfg = dofile( os.getenv("HOME").."/luacheck_config.lua" )
--          local luafar = env.luafar and cfg.luafar
--          local lf4 = env.lf4ed and cfg.lf4ed
--          local luamacro = env.luamacro and cfg.luamacro
--          for _,field in ipairs {"globals","read_globals"} do
--            options[field] = merge_field(field, luafar, lf4, luamacro)
--          end
--          env.luafar, env.lf4ed, env.luamacro = nil, nil, nil
--        end
--        for k,v in pairs(env) do options[k]=v; end
--        break
--      end
--    end
--  end
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
  local tmpfile = far.InMyTemp("to-check.sh")
  local fp, msg = io.open(tmpfile, "w")
  if fp == nil then
    far.Message(msg, "Error", nil, "w")
    return
  end
  fp:write(GetEditorText())
  fp:close()

  fp = io.popen("shellcheck -f gcc "..tmpfile)

  -- create menu items
  local maxlen = 0
  local items = {}
  local i = 0
  for line in fp:lines() do
    local ln,pos,msg = line:match(".-:(%d+):(%d+):%s*(.+)")
    if ln then
      i = i + 1
      items[i] = {text=msg; line=ln; column=pos}
      maxlen = math.max(maxlen, ln:len())
    end
  end
  fp:close()
  win.DeleteFile(tmpfile)

  -- show either the menu or the success message
  if #items > 0 then
    local props = {
      Title = "ShellCheck"; -- ..luacheck._VERSION;
      --Bottom = ("%d warnings, %d errors, %d fatals"):format(report.warnings,report.errors,report.fatals);
      Flags = menuflags;
      MaxHeight = math.min(#items, MenuMaxHeight);
      SelectIndex = 1;
    }
    local brkeys = { -- scroll the menu + update editor position and selection
      {BreakKey="DOWN"}, {BreakKey="UP"}, {BreakKey="LEFT"}, {BreakKey="RIGHT"},
      {BreakKey="HOME"}, {BreakKey="END"},
    }

    local function show_found()
      local R = actl.GetFarRect()
      props.Y = (R.Bottom-R.Top+1) - (props.MaxHeight+3)
      props.X = (R.Right-R.Left+1) - (maxlen+6)
      local info = items[props.SelectIndex]
      local topline = math.max(1, info.line - 10)
      editor.SetPosition(nil, info.line, info.column, nil, topline)
      editor.Select(nil, "BTYPE_STREAM", info.line, info.column, SelectLen, 1)
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
    far.Message("OK", "ShellCheck", "")
    win.Sleep(600)
    editor.Redraw()
  end
end

Macro {
  description=Title;
  area="Editor"; key="CtrlShiftF7"; filemask="*.sh";
  action=function() CheckEditor() end;
}
