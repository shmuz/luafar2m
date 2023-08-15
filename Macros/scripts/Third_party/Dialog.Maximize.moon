-- Dialog.Maximize.moon
-- Resizing dialogs, aligning the positions of dialog elements
-- Keys: F2 in dialogs or CtrlAltRight or CtrlAltLeft
-- Url: https://github.com/z0hm/far-scripts
-- Url: https://forum.farmanager.com/viewtopic.php?p=148024#p148024
-- Based on https://forum.farmanager.com/viewtopic.php?p=146816#p146816

XScale=0 -- scale 0<=XScale<=1 for all dialogs: 0 = original width, 1 = full width, 0.5 = (full - original) / 2
XStep=0.25 -- width change step
DX=4 -- indent

XScale=_G.XScale or XScale
_XScale={id:"",xs:XScale,cw:nil,ch:nil,dw:nil,dh:nil,dl:nil,dt:nil,dr:nil,db:nil,pl:nil,pr:nil} -- original width

F,GetDlgItem,Guids = far.Flags,far.GetDlgItem,far.Guids
SetDlgItem,SendDlgMessage = far.SetDlgItem,far.SendDlgMessage

abs,ceil,floor,fmod,modf = math.abs,math.ceil,math.floor,math.fmod,math.modf

match = string.match

Uuid=win.Uuid

Guid_DlgXScale=Uuid"D37E1039-B69B-4C63-B750-CBA4B3A7727C"

transform=
  --[Guid_DlgXScale]: {0,"1.16.A27",3.0} -- Set Dlg.XScale
  [Uuid Guids.CopyFilesId                    ]: {1,3,6,14}    -- Shell: Copy
  [Uuid Guids.CopyCurrentOnlyFileId          ]: {1,3,6,14}    -- Shell: Copy current
  [Uuid Guids.MoveFilesId                    ]: {1,3,6,14}    -- Shell: Move
  [Uuid Guids.MoveCurrentOnlyFileId          ]: {1,3,6,14}    -- Shell: Move current
  [Uuid Guids.MakeFolderId                   ]: {1,3}         -- Shell: mkdir
  [Uuid Guids.HardSymLinkId                  ]: {1,3,6}       -- Shell: Link
  [Uuid Guids.FileOpenCreateId               ]: {1,3,6}       -- Shell: New
  [Uuid Guids.FindFileId                     ]: {1,3,6,7,9,14.1,15.1,16.1,18.1,20.2,21.1} -- Find File
  [Uuid Guids.EditorSearchId                 ]: {1,3,8.1,9.1} -- Editor Search
  [Uuid Guids.EditorReplaceId                ]: {1,3,5,10.1}  -- Editor Replace
  [Uuid Guids.FileSaveAsId                   ]: {1,3,6}       -- File Save As
  [Uuid Guids.PluginInformationId            ]: {1,3,5,7,9,11,13,15}
  [Uuid Guids.DescribeFileId                 ]: {1,3}         -- Describe File
  [Uuid Guids.ApplyCommandId                 ]: {1,3}         -- Shell: Apply command (CtrlG)
  [Uuid Guids.EditUserMenuId                 ]: {1,5,8,9,10,11,12,13,14,15,16,17}
  [Uuid Guids.FileAssocModifyId              ]: {1,3,5,8,10,12,14,16,18}
  [Uuid Guids.ViewerSearchId                 ]: {1,3,8.1,9.1,10.1,11.1} -- Viewer Search
  [Uuid Guids.SelectDialogId                 ]: {1,2}         -- Select Gray+
  [Uuid Guids.UnSelectDialogId               ]: {1,2}         -- Select Gray-
  --[Uuid Guids.FileAttrDlgId                  ]: {1,37} -- File Attributes
  -- LFSearch/Shell
  [Uuid"3CD8A0BB-8583-4769-BBBC-5B6667D13EF9"]: {1,3,5,11.1,13.1,15.1,18,20.2,21.1,22.1,25.1} -- Shell/Find
  [Uuid"F7118D4A-FBC3-482E-A462-0167DF7CC346"]: {1,3,5,7}     -- Shell/Replace
  [Uuid"74D7F486-487D-40D0-9B25-B2BB06171D86"]: {1,3,5,7}     -- Shell/Grep
  [Uuid"AF8D7072-FF17-4407-9AF4-7323273BA899"]: {1,3,6.1,7.1,11,13,14.4,15.1,16.4,20.2,21.1,22.5,25,27} -- Shell/Rename
  -- LFSearch/Editor
  --# [Uuid"0B81C198-3E20-4339-A762-FFCBBC0C549C"]: {1,3,4.3,7.1,"8.12.F2.2.13",10.1,14.4,15.4,"16.6.1","19.10.20",25,27.2,28.1,29.5} -- Editor/Find
  --# [Uuid"FE62AEB9-E0A1-4ED3-8614-D146356F86FF"]: {1,3,5,6.3,7.3,8.4,9.1,10.4,11.5,"14.10.11","15.16.11.11","17.10.11","20.12.3.1","21.10.20","22.10.20","23.6.1",32,34.2,35.5,36.5} -- Editor/Replace
  [Uuid"87ED8B17-E2B2-47D0-896D-E2956F396F1A"]: {1,3,5,19.2,20.1,21.5} -- Editor/Multi-Line Replace
  --# -- Calculator
  --# [Uuid"E45555AE-6499-443C-AA04-12A1AADAB989"]: {1,3,10,11,12,13,14}
  --# -- Macroses:
  --# [Uuid"5B40F3FF-6593-48D2-8F78-4A32C8C36BCA"]: {1,5,12,14} -- Panel.CustomSortByName.lua


