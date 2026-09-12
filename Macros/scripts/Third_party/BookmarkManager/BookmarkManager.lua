local Info = Info or package.loaded.regscript or function(...) return ... end --luacheck: ignore 113/Info
local nfo = Info {_filename or ...,
  name          = "Bookmark manager";
  description   = "Менеджер закладок на папки для Fara";
  version       = "3.0.10"; --http://semver.org/lang/ru/
  author        = "IgorZ";
  url           = "http://forum.farmanager.com/viewtopic.php?t=8465";
  id            = "F93842EB-FFD3-481A-8AA8-2E7DCEBDF2B1";
  minfarversion = {3,0,0,4324,0};
  files         = "*Eng.hlf;*Rus.hlf;*Eng.lng;*Rus.lng";
  helptxt       = [[
Управление:
 RCtrl+Shift+последовательность клавиш - запомнить закладку на текущую папку
 RCtrl+Alt+последовательность клавиш   - запомнить закладку на обе папки
 RCtrl+последовательность клавиш       - перейти на закладку/переменную окружения
 RCtrl+/                               - меню закладок

Префиксы командной строки:
 bm            - перейти по закладке/переменной окружения
 bma/bmal/bmag - добавить закладку/локальную закладку/глобальную закладку
 bme/bmel/bmeg - редактировать в диалоге закладку/локальную закладку/глобальную закладку
 bmr/bmrl/bmrg - удалить закладку/локальную закладку/глобальную закладку
 bmhelp        - вызов справки
Поскольку имена закладок переводятся в символы, набираемые при нажатом Ctrl, то, к примеру, bm:Фильмы равнозначна bm:ABKMVS. Пользуйтесь.
При переходе после имени закладки можно указать подкаталог, к примеру, "bm:фильмы\Мультфильмы\Фиксики".
]];
history         = [[
2014/01/21 v1.0   - Первый релиз.
2014/01/27 v1.0.1 - Исправлена ошибка, когда скрипт не запускался, пока не вызовешь меню закладок, мелкие правки
2014/01/27 v1.0.2 - Локализация работы с настройками, более корректная обработка ситуации, когда локальный и глобальный
                    профили совпадают и когда не совпадают, мелкие правки
2014/01/28 v1.0.3 - Сообщение при сохранении новой закладки, мелкие правки
2014/01/29 v1.0.4 - Небольшая оптимизация формирования меню, поддержка плагиновых панелей, мелкие правки
2014/02/04 v1.1   - Поддержка установки одновременно активной и пассивной панели, мелкие правки.
                    Экспериментально: изменён принцип хранения и загрузки языковых данных. Просьба отписаться в теме,
                    который вариант лучше
2014/02/04 v1.1.1 - Корректная обработка пустой строки в языковом файле
2014/02/05 v1.1.2 - Исправлена ошибка с обращением к старым языковым файлам, мелкие правки
2014/06/30 v1.2.0 - Расширение формата каталога. Теперь можно указывать панели: активную, пассивную, левую, правую. Изгнание io.lines.
                    Если языка нет, подгружается английский, при загрузке настроек язык не подгружается, если не менялся. Мелкие правки.
2014/11/14 v1.2.1 - Срабатывание быстрых клавиш в меню RCtrl+/, рефакторинг, добавим uid-ы в макросы и пункт в меню плагинов.
2015/01/26 v1.2.2 - "&" в меню отрабатывался как акселератор, а не символ. Запрет вводить символы, которые нельзя ввести в сочетании с Ctrl.
2015/02/06 v1.2.3 - В версии 1.2.1 была поломана загрузка части параметров, в результате чего при некоторых комбинациях настроек скрипт падал
                    при попытке создать новую закладку.
2015/06/01 v1.2.4 - Скрипт зачем-то вызывался из любых меню. В целях унификации с другими скриптами автора изменён механизм языковой настройки.
                    Исправлена ошибка с разной шириной столбца закладок для локальных и глобальных закладок. Теперь в менеджере закладок по F4
                    закладка не копируется при её изменении. Для копирования жать F5.
2015/12/09 v2.0.0 - Помимо закладок поддерживаются переменные окружения (только переход на папки). Если закладка или переменная набрана частично,
                    выводится список всех, содержащих набранный фрагмент. Мелкие правки.
2015/12/15 v2.0.1 - Мелкие правки.
2016/01/24 v2.1.0 - Добавлена работа из командной строки через префиксы. Можно переходить по закладкам и переменным окружения,
                    добавлять/редактировать в диалоге/удалять закладки. Рефакторинг. Исправление кучи внезапно обнаруженных ошибок.
2016/02/08 v2.1.1 - Сокращённые меню позволяют все те же действия, что и полное. Комбинации RCtrlЦифра передаются Far-у, если такой закладки
                    или переменной нет. Не совпадающие даже частично ни с одной закладкой или переменной окружения, содержащей путь, тоже.
2016/02/11 v2.1.2 - При вызове через префикс несуществующая комбинация не возвращается в виде нажатий клавиатуры.
2016/02/26 v2.2.0 - Настройка вынесена в отдельный диалог. Улучшены диалоги для совпадающих локального и глобального профилей. Переработана справка.
                    Добавлен префикс для вызова справки. Мелкие правки.
2016/02/29 v2.2.1 - Исправлена ошибка, из-за которой не показывалась справка.
2016/10/26 v2.3.0 - Теперь можно использовать в командной строке конструкции вида "bm:<метка><подкаталог>", например, "bm:фильмы\Мультфильмы\Фиксики".
                    Nfo. Смена места хранения данных. Разделение префиксов. При выводе справки используется язык справки фара. Улучшение
                    быстрого позиционирования в главном меню. Мелкие правки.
2016/10/26 v2.3.1 - В прошлой версии забыл сменить uid на id в зависимости от версии LuaMacro. Изменено определение Info.
2017/05/11 v2.4.0 - Скрипт можно вызывать из меню дисков; показываются только актуальные пункты. Исправлены замеченные ошибки. Мелкие правки.
2017/05/15 v2.4.1 - Исправлены свежевыявленные ошибки.
2017/08/01 v2.4.2 - Исправлена ошибка с вызовом меню при пустом списке закладок. Исправлены свежевыявленные ошибки в справке.
2017/08/03 v2.4.3 - Исправлена работа с закладками на плагины.
2017/08/08 v2.5.0 - Изменён формат хранения закладок в БД. Старый формат пока поддерживается. Рефакторинг.
2017/08/11 v2.5.1 - Исправлены некоторые недоделки и упущения предыдущей версии.
2017/08/12 v2.5.2 - Исправлен вызов из меню дисков, там же изменена логика работы.
2017/10/24 v2.5.3 - Теперь можно указать с помощью модификатора "C" необходимость смены панели. Подробности в справке.
2018/01/05 v2.5.4 - Работа над ошибками.
2018/05/16 v3.0.0 - Если в качестве цели указан файл, не просто переходим в папку, но и позиционируемся на файле. Возможно не только переходить
                    в папку или на файл, но и выполнять системные контекстные команды "открыть" (выполнить) и "редактировать"; можно указывать
                    действие в параметрах закладки. Можно указывать маски для пути (включая маску имени локального диска); основа алгоритма
                    разработана buniak_a_h. Если элемент пути не найден, ищем его же, но в обрамлении "*" (настраивается). Скрипт теперь можно
                    вызывать как функцию, параметры как для префиксов. При наборе последовательности символов она опционально отображается на экране.
                    При неполном наборе закладки/переменной, если подходит всего один вариант, меню может не выводиться (настраивается).
                    Отдельная настройка для показа переменных окружения в меню. Рефакторинг.
2018/07/27 v3.0.1 - Исправление ошибки с переходом в сетевую папку. Исправление справки. Рефакторинг.
2018/11/26 v3.0.2 - При вызове скрипта как функции без параметров ошибка не выдаётся. Исправлена ошибка при переходе в плагин.
2019/12/09 v3.0.3 - Исправлена ошибка при нажатии клавиш в режиме активной фильтрации. Предпочтительное место хранения закладок теперь настраивается.
                    Доработан вызов action-функций с учётом введённых в build 717 параметров для condition/action. Рефакторинг.
2020/04/22 v3.0.4 - Исправлена работа диалога настроек. Дополнена справка по диалогу настроек.
2020/05/22 v3.0.5 - Исправлена работа с закладкой на файл. Дополнена справка по закладкам.
2021/08/18 v3.0.6 - Исправлена ошибка с удалением несуществующей закладки. Рефакторинг.
2022/01/24 v3.0.7 - Исправлена ошибка с ненужными сообщениями об удалении несуществующей закладки. Исправлена опечатка в английском языковом файле.
2022/02/04 v3.0.8 - Исправлена ошибка с некорректной обработкой модификатора "C". Небольшой рефакторинг.
2023/02/17 v3.0.9 - Исправлена ошибка с выводом информации о новой папке при переходе для правой панели.
2025/03/14 v3.0.10- День числа π. Исправлена ошибка, возникшая из-за изменения поведения Far.
]];
  options       = { DefProfile = far.Flags.PSL_ROAMING--[[far.Flags.PSL_LOCAL--]] } -- место хранения настроек по умолчанию: глобальные/локальные
}
if not nfo then return end
-- +
--[[константы]]
-- -
local F,Author,KeysPart,ConfPart = far.Flags,"IgorZ","BookmarkManagerData","BookmarkManagerConfig"
local ToCtrl = { [" "]="",["|"]="",["\\"]="", -- таблица замены символов на те, которые вводятся с Ctrl
  ["~"]="`",["!"]="1",["@"]="2",["#"]="3",["№"]="3",["$"]="4",["%"]="5",["^"]="6",["&"]="7",["*"]="8",["("]="9",[")"]="0",["_"]="-",["+"]="=",
  ["{"]="[",["}"]="]",[":"]=";",['"']="'",["<"]=",",[">"]=".",["?"]="/",["Ё"]="`",["Й"]="Q",["Ц"]="W",["У"]="E",["К"]="R",["Е"]="T",["Н"]="Y",
  ["Г"]="U",["Ш"]="I",["Щ"]="O",["З"]="P",["Х"]="[",["Ъ"]="]",["Ф"]="A",["Ы"]="S",["В"]="D",["А"]="F",["П"]="G",["Р"]="H",["О"]="J",["Л"]="K",
  ["Д"]="L",["Ж"]=";",["Э"]="'",["Я"]="Z",["Ч"]="X",["С"]="C",["М"]="V",["И"]="B",["Т"]="N",["Ь"]="M",["Б"]=",",["Ю"]=".",
}
local Guids = {
  LuaMacro = win.Uuid("4EBBEFC8-2084-4B7F-94C0-692CE136894D"); -- guid LuaMacro
  SaveMacro   = "2F17BA22-2438-4D7C-AF5C-A838CD023608",
  GoToMacro   = "97ADF907-40BC-4FF5-945F-ABF69687C848",
  MenuMacro   = "33668CB0-4F8F-4F85-98E4-B47B949E1D4B",
  QSMenuMacro = "FF47C3A8-42B5-4817-9AB5-051155BD0716",
  PlugMenu    = "7CD7B065-FC92-4859-AFB1-F042485542B5",
  Menu        = win.Uuid("0E0B4A2B-BC1F-44D4-A986-C24E48142955"),
  diEdit      = win.Uuid("6BDD26FF-1D69-492C-A023-94B9AFF58F0F"),
  Config      = win.Uuid("CF79A927-A0B9-4B13-9DEB-A39E2DAA7CC6"),
}
local PathName = debug.getinfo(function()end).source:match("^@?([^@].*)%.[^%.\\]+$") -- путь и имя без расширения
local LMBuild = far.GetPluginInformation(far.FindPlugin(F.PFM_GUID,Guids.LuaMacro)).GInfo.Version[4] -- запомним версию LuaMacro
local PanelColor = far.AdvControl(F.ACTL_GETCOLOR,far.Colors.COL_PANELBOX) -- цвет панели
local Def = { -- настройки по умолчанию
  UseLocal = 1, -- использовать локальные закладки
  UseGlobal = 1, -- использовать глобальные закладки
  DefBMProfile = F.PSL_LOCAL, -- место хранения закладок по умолчанию
  UseEnv = 1, -- использовать переменные окружения
  ShowEnv = 1, -- показывать переменные окружения в меню
  ExtMask = 1, -- использовать "слабые совпадения" (дополнять имя папки '*')
  MenuForOne = 1, -- при неполном совпадении имени закладки выводить меню даже для одного элемента
  SeqColor = band(PanelColor.ForegroundColor,0x0f)*0x10+band(PanelColor.BackgroundColor,0x0f), -- цвет сообщения о набираемой последовательности
  SeqLine = 0, -- строка сообщения о набираемой последовательности
  GoToMessDelay = 1000, -- длительность показа сообщения о смене папки
  SaveMessDelay = 500, -- длительность показа сообщения о сохранении закладки
}
local OneProfile = win.GetEnv("FARLOCALPROFILE")==win.GetEnv("FARPROFILE") -- локальные и глобальные настройки в одном профиле
-- +
--[[переменные]]
-- -
local L,LT,S,InProcess,UsedProfile -- язык, настройки, признак обработки нажатой клавиатурной комбинации, откуда загрузили настройки
local function _f() return setmetatable({},{__index=_f,__tostring=function() return "TmpPanel: Cannot find language file" end}) end -- функция-затычка
L = setmetatable({},{__index=function(_,idx) -- языковые данные, меняющиеся при смене языка, да ещё с затычкой
  local FL = Far.GetConfig("Language.Main"):sub(1,3) if LT and LT.Lang==FL then return LT[idx] end  -- язык; совпадает - вернём требуемое
  local LF = loadfile(PathName..FL..".lng") or loadfile(PathName.."Eng.lng") -- функция, возвращающая содержимое языкового файла
  if LF then LT = LF() return LT[idx] else return _f() end end}) -- вернём из найденного или затычку
