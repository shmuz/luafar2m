-------------------------------------------------------------------------------
-- Календарь.
-- Copyright (c) SimSU
-- Copyright (c) Shmuel Zeigerman
--     (1) The utility made portable between Far3 and far2m (was: Far3)
--     (2) The interface language is set when the macro is called (was: when loaded)
--     (3) The first day of week can be specified (was: Monday)
--     (4) Added button [Today] for setting the current date
--     (5) The calendar starts from 0001-01-01 (was: 1601-01-01)
--     (6) Layout can be either "vertical weeks" (as in original) or "horizontal weeks"
-------------------------------------------------------------------------------

---- Настройки
local Settings = {
  Key = "CtrlShift5 CtrlShift6";
  FirstDayOfWeek = 0; -- 0=Sunday, 1=Monday, etc.
}
local S = Settings

local MsgRus = {
  Descr  = "Календарь. © SimSU";
  Title  = "Календарь";
  DaysOfWeek = {"Вс","Пн","Вт","Ср","Чт","Пт","Сб"};
  Months = {"Январь","Февраль","Март","Апрель","Май","Июнь","Июль","Август","Сентябрь","Октябрь",
            "Ноябрь","Декабрь"};
  Today  = "&Сегодня";
  Ins    = "&Вставить";
  Close  = "&Закрыть";
}

local MsgEng = {
  Descr  = "Calendar. © SimSU";
  Title  = "Calendar";
  DaysOfWeek = {"Su","Mo","Tu","We","Th","Fr","Sa"};
  Months = {"January","February","March","April","May","June","July","August","September","October",
            "November","December"};
  Today  = "&Today";
  Ins    = "&Insert";
  Close  = "&Close";
}

local F = far.Flags
local _Colors = far.Colors or F -- luacheck: no global (different between far2 and far3)
local COLOR_ENB = far.AdvControl(F.ACTL_GETCOLOR,_Colors.COL_DIALOGTEXT)
local COLOR_DSB = far.AdvControl(F.ACTL_GETCOLOR,_Colors.COL_DIALOGDISABLED)
local COLOR_WD  = {0x79}
local WEEK = 7
local NUMWEEKS = 6
local CELL_WIDTH = 4

local Cal = {}
local Cal_meta = { __index=Cal }

local function NewCalendar(aHorizontalWeek)
  local self = setmetatable({}, Cal_meta)
  self.HorizWeek = aHorizontalWeek
  self.ucHoriz = aHorizontalWeek and WEEK or NUMWEEKS -- user control width, in cells
  self.ucVert = aHorizontalWeek and NUMWEEKS or WEEK  -- user control height
  self.IncHoriz = aHorizontalWeek and 1 or WEEK
  self.IncVert = aHorizontalWeek and WEEK or 1
  return self
end

-- Встроенные языки / Built-in languages
local function Messages()
  return win.GetEnv("FARLANG")=="Russian" and MsgRus or MsgEng
end

local M=Messages()

local function GetDayOfWeek(num)
  return M.DaysOfWeek[(S.FirstDayOfWeek+num-1) % WEEK + 1]
end

local function GetAllDaysOfWeek()
  local t = {}
  for k=1,WEEK do t[k] = GetDayOfWeek(k) end
  return table.concat(t, (" "):rep(CELL_WIDTH - 2))
end

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
local Send = far.SendDlgMessage
local DaysInMonth={[0]=31,31,28,31,30,31,30,31,31,30,31,30,31,[13]=31}
local MaxDayNum = DateToDnum {wYear=9999; wMonth=12; wDay=31}

local function CopyDate(dt)
  local t = {}
  for k,v in pairs(dt) do t[k]=v end
  return t
end

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
  local lt=win.GetLocalTime
  return lt and lt() or
    win.FileTimeToSystemTime(win.FileTimeToLocalFileTime(win.GetSystemTimeAsFileTime()))
end

local function Leap(year) -- високосный год?
  return year%4 == 0 and (year%100 ~= 0 or year%400 == 0)
end

local function IncDay(dt,Days)
  local dnum = DateToDnum(dt) + Days
  return (dnum > 0 and dnum <= MaxDayNum) and DnumToDate(dnum) or CopyDate(dt)
end

local function WeekStartDay(dt) -- первый день текущей недели параметра dt
  local a = S.FirstDayOfWeek - dt.wDayOfWeek
  return IncDay(dt, a <= 0 and a or a-WEEK)
end

local function MonthFirstDay(dt) -- первый день месяца параметра dt
  return IncDay(dt,1-dt.wDay)
end

local function IncMonth(dt) -- добавить 1 месяц
  local This = DaysInMonth[dt.wMonth]
  local Next = DaysInMonth[dt.wMonth+1]
  if This==28 and Leap(dt.wYear) then This=29 end
  if Next==28 and Leap(dt.wYear) then Next=29 end
  return IncDay(dt, dt.wDay<=Next and This or This-dt.wDay+Next)
end

