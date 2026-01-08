-------------------------------------------------------------------------------
--           Работа мышкой с выделением в редакторе. © SimSU
-------------------------------------------------------------------------------
-- Умеет:
--   первая таблица (действие):
--     перемещать курсор за мышкой - команда "SelNone";
--     выделять обычные и вертикальные блоки - "SelNorm", "SelVert";
--     корректировать выделение обычных и вертикальных блоков - "CorNorm" и "CorVert";
--     выделять слово, строку как нормальный, так и как вертикальный блок - "WordNorm", "LineNorm" и "WordVert", "LineVert";
--     перетаскивать блоки, перетаскивать с копированием - "Move", "Copy";
--   вторая таблица (последействие):
--     в буфер обмена вырезать, копировать, добавлять, вырезать с добавлением - "Copy", "Cut", "Add", "CutAdd";
--     удалять, вставлять и обменивать с буфером обмена - "Delete", "Paste" и "Replace".
-- Различает состояния - ключи в соответствующей таблице:
--   одинарный, двойной и т.д. клик мышки в выделенной области "InSel1", "InSel2", ...
--   одинарный, двойной и т.д. клик мышки вне выделенной области "NotSel1", "NotSel2", ...
--   одинарный, двойной и т.д. клик мышки в любой области при отсутствии действий для предыдущих состояний "Click1", "Click2", ...
-- Пример: хотим выделить и вырезать в клипборд вертикальный блок - SimSU.Editor_MouseSelect.MouseSelect({Click1="SelVert"},{Click1="Cut"})
--         ещё хотим по двойному клику выделять и удалять слово - дополним таблицы... SimSU.Editor_MouseSelect.MouseSelect({Click1="SelVert",Click2="WordNorm"},{Click1="Cut",Click2="Delete"})

---- Настройки
local function Settings()
-- Начало файла Profile\SimSU\Editor_MouseSelect.cfg
return{
  {-- Обычный блок: при клике в выделении корректируем, иначе выделяем, при двойном клике выделить слово, при тройном выделить строку."
  Key="MsLClick";             --Prior=50; --Sort=50;
  Action ={InSel1="CorNorm"; Click1="SelNorm"; Click2="WordNorm"; Click3="LineNorm"};
  id="2718943b-0302-4bab-8db1-1d3369e4bf5d"};
  {-- Вертикальный блок: При клике в выделении корректируем, иначе выделяем, при двойном клике выделить слово, при тройном выделить строку."
  Key="MsRClick AltMsLClick"; --Prior=50; --Sort=50;
  Action ={InSel1="CorVert"; Click1="SelVert"; Click2="WordVert"; Click3="LineVert"};
  id="30d9c41b-3b50-4212-8f5f-df0350f2522e"};
  {-- Обычный блок с копированием в буфер: при клике в выделении перетаскиваем копию, иначе выделяем, при двойном клике выделить слово, при тройном выделить строку."
  Key="CtrlMsLClick";         --Prior=50; --Sort=50;
  Action ={InSel1="Copy"; Click1="SelNorm"; Click2="WordNorm"; Click3="LineNorm"   };
  PostAct={               Click1="Copy"   ; Click2="Copy"    ; Click3="Copy"       };
  id="a70c91df-2ea4-4119-870d-f28c0bc7859a"};
  {-- Обычный блок с вырезанием в буфер: при клике в выделении перетаскиваем, иначе выделяем, при двойном клике выделить слово, при тройном выделить строку."
  Key="ShiftMsLClick";        --Prior=50; --Sort=50;
  Action ={InSel1="Move"; Click1="SelNorm"; Click2="WordNorm"; Click3="LineNorm"   };
  PostAct={               Click1="Cut"    ; Click2="Cut"     ; Click3="Cut"        };
  id="238dc4e8-0b2d-4f34-9668-2718878ced0f"};
  Timing=250 -- Максимальный интервал (мс) между кликами при превышении которого двойной, тройной и т.д. клик не будет засчитан.
}
-- Конец файла Profile\SimSU\Editor_MouseSelect.cfg
end

