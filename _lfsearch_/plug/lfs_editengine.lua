-- lfs_editengine.lua

local M      = require "lfs_message"
local Common = require "lfs_common"
local F = far.Flags
local EditorGetString = editor.GetString
local EditorSetString = editor.SetString
local _lastclock
local floor, ceil, min = math.floor, math.ceil, math.min

local function GetUserChoice (aTitle, s_found, s_rep)
  s_found = s_found:gsub("%z", " ")
  s_rep = s_rep:gsub("%z", " ")
  local c = far.Message(
    M.MUserChoiceReplace ..
    "\n\"" .. s_found .. "\"\n" ..
    M.MUserChoiceWith ..
    "\n\"" .. s_rep .. "\"\n\001",
    aTitle,
    M.MUserChoiceButtons)
  if c==1 or c==2 then
    _lastclock = os.clock()
  end
  return c==1 and "yes" or c==2 and "all" or c==3 and "no" or "cancel"
end


local function EditorSelect (b)
  editor.Select(b.BlockType, b.StartLine, b.StartPos, b.EndPos - b.StartPos + 1,
                   b.EndLine - b.StartLine + 1)
end


local function CheckUserBreak (aTitle)
  return (win.ExtractKey() == "ESCAPE") and
    1 == far.Message(M.MUsrBrkPrompt, aTitle, ";YesNo", "w")
end


-- This function replaces the old 9-line function.
-- The reason for applying a new, much more complicated algorithm is that
-- the old algorithm has unacceptably poor performance on long subjects.
local function find_back (s, regex, init)
  local out = regex:ufind(s, 1)
  if out == nil or out[2]>=init then return nil end

  local BEST = 1
  local stage = 1
  local MIN, MAX = 2, init
  local start = ceil((MIN+MAX)/2)

  while true do
    local res = regex:ufind(s, start)
    if res and res[2]>=init then res=nil end
    local ok = false
    ---------------------------------------------------------------------------
    if stage == 1 then -- maximize out[2]
      if res then
        if res[2] > out[2] then
          BEST, out, ok = start, res, true
        elseif res[2] == out[2] then
          ok = true
        end
      end
      if MIN >= MAX then
        stage = 2
        MIN, MAX = 2, BEST-1
        start = floor((MIN+MAX)/2)
      elseif ok then
        MIN = start+1
        start = ceil((MIN+MAX)/2)
      else
        MAX = start-1
        start = floor((MIN+MAX)/2)
      end
    ---------------------------------------------------------------------------
    else -- minimize out[1]
      if res and res[2] >= out[2] then
        if res[1] < out[1] then
          out, ok = res, true
        elseif res[1] == out[1] then
          ok = true
        end
      end
      if MIN >= MAX then
        break
      elseif ok then
        MAX = start-1
        start = floor((MIN+MAX)/2)
      else
        MIN = start+1
        start = ceil((MIN+MAX)/2)
      end
    end
    ---------------------------------------------------------------------------
  end
  return out
end


-- Note: argument 'row' can be nil (using current line)
local function ScrollToPosition (row, pos, from, to, scroll)
  local editInfo = editor.GetInfo()
  local LeftPos = editInfo.LeftPos
  -- left-most (or right-most) char is not visible
  if (from <= LeftPos) or (to > LeftPos + editInfo.WindowSizeX) then
    if to - from + 1 >= editInfo.WindowSizeX then
      LeftPos = from - 1
    else
      LeftPos = floor((to + from - 1 - editInfo.WindowSizeX) / 2)
      if LeftPos < 0 then LeftPos = 0 end
    end
  end
  -----------------------------------------------------------------------------
  local top
  local halfscreen = editInfo.WindowSizeY / 2
  scroll = scroll or 0
  row = row or editInfo.CurLine
  if row < halfscreen - scroll then
    top = 1
  elseif row > halfscreen + scroll then
    top = row - floor(halfscreen + scroll - 0.5)
  else
    top = row - floor(halfscreen - scroll - 0.5)
  end
  -----------------------------------------------------------------------------
  editor.SetPosition { TopScreenLine=top, CurLine=row, LeftPos=LeftPos, CurPos=pos }
end


