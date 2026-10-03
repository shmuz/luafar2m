-- Author           : Sergey Oblomov (hoopoe)
-- Published        : https://forum.farmanager.com/viewtopic.php?t=9445
-- Modifications by : Shmuel Zeigerman
-- Portable         : far3 and far2m

local dbKey = "named folders"
local dbEntries = "entries"
local dbShowDir = "showdir"
local MacroKey = "CtrlD"

local osWindows = package.config:sub(1,1) == "\\"
local F = far.Flags
local OpSetDir, OpInsert, OpDelete, OpEdit, OpShowDir = 1,2,3,4,5
local FarManId = osWindows and ("\0"):rep(16) or 0
local Msg

local bShowDir = mf.mload(dbKey, dbShowDir)
bShowDir = bShowDir == nil or bShowDir -- true by default

local Eng = {
  AppTitle         = "Named folders";
  BtnCancel        = "Cancel";
  BtnOK            = "Ok";
  BtnYesNo         = "&Yes;&No";
  ConfirmCaption   = "Confirm";
  EDialogCaption   = "Named Folder";
  EDialogData      = "&Data:";
  EDialogFile      = "&File:";
  EDialogPath      = "&Path:";
  EDialogTitle     = "&Title:";
  EmptyFields      = "Empty fields are not allowed";
  GetPanelDirFail  = "Failed to get panel directory data";
  MenuBottom       = "Ins:insert, Del:delete, F4:edit, Ctrl+L:show/hide path";
  OverwriteQuery   = "The alias \"%s\" is already in use. Overwrite?";
  PluginNotFound   = "Plugin not found.";
  RemoveQuery      = "Remove named folder '%s'\n%s ?";
}

local Rus = {
  AppTitle         = "Именованные папки";
  BtnCancel        = "Отмена";
  BtnOK            = "Ok";
  BtnYesNo         = "&Да;&Нет";
  ConfirmCaption   = "Подтверждение";
  EDialogCaption   = "Именованная папка";
  EDialogData      = "&Данные:";
  EDialogFile      = "&Файл:";
  EDialogPath      = "&Путь:";
  EDialogTitle     = "&Заголовок:";
  EmptyFields      = "Пустые поля не разрешены";
  GetPanelDirFail  = "Неудача получения данных папки панели";
  MenuBottom       = "Ins:вставить, Del:удалить, F4:редактировать, Ctrl+L:показывать путь";
  OverwriteQuery   = "Алиас \"%s\" уже используется. Перезаписать?";
  PluginNotFound   = "Плагин не найден.";
  RemoveQuery      = "Удалить именованную папку '%s'\n%s ?";
}

local function ErrorMsg(str)
  far.Message(str, Msg.AppTitle, ";Ok", "w")
end

local function ExtractFileName(path)
  return path:match(osWindows and "([^\\]+)\\?$" or "([^/]+)/?$")
end

local function GetPluginTitle(PluginId)
  local hnd = far.FindPlugin(osWindows and "PFM_GUID" or "PFM_SYSID", PluginId)
  if hnd then
    local info = far.GetPluginInformation(hnd)
    return info.GInfo.Title
  else
    return osWindows and win.Uuid(PluginId) or ("0x%08X"):format(PluginId)
  end
end

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

local function Filter(items, pattern)
  local ent = {}
  for _, v in ipairs(items) do -- filter items by pattern
    if v.alias:lower():match(pattern:lower()) then
      table.insert(ent, v)
    end
  end
  return ent
end

local function DoMenu(pattern, pos, alias)
  local use_filter = pattern and pattern ~= "" and not pattern:match("%s")
  local all_entries = LoadEntries()

  local entries
  if use_filter then
    entries = Filter(all_entries, "^" .. pattern)
    if #entries == 0 then return nil; end
    if #entries == 1 then return OpSetDir, entries[1]; end
  else
    entries = all_entries
  end

  local space = 0 -- calculate max width alias
  for _, v in ipairs(entries) do space = math.max(space, v.alias:len()) end

  local menuitems = {}
  for _, v in ipairs(entries) do
    local text = bShowDir
        and v.alias .. (" "):rep(space - v.alias:len()) .. " │ " .. v.path
        or v.alias
    table.insert(menuitems, {text=text; entry=v})
  end
  table.sort(menuitems, function(a,b) return a.entry.alias:lower() < b.entry.alias:lower(); end)

  if alias then
    for i,v in ipairs(menuitems) do
      if v.entry.alias == alias then
        pos = i
        break
      end
    end
  end

  local props = {
      Title = Msg.AppTitle;
      Bottom = use_filter and "" or Msg.MenuBottom;
      Flags = bit64.bor(F.FMENU_AUTOHIGHLIGHT, F.FMENU_WRAPMODE);
      SelectIndex = pos;
    }

  local brkeys = not use_filter and {
      { BreakKey = "Ins";     Op = OpInsert;  },
      { BreakKey = "Del";     Op = OpDelete;  },
      { BreakKey = "F4";      Op = OpEdit;    },
      { BreakKey = "CtrlL";   Op = OpShowDir; },
    }

  local item, position = far.Menu(props, menuitems, brkeys)
  return item, position, menuitems
end

