-- Author: Vadim Yegorov (zg)
-- URL: https://github.com/trexinc/evil-programmers/blob/master/LuaHexEd/Macros/scripts/hexed.moon
-- Modifications by Shmuel Zeigerman:
--   * Adaptation to far2m
--   * Help message box
--   * Customizable persistent colors
--   * Setting position with a mouse click
--   * Switching ANSI/OEM code page by F8
--   * Fix: the editor withstands resizing
--   * Fix: handling BS in editing mode in the text part

--BACKUP YOUR FILES BEFORE USE
if not jit then return -- LuaJIT required

import floor,max,min from math
import byte,char,format,rep,sub from string
F=far.Flags
SETTINGS_KEY  = "hexed"
SETTINGS_NAME = "settings"
Settings = nil
Colors = nil

ffi=require'ffi'
C=ffi.C
MinWidth=80 -- must fully cover the right (displaytext) part
dialogs={}
id=win.Uuid'02FFA2B9-98F8-4A73-B311-B3431340E272'
idPos=win.Uuid'4FEA7612-507B-453F-A83D-53837CAD86ED'
ffi.cdef[[
HANDLE WINPORT_CreateFile (LPCWSTR lpFileName, DWORD dwDesiredAccess, DWORD dwShareMode, void* lpSecurityAttributes, DWORD dwCreationDisposition, DWORD dwFlagsAndAttributes, HANDLE hTemplateFile);
WINBOOL WINPORT_GetFileSizeEx (HANDLE hFile, int64_t* lpFileSize);
WINBOOL WINPORT_SetFilePointerEx (HANDLE hFile, int64_t liDistanceToMove, void* lpNewFilePointer, DWORD dwMoveMethod);
WINBOOL WINPORT_ReadFile (HANDLE hFile, LPVOID lpBuffer, DWORD nNumberOfBytesToRead, LPDWORD lpNumberOfBytesRead, void* lpOverlapped);
WINBOOL WINPORT_WriteFile (HANDLE hFile, LPCVOID lpBuffer, DWORD nNumberOfBytesToWrite, LPDWORD lpNumberOfBytesWritten, void* lpOverlapped);
WINBOOL WINPORT_CloseHandle (HANDLE hObject);
]]
INVALID_HANDLE_VALUE=ffi.cast 'void*',-1
GENERIC_READ=0x80000000
GENERIC_WRITE=0x40000000
FILE_SHARE_READ=1
FILE_SHARE_WRITE=2
FILE_SHARE_DELETE=4
OPEN_EXISTING=3
FILE_BEGIN=0
WSIZE=ffi.sizeof("wchar_t")

HelpText = [[
F1           Help window
F3           Toggle view/edit mode
F8           Toggle ANSI/OEM text area
F9           Save
BS           Restore the changed cell value
Tab          Toggle Hex/Text editing area
AltF8        "Go to" dialog
AltShiftF9   Edit colors
CtrlF10      Synchronize viewer position
Esc          Quit Hex Editor]]

GetDefaultColors=-> {
    Title:     actl.GetColor F.COL_VIEWERSTATUS,
    Unchanged: actl.GetColor F.COL_VIEWERTEXT,
    Changed:   actl.GetColor F.COL_VIEWERARROWS,
    Selected:  actl.GetColor F.COL_VIEWERSELECTEDTEXT
  }

LoadSettings=->
  Settings=mf.mload(SETTINGS_KEY,SETTINGS_NAME) or {}
  Colors=Settings.Colors or GetDefaultColors!

SaveSettings=->
  Settings.Colors=Colors
  mf.msave SETTINGS_KEY,SETTINGS_NAME,Settings

ChangeColor=(data)->
  props = { Title:"Select a color to edit" }
  items = {
    { text:"Unchanged" , val:"Unchanged" , key:"textel"}
    { text:"Changed"   , val:"Changed"   , key:"textel_changed"}
    { text:"Selected"  , val:"Selected"  , key:"textel_sel" }
    { text:"Title"     , val:"Title" }
    { separator:true }
    { text:"Set default colors", reset:true }
  }
  while true
    sel,pos = far.Menu props,items
    return if not sel
    props.SelectIndex=pos

    if sel.reset
      Colors=GetDefaultColors!
      for v in *items
        if v.key then data[v.key].Attributes = Colors[v.val]
      return true

    clr = far.ColorDialog Colors[sel.val], 0x03
    if clr
      clr=clr.Color
      if sel.key
        data[sel.key].Attributes=clr
      Colors[sel.val]=clr
      return true

