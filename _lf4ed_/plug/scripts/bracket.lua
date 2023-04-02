-- bracket.lua

local function FastGetString (num)
  return editor.GetString(nil,num, 2)
end

local function FindBracket()
  local ei = editor.GetInfo()
  local line = FastGetString(ei.CurLine)
  if ei.CurPos > line:len() then
    return
  end

  local Bracket = line:sub (ei.CurPos, ei.CurPos)
  local Direction, Match
  do
    local tForward  = { ["("]=")", ["{"]="}", ["["]="]", ["<"]=">", }
    local tBackward = { [")"]="(", ["}"]="{", ["]"]="[", [">"]="<", }
    if tForward[Bracket] then
      Direction, Match = 1, tForward[Bracket]
    elseif tBackward[Bracket] then
      Direction, Match = -1, tBackward[Bracket]
    else
      return
    end
  end

  local CurPos, CurLine = ei.CurPos, ei.CurLine
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
          local esp = { CurLine = CurLine, CurPos = CurPos }
          if (CurLine < ei.TopScreenLine or
              CurLine >= ei.TopScreenLine + ei.WindowSizeY)
          then
            esp.TopScreenLine = CurLine - ei.WindowSizeY/2;
            if esp.TopScreenLine < 1 then
              esp.TopScreenLine = 1
            end
          end
          editor.SetPosition(nil,esp) -- match found: set the new position
          editor.Redraw()
          return
        end
      end
    end
  end
  editor.SetPosition(nil,ei) -- match not found: restore the initial position
  editor.Redraw()
end

AddToMenu ("e", nil, "Ctrl+E", FindBracket)
