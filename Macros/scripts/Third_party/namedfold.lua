-- Author           : Sergey Oblomov (hoopoe)
-- Published        : https://forum.farmanager.com/viewtopic.php?t=9445
-- Modifications by : Shmuel Zeigerman
-- Portable         : far3 and far2m

local dbKey = "named folders"
local dbEntries = "entries"
local dbShowDir = "showdir"
local Title = "Named Folders Lua Edition"
local MacroKey = "CtrlD"

local osWindows = package.config:sub(1,1) == "\\"
local F = far.Flags
local OpSetDir, OpInsert, OpDelete, OpEdit, OpShowDir, OpDontClose = 1,2,3,4,5,6

local ExpandEnv = not osWindows and win.ExpandEnv or -- luacheck: ignore
  function(s)
    return (s:gsub("%%(.-)%%", win.GetEnv))
  end

local function LoadEntries()
  local v = mf.mload(dbKey, dbEntries)
  return type(v) == "table" and v or {}
end

local function SaveEntries(ent)
  mf.msave(dbKey, dbEntries, ent)
end

local bShowDir = mf.mload(dbKey, dbShowDir)
bShowDir = bShowDir == nil or bShowDir -- true by default

local function Filter(items, pattern)
  local ent = {}
  local space = 0
  for _, v in ipairs(items) do -- filter items by pattern & calculate max width alias
    if not pattern or v.alias:lower():match(pattern:lower()) then
      table.insert(ent, v)
      space = math.max(space, v.alias:len())
    end
  end
  return ent, space
end

local function DoMenu(pattern)
  local use_filter = pattern and pattern ~= "" and not pattern:match("%s")
  local all_entries = LoadEntries()

  local entries, space
  if use_filter then
    entries, space = Filter(all_entries, "^" .. pattern)
    if #entries == 0 then return nil; end
    if #entries == 1 then return OpSetDir, entries[1]; end
  else
    entries, space = Filter(all_entries, nil)
  end

  local menuitems = {}
  for _, v in ipairs(entries) do
    local item = {
      text = v.alias .. (" "):rep(space + 1 - v.alias:len()) .. (bShowDir and v.path or "");
      entry = v;
    }
    table.insert(menuitems, item)
  end
  table.sort(menuitems, function(a,b) return a.entry.alias:lower() < b.entry.alias:lower(); end)

  local brkeys, bottom
  if not use_filter then
    brkeys = {
      { BreakKey = "INSERT";  Op = OpInsert;  },
      { BreakKey = "DELETE";  Op = OpDelete;  },
      { BreakKey = "F4";      Op = OpEdit;    },
      { BreakKey = "C+L";     Op = OpShowDir; },
    }
    bottom = "Ins:Insert, Del:Delete, F4:Edit, Ctrl+L:Show/Hide path"
  end

  local item, position = far.Menu(
    { Title = Title;
      Bottom = bottom;
      Flags = bit64.bor(F.FMENU_AUTOHIGHLIGHT, F.FMENU_WRAPMODE)
    },
    menuitems, brkeys)

  if not item then
    return nil
  elseif item.Op == OpInsert then
    return OpInsert
  elseif position > 0 then
    local entry = menuitems[position].entry
    if     item.Op == nil       then return OpSetDir, entry
    elseif item.Op == OpDelete  then return OpDelete, entry
    elseif item.Op == OpEdit    then return OpEdit, entry
    elseif item.Op == OpShowDir then return OpShowDir
    end
  else
    return OpDontClose
  end
end

local function NewEntry(entry)
  local guid = win.Uuid("8B0EE808-C5E3-44D8-9429-AAFD8FA04067")
  local panelDir = panel.GetPanelDirectory(nil, 1).Name
  local alias_name = entry and entry.alias or panelDir:match(osWindows and "([^\\]+)\\?$" or "([^/]+)/?$")
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
      local entries = LoadEntries()
      for i, v in ipairs(entries) do
        if v.alias:lower() == alias:lower() then
          local msg = ("Replace named folder '%s'\n%s ?"):format(v.alias, v.path)
          if 1 ~= far.Message(msg, "Confirm", ";YesNo", "w") then
            return
          end
          table.remove(entries, i)
          break
        end
      end
      table.insert(entries, {alias=alias; path=path})
      SaveEntries(entries)
    end
  end
end

local function RemoveEntry(entry)
  if entry and entry.alias and entry.path then
    local msg = ("Remove named folder '%s'\n%s ?"):format(entry.alias, entry.path)
    local res = far.Message(msg, "Confirm", ";YesNo", "w")
    if res == 1 then
      local entries = LoadEntries()
      for i, v in ipairs(entries) do
        if v.alias == entry.alias then
          table.remove(entries, i)
          SaveEntries(entries)
          break
        end
      end
    end
  end
end

local function Main(text)
  local op, entry = DoMenu(text)
  while op do
    if op == OpSetDir then
      if entry.path then
        panel.SetPanelDirectory(nil, 1, ExpandEnv(entry.path))
      end
      break
    elseif op == OpInsert  then NewEntry()
    elseif op == OpDelete  then RemoveEntry(entry)
    elseif op == OpEdit    then NewEntry(entry)
    elseif op == OpShowDir then
      bShowDir = not bShowDir
      mf.msave(dbKey, dbShowDir, bShowDir)
    end
    op, entry = DoMenu(text)
  end
end

CommandLine {
  description = "Named Folders Lua Edition";
  prefixes = "cd";
  action = function(prefix, text) Main(text); end;
}

Macro {
  id="D812F8E8-4CDC-48AD-8C52-9B905263BAEC";
  description = Title;
  area="Shell"; key=MacroKey;
  action=function() Main(); end;
}
