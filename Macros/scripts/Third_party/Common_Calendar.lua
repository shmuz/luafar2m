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
local Text

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
  local dt=win.FileTimeToSystemTime(win.SystemTimeToFileTime(DateTime)+Days*MSinDay)
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
  M=Messages()
--==
  local Current=Today()
--==
  IncDay(Current,0) -- Чтобы февраль откорректировать.
--==

  local dt=DateTime and win.SystemTimeToFileTime(DateTime) and DateTime or Current
  local ITic
  local Items = {}
  Items[01]={F.DI_DOUBLEBOX,3, 1,32,18,0,0,0,0                  ,M.Title}
  Items[02]={F.DI_TEXT,    -1, 2, 0, 2,0,0,F.DIF_SEPARATOR,0    ,""     }
  Items[03]={F.DI_BUTTON,   4, 3, 0, 3,0,0,F.DIF_BTNNOCLOSE,0   ,"<"    } --Год назад
  Items[04]={F.DI_FIXEDIT, 16, 3,19, 3,0,"9999",F.DIF_MASKEDIT,0,""     } --Год
  Items[05]={F.DI_BUTTON,  27, 3, 0, 3,0,0,F.DIF_BTNNOCLOSE,0   ,">"    } --Год вперёд
  Items[06]={F.DI_TEXT,    -1, 4, 0, 4,0,0,F.DIF_SEPARATOR,0    ,""     }
  local Months={}
  for m=1,12 do
    Months[m]={}; Months[m]["Text"]=M.Months[m]
  end
  Items[07]={F.DI_BUTTON,   4, 5, 0,21,0,0,F.DIF_BTNNOCLOSE,0,"<"} --Месяц назад
  Items[08]={F.DI_COMBOBOX,10, 5,24, 5,0,Months,F.DIF_DROPDOWNLIST,0,""} --Месяц
  Items[09]={F.DI_BUTTON,  27, 5, 0,21,0,0,F.DIF_BTNNOCLOSE,0,">"} --Месяц вперёд
  Items[10]={F.DI_TEXT,     0, 6, 0, 6,0,0,F.DIF_SEPARATOR,0,""}
  Items[11]={F.DI_TEXT,     0,14, 0,14,0,0,F.DIF_SEPARATOR,0,""}
  local yd=6
  for d=1,7 do
    Items[#Items+1]={F.DI_TEXT, 5, yd+d, 0, yd+d,0,0,0,0,M.DaysOfWeek[d]}
  end
  local IF=18
  for w=0,5 do
    for d=1,7 do
      Items[#Items+1]={F.DI_TEXT, 8+w*4, yd+d, 0, yd+d,0,0,0,0,""}
    end
  end
  Items[61]={F.DI_USERCONTROL,8, 7,31,13,0,0,0,0} --Движение по дням
  Items[62]={F.DI_FIXEDIT,    7,15,16,15,0,"99.99.9999",F.DIF_MASKEDIT+F.DIF_READONLY,0,""}
  Items[63]={F.DI_BUTTON,    18,15, 0,15,0,0,0,0,M.Ins} -- Вставить дату
  Items[64]={F.DI_TEXT,       0,16, 0,16,0,0,F.DIF_SEPARATOR,0,""}
  Items[65]={F.DI_BUTTON,     0,17, 0,17,1,0,F.DIF_CENTERGROUP,1,M.Ok}

  local function Rebuild(hDlg,dT)
    msg(hDlg,F.DM_ENABLEREDRAW ,0                       )
    msg(hDlg,F.DM_SETTEXT      ,04,tostring(dT.wYear)   )
    msg(hDlg,F.DM_LISTSETCURPOS,08,{SelectPos=dT.wMonth})
    local day=WeekStartDay(FirstDay(dT))
    ITic=nil
    for w=0,5 do
      for d=1,7 do
        msg(hDlg,F.DM_SETTEXT,IF+w*7+d,("%3s "):format(day.wDay)       )
        msg(hDlg,F.DM_ENABLE ,IF+w*7+d,day.wMonth==dT.wMonth and 1 or 0)
        if day.wYear==Current.wYear and day.wMonth==Current.wMonth and day.wDay==Current.wDay then
          msg(hDlg,F.DM_SETTEXT,IF+w*7+d,("[%2s]"):format(day.wDay))
          ITic= ITic or w*7+d
        elseif day.wDay==dT.wDay then
          msg(hDlg,F.DM_SETTEXT,IF+w*7+d,("{%2s}"):format(day.wDay))
          ITic=day.wMonth==dT.wMonth and w*7+d or ITic
        else
          msg(hDlg,F.DM_SETTEXT,IF+w*7+d,("%3s " ):format(day.wDay))
        end
        day=IncDay(day,1)
      end
    end
    msg(hDlg,F.DM_SETTEXT     ,62,string.format("%02d.%02d.%4d",dT.wDay,dT.wMonth,dT.wYear))
    msg(hDlg,F.DM_ENABLEREDRAW,1)
  end

  local function DlgProc(hDlg,Msg,Param1,Param2)
    if Msg==F.DN_GETDIALOGINFO then
      return win.Uuid("615d826b-3921-48bb-9cf2-c6d345833855")
    elseif Msg==F.DN_INITDIALOG then
      Rebuild(hDlg,dt)
    elseif Msg==F.DN_BTNCLICK and Param1==63 then
      Text=msg(hDlg,F.DM_GETTEXT, 62, nil)
    elseif Msg==F.DN_BTNCLICK then
      if     Param1==03 --[[Год назад   ]] then dt=DecYear(dt)
      elseif Param1==05 --[[Год вперёд  ]] then dt=IncYear(dt)
      elseif Param1==07 --[[Месяц назад ]] then dt=DecMonth(dt)
      elseif Param1==09 --[[Месяц вперёд]] then dt=IncMonth(dt)
      end
      Rebuild(hDlg,dt)
    elseif Msg==F.DN_EDITCHANGE and Param1==04 then
      local oldY=dt.wYear
      dt.wYear=tonumber(msg(hDlg,F.DM_GETTEXT, 04, nil))
      if win.SystemTimeToFileTime(dt) then
        Rebuild(hDlg,dt)
      else
        dt.wYear=oldY
      end
    elseif Msg==F.DN_EDITCHANGE and Param1==08 then
      local oldM=dt.wMonth
      dt.wMonth=(msg(hDlg,F.DM_LISTGETCURPOS, 08, nil)).SelectPos
      if not win.SystemTimeToFileTime(dt) then
        msg(hDlg,F.DM_LISTSETCURPOS,08,{SelectPos=dt.wMonth})
        dt.wMonth=oldM
      end
      Rebuild(hDlg,dt)
    elseif Msg==F.DN_KEY and Param1==61 then
      if     band(Param2,F.KEY_CTRL+F.KEY_RCTRL)~=0 then
        local key = band(Param2, bnot(F.KEY_CTRL+F.KEY_RCTRL))
        if     key==F.KEY_LEFT  then dt=DecMonth(dt   )
        elseif key==F.KEY_UP    then dt=DecYear (dt,-1)
        elseif key==F.KEY_RIGHT then dt=IncMonth(dt, 7)
        elseif key==F.KEY_DOWN  then dt=IncYear (dt, 1)
        end
      elseif Param2==F.KEY_LEFT  then dt=IncDay(dt,-7)
      elseif Param2==F.KEY_UP    then dt=IncDay(dt,-1)
      elseif Param2==F.KEY_RIGHT then dt=IncDay(dt, 7)
      elseif Param2==F.KEY_DOWN  then dt=IncDay(dt, 1)
      end
      Rebuild(hDlg,dt)
    elseif Msg==F.DN_MOUSECLICK and Param1==61 then
      if Param2.ButtonState==1 then
        local i=math.floor(Param2.MousePositionX/4)*7+Param2.MousePositionY+1
        dt=IncDay(dt,i-ITic)
      end
      Rebuild(hDlg,dt)
    end
  end

  far.Dialog (-1,-1,36,20,nil,Items,nil,DlgProc)
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
