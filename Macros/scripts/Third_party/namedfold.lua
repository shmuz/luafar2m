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
    local text = bShowDir and
      v.alias .. (" "):rep(space - v.alias:len()) ..
      " │ " .. v.path or v.alias
    table.insert(menuitems, {text=text; entry=v})
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

local function NewEntry(aEntry)
  local sd = require "far2.simpledialog"

  local alias_name, target_name
  if aEntry then
    alias_name = aEntry.alias
    target_name = aEntry.path
  else
    local panelDir = panel.GetPanelDirectory(nil, 1).Name
    alias_name = panelDir:match(osWindows and "([^\\]+)\\?$" or "([^/]+)/?$")
    target_name = panelDir
  end

  local items = {
    guid="8B0EE808-C5E3-44D8-9429-AAFD8FA04067";
    {tp="dbox", text="Named Folder"},
    {tp="text", text="&Alias name:"},
    {tp="edit", text=alias_name, name="alias"},
    {tp="text", text="&Target:"},
    {tp="edit", text=target_name, name="path"},
    {tp="sep"},
    {tp="butt", centergroup=1, default=1; text="Ok"},
    {tp="butt", centergroup=1, cancel=1; text="Cancel"}
  }
  items.proc = function(hDlg, msg, par1, par2)
    if msg == F.DN_CLOSE then
      if par2.alias == "" or par2.path == "" then
        far.Message("Empty fields are not allowed", nil, ";Ok", "w")
        return 0
      end
    end
  end

  -- Not checking if the alias already exists as multiple entries having the same alias is a feature
  local out = sd.New(items):Run()
  if out then
    local entries = LoadEntries()
    table.insert(entries, {alias=out.alias; path=out.path})
    SaveEntries(entries)
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
