-- assuming "Show directories first" option is set
-- description="Find an upper non-directory item";
-- area="Shell"; key="CtrlShiftHome";
local function JumpToNonDir()
  local pInfo = panel.GetPanelInfo(1)
  if pInfo then
    local lower, upper = 1, pInfo.ItemsNumber
    while upper-lower >= 2 do -- binary search
      local curr = math.floor((lower+upper)/2)
      local item = panel.GetPanelItem(1,curr)
      if item.FileAttributes:find("d") then lower = curr
      else upper = curr
      end
    end
    panel.RedrawPanel(1,{ CurrentItem=upper; TopPanelItem=upper-8; })
  end
end

local function SmartHome()
  local info, str = editor.GetInfo(), editor.GetString()
  local pos = str.StringText:find("%S") or 1
  editor.SetPosition(nil, pos==info.CurPos and 1 or pos)
  editor.Redraw()
end

local function InsertNewGuid()
  editor.InsertText('"'..win.Uuid(win.Uuid()):upper()..'"', true)
end

local function Calc() require("far2.calc")() end

AddCommand ("luacalc", Calc)
AddCommand ("JumpToNonDir", JumpToNonDir)

AddToMenu ("e", nil, "Home", SmartHome)
AddToMenu ("e", nil, "Ctrl+F11", InsertNewGuid)
AddToMenu ("depv", "Lua Calc", nil, Calc)