local function DecMonth(dt) -- убавить 1 месяц
  local Prev = DaysInMonth[dt.wMonth-1]
  if Prev==28 and Leap(dt.wYear) then Prev=29 end
  return IncDay(dt, dt.wDay<=Prev and -Prev or -dt.wDay)
end

local function ChangeMonth(dt,month) -- изменить месяц на параметр month
  local Next = DaysInMonth[month]
  if Next==28 and Leap(dt.wYear) then Next=29 end
  dt.wDay=math.min(Next,dt.wDay)
  dt.wMonth=month
  return IncDay(dt,0)
end

local function IncYear(dt) -- добавить 1 год
  local Inc=365
  if Leap(dt.wYear) then
    if dt.wMonth<=2 and not (dt.wMonth==2 and dt.wDay==29) then Inc=366 end
  elseif Leap(dt.wYear+1) then
    if dt.wMonth>2 then Inc=366 end
  end
  return IncDay(dt,Inc)
end

local function DecYear(dt) -- убавить 1 год
  local Inc=365
  if Leap(dt.wYear) then
    if dt.wMonth>2 or (dt.wMonth==2 and dt.wDay==29) then Inc=366 end
  elseif Leap(dt.wYear-1) then
    if dt.wMonth<=2 then Inc=366 end
  end
  return IncDay(dt,-Inc)
end

