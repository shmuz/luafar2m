-- file created: 2008-12-18

local sd = require "far2.simpledialog"
local M = require "lf4ed_message"

local function ExecuteDialog (aData)
  local Items = {
    width=46;
    {tp="dbox";  text=M.MPluginSettings;},
    {tp="chbox"; text=M.MReloadDefaultScript; name="ReloadDefaultScript"; },
    {tp="chbox"; text=M.MRequireWithReload;   name="RequireWithReload";   },
    {tp="chbox"; text=M.MUseStrict;           name="UseStrict";           },
    {tp="chbox"; text=M.MReturnToMainMenu;    name="ReturnToMainMenu";    },
    {tp="sep";                                                            },
    {tp="butt";  text=M.MOk;     default=1; centergroup=1;                },
    {tp="butt";  text=M.MCancel; cancel=1;  centergroup=1;                },
  }
  ------------------------------------------------------------------------------
  sd.LoadData(aData, Items)
  local out = sd.Run(Items)
  if out then
    sd.SaveData(out, aData)
    return true
  end
end

local Cfg = (...)[1]
return ExecuteDialog(Cfg)
