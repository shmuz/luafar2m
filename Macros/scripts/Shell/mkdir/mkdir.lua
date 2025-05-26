-- Started:    2025-05-25
-- Author:     Shmuel Zeigerman
-- Published:  https://forum.farmanager.com/viewtopic.php?p=180545#p180545
-- Name:       Analogue of MkDir plugin from Igor Grabelnikov
-- Note:       Written from scratch, the plugin source code was not available

local Eng = {
  Title   = "Make folder";
  BreakOp = "Break the operation?";
  Wait    = "Please wait...";
  Prompt  = "Create the folder (you can use templates)";
}

local Rus = {
  Title   = "Создание папки";
  BreakOp = "Прервать операцию?";
  Wait    = "Пожалуйста ждите...";
  Prompt  = "Создать папку (вы можете использовать шаблоны)";
}

local M -- localization table
local DlgId = win.Uuid("CC48FA63-B031-4F2D-952E-43FC642722DB")
local FName = _filename or ...
local range_dec, range_hex, range_sym = 1, 2, 3

local PatSimple = regex.new( [[
  "([^"]+)"(?: ;+|$) |
  ([^;"]+) (?: ;+|$) |
  (.+)
]], "x")

local PatTemplate = regex.new( [[
     ( [^{]+ )       |
  \{ ( [^{]+ ) \}
]], "x")

local function CheckEscape(num, base)
  return num % base == 0 and win.ExtractKey() == "ESCAPE" and
      far.Message(M.BreakOp, M.Title, ";YesNo") == 1
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


local function DoTemplate(str)
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
  local dirs = {}
  far.Message(M.Wait, M.Title, "")
  for i=1,math.huge do
    dirs[i] = GetValue(parts)
    if not IncIndex(parts) then break end
    if CheckEscape(i, 1000) then return nil end
  end
  return dirs
end

local function DoSimple(str)
  local dirs = {}
  for d1, d2, bad in PatSimple:gmatch(str) do
    if bad or (d2 and d2:find("{")) then return nil end
    table.insert(dirs, d1 or d2)
  end
  return dirs
end

local function main()
  M = win.GetEnv("FARLANG")=="Russian" and Rus or Eng
  local name = FName:match("(.-)[^.+]$")
  local topic = "<"..name..">Contents"
  local str = far.InputBox (DlgId, M.Title, M.Prompt, "MkDirHistory", nil, nil, topic, 0)
  if str then
    local dirs = DoSimple(str) or DoTemplate(str)
    if dirs then
      local curdir = panel.GetPanelDirectory(nil, 1).Name
      far.Message(M.Wait, M.Title, "")
      for i,dir in ipairs(dirs) do
        win.CreateDir(win.JoinPath(curdir, dir))
        if CheckEscape(i, 100) then break end
      end
      panel.UpdatePanel(nil, 1) -- update active panel
    end
    panel.RedrawPanel(nil, 0) -- redraw passive panel
    panel.RedrawPanel(nil, 1) -- redraw active panel
  end
end

if not Macro then
  main()
  return
end

Macro {
  description="mkdir with templates";
  area="Shell"; key="ShiftF7";
  flags="NoPluginPanels";
  id="3CEFA3A8-334E-4BAA-8DAD-87DBF02E1897";
  action=function() main() end;
}
