-- Started: 2024-05-24
-- This utility makes possible to switch back and forth between 2 screens.
--   1. Envoke the macro.
--   2. The Settings dialog appears. Select the desired screens and press "Enable" button.
--   3. Toggle between 2 screens with CtrlTab.

local Enable
local Screen1, Screen2

local Title = "Toggle between 2 screens"

local function Settings()
  local sd = require "far2.simpledialog"
  local items = {
    width=Far.Width; -- maximal width to avoid scrolling file names
    {tp="dbox"; text=Title; },
    {tp="text"; text="Screen 1:" },
    {tp="combobox"; dropdown=1; y1=""; x1=15; name="scr1"; list={}; val=Screen1 or 1; },
    {tp="text"; text="Screen 2:" },
    {tp="combobox"; dropdown=1; y1=""; x1=15; name="scr2"; list={}; val=Screen2 or 1; },
    {tp="sep"; },
    {tp="butt"; centergroup=1; text="&Enable";  name="enable"; default=1; },
    {tp="butt"; centergroup=1; text="&Disable"; name="disable"; },
    {tp="butt"; centergroup=1; text="&Cancel"; cancel=1; },
  }

  local Dlg = sd.New(items)
  local Pos, Elem = Dlg:Indexes()

  local wcount = actl.GetWindowCount()
  if Elem.scr1.val > wcount then Elem.scr1.val = 1 end -- avoid combobox showing empty line
  if Elem.scr2.val > wcount then Elem.scr2.val = 1 end -- ditto

  for k=1,wcount do -- fill comboboxes
    local inf = actl.GetWindowInfo(k)
    local t = { Text = ("%-10s%s"):format(inf.TypeName, inf.Name) }
    table.insert(Elem.scr1.list, t)
    table.insert(Elem.scr2.list, t)
  end

  local out, pos = Dlg:Run()
  if out then
    Screen1 = out.scr1
    Screen2 = out.scr2
    Enable = (pos == Pos.enable)
    if Enable then actl.SetCurrentWindow(Screen1) end
  end
end

Macro {
  description="Turn ON/OFF toggle 2 selected screens";
  area="Common"; key="CtrlAltJ";
  action=function() Settings() end;
}

Macro {
  description=Title;
  area="Common"; key="CtrlTab";
  condition=function(key)
    return Enable and Screen1 and Screen2
  end;
  action=function()
    local pos = actl.GetWindowInfo().Pos
    pos = pos==Screen1 and Screen2 or Screen1
    if 0 == actl.SetCurrentWindow(pos) then
      Settings()
    end
  end;
}
