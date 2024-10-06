-------------------------------------------------------------------------------
-- Расширенная работа с пометкой файлов. © SimSU
-- + правки © BAX
-------------------------------------------------------------------------------

---- Настройки
local function Settings()
-- Начало файла Profile\SimSU\Shell_SelectingEx.cfg
return{
  Key       = "AltShiftS";    --Prior       = 50; --Sort       = 50;
  KeyToEdit = "CtrlShiftE";   --PriorToEdit = 50; --SortToEdit = 50;
  KeyToEditF= "CtrlShiftH";   --PriorToEditF= 50; --SortToEditF= 50;
  KeyMark   = "CtrlShiftM";   --PriorMark   = 50; --SortMark   = 50;
  KeyUnMark = "CtrlShiftR";   --PriorUnMark = 50; --SortUnMark = 50;
  KeySync   = "Divide";       --PriorSync   = 50; --SortSync   = 50;
  KeySame   = "CtrlShift=";   --PriorSame   = 50; --SortSame   = 50;
  KeyFirst  = "AltHome";      --PriorFirst  = 50; --SortFirst  = 50;
  KeyPrev   = "AltUp";        --PriorPrev   = 50; --SortPrev   = 50;
  KeyNext   = "AltDown";      --PriorNext   = 50; --SortNext   = 50;
  KeyLast   = "AltEnd";       --PriorLast   = 50; --SortLast   = 50;
  KeyDay    = "CtrlAltD";     --PriorDay    = 50; --SortDay    = 50;

  FileName = "Files.bbs"; -- Имя Файла с именами Файлов.
  EOL      = "\n"; -- Перевод строк при вставке списка в редактор.
  SEP      = "%,%;\r\""; -- Что считать разделителями имён файлов в буфере обмена.
}
-- Конец файла Profile\SimSU\Shell_SelectingEx.cfg
end

-- Локализация
local function lang() return win.GetEnv("FARLANG") end
-- Встроенные языки / Built-in laguages
local function Messages()
if lang()=="Russian" then
-- Начало файла Profile\SimSU\Shell_SelectingExRussian.lng
return{
  Descr       = "Расширенная работа с пометкой файлов. © SimSU";
  DescrToEdit = "Копирование имён помеченных файлов в редактор. © SimSU";
  DescrToEditF= "Копирование полных имён помеченных файлов в редактор. © SimSU";
  DescrMark   = "Пометка файлов имена которых находятся в буфере обмена. © SimSU";
  DescrUnMark = "Снятие пометки с файлов имена которых находятся в буфере обмена. © SimSU";
  DescrSync   = "Пометка одинаковых файлов на обоих панелях. © SimSU";
  DescrSame   = "Пометка тех же файлов на пассивной панели что и на активной. © SimSU";
  DescrFirst  = "Переход на первый помеченный файл. © SimSU";
  DescrPrev   = "Переход на предыдущий помеченный файл. © SimSU";
  DescrNext   = "Переход на следующий помеченный файл. © SimSU";
  DescrLast   = "Переход на последний помеченный файл. © SimSU";
  DescrDay    = "Пометка файлов с днём записи равным дню записи файла под курсором. © SimSU";

  mTitle   = "Работа с пометкой";
  mToEdit  = "&E Имена в редактор";
  mToEditF = "&G Полные имена в редактор";
  mClip    = "Буфер обмена";
  mCopy    = "&C Копировать в буфер";
  mMark    = "&M Пометить из буфера";
  mRemMark = "&R Снять пометку из буфера";
  mCopyF   = "&K Полные имена в буфер";
  mPanels  = "Панели";
  mSync    = "&S Синхронизировать";
  mSame    = "&= Пометить те же";
  mAddName = "&A +Имена";
  mAddExt  = "&T +Расширения";
  mUnName  = "&B -Имена";
  mUnExt   = "&U -Расширения";
  mAddMark = "&+ Добавить к помеченным...";
  mUnMark  = "&- Убрать из помеченных...";
  mAddAll  = "&! Пометить все";
  mUnAll   = "&% Снять пометку со всех";
  mInvert  = "&* Инвертировать";
  mDay     = "&D Отметить файлы за день";
  mMove    = "Позиционироваться на";
  mFirst   = "&F Первый";
  mPrev    = "&P Предыдущий";
  mNext    = "&N Следующий";
  mLast    = "&L Последний";
}
-- Конец файла Profile\SimSU\Shell_SelectingExRussian.lng
else--if lang()=="English" then
-- Begin of file Profile\SimSU\Shell_SelectingExEnglish.lng
return{
  Descr       = "The expanded work with selection of files. © SimSU";
  DescrToEdit = "Copying of names of the marked files in the editor. © SimSU";
  DescrToEditF= "Copying of full names of the marked files in the editor. © SimSU";
  DescrMark   = "Mark of files names of which are in a clipboard. © SimSU";
  DescrUnMark = "Unmark of files names of which are in a clipboard. © SimSU";
  DescrSync   = "Mark of the files of the same name on both panels. © SimSU";
  DescrSame   = "Mark of the same files on the passive panel as on active. © SimSU";
  DescrFirst  = "Transition to the first marked file. © SimSU";
  DescrPrev   = "Transition to the previous marked file. © SimSU";
  DescrNext   = "Transition to the following marked file. © SimSU";
  DescrLast   = "Transition to the last marked file. © SimSU";
  DescrDay    = "Mark of files with day of record equal to day of record of the file under the cursor. © SimSU";

  mTitle   = "Operations on selection";
  mToEdit  = "&E Bring selection to editor";
  mToEditF = "&G Bring full names to editor";
  mClip    = "Clipboard";
  mCopy    = "&C Copy to clipboard";
  mMark    = "&M Select from clipboard";
  mRemMark = "&R Unselect from clipboard";
  mCopyF   = "&K Full names to clipboard";
  mPanels  = "Panels";
  mSync    = "&S Synchronize";
  mSame    = "&= Select the same";
  mAddName = "&A +Names";
  mAddExt  = "&T +Extensions";
  mUnName  = "&B -Names";
  mUnExt   = "&U -Extensions";
  mAddMark = "&+ Add to selection...";
  mUnMark  = "&- Subtract from selection...";
  mAddAll  = "&! Select all";
  mUnAll   = "&% Unselect all";
  mInvert  = "&* Reverse selection";
  mDay     = "&D Select files for a day";
  mMove    = "Position to";
  mFirst   = "&F First";
  mPrev    = "&P Previous";
  mNext    = "&N Next";
  mLast    = "&L Last";
}
-- End of file Profile\SimSU\Shell_SelectingExEnglish.lng
end end