local function lang() return win.GetEnv("farlang") end
-- Встроенные языки / Built-in languages
local function Messages()
--if lang()=="Russian" then
-- Начало файла Profile\SimSU\SimSU\Editor_MouseSelectRussian.lng
return{
  -- Обычный блок: при клике в выделении корректируем, иначе выделяем, при двойном клике выделить слово, при тройном выделить строку."
  "Выделение обычного блока. © SimSU";
  -- Вертикальный блок: При клике в выделении корректируем, иначе выделяем, при двойном клике выделить слово, при тройном выделить строку."
  "Выделение вертикального блока. © SimSU";
  -- Обычный блок с копированием в буфер: при клике в выделении перетаскиваем копию, иначе выделяем, при двойном клике выделить слово, при тройном выделить строку."
  "Выделение с копированием. © SimSU";
  -- Обычный блок с вырезанием в буфер: при клике в выделении перетаскиваем, иначе выделяем, при двойном клике выделить слово, при тройном выделить строку."
  "Выделение с вырезанием. © SimSU";
}
-- Конец файла Profile\SimSU\Editor_MouseSelectRussian.lng
end --end

--! local S=(loadfile(win.GetEnv("FARLOCALPROFILE").."\\SimSU\\Editor_MouseSelect.cfg") or loadfile(win.GetEnv("FARPROFILE").."\\SimSU\\Editor_MouseSelect.cfg") or Settings)()
--! local L=(loadfile(win.GetEnv("FARPROFILE").."\\SimSU\\Editor_MouseSelect"..lang()..".lng") or Messages)
--! local M=L()
local M=Messages()
local S=Settings()
-------------------------------------------------------------------------------
S.Timing = S.Timing==nil and Settings().Timing or S.Timing

local F=far.Flags
local Editor=Editor
local Sel=Editor.Sel
local Pos=Editor.Pos
local Set=Editor.Set
local editorGetInfo=editor.GetInfo

local function GetInfo()
-- Расширение функции editor.GetInfo, чтобы знать координаты окна редактора в фаре и состояние строк заголовка и клавиш, а также полосы прокрутки.
  local EdInf=editorGetInfo()
  EdInf.TitleBar=Far.GetConfig("Editor.ShowTitleBar")==true and 1 or 0 -- Строка статуса включена?
  EdInf.KeyBar=Far.KeyBar_Show(0)                                        -- Кейбар включён?
  EdInf.ScrollBar=Set(15)                                                -- Скролбар включён?
                                                                         -------------------------------------------
  local C=far.AdvControl(F.ACTL_GETCURSORPOS)                            -- (X1,Y1)                               --
  EdInf.X1=C.X-(EdInf.CurTabPos-EdInf.LeftPos)                           --                                       --
  EdInf.Y1=C.Y-(EdInf.CurLine-EdInf.TopScreenLine)-EdInf.TitleBar        --       Координаты окна редактора       --
  EdInf.X2=C.X-(EdInf.CurTabPos-EdInf.LeftPos)    +EdInf.WindowSizeX     --                                       --
  EdInf.Y2=C.Y-(EdInf.CurLine-EdInf.TopScreenLine)+EdInf.WindowSizeY     --                               (X2,Y2) --
                                                                         -------------------------------------------
  return EdInf
end

local function InEditorMouse()
-- Проверка - мышка в тексте?
  local EdInf=GetInfo()
  return Mouse.X>=EdInf.X1 and Mouse.Y>=EdInf.Y1+EdInf.TitleBar and Mouse.X<=EdInf.X2-2*EdInf.ScrollBar and Mouse.Y<=EdInf.Y2-EdInf.KeyBar -- Кликнули в текст, значит разрешим макрос.
end

local function MouseToText()
-- Пересчёт экранных координат мышки в координаты текста.
  local EdInf = GetInfo()
  local X1 = EdInf.LeftPos
  local Y1 = EdInf.TopScreenLine
  local X2 = X1+EdInf.WindowSizeX-EdInf.ScrollBar
  local Y2 = Y1+EdInf.WindowSizeY-EdInf.KeyBar
  local Xm = X1+Mouse.X-EdInf.X1               ;  Xm = Xm<X1 and X1 or Xm>X2 and X2 or Xm
  local Ym = Y1+Mouse.Y-EdInf.Y1-EdInf.TitleBar;  Ym = Ym<Y1 and Y1 or Ym>Y2 and Y2 or Ym
  return Xm,Ym,X1,Y1,X2,Y2 -- Координаты мышки и экрана в тексте
end