re0 = "^(%d+)%.(%d+)%.(.+)$"
re1 = "[%-%+]?%d+"
re2 = "([%-%+]?%d+)%.([%-%+]?%d+)"
re3 = "([F]?)(%d)%.(%d)%.([%-%+]?%d+)"
re4 = "([F]?)(%d)%.(%d)"
re5 = "([%-%+]?%d+)%.([%-%+]?%d+)%.([%-%+]?%d+)%.([%-%+]?%d+)"

ConsoleSize=->
  rr=far.AdvControl"ACTL_GETFARRECT"
  rr.Right-rr.Left+1,rr.Bottom-rr.Top+1

_XScale.cw,_XScale.ch = ConsoleSize!

Proc=(id,hDlg)->
  if id~=_XScale.id
    _XScale.id=id
    if not _XScale[id]
      _XScale[id]={}
      {Left:_XScale[id].dl,Top:_XScale[id].dt,Right:_XScale[id].dr,Bottom:_XScale[id].db}=hDlg\GetDlgRect!
      _XScale[id].dw=_XScale[id].dr-_XScale[id].dl+1
      _XScale[id].dh=_XScale[id].db-_XScale[id].dt+1
      _XScale[id].pl=(GetDlgItem hDlg,1)[2]+2
      _XScale[id].pr=_XScale[id].dw-_XScale[id].pl-1
      idx=0
      while true
        idx+=1
        item=GetDlgItem hDlg,idx
        if item
          _XScale[id][idx]={}
          _XScale[id][idx][2]=item[2]
          _XScale[id][idx][3]=item[3]
          _XScale[id][idx][4]=item[4]
          _XScale[id][idx][5]=item[5]
        else
          break
  cw,ch = ConsoleSize!
  if cw~=_XScale.cw or ch~=_XScale.ch
    _XScale.cw,_XScale.ch = cw,ch
  dh,pl = _XScale[id].dh,_XScale[id].pl
  df=cw-DX-_XScale[id].dw
  diff=_XScale.xs*df
  dw=_XScale[id].dw+diff
  pr=dw-pl-1
  SendDlgMessage hDlg,F.DM_ENABLEREDRAW,0
  SendDlgMessage hDlg,F.DM_RESIZEDIALOG,0,{X:dw,Y:dh}
  for ii in *transform[id]
    local idx,opt,ref
    if "number"==type ii
      continue if ii<1
      idx,opt = modf ii
      opt=floor opt*10+0.5
    else
      idx,opt,ref = match ii,re0
      idx=tonumber idx
      opt=tonumber opt
    item=GetDlgItem hDlg,idx
    if item  -- prevent error message for out-of-range index (see "hack" above)
      item[2]=_XScale[id][idx][2]
      item[3]=_XScale[id][idx][3]
      item[4]=_XScale[id][idx][4]
      item[5]=_XScale[id][idx][5]
      NOTDITEXT=not (item[1]==F.DI_TEXT and item[4]==0)
      switch opt
        when 0  -- Stretch full
          if idx==1 and (item[1]==F.DI_DOUBLEBOX or item[1]==F.DI_SINGLEBOX)
            item[4]=pr+2
          else
            if item[4]==item[2]
              item[2]+=diff
            if NOTDITEXT
              item[4]+=diff
        when 1  -- Move half
          if NOTDITEXT and item[4]==item[2]
            item[4]+=diff/2
          item[2]+=diff/2
        when 2  -- Stretch half
          if item[4]==item[2]
            item[2]+=diff/2
          if NOTDITEXT
            item[4]+=diff/2
        when 3  -- Move full
          if NOTDITEXT and item[4]==item[2]
            item[4]+=diff
          item[2]+=diff
        when 4  -- Move left
          item[2]=pl
        when 5  -- Move half & Stretch full
          if NOTDITEXT
            if item[4]==item[2]
              item[4]+=diff/2
            if diff>=0
              item[4]+=diff
          item[2]+=diff/2
        when 6  -- Move relative by X
          x=tonumber match ref,re1
          item[2]+=x
          if NOTDITEXT
            item[4]+=x
        when 7  -- Move relative by Y
          y=tonumber match ref,re1
          item[3]+=y
          item[5]+=y
        --when 8  -- MoveX full
        --  item[2]+=diff+item[2]-item[4]
        --  item[4]+=diff
        when 9  -- Move & Size relative by X1 & X2
          x1,x2 = match ref,re2
          item[2]+=tonumber x1
          if NOTDITEXT
            item[4]+=tonumber x2
        when 10  -- Align to ref.X
          ref=tonumber ref
          t=_XScale[id][ref]
          if NOTDITEXT
            item[4]=item[4]+t[2]-item[2]
          item[2]=t[2]
        when 11  -- Align to ref.Y
          ref=tonumber ref
          t=_XScale[id][ref]
          item[5]=item[5]+t[3]-item[3]
          item[3]=t[3]
        when 12  -- Move & Stretch: (colons quantity).(colon number).(dx)
          m,q,n,x = match ref,re3
          if not q
            m,q,n = match ref,re4
            x=0
          wc=(dw-pl*2-1)/tonumber q
          n=tonumber n
          w=item[4]-item[2]+1
          if w>wc
            w=wc
          x=tonumber x
          item[2]=wc*(n-1)+pl+x
          if m=="F"
            item[4]=item[2]+w-1
          else
            item[4]=item[2]+wc-1
        when 13  -- Free Move & Stretch Relative
          x1,x2,y1,y2 = match ref,re5
          item[2]+=tonumber x1
          item[3]+=tonumber y1
          if NOTDITEXT
            item[4]+=tonumber x2
          item[5]+=tonumber y2
        when 14  -- Free Move & Stretch Absolute
          x1,x2,y1,y2 = match ref,re5
          item[2]=tonumber x1
          item[3]=tonumber y1
          if NOTDITEXT
            item[4]=tonumber x2
          item[5]=tonumber y2
        when 15  -- Set text
          item[10]=ref
        when 16  -- Align to ref.X + offset
          x1,x2 = match ref,re2
          x1=tonumber x1
          x2=tonumber x2
          t=_XScale[id][x1]
          if NOTDITEXT
            item[4]=item[4]+t[2]-item[2]+x2
          item[2]=t[2]+x2
      if idx==1
        if item[2]<pl-2
          item[2]=pl-2
        if item[4]>pr+2
          item[4]=pr+2
      else
        if item[2]<pl
          item[2]=pl
        if item[4]>pr
          item[4]=pr
      if item[1]==F.DI_EDIT or item[1]==F.DI_FIXEDIT
        f=SendDlgMessage hDlg,F.DM_EDITUNCHANGEDFLAG,idx,-1
        SetDlgItem hDlg,idx,item
        SendDlgMessage hDlg,F.DM_EDITUNCHANGEDFLAG,idx,f
      else
        SetDlgItem hDlg,idx,item
  SendDlgMessage hDlg,F.DM_MOVEDIALOG,1,{X:(cw-dw)/2,Y:(ch-dh)/2}
  SendDlgMessage hDlg,F.DM_ENABLEREDRAW,1