local S=(loadfile(far.InMyConfig("SimSU/Shell_SelectingEx.cfg")) or Settings)()
local L=(loadfile(far.InMyConfig("SimSU/Shell_SelectingEx")..lang()..".lng") or Messages)
local M=L()
-------------------------------------------------------------------------------
local F=far.Flags
S.FileName = S.FileName==nil and Settings().FileName or S.FileName
S.EOL      = S.EOL     ==nil and Settings().EOL      or S.EOL
S.SEP      = S.SEP     ==nil and Settings().SEP      or S.SEP

local LastItem=1

local IsItemSelected

if jit then
  local ffi = require "ffi"
  local C = ffi.C
  local PSInfo = ffi.cast("struct PluginStartupInfo*", far.CPluginStartupInfo())
  local PANEL_ACTIVE = ffi.cast("void*", F.PANEL_ACTIVE)
  local RawBuf, Item, Ptr
  local MaxSize = 0

  IsItemSelected = function(Index)
    Index = Index - 1 -- FFI: 0-based index
    local Size = PSInfo.Control(PANEL_ACTIVE, C.FCTL_GETPANELITEM, Index, 0)
    if Size > 0 then
      if Size > MaxSize then
        MaxSize = Size
        RawBuf = ffi.new("char[?]", Size)
        Item = ffi.cast("struct PluginPanelItem*", RawBuf)
        Ptr = ffi.cast("LONG_PTR", Item)
      end
      if PSInfo.Control(PANEL_ACTIVE, C.FCTL_GETPANELITEM, Index, Ptr) ~= 0 then
        return bit.band(Item.Flags, C.PPIF_SELECTED) ~= 0 -- use bit to avoid tonumber(Flags)
      end
    end
  end

else
  IsItemSelected = function(Index)
    local item = panel.GetPanelItem(nil,1,Index)
    return item and band(item.Flags,F.PPIF_SELECTED) ~= 0
  end
end

local function ToEditor()
  local Files={}
  for i=1, panel.GetPanelInfo(nil,1).SelectedItemsNumber do
    Files[i]=panel.GetSelectedPanelItem(nil,1,i).FileName
  end
  local Names=table.concat(Files,S.EOL)..S.EOL
  editor.Editor(S.FileName,nil,nil,nil,nil,nil,F.EF_NONMODAL+F.EF_IMMEDIATERETURN)
  mf.print(Names)
  return Files
end