ToWChar=(str)->
  str=win.Utf8ToUtf32 str
  result=ffi.new 'wchar_t[?]',#str/WSIZE+1
  ffi.copy result,str
  result

LongPath=(path)-> path
--  type=path\match([[^\\(.?.?)]])
--  type and (([[?\]]==type or [[.\]]==type) and path or [[\\?\UNC]]..path\sub(2)) or [[\\?\]]..path

ConsoleSize=->
  rr=far.AdvControl F.ACTL_GETFARRECT
  rr.Right-rr.Left+1,rr.Bottom-rr.Top+1

UnicodeThunk=(fn,txt,codepage)->
  switch codepage
    when 1200
      txt
    when 1201
      result=''
      at=(s,p)->sub s,p,p
      for ii=1,#txt/2
        result..=(at txt,ii*2)..(at txt,ii*2-1)
      result
    else
      fn txt,codepage

MB2WC=(txt,codepage)->UnicodeThunk win.MultiByteToWideChar,txt,codepage
WC2MB=(txt,codepage)->UnicodeThunk win.WideCharToMultiByte,txt,codepage

GenerateDisplayText=(txt,codepage)->
  wide=MB2WC txt,codepage
  out=''
  for ii=1,#wide,WSIZE
    wchar=sub wide,ii,ii-1+WSIZE
    if wchar=='\0\0\0\0' -- DI_USERCONTROL in far2l displays binary zeroes as white rectangles. Prevent that.
      wchar='.\0\0\0'
    out..=(win.WideCharToMultiByte wchar,65001)..rep '.',#(WC2MB wchar,codepage)-1
  out

Read=(data)->
  with data
    C.WINPORT_SetFilePointerEx .file,.offset,ffi.NULL,FILE_BEGIN
    readed=ffi.new'DWORD[1]'
    buff=ffi.new 'uint8_t[?]',16*.height
    C.WINPORT_ReadFile .file,buff,16*.height,readed,ffi.NULL
    .chunk=ffi.string buff,readed[0]
    .displaytext=GenerateDisplayText .chunk,.codepage

Write=(data)->
  with data
    fileW=C.WINPORT_CreateFile .filenameW,GENERIC_WRITE,FILE_SHARE_READ,ffi.NULL,OPEN_EXISTING,0,ffi.NULL
    if fileW~=INVALID_HANDLE_VALUE
      C.WINPORT_SetFilePointerEx fileW,.offset,ffi.NULL,FILE_BEGIN
      written=ffi.new'DWORD[1]'
      C.WINPORT_WriteFile fileW,.chunk,#.chunk,written,ffi.NULL
      C.WINPORT_CloseHandle fileW

GetOffset=->
  _pos=2
  items={
    {'DI_DOUBLEBOX',3,1,56,3,0,0             ,0,0                                 ,'Go to'},
    {'DI_EDIT',     5,2,54,0,0,'HexEdGotoPos',0,F.DIF_HISTORY+F.DIF_USELASTHISTORY,''},
  }
  result=false
  hDlg=far.DialogInit idPos,-1,-1,60,5,nil,items
  if _pos==far.DialogRun hDlg
    result=tonumber hDlg\GetText _pos
  far.DialogFree hDlg
  result

_title,_view,_edit=1,2,3

