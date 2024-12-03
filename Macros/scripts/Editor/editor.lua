local F = far.Flags

Macro {
  id="064E3824-0517-4E07-88CD-32334D3EB490";
  id="DBE0D51F-0D48-4CEF-86F6-EF5161DC31D1";
  description="Use CtrlS for saving files instead of F2";
  area="Editor"; key="CtrlS F2";
  action = function()
    if akey(1,1)=="CtrlS" then Keys("F2")
    elseif akey(1,1)=="F2" then mf.usermenu()
    end
  end;
}

Macro {
  id="4210FF9C-A661-42B8-9D9A-FF9373B5FA9E";
  id="319685C8-9AE6-4AD7-B564-11E982C6CB51";
  description="Insert new GUID";
  area="Editor"; key="CtrlF11";
  action=function()
    print('"'..win.Uuid(win.Uuid()):upper()..'"')
  end;
}

Macro {
  id="D36B2FE9-93A9-4105-965D-FAC25C1733C5";
  id="512E5C55-BD29-4430-86CC-1DF9AE4EA91A";
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
  id="FFB9DBC9-B1C6-41DF-B755-21BDD5270A3C";
  id="12BC1508-9E14-4C5C-A0A5-CE5ABBB03955";
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
  id="29D1CFE6-F87F-4010-AFB3-CD3C0768537C";
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
  id="8E572772-C12A-4997-9DAA-6712830E91E4";
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
  id="C4571286-977C-437E-B631-8176E3A8448D";
  id="1711DC0D-D53F-4971-AFD0-7F147EF29B11";
  description="Goto in the editor";
  area="Editor"; key="CtrlG";
  action=function() Keys("AltF8") end;
}
