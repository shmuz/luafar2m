-- Started: 2016-02-28
-- Goal: pick some text from current editor line into dialog input field
-- What is picked:
--   (a) if some text in the line is selected - that text is picked
--   (b) else the word under cursor,
--       else the nearest word in the forward direction,
--       else the nearest word in the backward direction.
-- If the text in the input field is equal to (a) then (b) is picked and vice versa.

-- SETTINGS
local pattern = regex.new("(\\w+)")
-- END OF SETTINGS

local function GetTextFromEditor (curtext)
  local line = editor.GetString()
  if line then
    local sel = line.SelStart>=1 and
                line.SelStart<=line.StringLength and
                line.StringText:sub(line.SelStart,line.SelEnd)
    if sel=="" then sel=nil end

    local word
    local pos = editor.GetInfo().CurPos
    local offset,last = pattern:find(line.StringText, pos==1 and 1 or pos-1)
    if offset then
      word = pattern:match(line.StringText:reverse(), line.StringLength-last+1):reverse()
    else
      local rword = pattern:match(line.StringText:reverse())
      word = rword and rword:reverse()
    end
    if word=="" then word=nil end

    return (curtext==sel and word) or (curtext==word and sel) or sel or word
  end
end

Macro {
  id="BD8E52B8-D85A-4EE3-BE69-BCC0C72CCED3";
  description="Pick word under editor cursor";
  area="Dialog"; key="CtrlShiftW";
  action=function()
    local tp = Dlg.ItemType
    if tp==4 or tp==6 or tp==10 then -- edit/fixedit/combobox
      local text = GetTextFromEditor(Dlg.GetValue(-1,0))
      if text then Keys("CtrlY"); print(text); end
    end
  end;
}