local function MouseMove(SelMode,Xb,Yb)
-- Функция обработки движения мышки.
  local MM=mmode(1,1) -- Запретим перерисовку экрана.
  local EOL=Set(7,1) -- Разрешим "курсор за пределами строки".
  local Xm,Ym,X1,Y1,X2,Y2
  Xm,Ym,X1,Y1 = MouseToText()
  if not ((SelMode==1 or SelMode==2) and Xb and Yb) then Xb=Xm; Yb=Ym end -- За начало примем текущие координаты.
  while Mouse.Button~=0 do
    if SelMode==1 or SelMode==2 then
      -- Выделение. И магия :) для табов с вертикальными блоками.
      Pos(1,1,Yb); Pos(1,4-SelMode,Xb); Sel(SelMode+1,0)
      Pos(1,1,Ym); Pos(1,4-SelMode,Xm); Sel(SelMode+1,1)
    end
    Pos(1,5,X1); Pos(1,4,Y1) -- Координаты экрана в тексте.
    Pos(1,3,Xm); Pos(1,1,Ym) -- Координаты мышки в тексте.
    mmode(1,mmode(1,0),Pos(1,2)) -- Перерисуем экран. Двинем курсор для колорера(v.1.2.11.0).
    mf.waitkey(1)
    Xm,Ym,X1,Y1,X2,Y2 = MouseToText() -- Новые координаты.
    -- Скроллирование.
    if Xm==X1 and X1>1 then X1=X1-1; Xm=X1 elseif Xm==X2                     then X1=X1+1; Xm=X2+1 end
    if Ym==Y1 and Y1>1 then Y1=Y1-1; Ym=Y1 elseif Ym==Y2 and Ym<Editor.Lines then Y1=Y1+1; Ym=Y2+1 end
  end
  Set(7,EOL) -- Восстановим состояние "курсор за пределами строки".
  mmode(1,MM) -- Восстановим состояние отрисовки.
end

local function ClickInSel()
-- Функция проверки на клик в выделенной области.
  local Xm,Ym = MouseToText()
  local St=Sel(0,4); local Yb= St==0 and Ym or Sel(0,0); local Xb= St==0 and Xm or Sel(0,1); local Ye= St==0 and Ym or Sel(0,2); local Xe= St==0 and Xm or Sel(0,3) -- Тип и координаты выделения.
  local Sl=(St==0 or (St>0 and Ym<=Ye and Ym>=Yb)) -- Курсор в строках где есть выделение.
  local Sp=(Sl and ((St==2 and Xm>=Xb and Xm<=Xe) or (St==1 and ((Yb~=Ye and Ym==Yb and Xm>=Xb) or (Yb~=Ye and Ym==Ye and Xm<=Xe) or (Yb==Ye and Xm>=Xb and Xm<=Xe) or (Yb~=Ye and Ym~=Yb and Ym~=Ye))))) -- Курсор точно в выделении.
  if not Sp then
    Xb=nil; Yb=nil -- Если кликнули не в выделенной области, то считаем, что и выделения нет.
  else
    if (Xb-Xm)^2+0.2*(Yb-Ym)^2<(Xe-Xm)^2+0.2*(Ye-Ym)^2 then Xb,Yb = Xe,Ye end -- За начало выделенной области примем её дальний от места клика угол.
  end
  return Xb,Yb -- Координаты начала выделенного блока и координаты экрана.
end

local function SelWord(SelectType,Line,Column)
-- Функция выделения слова.
  local St= SelectType or 1
  local Xc,Yc
  if Line and Column then Yc,Xc = Line,Column else Xc,Yc = MouseToText() end
  Pos(1,1,Yc); Pos(1,3,Xc)
  local s=Editor.Value; local Xct=Editor.RealPos
  local Xe=Xct while s:sub(Xe,Xe):find("[%w_]") do Xe=Xe+1 end -- Ищем конец слова c курсором.
  local Xb=Xct while s:sub(Xb-1,Xb-1):find("[%w_]") do Xb=Xb-1 end -- Ищем начало слова c курсором.
  Pos(1,2,Xb); Sel(St+1,0); Pos(1,2,Xe); Sel(St+1,1) -- Выделяем найденное слово, если слово не нашли, то выделение просто снимется из-за равенства Beg и End.
  mmode(1,mmode(1,0),Pos(1,2,Xct)) -- Перерисуем экран. Двинем курсор для колорера.
end

local function SelLine(SelectType,Line,Column)
-- Функция выделения строки.
  local St= SelectType or 1
  local Xc,Yc
  if Line then Yc=Line; Xc= Column or Editor.CurPos else  Xc,Yc = MouseToText() end
  local Yb=Yc; local Ye= St==1 and Yc<Editor.Lines and Yc+1 or Yc
  Pos(1,1,Yc); local s=Editor.Value
  local Xb=1; local Xe= Yb~=Ye and 1 or s:len()+1
  Pos(1,1,Yb); Pos(1,2,Xb); Sel(St+1,0); Pos(1,1,Ye); Pos(1,2,Xe); Sel(St+1,1)
  Pos(1,1,Yc) -- Координаты курсора в тексте.
  mmode(1,mmode(1,0),Pos(1,2,Xc)) -- Перерисуем экран. Двинем курсор для колорера.
