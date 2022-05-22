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
