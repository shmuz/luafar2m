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
local OpSetDir, OpInsert, OpDelete, OpEdit, OpShowDir, OpDontClose = 1,2,3,4,5,6
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

local function DoMenu(pattern)
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

  local props = {
      Title = Msg.AppTitle;
      Bottom = use_filter and "" or Msg.MenuBottom;
      Flags = bit64.bor(F.FMENU_AUTOHIGHLIGHT, F.FMENU_WRAPMODE)
    }

  local brkeys = not use_filter and {
      { BreakKey = "INSERT";  Op = OpInsert;  },
      { BreakKey = "DELETE";  Op = OpDelete;  },
      { BreakKey = "F4";      Op = OpEdit;    },
      { BreakKey = "C+L";     Op = OpShowDir; },
    }

  local item, position = far.Menu(props, menuitems, brkeys)

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

local function EditEntry(aEntry)
  local sd = require "far2.simpledialog"
  local Entries

  if not aEntry then
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

  local function insert_item(out)
    Entries = Entries or LoadEntries()
    for i,v in ipairs(Entries) do
      if v.alias:lower() == out.alias:lower() then
        if not aEntry then -- inserting a new record
          local text = Msg.OverwriteQuery:format(v.alias)
          if 1 ~= far.Message(text, Msg.AppTitle, Msg.BtnYesNo, "w") then
            return false
          end
        end
        table.remove(Entries, i)
        break
      end
    end
    table.insert(Entries, {
          File     = out.File;
          Param    = out.Param;
          PluginId = aEntry.PluginId;
          alias    = out.alias;
          path     = out.path;
        })
    SaveEntries(Entries)
    return true
  end

  Items.proc = function(hDlg, msg, par1, par2)
    if msg == F.DN_CLOSE then
      if par2.alias == "" or par2.path == "" then
        ErrorMsg(Msg.EmptyFields)
        return 0
      end
      if not insert_item(par2) then
        return 0
      end
    end
  end

  sd.New(Items):Run()
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
  local op, entry = DoMenu(text)
  while op do
    if op == OpSetDir then
      SetPanelDir(entry)
      break
    elseif op == OpInsert  then EditEntry(nil)
    elseif op == OpDelete  then RemoveEntry(entry)
    elseif op == OpEdit    then EditEntry(entry)
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
  description = "Named Folders";
  area="Shell"; key=MacroKey;
  action=function() Main(); end;
}
