-- Started 2014-12-01 by Shmuel Zeigerman
-- http://forum.farmanager.com/viewtopic.php?f=15&t=9191
-- http://forum.farmanager.com/viewtopic.php?p=126100#p126100

-- Imitate the feature of typing/erasing on multiple lines at once (like the SciTE editor does).
-- * Select a vertical block 0 or 1 character wide.
-- * Position the cursor on any line covered with the block.
-- * Type or delete (Del, BS) the text.

-- OPTIONS -----------------------------------------------------------------------------------------

  -- Replace the block with entered character; delete the block contents on pressing Del or BS.
  -- This option works for vertical blocks with width >= 2.
local OptReplaceBlock = true

  -- Use Alt codes e.g. Alt+64 --> @. (This feature is still experimental).
local OptUseAltCodes = false

  -- Reset selection on cursor key moves (only with non-persistent blocks).
local OptCursorMoveResetsBlock = true

-- END OF OPTIONS ----------------------------------------------------------------------------------

local F = far.Flags
local band = bit.band
local CharMap = {Space=" ", ShiftSpace=" ", Tab="\t",     BackSlash="\\",
                 Add="+",   Subtract="-",   Multiply="*", Divide="/",     Decimal="."}
local KeyMap = {Num2="Down", Num4="Left", Num6="Right", Num8="Up", NumDel="Del", ShiftIns="CtrlV", ShiftNum0="CtrlV"}

local function scite_like(Rec)
  if Rec.EventType ~= F.KEY_EVENT then return false end

  local EI = editor.GetInfo()
  if not (EI and EI.BlockType==F.BTYPE_COLUMN and band(EI.CurState,F.ECSTATE_LOCKED)==0) then return false end

  local uc = Rec.UnicodeChar
  local altchar = OptUseAltCodes and not Rec.KeyDown and Rec.VirtualKeyCode==18 and uc~="" and uc~="\0" and uc
  local key = not altchar and far.InputRecordToName(Rec)

  if key=="CtrlS" then key="Left"; Rec.ControlKeyState=0; end
  key = KeyMap[key] or key

  if OptCursorMoveResetsBlock and band(EI.Options,F.EOPT_PERSISTENTBLOCKS)==0 then
    if key=="Left" or key=="Right" or key=="Up" or key=="Down" then return false end
  end

  if not (altchar or key=="CtrlV" or (Rec.KeyDown and band(Rec.ControlKeyState,0x0F)==0)) then return false end

  local cur = editor.GetString()
  local BlockWidth = cur and cur.SelStart>0 and cur.SelEnd-cur.SelStart+1
  if BlockWidth then
    if not (OptReplaceBlock or BlockWidth<=1) then return false end
  else
    -- check entering inside the region
    if key=="Down" then
      if EI.CurLine ~= EI.BlockStartLine-1 then return false end
      local line = editor.GetString(EI.BlockStartLine)
      if not (line and line.SelStart>0 and line.SelEnd-line.SelStart+1 <= 1) then return false end
    elseif key=="Up" and EI.CurLine>1 then
      local line = editor.GetString(EI.CurLine-1)
      if not (line and line.SelStart>0 and line.SelEnd-line.SelStart+1 <= 1) then return false end
    else
      return false
    end
  end

  local char = altchar or key and (CharMap[key] or key:match("^.$"))
  local text = char
  if key=="CtrlV" then
    local clip = far.PasteFromClipboard()
    text = clip and clip:match("^([^\r\n]*)\r?\n?$")
    if not text then return false end
  end
  local textlen = text and text:len() or 0

  local delblock = OptReplaceBlock and BlockWidth and BlockWidth>1
  if delblock and not (text or key=="Del" or key=="BS") then return false end

  if not (text or key=="Del" or key=="BS" or key=="Left" or key=="Right" or key=="Up" or key=="Down")
  then return false end

  if (key=="BS" or key=="Left") and EI.CurPos==1 then return true end

  -- check leaving the region
  if key=="Up" then
    if EI.CurLine==1 then return true end
    if EI.CurLine==EI.BlockStartLine then return false end
  elseif key=="Down" then
    if EI.CurLine==EI.TotalLines then return true end
    local line = editor.GetString(EI.CurLine+1)
    if not line or line.SelStart <= 0 then return false end
  end

  local lnum = EI.BlockStartLine
  local clean = true
  local BlockStartRealPos, BlockStartTabPos
  while true do
    local line = editor.GetString(lnum)
    if not line or line.SelStart <= 0 then break end
    BlockStartRealPos = BlockStartRealPos or line.SelStart
    BlockStartTabPos = BlockStartTabPos or editor.RealToTab(lnum,BlockStartRealPos)
    local pos = editor.TabToReal(lnum,EI.CurTabPos)
    local s, len, newS = line.StringText, line.StringLength, nil
    if delblock then
      if key == "Del" or key == "BS" then
        if line.SelStart <= len then newS = s:sub(1,line.SelStart-1)..s:sub(line.SelEnd+1) end
      elseif text then
        if line.SelStart > len+1 then newS = s..(" "):rep(line.SelStart-len-1)..text
        else newS = s:sub(1,line.SelStart-1)..text..s:sub(line.SelEnd+1)
        end
      end
    else
      if key == "Del" then
        if pos <= len then newS = s:sub(1,pos-1)..s:sub(pos+1) end
      elseif key == "BS" then
        if pos <= len+1 then newS = s:sub(1,pos-2)..s:sub(pos) end
      elseif text then
        if pos > len+1 then newS = s..(" "):rep(pos-len-1)..text
        else newS = s:sub(1,pos-1)..text..s:sub(pos+(EI.Overtype~=0 and textlen or 0))
        end
      end
    end
    if newS then
      if clean then editor.UndoRedo(F.EUR_BEGIN); clean=false; end
      editor.SetString(lnum, newS)
    end
    lnum = lnum + 1
  end
  if not clean then editor.UndoRedo(F.EUR_END) end

  local realX, tabX, newY
  if delblock then
    realX = BlockStartRealPos + textlen
    tabX = BlockStartTabPos + textlen
    newY = EI.CurLine
  else
    realX = math.max(1, EI.CurPos + ((key=="Right") and 1 or (key=="BS" or key=="Left") and -1 or textlen))
    tabX = editor.RealToTab(EI.CurLine, realX)
    newY = math.max(1, EI.CurLine + (key=="Up" and -1 or key=="Down" and 1 or 0))
  end
  editor.SetPosition(newY, realX)
  editor.Select("BTYPE_COLUMN", EI.BlockStartLine, tabX, 1, lnum-EI.BlockStartLine)
  editor.Redraw()
  return true
end

Event {
  description="SciTE-like multiline input";
  group="EditorInput";
  action=scite_like;
}