HexDraw=(hDlg,data)->
  DrawStr=(pos,str,textel=data.textel)->
    len=str\len!
    for ii=1,len
      textel.Char=str\byte ii
      data.buffer[pos+ii-1]=textel

  GetChar=(pos)->
    char=format '%02X',byte data.chunk,pos
    char,data.edit and (format '%02X',byte data.oldchunk,pos) or char

  with data
    -- Fill buffer with spaces
    .textel.Char=0x20
    for ii=1,#.buffer do
      .buffer[ii]=.textel
    -- Draw all
    len=#.chunk
    for row=0,.height-1
      -- Draw offsets and vertical line
      if row*16<len
        DrawStr row*.width+1,format '%010X:',tonumber .offset+row*16
        .textel.Char=0x2502
        .buffer[row*.width+24+1+12]=.textel
      -- Draw hex data
      for col=1,16
        pos=col+row*16
        if pos<=len
          char,oldchar=GetChar pos
          txtl=pos==.cursor and not .edit and .textel_sel or
            (char==oldchar and .textel or .textel_changed)
          DrawStr row*.width+(col-1)*3+1+12+(col>8 and 2 or 0),char,txtl
          DrawStr row*.width+16*3+2+1+12+col,(.displaytext\sub pos,pos),txtl
    if .edit
      cursor=tonumber .cursor
      xx,yy=.editascii and 63+(cursor-1)%16 or (cursor-1)%16,1+floor (cursor-1)/16
      xx=12+xx*3+(xx>7 and 2 or 0)+.editpos if not .editascii
      hDlg\SetItemPosition _edit,{Left:xx,Top:yy,Right:xx,Bottom:yy}
      char,oldchar=GetChar cursor
      .editchanged=char~=oldchar
      hDlg\SetText _edit,.editascii and (.displaytext\sub cursor,cursor) or
        sub char,.editpos+1,.editpos+1

UpdateDlg=(hDlg,data)->
  if not data.edit then Read data
  HexDraw hDlg,data
  hDlg\Redraw!

MakeTitle=(fname,codepage)->
  fname.." ["..codepage.."]"

MSClickEvalCursor=(X,Y)->
  if X < 12
    1 + 16*Y
  elseif X < 36
    X -= 12
    1 + 16*Y + (X-X%3)/3
  elseif X == 36 or X == 37
    1 + 16*Y + 8
  elseif X < 62
    X -= 38
    1 + 16*Y + 8 + (X-X%3)/3
  elseif X == 62
    1 + 16*Y
  elseif X < 63+16
    1 + 16*Y + (X-63)
  else
    1 + 16*Y + 15