--------------------------------------------------------------------------------
-- +
--[=[вспомогательные функции]=]
-- -
local LoadSettings,SaveSettings,InputSeq,GoToObject,GiveBack,BM2str,BM2tbl,NiceFolder,ReadBM,WriteBM,DelBM,ShowHelp,ErrMess
--
function LoadSettings(ForceDef) --[[загрузить настройки из БД]]
UsedProfile = nfo.options.DefProfile -- запомним профиль
local obj = far.CreateSettings(nil,UsedProfile) -- откроем предпочтительные настройки
local key = obj:OpenSubkey(obj:OpenSubkey(0,Author) or 0,ConfPart) -- есть раздел?
if not key then -- настроек нет?
  obj:Free() obj = far.CreateSettings(nil,UsedProfile==F.PSL_LOCAL and F.PSL_ROAMING or F.PSL_LOCAL) -- откроем другие настройки
  key = obj:OpenSubkey(obj:OpenSubkey(0,Author) or 0,ConfPart) -- есть раздел?
  if key then UsedProfile = UsedProfile==F.PSL_LOCAL and F.PSL_ROAMING or F.PSL_LOCAL end -- из другого профиля открылись? запомним профиль
end
local function L1(n) return not ForceDef and obj:Get(key or -1,n,type(Def[n])=="string" and F.FST_STRING or F.FST_QWORD) or Def[n] end
S = { UseLocal = L1("UseLocal")~=0 and F.PSL_LOCAL,UseGlobal = L1("UseGlobal")~=0 and F.PSL_ROAMING,DefBMProfile = L1("DefBMProfile"),
      UseEnv = L1("UseEnv")~=0,ShowEnv = L1("ShowEnv")~=0,ExtMask = L1("ExtMask")~=0,MenuForOne = L1("MenuForOne")~=0,
      SeqColor = L1("SeqColor"),SeqLine = L1("SeqLine"),GoToMessDelay = L1("GoToMessDelay"),SaveMessDelay = L1("SaveMessDelay")}
