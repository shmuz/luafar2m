------------------------------------------------------------------------------------------------
-- Started              : 2019-09-08 (?)
-- Portability          : far3 (>= 3425), far2m
-- Far plugin           : LuaMacro
------------------------------------------------------------------------------------------------

local F = far.Flags

local EnableTrim = {}
local patTrailSpace = regex.new("\\s+$", "o")

local GetStrW do
  local getstr = editor.GetStringW
  GetStrW = function(id,line) return getstr(id,line,3); end
end

Event { -- for text files
  description="EE_SAVE: delete trailing spaces";
  group="EditorEvent";
  action=function(Id, Event, Param)
    if Event == F.EE_SAVE then
      if EnableTrim[Id] then
        EnableTrim[Id] = nil
        local info = editor.GetInfo(Id)
        if info then
          for k=1,info.TotalLines do
            local str,eol = GetStrW(Id, k)
            local from = patTrailSpace:findW(str)
            if from then
              str = win.subW(str, 1, from-1)
              editor.SetStringW(Id, k, str, eol)
            end
          end
        end
      end
    end
  end;
}

Macro {
  id="D0FCEB16-E693-4EA0-8902-8009EFB578C3";
  description="Use CtrlS / CtrlShiftS for saving files";
  area="Editor"; key="CtrlS CtrlShiftS";
  action = function()
    local key = akey(1,1)
    if key == "CtrlS" then -- save file with trim
      local info = editor.GetInfo()
      EnableTrim[info.EditorID] = true
      editor.SaveFile()
    elseif key == "CtrlShiftS" then -- save file w/o trim
      editor.SaveFile()
    end
  end;
}
