local F = far.Flags

Macro {
  id="4210FF9C-A661-42B8-9D9A-FF9373B5FA9E";
  description="Insert new GUID";
  area="Editor"; key="CtrlF11";
  action=function()
    print('"'..win.Uuid(win.Uuid()):upper()..'"')
  end;
}

Macro {
  id="D36B2FE9-93A9-4105-965D-FAC25C1733C5";
  description="Save and run script from editor";
  area="Editor"; key="CtrlF12";
  filemask="*.lua;*.moon";
  action=function()
    local info = editor.GetInfo()
    if bit64.band(info.CurState, F.ECSTATE_SAVED) == 0 then
      if not editor.SaveFile() then
        far.Message("Could not save file. The script will not be run.")
        return
      end
    end
    local Flags = info.FileName:sub(-5):lower()==".moon" and "KMFLAGS_MOONSCRIPT" or "KMFLAGS_LUA"
    far.MacroPost('@"' .. info.FileName .. '"', Flags)
  end;
}

Macro {
  id="FFB9DBC9-B1C6-41DF-B755-21BDD5270A3C";
  description="Insert Internet Shortcut";
  area="Editor"; key="CtrlF11";
  action=function()
    print[[
[InternetShortCut]
Url=]]
  end;
}

Macro {
  id="94A59D13-A484-44CA-A192-31DC6096BC3D";
  description="Insert C-file template";
  area="Editor"; key="CtrlF11";
  action=function()
    print[[
#include <stdio.h>

int main(int argc, const char* argv[])
{
  return 0;
}
]]
  end;
}

Macro {
  id="32B5235E-35C8-4665-B254-9895C26B71D1";
  description="Insert a simple dialog template";
  area="Editor"; key="CtrlF11";
  action=function()
    print[[
local F = far.Flags
local sd = require "far2.simpledialog"
local Items = {
  -- guid = xxx;
  -- help = "Contents";
  -- width = 76;
  { tp="dbox"; text="Title";                           },
  { tp="text"; text="Enter the text:";                 },
  { tp="edit"; name="edit1";                           },
  { tp="sep";                                          },
  { tp="butt"; centergroup=1; default=1; text="OK";    },
  { tp="butt"; centergroup=1; cancel=1; text="Cancel"; },
}

local Dlg = sd.New(Items)
local Pos, Elem = Dlg:Indexes()

Items.proc = function(hDlg, msg, param1, param2)
  if msg == F.DN_INITDIALOG then
  elseif msg == F.DN_BTNCLICK then
  elseif msg == F.DN_EDITCHANGE then
  elseif msg == F.DN_CLOSE then
  elseif msg == "EVENT_KEY" then
  elseif msg == "EVENT_MOUSE" then
  end
end

local out = Dlg:Run()
if out then
end
]]
  end;
}

Macro {
  id="C4571286-977C-437E-B631-8176E3A8448D";
  description="Goto in the editor";
  area="Editor"; key="CtrlG";
  action=function() Keys("AltF8") end;
}