end

local function MouseSelect(Action,PostAct)
-- Функция работы мышкой с выделением в редакторе. © SimSU
  local NumClick=1
  local PA=true
  while NumClick do
    local Act = Action ~=nil and ((Sel(0,4)>0 and ClickInSel() and Action ["InSel"..NumClick]) or (Sel(0,4)>0 and not ClickInSel() and Action ["NotSel"..NumClick]) or Action ["Click"..NumClick])
    local PAct= PostAct~=nil and ((Sel(0,4)>0 and ClickInSel() and PostAct["InSel"..NumClick]) or (Sel(0,4)>0 and not ClickInSel() and PostAct["NotSel"..NumClick]) or PostAct["Click"..NumClick])
    if     Act=="SelNorm"  then MouseMove(1)
    elseif Act=="SelVert"  then MouseMove(2)
    elseif Act=="SelNone"  then MouseMove(0)
    elseif Act=="CorNorm"  then local Xb,Yb = ClickInSel(); MouseMove(1,Xb,Yb)
    elseif Act=="CorVert"  then local Xb,Yb = ClickInSel(); MouseMove(2,Xb,Yb)
    elseif Act=="WordNorm" then SelWord(1)
    elseif Act=="WordVert" then SelWord(2)
    elseif Act=="LineNorm" then SelLine(1)
    elseif Act=="LineVert" then SelLine(2)
    elseif Act=="Move"     then local PB=Set(2,1); MouseMove(0); Keys("CtrlM"); Set(2,PB); PA=false
    elseif Act=="Copy"     then local PB=Set(2,1); MouseMove(0); Keys("CtrlP"); Set(2,PB); PA=false
    end
    if     PA and PAct=="Copy"    then mf.clip(1,Editor.SelValue)
    elseif PA and PAct=="Cut"     then mf.clip(1,Editor.SelValue); editor.DeleteBlock() --Keys("CtrlD")
    elseif PA and PAct=="Add"     then mf.clip(2,Editor.SelValue)
    elseif PA and PAct=="CutAdd"  then mf.clip(2,Editor.SelValue); editor.DeleteBlock() --Keys("CtrlD")
    elseif PA and PAct=="Delete"  then editor.DeleteBlock() -- Keys("CtrlD")
    elseif PA and PAct=="Paste"   then Keys("CtrlV")
    elseif PA and PAct=="Replace" then local s=Editor.SelValue; editor.DeleteBlock() Keys("CtrlV"); mf.clip(1,s)
    end
    local VK=mf.waitkey(S.Timing)
    NumClick= VK:find("Click",1,true) and NumClick+1 or nil
  end
end;
-------------------------------------------------------------------------------
local Editor_MouseSelect={
  GetInfo      = GetInfo      ;
  InEditorMouse= InEditorMouse;
  MouseToText  = MouseToText  ;
  MouseMove    = MouseMove    ;
  ClickInSel   = ClickInSel   ;
  SelWord      = SelWord      ;
  SelLine      = SelLine      ;
  MouseSelect  = MouseSelect  ;
}; for k,v in pairs(Editor_MouseSelect) do Editor_MouseSelect[k:lower()] = v end
-------------------------------------------------------------------------------
--Для командной строки John Doe
if _filename and (not sh or _cmdline) then --luacheck: ignore 113/_cmdline 113/sh
  if not ... then
    return require'le'(GetInfo())
  else
    local f=assert(loadstring(_cmdline or ...)) --luacheck: ignore 113/_cmdline
    setmetatable(Editor_MouseSelect,{__index = _G})
    return setfenv(f,Editor_MouseSelect)()
  end
end
-------------------------------------------------------------------------------
--Для использования в виде модуля
if not Macro then return Editor_MouseSelect end
-------------------------------------------------------------------------------
for i=1,#S do
Macro {id=S[i].id;
  area="Editor"; key=S[i].Key; priority=S[i].Prior; sortpriority=S[i].Sort; description=M[i];
  condition=function() return InEditorMouse() end;
  action=function() return MouseSelect(S[i].Action,S[i].PostAct) end;
}
end
