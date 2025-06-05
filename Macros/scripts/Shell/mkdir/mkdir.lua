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

local function ApplyAliases(str)
  -- if 'str' contains no aliases then just return 'str'
  local patAlias = "<(%S%S-)>"
  if not str:find(patAlias) then return str end

  -- if no alias file found then return nil
  local fname = "mkdir.alias"
  local fp = io.open(ScriptDir..fname)
  if not fp then
    ErrMsg(M.AliasFile:format(fname))
    return nil
  end

  -- collect aliases from the file
  local patLine = "^%s*(%S+)%s+(.-)%s*$"
  local map, luamap = {}, {}
  for line in fp:lines() do
    if not line:find("^%s*#") then -- if not comment
      local name,alias = line:match(patLine)
      if name and alias ~= "" then
        local key = name:lower()
        local luakey = key:match("lua:(%S+)")
        if luakey then luamap[luakey] = alias
        else map[key] = alias
        end
      end
    end
  end
  fp:close(fp)

  -- expand aliases in 'str'
  local ok = true
  local env = setmetatable({}, { __index=_G })
  local function subst(c)
    if ok then
      local key = c:lower()
      local val = map[key]
      if val then
        return val -- simple substitution
      end
      val = luamap[key]
      if val then
        -- substitution with Lua expression
        local chunk, ret, ok2
        chunk,ret = loadstring("return "..val)
        if not chunk then chunk,ret = loadstring(val) end
        if chunk then
          setfenv(chunk, env)
          ok2, ret = pcall(chunk)
          if ok2 then return tostring(ret)
          else ErrMsg(ret); ok = false;
          end
        else
          ErrMsg(ret); ok = false;
        end
      else -- alias not found
        ErrMsg(M.AliasErr:format(c)); ok = false;
      end
    end
  end
  str = str:gsub(patAlias, subst)

  return ok and str
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
  local str
  local function proc(hDlg,msg,par1,par2)
    if msg == F.DN_CLOSE and par1 >= 1 then
      str = ApplyAliases(hDlg:GetText(3))
      if not str then return 0 end
    end
  end
  local ret = far.Dialog(DlgId,-1,-1,76,6,topic,items,nil,proc)
  if ret and ret >= 1 then return str end
end

local function main()
  M = win.GetEnv("FARLANG")=="Russian" and Rus or Eng
  local str = GetUserString()
  if (not str) or str == "" then return end

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
