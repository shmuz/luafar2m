------------------------------------------------------------------------------------------------
-- Started:                 2013-01-24
-- Author:                  Shmuel Zeigerman
-- Published:               2013-01-24 (https://forum.farmanager.com/viewtopic.php?f=60&t=7654)
-- Language:                Lua 5.1
-- Minimal Far version:     3.0.3300
-- Depends on:              far2/simpledialog.lua (on Lua package.path)
------------------------------------------------------------------------------------------------

local function InsertMacro()
  local sDialog = require("far2.simpledialog")
  local F = far.Flags

  local data = {
    guid="7feed31e-ce59-4f94-9dd9-7da619b4ef00",
    width=73,

    { tp="dbox", text="Macro settings" },
    { tp="text", text="Description:" },
    { tp="edit", name="sDescr", hist="MacroDescription" },
    { tp="sep" },

    { tp="chbox", text="Allo&w screen output while executing macro", name="bOutputEnb"},
    { tp="chbox", text="Execute after FAR &start",                   name="bAfterFarStart"},
    { tp="chbox", text="Do not send &keys to plugins",               name="bNoSendToPlugins"},
    { tp="sep" },

    { tp="chbox", text="&ActivePanel",         name="bActivePanel" },
    { tp="chbox", text="P&luginPanel",         name="APluginPanel",      x1=7,  tristate=1, val=2, disable=1 },
    { tp="chbox", text="Execute for &folders", name="AExecForFolders",   x1=7,  tristate=1, val=2, disable=1 },
    { tp="chbox", text="Se&lection present",   name="ASelectionPresent", x1=7,  tristate=1, val=2, disable=1 },

    { tp="chbox", text="&PassivePanel",        name="bPassivePanel",     ystep=-3, x1=37 },
    { tp="chbox", text="P&luginPanel",         name="PPluginPanel",      x1=39, tristate=1, val=2, disable=1 },
    { tp="chbox", text="Execute for &folders", name="PExecForFolders",   x1=39, tristate=1, val=2, disable=1 },
    { tp="chbox", text="Se&lection present",   name="PSelectionPresent", x1=39, tristate=1, val=2, disable=1 },
    { tp="sep" },

    { tp="chbox", text="Empty &command line",      name="bEmptyComLine",    tristate=1, val=2 },
    { tp="chbox", text="Selection &block present", name="bSelBlockPresent", tristate=1, val=2 },
    { tp="sep" },

    { tp="butt", text="OK",     default=1, centergroup=1 },
    { tp="butt", text="Cancel", cancel=1,  centergroup=1 },
  }
  data.proc = function (hDlg,Msg,Param1,Param2)
    if Msg == F.DN_BTNCLICK then
      local item = data[Param1]
      if item.name=="bActivePanel" or item.name=="bPassivePanel" then
        local enable = far.SendDlgMessage(hDlg,"DM_GETCHECK",Param1)
        far.SendDlgMessage(hDlg,"DM_ENABLE",Param1+1,enable)
        far.SendDlgMessage(hDlg,"DM_ENABLE",Param1+2,enable)
        far.SendDlgMessage(hDlg,"DM_ENABLE",Param1+3,enable)
      end
    end
  end;

  local out = sDialog.Run(data)
  if not out then return; end

  local tFlags, num = {}, 0
  local function append(str) num=num+1; tFlags[num]=str; end

  if out.bOutputEnb       then append("EnableOutput") end
  if out.bAfterFarStart   then append("RunAfterFARStart") end
  if out.bNoSendToPlugins then append("NoSendKeysToPlugins") end

  if out.bActivePanel then
    if     out.APluginPanel==false then append("NoPluginPanels")
    elseif out.APluginPanel==true  then append("NoFilePanels")
    end
    if     out.AExecForFolders==false then append("NoFolders")
    elseif out.AExecForFolders==true  then append("NoFiles")
    end
    if     out.ASelectionPresent==false then append("NoSelection")
    elseif out.ASelectionPresent==true  then append("Selection")
    end
  end

  if out.bPassivePanel then
    if     out.PPluginPanel==false then append("NoPluginPPanels")
    elseif out.PPluginPanel==true  then append("NoFilePPanels")
    end
    if     out.PExecForFolders==false then append("NoPFolders")
    elseif out.PExecForFolders==true  then append("NoPFiles")
    end
    if     out.PSelectionPresent==false then append("NoPSelection")
    elseif out.PSelectionPresent==true  then append("PSelection")
    end
  end

  if     out.bEmptyComLine==false then append("NotEmptyCommandLine")
  elseif out.bEmptyComLine==true  then append("EmptyCommandLine")
  end

  if     out.bSelBlockPresent==false then append("NoEVSelection")
  elseif out.bSelBlockPresent==true  then append("EVSelection")
  end

  local tResult = ( [[
Macro {
  description=%q;
  area=""; key="";
  flags=%q;
  id=%q;
  -- priority=50; condition=function(key) end;
  action=function()
  end;
}
]] ) : format(out.sDescr, table.concat(tFlags," "), win.Uuid(win.Uuid()):upper())

  print(tResult)
end

Macro {
  description="Insert Far Manager Macro";
  area="Editor"; key="CtrlF11";
  action=InsertMacro;
}
