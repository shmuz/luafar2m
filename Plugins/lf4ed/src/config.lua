-- file created: 2008-12-18

local sd = require "far2.simpledialog"
local M = require "lf4ed_message"
local F = far.Flags

local function ExecuteDialog (aData)
  local Items = {
    width=54;
    help="PluginConfig";
    guid="0F5573D7-FD25-408D-8A8A-E917C0CA14DE";

    {tp="dbox";  text=M.MPluginSettings;},
    {tp="chbox"; text=M.MReloadDefaultScript;     name="ReloadDefaultScript"; },
    {tp="chbox"; text=M.MRequireWithReload;       name="RequireWithReload";   },
    {tp="text";  text=M.MExcludeFromReload; x1=9; name="txtExclude";          },
    {tp="edit";                             x1=9; name="ExcludeFromReload";   },
    {tp="chbox"; text=M.MReturnToMainMenu;        name="ReturnToMainMenu";    },
    {tp="sep";                                                                },
    {tp="butt";  text=M.MOk;     default=1; centergroup=1;                    },
    {tp="butt";  text=M.MCancel; cancel=1;  centergroup=1;                    },
  }
  ------------------------------------------------------------------------------
  local dlg = sd.New(Items)
  local Pos = dlg:Indexes()
  function Items.proc(hDlg, Msg, Par1, Par2)
    if Msg==F.DN_INITDIALOG or (Msg==F.DN_BTNCLICK and Par1==Pos.RequireWithReload) then
      local enb = hDlg:GetCheck(Pos.RequireWithReload)
      hDlg:Enable(Pos.txtExclude, enb)
      hDlg:Enable(Pos.ExcludeFromReload, enb)
    end
  end
  ------------------------------------------------------------------------------
  dlg:LoadData(aData)
  local out = dlg:Run()
  if out then
    dlg:SaveData(out, aData)
    return true
  end
end

local data = (...)
return ExecuteDialog(data)
