-- Started: 2024-05-24
-- This utility makes possible switch back and forth between 2 screens.
--   1. Press F12 to see the list of all screens.
--   2. From the macro browser press Enter on the item whose key is "0_Toggle_Screens".
--   3. The Settings dialog appears. Enter the desired screen numbers and press "Enable" button.
--   4. Now you are able to toggle between 2 screens with CtrlTab presses.

local Enable
local Screen1, Screen2

local Title = "Toggle between 2 screens"

local function Settings()
  local sd = require "far2.simpledialog"
  local items = {
    width=50;
    {tp="dbox"; text=Title; },
    {tp="text"; text="Screen 1:" },
    {tp="fixedit"; mask="99"; width=3; name="scr1"; y1=""; x1=15; text=Screen1 or 0; },
    {tp="text"; text="Screen 2:" },
    {tp="fixedit"; mask="99"; width=3; name="scr2"; y1=""; x1=15; text=Screen2 or 0; },
    {tp="sep"; },
    {tp="butt"; centergroup=1; text="&Enable";  name="enable"; default=1; },
    {tp="butt"; centergroup=1; text="&Disable"; name="disable"; },
  }
  local Dlg = sd.New(items)
  local Pos = Dlg:Indexes()
  local out, pos = Dlg:Run()
  if out then
    Screen1 = tonumber(out.scr1) or 0
    Screen2 = tonumber(out.scr2) or 0
    Enable = (pos == Pos.enable)
  end
end

Macro { -- to be called from Macro Browser
  description="Turn ON/OFF toggle 2 selected screens";
  area="Common"; key="0_Toggle_Screens";
  action=function() Settings() end;
}

Macro {
  description=Title;
  area="Common"; key="CtrlTab";
  condition=function(key)
    return Enable and Screen1 and Screen2
  end;
  action=function()
    local Pos = actl.GetWindowInfo().Pos - 1
    Pos = Pos==Screen1 and Screen2 or Screen1
    if 1 ~= actl.SetCurrentWindow(Pos + 1, true) then
      Settings()
    end
  end;
}
