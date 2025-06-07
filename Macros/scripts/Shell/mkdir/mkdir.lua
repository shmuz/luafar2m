-- Started:    2025-05-25
-- Author:     Shmuel Zeigerman
-- Published:  https://forum.farmanager.com/viewtopic.php?p=180545#p180545
-- Note:       Inspired by MkDir plugin (https://plugring.farmanager.com/plugin.php?pid=127)
-- Note:       Written from scratch, the plugin source code was not available

local Eng = {
  Title       = "Make directories";
  BreakOp     = "Break the operation?";
  ListMsg     = "Creating the list.\nPlease wait...";
  DirsMsg     = "Creating directories.\nPlease wait...";
  Prompt      = "&Create the directory";
  AliasErr    = "Alias <%s> not found";
  AliasFile   = "Can't process aliases as '%s' not found";
  SyntaxErr   = "Syntax error in the input data";
  CBoxPassive = "on the &Passive panel";
}

local Rus = {
  Title       = "Создание папок";
  BreakOp     = "Прервать операцию?";
  ListMsg     = "Создаётся список.\nПожалуйста ждите...";
  DirsMsg     = "Создаются папки.\nПожалуйста ждите...";
  Prompt      = "&Создать папку";
  AliasErr    = "Псевдоним <%s> не найден";
  AliasFile   = "Невозможно обработать псевдонимы: '%s' не найден";
  SyntaxErr   = "Ошибка синтаксиса во входных данных";
  CBoxPassive = "на &Пассивной панели";
}

local DIRSEP = package.config:sub(1,1)
local F = far.Flags
local M = Eng -- localization table
local DlgId = win.Uuid("CC48FA63-B031-4F2D-952E-43FC642722DB")
local FName = _filename or ...
local ScriptDir = FName:match(".+"..DIRSEP)
local IsPassivePanel = false

local function ErrMsg(str)
  far.Message(str, M.Title, ";OK", "w")
end

local function CheckEscape(text)
  if win.ExtractKey()=="ESCAPE" and far.Message(M.BreakOp, M.Title, ";YesNo")==1 then
    return true
  end
  far.Message(text, M.Title, "")
end

local function ApplyAliases(str)
  -- if 'str' contains no aliases then just return 'str'
  local patAlias = "<(%S%S-)>"
  if not str:find(patAlias) then return str end

  local ok, chunk, msg

  -- load the alias file
  local fname = "mkdir.alias"
  chunk, msg = loadfile(ScriptDir..fname)
  if not chunk then
    ErrMsg(msg); return nil
  end

  -- run the alias file
  local env = setmetatable({}, {__index=_G})
  setfenv(chunk, env)
  ok, msg = pcall(chunk)
  if not ok then
    ErrMsg(msg); return nil
  end

  -- convert all aliases' names to lower case
  local map = {}
  for k,v in pairs(env) do
    if type(k) == "string" then map[k:lower()] = v end
  end

  -- expand aliases in 'str'
  ok = true
  local function subst(c)
    if not ok then return end

    local key = c:lower()
    local val = map[key]
    if val == nil then
      ErrMsg(M.AliasErr:format(c))
      ok = false
      return
    end

    if type(val) == "function" then -- use the first return value
      setfenv(val, env)
      ok, val = pcall(val)
      if not ok then
        ErrMsg(val)
        return
      end
    end

    if type(val) == "table" then
      for i=1,#val do
        val[i] = tostring(val[i])
        if val[i]:find("[;{}]") then
          val[i] = '"'..val[i]..'"' -- assumes knowledge about the grammar
        end
      end
      return "{"..table.concat(val,";").."}" -- assumes knowledge about the grammar
    else
      return tostring(val)
    end

  end

  str = str:gsub(patAlias, subst)
  return ok and str
end

local function GetUserString()
  local topic = "<"..ScriptDir..">Contents"
  local eFlags = F.DIF_HISTORY + F.DIF_USELASTHISTORY
  local eHistory = "MkDirHistory"

  local cbFlags = 0
  local cbState = IsPassivePanel and 1 or 0
  if panel.GetPanelDirectory(nil,0).Name == "" then
    cbFlags, cbState = F.DIF_DISABLE, 0  -- passive panel is plugin panel
  end

  local items = {
    {F.DI_DOUBLEBOX, 3,1,72,5,  0,0,         0, 0,       M.Title},
    {F.DI_TEXT,      5,2, 0,2,  0,0,         0, 0,       M.Prompt},
    {F.DI_EDIT,      5,3,70,3,  0,eHistory,  0, eFlags,  ""},
    {F.DI_CHECKBOX,  5,4, 0,4,  cbState, 0,  0, cbFlags, M.CBoxPassive},
  }
  local posEdit, posChbox = 3, 4
  local str
  local function proc(hDlg,msg,par1,par2)
    if msg == F.DN_CLOSE and par1 >= 1 then
      str = ApplyAliases(hDlg:GetText(posEdit))
      if not str then return 0 end
      IsPassivePanel = hDlg:GetCheck(posChbox) ~= 0
    end
  end
  local ret = far.Dialog(DlgId,-1,-1,76,7,topic,items,nil,proc)
  if ret and ret >= 1 then return str end
end

local function main()
  M = win.GetEnv("FARLANG")=="Russian" and Rus or Eng
  local str = GetUserString()
  if (not str) or str == "" then return end

  local grammar = assert(dofile(ScriptDir.."mkdir.grammar"))
  local dirs = grammar.GetList(str)
  if dirs then
    local numPanel = IsPassivePanel and 0 or 1
    local curdir = panel.GetPanelDirectory(nil,numPanel).Name
    for i,dir in ipairs(dirs) do
      win.CreateDir(win.JoinPath(curdir, dir))
      if i%100 == 0 and CheckEscape(M.DirsMsg) then break end
    end
    panel.UpdatePanel(nil, numPanel)
    if Panel and not IsPassivePanel then
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
