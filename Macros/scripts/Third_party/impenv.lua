﻿--[[
.Language=Russian,Russian (Русский)
.PluginContents=Import environment
.Options CtrlStartPosChar=§¦


@Contents
$ Import environment — загрузка *.env файлов
 #Функции скрипта#

 • §¦Запуск из командной строки по префиксу #env:#.
   §¦Рекомендуется назначить ассоциацию на #*.env#.
 • §¦При загрузке макросов, может автоматически загружать файл #autoload.env# из
пользовательской директории (см.)
 • §¦Макрос, позволяющий выбрать файл для импорта из списка.
Файлы читаются из пользовательской директории.
   §¦Клавиатурную комбинацию для вызова нужно определить через опцию #macrokey#
(по умолчанию не задана).


 #Пользовательская директория#

 По умолчанию - #%FARPROFILE%\.env#.
Может быть переопределена через опцию #envdir#
(поддерживается cfgscript/~ScriptsBrowser~@https://forum.farmanager.com/viewtopic.php?f=15&t=10418@).
 Если эта директория отсутствует, то ищется директория #.env# рядом со скриптом.

 
 #Командная строка#

 #env:file.env#
   §¦Импорт окружения из заданного файла.

 #env:directory#
   §¦Чтение списка *.env-файлов из заданной директории,
и выбор файла для импорта из списка.

 #env:#
   §¦При запуске без параметров выводится эта справка.

 Примечания:

 • §¦При запуске через префикс имя файла/директории ожидаются без кавычек.
 • §¦Возможен также запуск без установки, через #lua:@@impenv.lua#.
В этом случае кавычки обязательны.
 • §¦Поддерживается также запуск через ~LuaShell~@https://forum.farmanager.com/viewtopic.php?f=15&t=10907@.


 #Формат *.env-файлов#

 #    ##comment#
 #    var=value#
@
--]]

local Info = Info or package.loaded.regscript or function(...) return ... end --luacheck: ignore 113/Info
local nfo = Info { _filename or ...,
  name        = "Import environment";
  description = "Choose / import *.env files";
  version     = "0.1"; --http://semver.org/lang/ru/
  author      = "jd";
  url         = "https://forum.farmanager.com/viewtopic.php?t=13400";
  id          = "D23D1FA0-043F-4B77-84FF-6967F87AF481";

  --disabled    = false;
  options     = {
    envdir = win.GetEnv("FARPROFILE").."\\.env",
    macrokey = "none",
  };
}
if not nfo or nfo.disabled then return end
local O = nfo.options

local set_pattern = "^([^=]+)=(.-)$"
local function importEnv (pathname)
  local fp = assert(io.open(pathname, "r"))
  for line in fp:lines() do
    if line:sub(1,1)~="#" and line~="" then -- skip comments end empty lines
      local var,val = line:match(set_pattern)
      if var then
        if val=="" then val = nil end
        win.SetEnv(var,val)
      else
        fp:close()
        far.Message("Error reading line:\n"..line.."\n\1\n"..pathname, nfo.name, nil, "lw")
        return false
      end
    end
  end
  fp:close()
end

local F = far.Flags
local selfpath = _filename or ...

local function chooseEnv (dir)
  local items = {}
  far.RecursiveSearch(dir, "*.env>>D", function (item, pathname)
    table.insert(items, {
      text = item.FileName,
      pathname = pathname,
    })
    return nil
  end)
  local props = {
    Title="Import env:",
    Bottom="(Ctrl+)Enter, F4, F1",
    Id=win.Uuid("DAF86E93-8153-4C6D-9792-1B6A75520AA8"),
  }
  local bkeys = "CtrlEnter F4 F1"
  repeat
    local item, pos = far.Menu(props, items, bkeys)
    if item then
      local bk = item.BreakKey
      if pos~=0 then
        item = items[pos]
      elseif bk~="F1" then
        bk = ""
      end
      if not bk then
        if importEnv(item.pathname)~=false then
          return
        end
      elseif bk=="CtrlEnter" then
        importEnv(item.pathname)
        item.checked = true
      elseif bk=="F4" then
        if F.EEC_MODIFIED==editor.Editor(item.pathname) then
          item.checked = false
        end
      elseif bk=="F1" then
        far.ShowHelp(selfpath, nil, F.FHELP_CUSTOMFILE)
      end
    end
    props.SelectIndex = pos
  until not item
end

-- .env directory searched in %FARPROFILE% or near the script
local function getEnvDir ()
  for _,dir in ipairs {
    O.envdir,
    selfpath:match"^(.*[\\/])"..".env",
  } do
    local attr = win.GetFileAttr(dir)
    if attr and attr:match("d") then
      return dir
    end
  end
end

local function processPath (pathname)
  if pathname=="" then
    return far.ShowHelp(selfpath, nil, F.FHELP_CUSTOMFILE)
  elseif pathname=="/envdir" then
    local envdir = getEnvDir()
    if envdir then
      chooseEnv(envdir)
    else
      far.Message(".env directory expected in %FARPROFILE% or near the script", nfo.name, nil, "w")
    end
    return
  end
  local attr,err = win.GetFileAttr(pathname)
  if err then
    far.Message(err.."\n\1\n"..pathname, nfo.name, nil, "lw")
    return
  end
  if attr:match("d") then
    chooseEnv(pathname)
  else
    importEnv(pathname)
  end
end

if Macro then
  CommandLine {
    prefixes="env:";
    description="Import environment variables from file";
    action=function(_,cmdline) -- expects no quote marks
      importEnv(cmdline)
    end;
  }
  Macro { description="Choose env file to import";
    area="Common"; key=O.macrokey; -- to be set in options
    id="0E285A94-5672-4191-A667-967A8B29ED59";
    action=function()
      processPath("/envdir")
    end;
  }
  -- autoload env from .env\autoload.env
  local envdir = getEnvDir()
  local file = envdir and envdir.."\\autoload.env"
  if envdir and win.GetFileAttr(file) then
    importEnv(file)
  end
  -- Scripts browser-related routines
  nfo.help = function ()
    far.ShowHelp(selfpath, nil, F.FHELP_CUSTOMFILE)
  end
  nfo.execute = function ()
    processPath("/envdir")
  end
  return
end

if _filename then -- lua:@ or luash:
  processPath(_cmdline or ... or "")
else
  return processPath
end