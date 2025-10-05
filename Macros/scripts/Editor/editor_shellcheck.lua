local Info = {
  Author        = "Shmuel Zeigerman";
  Guid          = "E32B39F6-12F5-4F4E-B582-C7166812AA62";
  Started       = "2024-08-30";
  Title         = "ShellCheck in editor";
}

-- Options
local MenuMaxHeight = 8
local MinSelectLen = 4
-- /Options

local SETTINGS_KEY  = "shmuz"
local SETTINGS_NAME = "ShellCheck"
local Conf = mf.mload(SETTINGS_KEY, SETTINGS_NAME) or {}

local F = far.Flags
local MenuFlags = bit64.bor(F.FMENU_SHOWAMPERSAND,F.FMENU_WRAPMODE)
local SC_Version

local function MakeCommandLine()
  local t = { [1] = "shellcheck -f gcc"; }

  if Conf.norc    then table.insert(t, "--norc") end
  if Conf.sourced then table.insert(t, "-a") end
  if Conf.outside then table.insert(t, "-x") end

  local b = Conf.scriptdir
  if type(b)=="string" and b:find("%S") then table.insert(t, '-P "' .. b .. '"') end

  b = ({nil,"sh","bash","dash","ksh"})[Conf.dialect] -- nil is default
  if b then table.insert(t, "-s "..b) end

  b = ({nil,"error","warning","info","style"})[Conf.severity] -- nil is default
  if b then table.insert(t, "-S "..b) end

  -- far.Show(table.concat(t, " "))
  return table.concat(t, " ")
end

local function Get_SC_Version()
  local fp = io.popen("shellcheck --version")
  local txt = fp:read("*all")
  fp.close()
  return txt:match("version:%s*(%S+)")
end

local function CheckEditor()
  SC_Version = SC_Version or Get_SC_Version()
  if not SC_Version then
    far.Message("ShellCheck not found, is it installed?", "Error", nil, "w")
    return
  end

  local eInfo = editor.GetInfo()
  if bit64.band(eInfo.CurState, F.ECSTATE_SAVED) == 0 then
    if not editor.SaveFile() then
      far.Message("Could not save the file", Info.Title, nil, "w")
      return
    end
  end

  local fp = io.popen(MakeCommandLine()..' "'..eInfo.FileName..'"')

  -- create menu items
  local maxlen = 0
  local items = {}
  local nErr, nWarn, nNote = 0, 0, 0
  for ln in fp:lines() do
    local fname,line,col,text = ln:match("(.-):(%d+):(%d+):%s*(.+)")
    if fname then
      local item = { fname=fname; text=text; line=tonumber(line); column=tonumber(col); }
      table.insert(items, item)
      maxlen = math.max(maxlen, text:len())
      if     text:find("^note:")    then nNote = nNote + 1
      elseif text:find("^warning:") then nWarn = nWarn + 1
      elseif text:find("^error:")   then nErr = nErr + 1
      end
    end
  end
  fp:close()

  -- show either the menu or the success message
  if #items > 0 then
    local props = {
      Title = "ShellCheck " .. SC_Version;
      Bottom = ("%d errors, %d warnings, %d notes"):format(nErr, nWarn, nNote);
      Flags = MenuFlags;
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

      -- ad hoc evaluation of selection length
      local str = editor.GetString(nil, info.line, 3)
      local from,to = str:find("[%w_}]+", info.column)
      local selLen = from and (from-info.column <= MinSelectLen) and (to-info.column+1) or 1
      selLen = math.max(selLen, MinSelectLen)

      editor.Select(nil, "BTYPE_STREAM", info.line, info.column, selLen, 1)
      editor.Redraw()
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

local function Configure()
  local sd = require "far2.simpledialog"
  local Items = {
    guid="50E0F580-85CC-4244-A352-62EF01893EE6";
    -- help = "Contents";
    width=60;
    { tp="dbox"; text=Info.Title; },
    { tp="chbox"; name="norc";    text="&Don't look for .shellcheckrc files";  },
    { tp="chbox"; name="sourced"; text="&Include warnings from sourced files"; },
    { tp="chbox"; name="outside"; text="&Allow 'source' outside of FILES";     },

    { tp="sep"; },
    { tp="text"; text="&Sourced files' path:"; },
    { tp="edit"; name="scriptdir"; hist="shellcheck_scriptdir"; },

    { tp="sep"; },
    {tp="text"; text="Shell &dialect:"; },
    {tp="combobox"; dropdown=1; name="dialect"; width=16; val=1;
      list = {{Text="default"},{Text="sh"},{Text="bash"},{Text="dash"},{Text="ksh"}};
      },

    { tp="sep"; },
    {tp="text"; text="&Minimum severity of errors to consider:"; },
    {tp="combobox"; dropdown=1; name="severity"; width=16; val=1;
      list = {{Text="default"},{Text="error"},{Text="warning"},{Text="info"},{Text="style"}};
      },

    { tp="sep"; },
    { tp="butt"; centergroup=1; default=1; text="OK";    },
    { tp="butt"; centergroup=1; cancel=1; text="Cancel"; },
  }

  local Dlg = sd.New(Items)
  Dlg:LoadData(Conf)
  local out = Dlg:Run()
  if out then
    Dlg:SaveData(out, Conf)
    mf.msave(SETTINGS_KEY, SETTINGS_NAME, Conf)
  end
end

Macro {
  id="9070169A-19C4-4A2C-849A-16563837BD3B";
  description=Info.Title;
  area="Editor"; key="CtrlShiftF7"; filemask="*.sh";
  action=function() CheckEditor() end;
}

MenuItem {
  description=Info.Title;
  menu="Config"; area="Shell";
  guid="DBA6B751-9233-4078-8500-F358F7F4B671";
  text=Info.Title;
  action=Configure;
}
