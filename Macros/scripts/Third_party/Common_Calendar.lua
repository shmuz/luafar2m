-------------------------------------------------------------------------------
-- Календарь. © SimSU
-------------------------------------------------------------------------------

---- Настройки
local Settings = {
  Key = "CtrlShiftF5";
  FirstDayOfWeek = 0; -- 0=Sunday, 1=Monday, etc.
}
local S = Settings

local MsgRus = {
  Descr="Календарь. © SimSU";
  Title="Календарь";
  __DaysOfWeek={"Вс","Пн","Вт","Ср","Чт","Пт","Сб"};
  Months={"Январь","Февраль","Март","Апрель","Май","Июнь","Июль","Август","Сентябрь","Октябрь","Ноябрь","Декабрь"};
  Ins="Вставить";
  Ok="Закрыть";
}

local MsgEng = {
  Descr="Calendar. © SimSU";
  Title="Calendar";
  __DaysOfWeek={"Su","Mo","Tu","We","Th","Fr","Sa"};
  Months={"January","February","March","April","May","June","July","August","September","October","November","December"};
  Ins="Insert";
  Ok="Close";
}

local function CorrectMsg(tbl)
  tbl.DaysOfWeek = {}
  for k=1,7 do
    tbl.DaysOfWeek[k] = tbl.__DaysOfWeek[(S.FirstDayOfWeek+k-1) % 7 + 1]
  end
end

CorrectMsg(MsgRus)
CorrectMsg(MsgEng)

-- Встроенные языки / Built-in languages
local function Messages()
  return win.GetEnv("FARLANG")=="Russian" and MsgRus or MsgEng
end

local M=Messages()

-------------------------------------------------------------------------------
local F,msg = far.Flags,far.SendDlgMessage
local MSinDay=1000*60*60*24
local DaysInMonths={[0]=31,31,28,31,30,31,30,31,31,30,31,30,31,[13]=31}

local function Today()
--[[ Возвращает таблицу DateTime с полями:
  wYear:          number
  wMonth:         number
  wDayOfWeek:     number
  wDay:           number
  wHour:          number
  wMinute:        number
  wSecond:        number
  wMilliseconds:  number
]]
  return win.FileTimeToSystemTime(win.FileTimeToLocalFileTime(win.GetSystemTimeAsFileTime()))
end

local function Leap(DateTime) -- високосный год?
  return DateTime.wYear%4 ==0 and (DateTime.wYear%100 ~=0 or DateTime.wYear%400 ==0)
end

local function IncDay(DateTime,Days)
  local dt=win.FileTimeToSystemTime(win.SystemTimeToFileTime(DateTime)+Days*MSinDay) or DateTime
  DaysInMonths[2]=Leap(dt) and 29 or 28 --### потенциальный или реальный баг
  return dt
end

local function WeekStartDay(DateTime) -- первый день текущей недели параметра DateTime
  local a = S.FirstDayOfWeek - DateTime.wDayOfWeek
  return IncDay(DateTime, a <= 0 and a or -7+a)
end

local function Monday(DateTime) -- последний наступивший понедельник параметра DateTime
  local a = 1 - DateTime.wDayOfWeek
  return IncDay(DateTime, a <= 0 and a or -7+a)
end

local function FirstDay(DateTime) -- первый день месяца параметра DateTime
  return IncDay(DateTime,1-DateTime.wDay)
end

local function LastDay(DateTime) -- последний день месяца параметра DateTime
  return IncDay(DaysInMonths[DateTime.wMonth]-DateTime.wDay)
end

local function IncMonth(DateTime) -- добавить 1 месяц (применяется нетрадиционная коррекция дня месяца)
  return IncDay(DateTime, DateTime.wDay>DaysInMonths[DateTime.wMonth+1]
         and DaysInMonths[DateTime.wMonth+1] or DaysInMonths[DateTime.wMonth])
end

local function DecMonth(DateTime) -- убавить 1 месяц (применяется традиционная коррекция дня месяца)
  return IncDay(DateTime, DateTime.wDay>DaysInMonths[DateTime.wMonth-1]
         and -DateTime.wDay or -DaysInMonths[DateTime.wMonth-1])
end

