-- Author: Vadim Yegorov (zg)
-- URL: https://github.com/trexinc/evil-programmers/blob/master/LuaHexEd/Macros/scripts/hexed.moon
-- Adaptation to far2l: Shmuel Zeigerman

--BACKUP YOUR FILES BEFORE USE
if not jit then return -- LuaJIT required

F=far.Flags
ffi=require'ffi'
C=ffi.C
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
F1        Help window
F3        Toggle view/edit mode
F9        Save
BS        Restore the changed cell value
Tab       Toggle Hex/Text editing area
AltF8     "Go to" dialog
Esc       Quit Hex Editor]]

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
      sub=(s,p)->string.sub s,p,p
      for ii=1,#txt/2
        result..=(sub txt,ii*2)..(sub txt,ii*2-1)
      result
    else
      fn txt,codepage

MB2WC=(txt,codepage)->UnicodeThunk win.MultiByteToWideChar,txt,codepage
WC2MB=(txt,codepage)->UnicodeThunk win.WideCharToMultiByte,txt,codepage

GenerateDisplayText=(txt,codepage)->
  wide=MB2WC txt,codepage
  out=''
  for ii=1,#wide,WSIZE
    wchar=string.sub wide,ii,ii-1+WSIZE
    if wchar=='\0\0\0\0' -- DI_USERCONTROL in far2l displays binary zeroes as white rectangles. Prevent that.
      wchar='.\0\0\0'
    out..=(win.WideCharToMultiByte wchar,65001)..string.rep '.',#(WC2MB wchar,codepage)-1
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
    char=string.format '%02X',string.byte data.chunk,pos
    char,data.edit and (string.format '%02X',string.byte data.oldchunk,pos) or char
  -- Fill buffer with spaces
  data.textel.Char=0x20
  for ii=1,#data.buffer do
    data.buffer[ii]=data.textel
  -- Draw all
  len=#data.chunk
  for row=0,data.height-1
    -- Draw offsets and vertical line
    if row*16<len
      DrawStr row*data.width+1,string.format '%010X:',tonumber data.offset+row*16
      data.textel.Char=0x2502
      data.buffer[row*data.width+24+1+12]=data.textel
    -- Draw hex data
    for col=1,16
      pos=col+row*16
      if pos<=len
        char,oldchar=GetChar pos
        txtl=pos==data.cursor and not data.edit and data.textel_sel or
          (char==oldchar and data.textel or data.textel_changed)
        DrawStr row*data.width+(col-1)*3+1+12+(col>8 and 2 or 0),char,txtl
        DrawStr row*data.width+16*3+2+1+12+col,(data.displaytext\sub pos,pos),txtl
  if data.edit
    xx,yy=data.editascii and 63+(data.cursor-1)%16 or (data.cursor-1)%16,1+math.floor (data.cursor-1)/16
    xx=12+xx*3+(xx>7 and 2 or 0)+data.editpos if not data.editascii
    hDlg\SetItemPosition _edit,{Left:xx,Top:yy,Right:xx,Bottom:yy}
    char,oldchar=GetChar data.cursor
    data.editchanged=char~=oldchar
    hDlg\SetText _edit,data.editascii and (data.displaytext\sub data.cursor,data.cursor) or
      string.sub char,data.editpos+1,data.editpos+1

UpdateDlg=(hDlg,data)->
  if not data.edit then Read data
  HexDraw hDlg,data
  hDlg\Redraw!

