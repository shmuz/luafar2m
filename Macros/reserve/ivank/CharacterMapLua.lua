-- source: https://forum.farmanager.com/viewtopic.php?t=10665

local macros_name = "CharacterMapLua"

local function Main()

  local draw_column_count = 32
  local include_symbols_7bit = true
  local include_symbols_8bit = false
  local include_symbols_encodings = {} --{"866", "1251", "20866"} --code page must be defined below (for example symbols_cp866)
  local include_additional_symbols = {
    "А", "Б", "В", "Г", "Д", "Е", "Ж", "З", "И", "Й", "К", "Л", "М", "Н", "О", "П",
    "Р", "С", "Т", "У", "Ф", "Х", "Ц", "Ч", "Ш", "Щ", "Ъ", "Ы", "Ь", "Э", "Ю", "Я",
    "а", "б", "в", "г", "д", "е", "ж", "з", "и", "й", "к", "л", "м", "н", "о", "п",
    "р", "с", "т", "у", "ф", "х", "ц", "ч", "ш", "щ", "ъ", "ы", "ь", "э", "ю", "я",
    "Ё", "ё", "•", "°", "±", "√", "№", "…", "§", "⌡", "⌠", "≈", "≤", "≥", "÷", "∞",
    "µ", "π", "⁰", "¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹", "⁻", "ⁿ", "ˣ", "ʸ",
    "₀", "₁", "₂", "₃", "₄", "₅", "₆", "₇", "₈", "₉", "→", "←", "↑", "↓", "↔", "↕",
     "‘", "’", "“", "”", "‚", "„","‹", "›", "«", "»", "–", "—", "‰", "™", "©", "®",
    "€"
  }

  local symbols_cp866 = {
    "А", "Б", "В", "Г", "Д", "Е", "Ж", "З", "И", "Й", "К", "Л", "М", "Н", "О", "П",
    "Р", "С", "Т", "У", "Ф", "Х", "Ц", "Ч", "Ш", "Щ", "Ъ", "Ы", "Ь", "Э", "Ю", "Я",
    "а", "б", "в", "г", "д", "е", "ж", "з", "и", "й", "к", "л", "м", "н", "о", "п",
    "░", "▒", "▓", "│", "┤", "╡", "╢", "╖", "╕", "╣", "║", "╗", "╝", "╜", "╛", "┐",
    "└", "┴", "┬", "├", "─", "┼", "╞", "╟", "╚", "╔", "╩", "╦", "╠", "═", "╬", "╧",
    "╨", "╤", "╥", "╙", "╘", "╒", "╓", "╫", "╪", "┘", "┌", "█", "▄", "▌", "▐", "▀",
    "р", "с", "т", "у", "ф", "х", "ц", "ч", "ш", "щ", "ъ", "ы", "ь", "э", "ю", "я",
    "Ё", "ё", "Є", "є", "Ї", "ї", "Ў", "ў", "°", "∙", "·", "√", "№", "¤", "■", " "
  }
  local symbols_cp1251 = {
    "Ђ", "Ѓ", "‚", "ѓ", "„", "…", "†", "‡", "€", "‰", "Љ", "‹", "Њ", "Ќ", "Ћ", "Џ",
    "ђ", "‘", "’", "“", "”", "•", "–", "—", "", "™", "љ", "›", "њ", "ќ", "ћ", "џ",
    " ", "Ў", "ў", "Ј", "¤", "Ґ", "¦", "§", "Ё", "©", "Є", "«", "¬", " ", "®", "Ї",
    "°", "±", "І", "і", "ґ", "µ", "¶", "·", "ё", "№", "є", "»", "ј", "Ѕ", "ѕ", "ї",
    "А", "Б", "В", "Г", "Д", "Е", "Ж", "З", "И", "Й", "К", "Л", "М", "Н", "О", "П",
    "Р", "С", "Т", "У", "Ф", "Х", "Ц", "Ч", "Ш", "Щ", "Ъ", "Ы", "Ь", "Э", "Ю", "Я",
    "а", "б", "в", "г", "д", "е", "ж", "з", "и", "й", "к", "л", "м", "н", "о", "п",
    "р", "с", "т", "у", "ф", "х", "ц", "ч", "ш", "щ", "ъ", "ы", "ь", "э", "ю", "я"
  }
  local symbols_cp20866 = {
    "─", "│", "┌", "┐", "└", "┘", "├", "┤", "┬", "┴", "┼", "▀", "▄", "█", "▌", "▐",
    "░", "▒", "▓", "⌠", "■", "∙", "√", "≈", "≤", "≥", " ", "⌡", "°", "²", "·", "÷",
    "═", "║", "╒", "ё", "╓", "╔", "╕", "╖", "╗", "╘", "╙", "╚", "╛", "╜", "╝", "╞",
    "╟", "╠", "╡", "Ё", "╢", "╣", "╤", "╥", "╦", "╧", "╨", "╩", "╪", "╫", "╬", "©",
    "ю", "а", "б", "ц", "д", "е", "ф", "г", "х", "и", "й", "к", "л", "м", "н", "о",
    "п", "я", "р", "с", "т", "у", "ж", "в", "ь", "ы", "з", "ш", "э", "щ", "ч", "ъ",
    "Ю", "А", "Б", "Ц", "Д", "Е", "Ф", "Г", "Х", "И", "Й", "К", "Л", "М", "Н", "О",
    "П", "Я", "Р", "С", "Т", "У", "Ж", "В", "Ь", "Ы", "З", "Ш", "Э", "Щ", "Ч", "Ъ"
  }

  local F = far.Flags
  local Items = {}

  -- Check window size
  local window_width, window_height
  local w = far.AdvControl(F.ACTL_GETFARRECT)
  if w then window_width, window_height = w.Right - w.Left + 1, w.Bottom - w.Top + 1 end
  local border_indent_x = 1
  local border_indent_y = 1

  local all_symbols = {}
  if include_symbols_7bit == true then
    for i = 0, 127 do
      table.insert(all_symbols, string.char(i))
    end
  end
  if include_symbols_8bit == true then
    for i = 128, 255 do
      table.insert(all_symbols, utf8.char(i))
    end
  end
  for j = 1, #include_symbols_encodings do
    if include_symbols_encodings[j] == "1251" then
      for i = 1, #symbols_cp1251 do
        table.insert(all_symbols, symbols_cp1251[i])
      end
    elseif include_symbols_encodings[j] == "866" then
      for i = 1, #symbols_cp866 do
        table.insert(all_symbols, symbols_cp866[i])
      end
    elseif include_symbols_encodings[j] == "20866" then
      for i = 1, #symbols_cp20866 do
        table.insert(all_symbols, symbols_cp20866[i])
      end
    else
      far.Message("Code page not supported: "..include_symbols_encodings[j], "Warning")
    end
  end
  for i = 1, #include_additional_symbols do
    table.insert(all_symbols, include_additional_symbols[i])
  end
  local draw_row_count = math.floor(#all_symbols / draw_column_count)
    + (math.fmod(#all_symbols, draw_column_count) > 0 and 1 or 0)
  if draw_row_count > window_height-3 then
    far.Message("The number of rows exceeds the window height", "Warning")
  end
  if draw_column_count > window_width-2 then
    far.Message("The number of columns exceeds the window width", "Warning")
  end

  -- Frame Creation
  table.insert(Items, {F.DI_DOUBLEBOX, 0, 0, 2+draw_column_count, 2+1+draw_row_count, 0, 0, 0, 0, macros_name})

  local x1, y1, div, mod

  for i = 1, #all_symbols do
    div = math.floor((i-1)/draw_column_count)
    mod = math.fmod(i-1, draw_column_count)
    x1 = border_indent_x+mod
    y1 = border_indent_y+div
    table.insert(Items, {F.DI_BUTTON, x1, y1, 0, 0, 0, 0, 0, F.DIF_NOBRACKETS, ""})
    local symb_char, symb_dec
    symb_char = all_symbols[i]
    symb_dec = utf8.byte(symb_char)
    if symb_dec == 38 then
      all_symbols[i] = "&"..symb_char
    elseif symb_dec == 0 then
      all_symbols[i] = " "
    elseif symb_dec == 173 then
      all_symbols[i] = " "
    end
  end

  table.insert(Items, {F.DI_TEXT, 1, draw_row_count+1, draw_column_count, 0, 0, 0, 0, 0, ""})

  local function Rebuild(hDlg, Param1, Param2)
    far.SendDlgMessage(hDlg, "DM_ENABLEREDRAW", 0)
    for i = 1, #all_symbols do
      far.SendDlgMessage(hDlg, "DM_SETTEXT", border_indent_y+i, all_symbols[i])
    end
    local symb_char, symb_dec, symb_hex
    symb_char = all_symbols[Param1-1]
    symb_dec = utf8.byte(symb_char)
    symb_hex = ("0x%.2X"):format(symb_dec)
    far.SendDlgMessage(hDlg, "DM_SETTEXT", #Items, "Char: "..symb_char.." Dec: "..symb_dec.." Hex: "..symb_hex)
    far.SendDlgMessage(hDlg, "DM_ENABLEREDRAW", 1)
  end

  local function DlgProc(hDlg, Msg, Param1, Param2)
    if Msg == F.DN_INITDIALOG then
      Rebuild(hDlg, Param1, Param2)
    elseif Msg == F.DN_CONTROLINPUT and Param2.EventType == F.KEY_EVENT then
        local key = far.InputRecordToName(Param2)
        if key == "Down" then
          local item_num = Param1+draw_column_count
          if item_num > #Items-1 then item_num = #Items-1; end
          hDlg:send(F.DM_SETFOCUS, item_num)
          return true
        elseif key == "Up" then
          local item_num = Param1-draw_column_count
          if item_num < 1 then item_num = 1; end
          hDlg:send(F.DM_SETFOCUS, item_num)
          return true
        end
      Rebuild(hDlg, Param1, Param2)
    elseif Msg == F.DN_GOTFOCUS then
      Rebuild(hDlg, Param1, Param2)
    elseif Msg == F.DN_BTNCLICK then
      Rebuild(hDlg, Param1, Param2)
    end
  end

  local result = far.Dialog(win.Uuid("D2E2C6D3-6142-4E11-B103-9D2F80BA19A7"), -1, -1, 2+draw_column_count, 2+1+draw_row_count, nil, Items, nil, DlgProc)
  if result > -1 then
    if Area.Editor then
      editor.InsertText(nil, all_symbols[result-1])
    elseif (Area.Dialog or Area.Shell) then
      mf.postmacro(print, all_symbols[result-1])
    end
  end

end

MenuItem {
  description = macros_name;
  menu   = "Plugins";
  area   = "Shell Editor Dialog";
  guid   = "DF8C9172-5AD7-4065-BE39-CB128700E7ED";
  text   = function() return macros_name end;
  action = function() Main() end;
}
