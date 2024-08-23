local F = far.Flags

Macro {
  description="Use CtrlS for saving files instead of F2";
  area="Editor"; key="CtrlS F2";
  action = function()
    if akey(1,1)=="CtrlS" then Keys("F2")
    elseif akey(1,1)=="F2" then mf.usermenu()
    end
  end;
}

Macro {
  description="Insert new GUID";
  area="Editor"; key="CtrlF11";
  action=function()
    print('"'..win.Uuid(win.Uuid()):upper()..'"')
  end;
}

Macro {
  description="Save and run script from editor";
  area="Editor"; key="CtrlF12";
  action=function()
    for k=1,2 do
      local info=editor.GetInfo()
      if bit64.band(info.CurState, F.ECSTATE_SAVED)~=0 then
        local Flags = info.FileName:sub(-5):lower()==".moon" and "KMFLAGS_MOONSCRIPT"
          or "KMFLAGS_LUA"
        far.MacroPost('@"' .. info.FileName .. '"', Flags)
        break
      end
      if k==1 then editor.SaveFile(); end
    end
  end;
}

Macro {
  description="Insert Internet Shortcut";
  area="Editor"; key="CtrlF11";
  action=function()
    print[[
[InternetShortCut]
Url=]]
  end;
}

Macro {
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
  end
end

local out = Dlg:Run()
if out then
end
]]
  end;
}

Macro {
  description="Goto in the editor";
  area="Editor"; key="CtrlG";
  action=function() Keys("AltF8") end;
}
