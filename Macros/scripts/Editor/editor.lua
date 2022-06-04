local F = far.Flags

Macro {
  description="Use CtrlS for saving files instead of F2";
  area="Editor"; key="CtrlS";
  action = function() Keys("F2") end;
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
  description="Smart Home";
  area="Editor"; key="Home";
  action=function()
    local info, str = editor.GetInfo(), editor.GetString()
    local pos = str.StringText:find("%S") or 1
    editor.SetPosition(nil, pos==info.CurPos and 1 or pos)
    editor.Redraw()
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
  description="Goto in the editor";
  area="Editor"; key="CtrlG";
  action=function() Keys("AltF8") end;
}

