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
  Prompt    = "Create the folder (you can use templates)";
  AliasErr  = "Alias <%s> not found";
  AliasFile = "Can't process aliases as '%s' not found";
}

local Rus = {
  Title     = "Создание папок";
  BreakOp   = "Прервать операцию?";
  ListMsg   = "Создаётся список.\nПожалуйста ждите...";
  DirsMsg   = "Создаются папки.\nПожалуйста ждите...";
  Prompt    = "Создать папку (вы можете использовать шаблоны)";
  AliasErr  = "Псевдоним <%s> не найден";
  AliasFile = "Невозможно обработать псевдонимы: '%s' не найден";
}

local DIRSEP = package.config:sub(1,1)
local F = far.Flags
local M = Eng -- localization table
local DlgId = win.Uuid("CC48FA63-B031-4F2D-952E-43FC642722DB")
local FName = _filename or ...
local range_dec, range_hex, range_sym = 1, 2, 3

local function ErrMsg(str)
  far.Message(str, M.Title, ";OK", "w")
end

local PatTemplate = regex.new( [[
     ( [^{]+ )       |
  \{ ( [^}]+ ) \}
]], "x")

local function CheckEscape(num, base, text)
  if num % base == 0 then
    if win.ExtractKey()=="ESCAPE" and far.Message(M.BreakOp, M.Title, ";YesNo")==1 then
      return true
    end
    far.Message(text, M.Title, "")
  end
end

local function IncIndex(parts)
  for k=#parts, 1, -1 do
    local t = parts[k]
    local item = t[t.idx]
    if type(item) == "table" then -- table representing a range
      if item.cur < item.to then
        item.cur = item.cur + 1
        return true
      else
        item.cur = item.fr
      end
    end
    if t.idx < #t then
      t.idx = t.idx + 1
      return true
    else
      t.idx = 1
    end
  end
end

local function GetValue(parts)
  local t = {}
  for _,v in ipairs(parts) do
    local item = v[v.idx]
    if type(item) == "table" then -- table representing a range
      if item.sym then
        t[#t+1] = utf8.char(item.cur)
      else
        t[#t+1] = item.fmt:format(item.cur)
      end
    else
      t[#t+1] = item
    end
  end
  return table.concat(t)
end

local function GetRange(txt)
  local fr, to

  fr, to = txt:match("^(%d+)%-(%d+)$") -- decimal range
  if fr then return range_dec, fr, to; end

  fr,to = txt:match("^(%x+)%-(%x+)$") -- hexadecimal range
  if fr then return range_hex, fr, to; end

  fr,to = txt:match("^(%a)%-(%a)$") -- symbolic range
  if fr then return range_sym, fr, to; end
end


local function DoTemplate(str, dirs)
  local parts = {}
  for d1, d2 in PatTemplate:gmatch(str) do
    if d1 then -- fixed part
      table.insert(parts, { d1, idx=1 })
    else       -- list
      local t = { idx=1 }
      table.insert(parts, t)
      for p in d2:gmatch("[^;]+") do
        local kind, fr, to = GetRange(p)
        if kind == range_dec then
          local fmt = fr:sub(1,1)=="0" and ("%0"..#fr.."d") or "%d"
          fr, to = tonumber(fr), tonumber(to)
          table.insert(t, { fr=fr; to=to; cur=fr; fmt=fmt; })
        elseif kind == range_hex then
          local fmt = fr:sub(1,1)=="0" and ("%0"..#fr.."X") or "%X"
          if fr:find("[a-f]") or to:find("[a-f]") then fmt = fmt:lower() end
          fr, to = tonumber(fr,16), tonumber(to,16)
          table.insert(t, { fr=fr; to=to; cur=fr; fmt=fmt; })
        elseif kind == range_sym then
          fr, to = fr:byte(), to:byte()
          table.insert(t, { fr=fr; to=to; cur=fr; sym=true; })
        else
          p = p:gsub("\\([%-\\])", "%1") -- escaped '-', according to help
          table.insert(t, p)
        end
      end
    end
  end
  for i=1,math.huge do
    table.insert(dirs, GetValue(parts))
    if not IncIndex(parts) then break end
    if CheckEscape(i, 1000, M.ListMsg) then return "break" end
  end
  return dirs
end

local function GetDirs(str)
  local dirs = {}
  local st = 1
  local len = str:len()
  local text, templ

  while st <= len do -- 1 loop = 1 task
    if text then
      local done = false
      local fr,to,cap = str:find('([;{])', st)
      if fr and cap==";" then
        text = text..str:sub(st,fr-1)
        st = to + 1
        done = true
      elseif fr and cap=="{" then
        text = text..str:sub(st,fr-1)
        st = fr
        fr,to,cap = str:find("({[^}]*})",st)
        if fr == st then
          text = text..cap
          st = to + 1
          templ = true
        else
          text = text.."{"
          st = st + 1
        end
      elseif not fr then
        text = text..str:sub(st)
        st = len + 1
      end

      if done or (st > len) then
        if text:find('"') then error("syntax") end
        if templ then
          if DoTemplate(text, dirs) == "break" then return "break" end
        else
          table.insert(dirs,text)
        end
        text = nil
      end

    else
      local fr,to,cap = str:find('"(.-)"',st)
      if fr == st then
        if cap ~= "" then table.insert(dirs,cap) end
        st = to + 1
      else
        fr,to = str:find(";+",st)
        if fr == st then
          st = to + 1
        else
          text = ""
          templ = false
        end
      end
    end
  end
  return dirs
end

local function GetUserString()
  local path = FName:match(".+"..DIRSEP)
  local topic = "<"..path..">Contents"
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

  local dirs = GetDirs(str)
  if type(dirs) == "table" and dirs[1] then
    local curdir = panel.GetPanelDirectory(nil, 1).Name
    for i,dir in ipairs(dirs) do
      win.CreateDir(win.JoinPath(curdir, dir))
      if CheckEscape(i, 100, M.DirsMsg) then break end
    end
    panel.UpdatePanel(nil, 1) -- update active panel
    if Panel then
      local fname = dirs[1]:match(DIRSEP=="/" and "^[^/]+" or "^[^/\\]+")
      Panel.SetPos(0, fname)
    end
  end
  panel.RedrawPanel(nil, 0) -- redraw passive panel
  panel.RedrawPanel(nil, 1) -- redraw active panel
end

if not Macro then
  local command = select(2,...)
  if command == "require" then
    return { main=main; GetDirs=GetDirs; }
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