obj:Free() -- приберёмся
if OneProfile then S.UseLocal = nil S.DefBMProfile = F.PSL_ROAMING end
end -- LoadSettings
--
function SaveSettings() --[[сохранить настройки в БД]]
if UsedProfile==F.PSL_LOCAL then win.CreateDir(win.GetEnv("FARLOCALPROFILE").."\\PluginsData") end -- создадим папку для локальных настроек, если надо
local obj = far.CreateSettings(nil,UsedProfile) -- откроем ранее прочитанные или предпочтительные настройки
local key = obj:CreateSubkey(obj:CreateSubkey(0,Author),ConfPart) -- откроем/создадим раздел
local function S1(n,v) if v==nil then v=S[n] end; if v==nil then obj:Delete(key,n) else local w,t = v==true and 1 or v or 0,
                       type(v)=="string" and F.FST_STRING or F.FST_QWORD; if obj:Get(key,n,t)~=w then obj:Set(key,n,t,w) end end end
S1("UseLocal",not not S.UseLocal) S1("UseGlobal",not not S.UseGlobal) S1("DefBMProfile") S1("UseEnv") S1("ShowEnv")
S1("ExtMask") S1("MenuForOne") S1("SeqColor") S1("SeqLine") S1("GoToMessDelay") S1("SaveMessDelay")
obj:Free() -- приберёмся
end -- SaveSettings
--
function InputSeq() --[[ввести последовательность клавиш]]
local nstr,mod,seq = S.SeqLine<0 and Far.Height+S.SeqLine or S.SeqLine,akey(1,1):match("^(.*)(.)$") -- первый из символов
repeat -- Обработаем очередное нажатие
  local key = mf.waitkey(10):sub(mod:len()+1) -- введём клавишу
  if key:len()<2 then -- нормальная клавиша?
    seq = seq..key -- добавим к последовательности
    if S.SeqColor~=0 then far.Text((Far.Width-seq:len()-L.Seq:len())/2,nstr,S.SeqColor,L.Seq..seq.." ") far.Text() end
  else -- нет - считаем, что эту последовательность надо отдать Far-у
    return GiveBack(mod,seq,key) -- вернём клавиши обратно и выйдем
  end
until band(Mouse.LastCtrlState,0x15)==0 -- повторяем, пока нажаты RCtrl+Shift/RAlt
panel.RedrawPanel(nil,1) panel.RedrawPanel(nil,0) return seq,mod
end -- InputSeq
--
function GoToObject(folder,delay,trail) --[[перейти в указанную папку]]
local LP,RP,Top
for _,v in ipairs(folder) do
  if Drv.ShowPos==1 or v.Panel=="<L>" then LP = v -- левая панель
  elseif Drv.ShowPos==2 or v.Panel=="<R>" then RP = v -- правая панель
  elseif v.Panel=="<A>" or v.Panel=="" then if APanel.Left then LP = v else RP = v end -- активная панель
  elseif v.Panel=="<P>" or v.Panel=="<>" then if APanel.Left then RP = v else LP = v end end -- пассивная панель
end
for _,p in ipairs(far.GetPlugins()) do -- получим id плагина по названию
  local pinfo = far.GetPluginInformation(p)
  if LP and pinfo and pinfo.GInfo.Title==LP.Plugin then LP.id = pinfo.GInfo.Guid end
  if RP and pinfo and pinfo.GInfo.Title==RP.Plugin then RP.id = pinfo.GInfo.Guid end