local function ToEditorF()
  local Files={}
  for i=1, panel.GetPanelInfo(nil,1).SelectedItemsNumber do
    Files[i]=panel.GetPanelDirectory(nil,1).Name..'\\'..panel.GetSelectedPanelItem(nil,1,i).FileName
  end
  local Names=table.concat(Files,S.EOL)..S.EOL
  editor.Editor(S.FileName,nil,nil,nil,nil,nil,F.EF_NONMODAL+F.EF_IMMEDIATERETURN)
  mf.print(Names)
  return Files
end

local function ClipboardMark(Mark)
  Mark= Mark and 1 or 0
  -- panel.select(0,0,2,clip(0)) -- FAR не проверяет пути если они есть.
  -- panel.select(0,1,2,clip(0)) -- FAR не проверяет пути если они есть.
  -- Делаем работу за FAR.
  local FileList=mf.clip(0)
  FileList=(FileList:gsub("["..S.SEP.."]","\n"):upper().."\n"):gsub("\\\n","\n")
  local PanelPath=APanel.Path:upper()
  for FullFileName in FileList:gmatch("[^\n]+") do
    local FilePath=mf.fsplit(FullFileName,0x1+0x2):gsub("\\$","")
    local Name=mf.fsplit(FullFileName,0x4+0x8)
    if FilePath=="" or FilePath==PanelPath then
      --Panel.Select(0,Mark,2,Name)
      Panel.Select(0,Mark,3,Name)
    end
  end
  return true
end

local function Synchronize()
  Panel.Select(0,0)
  Panel.Select(1,0)
  local AFiles = {}
  for i=1,panel.GetPanelInfo(nil,1).ItemsNumber do
    local bare = panel.GetPanelItem(nil,1,i).FileName:match("[^/]*$")
    AFiles[bare] = i
  end
  for i=1,panel.GetPanelInfo(nil,0).ItemsNumber do
    local bare = panel.GetPanelItem(nil,0,i).FileName:match("[^/]*$")
    if AFiles[bare] then
      panel.SetSelection(nil,1,AFiles[bare],true)
      panel.SetSelection(nil,0,i,true)
    end
  end
  panel.RedrawPanel(nil,1); panel.RedrawPanel(nil,0)
end

local function TheSame()
  local Name = {}
  for i=1,panel.GetPanelInfo(nil,1).SelectedItemsNumber do
    local barename = panel.GetSelectedPanelItem(nil,1,i).FileName:match("[^/]+$")
    Name[barename] = true
  end
  Panel.SetPos(1, APanel.Current)
  panel.BeginSelection(nil,0)
  for i=1,panel.GetPanelInfo(nil,0).ItemsNumber do
    local barename = panel.GetPanelItem(nil,0,i).FileName:match("[^/]+$")
    if Name[barename] then
      panel.SetSelection(nil,0,i,true)
    end
  end
  panel.EndSelection(nil,0)
end

local function DayMark()
  --local mSecInDay=24*60*60*1000
  local TicksPerDay = 24*60*60*1000
  local PanelItem=panel.GetCurrentPanelItem(nil,1)
  local Sel=(band(PanelItem.Flags,F.PPIF_SELECTED)==0)
  local DateMin= PanelItem.FileName == ".." and win.GetSystemTimeAsFileTime() or PanelItem.LastWriteTime
  local Offset=win.FileTimeToLocalFileTime(DateMin)-DateMin
  DateMin=math.floor((DateMin+Offset)/TicksPerDay)*TicksPerDay-Offset
  local DateMax=DateMin+TicksPerDay
  for i=1,panel.GetPanelInfo(nil,1).ItemsNumber do
    PanelItem=panel.GetPanelItem(nil,1,i)
    if PanelItem.LastWriteTime>=DateMin and PanelItem.LastWriteTime<DateMax then
      panel.SetSelection(nil,1,i,Sel)
    end
  end
  panel.RedrawPanel(nil,1)
end

local function GoFirst()
  return Panel.SetPosIdx(0,1,1)
end

local function GoPrevious()
--  return Panel.SetPosIdx(0,0,1)==1 and Panel.SetPosIdx(0,APanel.SelCount,1) or Panel.SetPosIdx(0,Panel.SetPosIdx(0,0,1)-1,1)
  local PanelInfo=panel.GetPanelInfo(nil,1)
  local CI=PanelInfo.CurrentItem
  for i=CI-1,1,-1 do
    if IsItemSelected(i) then CI=i; Panel.SetPosIdx(0,CI,0); break end
  end
  if CI==PanelInfo.CurrentItem then Panel.SetPosIdx(0,APanel.SelCount,1) end
end

