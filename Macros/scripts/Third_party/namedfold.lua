-- Author       : Sergey Oblomov (hoopoe)
-- Published    : https://forum.farmanager.com/viewtopic.php?t=9445
-- Modifications by : Shmuel Zeigerman

local dbkey = "named folders lua edition"
local dbname = "entries"
local dbconfig = dbkey .. " config"
local dbshowdir = "showdir"

local F = far.Flags

local load_nf = function()
  local v = mf.mload(dbkey, dbname)
  return type(v) == "table" and v or {}
end

local save_nf = function(ent) mf.msave(dbkey, dbname, ent); end

local noshowdir = mf.mload(dbconfig, dbshowdir)

local menu = function(pattern)
  local entry = function(e, space)
    return {
      text = e.alias .. (" "):rep(space + 1 - e.alias:len()) .. (not noshowdir and e.path or "");
      entry = e;
    }
  end

  local best = function(pattern)
    local scan = function(pattern)
      local ent = {}
      local space = 0

      for _, v in ipairs(load_nf()) do -- filter items by pattern & calculate max width alias
        if (not pattern or v.alias:lower():match(pattern:lower())) then
          table.insert(ent, v)
          space = math.max(space, v.alias:len())
          if pattern and pattern:lower() == v.alias:lower() then
            return 1, v
          end -- exact matching - return it
        end
      end
      return ent, space
    end

    if not pattern then return scan(); end

    local ent, space = scan("^" .. pattern)
    if space > 0 then return ent, space; end
    ent, space = scan("%s+" .. pattern)
    if space > 0 then return ent, space; end
    return scan(pattern)
  end

  local entries = {}

  local ent, space = best(pattern)

  for _, v in ipairs(ent) do table.insert(entries, entry(v, space)); end

  if pattern and #entries == 1 then return 1, entries[1].entry; end
  if pattern and #entries == 0 then return nil; end

  table.sort(entries, function(a, b) return a.entry.alias:lower() < b.entry.alias:lower(); end)

  local brakes = {{BreakKey = "INSERT"}, {BreakKey = "DELETE"}, {BreakKey = "F4"}, {BreakKey = "C+l"}}
  local bottom = "Ins - Insert, Del - Delete, F4 - Edit, Ctrl+L - Show/Hide path"

  if (pattern) then
    brakes = nil
    bottom = nil
  end

  local item, position = far.Menu(
    { Title = "Named Folders Lua Edition";
      Bottom = bottom,
      Flags = bit.bor(F.FMENU_AUTOHIGHLIGHT, F.FMENU_WRAPMODE)
    },
    entries, brakes)

  if not item then return nil
  elseif item.BreakKey == "INSERT" then return "insert"
  elseif item.BreakKey == "DELETE" and position and position > 0 then return "delete", entries[position].entry
  elseif item.BreakKey == "F4" and position and position > 0 then return "edit", entries[position].entry
  elseif item.BreakKey == "C+l" then return "showdir"
  elseif position > 0 then return position, entries[position].entry
  else return nil
  end
end

local newentry = function(entry)
  local split = function(str, pattern)
    local v = {}
    for i in str:gmatch(pattern) do table.insert(v, i); end
    return v
  end

  local guid = win.Uuid("8B0EE808-C5E3-44D8-9429-AAFD8FA04067")
  local alias_name = entry and entry.alias or table.remove(split(panel.GetPanelDirectory(nil, 1), "[^\\/]+"))
  local target_name = entry and entry.path or panel.GetPanelDirectory(nil, 1)
  local items = {
  --[[ 1]] {F.DI_DOUBLEBOX, 3,1, 65,8, 0, 0,0, 0, "Named Folder"},
  --[[ 2]] {F.DI_TEXT,    5,2, 16,2, 0, 0,0, 0, "&Alias name:"},
  --[[ 3]] {F.DI_EDIT,    5,3, 63,3, 0, 0,0, 0, alias_name},
  --[[ 4]] {F.DI_TEXT,    5,4, 11,4, 0, 0,0, 0, "&Target:"},
  --[[ 5]] {F.DI_EDIT,    5,5, 63,5, 0, 0,0, 0, target_name},
  --[[ 6]] {F.DI_TEXT,   -1,6,  0,0, 0, 0,0, F.DIF_SEPARATOR,""},
  --[[ 7]] {F.DI_BUTTON,  0,7,  0,0, 0, 0,0, F.DIF_DEFAULTBUTTON+F.DIF_CENTERGROUP,"Ok"},
  --[[ 8]] {F.DI_BUTTON,  0,7,  0,0, 0, 0,0, F.DIF_CENTERGROUP,"Cancel"}
  }
  if far.Dialog(guid, -1, -1, 69, 10, nil, items, nil, nil) == 7 then
    local alias = items[3][10]
    local path = items[5][10]
    if (alias ~= "" and path ~= "") then
      local entries = load_nf()
      for i, v in ipairs(entries) do
        if v.alias == alias then
          table.remove(entries, i)
          break
        end
      end
      table.insert(entries, {alias = alias; path=path})
      save_nf(entries)
    end
  end
end

local removeentry = function(entry)
  if entry and entry.alias and entry.path then
    local res = far.Message("Remove named folder " .. entry.alias .. " (" .. entry.path .. ")?",
          "Remove named folder", ";YesNo")
    if res == 1 then
      local entries = load_nf()
      for i, v in ipairs(entries) do
        if v.alias == entry.alias then
          table.remove(entries, i)
          save_nf(entries)
          --far.Message("removed: " .. entry.alias)
          break
        end
      end
    end
  end
end

local action = function(text)
  --far.Message("prefix: " .. prefix .. " text: " .. text)
  if not text or text == "" or text:match("%s") then text = nil; end
  while true do
    local res, entry = menu(text)
    --far.Message("menu: " .. res .. " : " .. tostring(entry.alias))
    if not res then break
    elseif entry and tonumber(res) and tonumber(res) >= 0 then
      local function ExpandEnv(str) return (str:gsub("%%(.-)%%", win.GetEnv)) end
      if entry.path then panel.SetPanelDirectory(nil, 1, ExpandEnv(entry.path)); end
      break
    elseif tostring(res) == "insert" then newentry()
    elseif tostring(res) == "delete" and entry then removeentry(entry)
    elseif tostring(res) == "edit" and entry then newentry(entry)
    elseif tostring(res) == "showdir" then
      noshowdir = not noshowdir
      mf.msave(dbconfig, dbshowdir, noshowdir)
    end
  end
end

CommandLine {
  description = "Named Folders Lua Edition";
  prefixes = "cd";
  action = function(prefix, text) action(text); end;
}

-- MenuItem {
--   description = "Named Folders Lua Edition";
--   menu   = "Plugins";
--   area   = "Shell";
--   guid   = "B854578E-AEF7-4DA6-83A8-872FA9D13E8B";
--   text   = function(menu, area) return "Named Folders Lua Edition"; end;
--   action = function(OpenFrom, Item) action(); end;
-- }
