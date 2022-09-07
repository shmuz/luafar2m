------------------------------------------------------------------------------
-- LuaFAR Search --
------------------------------------------------------------------------------

local Guid = 0x8E11EA75

local function LFS_Editor(...) Plugin.Call(Guid, "own", "editor", ...) end
local function LFS_Panels(...) Plugin.Call(Guid, "own", "panels", ...) end

Macro {
  description="LF Search: Editor Find";
  area="Editor"; key="F3";
  action = function() LFS_Editor "search" end;
}

Macro {
  description="LF Search: Editor Replace";
  area="Editor"; key="CtrlF3";
  action = function() LFS_Editor "replace" end;
}

Macro {
  description="LF Search: Editor Repeat";
  area="Editor"; key="ShiftF3";
  action = function() LFS_Editor "repeat" end;
}

Macro {
  description="LF Search: Editor Repeat reverse";
  area="Editor"; key="AltF3";
  action = function() LFS_Editor "repeat_rev" end;
}

Macro {
  description="LF Search: Editor search word";
  area="Editor"; key="Alt6";
  action = function() LFS_Editor "searchword" end
}

Macro {
  description="LF Search: Editor search word reverse";
  area="Editor"; key="Alt5";
  action = function() LFS_Editor "searchword_rev" end;
}

Macro {
  description="LF Search: Editor Multi-line replace";
  area="Editor"; key="CtrlShiftF3";
  action = function() LFS_Editor "mreplace" end;
}

Macro {
  description="LF Search: Panel Find";
  area="Shell QView Tree Info"; key="CtrlShiftF";
  action = function() LFS_Panels "search" end;
}

Macro {
  description="LF Search: Panel Grep";
  area="Shell QView Tree Info"; key="CtrlShiftH";
  action = function() LFS_Panels "grep" end;
}

Macro {
  description="LF Search: Panel Rename";
  area="Shell QView Tree Info"; key="CtrlShiftJ";
  action = function() LFS_Panels "rename" end
}

Macro {
  description="LF Search: Show Panel";
  area="Shell QView Tree Info"; key="CtrlShiftK";
  action = function() LFS_Panels "panel" end
}

-- This macro works best when "Show line numbers" Grep option is used.
-- When this option is off the jump occurs to the beginning of the file.
Macro {
  description="Jump from Grep results to file and position under cursor";
  area="Editor"; key="CtrlShiftG";
  action=function()
    local lnum = editor.GetString(nil,3):match("^(%d+)[:%-]")
    local EI = editor.GetInfo()
    for n = EI.CurLine,1,-1 do
      local fname = editor.GetString(n,3):match("^%[%d+%]%s+(.+)")
      if fname then
        editor.Editor(fname,nil,nil,nil,nil,nil,
          {EF_NONMODAL=1,EF_IMMEDIATERETURN=1,EF_ENABLE_F6=1},
          lnum or 1, lnum and math.max(1, EI.CurPos-lnum:len()-1) or 1)
        break
      end
    end
  end;
}
