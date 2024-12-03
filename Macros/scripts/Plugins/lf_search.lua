------------------------------------------------------------------------------
-- LuaFAR Search --
------------------------------------------------------------------------------

local Guid = 0x8E11EA75

local function LFS_Editor(...) Plugin.Call(Guid, "own", "editor", ...) end
local function LFS_Panels(...) Plugin.Call(Guid, "own", "panels", ...) end
local function LFS_Exist() return Plugin.Exist(Guid) end

Macro {
  id="252A4DE0-1FFB-4409-9691-15A874BF7ADD";
  id="48A4AB2C-37AB-4AC6-8716-42678A076679";
  description="LF Search: Editor Find";
  area="Editor"; key="F3";
  condition=LFS_Exist;
  action = function() LFS_Editor "search" end;
}

Macro {
  id="F2176F24-61A1-4180-A3E9-7D93957DF991";
  id="D429AA0B-FC34-43B6-A958-093901C52E02";
  description="LF Search: Editor Replace";
  area="Editor"; key="CtrlF3";
  condition=LFS_Exist;
  action = function() LFS_Editor "replace" end;
}

Macro {
  id="70DEB965-DB0F-40C7-B3AC-0BE52AD06BE6";
  id="1B9A5A29-4699-4B47-B3D9-E51CB4A597CB";
  description="LF Search: Editor Repeat";
  area="Editor"; key="ShiftF3";
  condition=LFS_Exist;
  action = function() LFS_Editor "repeat" end;
}

Macro {
  id="2EA68553-569E-434B-8294-94A8451EA6FB";
  id="A37E86E3-5F43-4189-B013-4159BEC3B0C2";
  description="LF Search: Editor Repeat reverse";
  area="Editor"; key="AltF3";
  condition=LFS_Exist;
  action = function() LFS_Editor "repeat_rev" end;
}

Macro {
  id="3973E1B8-A5DE-479D-910C-12997C7E129F";
  id="35C4107A-6BE5-42A7-97C0-F8706014599C";
  description="LF Search: Editor search word";
  area="Editor"; key="Alt6";
  condition=LFS_Exist;
  action = function() LFS_Editor "searchword" end
}

Macro {
  id="43F80CC7-7496-4815-8714-A9FF73A2DA78";
  id="F60EAA3F-9632-4C7E-9EC8-2375D4267EA6";
  description="LF Search: Editor search word reverse";
  area="Editor"; key="Alt5";
  condition=LFS_Exist;
  action = function() LFS_Editor "searchword_rev" end;
}

Macro {
  id="FC4DED58-C741-46FF-9070-F3A0CB6C9EC7";
  id="4D838FB8-D4CF-4DBD-9E4E-0A6B90838F12";
  description="LF Search: Editor Multi-line replace";
  area="Editor"; key="CtrlShiftF3";
  condition=LFS_Exist;
  action = function() LFS_Editor "mreplace" end;
}

Macro {
  id="2CA8B91D-C2EB-4387-8AC9-79BDC7C70763";
  id="E1B5B69A-FACC-4537-9734-1DFB812CFD17";
  description="LF Search: Panel Find";
  area="Shell QView Tree Info"; key="CtrlShiftF";
  condition=LFS_Exist;
  action = function() LFS_Panels "search" end;
}

Macro {
  id="01E5738F-1250-4080-8A32-E1C9F2FC67F8";
  id="65964FC4-5077-47F7-A1AC-B8B17E12C56C";
  description="LF Search: Panel Replace";
  area="Shell QView Tree Info"; key="CtrlShiftG";
  condition=LFS_Exist;
  action = function() LFS_Panels "replace" end;
}

Macro {
  id="C309794F-D629-4B8C-90CE-ED3804FEE2A2";
  id="97C0FFF3-08A9-4052-9867-13D83403B9E4";
  description="LF Search: Panel Grep";
  area="Shell QView Tree Info"; key="CtrlShiftH";
  condition=LFS_Exist;
  action = function() LFS_Panels "grep" end;
}

Macro {
  id="AFCCCC5A-177B-4A8B-BC34-7FC74F8ABEB3";
  id="C116882B-4A8B-48D6-93A7-76B8D21ADBB2";
  description="LF Search: Panel Rename";
  area="Shell QView Tree Info"; key="CtrlShiftJ";
  condition=LFS_Exist;
  action = function() LFS_Panels "rename" end
}

Macro {
  id="658B6513-DD1B-409F-886B-6C9BDAECCBC0";
  id="33A9B206-F7D7-4ED6-8BCE-2DF52676D070";
  description="LF Search: Show Panel";
  area="Shell QView Tree Info"; key="CtrlShiftK";
  condition=LFS_Exist;
  action = function() LFS_Panels "panel" end
}

-- This macro works best when "Show line numbers" Grep option is used.
-- When this option is off the jump occurs to the beginning of the file.
Macro {
  id="69BF96AF-F09E-43C0-BDB3-4A38B7BE156A";
  id="5CB7E3A8-B011-4262-AD04-E14475B35EAB";
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