local function GoNext()
--  return Panel.SetPosIdx(0,0,1)==APanel.SelCount and Panel.SetPosIdx(0,1,1) or Panel.SetPosIdx(0,Panel.SetPosIdx(0,0,1)+1,1)
  local PanelInfo=panel.GetPanelInfo(nil,1)
  local CI=PanelInfo.CurrentItem
  for i=CI+1,PanelInfo.ItemsNumber do
    if IsItemSelected(i) then CI=i; Panel.SetPosIdx(0,CI,0); break end
  end
  if CI==PanelInfo.CurrentItem then Panel.SetPosIdx(0,1,1) end
end

local function GoLast()
  return Panel.SetPosIdx(0,APanel.SelCount,1)
end

local function Select()
  M=L()
  -- + идеи BAX, 23.02.2019
  local mi={ -- far.Menu
    {text=M.mToEdit ; AccelKey =(S.KeyToEdit  or ""); Action=ToEditor                                 };
    {text=M.mToEditF; AccelKey =(S.KeyToEditF or ""); Action=ToEditorF                                };
    {text=M.mClip   ; separator=(true              );                                                 };
    {text=M.mCopy   ; AccelKey =("CtrlShiftIns"    );                                                 };
    {text=M.mMark   ; AccelKey =(S.KeyMark    or ""); Action=function() return ClipboardMark(true )end};
    {text=M.mRemMark; AccelKey =(S.KeyUnMark  or ""); Action=function() return ClipboardMark(false)end};
    {text=M.mCopyF  ; AccelKey =("CtrlAltIns"      );                                                 };
    {text=M.mPanels ; separator=(true              );                                                 };
    {text=M.mSync   ; AccelKey =(S.KeySync    or ""); Action=Synchronize                              };
    {text=M.mSame   ; AccelKey =(S.KeySame    or ""); Action=TheSame                                  };
    {text=M.mAddName; AccelKey =("AltAdd"          );                                                 };
    {text=M.mAddExt ; AccelKey =("CtrlAdd"         );                                                 };
    {text=M.mUnName ; AccelKey =("AltSubtract"     );                                                 };
    {text=M.mUnExt  ; AccelKey =("CtrlSubtract"    );                                                 };
    {text=M.mAddMark; AccelKey =("Add"             );                                                 };
    {text=M.mUnMark ; AccelKey =("Subtract"        );                                                 };
    {text=M.mAddAll ; AccelKey =("ShiftAdd"        );                                                 };
    {text=M.mUnAll  ; AccelKey =("ShiftSubtract"   );                                                 };
    {text=M.mInvert ; AccelKey =("Multiply"        );                                                 };
    {text=M.mDay    ; AccelKey =(S.KeyDay     or ""); Action=DayMark                                  };
    {text=M.mMove   ; separator=(true              );                                                 };
    {text=M.mFirst  ; AccelKey =(S.KeyFirst   or ""); Action=GoFirst                                  };
    {text=M.mPrev   ; AccelKey =(S.KeyPrev    or ""); Action=GoPrevious                               };
    {text=M.mNext   ; AccelKey =(S.KeyNext    or ""); Action=GoNext                                   };
    {text=M.mLast   ; AccelKey =(S.KeyLast    or ""); Action=GoLast                                   };
  }
  local len = 0
  for _,v in ipairs(mi) do len = (v.separator~=true) and (len < v.text:len()) and  v.text:len() or len end
  len = len + 2
  for i,v in ipairs(mi) do
    v.text = (v.separator~=true) and   ((v.text .. (' '):rep(len)):sub(1,len) .. v.AccelKey) or v.text
    v.selected = (i==LastItem)
  end
  local it, pos = far.Menu({Title=M.mTitle}, mi)
  if it then
    LastItem=pos
    return it.Action and it.Action() or Keys(it.AccelKey)
  end
end

-------------------------------------------------------------------------------
local Shell_SelectingEx={
  ToEditor      = ToEditor     ;
  ToEditorF     = ToEditorF    ;
  ClipboardMark = ClipboardMark;
  Synchronize   = Synchronize  ;
  TheSame       = TheSame      ;
  DayMark       = DayMark      ;
  GoFirst       = GoFirst      ;
  GoPrevious    = GoPrevious   ;
  GoNext        = GoNext       ;
  GoLast        = GoLast       ;
  Select        = Select       ;
}; for k,v in pairs(Shell_SelectingEx) do Shell_SelectingEx[k:lower()] = v end
-------------------------------------------------------------------------------
--Для командной строки
if _filename and (not sh or _cmdline) then --luacheck: ignore 113/_cmdline 113/sh
  if not ... then
    return Select()
  else
    local f=assert(loadstring(_cmdline or ...)) --luacheck: ignore 113/_cmdline
    setmetatable(Shell_SelectingEx,{__index = _G})
    return setfenv(f,Shell_SelectingEx)()
  end
