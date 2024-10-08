if not jit then
  return 
end
local F = far.Flags
local Col_Title = actl.GetColor(F.COL_VIEWERSTATUS)
local Col_Dialog = actl.GetColor(F.COL_VIEWERSTATUS)
local Col_Unchanged = actl.GetColor(F.COL_VIEWERTEXT)
local Col_Changed = actl.GetColor(F.COL_VIEWERARROWS)
local Col_Selected = actl.GetColor(F.COL_VIEWERSELECTEDTEXT)
local ffi = require('ffi')
local C = ffi.C
local dialogs = { }
local id = win.Uuid('02FFA2B9-98F8-4A73-B311-B3431340E272')
local idPos = win.Uuid('4FEA7612-507B-453F-A83D-53837CAD86ED')
ffi.cdef([[HANDLE WINPORT_CreateFile (LPCWSTR lpFileName, DWORD dwDesiredAccess, DWORD dwShareMode, void* lpSecurityAttributes, DWORD dwCreationDisposition, DWORD dwFlagsAndAttributes, HANDLE hTemplateFile);
WINBOOL WINPORT_GetFileSizeEx (HANDLE hFile, int64_t* lpFileSize);
WINBOOL WINPORT_SetFilePointerEx (HANDLE hFile, int64_t liDistanceToMove, void* lpNewFilePointer, DWORD dwMoveMethod);
WINBOOL WINPORT_ReadFile (HANDLE hFile, LPVOID lpBuffer, DWORD nNumberOfBytesToRead, LPDWORD lpNumberOfBytesRead, void* lpOverlapped);
WINBOOL WINPORT_WriteFile (HANDLE hFile, LPCVOID lpBuffer, DWORD nNumberOfBytesToWrite, LPDWORD lpNumberOfBytesWritten, void* lpOverlapped);
WINBOOL WINPORT_CloseHandle (HANDLE hObject);
]])
local INVALID_HANDLE_VALUE = ffi.cast('void*', -1)
local GENERIC_READ = 0x80000000
local GENERIC_WRITE = 0x40000000
local FILE_SHARE_READ = 1
local FILE_SHARE_WRITE = 2
local FILE_SHARE_DELETE = 4
local OPEN_EXISTING = 3
local FILE_BEGIN = 0
local WSIZE = ffi.sizeof("wchar_t")
local HelpText = [[F1        Help window
F3        Toggle view/edit mode
F9        Save
BS        Restore the changed cell value
Tab       Toggle Hex/Text editing area
AltF8     "Go to" dialog
Esc       Quit Hex Editor]]
local ToWChar
ToWChar = function(str)
  str = win.Utf8ToUtf32(str)
  local result = ffi.new('wchar_t[?]', #str / WSIZE + 1)
  ffi.copy(result, str)
  return result
end
local LongPath
LongPath = function(path)
  return path
end
local ConsoleSize
ConsoleSize = function()
  local rr = far.AdvControl(F.ACTL_GETFARRECT)
  return rr.Right - rr.Left + 1, rr.Bottom - rr.Top + 1
end
local UnicodeThunk
UnicodeThunk = function(fn, txt, codepage)
  local _exp_0 = codepage
  if 1200 == _exp_0 then
    return txt
  elseif 1201 == _exp_0 then
    local result = ''
    local sub
    sub = function(s, p)
      return string.sub(s, p, p)
    end
    for ii = 1, #txt / 2 do
      result = result .. ((sub(txt, ii * 2)) .. (sub(txt, ii * 2 - 1)))
    end
    return result
  else
    return fn(txt, codepage)
  end
end
local MB2WC
MB2WC = function(txt, codepage)
  return UnicodeThunk(win.MultiByteToWideChar, txt, codepage)
end
local WC2MB
WC2MB = function(txt, codepage)
  return UnicodeThunk(win.WideCharToMultiByte, txt, codepage)
end
local GenerateDisplayText
GenerateDisplayText = function(txt, codepage)
  local wide = MB2WC(txt, codepage)
  local out = ''
  for ii = 1, #wide, WSIZE do
    local wchar = string.sub(wide, ii, ii - 1 + WSIZE)
    if wchar == '\0\0\0\0' then
      wchar = '.\0\0\0'
    end
    out = out .. ((win.WideCharToMultiByte(wchar, 65001)) .. string.rep('.', #(WC2MB(wchar, codepage)) - 1))
  end
  return out
end
local Read
Read = function(data)
  do
    local _with_0 = data
    C.WINPORT_SetFilePointerEx(_with_0.file, _with_0.offset, ffi.NULL, FILE_BEGIN)
    local readed = ffi.new('DWORD[1]')
    local buff = ffi.new('uint8_t[?]', 16 * _with_0.height)
    C.WINPORT_ReadFile(_with_0.file, buff, 16 * _with_0.height, readed, ffi.NULL)
    _with_0.chunk = ffi.string(buff, readed[0])
    _with_0.displaytext = GenerateDisplayText(_with_0.chunk, _with_0.codepage)
    return _with_0
  end
end
local Write
Write = function(data)
  do
    local _with_0 = data
    local fileW = C.WINPORT_CreateFile(_with_0.filenameW, GENERIC_WRITE, FILE_SHARE_READ, ffi.NULL, OPEN_EXISTING, 0, ffi.NULL)
    if fileW ~= INVALID_HANDLE_VALUE then
      C.WINPORT_SetFilePointerEx(fileW, _with_0.offset, ffi.NULL, FILE_BEGIN)
      local written = ffi.new('DWORD[1]')
      C.WINPORT_WriteFile(fileW, _with_0.chunk, #_with_0.chunk, written, ffi.NULL)
      C.WINPORT_CloseHandle(fileW)
    end
    return _with_0
  end
end
local GetOffset
GetOffset = function()
  local _pos = 2
  local items = {
    {
      'DI_DOUBLEBOX',
      3,
      1,
      56,
      3,
      0,
      0,
      0,
      0,
      'Go to'
    },
    {
      'DI_EDIT',
      5,
      2,
      54,
      0,
      0,
      'HexEdGotoPos',
      0,
      F.DIF_HISTORY + F.DIF_USELASTHISTORY,
      ''
    }
  }
  local result = false
  local hDlg = far.DialogInit(idPos, -1, -1, 60, 5, nil, items)
  if _pos == far.DialogRun(hDlg) then
    result = tonumber(hDlg:GetText(_pos))
  end
  far.DialogFree(hDlg)
  return result
end
local _title, _view, _edit = 1, 2, 3
local HexDraw
HexDraw = function(hDlg, data)
  local DrawStr
  DrawStr = function(pos, str, textel)
    if textel == nil then
      textel = data.textel
    end
    local len = str:len()
    for ii = 1, len do
      textel.Char = str:byte(ii)
      data.buffer[pos + ii - 1] = textel
    end
  end
  local GetChar
  GetChar = function(pos)
    local char = string.format('%02X', string.byte(data.chunk, pos))
    return char, data.edit and (string.format('%02X', string.byte(data.oldchunk, pos))) or char
  end
  data.textel.Char = 0x20
  for ii = 1, #data.buffer do
    data.buffer[ii] = data.textel
  end
  local len = #data.chunk
  for row = 0, data.height - 1 do
    if row * 16 < len then
      DrawStr(row * data.width + 1, string.format('%010X:', tonumber(data.offset + row * 16)))
      data.textel.Char = 0x2502
      data.buffer[row * data.width + 24 + 1 + 12] = data.textel
    end
    for col = 1, 16 do
      local pos = col + row * 16
      if pos <= len then
        local char, oldchar = GetChar(pos)
        local txtl = pos == data.cursor and not data.edit and data.textel_sel or (char == oldchar and data.textel or data.textel_changed)
        DrawStr(row * data.width + (col - 1) * 3 + 1 + 12 + (col > 8 and 2 or 0), char, txtl)
        DrawStr(row * data.width + 16 * 3 + 2 + 1 + 12 + col, (data.displaytext:sub(pos, pos)), txtl)
      end
    end
  end
  if data.edit then
    local xx, yy = data.editascii and 63 + (data.cursor - 1) % 16 or (data.cursor - 1) % 16, 1 + math.floor((data.cursor - 1) / 16)
    if not data.editascii then
      xx = 12 + xx * 3 + (xx > 7 and 2 or 0) + data.editpos
    end
    hDlg:SetItemPosition(_edit, {
      Left = xx,
      Top = yy,
      Right = xx,
      Bottom = yy
    })
    local char, oldchar = GetChar(data.cursor)
    data.editchanged = char ~= oldchar
    return hDlg:SetText(_edit, data.editascii and (data.displaytext:sub(data.cursor, data.cursor)) or string.sub(char, data.editpos + 1, data.editpos + 1))
  end
end
local UpdateDlg
UpdateDlg = function(hDlg, data)
  if not data.edit then
    Read(data)
  end
  HexDraw(hDlg, data)
  return hDlg:Redraw()
end
local DlgProc
DlgProc = function(hDlg, Msg, Param1, Param2)
  local data = dialogs[hDlg:rawhandle()]
  if data then
    if Msg == F.DN_CLOSE then
      C.WINPORT_CloseHandle(data.file)
      dialogs[hDlg:rawhandle()] = nil
    elseif Msg == F.DN_CTLCOLORDIALOG then
      return Col_Dialog
    elseif Msg == F.DN_CTLCOLORDLGITEM then
      local DoColor
      DoColor = function(color)
        return {
          color,
          color,
          color,
          color
        }
      end
      local _exp_0 = Param1
      if _title == _exp_0 then
        return DoColor(Col_Title)
      elseif _edit == _exp_0 then
        return DoColor(data.editchanged and Col_Changed or Col_Unchanged)
      end
    elseif Msg == F.DN_KILLFOCUS then
      if Param1 == _edit and data.edit then
        return _edit
      end
    elseif Msg == F.DN_RESIZECONSOLE then
      local item = hDlg:GetDlgItem(_view)
      if item then
        data.width, data.height = ConsoleSize()
        data.height = data.height - 1
        data.buffer = far.CreateUserControl(data.width, data.height)
        item[4] = data.width - 1
        item[5] = data.height
        item[7] = data.buffer
        hDlg:SetDlgItem(_view, item)
        hDlg:ResizeDialog(0, {
          X = data.width,
          Y = data.height + 1
        })
        UpdateDlg(hDlg, data)
      end
    elseif Msg == F.DN_KEY then
      local processed = true
      do
        local Update
        Update = function(inc)
          if not data.edit then
            local old_offset = data.offset
            data.offset = data.offset + inc
            if data.offset >= data.filesize then
              if (data.filesize - old_offset - 1) <= data.height * 16 then
                data.offset = old_offset
              else
                data.offset = data.filesize - 1
              end
            end
            if data.offset < 0 then
              data.offset = 0
            end
            data.offset = data.offset - data.offset % 16
          end
        end
        local DoRight
        DoRight = function()
          if not data.edit then
            if data.cursor + data.offset < data.filesize then
              data.cursor = data.cursor + 1
            end
            if data.cursor > data.height * 16 then
              data.cursor = data.cursor - 16
              return Update(16)
            end
          elseif data.cursor < data.height * 16 and data.cursor + data.offset < data.filesize and (data.editpos == 1 or data.editascii) then
            data.cursor = data.cursor + 1
            data.editpos = 0
          else
            data.editpos = 1
          end
        end
        local DoLeft
        DoLeft = function()
          if not data.edit then
            data.cursor = data.cursor - 1
            if data.cursor < 1 then
              if data.offset > 0 then
                data.cursor = 16
                return Update(-16)
              else
                data.cursor = 1
              end
            end
          elseif data.cursor > 1 and (data.editpos == 0 or data.editascii) then
            data.cursor = data.cursor - 1
            data.editpos = 1
          else
            data.editpos = 0
          end
        end
        local DoUp
        DoUp = function()
          data.cursor = data.cursor - 16
          if data.cursor < 1 then
            data.cursor = data.cursor + 16
            if data.offset > 0 then
              return Update(-16)
            end
          end
        end
        local DoDown
        DoDown = function()
          data.cursor = data.cursor + 16
          if data.cursor + data.offset > data.filesize then
            data.cursor = data.cursor - 16
            if data.offset + data.height * 16 < data.filesize then
              data.cursor = data.cursor - 16
              Update(16)
            end
          end
          if data.cursor > data.height * 16 then
            data.cursor = data.cursor - 16
            return Update(16)
          end
        end
        local DoEditMode
        DoEditMode = function()
          data.edit = not data.edit
          data.editpos = 0
          data.oldchunk = data.edit and data.chunk or nil
          hDlg:ShowItem(_edit, data.edit and 1 or 0)
          return hDlg:SetFocus(data.edit and _edit or _view)
        end
        local uchar = Param2
        if data.edit and data.editascii and uchar ~= 0 and uchar ~= 9 and uchar ~= 27 and uchar < 0x10000 then
          local t = { }
          for k = 1, WSIZE do
            t[k] = uchar % 0x100
            uchar = (uchar - t[k]) / 0x100
          end
          local new = win.WideCharToMultiByte((string.char(unpack(t))), data.codepage)
          data.chunk = (string.sub(data.chunk, 1, data.cursor - 1)) .. new .. (string.sub(data.chunk, data.cursor + #new))
          data.oldchunk = data.oldchunk .. string.rep('\0', #data.chunk - #data.oldchunk)
          data.displaytext = GenerateDisplayText(data.chunk, data.codepage)
          for _ = 1, #new do
            DoRight()
          end
        else
          local key = far.KeyToName(Param2)
          local _exp_0 = key
          if '0' == _exp_0 or '1' == _exp_0 or '2' == _exp_0 or '3' == _exp_0 or '4' == _exp_0 or '5' == _exp_0 or '6' == _exp_0 or '7' == _exp_0 or '8' == _exp_0 or '9' == _exp_0 or 'A' == _exp_0 or 'B' == _exp_0 or 'C' == _exp_0 or 'D' == _exp_0 or 'E' == _exp_0 or 'F' == _exp_0 or 'a' == _exp_0 or 'b' == _exp_0 or 'c' == _exp_0 or 'd' == _exp_0 or 'e' == _exp_0 or 'f' == _exp_0 then
            if data.edit then
              local old = string.byte(data.chunk, data.cursor)
              local new = data.editpos == 0 and ((tonumber(key, 16)) * 16 + old % 16) or (16 * (math.floor(old / 16)) + tonumber(key, 16))
              data.chunk = (string.sub(data.chunk, 1, data.cursor - 1)) .. (string.char(new)) .. (string.sub(data.chunk, data.cursor + 1))
              data.displaytext = GenerateDisplayText(data.chunk, data.codepage)
              DoRight()
            end
          elseif 'F3' == _exp_0 then
            DoEditMode()
          elseif 'F9' == _exp_0 then
            if data.edit then
              Write(data)
              DoEditMode()
            end
          elseif 'Left' == _exp_0 then
            DoLeft()
          elseif 'Right' == _exp_0 then
            DoRight()
          elseif 'Home' == _exp_0 then
            data.cursor = data.cursor - ((data.cursor - 1) % 16)
            data.editpos = 0
          elseif 'End' == _exp_0 then
            data.cursor = data.cursor + 16
            data.cursor = data.cursor - (data.cursor - 1) % 16 - 1
            if data.cursor + data.offset > data.filesize then
              data.cursor = tonumber(data.filesize - data.offset)
            end
            data.editpos = 1
          elseif 'Up' == _exp_0 then
            DoUp()
          elseif 'Down' == _exp_0 then
            DoDown()
          elseif 'CtrlPgUp' == _exp_0 or 'RCtrlPgUp' == _exp_0 or 'CtrlUp' == _exp_0 or 'RCtrlUp' == _exp_0 then
            if data.edit then
              DoUp()
            else
              if data.offset == 0 and data.cursor > 16 then
                data.cursor = data.cursor - 16
              else
                Update(-16)
              end
            end
          elseif 'CtrlPgDn' == _exp_0 or 'RCtrlPgDn' == _exp_0 or 'CtrlDown' == _exp_0 or 'RCtrlDown' == _exp_0 then
            if data.edit then
              DoDown()
            else
              if data.offset + data.height * 16 < data.filesize then
                Update(16)
              elseif data.offset + data.cursor + 16 <= data.filesize then
                data.cursor = data.cursor + 16
              end
            end
          elseif 'PgUp' == _exp_0 then
            if data.offset == 0 or data.edit then
              data.cursor = (data.cursor - 1) % 16 + 1
            else
              Update(-16 * data.height)
            end
          elseif 'PgDn' == _exp_0 then
            local fixcursor
            fixcursor = function()
              local rest = data.filesize - data.offset
              data.cursor = tonumber(rest - ((15 - (data.cursor - 1) % 16) + rest % 16) % 16)
            end
            if data.offset + data.height * 16 < data.filesize then
              if data.edit then
                data.cursor = (data.height - 1) * 16 + (data.cursor - 1) % 16 + 1
              else
                Update(16 * data.height)
                if data.cursor + data.offset > data.filesize then
                  fixcursor()
                end
              end
            else
              fixcursor()
            end
          elseif 'CtrlHome' == _exp_0 or 'RCtrlHome' == _exp_0 then
            Update(-data.filesize)
            data.cursor = 1
          elseif 'CtrlEnd' == _exp_0 or 'RCtrlEnd' == _exp_0 then
            Update(data.filesize - data.offset - 1 - (data.height - 1) * 16)
            if not data.edit then
              data.cursor = tonumber(data.filesize - data.offset)
            end
          elseif (data.edit and 'Esc') == _exp_0 then
            DoEditMode()
          elseif (data.edit and 'Ins') == _exp_0 then
            local _ = nil
          elseif 'BS' == _exp_0 then
            if data.edit then
              local idx = data.cursor - (0 == data.editpos and 1 or 0)
              data.chunk = (string.sub(data.chunk, 1, idx - 1)) .. (string.sub(data.oldchunk, idx, idx)) .. (string.sub(data.chunk, idx + 1))
              data.displaytext = GenerateDisplayText(data.chunk, data.codepage)
              DoLeft()
            end
          elseif 'Tab' == _exp_0 then
            data.editascii = data.edit and not data.editascii
          elseif 'AltF8' == _exp_0 or 'RAltF8' == _exp_0 then
            if not data.edit then
              local offset = GetOffset()
              if offset then
                data.offset = offset - offset % 16
              end
            end
          elseif 'CtrlF10' == _exp_0 or 'RCtrlF10' == _exp_0 then
            if not data.edit then
              viewer.SetPosition(tonumber(data.offset))
            end
          elseif 'F1' == _exp_0 then
            far.Message(HelpText, 'Hex Editor', nil, 'l')
          else
            processed = false
          end
        end
      end
      if processed then
        UpdateDlg(hDlg, data)
        return true
      end
    end
  end
  return nil
end
local DoHex
DoHex = function()
  local filename = viewer.GetFileName()
  local filenameW = ToWChar(LongPath(filename))
  local file = C.WINPORT_CreateFile(filenameW, GENERIC_READ, FILE_SHARE_READ + FILE_SHARE_WRITE + FILE_SHARE_DELETE, ffi.NULL, OPEN_EXISTING, 0, ffi.NULL)
  if file ~= INVALID_HANDLE_VALUE then
    local filesize = ffi.new('int64_t[1]')
    if 0 ~= C.WINPORT_GetFileSizeEx(file, filesize) then
      local ww, hh = ConsoleSize()
      local buffer = far.CreateUserControl(ww, hh - 1)
      local textel = {
        Char = 0x20,
        Attributes = Col_Unchanged
      }
      local textel_sel = {
        Char = 0x20,
        Attributes = Col_Selected
      }
      local textel_changed = {
        Char = 0x20,
        Attributes = Col_Changed
      }
      local info = viewer.GetInfo()
      local offset = info.FilePos
      offset = offset - (offset % 16)
      local items = {
        {
          F.DI_TEXT,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          filename
        },
        {
          F.DI_USERCONTROL,
          0,
          1,
          ww - 1,
          hh - 1,
          buffer,
          0,
          0,
          0,
          ''
        },
        {
          F.DI_FIXEDIT,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          F.DIF_HIDDEN + F.DIF_READONLY,
          ''
        }
      }
      local hDlg = far.DialogInit(id, -1, -1, ww, hh, nil, items, F.FDLG_NONMODAL + F.FDLG_NODRAWSHADOW, DlgProc)
      if hDlg then
        dialogs[hDlg:rawhandle()] = {
          buffer = buffer,
          width = ww,
          height = hh - 1,
          file = file,
          filenameW = filenameW,
          codepage = info.CurMode.CodePage,
          ViewerID = info.ViewerID,
          offset = offset,
          cursor = 1,
          filesize = filesize[0],
          textel = textel,
          textel_sel = textel_sel,
          textel_changed = textel_changed,
          edit = false,
          editpos = 0,
          editchanged = false,
          editascii = false
        }
        return UpdateDlg(hDlg, dialogs[hDlg:rawhandle()])
      end
    else
      return C.WINPORT_CloseHandle(file)
    end
  end
end
return Macro({
  description = 'HEX Editor',
  area = 'Viewer',
  key = 'CtrlF4',
  action = DoHex
})
