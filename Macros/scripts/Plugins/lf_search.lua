------------------------------------------------------------------------------
-- LuaFAR Search --
------------------------------------------------------------------------------

local Guid = 0x8E11EA75

local function LFS_Editor(...) Plugin.Call(Guid, "own", "editor", ...) end
local function LFS_Panels(...) Plugin.Call(Guid, "own", "panels", ...) end
local function LFS_Exist() return Plugin.Exist(Guid) end

Macro {
  id="252A4DE0-1FFB-4409-9691-15A874BF7ADD";
  description="LF Search: Editor Find";
  area="Editor"; key="F3";
  condition=LFS_Exist;
  action = function() LFS_Editor "search" end;
}

Macro {
  id="F2176F24-61A1-4180-A3E9-7D93957DF991";
  description="LF Search: Editor Replace";
  area="Editor"; key="CtrlF3";
  condition=LFS_Exist;
  action = function() LFS_Editor "replace" end;
}

Macro {
  id="70DEB965-DB0F-40C7-B3AC-0BE52AD06BE6";
  description="LF Search: Editor Repeat";
  area="Editor"; key="ShiftF3";
  condition=LFS_Exist;
  action = function() LFS_Editor "repeat" end;
}

Macro {
  id="2EA68553-569E-434B-8294-94A8451EA6FB";
  description="LF Search: Editor Repeat reverse";
  area="Editor"; key="AltF3";
  condition=LFS_Exist;
  action = function() LFS_Editor "repeat_rev" end;
}

Macro {
  id="3973E1B8-A5DE-479D-910C-12997C7E129F";
  description="LF Search: Editor search word";
  area="Editor"; key="Alt6";
  condition=LFS_Exist;
  action = function() LFS_Editor "searchword" end
}

Macro {
  id="43F80CC7-7496-4815-8714-A9FF73A2DA78";
  description="LF Search: Editor search word reverse";
  area="Editor"; key="Alt5";
  condition=LFS_Exist;
  action = function() LFS_Editor "searchword_rev" end;
}

Macro {
  id="FC4DED58-C741-46FF-9070-F3A0CB6C9EC7";
  description="LF Search: Editor Multi-line replace";
  area="Editor"; key="CtrlShiftF3";
  condition=LFS_Exist;
  action = function() LFS_Editor "mreplace" end;
}

Macro {
  id="2CA8B91D-C2EB-4387-8AC9-79BDC7C70763";
  description="LF Search: Panel Find";
  area="Shell QView Tree Info"; key="CtrlShiftF";
  condition=LFS_Exist;
  action = function() LFS_Panels "search" end;
}

Macro {
  id="01E5738F-1250-4080-8A32-E1C9F2FC67F8";
  description="LF Search: Panel Replace";
  area="Shell QView Tree Info"; key="CtrlShiftG";
  condition=LFS_Exist;
  action = function() LFS_Panels "replace" end;
}

Macro {
  id="C309794F-D629-4B8C-90CE-ED3804FEE2A2";
  description="LF Search: Panel Grep";
  area="Shell QView Tree Info"; key="CtrlShiftH";
  condition=LFS_Exist;
  action = function() LFS_Panels "grep" end;
}

Macro {
  id="AFCCCC5A-177B-4A8B-BC34-7FC74F8ABEB3";
  description="LF Search: Panel Rename";
  area="Shell QView Tree Info"; key="CtrlShiftJ";
  condition=LFS_Exist;
  action = function() LFS_Panels "rename" end
}

Macro {
  id="658B6513-DD1B-409F-886B-6C9BDAECCBC0";
  description="LF Search: Show Panel";
  area="Shell QView Tree Info"; key="CtrlShiftK";
  condition=LFS_Exist;
  action = function() LFS_Panels "panel" end
}

-- This macro works best when "Show line numbers" Grep option is used.
-- When this option is off the jump occurs to the beginning of the file.
Macro {
  id="69BF96AF-F09E-43C0-BDB3-4A38B7BE156A";
  description="Jump from Grep results to file and position under cursor";
  area="Editor"; key="CtrlShiftG";
  condition=LFS_Exist;
  action=function()
    local lnum = editor.GetString(nil,nil,3):match("^(%d+)[:%-]")
    local EI = editor.GetInfo()
    for n = EI.CurLine,1,-1 do
      local fname = editor.GetString(nil,n,3):match("^%[%d+%]%s+(.-) : %d+$")
      if fname then
        editor.Editor(fname,nil,nil,nil,nil,nil,
          {EF_NONMODAL=1,EF_IMMEDIATERETURN=1,EF_ENABLE_F6=1},
          lnum or 1, lnum and math.max(1, EI.CurPos-lnum:len()-1) or 1)
        break
      end
    end
  end;
}
