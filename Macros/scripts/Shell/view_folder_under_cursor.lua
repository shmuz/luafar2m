-- started: 2021-09-25
-- https://forum.ru-board.com/topic.cgi?forum=5&topic=50439&start=3180#17
-- https://forum.farmanager.com/viewtopic.php?t=12619

-- Settings -------------------------------------------------------
local Key_manual   = "AltShiftF3"
local Key_toggle   = "CtrlShiftQ"
local Key_navigate = "Down Up PgDn PgUp Left Right Home End Enter"
local Key_off      = "Tab"
-------------------------------------------------------------------

local JoinPath = win.JoinPath
local Qmode = false -- Quick folder view mode

local function is_active_dir()
  return APanel.Folder or APanel.Current:find("/")
end

local function set_passive_path()
  Far.DisableHistory(0x02)
  local path, file = APanel.Current:match("(.+/)(.*)")
  if APanel.Folder then
    if path then                        ---- directory on TmpPanel
      Panel.SetPath(1, APanel.Current)
    elseif APanel.Path ~= "" then       ---- directory on a regular panel
      Panel.SetPath(1, JoinPath(APanel.Path, APanel.Current))
    end
  elseif path then                      ---- file on TmpPanel
    Panel.SetPath(1, path, file)
  elseif APanel.Path ~= "" then         ---- file on a regular panel
    Panel.SetPath(1, JoinPath(APanel.Path, APanel.Current))
  end
end

Macro {
  id="6C01D019-6C7E-4AB8-8F7D-E1D5ACC3CE9D";
  description="Quick folder view: manual";
  area="Shell"; key=Key_manual;
  flags="NoPluginPanels NoFiles";
  action=function() set_passive_path() end;
}

Macro {
  id="BB357E70-621E-410B-BA42-74228F70F1E6";
  description="Quick folder view: toggle ON/OFF";
  area="Shell"; key=Key_toggle;
  action=function()
    Qmode = not Qmode
    if Qmode and is_active_dir() then
      set_passive_path()
      panel.RedrawPanel(nil, 0)
    end
    far.Message("Quick view mode is "..(Qmode and "ON" or "OFF"), "", "")
    win.Sleep(600)
    far.AdvControl("ACTL_REDRAWALL")
  end;
}

Macro {
  id="5397310D-BB80-467C-9B0A-CF5D41455521";
  description="Quick folder view: navigate";
  area="Shell"; key=Key_navigate;
  condition=function()
    return Qmode and CmdLine.Empty
  end;
  action=function()
    Keys(akey(1))
    if is_active_dir() then set_passive_path() end
  end;
}

Macro {
  id="1D1EF06D-C58B-4705-9EB8-0C30C5F948A7";
  description="Quick folder view: turn off";
  area="Shell"; key=Key_off;
  condition=function() return Qmode end;
  action=function()
    Qmode = false
    Keys(akey(1))
  end;
}
