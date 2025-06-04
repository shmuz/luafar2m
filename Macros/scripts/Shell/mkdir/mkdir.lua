-- Started:    2025-05-25
-- Author:     Shmuel Zeigerman
-- Published:  https://forum.farmanager.com/viewtopic.php?p=180545#p180545
-- Name:       Analogue of MkDir plugin from Igor Grabelnikov
-- Note:       Written from scratch, the plugin source code was not available

local Eng = {
  Title     = "Make folders";
  BreakOp   = "Break the operation?";
  ListMsg   = "Creating the list.\nPlease wait...";
  DirsMsg   = "Creating directories.\nPlease wait...";
  Prompt    = "Create the folder (templates can be used)";
  AliasErr  = "Alias <%s> not found";
  AliasFile = "Can't process aliases as '%s' not found";
  SyntaxErr = "Syntax error in the input data";
}

local Rus = {
  Title     = "Создание папок";
  BreakOp   = "Прервать операцию?";
  ListMsg   = "Создаётся список.\nПожалуйста ждите...";
  DirsMsg   = "Создаются папки.\nПожалуйста ждите...";
  Prompt    = "Создать папку (можно использовать шаблоны)";
  AliasErr  = "Псевдоним <%s> не найден";
  AliasFile = "Невозможно обработать псевдонимы: '%s' не найден";
  SyntaxErr = "Ошибка синтаксиса во входных данных";
}

local DIRSEP = package.config:sub(1,1)
local F = far.Flags
local M = Eng -- localization table
local DlgId = win.Uuid("CC48FA63-B031-4F2D-952E-43FC642722DB")
local FName = _filename or ...
local ScriptDir = FName:match(".+"..DIRSEP)

local function ErrMsg(str)
  far.Message(str, M.Title, ";OK", "w")
end

local function CheckEscape(text)
  if win.ExtractKey()=="ESCAPE" and far.Message(M.BreakOp, M.Title, ";YesNo")==1 then
    return true
  end
  far.Message(text, M.Title, "")
end

local function GetUserString()
  local topic = "<"..ScriptDir..">Contents"
  local eFlags = F.DIF_HISTORY + F.DIF_USELASTHISTORY
  local eHistory = "MkDirHistory"
  local items = {
    {F.DI_DOUBLEBOX, 3,1,72,4,  0,0,        0,0,      M.Title},
    {F.DI_TEXT,      5,2, 0,2,  0,0,        0,0,      M.Prompt},
    {F.DI_EDIT,      5,3,70,3,  0,eHistory, 0,eFlags, ""},
  }
  local ret = far.Dialog(DlgId,-1,-1,76,6,topic,items)
  if ret and ret >= 1 then return items[3][10] end
end

local function ApplyAliases(str)
  local fname = "mkdir.alias"
  local patLine = "^%s*(%S+)%s+(.-)%s*$"
  local patAlias = "<(%S%S-)>"
  local map = {}

  local fp = io.open(FName:match(".+"..DIRSEP)..fname)
  if fp then
    for line in fp:lines() do
      if not line:find("^%s*#") then -- if not comment
        local name,alias = line:match(patLine)
        if name and alias ~= "" then map[name:lower()]=alias end
      end
    end
    fp:close(fp)
  else
    if str:find(patAlias) then
      ErrMsg(M.AliasFile:format(fname))
      return nil
    end
  end

  local ok = true
  str = str:gsub(patAlias,
    function(c)
      local val = map[c:lower()]
      if val == nil then
        ErrMsg(M.AliasErr:format(c))
        ok = false
      end
      return val
    end)

  return ok and str
end

local function main()
  M = win.GetEnv("FARLANG")=="Russian" and Rus or Eng
  local str = GetUserString()
  if (not str) or str == "" then return end

  str = ApplyAliases(str)
  if not str then return end

  local grammar = assert(dofile(ScriptDir.."mkdir.grammar"))
  local dirs = grammar.GetList(str)
  if dirs then
    local curdir = panel.GetPanelDirectory(nil,1).Name
    for i,dir in ipairs(dirs) do
      win.CreateDir(win.JoinPath(curdir, dir))
      if i%100 == 0 and CheckEscape(M.DirsMsg) then break end
    end
    panel.UpdatePanel(nil, 1) -- update active panel
    if Panel then
      local fname = dirs[1]:match(DIRSEP=="/" and "^[^/]+" or "^[^/\\]+")
      Panel.SetPos(0, fname)
    end
    panel.RedrawPanel(nil, 0) -- redraw passive panel
    panel.RedrawPanel(nil, 1) -- redraw active panel
  else
    ErrMsg(M.SyntaxErr)
  end
end

if not Macro then
  local command = select(2,...)
  if command == "require" then
    local grammar = assert(dofile(ScriptDir.."mkdir.grammar"))
    return { main=main; GetDirs=grammar.GetList; }
  else
    main()
    return
  end
end

Macro {
  description="mkdir with templates";
  area="Shell"; key="ShiftF7";
  flags="NoPluginPanels";
  id="3CEFA3A8-334E-4BAA-8DAD-87DBF02E1897";
  action=function() main() end;
}