XItems={
         {F.DI_DOUBLEBOX, 0,0,19,2,0,       0,0,       0,  "XScale"}
         {F.DI_TEXT,      2,1, 9,1,0,       0,0,       0,"0<=X<=1:"}
         {F.DI_EDIT,     11,1,17,1,0,"XScale",0,       0,        ""}
       }

XDlgProc=(hDlg,Msg,Param1,Param2)->
  if Msg==F.DN_INITDIALOG
    SendDlgMessage hDlg,F.DM_SETTEXT,3,tostring _XScale.xs
  elseif Msg==F.DN_CLOSE and Param1==3
    res=tonumber SendDlgMessage hDlg,F.DM_GETTEXT,Param1
    if res
      if res<0
        res=0
      elseif res>1
        res=1
      _XScale.xs=res

exec=(hDlg)->
  id=SendDlgMessage hDlg,F.DM_GETDIALOGINFO
  if id and transform[id.Id]
    Proc id.Id,hDlg

Event
  group:"DialogEvent"
  description:"Dialog Transform"
  action:(event,param)->
    if event==F.DE_DLGPROCINIT and (param.Msg==F.DN_INITDIALOG or param.Msg==F.DN_RESIZECONSOLE)
      exec param.hDlg
    elseif event==F.DE_DEFDLGPROCINIT and param.Msg==F.DN_KEY
      name=far.KeyToName param.Param2
      if name=="F2"
        res=far.Dialog Guid_DlgXScale,-1,-1,20,3,nil,XItems,F.FDLG_SMALLDIALOG+F.FDLG_WARNING,XDlgProc
        if res==3
          exec param.hDlg
      elseif name=="CtrlAltRight"
        if _XScale.xs<1
          _XScale.xs+=XStep
          if _XScale.xs>1
            _XScale.xs=1
          exec param.hDlg
      elseif name=="CtrlAltLeft"
        if _XScale.xs>0
          _XScale.xs-=XStep
          if _XScale.xs<0
            _XScale.xs=0
          exec param.hDlg
    false