end
-------------------------------------------------------------------------------
--Для использования в виде модуля
---- if not Macro then return Shell_SelectingEx end
---- SimSU=_G.SimSU or {}; SimSU.Shell_SelectingEx=Shell_SelectingEx; _G.SimSU=SimSU
-------------------------------------------------------------------------------

Macro {id="7ff37302-a606-4a17-972d-b51c006c4da7";
  area="Shell"; key=S.Key;       priority=S.Prior;       sortpriority=S.Sort;       description=M.Descr;
  action=function() return Select() end;
}
Macro {id="5fb1e2d0-87fc-4eda-a398-28e20a3eaf2f";
  area="Shell"; key=S.KeyToEdit; priority=S.PriorToEdit; sortpriority=S.SortToEdit; description=M.DescrToEdit;
  condition = function() return APanel.Visible and APanel.FilePanel end;
  action=function() return ToEditor() end;
}
Macro {id="e2ebcebb-4aeb-422a-94d9-2181349a49cb";
  area="Shell"; key=S.KeyToEditF;priority=S.PriorToEditF;sortpriority=S.SortToEditF;description=M.DescrToEditF;
  condition = function() return APanel.Visible and APanel.FilePanel end;
  action=function() return ToEditorF() end;
}
Macro {id="6c556f56-da67-4a52-a490-90430947d7c2";
  area="Shell"; key=S.KeyMark;   priority=S.PriorMark;   sortpriority=S.SortMark;   description=M.DescrMark;
  condition = function() return APanel.Visible and APanel.FilePanel end;
  action=function() return ClipboardMark(true) end;
}
Macro {id="db6e5645-0053-4598-94d7-cf6bb133c20f";
  area="Shell"; key=S.KeyUnMark; priority=S.PriorUnMark; sortpriority=S.SortUnMark; description=M.DescrUnMark;
  condition = function() return APanel.Visible and APanel.FilePanel end;
  action=function() return ClipboardMark(false) end;
}
Macro {id="512a4220-7018-4d02-9ca7-833c01269575";
  area="Shell"; key=S.KeySync;   priority=S.PriorSync;   sortpriority=S.SortSync;   description=M.DescrSync;
  condition = function() return APanel.Visible and APanel.FilePanel and PPanel.Visible and PPanel.FilePanel end;
  action=function() return Synchronize() end;
}
Macro {id="cb9c1655-15f3-4894-b9a6-db9db5a12e19";
  area="Shell"; key=S.KeySame;   priority=S.PriorSame;   sortpriority=S.SortSame;   description=M.DescrSame;
  condition = function() return APanel.Visible and APanel.FilePanel and PPanel.Visible and PPanel.FilePanel end;
  action=function() return TheSame() end;
}
Macro {id="bf643ce8-5cec-41b9-803b-e794a0a3e97b";
  area="Shell"; key=S.KeyFirst;  priority=S.PriorFirst;  sortpriority=S.SortFirst;  description=M.DescrFirst; flags="Selection";
  condition = function() return APanel.Visible and APanel.FilePanel end;
  action=function() return GoFirst() end;
}
Macro {id="a67c3e04-7061-4f6c-a525-bbde0ad7fe0d";
  area="Shell"; key=S.KeyPrev;   priority=S.PriorPrev;   sortpriority=S.SortPrev;   description=M.DescrPrev; flags="Selection";
  condition = function() return APanel.Visible and APanel.FilePanel end;
  action=function() return GoPrevious() end;
}
Macro {id="904c717f-5e8b-4da4-bd1b-63dbf464094b";
  area="Shell"; key=S.KeyNext;   priority=S.PriorNext;   sortpriority=S.SortNext;   description=M.DescrNext; flags="Selection";
  condition = function() return APanel.Visible and APanel.FilePanel end;
  action=function() return GoNext() end;
}
Macro {id="8e60772c-2a38-41f2-9f75-49335df9ee63";
  area="Shell"; key=S.KeyLast;   priority=S.PriorLast;   sortpriority=S.SortLast;   description=M.DescrLast; flags="Selection";
  condition = function() return APanel.Visible and APanel.FilePanel end;
  action=function() return GoLast() end;
}
Macro {id="4afe7929-4974-49e6-8db2-59e3822e457f";
  area="Shell"; key=S.KeyDay;    priority=S.PriorDay;    sortpriority=S.SortDay;    description=M.DescrDay;
  condition = function() return APanel.Visible and APanel.FilePanel end;
  action=function() return DayMark() end;
}