function Cal:Calendar(DateTime)
  local sd = require "far2.simpledialog"
  M=Messages()

  local Months={}
  for m,v in ipairs(M.Months) do Months[m] = {["Text"]=v}; end

  local buff = far.CreateUserControl(CELL_WIDTH * self.ucHoriz, WEEK)

  local Items = {
    guid="615d826b-3921-48bb-9cf2-c6d345833855";
    width=36;
    {tp="dbox"; text=M.Title},
    {tp="sep"},
    {tp="butt";     name="DecYear";  btnnoclose=1;   x1=4;  text="<";        }, --Год назад
    {tp="fixedit";  name="Year";     mask="9999";    x1=16; width=4;  y1=""; }, --Год
    {tp="butt";     name="IncYear";  btnnoclose=1;   x1=27; text=">"; y1=""; }, --Год вперёд
    {tp="sep"},
    {tp="butt";     name="DecMonth"; btnnoclose=1;   x1=4;  text="<";                 }, --Месяц назад
    {tp="combobox"; name="Month";    dropdown=1; x1=11; x2=23;    y1=""; list=Months; }, --Месяц
    {tp="butt";     name="IncMonth"; btnnoclose=1;   x1=27; text=">"; y1="";          }, --Месяц вперёд
    {tp="sep" },
  }
  local function AddItems(tt)
    for _,v in ipairs(tt) do table.insert(Items, v) end
  end

  if self.HorizWeek then AddItems {
    {tp="text"; text=GetAllDaysOfWeek(); x1=6; colors=COLOR_WD; },
    {tp="user"; name="User"; width=CELL_WIDTH*self.ucHoriz; height=self.ucVert; buffer=buff; }}
  else AddItems {
    {tp="text"; text=GetDayOfWeek(1); width=2; colors=COLOR_WD; },
    {tp="text"; text=GetDayOfWeek(2); width=2; colors=COLOR_WD; },
    {tp="text"; text=GetDayOfWeek(3); width=2; colors=COLOR_WD; },
    {tp="text"; text=GetDayOfWeek(4); width=2; colors=COLOR_WD; },
    {tp="text"; text=GetDayOfWeek(5); width=2; colors=COLOR_WD; },
    {tp="text"; text=GetDayOfWeek(6); width=2; colors=COLOR_WD; },
    {tp="text"; text=GetDayOfWeek(7); width=2; colors=COLOR_WD; },
    {tp="user"; name="User"; x1=8; ystep=1-WEEK; width=CELL_WIDTH*self.ucHoriz; height=WEEK; buffer=buff; }}
  end

  AddItems {
    {tp="sep" },
    {tp="fixedit"; name="Date";   x1=7; x2=16; mask="99.99.9999"; readonly=1; },
    {tp="butt";    name="Today";  x1=18;  text=M.Today; y1=""; btnnoclose=1;  }, -- Установить текущую дату
    {tp="sep" },
    {tp="butt";    name="Close";  centergroup=1; default=1; text=M.Close; focus=1; },
    {tp="butt";    name="Insert"; centergroup=1; x1=18;  text=M.Ins; y1=""; }, -- Вставить дату
  }

  local Dlg = sd.New(Items)
  local Pos = Dlg:Indexes()

  local Current = Today()
  local dt = DateTime or CopyDate(Current)
  local ITic
  local IsRebuilding

  local function Rebuild(hDlg,dT)
    IsRebuilding=true
    Send(hDlg,F.DM_ENABLEREDRAW,0)
    Send(hDlg,F.DM_SETTEXT,Pos.Year,("%04d"):format(dT.wYear))
    Send(hDlg,F.DM_LISTSETCURPOS,Pos.Month,{SelectPos=dT.wMonth})
    local day=WeekStartDay(MonthFirstDay(dT))
    ITic=nil
    local elem={}
    for w=0,NUMWEEKS-1 do
      for d=1,WEEK do
        local txt
        if day.wYear==Current.wYear and day.wMonth==Current.wMonth and day.wDay==Current.wDay then
          txt = ("[%2s]"):format(day.wDay)
          ITic= ITic or w*WEEK+d
        elseif day.wDay==dT.wDay then
          txt = ("{%2s}"):format(day.wDay)
          ITic=day.wMonth==dT.wMonth and w*WEEK+d or ITic
        else
          txt = ("%3s "):format(day.wDay)
        end
        local color=day.wMonth==dT.wMonth and COLOR_ENB or COLOR_DSB
        local curpos = self.HorizWeek
          and 1 + ((d-1) + w*self.ucHoriz) * CELL_WIDTH
          or  1 + (w + (d-1)*self.ucHoriz) * CELL_WIDTH
        for k=1,CELL_WIDTH do
          elem.Char=txt:sub(k,k)
          elem.Attributes=color
          buff[curpos+k-1]=elem
        end
        day=IncDay(day,1)
      end
    end
    Send(hDlg,F.DM_SETTEXT,Pos.Date,("%02d.%02d.%04d"):format(dT.wDay,dT.wMonth,dT.wYear))
    Send(hDlg,F.DM_ENABLEREDRAW,1)
    IsRebuilding=false
  end

  local keyaction = function(hDlg,Param1,KeyName)
    if Param1==Pos.User then
      if     KeyName=="Left"      then dt=IncDay(dt, -self.IncHoriz)
      elseif KeyName=="Up"        then dt=IncDay(dt, -self.IncVert)
      elseif KeyName=="Right"     then dt=IncDay(dt, self.IncHoriz)
      elseif KeyName=="Down"      then dt=IncDay(dt, self.IncVert)
      elseif KeyName=="CtrlLeft"  then dt=DecMonth(dt)
      elseif KeyName=="CtrlUp"    then dt=DecYear (dt)
      elseif KeyName=="CtrlRight" then dt=IncMonth(dt)
      elseif KeyName=="CtrlDown"  then dt=IncYear (dt)
      else return
      end
      Rebuild(hDlg,dt)
    end
  end

  local mouseaction = function(hDlg,Param1,Param2)
    if Param1 == Pos.User then
      if Param2.ButtonState == F.FROM_LEFT_1ST_BUTTON_PRESSED then
        local i = math.floor(Param2.MousePositionX/CELL_WIDTH) * self.IncHoriz
            + Param2.MousePositionY * self.IncVert + 1
        dt = IncDay(dt, i - ITic)
        Rebuild(hDlg, dt)
      end
    end
  end

  function Items.proc(hDlg,Msg,Param1,Param2)
    if IsRebuilding then
      return
    elseif Msg==F.DN_INITDIALOG then
      Rebuild(hDlg,dt)
    elseif Msg==F.DN_BTNCLICK then
      if     Param1==Pos.DecYear  then dt=DecYear(dt)  -- Год назад
      elseif Param1==Pos.IncYear  then dt=IncYear(dt)  -- Год вперёд
      elseif Param1==Pos.DecMonth then dt=DecMonth(dt) -- Месяц назад
      elseif Param1==Pos.IncMonth then dt=IncMonth(dt) -- Месяц вперёд
      elseif Param1==Pos.Today    then
        Current=Today()
        dt=CopyDate(Current)
        Send(hDlg,F.DM_SETFOCUS,Pos.Close)
      else return
      end
      Rebuild(hDlg,dt)
    elseif Msg==F.DN_EDITCHANGE and Param1==Pos.Year then
      local year=tonumber(Send(hDlg,F.DM_GETTEXT, Pos.Year))
      if year and year>0 then
        local pos=Send(hDlg,F.DM_GETCURSORPOS,Pos.Year)
        dt.wYear=year
        Rebuild(hDlg,dt)
        Send(hDlg,F.DM_SETCURSORPOS,Pos.Year,pos)
      end
    elseif Msg==F.DN_EDITCHANGE and Param1==Pos.Month then
      local month=Send(hDlg,F.DM_LISTGETCURPOS, Pos.Month).SelectPos
      ChangeMonth(dt,month)
      Rebuild(hDlg,dt)
    elseif Msg == "EVENT_KEY" then
      return keyaction(hDlg, Param1, Param2)
    elseif Msg == "EVENT_MOUSE" then
      return mouseaction(hDlg, Param1, Param2)
    end
  end

  local out,pos = Dlg:Run()
  if out and pos==Pos.Insert then mf.print(out.Date) end
end

Macro {
  id="920ABC6E-7E48-4E9E-A084-350699127AF4";
  area="Common"; key=S.Key; description=M.Descr;
  action=function()
    local HorizWeek = mf.akey(1) == "CtrlShift6"
    local cal = NewCalendar(HorizWeek)
    cal:Calendar()
  end;
}