local function ShowCollectedLines (items, params)
  if #items == 0 then return end

  package.loaded["far2.custommenu"] = nil
  local custommenu = require("far2.custommenu")

  table.sort(items, function(a,b) return a.lineno < b.lineno end)
  local maxno, n = 1, items[#items].lineno+1
  while n >= 10 do maxno=maxno+1; n=n/10; end

  local fmt = ("%%%dd%s %%s"):format(maxno, ("").char(9474))
  for _, item in ipairs(items) do
    local s = item.text:gsub("%z", " ") -- replace null bytes with spaces
                       :gsub("^%s*",    -- delete leading spaces
      function(c)                       -- adjust offsets for highlighting
        local len_delete = min(c:len(), item.fr-1)
        local m = maxno + 2 - len_delete
        item.offset, item.fr, item.to = m, item.fr+m, item.to+m
        return c:sub(len_delete + 1)
      end)
    item.text = fmt:format(item.lineno+1, s)
  end
  local bottom = #items..M.MLinesFound.." [F6,F7,Ctrl-C]"

  local list = custommenu.NewList({
      resizeScreen = true,          -- make it the default for CustomMenu?
--~       col_highlight = 0x3A,
--~       col_selectedhighlight = 0x0A,
      col_highlight = 0x6F,
      col_selectedhighlight = 0x4F,
      ellipsis = 3,                 -- position ellipsis at line end
      searchstart = maxno + 3,      -- needed for correct work of ellipsis
    }, items)

  local item = custommenu.Menu({
      Title=M.MSearchResults.." ["..params.sSearchPat.."]",-- honored by CustomMenu
      Bottom=bottom,                -- honored by CustomMenu
      Flags=F.FMENU_SHOWAMPERSAND,  -- ignored by CustomMenu?
      HelpTopic="Contents",
    }, list)
  if item then
    local fr, to = item.fr-item.offset, item.to-item.offset
    ScrollToPosition(item.lineno, to, fr, to)
    editor.Select("BTYPE_STREAM", nil, fr, to-fr+1, 1)
    editor.Redraw()
  end
end


local function EditorSetCurString (text)
  if not EditorSetString(nil, text) then error("EditorSetString failed") end
end


-- @aOp: "search", "replace", "count", "showall"
local function DoAction (aOp, aParams, aWithDialog, aChoiceFunc)
  -----------------------------------------------------------------------------
  local sTitle = (aOp == "replace") and M.MTitleReplace or M.MTitleSearch
  local bForward = not aParams.bSearchBack
  local bAllowEmpty = aWithDialog
  local fFilter, Regex = aParams.FilterFunc, aParams.Regex
  local fChoice = aChoiceFunc or GetUserChoice
  local fReplace = (aOp == "replace") and Common.GetReplaceFunction(aParams.ReplacePat)
  local tItems = (aOp == "showall") and {}
  local bFastCount = (aOp == "count") and bForward

  local sChoice, bEurBegin
  local nFound, nReps, nLine = 0, 0, 0
  local tInfo, tStartPos = editor.GetInfo(), editor.GetInfo()
  local nOp, nOpMax, last_update = 0, 5, 0

  local tBlockInfo
  if aParams.sScope == "block" then
    tBlockInfo = assert(editor.GetSelection(), "no selection")
  end

  local fLineInScope
  if tBlockInfo then
    fLineInScope = bForward
      and function(y) return y <= tBlockInfo.EndLine end
      or function(y) return y >= tBlockInfo.StartLine end
  else
    fLineInScope = bForward
      and function(y) return y <= tInfo.TotalLines end
      or function(y) return y >= 1 end
  end

  -- sLine must be set/modified only via set_sLine, in order to cache its length.
  -- This gives a very noticeable performance gain on long lines.
  local sLine, sLineLen
  local function set_sLine(s) sLine, sLineLen = s, s:len(); end

  local x, y, egs, part1, part3
  local function SetStartBlockParam (y)
    if aOp == "replace" then
      if tBlockInfo then EditorSelect(tBlockInfo)
      else editor.Select("BTYPE_NONE")
      end
    end
    egs = EditorGetString(y, 1)
    part1 = egs.StringText:sub(1, egs.SelStart-1)
    if egs.SelEnd == -1 then
      set_sLine(egs.StringText:sub(egs.SelStart))
      part3 = ""
    else
      set_sLine(egs.StringText:sub(egs.SelStart, egs.SelEnd))
      part3 = egs.StringText:sub(egs.SelEnd+1)
    end
  end

  if aWithDialog and aParams.sOrigin == "scope" then
    if tBlockInfo then
      y = bForward and tBlockInfo.StartLine or tBlockInfo.EndLine
      SetStartBlockParam(y)
      x = bForward and 1 or sLineLen+1
    else
      y = bForward and 1 or tInfo.TotalLines
      set_sLine(EditorGetString(y, 2))
      x = bForward and 1 or sLineLen+1
      part1, part3 = "", ""
    end
  else -- "cursor"
    if tBlockInfo then
      if tInfo.CurLine < tBlockInfo.StartLine then
        y = tBlockInfo.StartLine
        SetStartBlockParam(y)
        x = bForward and 1 or sLineLen
      elseif tInfo.CurLine > tBlockInfo.EndLine then
        y = tBlockInfo.EndLine
        SetStartBlockParam(y)
        x = bForward and 1 or sLineLen
      else
        y = tInfo.CurLine
        SetStartBlockParam(y)
        x = tInfo.CurPos <= egs.SelStart and 1
            or min(egs.SelEnd==-1 and sLineLen or egs.SelEnd,
                   tInfo.CurPos - egs.SelStart, sLineLen)
      end
    else
      y = tInfo.CurLine
      set_sLine(EditorGetString(y, 2))
      x = min(tInfo.CurPos, sLineLen+1)
      part1, part3 = "", ""
    end
  end
  -----------------------------------------------------------------------------
  local function update_y (bLineDeleted)
    y = bForward and y+(bLineDeleted and 0 or 1) or y-1
    if fLineInScope(y) then
      if tBlockInfo then
        SetStartBlockParam(y)
      else
        set_sLine(EditorGetString(y, 2))
      end
      x = bForward and 1 or sLineLen+1
      bAllowEmpty = true
    end
  end
  -----------------------------------------------------------------------------
  local update_x = bForward
    and function(fr, to, delta) x = to + (delta or 1) end
    or function(fr, to) x = fr end
  -----------------------------------------------------------------------------
  local function update_info()
    editor.SetTitle("found: " .. nFound)
  end
  local function check_and_update()
    local currclock = os.clock()
    local tm = currclock - _lastclock
    if tm == 0 then tm = 0.01 end
    nOpMax = nOpMax * 0.5 / tm
    if nOpMax > 100 then nOpMax = 100 end
    _lastclock = currclock
    -------------------------------------------------
    if currclock - last_update >= 0.5 then
      update_info()
      if CheckUserBreak(sTitle) then return true end
      last_update = currclock
    end
  end
  _lastclock = os.clock()
  --===========================================================================
  -- ITERATE ON LINES
  --===========================================================================
  while sChoice ~= "cancel" and sChoice ~= "broken" and fLineInScope(y) do
    nLine = nLine + 1
    local bLineDeleted
    ---------------------------------------------------------------------------
    if not (fFilter and fFilter(sLine, nLine)) then
      while bForward and x <= sLineLen+1 or not bForward and x >= 1 do
        -- iterate on current line
        -----------------------------------------------------------------------
        nOp = nOp + 1
        if nOp >= nOpMax then -- don't use "==" here (int vs floating point)
          nOp = 0
          if check_and_update() then sChoice = "broken"; break; end
        end
        -----------------------------------------------------------------------
        if bFastCount then
          local _, n = Regex:gsub(sLine:sub(x), "")
          nFound = nFound + n
          break
        end
        -----------------------------------------------------------------------
        local collect, fr, to
        if bForward then collect = Regex:ufind(sLine, x)
        else collect = find_back(sLine, Regex, x)
        end
        if not collect then break end
        fr, to = collect[1], collect[2]
        -----------------------------------------------------------------------
        if fr==x and to+1==x and not bAllowEmpty then
          if bForward then
            if x > sLineLen then break end
            x = x + 1
            collect = Regex:ufind(sLine, x)
          else
            if x == 1 then break end
            x = x - 1
            collect = find_back(sLine, Regex, x)
          end
          if not collect then break end
          fr, to = collect[1], collect[2]
        end
        -----------------------------------------------------------------------
        nFound = nFound + 1
        bAllowEmpty = false
        -----------------------------------------------------------------------
        local function ShowFound (scroll)
          --editor.SetPosition(y, x)
          local p1 = part1:len()
          ScrollToPosition (y, p1+x, fr, to, scroll)
          editor.Select("BTYPE_STREAM", y, p1+fr, to-fr+1, 1)
          editor.Redraw()
          tStartPos = editor.GetInfo()
        end
        -----------------------------------------------------------------------
        if aOp == "search" then
          update_x(fr, to)
          ShowFound()
          return 1, 0
        -----------------------------------------------------------------------
        elseif aOp == "count" then
          update_x(fr, to)
        -----------------------------------------------------------------------
        elseif aOp == "showall" then
          update_x(fr, to)
          if #tItems == 0 or y ~= tItems[#tItems].lineno then
            table.insert(tItems, {lineno=y, text=sLine, fr=fr, to=to})
          end
        -----------------------------------------------------------------------
        elseif aOp == "replace" then
          collect[2] = sLine:sub(fr, to)
          local sRepFinal = fReplace(collect, nFound, nReps, y)
          if sRepFinal then
            --=================================================================
            local function Replace()
              local bTraceSelection = tBlockInfo
                and (tBlockInfo.BlockType == F.BTYPE_STREAM)
                and (tBlockInfo.EndLine == y) and (tBlockInfo.EndPos ~= -1)
              local sHead = sLine:sub(1, fr-1)
              local sLastRep, sStartLine
              local nAddedLines = 0
              for txt, nl in sRepFinal:gmatch("([^\r\n]*)(\r?\n?)") do
                sLastRep = txt
                sHead = sHead .. txt
                if nl == "" then break end
                if nAddedLines == 0 then
                  sStartLine = sHead
                  sHead = part1 .. sHead
                  part1 = ""
                end
                EditorSetCurString(sHead)
                editor.SetPosition(nil, sHead:len()+1)
                editor.InsertString()
                sHead = ""
                nAddedLines = nAddedLines + 1
              end

              set_sLine(sHead .. sLine:sub(to+1))
              local line = part1 .. sLine .. part3
              bLineDeleted = aParams.bDelEmptyLine and line == ""
              local nDeleted = bLineDeleted and 1 or 0
              if bLineDeleted then editor.DeleteString()
              else EditorSetCurString(line)
              end

              if bForward then
                y = y + nAddedLines
                x = sHead:len() + 1
              else
                if sStartLine then set_sLine(sStartLine) end
                x = fr
                editor.SetPosition(y, x)
              end

              if tBlockInfo then
                tBlockInfo.EndLine = tBlockInfo.EndLine + nAddedLines - nDeleted
                if bTraceSelection then
                  tBlockInfo.EndPos = bLineDeleted and -1
                    or tBlockInfo.EndPos + sLastRep:len() - (to-fr+1)
                end
              else
                tInfo.TotalLines = tInfo.TotalLines + nAddedLines - nDeleted
              end

              if sChoice == "yes" then editor.Redraw() end
              if tBlockInfo then EditorSelect(tBlockInfo) end
              tStartPos = editor.GetInfo() -- save position
              nReps = nReps + 1
              return bLineDeleted
            end
            --=================================================================
            if sChoice == "all" then
              if Replace() then break end
              editor.SetPosition(y, x)
              tStartPos = editor.GetInfo()
            else
              ShowFound(14/2 + 2)
              sChoice = fChoice(sTitle, sLine:sub(fr, to), sRepFinal)
              if sChoice == "all" then
                editor.UndoRedo("EUR_BEGIN") -- for undoing the bulk replacement in a single step
                bEurBegin = true
              end
              -----------------------------------------------------------------
              if sChoice == "yes" or sChoice == "all" then
                if Replace() then break end
                if sChoice == "yes" then ShowFound() end
              -----------------------------------------------------------------
              elseif sChoice == "no" then
                update_x(fr, to)
              -----------------------------------------------------------------
              elseif sChoice == "cancel" then
                break
              -----------------------------------------------------------------
              end
            end
          else
            update_x(fr, to)
          end
        -----------------------------------------------------------------------
        end
      end -- Current Line loop
    end -- Line Filter check
    update_y(bLineDeleted)
  end
  --===========================================================================
  editor.SetPosition(tStartPos)
  if tBlockInfo then
    EditorSelect(tBlockInfo)
  end
  editor.Redraw()
  update_info()
  if aOp == "showall" then
    ShowCollectedLines(tItems, aParams)
  elseif aOp == "replace" and bEurBegin then
    editor.UndoRedo("EUR_END")
  end
  return nFound, nReps, sChoice
end

return {
  DoAction = DoAction;
}
