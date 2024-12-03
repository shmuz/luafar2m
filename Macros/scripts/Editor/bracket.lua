-- bracket.lua

local function FastGetString (num)
  return editor.GetString(nil, num, 2)
end

local function FindBracket (aSelect)
  local ei = editor.GetInfo()
  local line = FastGetString(ei.CurLine)

  local CurPos, CurLine = ei.CurPos, ei.CurLine
  local Bracket, Match, Direction, Increment

  local tForward  = { ["("]=")", ["{"]="}", ["["]="]", ["<"]=">", }
  local tBackward = { [")"]="(", ["}"]="{", ["]"]="[", [">"]="<", }
  for k=0,1 do -- test cursor position and left-to-cursor position
    Increment = 1-k
    Bracket = line:sub (CurPos-k, CurPos-k)
    if tForward[Bracket] then
      Direction, Match = 1, tForward[Bracket]
      break
    elseif tBackward[Bracket] then
      Direction, Match = -1, tBackward[Bracket];
      CurPos = CurPos - k
      break
    elseif k==1 or CurPos==1 then
      return
    end
  end

  local MatchCount = 1
  while true do
    CurPos = CurPos + Direction
    if CurPos > line:len() then
      CurLine = CurLine + 1
      if CurLine > ei.TotalLines then
        break
      end
      line = FastGetString(CurLine)
      CurPos = 1
    end
    if CurPos < 1 then
      CurLine = CurLine - 1
      if CurLine < 1 then
        break
      end
      line = FastGetString(CurLine)
      CurPos = line:len()
    end
    if CurPos >= 1 and CurPos <= line:len() then
      local Ch = line:sub (CurPos, CurPos)
      if Ch == Bracket then
        MatchCount = MatchCount + 1
      elseif Ch == Match then
        MatchCount = MatchCount - 1
        if MatchCount == 0 then
          local esp = { CurLine=CurLine, CurPos=CurPos+Increment }
          if (CurLine < ei.TopScreenLine or CurLine >= ei.TopScreenLine + ei.WindowSizeY) then
            esp.TopScreenLine = CurLine - ei.WindowSizeY/2;
            if esp.TopScreenLine < 1 then
              esp.TopScreenLine = 1
            end
          end
          editor.SetPosition(nil,esp) -- match found: set the new position
          if aSelect then
            local from,to = ei,esp
            if Direction < 0 then
              from,to = to,from
            end
            local width = to.CurPos-from.CurPos
            local height = to.CurLine-from.CurLine+1
            editor.Select(nil, "BTYPE_STREAM", from.CurLine, from.CurPos, width, height)
          end
          return
        end
      end
    end
  end
  editor.SetPosition(nil,ei) -- match not found: restore the initial position
end

Macro {
  id="9A1A2860-E6E7-4C6A-A98E-1417269740CE";
  description="Go to matching bracket";
  area="Editor"; key="CtrlE";
  action=function() FindBracket(false) end;
}
Macro {
  id="733D4957-610C-4E05-B742-7D8A9FC81AB5";
  description="Select to matching bracket";
  area="Editor"; key="CtrlShiftE";
  action=function() FindBracket(true) end;
}