local function IncYear(DateTime) -- добавить 1 год
  return IncDay(DateTime,
    DateTime.wMonth>2  and Leap(IncDay(DateTime,365)) and 366 or
    DateTime.wMonth==2 and DateTime.wDay==29 and 365 or
    DateTime.wMonth<3  and Leap(DateTime) and 366 or 365
  )
end

local function DecYear(DateTime) -- убавить 1 год
  return IncDay(DateTime,
    DateTime.wMonth>2  and Leap(DateTime) and -366 or
    DateTime.wMonth==2 and DateTime.wDay==29 and -366 or
    DateTime.wMonth<3  and Leap(IncDay(DateTime,-365)) and -366 or -365
  )
end

local function Calendar(DateTime)
  local sd = require "far2.simpledialog"
  M=Messages()
--==
  local Current=Today()
--==
  IncDay(Current,0) -- Чтобы февраль откорректировать.
--==

  local dt=DateTime and win.SystemTimeToFileTime(DateTime) and DateTime or Current
  local Items = {
    guid="615d826b-3921-48bb-9cf2-c6d345833855";
    width=36;
    {tp="dbox"; text=M.Title},
    {tp="sep"},
    {tp="butt";             name="decYear"; btnnoclose=1; x1=4;  text="<";        }, --Год назад
    {tp="fixedit";          name="Year";     mask="9999"; x1=16; width=4;  y1=""; }, --Год
    {tp="butt";             name="incYear"; btnnoclose=1; x1=27; text=">"; y1=""; }, --Год вперёд
    {tp="sep"                                                            },
  }
  local Months={}
  for m=1,12 do
    Months[m]={}; Months[m]["Text"]=M.Months[m]
  end
  local Add=table.insert
  Add(Items,{tp="butt";     name="decMonth"; btnnoclose=1;   x1=4;  text="<";                  }) --Месяц назад
  Add(Items,{tp="combobox"; name="Month";    dropdownlist=1; x1=10; x2=24; list=Months; y1=""; }) --Месяц
  Add(Items,{tp="butt";     name="incMonth"; btnnoclose=1;   x1=27; text=">";           y1=""; }) --Месяц вперёд
  Add(Items,{tp="sep"})

  for d=1,7 do
    Add(Items,{tp="text"; text=M.DaysOfWeek[d]})
  end
  local IF=#Items

  for w=0,5 do
    for d=1,7 do
      Add(Items,{tp="text"; x1=8+w*4; ystep=(d==1 and -6); })
    end
  end

  Add(Items,{tp="user";     name="User"; x1=8; ystep=-6; x2=31; height=7; }) --Движение по дням
  Add(Items,{tp="sep"})
  Add(Items,{tp="fixedit";  name="Date"; x1=7; x2=16; mask="99.99.9999"; readonly=1; })
  Add(Items,{tp="butt";     name="Insert"; x1=18; text=M.Ins; y1="";  }) -- Вставить дату
  Add(Items,{tp="sep"})
  Add(Items,{tp="butt"; centergroup=1; default=1; text=M.Ok; focus=1; })

  local Dlg = sd.New(Items)
  local Pos = Dlg:Indexes()
  local Text
  local ITic

  local function Rebuild(hDlg,dT)
    msg(hDlg,F.DM_ENABLEREDRAW,0)
    msg(hDlg,F.DM_SETTEXT,Pos.Year,tostring(dT.wYear))
    msg(hDlg,F.DM_LISTSETCURPOS,Pos.Month,{SelectPos=dT.wMonth})
    local day=WeekStartDay(FirstDay(dT))
    ITic=nil
    for w=0,5 do
      for d=1,7 do
        local curpos=IF+w*7+d
        msg(hDlg,F.DM_ENABLE,curpos,day.wMonth==dT.wMonth and 1 or 0)
        if day.wYear==Current.wYear and day.wMonth==Current.wMonth and day.wDay==Current.wDay then
          msg(hDlg,F.DM_SETTEXT,curpos,("[%2s]"):format(day.wDay))
          ITic= ITic or w*7+d
        elseif day.wMonth==dT.wMonth and day.wDay==dT.wDay then
          msg(hDlg,F.DM_SETTEXT,curpos,("{%2s}"):format(day.wDay))
          ITic=day.wMonth==dT.wMonth and w*7+d or ITic
        else
          msg(hDlg,F.DM_SETTEXT,curpos,("%3s "):format(day.wDay))
        end
        day=IncDay(day,1)
      end
    end
    msg(hDlg,F.DM_SETTEXT,Pos.Date,string.format("%02d.%02d.%4d",dT.wDay,dT.wMonth,dT.wYear))
    msg(hDlg,F.DM_ENABLEREDRAW,1)
  end

  function Items.proc(hDlg,Msg,Param1,Param2)
    if Msg==F.DN_INITDIALOG then
      Rebuild(hDlg,dt)
    elseif Msg==F.DN_BTNCLICK and Param1==Pos.Insert then
      Text=msg(hDlg,F.DM_GETTEXT, Pos.Date)
    elseif Msg==F.DN_BTNCLICK then
      if     Param1==Pos.decYear  then dt=DecYear(dt)  -- Год назад
      elseif Param1==Pos.incYear  then dt=IncYear(dt)  -- Год вперёд
      elseif Param1==Pos.decMonth then dt=DecMonth(dt) -- Месяц назад
      elseif Param1==Pos.incMonth then dt=IncMonth(dt) -- Месяц вперёд
      end
      Rebuild(hDlg,dt)
    elseif Msg==F.DN_EDITCHANGE and Param1==Pos.Year then
      local oldY=dt.wYear
      dt.wYear=tonumber(msg(hDlg,F.DM_GETTEXT, Pos.Year))
      if win.SystemTimeToFileTime(dt) then
        Rebuild(hDlg,dt)
      else
        ---require"far2.lua_explorer"(dt,"dt")
        dt.wYear=oldY
      end
    elseif Msg==F.DN_EDITCHANGE and Param1==Pos.Month then
      local oldM=dt.wMonth
      dt.wMonth=(msg(hDlg,F.DM_LISTGETCURPOS, Pos.Month)).SelectPos
      if not win.SystemTimeToFileTime(dt) then
        msg(hDlg,F.DM_LISTSETCURPOS,Pos.Month,{SelectPos=dt.wMonth})
        dt.wMonth=oldM
      end
      Rebuild(hDlg,dt)
    elseif Msg==F.DN_KEY and Param1==Pos.User then
      if     band(Param2,F.KEY_CTRL+F.KEY_RCTRL)~=0 then
        local key = band(Param2, bnot(F.KEY_CTRL+F.KEY_RCTRL))
        if     key==F.KEY_LEFT  then dt=DecMonth(dt)
        elseif key==F.KEY_UP    then dt=DecYear (dt)
        elseif key==F.KEY_RIGHT then dt=IncMonth(dt)
        elseif key==F.KEY_DOWN  then dt=IncYear (dt)
        end
      elseif Param2==F.KEY_LEFT  then dt=IncDay(dt,-7)
      elseif Param2==F.KEY_UP    then dt=IncDay(dt,-1)
      elseif Param2==F.KEY_RIGHT then dt=IncDay(dt, 7)
      elseif Param2==F.KEY_DOWN  then dt=IncDay(dt, 1)
      end
      Rebuild(hDlg,dt)
    elseif Msg==F.DN_MOUSECLICK and Param1==Pos.User then
      if Param2.ButtonState==1 then
        local i=math.floor(Param2.MousePositionX/4)*7+Param2.MousePositionY+1
        dt=IncDay(dt,i-ITic)
      end
      Rebuild(hDlg,dt)
    end
  end

  Dlg:Run()
  if Text then mf.print(Text) end
end
-------------------------------------------------------------------------------
local Common_Calendar={
  Today    = Today   ;
  Leap     = Leap    ;
  IncDay   = IncDay  ;
  Monday   = Monday  ;
  FirstDay = FirstDay;
  LastDay  = LastDay ;
  IncMonth = IncMonth;
  DecMonth = DecMonth;
  IncYear  = IncYear ;
  DecYear  = DecYear ;
  Calendar = Calendar;
  WeekStartDay=WeekStartDay;
}
local function filename() return Calendar() end
-------------------------------------------------------------------------------
if _filename then return filename(...) end
if not Macro then return {Common_Calendar=Common_Calendar} end
-------------------------------------------------------------------------------

Macro {id="6dd41dba-866d-4e67-83e0-ed6a809cbdf9";
  area="Common"; key=S.Key; description=M.Descr;
  action=function() Calendar() end;
}