end
for LR,Pnl in pairs({[0]=LP,[1]=RP}) do -- переберём панели (если есть)
  Top,Pnl.Folder,trail = Pnl.Folder..(trail or""),Pnl.Folder:gsub("%%(.-)%%",win.GetEnv),(trail or""):gsub("%%(.-)%%",win.GetEnv) -- запомним,раскроем
  if not Pnl.id then -- реальная файловая панель?
    local List = {} -- главный список вариантов
    for p in Pnl.Folder:gmatch("[^;]+") do -- поделим по ";"
      local Path,L1,Root,Rest = p..trail,{} -- путь поиска, список результатов одной части, корень пути, всё, кроме корня
      if Path:match([[^[A-Za-z*]:]]) then Root,Rest = Path:upper():match([[^(.):\*(.*)$]]) -- имя диска в стиле Windows? достанем, запомним остаток
        for d in ("ABCDEFGHIJKLMNOPQRSTUVWXYZ"):gmatch(".") do if d:match(Root) or Root=="*" then L1[#L1+1] = d..[[:\]] end end -- раскроем корень
      elseif Path:match([[^\\]]) then L1[1],Rest = Path:match([[^(\\[^\]+\[^\]+\?)(.*)$]]) -- имя сетевой папки? достанем, запомним остаток
      else ErrMess(L.BadBMValue..":\n"..Path,L.Hdr) return end -- выведем сообщение об ошибке
      for s in Rest:gsub([[\+]],[[\]]):gmatch([[[^\]+]]) do -- разберём остаток
        local tmp = {} -- новый список
        for _,path in ipairs(L1) do -- для каждого элемента списка
          if s=='..' then
            tmp[#tmp+1] = path:match([[^(.+)\]]) -- ".."? просто возвращаем то же самое без последнего каталога
          else
            local ff local function AddOne(_,fn) tmp[#tmp+1] = fn ff = true end -- признак нахождения; функция добавления найденных
            far.RecursiveSearch(path,s,AddOne) -- попробуем добавить просто так
            if not ff and S.ExtMask and not s:match('[*?]') then far.RecursiveSearch(path, '*'..s..'*',AddOne) end -- поищем, как маску
            if not ff and win.GetFileAttr(path.."\\"..s) then tmp[#tmp+1] = path.."\\"..s end -- поищем, как есть (надо для коротких имён)
          end
        end
        L1 = tmp -- сделаем новый список основным
      end
      for _,p1 in ipairs(L1) do List[#List+1] = p1 end -- допишем полученные варианты в главный список
    end -- раскроем все варианты
    if #List==1 and(win.GetFileAttr(List[1]):match("d") or Pnl.Cmd~="") then -- единственный элемент, каталог или действие указано?
      Pnl.Folder = List[1] -- просто запомним его
    elseif #List>0 then -- список не пустой
      local items,ff,res,pos = {} -- элементы меню, признак наличия файла в списке, результат вызова меню, позиция элемента в меню
      for _,v in ipairs(List) do local d = (win.GetFileAttr(v)or""):match('d') ff = ff or not d items[#items+1] = {text=v,checked=d and "↓"} end
      table.sort(items,function(a,b) return (a.checked and "D" or "F")..a.text<(b.checked and "D" or "F")..b.text end) -- отсортируем список
      local Bottom = "Enter, Esc"..(Pnl.Cmd:find("[CE]")and""or", ShiftEnter")..((not ff or Pnl.Cmd:find("[CX]"))and""or", F4")
      local BK = {{BreakKey="RETURN",cmd=Pnl.Cmd},
                  not Pnl.Cmd:find("[CE]") and {BreakKey="S+RETURN",cmd="X"},ff and not Pnl.Cmd:find("[CX]") and {BreakKey="F4",cmd="E"}}
      res,pos = far.Menu({Title=Top,Bottom=Bottom},items,BK) -- спросим
      if not pos then return end -- Esc - выйдем
      Pnl.Folder,Pnl.Cmd = items[pos].text,res.cmd
    else return end -- список пуст
  end -- not Pnl.id
  if Pnl.Cmd:find("[XE]") then
    win.ShellExecute(nil,Pnl.Cmd=="X" and "open" or "edit",Pnl.Folder) return -- запустить/редактировать - передать в систему
  else
    if not Pnl.id and not win.GetFileAttr(Pnl.Folder):match('d') then Pnl.Folder,Pnl.FN = Pnl.Folder:match([[^(.-)([^\]*)$]]) end -- файл? поделим
    local AP = APanel.Left and 1-LR or LR -- вычислим признак, для активной или пассивной панели меняем
    local cd = panel.SetPanelDirectory(nil,AP,{PluginId=Pnl.id,File=Pnl.File,Name=Pnl.Folder,Param=Pnl.Param}) -- сменим каталог
    if cd and (Pnl.Cmd=="C") and AP==0 then cd = panel.SetActivePanel(nil,0) end -- если данную пассивную панель надо сделать активной, сделаем
    if cd and Pnl.FN then Panel.SetPos(Pnl.Cmd=="C" and 0 or 1-AP,Pnl.FN) end -- если надо позиционироваться на файле, сделаем
  end
end
if delay>=0 then -- надо вывести сообщение?
  local h = far.SaveScreen() -- сохраним экран
  far.Message(NiceFolder({LP,RP}),"","") local key = mf.waitkey(delay) -- выведем сообщение и подождём
  far.RestoreScreen(h) -- восстановим экран
  if key~="" then GiveBack("","",key) end -- задержка прервана нажатием клавиши? вернём клавишу обратно
end
end -- GoToObject
--
function GiveBack(mod,seq,x) --[[Вернуть клавиши в Far]]
InProcess = true -- запретим повторный вызов
for c in seq:gmatch(".") do if eval(mod..c,2)<0 then Keys(mod..c) end end -- для каждой ранее нажатой клавиши симулируем нажатие mod+эта клавиша
if x then if eval(mod..x,2)<0 then Keys(mod..x) end end -- симулируем нажатие mod+эта клавиша для последней (прервавшей скрипт)
InProcess = false -- разрешим вызов снова
end -- GiveBack
--
function BM2str(folder) --[[Преобразовать значение закладки в строку]]
if type(folder)=="string" then return folder end -- если уже, то и вернём сразу
local s = "" for _,f in pairs(folder) do
  local PC = f.Panel:match("<?([^>]*)>?")..f.Cmd s = s..(PC~="" and("<"..PC..">") or f.Panel)..f.Plugin.."|"..f.File.."|"..f.Folder.."|"..f.Param
end return s
end -- BM2str
--
function BM2tbl(folder,bm,lg) --[[Преобразовать значение закладки в таблицу]]
if type(folder)=="table" then return folder end -- если уже, то и вернём сразу
local t,e = {},folder=="" and {f="",e="Z"} or {}
for pf,nf in (folder:gsub("^[^<]","<1>%1"):gsub("^<([CcXxEe]?)>","<1%1>"):gsub("<([CcXxEe]?)>","<2%1>")):gmatch("(%b<>)([^<]*)") do
  local tt,n = {Panel=pf:upper():gsub("[CXE]",""):gsub("<1>",""):gsub("<2>","<>")},nf:gsub("[^|]+",""):len() -- очередная часть, количество "|"
  tt.Cmd = pf:upper():match("<[APLR12]([CXE]?)>") -- признак перехода на эту панель, действие
  if n==0 then tt.Plugin,tt.File,tt.Folder,tt.Param = "","",nf,"" -- если строка не содержит "|", считаем, что это путь
  elseif n==1 then tt.File,tt.Param,tt.Plugin,tt.Folder = "","",nf:match("^([^|]*)|([^|]*)$") -- если "|" один, это плагин и путь
  elseif n==2 then -- если "|" два, нет файла или параметра, или обоих, в середине имя папки или файл, или "||"
    local a = win.GetFileAttr(nf:match("|(.*)|")) -- предположим, что в середине файл и получим его атрибуты
    if a and not a:find("d") or nf:find("||") then -- нет параметра
      tt.Param,tt.Plugin,tt.File,tt.Folder = "",nf:match("^([^|]*)|([^|]*)|([^|]*)$")
    else -- нет файла
      tt.File,tt.Plugin,tt.Folder,tt.Param = "",nf:match("^([^|]*)|([^|]*)|([^|]*)$")
    end
  else tt.Plugin,tt.File,tt.Folder,tt.Param = nf:match("^([^|]*)|([^|]*)|([^|]*)|(.*)$") end -- если "|" больше двух, всё разбирается
  if not pf:find("<[12AaPpLlRr][CcXxEe]?>") then e[#e+1] = {f=pf..nf,e="P"} elseif tt.Folder=="" then e[#e+1] = {f=pf..nf,e="F"} else t[#t+1] = tt end
end
if #e>0 then
  local s,sp = (L.BadBM1:format((OneProfile or not lg) and L.BMUndef or lg==F.PSL_LOCAL and L.BMLocal or L.BMGlobal,bm)) sp = (" "):rep(s:len())
  for i,v in ipairs(e) do s = s..(i>1 and sp or "")..L["BadBM"..v.e.."Fmt"]:format(v.f:gsub("<1>",""):gsub("<2>","<>"))..(i<#e and "\n" or "") end
  ErrMess(s,L.Hdr)
end
return t,#e>0 and e or nil
end -- BM2tbl
--
function NiceFolder(folder) --[[Красивая строка папки]]
return BM2str(BM2tbl(folder)):gsub("([^|<>]*|[^|<>]*|[^|<>]*)|[^|<>]*","%1"):gsub("|*(%b<>)|*","%1"):gsub("^|+",""):gsub("|+$",""):gsub("|+",":")
end -- NiceFolder
--
function ReadBM(bm,lg)
local folder,err = {}
if not lg then -- профиль не указан явно?
  lg = S.UseLocal and S.UseGlobal and S.DefBMProfile or S.UseLocal or S.UseGlobal -- вычислим предпочтительный
  if lg then folder,err = ReadBM(bm,lg) else return end -- есть - прочитаем из него, иначе скажем, что нет
  if folder or err then return folder,err end -- если закладка обнаружена, или ошибка при конвертации, то вернём, что получили
  lg = lg==S.UseLocal and S.UseGlobal or S.UseLocal -- другой вариант расположения?
  if lg then return ReadBM(bm,lg) else return end -- если есть, вернём его, иначе ничего
end
local obj = far.CreateSettings(nil,lg) -- откроем нужный профиль
local key = obj:OpenSubkey(obj:OpenSubkey(0,Author) or 0,KeysPart) -- раздел
if key then -- есть раздел?
  local f = obj:Get(key,bm,F.FST_STRING) -- старый формат?
  if f then folder,err = BM2tbl(f,bm,lg) else
    key = obj:OpenSubkey(key,bm) -- закладка
    local t = key and obj:Enum(key) or {} -- если есть - прочитаем содержимое, иначе сделаем пустой список
    for i,v in ipairs(t) do
      local subkey = obj:OpenSubkey(key,v.Name)
      folder[i] = {CD = obj:Get(subkey,"CD",F.FST_QWORD)==1,Panel = obj:Get(subkey,"Panel",F.FST_STRING),File = obj:Get(subkey,"File",F.FST_STRING),
        Plugin = obj:Get(subkey,"Plugin",F.FST_STRING),Folder = obj:Get(subkey,"Folder",F.FST_STRING),Param = obj:Get(subkey,"Param",F.FST_STRING)}
      folder[i].Cmd = folder[i].CD and "C" or obj:Get(subkey,"Cmd",F.FST_STRING) or ""
    end
  end
end
obj:Free() return #folder>0 and folder or nil,err
end -- ReadBM
--
function WriteBM(bm,folder,lg)
DelBM(bm,lg) -- удалим старое значение, чтобы не наложилось одно на другое
local obj = far.CreateSettings(nil,lg) -- откроем профиль
local key = obj:CreateSubkey(obj:CreateSubkey(0,Author),KeysPart) -- откроем/создадим раздел
key = obj:CreateSubkey(key,bm) -- сохраним закладку
for i,v in ipairs(folder) do -- сохраним закладку
  local subkey = obj:CreateSubkey(key,tostring(i))
  obj:Set(subkey,"Panel",F.FST_STRING,v.Panel) obj:Set(subkey,"Cmd",F.FST_STRING,v.Cmd) obj:Set(subkey,"Plugin",F.FST_STRING,v.Plugin)
  obj:Set(subkey,"File",F.FST_STRING,v.File) obj:Set(subkey,"Folder",F.FST_STRING,v.Folder) obj:Set(subkey,"Param",F.FST_STRING,v.Param)
end
obj:Free()
end -- WriteBM
--
function DelBM(bm,lg,confirm)--[=[Удалить закладку]=]
local folder = ReadBM(bm,lg) -- достанем значение закладки; если нет - отрапортуем (если надо) и уйдём
if not folder and confirm then ErrMess(L.BadBM:format((OneProfile or not lg) and L.BMUndef or lg==F.PSL_LOCAL and L.BMLocal or L.BMGlobal,bm),L.Hdr)
                               return end
if confirm and far.Message(L.DeleteBM:format((OneProfile or not lg) and L.BMUndef or lg==F.PSL_LOCAL and L.BMLocal or L.BMGlobal,
                                             bm,NiceFolder(folder)),L.Hdr,";OkCancel")~=1 then
  return -- если нужно подтверждение, и отказались, ничего не делаем
end
local obj = far.CreateSettings(nil,lg) -- считаем из локального профиля
local key = obj:OpenSubkey(obj:OpenSubkey(0,Author) or 0,KeysPart) -- раздел
if key then -- есть раздел?
  if obj:Get(key,bm,F.FST_STRING) then obj:Delete(key,bm) -- удалим, если старый формат
  else  key = obj:OpenSubkey(key,bm) if key then obj:Delete(key) end end -- удалим закладку нового типа
end
obj:Free()
end -- DelBM
--
function ShowHelp(text) --[[Вывести справку]]
local HL = Far.GetConfig("Language.Help"):sub(1,3) -- язык (первые 3 буквы)
far.ShowHelp(PathName..(win.GetFileAttr(PathName..HL..".hlf") and HL or "Eng")..".hlf",text,F.FHELP_CUSTOMFILE) -- выведем
end -- ShowHelp
--
if type(nfo)=="table" then nfo.help = function() ShowHelp() end end
--
function ErrMess(msg,ttl) far.Message(msg,ttl or nfo.name,";Ok","wl") end --[[вывести сообщение об ошибке]]
--------------------------------------------------------------------------------
-- +
--[==[Основные функции]==]
-- -
local BMSave,BMGoTo,BMEdit,Config,BMMenu,QSMenu,CLProc
-- +
--[=[Сохранить текущую папку в указанной закладке]=]
-- -
function BMSave(bm,folder,lg)
local mod -- папка, последовательность символов для закладки, нажатые модификаторы, очередная клавиша
if not bm then bm,mod = InputSeq() end -- имя не - введём
if not folder then -- папка не задана?
  local function PluginByID(id) return id~=("\000"):rep(16) and far.GetPluginInformation(far.FindPlugin(F.PFM_GUID,id)).GInfo.Title or "" end
  local t = panel.GetPanelDirectory(nil,1) -- папка на активной панели
  folder = {{Panel="<A>",Cmd="",Plugin=PluginByID(t.PluginId),File=t.File,Folder=t.Name,Param=t.Param}}
  if mod=="RCtrlRAlt" then -- RCtrlRAlt?
    t = panel.GetPanelDirectory(nil,0) -- папка на пассивной панели
    folder[2] = {Panel="<P>",Cmd="",Plugin=PluginByID(t.PluginId),File=t.File,Folder=t.Name,Param=t.Param}
  end
end
lg = lg or (S.UseLocal and S.UseGlobal and S.DefBMProfile or S.UseLocal or S.UseGlobal) -- профиль
local of = ReadBM(bm,lg) -- старое значение для закладки, если есть
if of then -- такая закладка уже есть, менять?
  if far.Message((L.BadBM1..L.ReplaceBM):format(OneProfile and L.BMUndef or lg==F.PSL_LOCAL and L.BMLocal or L.BMGlobal,
    bm,NiceFolder(of),NiceFolder(folder)),L.SaveHdr,";YesNo")==1 then of = nil end -- запомним, что старой нет
end
if not of then -- старой нет, сохраняем
  WriteBM(bm,folder,lg) -- сохраним закладку
  if S.SaveMessDelay>=0 then
    local h = far.SaveScreen() -- сохраним экран
    far.Message(L.SaveMess:format(bm,NiceFolder(folder)),"","") mf.waitkey(S.SaveMessDelay) -- выведем сообщение и подождём
    far.RestoreScreen(h) -- восстановим экран
  end
end
end -- BMSave
-- +
--[=[Перейти на закладку]=]
-- -
function BMGoTo(sq,pref,trail)
local seq,folder,fl,fg,fe,err -- последовательность символов для закладки, очередная клавиша, папка, папки, ошибка
if sq then seq = sq else seq = InputSeq() end -- имя задано? будем использовать его. если не задано - введём
if S.UseLocal then fl,err = ReadBM(seq,F.PSL_LOCAL) end -- локальная закладка с этим именем
if S.UseGlobal then fg,err = ReadBM(seq,F.PSL_ROAMING) end -- глобальная закладка с этим именем
if S.UseEnv then fe = win.GetEnv(seq) fe = fe and {{Panel="",Cmd="",Plugin="",File="",Folder=fe,Param=""}} end -- и переменная окружения
folder = fl and fg and S.DefBMProfile==S.UseLocal and fl or fg or fl -- выберем правильный каталог
folder = folder or fe -- если нет закладки, используем переменную окружения
if folder then GoToObject(folder,S.GoToMessDelay,trail) -- есть такая закладка? - перейдём
elseif seq:match("^%d$") or (not err and not BMMenu(seq,trail)) then -- нет такой закладки и нет подходящих по шаблону
  if pref then ErrMess(L.BadBM:format(L.BMUndef,sq),L.Hdr) else GiveBack("RCtrl",seq) end -- выведем сообщение об ошибке или вернём клавиши обратно
end
end -- BMGoTo
-- +
--[=[Редактировать закладку в диалоге]=]
-- -
function BMEdit(bm,folder,lg,move)
--
local Hdr = not bm and L.diEdit.HdrNew or move and L.diEdit.Hdr or L.diEdit.HdrCopy -- выберем заголовок
local w = math.max(math.min((BM2str(folder) or ""):len(),Far.Width-17),34) -- отрегулируем ширину окна
--
local function DlgProc (hDlg,Msg,Param1,Param2) -- обработка событий диалога
if Msg==F.DN_EDITCHANGE and Param1==3 then -- изменение поля bookmark
  far.SendDlgMessage(hDlg,F.DM_SETTEXT,Param1,Param2[10]:upper():gsub(".",ToCtrl)) -- поднимем регистр, исправим символы на допустимые
elseif Msg==F.DN_CONTROLINPUT and (Param2.VirtualKeyCode==0x70 and band(Param2.ControlKeyState,0x1f)==0) then -- F1
  return true,ShowHelp("Edit")
end
end
--
local form = { -- диалог редактирования
--[[01]] {F.DI_DOUBLEBOX,   3, 1,w+17, 7,0,0,0,0,Hdr},
--[[02]] {F.DI_TEXT,        5, 2,   0, 2,0,0,0,0,L.diEdit.BM},
--[[03]] {F.DI_EDIT,       15, 2,w+15, 2,0,0,0,0,bm},
--[[04]] {F.DI_TEXT,        5, 3,   0, 3,0,0,0,0,L.diEdit.Folder},
--[[05]] {F.DI_EDIT,       15, 3,w+15, 3,0,0,0,0,BM2str(folder)},
--[[06]] OneProfile
     and {F.DI_TEXT,        5, 2, 0, 2,0,0,0,0,""}
      or {F.DI_RADIOBUTTON, 5, 4,   0, 4,lg==F.PSL_LOCAL and 1 or 0,0,0,
                           (S.UseLocal and F.DIF_GROUP or F.DIF_DISABLE)+F.DIF_CENTERGROUP,L.diEdit.LocalBM},
--[[07]] OneProfile
     and {F.DI_TEXT,        5, 2, 0, 2,0,0,0,0,""}
      or {F.DI_RADIOBUTTON,27, 4,   0, 4,lg==F.PSL_LOCAL and 0 or 1,0,0,
                           (S.UseGlobal and 0 or F.DIF_DISABLE)+F.DIF_CENTERGROUP,L.diEdit.GlobalBM},
--[[08]] {F.DI_TEXT,       -1, 5,   0, 5,0,0,0,F.DIF_SEPARATOR,""},
--[[09]] {F.DI_BUTTON,      0, 6,   0, 6,0,0,0,F.DIF_DEFAULTBUTTON+F.DIF_CENTERGROUP,L.OK},
--[[10]] {F.DI_BUTTON,      0, 6,   0, 6,0,0,0,F.DIF_CENTERGROUP,L.Cancel},
}
-- начало тела функции BMEdit
if type(lg)~="number" or far.Dialog(Guids.diEdit,-1,-1,w+21,9,nil,form,nil,DlgProc)~=9 then return end -- вызовем диалог, не "ОК" - уйдём
local newbm,newfolder,newlg,err = form[3][10],form[5][10],form[6][6]==1 and F.PSL_LOCAL or F.PSL_ROAMING
newfolder,err = BM2tbl(newfolder,newbm,newlg) -- преобразуем в таблицу и получим список некорректных элементов
if newbm~="" then -- если имя закладки не пустое - работаем
  local of = ReadBM(newbm,newlg)
  if #newfolder==0 then -- папка пустая?
    if of and not err then DelBM(newbm,newlg,true) end -- если закладка с новым именем уже была и не было ошибок в новой - удалим
  else -- папка не пустая
    if (lg~=newlg or bm~=newbm) and of and far.Message((L.BadBM1..L.ReplaceBM):format(
        OneProfile and L.BMUndef or newlg==F.PSL_LOCAL and L.BMLocal or L.BMGlobal,newbm,NiceFolder(of),NiceFolder(newfolder)),Hdr,";YesNo")~=1 then
      return
    end -- сменили имя или размещение закладки (или новая), такая закладка есть, и мы не хотим её заменять? ничего не делаем, уйдём
    if move then DelBM(bm,lg) end -- удалим старую, если перенос, а не копирование
    WriteBM(newbm,newfolder,newlg) -- сохраним закладку
  end
end
end -- BMEdit
-- +
--[==[Настройка конфигурации]==]
-- -
function Config()
--
local TmpColor,ov = S.SeqColor
--
local function cDlgProc (hDlg,Msg,Param1,Param2) -- обработка событий диалога
if Msg==F.DN_HOTKEY and Param1==4 then -- Предпочтительное место хранения закладок?
  far.SendDlgMessage(hDlg,"DM_SETCHECK",far.SendDlgMessage(hDlg,"DM_GETCHECK",5)==F.BSTATE_CHECKED and 6 or 5,F.BSTATE_CHECKED)
elseif Msg==F.DN_BTNCLICK and Param1==7 then -- переключение работы с переменными окружения?
  hDlg:send(F.DM_SHOWITEM,Param1+1,Param2) -- установим видимость зависимого чекбокса
elseif Msg==F.DN_BTNCLICK and Param1==11 then -- нажали кнопку выбора цвета подсказки?
  TmpColor = math.fmod(far.ColorDialog(TmpColor) or TmpColor,0x100) -- выберем новый или сохраним старый
elseif Msg==F.DN_GOTFOCUS and (Param1==14 or Param1==16 or Param1==18) then -- вошли в di_edit?
  ov = far.SendDlgMessage(hDlg,"DM_GETTEXT",Param1) -- запомним старое значение
elseif Msg==F.DN_KILLFOCUS and (Param1==14 or Param1==16 or Param1==18) then -- покидаем di_edit?
  local nv = tonumber(far.SendDlgMessage(hDlg,"DM_GETTEXT",Param1)) -- новое значение
  if not nv then far.SendDlgMessage(hDlg,"DM_SETTEXT",Param1,ov) end -- не число - откатим
elseif (Msg==F.DN_CONTROLINPUT and (Param2.VirtualKeyCode==0x70 and band(Param2.ControlKeyState,0x1f)==0))or(Msg==F.DN_BTNCLICK and Param1==23) then
  ShowHelp("Config")
elseif Msg==F.DN_CONTROLINPUT and (Param2.VirtualKeyCode==0x0d and band(Param2.ControlKeyState,0x1f)==0x10) then -- ShiftEnter
  far.SendDlgMessage(hDlg,"DM_CLOSE",21) -- закроем диалог
elseif Msg==F.DN_CLOSE then
  far.SendDlgMessage(hDlg,"DM_SETFOCUS",2) -- переключимся на чекбокс
end
local rect = hDlg:send(F.DM_GETDLGRECT,0) -- окно диалога
if TmpColor~=0 then far.Text() far.Text(rect.Left+45,rect.Top+9,TmpColor,L.diConf.ColorSample) else hDlg:send(F.DM_REDRAW) end -- пример подсказки
end
--
local Items = { -- диалог настройки конфигурации
--[[01]] {F.DI_DOUBLEBOX,   3, 1,74,15,0,0,0,0,L.Hdr},
--[[02]] OneProfile
     and {F.DI_TEXT,        5, 2, 0, 2,0,0,0,0,""}
      or {F.DI_CHECKBOX,    5, 2, 0, 2,S.UseLocal and 1 or 0,0,0,0,L.diConf.LocalBM},
--[[03]] {F.DI_CHECKBOX,    5, 3, 0, 3,S.UseGlobal and 1 or 0,0,0,0,OneProfile and L.diConf.AllBM or L.diConf.GlobalBM},
--[[04]] OneProfile
     and {F.DI_TEXT,        5, 2, 0, 2,0,0,0,0,""}
      or {F.DI_TEXT,        5, 4, 0, 4,0,0,0,0,L.diConf.DefBMProfile},
--[[05]] OneProfile
     and {F.DI_TEXT,        5, 2, 0, 2,0,0,0,0,""}
      or {F.DI_RADIOBUTTON,45, 4, 0, 4,S.DefBMProfile==F.PSL_LOCAL and 1 or 0,0,0,0,L.diConf.UseLocal},
--[[06]] OneProfile
     and {F.DI_TEXT,        5, 2, 0, 2,0,0,0,0,""}
      or {F.DI_RADIOBUTTON,59, 4, 0, 4,S.DefBMProfile==F.PSL_ROAMING and 1 or 0,0,0,0,L.diConf.UseGlobal},
--[[07]] {F.DI_CHECKBOX,    5, 5, 0, 4,S.UseEnv and 1 or 0,0,0,0,L.diConf.EnvBM},
--[[08]] {F.DI_CHECKBOX,    9, 6, 0, 6,S.ShowEnv and 1 or 0,0,0,S.UseEnv and 0 or F.DIF_HIDDEN,L.diConf.ShowEnv},
--[[09]] {F.DI_CHECKBOX,    5, 7, 0, 7,S.ExtMask and 1 or 0,0,0,0,L.diConf.ExtMask},
--[[10]] {F.DI_CHECKBOX,    5, 8, 0, 8,S.MenuForOne and 1 or 0,0,0,0,L.diConf.MenuForOne},
--[[11]] {F.DI_BUTTON,      7, 9, 0, 9,0,0,0,F.DIF_BTNNOCLOSE,L.diConf.SeqColor},
--[[12]] {F.DI_TEXT,       45, 9, 0, 9,0,0,0,0,L.diConf.NoHint},
--[[13]] {F.DI_TEXT,        5,10, 0,10,0,0,0,0,L.diConf.SeqLine},
--[[14]] {F.DI_EDIT,       52,10,57,10,0,0,0,0,S.SeqLine},
--[[15]] {F.DI_TEXT,        5,11, 0,11,0,0,0,0,L.diConf.GoToDelay},
--[[16]] {F.DI_EDIT,       52,11,57,11,0,0,0,0,S.GoToMessDelay},
--[[17]] {F.DI_TEXT,        5,12, 0,12,0,0,0,0,L.diConf.SaveDelay},
--[[18]] {F.DI_EDIT,       52,12,57,12,0,0,0,0,S.SaveMessDelay},
--[[19]] {F.DI_TEXT,       -1,13, 0,13,0,0,0,F.DIF_SEPARATOR,""},
--[[20]] {F.DI_BUTTON,      0,14, 0,14,0,0,0,F.DIF_DEFAULTBUTTON+F.DIF_CENTERGROUP,L.Save},
--[[21]] {F.DI_BUTTON,      0,14, 0,14,0,0,0,F.DIF_CENTERGROUP,L.NoSave},
--[[22]] {F.DI_BUTTON,      0,14, 0,14,0,0,0,F.DIF_CENTERGROUP,L.Cancel},
--[[23]] {F.DI_BUTTON,      0,14, 0,14,0,0,0,F.DIF_CENTERGROUP+F.DIF_BTNNOCLOSE,L.BHelp},
}
-- начало кода функции
local res = far.Dialog(Guids.Config,-1,-1,78,17,nil,Items,nil,cDlgProc) -- вызовем диалог
if res~=20 and res~=21 then return end -- не "ОК" - уйдём
S = { UseLocal = Items[2][6]~=0 and F.PSL_LOCAL,UseGlobal = Items[3][6]~=0 and F.PSL_ROAMING,UseEnv = Items[7][6]~=0, -- новые значения
      DefBMProfile = Items[5][6]==1 and F.PSL_LOCAL or F.PSL_ROAMING,ShowEnv = Items[8][6]~=0,ExtMask = Items[9][6]~=0,MenuForOne = Items[10][6]~=0,
      SeqColor = TmpColor,SeqLine = tonumber(Items[14][10]),GoToMessDelay = tonumber(Items[16][10]),SaveMessDelay = tonumber(Items[18][10])}
if res==20 then SaveSettings() end -- сохраним в БД, если надо
end -- Config
--
if type(nfo)=="table" then nfo.config = Config end
-- +
--[=[Меню закладок]=]
-- -
function BMMenu(mask,trail)
--
local function prep_menu(lg) -- подготовить заполнение меню закладками
local maxlen,l = 0,{} -- наибольшая длина имени, данные для заполнения, профиль, раздел, список имён
if lg then -- для закладок
  local obj = far.CreateSettings(nil,lg) -- откроем нужные настройки
  local key = obj:OpenSubkey(obj:OpenSubkey(0,Author) or 0,KeysPart) -- есть раздел?
  l = key and obj:Enum(key) or {} obj:Free()-- если есть - прочитаем содержимое, иначе сделаем пустой список
  for i=1,#l do l[i].Value = ReadBM(l[i].Name,lg) or {} end -- дополним значениями
else -- дёргаем переменные окружения
  local ffi = require "ffi" local C = ffi.C
  ffi.cdef [[wchar_t* GetEnvironmentStringsW(); void FreeEnvironmentStringsW(wchar_t*); size_t wcslen(const wchar_t*);]]
  local env = C.GetEnvironmentStringsW() -- выдернем все переменные окружения в виде последовательности 0-терминированных строк
  local p = env -- указатель на очередную
  while true do -- разберём
    local len = C.wcslen(p) if len==0 then break end -- длина очередной строки; нулевая - закончим
    local s = win.Utf16ToUtf8(ffi.string(ffi.cast("char*",p),2*(len+1))) -- получим очередную строку
    if s:sub(1,1)~="=" then -- закинем каталог в таблицу (кроме "=<диск>=<путь>")
      local n,v = s:match("^(.-)=(.*)$") -- выдернем имя и значение; если существующий каталог - добавим
      if tostring(win.GetFileAttr(v)):find("d") then l[#l+1] = {Name=n,Value={{Panel="",Cmd="",Plugin="",File="",Folder=v,Param=""}}} end
    end
    p = p+len+1 -- указатель на следующую строку
  end
  C.FreeEnvironmentStringsW(env) -- освободим память
end
if l and #l>0 then -- если есть что разбирать
  if lg and Drv.ShowPos~=0 then -- меню дисков, закладки?
    for i=#l,1,-1 do local v = l[i].Value for j=#v,1,-1 do local w = v[j] -- переберём все закладки
      if w.Panel~="" and w.Panel:sub(2,2)~="A" and w.Panel:sub(2,2)~=({"L","R"})[Drv.ShowPos] then table.remove(v,j) end
    end end -- отбросим все, не подходящие по префиксу для данного меню
  end
  if mask then for i=#l,1,-1 do if not l[i].Name:upper():find(mask,1,true) then table.remove(l,i) end end end -- есть маска? отбросим всё лишнее
  table.sort(l,function(a,b) return(a.Name<b.Name) end) -- отсортируем закладки
  for i,v in ipairs(l) do maxlen,l[i].lg = math.max(maxlen,v.Name:len()),lg end -- вычислим максимальную длину имени закладки и запомним профиль
end
return maxlen,l
end
--
local function fill_menu(tbl,title,blen,itms) -- заполнить меню закладками
itms[#itms+1] = {text=title,separator=true} -- подзаголовок
for _,v in ipairs(tbl) do -- сформируем меню
  itms[#itms+1] = {text=v.Name..(" "):rep(blen-v.Name:len()).." │ "..NiceFolder(v.Value),grayed=#v.Value==0,bm=v.Name,folder=v.Value,lg=v.lg}
end
end
-- начало тела функции BMMenu
local Title,Bottom,HotKeys,pos,res = L.Hdr..L.HdrA[Drv.ShowPos],"Enter,Esc,CtrlPgDn,ShiftEnter,ShiftF4,F1,F4,F5,Ins,Del,F9",
  {{BreakKey="C+NEXT"},{BreakKey="C+NUMPAD3"},{BreakKey="S+RETURN"},{BreakKey="S+F4"},{BreakKey="F1"},{BreakKey="F4"},{BreakKey="F5"},
   {BreakKey="F9"},{BreakKey="INSERT"},{BreakKey="NUMPAD0"},{BreakKey="DELETE"},{BreakKey="DECIMAL"}} -- заголовок, подсказка, горячие клавиши...
--
LoadSettings() -- прочитаем настройки
repeat -- начало главного цикла
  local listl,listg,liste,maxl,maxg,maxe,items = {},{},{},0,0,0,{} -- чем заполнять меню, результаты разборки закладок, элементы меню
  if S.UseLocal then maxl,listl = prep_menu(F.PSL_LOCAL) end -- достанем локальные закладки
  if S.UseGlobal then maxg,listg = prep_menu(F.PSL_ROAMING) end -- достанем глобальные закладки
  if S.UseEnv then maxe,liste = prep_menu() end -- достанем переменные окружения
  if #listl>0 then fill_menu(listl,L.LocalBM,math.max(maxl,maxg,maxe),items) end-- заполним меню закладками
  if #listg>0 then fill_menu(listg,OneProfile and L.AllBM or L.GlobalBM,math.max(maxl,maxg,maxe),items) end
  if #liste>0 and (S.ShowEnv or mask) then fill_menu(liste,L.EnvBM,math.max(maxl,maxg,maxe),items) end
  if mask and #items==0 then return false end -- если меню перехода по неполному имени и выводить совсем нечего, закончим и сообщим
  if not S.MenuForOne and #items==2 then -- пункт всего 1 (+заголовок), и не выводить единственный пункт?
    res,pos = items[2],2 -- сразу выберем единственный (как если бы нажали Enter)
  else -- иначе выведем меню
    res,pos = far.Menu({Title=Title,Bottom=Bottom,SelectIndex=pos,Id=Guids.Menu,Flags=F.FMENU_SHOWAMPERSAND+F.FMENU_WRAPMODE},items,HotKeys) -- меню
  end
  if not res then break end -- Esc. "работаем, пока не надоест"? Надоело...
  if res.BreakKey=="F1" then -- F1 - выведем справку
    ShowHelp("Main")
  elseif res.BreakKey=="F4" or res.BreakKey=="F5" then -- редактировать в диалоге?
    BMEdit(items[pos].bm,items[pos].folder,items[pos].lg,res.BreakKey=="F4") -- отредактируем
  elseif res.BreakKey=="INSERT" or res.BreakKey=="NUMPAD0" then -- добавить новый?
    if S.UseLocal or S.UseGlobal then -- есть куда?
      BMEdit(nil,{},S.UseLocal==S.DefBMProfile and S.UseLocal or S.UseGlobal or S.UseLocal) -- добавим
    else
      ErrMess(L.NoLG,L.Hdr) -- всё выключено!
    end
  elseif res.BreakKey=="DELETE" or res.BreakKey=="DECIMAL" then -- удалить текущий?
    DelBM(items[pos].bm,items[pos].lg,true) -- удалим
  elseif res.BreakKey=="F9" then -- конфигурация?
    Config() -- отредактируем
  else -- Enter/CtrlPgDn/ShiftEnter/ShiftF4
    local cmd = (not res.BreakKey and"O")or(res.BreakKey:match("^C")and"")or(res.BreakKey=="S+RETURN"and"X")or(res.BreakKey=="S+F4"and"E")
    for _,v in ipairs(items[pos].folder) do v.Cmd = (cmd=="O")and v.Cmd or cmd end
    GoToObject(items[pos].folder,-1,trail) -- перейдём без задержки на показ новой папки
    break -- закончим на этом
  end
until false -- конец главного цикла
return true -- сработали и закончили
end -- BMMenu
--
if type(nfo)=="table" then nfo.execute = function() BMMenu() end end
-- +
--[=[Быстрый поиск в меню закладок]=]
-- -
function QSMenu()
local seq,key = "",(akey(1,1):gsub("^RCtrl","")) -- последовательность символов для закладки,нажатая клавиша
local bkeys = {Enter=1,NumEnter=1,CtrlPgDn=1,CtrlNum3=1,ShiftEnter=1,ShiftNumEnter=1,ShiftF4=1,F1=1,F4=1,F5=1,F9=1,Ins=1,Num0=1,Del=1,NumDel=1,Esc=0}
repeat -- Обработаем очередное нажатие
  if key=="Home" then
    Menu.Select(seq,1,0) -- перейдём на первый подходящий пункт меню
  elseif key=="End" then
    Keys(key) Menu.Select(seq,1,1) -- перейдём на последний подходящий пункт меню
  elseif key=="Up" then
    Keys(key) if Menu.Select(seq,1,1)==0 then Keys("End") Menu.Select(seq,1,1) end -- перейдём на следующий подходящий пункт меню
  elseif key=="Down" then
    Keys(key) if Menu.Select(seq,1,2)==0 then Keys("Home") Menu.Select(seq,1,2) end -- перейдём на предыдущий подходящий пункт меню
  elseif key:len()==1 then
    seq = seq..key:upper():gsub(".",ToCtrl) -- преобразуем, добавим
    if Menu.Select(seq,1,0)==0 then seq = seq:sub(1,-2) end -- перейдём на подходящий пункт меню
  end
  far.Text((Far.Width-Object.Width)/2+3,(Far.Height-Object.Height)/2,far.AdvControl(F.ACTL_GETCOLOR,far.Colors.COL_MENUTITLE),"["..seq.."]")
  far.Text() -- перерисуем экран
  key = mf.waitkey(10):gsub("^RCtrl","") -- введём клавишу,отрежем "RCtrl", если есть
until bkeys[key] -- повторяем, пока не Esc
if bkeys[key]==1 then Keys(key) end
end -- QSMenu
-- +
--[=[Обработка командной строки]=]
-- -
function CLProc(pref,line)
LoadSettings()
local p13,p4,bm,folder,trail = (pref or ""):sub(1,3),(pref or ""):sub(4),(line or ""):match("^(%S*)%s*(.*)$") -- функция,профиль,закладка,папка/и
if pref=="bm" then bm,trail = (line or ""):match("^([^\\]*)(.-)$") end -- для перехода формат и содержание строки другие
if OneProfile then p4 = "" end -- для единого профиля нет различия на локальные и глобальные закладки/
local lg = p4=="l" and F.PSL_LOCAL or p4=="g" and F.PSL_ROAMING or S.UseLocal and S.UseGlobal and S.DefBMProfile or S.UseLocal or S.UseGlobal--профиль
if not lg and p13~="bm" then return end -- если профиль не задан явно, все закладки отключены, и это не переход, выйдем
bm = bm:upper():gsub(".",ToCtrl) -- преобразуем закладку к виду, вводимому с Ctrl
if p13=="bm" then -- переход?
  BMGoTo(bm,pref,trail) -- перейдём
elseif p13=="bma" then -- добавление?
  if folder=="" then -- папка не указана?
    ErrMess((L.BadBM1..L.BadBMValue):format(p4=="" and L.BMUndef or lg==F.PSL_LOCAL and L.BMLocal or L.BMGlobal,bm),L.Hdr) -- сообщим об ошибке
  else
    local tfolder = BM2tbl(folder,bm,lg) -- преобразуем в таблицу и получим список некорректных элементов
    if #tfolder>0 then BMSave(bm,tfolder,lg) -- добавим (если есть что)
    else ErrMess((L.BadBM1..L.BadBMZFmt):format(p4=="" and L.BMUndef or lg==F.PSL_LOCAL and L.BMLocal or L.BMGlobal,bm),L.Hdr) end
  end
elseif p13=="bme" then -- изменение?
  BMEdit(bm,folder=="" and ReadBM(bm,p4~="" and lg or nil) or BM2tbl(folder,bm,lg),lg,true) -- подредактируем
elseif p13=="bmr" then -- удаление?
  DelBM(bm,p4~="" and lg or nil,true) -- удалим
end
end -- CLProc
--------------------------------------------------------------------------------
if Macro then
-- +
--[=[Макросы]=]
-- -
  Macro{
    area="Shell"; key="/RCtrl(Shift|RAlt)[^\\/]/"; description=L.SaveDesc; [(LMBuild<579 and "u" or "").."id"]=Guids.SaveMacro;
    condition = function() LoadSettings() return not InProcess and (S.UseLocal or S.UseGlobal) and 55 end; action=function() BMSave() end;
  }
  --
  Macro{
    area="Shell"; key="/RCtrl[^\\/]/"; description=L.GoToDesc; [(LMBuild<579 and "u" or "").."id"]=Guids.GoToMacro;
    condition = function() LoadSettings() return not InProcess and (S.UseLocal or S.UseGlobal or S.UseEnv) and 55 end; action=function() BMGoTo() end;
  }
  --
  Macro{
    area="Shell"; key="RCtrl/"; description=L.MenuDesc; [(LMBuild<579 and "u" or "").."id"]=Guids.MenuMacro;
    condition = function() return not InProcess end; action=function() BMMenu() end;
  }
  Macro{
    area="Menu"; key="/(RCtrl)?[^\\/]/"; description=L.QSMenuDesc; [(LMBuild<579 and "u" or "").."id"]=Guids.QSMenuMacro;
    condition = function() return not InProcess and win.Uuid(Menu.Id)==Guids.Menu end; action=QSMenu;
  }
-- +
--[=[Пункт меню]=]
-- -
  MenuItem {
    description = L.Desc; menu = "Plugins Disks Config"; area = "Shell"; guid = Guids.PlugMenu;
    text = function(menu) return menu=="Config" and L.ConfigDesc or L.MenuDesc end;
    action = function(OpenFrom) if OpenFrom then BMMenu() else Config() end end;
  }
-- +
--[=[Префиксы]=]
-- -
  CommandLine { description = L.Desc; prefixes = "bm"; action = CLProc; }
  CommandLine { description = L.Desc..L.Add; prefixes = "bma:bmal:bmag"; action = CLProc; }
  CommandLine { description = L.Desc..L.Edit; prefixes = "bme:bmel:bmeg"; action = CLProc; }
  CommandLine { description = L.Desc..L.Rem; prefixes = "bmr:bmrl:bmrg"; action = CLProc; }
  CommandLine { description = L.Desc..L.Help; prefixes = "bmhelp"; action = function() ShowHelp("prefix") end; }
else CLProc(...) end -- для вызова как функции