DlgProc=(hDlg,Msg,Param1,Param2)->
  data=dialogs[hDlg\rawhandle!]
  return nil if not data

  with data
    DoEditMode=()->
      .edit=not .edit
      .editpos=0
      .oldchunk=.edit and .chunk or nil
      hDlg\ShowItem _edit, .edit and 1 or 0
      hDlg\SetFocus .edit and _edit or _view

    if Msg==F.DN_CLOSE
      C.WINPORT_CloseHandle .file
      dialogs[hDlg\rawhandle!]=nil
    elseif Msg==F.DN_CTLCOLORDIALOG
      return Colors.Title
    elseif Msg==F.DN_CTLCOLORDLGITEM
      DoColor=(color)->
        {color,color,color,color}
      return switch Param1
        when _title
          DoColor Colors.Title
        when _edit
          DoColor .editchanged and Colors.Changed or Colors.Unchanged
    elseif Msg==F.DN_KILLFOCUS
      if Param1==_edit and .edit then return _edit
    elseif Msg==F.DN_RESIZECONSOLE
      item=hDlg\GetDlgItem _view
      if item
        .width,.height=ConsoleSize!
        .width=max MinWidth,.width
        .height-=1
        .buffer=far.CreateUserControl .width,.height
        item[4]=.width-1
        item[5]=.height
        item[6]=.buffer
        hDlg\SetDlgItem _view,item
        hDlg\ResizeDialog 0,{X:.width,Y:.height+1}
        UpdateDlg hDlg,data
    elseif Msg==F.DN_KEY
      processed=true
      Update=(inc)->
        if not .edit
          old_offset=.offset
          .offset+=inc
          if .offset>=.filesize
            if (.filesize-old_offset-1)<=.height*16 then .offset=old_offset
            else .offset=.filesize-1
          if .offset<0 then .offset=0
          .offset-=.offset%16
      DoRight=->
        if not .edit
          if .cursor+.offset<.filesize then .cursor+=1
          if .cursor>.height*16
            .cursor-=16
            Update 16
        elseif .cursor<.height*16 and .cursor+.offset<.filesize and (.editpos==1 or .editascii)
          .cursor+=1
          .editpos=0
        else .editpos=1
      DoLeft=->
        if not .edit
          .cursor-=1
          if .cursor<1
            if .offset>0
              .cursor=16
              Update -16
            else .cursor=1
        elseif .cursor>1 and (.editpos==0 or .editascii)
          .cursor-=1
          .editpos=1
        else .editpos=0
      DoUp=->
        .cursor-=16
        if .cursor<1
          .cursor+=16
          if .offset>0 then Update -16
      DoDown=->
        .cursor+=16
        if .cursor+.offset>.filesize
          .cursor-=16
          if .offset+.height*16<.filesize
            .cursor-=16
            Update 16
        if .cursor>.height*16
          .cursor-=16
          Update 16
      --uchar=(Param2.UnicodeChar\sub 1,1)\byte 1
      uchar=Param2
      if .edit and .editascii and uchar~=0 and uchar~=8 and uchar~=9 and uchar~=27 and uchar<0x10000
        t={}
        for k=1,WSIZE
          t[k]=uchar%0x100
          uchar=(uchar-t[k])/0x100
        new=win.WideCharToMultiByte (char unpack t),.codepage
        .chunk=(sub .chunk,1,.cursor-1)..new..(sub .chunk,.cursor+#new)
        .oldchunk..=rep '\0',#.chunk-#.oldchunk
        .displaytext=GenerateDisplayText .chunk,.codepage
        for _=1,#new do DoRight!
      else
        key=far.KeyToName Param2
        switch key
          when '0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F','a','b','c','d','e','f'
            if .edit
              old=byte .chunk,.cursor
              new=.editpos==0 and ((tonumber key,16)*16+old%16) or (16*(floor old/16)+tonumber key,16)
              .chunk=(sub .chunk,1,.cursor-1)..(char new)..(sub .chunk,.cursor+1)
              .displaytext=GenerateDisplayText .chunk,.codepage
              DoRight!
          when 'F3' then DoEditMode!
          when 'F9'
            if .edit
              Write data
              DoEditMode!
          when 'Left' then DoLeft!
          when 'Right' then DoRight!
          when 'Home'
            .cursor-=(.cursor-1)%16
            .editpos=0
          when 'End'
            .cursor+=16
            .cursor=.cursor-(.cursor-1)%16-1
            if .cursor+.offset>.filesize
              .cursor=tonumber .filesize-.offset
            .editpos=1
          when 'Up' then DoUp!
          when 'Down' then DoDown!
          when 'CtrlPgUp','RCtrlPgUp','CtrlUp','RCtrlUp','MsWheelUp'
            if .edit then DoUp!
            else
              if .offset==0 and .cursor>16 then .cursor-=16
              else Update -16
          when 'CtrlPgDn','RCtrlPgDn','CtrlDown','RCtrlDown','MsWheelDown'
            if .edit then DoDown!
            else
              if .offset+.height*16<.filesize
                Update 16
              elseif .offset+.cursor+16<=.filesize
                .cursor+=16
          when 'PgUp'
            if .offset==0 or .edit then .cursor=(.cursor-1)%16+1
            else Update -16*.height
          when 'PgDn'
            fixcursor=->
              rest=.filesize-.offset
              .cursor=tonumber rest-((15-(.cursor-1)%16)+rest%16)%16
            if .offset+.height*16<.filesize
              if .edit
                .cursor=(.height-1)*16+(.cursor-1)%16+1
              else
                Update 16*.height
                if .cursor+.offset>.filesize then fixcursor!
            else fixcursor!
          when 'CtrlHome','RCtrlHome'
            Update -.filesize
            .cursor=1
          when 'CtrlEnd','RCtrlEnd'
            Update .filesize-.offset-1-(.height-1)*16
            if not .edit then .cursor=tonumber .filesize-.offset
          when .edit and 'Esc' then DoEditMode!
          when .edit and 'Ins' then nil -- don't change cursor shape
          when 'BS'
            if .edit
              idx=.cursor-(0==.editpos and 1 or 0)
              .chunk=(sub .chunk,1,idx-1)..(sub .oldchunk,idx,idx)..(sub .chunk,idx+1)
              .displaytext=GenerateDisplayText .chunk,.codepage
              DoLeft!
          when 'Tab' then .editascii=.edit and not .editascii
          when 'AltF8','RAltF8'
            if not .edit
              offs=GetOffset!
              if offs
                offs=min (max 0,offs),.filesize-1
                .offset=offs-offs%16
                .cursor=offs%16+1
          when 'CtrlF10','RCtrlF10'
            if not .edit
              viewer.SetPosition .ViewerID, tonumber .offset
          when 'F1'
            far.Message HelpText,'Hex Editor',nil,'l'
          when 'F8'
            if not .edit
              cp=win.GetACP!
              .codepage = .codepage==cp and win.GetOEMCP! or cp
              hDlg\SetText _title, MakeTitle .filenameU,.codepage
          when 'AltShiftF9'
            if ChangeColor data
              SaveSettings!
              hDlg\Redraw!
          else processed=false
      if processed
        UpdateDlg hDlg,data
        return true
    elseif Msg==F.DN_MOUSECLICK
      if Param2.ButtonState==F.FROM_LEFT_1ST_BUTTON_PRESSED
        if Param1==_view
          .cursor = MSClickEvalCursor Param2.MousePositionX, Param2.MousePositionY
          if .cursor + .offset > .filesize
            .cursor = .filesize - .offset
          if Param2.EventFlags==F.DOUBLE_CLICK and not .edit
            DoEditMode!
          if .edit
            .editascii = Param2.MousePositionX>=62
          UpdateDlg hDlg,data
      elseif Param2.ButtonState==F.RIGHTMOST_BUTTON_PRESSED
        if .edit
          DoEditMode!
          UpdateDlg hDlg,data
  nil

DoHex=->
  LoadSettings!
  filenameU=viewer.GetFileName!
  filenameW=ToWChar LongPath filenameU
  file=C.WINPORT_CreateFile filenameW,GENERIC_READ,FILE_SHARE_READ+FILE_SHARE_WRITE+FILE_SHARE_DELETE,
                            ffi.NULL,OPEN_EXISTING,0,ffi.NULL
  if file~=INVALID_HANDLE_VALUE
    filesize=ffi.new('int64_t[1]')
    if 0~=C.WINPORT_GetFileSizeEx file,filesize
      ww,hh=ConsoleSize!
      ww=max MinWidth,ww
      buffer=far.CreateUserControl ww,hh-1
      textel=Char:0x20,Attributes:Colors.Unchanged
      textel_sel=Char:0x20,Attributes:Colors.Selected
      textel_changed=Char:0x20,Attributes:Colors.Changed
      info=viewer.GetInfo!
      offset=info.FilePos
      offset-=offset%16
      codepage=win.GetACP!
      items={
        {F.DI_TEXT,0,0,0,0,0,0,0,0,MakeTitle filenameU,codepage}
        {F.DI_USERCONTROL,0,1,ww-1,hh-1,buffer,0,0,0,''}
        {F.DI_FIXEDIT,0,0,0,0,0,0,0,F.DIF_HIDDEN+F.DIF_READONLY,''}
      }
      hDlg=far.DialogInit id,-1,-1,ww,hh,nil,items,F.FDLG_NONMODAL+F.FDLG_NODRAWSHADOW,DlgProc
      if hDlg
        dialogs[hDlg\rawhandle!]=
          :buffer,
          width:ww,
          height:hh-1,
          :file,
          :filenameW,
          :filenameU,
          --codepage:info.CurMode.CodePage,
          :codepage,
          ViewerID:info.ViewerID,
          :offset,
          cursor:1,
          filesize:tonumber filesize[0],
          :textel,
          :textel_sel,
          :textel_changed,
          edit:false,
          editpos:0,
          editchanged:false,
          editascii:false
        UpdateDlg hDlg,dialogs[hDlg\rawhandle!]
        actl.RedrawAll!
    else
      C.WINPORT_CloseHandle file

Macro
  description:'HEX Editor'
  area:'Viewer'
  key:'CtrlF4'
  action:DoHex
