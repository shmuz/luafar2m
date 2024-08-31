local Info = { --luacheck: no unused
  Author        = "Shmuel Zeigerman";
  Guid          = "E32B39F6-12F5-4F4E-B582-C7166812AA62";
  Started       = "2024-08-30";
  Title         = "ShellCheck in editor";
}

-- Options
local MenuMaxHeight = 8
local SelectLen = 4
-- /Options

local F = far.Flags
local menuflags = bit64.bor(F.FMENU_SHOWAMPERSAND,F.FMENU_WRAPMODE)

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
  local fp = assert(io.open(tmpfile, "w"))
  fp:write(GetEditorText())
  fp:close()

  fp = io.popen("shellcheck -f gcc "..tmpfile)

  -- create menu items
  local maxlen = 0
  local items = {}
  local nErr, nWarn, nNote = 0, 0, 0
  local i = 0
  for ln in fp:lines() do
    local line,col,text = ln:match(".-:(%d+):(%d+):%s*(.+)")
    if line then
      i = i + 1
      items[i] = {text=text; line=line; column=col}
      maxlen = math.max(maxlen, ln:len())
      if     text:find("^error:")   then nErr = nErr + 1
      elseif text:find("^warning:") then nWarn = nWarn + 1
      elseif text:find("^note:")    then nNote = nNote + 1
      end
    end
  end
  fp:close()
  win.DeleteFile(tmpfile)

  -- show either the menu or the success message
  if #items > 0 then
    local props = {
      Title = "ShellCheck"; -- ..luacheck._VERSION;
      Bottom = ("%d errors, %d warnings, %d notes"):format(nErr, nWarn, nNote);
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
  description=Info.Title;
  area="Editor"; key="CtrlShiftF7"; filemask="*.sh";
  action=function() CheckEditor() end;
}