local function EditEntry(aEntry)
  local sd = require "far2.simpledialog"
  local NewEntry
  local Inserting = not aEntry -- inserting a new record

  if Inserting then
    local dir = panel.GetPanelDirectory(nil, 1)
    if dir then
      aEntry = {
        File     = dir.File;
        Param    = dir.Param;
        PluginId = dir.PluginId;
        alias    = ExtractFileName(dir.Name);
        path     = dir.Name;
      }
    else
      ErrorMsg(Msg.GetPanelDirFail)
      return
    end
  end

  local Items = {
    guid="8B0EE808-C5E3-44D8-9429-AAFD8FA04067";
  }
  local function AddItem(t) Items[#Items+1] = t; end

  AddItem {tp="dbox"; text=Msg.EDialogCaption}
  AddItem {tp="text"; text=Msg.EDialogTitle}
  AddItem {tp="edit"; text=aEntry.alias; name="alias"}
  AddItem {tp="text"; text=Msg.EDialogPath}
  AddItem {tp="edit"; text=aEntry.path; name="path"}
  if aEntry.PluginId and aEntry.PluginId ~= FarManId then
    AddItem {tp="sep";  text=GetPluginTitle(aEntry.PluginId) }
    AddItem {tp="text"; text=Msg.EDialogFile}
    AddItem {tp="edit"; text=aEntry.File; name="File"}
    AddItem {tp="text"; text=Msg.EDialogData}
    AddItem {tp="edit"; text=aEntry.Param; name="Param"}
  end
  AddItem {tp="sep"}
  AddItem {tp="butt"; text=Msg.BtnOK; centergroup=1; default=1}
  AddItem {tp="butt"; text=Msg.BtnCancel; centergroup=1; cancel=1}

  local Entries
  local function insert_item(out)
    -- Check if an entry with the same alias already exists.
    -- If it exists and a new entry is inserted, ask for overwrite permission.
    -- Then remove that existing entry.
    Entries = Entries or LoadEntries()
    for i,v in ipairs(Entries) do
      if v.alias:lower() == out.alias:lower() then
        if Inserting then
          local text = Msg.OverwriteQuery:format(v.alias)
          if 1 ~= far.Message(text, Msg.AppTitle, Msg.BtnYesNo, "w") then
            return false
          end
        end
        table.remove(Entries, i)
        break
      end
    end

    -- Insert a new entry.
    NewEntry = {
        File     = out.File;
        Param    = out.Param;
        PluginId = aEntry.PluginId;
        alias    = out.alias;
        path     = out.path;
      }

    -- Save the entries.
    table.insert(Entries, NewEntry)
    SaveEntries(Entries)
    return true
  end

  Items.proc = function(hDlg, msg, par1, par2)
    if msg == F.DN_CLOSE then
      if par2.alias == "" or par2.path == "" then
        ErrorMsg(Msg.EmptyFields)
        return 0 -- don't close
      end
      if not insert_item(par2) then
        return 0 -- don't close
      end
    end
  end

  sd.New(Items):Run()
  return NewEntry
end

local function RemoveEntry(entry)
  if entry and entry.alias and entry.path then
    local msg = Msg.RemoveQuery:format(entry.alias, entry.path)
    local res = far.Message(msg, Msg.ConfirmCaption, Msg.BtnYesNo, "w")
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

local function SetPanelDir(entry)
  if osWindows then
    local dir = {
      File     = entry.File;
      Param    = entry.Param;
      PluginId = entry.PluginId;
      Name     = ExpandEnv(entry.path);
    }
    panel.SetPanelDirectory(nil, 1, dir)
  else
    local dir = {
      HostFile = entry.File;
      Path     = ExpandEnv(entry.path);
    }
    if entry.PluginId and entry.PluginId ~= FarManId then
      local hnd = far.FindPlugin("PFM_SYSID", entry.PluginId)
      if not hnd then
        ErrorMsg(Msg.PluginNotFound)
        return
      end
      local info = far.GetPluginInformation(hnd)
      dir.PluginName = info.ModuleName
    end
    panel.SetPanelLocation(nil, 1, dir)
  end
end

local function Main(text)
  Msg = win.GetEnv("FARLANG") == "Russian" and Rus or Eng

  -- The values for handling position in the menu during multiple Menu() calls.
  -- 'alias' has higher priority than 'position'.
  local position, alias

  while true do
    local item, pos, items = DoMenu(text, position, alias)
    if item == nil then break end

    position, alias = pos, nil
    local entry = pos > 0 and items[pos].entry

    if item.Op == OpInsert then
      local newentry = EditEntry(nil)
      alias = newentry and newentry.alias
    elseif entry then
      if item.Op == nil then
        SetPanelDir(entry)
        break
      elseif item.Op == OpDelete then
        RemoveEntry(entry)
      elseif item.Op == OpEdit then
        EditEntry(entry)
      elseif item.Op == OpShowDir then
        bShowDir = not bShowDir
        mf.msave(dbKey, dbShowDir, bShowDir)
      end
    end
  end
end

CommandLine {
  description = "Named Folders Lua Edition";
  prefixes = "cd";
  action = function(prefix, text) Main(text); end;
}

Macro {
  id="D812F8E8-4CDC-48AD-8C52-9B905263BAEC";
  description = "Named Folders";
  area="Shell"; key=MacroKey;
  action=function() Main(); end;
}
