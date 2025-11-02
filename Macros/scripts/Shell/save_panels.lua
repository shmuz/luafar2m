------------------------------------------------------------------------------------------------
-- Description:      Save panel directories on Far exit, restore on Far start
--                   (for those who keep Auto Save Setup off).
-- Started:          2025-11-01
-- Author:           Shmuel Zeigerman
-- Language:         Lua 5.1
-- Portability:      far3 (>= 6139), far2m
-- Far plugin:       LuaMacro
------------------------------------------------------------------------------------------------

local osWindows = "\\" == string.sub(package.config,1,1)
if osWindows then
  local farbuild = select(4, far.AdvControl("ACTL_GETFARMANAGERVERSION", true))
  if farbuild < 6139 then return end
end

local set_key, set_name = "temp", "PanelsOnExitFar"

local function Save()
  mf.msave(set_key, set_name,
    { ALeft = APanel.Left; APath = APanel.Path0; PPath = PPanel.Path0; })
end

Event {
  description="Save panels on Far exit";
  group = osWindows and "ExitFAR" or "MayExitFAR"; -- not ready for ExitFAR on far2m
  action=function(reload)
    if osWindows then
      if not reload then Save() end
    else
      Save(); return true;
    end
  end;
}

Macro {
  id="28F4711F-9631-4640-A227-89870C46499B";
  description="Restore panels on Far start";
  area="Shell"; flags="RunAfterFARStart";
  action=function()
    local t = mf.mload(set_key, set_name)
    if type(t) ~= "table" then return end
    panel.SetPanelDirectory(nil, 0, t.PPath)
    panel.SetPanelDirectory(nil, 1, t.APath)
    if APanel.Left ~= t.ALeft then Keys("CtrlU") end
  end;
}
