-------------------------------------------------------------------------------
-- Завершение слова в редакторе. © SimSU
-- Portability: far3 and far2m. © Shmuel Zeigerman
-------------------------------------------------------------------------------
-- luacheck: no max line length

---- Настройки
local function Settings()
-- Начало файла Profile\SimSU\Editor_WordComplete.cfg
return{
  Key    ="CtrlSpace";   Prior    =51; --Sort    =51; -- Принять завершение.
  KeyList="CtrlSpace"; --PriorList=50; --SortList=50; -- Список автозавершения.

  Auto    =true;     -- Автозавершение разрешено.
  ThatWord="[%w_]+"; -- Что считается словом.
  MaxLines=500;      -- Число строк для поиска продолжения.
  MaxTime =  4;      -- Время показа и жизни автоматического завершения.
  Color   = 15;      -- Цвет завершения (текст и фон). Эквивалентные значения:  15 или 0x0F или {Flags=nil; ForegroundColor=15; BackgroundColor=0;}.
  CaseSensitive = true; -- Делать ли сравнение регистрозависимым (true) или регистронезависимым (false)
  InsideWords   = true; -- Предлагать дополнение внутри слов (true) или только в конце слова (false)
}
-- Конец файла Profile\SimSU\Editor_WordComplete.cfg
end

local far2m = package.config:sub(1,1) == "/"

---- Локализация
local function lang() return win.GetEnv("farlang") end
-- Встроенные языки / Built-in languages
local function Messages()
if lang()=="Russian" then
-- Начало файла Profile\SimSU\Editor_WordCompleteRussian.lng
return{
  Descr="Принять завершение слова. © SimSU";
  DescrList="Список завершённых слов. © SimSU";
}
-- Конец файла Profile\SimSU\Editor_WordCompleteRussian.lng
else--if lang()=="English" then
-- Begin of file Profile\SimSU\Editor_WordCompleteEnglish.lng
return{
  Descr="Принять завершение слова. © SimSU";
  DescrList="Список завершённых слов. © SimSU";
}
-- End of file Profile\SimSU\Editor_WordCompleteEnglish.lng
end end

local M=Messages()
local S=Settings()
-------------------------------------------------------------------------------
local F=far.Flags
S.ThatWord      = S.ThatWord     ==nil and Settings().ThatWord      or          S.ThatWord
S.MaxLines      = S.MaxLines     ==nil and Settings().MaxLines      or tonumber(S.MaxLines)
S.MaxTime       = S.MaxTime      ==nil and Settings().MaxTime       or tonumber(S.MaxTime )
S.Color         = S.Color        ==nil and Settings().Color         or tonumber(S.Color   )
S.Auto          = S.Auto         ==nil and Settings().Auto          or          S.Auto
S.CaseSensitive = S.CaseSensitive==nil and Settings().CaseSensitive or          S.CaseSensitive
S.InsideWords   = S.InsideWords  ==nil and Settings().InsideWords   or          S.InsideWords
S._ThatWord     ="^("..S.ThatWord..")"
S.ThatWord_     ="("..S.ThatWord..")$"

local _, hTimer

local Comp, CP

local function NewValue(Switch, Value)
  if Switch == 1 then return true end
  if Switch == -1 then return false end
  return not Value
end

local function EnableAuto(Switch)
  local Prev = S.Auto
  S.Auto = NewValue(Switch, S.Auto)
  return Prev
end

local function EnableCaseSensitive(Switch)
  local Prev = S.CaseSensitive
  S.CaseSensitive = NewValue(Switch, S.CaseSensitive)
  return Prev
end

local function EnableInsideWords(Switch)
  local Prev = S.InsideWords
  S.InsideWords = NewValue(Switch, S.InsideWords)
  return Prev
end

local function GetWord(Line,Pos,InWord)
  local EdInf=editor.GetInfo()
  Line   = Line or EdInf.CurLine
  Pos    = Pos  or EdInf.CurPos
  InWord = InWord==nil and S.InsideWords or InWord
  local s=editor.GetString(nil,Line,3)
  local b,e,w
  if InWord then
    Pos = Pos-1
  else
    _,e = s:find(S._ThatWord,Pos); Pos = e or Pos-1
  end
  b,e,w=s:sub(1,Pos):find(S.ThatWord_)
  return w,b,e
end

local function FindNearest(Word,Line)
  local EdInf=editor.GetInfo()
  Line= Line or EdInf.CurLine
  if not Word then Word = GetWord(Line,EdInf.CurPos) end
  if not Word then return end
  local W=Word; local N=W:len()
  if not S.CaseSensitive then W = W:upper() end
  local s=editor.GetString(nil,Line,3)
  local Lines=EdInf.TotalLines
  for i=1,S.MaxLines do
    for w in s:gmatch(S.ThatWord) do if w:len()>N and ((S.CaseSensitive and w:find(W,1,true)==1) or (not S.CaseSensitive and w:upper():find(W,1,true)==1)) then return w end end
    if Line-i>0 then s=editor.GetString(nil,Line-i,3) else s="" end
    for w in s:gmatch(S.ThatWord) do if w:len()>N and ((S.CaseSensitive and w:find(W,1,true)==1) or (not S.CaseSensitive and w:upper():find(W,1,true)==1)) then return w end end
    if Line+i<Lines then s=editor.GetString(nil,Line+i,3) else s="" end
  end
end

