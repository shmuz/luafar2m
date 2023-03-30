-------------------------------------------------------------------------------
-- Календарь.
-- Copyright (c) SimSU
-- Copyright (c) Shmuel Zeigerman
--     (1) the utility made portable between Far3 and far2l (was: Far3)
--     (2) the interface language is set when the macro is called (was: when loaded)
--     (3) the first day of week can be specified (was: Monday)
--     (4) Added button [Today] for setting the current date
-------------------------------------------------------------------------------

---- Настройки
local Settings = {
  Key = "CtrlShift5";
  FirstDayOfWeek = 0; -- 0=Sunday, 1=Monday, etc.
}
local S = Settings

local MsgRus = {
  Descr="Календарь. © SimSU";
  Title="Календарь";
  __DaysOfWeek={"Вс","Пн","Вт","Ср","Чт","Пт","Сб"};
  Months={"Январь","Февраль","Март","Апрель","Май","Июнь","Июль","Август","Сентябрь","Октябрь","Ноябрь","Декабрь"};
  Today="&Сегодня";
  Ins="&Вставить";
  Close="&Закрыть";
}

local MsgEng = {
  Descr="Calendar. © SimSU";
  Title="Calendar";
  __DaysOfWeek={"Su","Mo","Tu","We","Th","Fr","Sa"};
  Months={"January","February","March","April","May","June","July","August","September","October","November","December"};
  Today="&Today";
  Ins="&Insert";
  Close="&Close";
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
local DnumToDate, DateToDnum
do
  local periods = {
    365*400 + 100 - 4 + 1, -- 400 years
    365*100 + 25 - 1,      -- 100 years
    365*4 + 1,             --   4 years
  }

  local factors = {400,100,4}

  local monthsReg  = {31,28,31,30,31,30,31,31,30,31,30,31}
  local monthsLeap = {31,29,31,30,31,30,31,31,30,31,30,31}

  local function leap(y)
    return y%4==0 and (y%100~=0 or y%400==0)
  end

  DnumToDate = function(aDay)
    local year = 0        -- number of whole years passed
    local month = 0       -- number of whole months passed
    local day = aDay - 1  -- number of whole days passed

    for i,T in ipairs(periods) do
      local r = day % T
      local num = (day-r) / T
      if i==2 and num==4 then num=3; r=r+T; end -- don't allow the 4-th century period
      year = year + factors[i] * num
      day = r
    end

    for _=1,3 do
      if day >= 365 then day=day-365; year=year+1; else break; end
    end

    local Months = leap(year+1) and monthsLeap or monthsReg
    for i,d in ipairs(Months) do
      if day < d then
        month = i-1
        break
      end
      day = day - d
    end

    return { wYear=year+1; wMonth=month+1; wDay=day+1; wDayOfWeek=aDay%7; }
  end

  DateToDnum = function(DateTime)
    local yy,mm,dd = DateTime.wYear, DateTime.wMonth, DateTime.wDay
    local day = 0
    local y1 = yy-1
    for i,T in ipairs(factors) do
      local r = y1 % T
      day = day + (y1-r) / T * periods[i]
      y1 = r
    end
    day = day + 365*y1

    local Months = leap(yy) and monthsLeap or monthsReg
    for i=1,mm-1 do
      day = day+Months[i]
    end
    return day + dd
  end
end
-------------------------------------------------------------------------------
local F,msg = far.Flags,far.SendDlgMessage
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
  local d = DateToDnum(DateTime) + Days
  return d > 0 and DnumToDate(d) or DateTime
end

local function WeekStartDay(DateTime) -- первый день текущей недели параметра DateTime
  local a = S.FirstDayOfWeek - DateTime.wDayOfWeek
  return IncDay(DateTime, a <= 0 and a or -7+a)
end

local function FirstDay(DateTime) -- первый день месяца параметра DateTime
  return IncDay(DateTime,1-DateTime.wDay)
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

  local Months={}
  for m,v in ipairs(M.Months) do Months[m] = {["Text"]=v}; end

  local Items = {
    guid="615d826b-3921-48bb-9cf2-c6d345833855";
    width=36;
    {tp="dbox"; text=M.Title},
    {tp="sep"},
    {tp="butt";     name="DecYear";  btnnoclose=1;   x1=4;  text="<";        }, --Год назад
    {tp="fixedit";  name="Year";     mask="9999";    x1=16; width=4;  y1=""; }, --Год
    {tp="butt";     name="IncYear";  btnnoclose=1;   x1=27; text=">"; y1=""; }, --Год вперёд
    {tp="sep"},
    {tp="butt";     name="DecMonth"; btnnoclose=1;   x1=4;  text="<";                     }, --Месяц назад
    {tp="combobox"; name="Month";    dropdownlist=1; x1=11; x2=23;    y1=""; list=Months; }, --Месяц
    {tp="butt";     name="IncMonth"; btnnoclose=1;   x1=27; text=">"; y1="";              }, --Месяц вперёд
    {tp="sep"}
  }

  local Add=table.insert
  for d=1,7 do
    Add(Items,{tp="text"; text=M.DaysOfWeek[d]})
  end
  local IF=#Items

  for w=0,5 do
    for d=1,7 do
      Add(Items,{tp="text"; x1=8+w*4; ystep=(d==1 and -6); })
    end
  end

  Add(Items,{tp="user";    name="User";   x1=8; ystep=-6; x2=31; height=7; }) --Движение по дням
  Add(Items,{tp="sep"})
  Add(Items,{tp="fixedit"; name="Date";   x1=7; x2=16; mask="99.99.9999"; readonly=1; })
  Add(Items,{tp="butt";    name="Today";  x1=18;  text=M.Today; y1=""; btnnoclose=1;  }) -- Установить текущую дату
  Add(Items,{tp="sep"})
  Add(Items,{tp="butt";    name="Close";  centergroup=1; default=1; text=M.Close; focus=1; })
  Add(Items,{tp="butt";    name="Insert"; centergroup=1; x1=18;  text=M.Ins; y1=""; }) -- Вставить дату

  local Dlg = sd.New(Items)
  local Pos = Dlg:Indexes()

  local Current = Today()
  IncDay(Current,0) -- Чтобы февраль откорректировать.
  local dt = DateTime and win.SystemTimeToFileTime(DateTime) and DateTime or Today()
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

  Items.keyaction = function(hDlg,Param1,KeyName)
    if Param1==Pos.User then
      if     KeyName=="Left"      then dt=IncDay(dt,-7)
      elseif KeyName=="Up"        then dt=IncDay(dt,-1)
      elseif KeyName=="Right"     then dt=IncDay(dt, 7)
      elseif KeyName=="Down"      then dt=IncDay(dt, 1)
      elseif KeyName=="CtrlLeft"  then dt=DecMonth(dt)
      elseif KeyName=="CtrlUp"    then dt=DecYear (dt)
      elseif KeyName=="CtrlRight" then dt=IncMonth(dt)
      elseif KeyName=="CtrlDown"  then dt=IncYear (dt)
      else return
      end
      Rebuild(hDlg,dt)
    end
  end

  Items.mouseaction = function(hDlg,Param1,Param2)
    if Param1==Pos.User then
      if Param2.ButtonState==1 then
        local i=math.floor(Param2.MousePositionX/4)*7+Param2.MousePositionY+1
        dt=IncDay(dt,i-ITic)
        Rebuild(hDlg,dt)
      end
    end
  end

  function Items.proc(hDlg,Msg,Param1,Param2)
    if Msg==F.DN_INITDIALOG then
      Rebuild(hDlg,dt)
    elseif Msg==F.DN_BTNCLICK then
      if     Param1==Pos.DecYear  then dt=DecYear(dt)  -- Год назад
      elseif Param1==Pos.IncYear  then dt=IncYear(dt)  -- Год вперёд
      elseif Param1==Pos.DecMonth then dt=DecMonth(dt) -- Месяц назад
      elseif Param1==Pos.IncMonth then dt=IncMonth(dt) -- Месяц вперёд
      elseif Param1==Pos.Today    then
        Current=Today()
        dt=Today()
        msg(hDlg,F.DM_SETFOCUS,Pos.Close)
      else return
      end
      Rebuild(hDlg,dt)
    elseif Msg==F.DN_EDITCHANGE and Param1==Pos.Year then
      local oldY=dt.wYear
      dt.wYear=tonumber(msg(hDlg,F.DM_GETTEXT, Pos.Year))
      if win.SystemTimeToFileTime(dt) then
        local pos=msg(hDlg,F.DM_GETCURSORPOS,Pos.Year)
        Rebuild(hDlg,dt)
        msg(hDlg,F.DM_SETCURSORPOS,Pos.Year,pos)
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
    end
  end

  local out,pos = Dlg:Run()
  if out and pos==Pos.Insert then mf.print(out.Date) end
end
-------------------------------------------------------------------------------
local Common_Calendar={
  Today    = Today   ;
  Leap     = Leap    ;
  IncDay   = IncDay  ;
  FirstDay = FirstDay;
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

Macro {
  area="Common"; key=S.Key; description=M.Descr;
  action=function() Calendar() end;
}
