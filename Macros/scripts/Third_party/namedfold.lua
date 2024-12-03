-- Author       : Sergey Oblomov (hoopoe)
-- Published    : https://forum.farmanager.com/viewtopic.php?t=9445
-- Modifications by : Shmuel Zeigerman
-- Portable     : Far3 and far2m

local dbkey = "named folders"
local dbname = "entries"
local dbshowdir = "showdir"

local Far3 = package.config:sub(1,1) == "\\"
local F = far.Flags

local ExpandEnv = not Far3 and win.ExpandEnv or -- luacheck: ignore
  function(s)
    return (s:gsub("%%(.-)%%", win.GetEnv))
  end

local function load_nf()
  local v = mf.mload(dbkey, dbname)
  return type(v) == "table" and v or {}
end

local function save_nf(ent)
  mf.msave(dbkey, dbname, ent)
end

local showdir = mf.mload(dbkey, dbshowdir)
showdir = showdir == nil or showdir -- true by default

local function scan(pattern, data)
  local ent = {}
  local space = 0

  for _, v in ipairs(data) do -- filter items by pattern & calculate max width alias
    if not pattern or v.alias:lower():match(pattern:lower()) then
      table.insert(ent, v)
      space = math.max(space, v.alias:len())
    end
  end
  return ent, space
end

local function menu(pattern)
  local data = load_nf()
  local ent, space
  if pattern then
    ent, space = scan("^" .. pattern, data)
    if #ent == 1 then return "setdir", ent[1]; end
    if #ent == 0 then return nil; end
  else
    ent, space = scan(nil, data)
  end

  local entries = {}
  for _, v in ipairs(ent) do
    local item = {
      text = v.alias .. (" "):rep(space + 1 - v.alias:len()) .. (showdir and v.path or "");
      entry = v;
    }
    table.insert(entries, item)
  end
  table.sort(entries, function(a, b) return a.entry.alias:lower() < b.entry.alias:lower(); end)

  local brakes, bottom
  if not pattern then
    brakes = {
      {BreakKey = "INSERT"},
      {BreakKey = "DELETE"},
      {BreakKey = "F4"},
      {BreakKey = "C+l"},
    }
    bottom = "Ins - Insert, Del - Delete, F4 - Edit, Ctrl+L - Show/Hide path"
  end

  local item, position = far.Menu(
    { Title = "Named Folders Lua Edition";
      Bottom = bottom,
      Flags = bit64.bor(F.FMENU_AUTOHIGHLIGHT, F.FMENU_WRAPMODE)
    },
    entries, brakes)

  if not item then
    return nil
  elseif item.BreakKey == "INSERT" then
    return "insert"
  elseif position > 0 then
    if     item.BreakKey == nil      then return "setdir", entries[position].entry
    elseif item.BreakKey == "DELETE" then return "delete", entries[position].entry
    elseif item.BreakKey == "F4"     then return "edit",   entries[position].entry
    elseif item.BreakKey == "C+l"    then return "showdir"
    end
  else
    return "dontclose"
  end
end

local function newentry(entry)
  local guid = win.Uuid("8B0EE808-C5E3-44D8-9429-AAFD8FA04067")
  local panelDir = panel.GetPanelDirectory(nil, 1).Name
  local alias_name = entry and entry.alias or panelDir:match(Far3 and "([^\\]+)\\?$" or "([^/]+)/?$")
  local target_name = entry and entry.path or panelDir
  local items = {
  --[[ 1]] {F.DI_DOUBLEBOX, 3,1, 65,8, 0, 0,0, 0, "Named Folder"},
  --[[ 2]] {F.DI_TEXT,      5,2, 16,2, 0, 0,0, 0, "&Alias name:"},
  --[[ 3]] {F.DI_EDIT,      5,3, 63,3, 0, 0,0, 0, alias_name},
  --[[ 4]] {F.DI_TEXT,      5,4, 11,4, 0, 0,0, 0, "&Target:"},
  --[[ 5]] {F.DI_EDIT,      5,5, 63,5, 0, 0,0, 0, target_name},
  --[[ 6]] {F.DI_TEXT,   -  1,6,  0,0, 0, 0,0, F.DIF_SEPARATOR,""},
  --[[ 7]] {F.DI_BUTTON,    0,7,  0,0, 0, 0,0, F.DIF_DEFAULTBUTTON+F.DIF_CENTERGROUP,"Ok"},
  --[[ 8]] {F.DI_BUTTON,    0,7,  0,0, 0, 0,0, F.DIF_CENTERGROUP,"Cancel"}
  }
  local posAlias, posPath, posOK = 3, 5, 7

  if posOK == far.Dialog(guid, -1, -1, 69, 10, nil, items) then
    local alias = items[posAlias][10]
    local path = items[posPath][10]
    if alias ~= "" and path ~= "" then
      local entries = load_nf()
      for i, v in ipairs(entries) do
        if v.alias:lower() == alias:lower() then
          table.remove(entries, i)
          break
        end
      end
      table.insert(entries, {alias=alias; path=path})
      save_nf(entries)
    end
  end
end

local function removeentry(entry)
  if entry and entry.alias and entry.path then
    local msg = ("Remove named folder %s (%s)?"):format(entry.alias, entry.path)
    local res = far.Message(msg, "Remove named folder", ";YesNo")
    if res == 1 then
      local entries = load_nf()
      for i, v in ipairs(entries) do
        if v.alias == entry.alias then
          table.remove(entries, i)
          save_nf(entries)
          break
        end
      end
    end
  end
end

local function action(text)
  if not text or text == "" or text:match("%s") then text = nil; end
  local res, entry = menu(text)
  while res do
    if res == "setdir" then
      if entry.path then panel.SetPanelDirectory(nil, 1, ExpandEnv(entry.path)); end
      break
    elseif res == "insert"  then newentry()
    elseif res == "delete"  then removeentry(entry)
    elseif res == "edit"    then newentry(entry)
    elseif res == "showdir" then
      showdir = not showdir
      mf.msave(dbkey, dbshowdir, showdir)
    end
    res, entry = menu(text)
  end
end

CommandLine {
  description = "Named Folders Lua Edition";
  prefixes = "cd";
  action = function(prefix, text) action(text); end;
}

Macro {
  id="D812F8E8-4CDC-48AD-8C52-9B905263BAEC";
  description = "Named Folders Lua Edition";
  area="Shell"; key="CtrlD";
  action=function() action(); end;
}