local function Complete(Rec)
  local KEY=far.InputRecordToName(Rec)
  if Rec.KeyDown then
    if KEY and KEY:len()==1 and KEY:find(S.ThatWord) then
      local w,_,e = GetWord()
      w = w and w..KEY or KEY
      if not e or e+1==Editor.RealPos then
        local W=FindNearest(w)
        if W then
          Comp=W:sub(w:len()+1)
          CP=far.AdvControl(F.ACTL_GETCURSORPOS)
          mf.postmacro(
            far.Dialog,
            '',CP.X,CP.Y,CP.X+Comp:len()+1,CP.Y,nil,
            --       01 02 03          04 05 06 07 08 09    10 11
            {{F.DI_TEXT, 1, 0, Comp:len(), 0, 0, 0, 0, 0, Comp, 0}},
            bor(F.FDLG_NODRAWSHADOW,F.FDLG_SMALLDIALOG,F.FDLG_NODRAWPANEL),
            function(hDlg, Msg, _ , Param2)
              if Msg == F.DN_INITDIALOG then
                hTimer = far.Timer(S.MaxTime*1000, function(h) h:Close() if hDlg then hDlg:send(F.DM_CLOSE); Comp=nil end end)
              elseif (far2m and Msg == F.DN_KEY) or (not far2m and Msg == F.DN_CONTROLINPUT) then
                local Key = (far.KeyToName or far.InputRecordToName)(Param2) -- luacheck: ignore
                if far2m and (not Key or Key == "Ctrl" or Key == "Alt" or Key == "Shift") then return end
                if hTimer then hTimer:Close() end
                hDlg:send(F.DM_CLOSE)
                if Key and Key:len()==1 then Comp=nil end
                mf.postmacro(function(key) if mf.eval(key,2)==-2 then Keys(key) end end, Key)
              end
            end
          )
        end
      end
    elseif Comp and KEY~=nil then
      Comp=nil
    end
  end
end

local function List()
  local EdInf=editor.GetInfo()
  local Id=EdInf.EditorID
  local First=math.max(EdInf.CurLine-S.MaxLines,1               )
  local Last =math.min(EdInf.CurLine+S.MaxLines,EdInf.TotalLines)
  local Items={}
  local w,b_  = GetWord()
  local W,b,e = GetWord(EdInf.CurLine,b_,false)
  local set = {}
  for i=First,Last do
    local s = editor.GetString(nil,i,3)
    for w_ in s:gmatch(S.ThatWord) do
      if w_ ~= W and set[w_] == nil then
        Items[#Items+1] = w_
        set[w_] = true
      end
    end
  end
  table.sort(Items, function(a1,a2) return utf8.ncasecmp(a1,a2) < 0 end)
  if W then editor.Select(Id,1,0,b,e-b+1,1) else w="" end
  mf.postmacro(function() Keys("CtrlAltF"); mf.print(w) end)
  Items=far.Menu({Title=""; Flags="FMENU_SHOWSINGLEBOX FMENU_SHOWSHORTBOX"}, Items)
  if Items then
    editor.UndoRedo(Id,0); editor.DeleteBlock(Id); mf.print(Items); editor.UndoRedo(Id,1)
    return Items
  else
    editor.Select(Id,0)
  end
end

local function Accept()
  if S.InsideWords then
    local EdInf=editor.GetInfo()
    local Line = EdInf.CurLine
    local Pos  = EdInf.CurPos
    local Id   = EdInf.EditorID
    local _,e = editor.GetString(Id,Line,3):find(S._ThatWord,Pos);
    if e then editor.Select(Id,1,0,Pos,e-Pos+1,1) end
    editor.UndoRedo(Id,0); editor.DeleteBlock(Id); mf.print(Comp); editor.UndoRedo(Id,1)
  else
    mf.print(Comp)
  end
  Comp=nil
end

_ = hTimer and hTimer:Close()
-------------------------------------------------------------------------------
local Editor_WordComplete={
  EnableAuto            = EnableAuto          ;
  EnableCaseSensitive   = EnableCaseSensitive ;
  EnableInsideWords     = EnableInsideWords   ;
  GetWord               = GetWord     ;
  FindNearest           = FindNearest ;
  Complete              = Complete    ;
  List                  = List        ;
}; for k,v in pairs(Editor_WordComplete) do Editor_WordComplete[k:lower()] = v end
-------------------------------------------------------------------------------
--Для командной строки John Doe
if _filename and (not sh or _cmdline) then --luacheck: ignore 113/_cmdline 113/sh
  if not ... then
    if Area.Editor then
      return List()
    end
  else
    local f=assert(loadstring(_cmdline or ...)) --luacheck: ignore 113/_cmdline
    setmetatable(Editor_WordComplete,{__index = _G})
    return setfenv(f,Editor_WordComplete)()
  end
end
-------------------------------------------------------------------------------
--Для использования в виде модуля
if not Macro then return Editor_WordComplete end
-------------------------------------------------------------------------------
Event {id="f71a0438-949d-4b65-836f-a70a282bafcd";
  group="EditorInput";          priority=S.Prior;     sortpriority=S.Sort;     description=M.Descr;
  condition=function(Rec) return S.Auto and Rec.EventType==F.KEY_EVENT end;
  action=function(Rec) return Complete(Rec) end;
}
Macro {id="7bd2ec59-ed87-42a9-9405-d769cce35080";
  area="Editor"; key=S.Key;     priority=S.Prior;     sortpriority=S.Sort;     description=M.Descr;
  condition=function() return Comp end;
  action=function() return Accept() end;
}
Macro {id="dd6be675-12e1-433b-b86c-f70cc6994e72";
  area="Editor"; key=S.KeyList; priority=S.PriorList; sortpriority=S.SortList; description=M.DescrList;
  condition=function() return not Comp end;
  action=function() return List() end;
}