DlgProc=(hDlg,Msg,Param1,Param2)->
  data=dialogs[hDlg\rawhandle!]
  if data
    if Msg==F.DN_CLOSE
      C.WINPORT_CloseHandle data.file
      dialogs[hDlg\rawhandle!]=nil
    elseif Msg==F.DN_CTLCOLORDIALOG
      return far.AdvControl F.ACTL_GETCOLOR,F.COL_VIEWERSTATUS
    elseif Msg==F.DN_CTLCOLORDLGITEM
      DoColor=(index)->
        far.AdvControl F.ACTL_GETCOLOR,index
      return switch Param1
        when _title
          DoColor F.COL_VIEWERSTATUS
        when _edit
          DoColor data.editchanged and F.COL_VIEWERARROWS or F.COL_VIEWERTEXT
    elseif Msg==F.DN_KILLFOCUS
      if Param1==_edit and data.edit then return _edit
    elseif Msg==F.DN_RESIZECONSOLE
      item=hDlg\GetDlgItem _view
      if item
        data.width,data.height=ConsoleSize!
        data.height-=1
        data.buffer=far.CreateUserControl data.width,data.height
        item[4]=data.width-1
        item[5]=data.height
        item[7]=data.buffer
        hDlg\SetDlgItem _view,item
        hDlg\ResizeDialog 0,{X:data.width,Y:data.height+1}
        UpdateDlg hDlg,data
    elseif Msg==F.DN_KEY
      processed=true
      with data
        Update=(inc)->
          if not .edit
            old_offset=.offset
            .offset+=inc
            if .offset>=.filesize
              if (.filesize-old_offset-1)<=.height*16 then .offset=old_offset
              else .offset=.filesize-1
            if .offset<0 then .offset=0
            .offset=.offset-.offset%16
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
        DoEditMode=->
          .edit=not .edit
          .editpos=0
          .oldchunk=.edit and .chunk or nil
          hDlg\ShowItem _edit,data.edit and 1 or 0
          hDlg\SetFocus data.edit and _edit or _view
        --uchar=(Param2.UnicodeChar\sub 1,1)\byte 1
        uchar=Param2
        if .edit and .editascii and uchar~=0 and uchar~=9 and uchar~=27 and uchar<0x10000
          t={}
          for k=1,WSIZE
            t[k]=uchar%0x100
            uchar=(uchar-t[k])/0x100
          new=win.WideCharToMultiByte (string.char unpack t),.codepage
          .chunk=(string.sub .chunk,1,.cursor-1)..new..(string.sub .chunk,.cursor+#new)
          .oldchunk..=string.rep '\0',#.chunk-#.oldchunk
          .displaytext=GenerateDisplayText .chunk,.codepage
          for _=1,#new do DoRight!
        else
          key=far.KeyToName Param2
          switch key
            when '0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F','a','b','c','d','e','f'
              if .edit
                old=string.byte .chunk,.cursor
                new=.editpos==0 and ((tonumber key,16)*16+old%16) or (16*(math.floor old/16)+tonumber key,16)
                .chunk=(string.sub .chunk,1,.cursor-1)..(string.char new)..(string.sub .chunk,.cursor+1)
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
            when 'CtrlPgUp','RCtrlPgUp','CtrlUp','RCtrlUp'
              if .edit then DoUp!
              else
                if .offset==0 and .cursor>16 then .cursor-=16
                else Update -16
            when 'CtrlPgDn','RCtrlPgDn','CtrlDown','RCtrlDown'
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
              if .offset+.height*16<.filesize
                if .edit
                  .cursor=(.height-1)*16+(.cursor-1)%16+1
                else
                  Update 16*.height
              else
                rest=.filesize-.offset
                .cursor=tonumber rest-((15-(.cursor-1)%16)+rest%16)%16
            when 'CtrlHome','RCtrlHome'
              Update -.filesize
              .cursor=1
            when 'CtrlEnd','RCtrlEnd'
              Update .filesize-.offset-1-(.height-1)*16
              if not .edit then .cursor=tonumber .filesize-.offset
            when .edit and 'Esc' then DoEditMode!
            when .edit and 'Ins' then nil
            when 'BS'
              if .edit
                idx=.cursor-(0==.editpos and 1 or 0)
                .chunk=(string.sub .chunk,1,idx-1)..(string.sub .oldchunk,idx,idx)..(string.sub .chunk,idx+1)
                .displaytext=GenerateDisplayText .chunk,.codepage
                DoLeft!
            when 'Tab' then .editascii=.edit and not .editascii
            when 'AltF8','RAltF8'
              if not .edit
                offset=GetOffset!
                if offset then .offset=offset-offset%16
            when 'CtrlF10','RCtrlF10'
              if not .edit
                viewer.SetPosition tonumber .offset
            when 'F1'
              far.Message HelpText,'Hex Editor',nil,'l'
            else processed=false
      if processed
        UpdateDlg hDlg,data
        return true
  nil

DoHex=->
  filename=viewer.GetFileName!
  filenameW=ToWChar LongPath filename
  file=C.WINPORT_CreateFile filenameW,GENERIC_READ,FILE_SHARE_READ+FILE_SHARE_WRITE+FILE_SHARE_DELETE,
                            ffi.NULL,OPEN_EXISTING,0,ffi.NULL
  if file~=INVALID_HANDLE_VALUE
    filesize=ffi.new('int64_t[1]')
    if 0~=C.WINPORT_GetFileSizeEx file,filesize
      ww,hh=ConsoleSize!
      buffer=far.CreateUserControl ww,hh-1
      textel=Char:0x20,Attributes:far.AdvControl F.ACTL_GETCOLOR,F.COL_VIEWERTEXT
      textel_sel=Char:0x20,Attributes:far.AdvControl F.ACTL_GETCOLOR,F.COL_VIEWERSELECTEDTEXT
      textel_changed=Char:0x20,Attributes:far.AdvControl F.ACTL_GETCOLOR,F.COL_VIEWERARROWS
      info=viewer.GetInfo!
      offset=info.FilePos
      offset-=offset%16
      items={
        {F.DI_TEXT,0,0,0,0,0,0,0,0,filename}
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
          codepage:info.CurMode.CodePage,
          ViewerID:info.ViewerID,
          :offset,
          cursor:1,
          filesize:filesize[0],
          :textel,
          :textel_sel,
          :textel_changed,
          edit:false,
          editpos:0,
          editchanged:false,
          editascii:false
        UpdateDlg hDlg,dialogs[hDlg\rawhandle!]
    else
      C.WINPORT_CloseHandle file

Macro
  description:'HEX Editor'
  area:'Viewer'
  key:'CtrlF4'
  action:DoHex
