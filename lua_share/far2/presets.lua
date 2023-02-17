-- luacheck: globals far win
local sett = require "far2.settings"
local F = far.Flags

local ENG = {
  BtnYesNo                  = "&Yes;&No";
  Confirm                   = "Confirm";
  DeletePreset              = "Delete preset";
  EnterPresetName           = "Enter preset's name";
  ErrorTitle                = "Error";
  PresetExportFailure       = "Could not save the file";
  PresetExportPrompt        = "Enter file name:";
  PresetExportSuccess       = "Presets have been exported";
  PresetExportTitle         = "Export Presets";
  PresetImportDataNotTable  = "Data to be imported must be a a table";
  PresetImportPrompt        = "Enter file name:";
  PresetImportTitle         = "Import Presets";
  PresetOverwrite           = "A preset with target name already exists and will be overwritten.\nOverwrite?";
  PresetOverwriteQuery      = "already exists. Overwrite?";
  PresetWasSaved            = "The current preset has been saved";
  RenamePreset              = "Rename Preset";
  SavePreset                = "Save Preset";
  TitlePresets              = "Presets";
  Warning                   = "Warning";
}

local RUS = {
  BtnYesNo                  = "&Да;&Нет";
  Confirm                   = "Подтверждение";
  DeletePreset              = "Удалить схему";
  EnterPresetName           = "Введите имя схемы";
  ErrorTitle                = "Ошибка";
  PresetExportFailure       = "Ошибка при сохранении файла";
  PresetExportPrompt        = "Введите имя файла:";
  PresetExportSuccess       = "Схемы были экспортированы";
  PresetExportTitle         = "Экспорт схем";
  PresetImportDataNotTable  = "Импортируемая величина должна быть таблицей";
  PresetImportPrompt        = "Введите имя файла:";
  PresetImportTitle         = "Импорт схем";
  PresetOverwrite           = "Схема с данным именем уже существует и будет перезаписана.\nПерезаписать?";
  PresetOverwriteQuery      = "уже существует. Перезаписать?";
  PresetWasSaved            = "Текущая схема сохранена";
  RenamePreset              = "Переименовать схему";
  SavePreset                = "Сохранить схему";
  TitlePresets              = "Схемы";
  Warning                   = "Предупреждение";
}

local function ErrorMsg(msg)
  far.Message(msg, "Error", nil, "w")
end

local function DoPresets (
  Dlg,             -- simple dialog instance
  hDlg,            -- dialog handle
  Presets,         -- _Plugin.History:field("Presets")
  HistPresetNames, -- _Plugin.DialogHistoryPath .. "Presets"
  HelpTopic,       -- help topic for the menu
  SaveHistory      -- function
)
  local M = win.GetEnv("FARLANG")=="Russian" and RUS or ENG
  ErrorMsg = function(msg) far.Message(msg, M.ErrorTitle, nil, "w") end

  hDlg:send("DM_SHOWDIALOG", 0)
  local props = { Title=M.TitlePresets; Bottom = "F1"; HelpTopic=HelpTopic or "Presets"; }
  local bkeys = {
    { action="save"   ; BreakKey="F2"     ; },
    { action="saveas" ; BreakKey="INSERT" ; },
    { action="delete" ; BreakKey="DELETE" ; },
    { action="rename" ; BreakKey="F6"     ; },
    { action="export" ; BreakKey="C+S"    ; },
    { action="import" ; BreakKey="C+O"    ; },
  }

  while true do
    local items = {}
    for name, preset in pairs(Presets) do
      local t = { text=name, preset=preset }
      items[#items+1] = t
      if name == Dlg.PresetName then t.selected,t.checked = true,true; end
    end
    table.sort(items, function(a,b) return win.CompareString(a.text,b.text,nil,"cS") < 0; end)
    local item, pos = far.Menu(props, items, bkeys)
    if not item then break end
    ----------------------------------------------------------------------------
    if item.preset then
      Dlg.PresetName = item.text
      Dlg:SetDialogState(hDlg, item.preset)
      break
    ----------------------------------------------------------------------------
    elseif item.action == "save" or item.action == "saveas" then
      local old_name = item.action == "save" and Dlg.PresetName
      local new_name = old_name or
        far.InputBox(nil, M.SavePreset, M.EnterPresetName, HistPresetNames,
                     Dlg.PresetName, nil, nil, F.FIB_NOUSELASTHISTORY)
      if new_name then
        if old_name or not Presets[new_name] or
          far.Message(M.PresetOverwrite, M.Confirm, M.BtnYesNo, "w") == 1
        then
          Presets[new_name] = Dlg:GetDialogState(hDlg)
          Dlg.PresetName = new_name
          SaveHistory()
          if old_name then
            far.Message(M.PresetWasSaved, M.TitlePresets)
            break
          end
        end
      end
    ----------------------------------------------------------------------------
    elseif item.action == "delete" and items[1] then
      local name = items[pos].text
      local msg = ([[%s "%s"?]]):format(M.DeletePreset, name)
      if far.Message(msg, M.Confirm, M.BtnYesNo, "w") == 1 then
        if Dlg.PresetName == name then
          Dlg.PresetName = nil
        end
        Presets[name] = nil
        SaveHistory()
      end
    ----------------------------------------------------------------------------
    elseif item.action == "rename" and items[1] then
      local oldname = items[pos].text
      local name = far.InputBox(nil, M.RenamePreset, M.EnterPresetName, HistPresetNames, oldname)
      if name and name ~= oldname then
        if not Presets[name] or far.Message(M.PresetOverwrite, M.Confirm, M.BtnYesNo, "w") == 1 then
          if Dlg.PresetName == oldname then
            Dlg.PresetName = name
          end
          Presets[name], Presets[oldname] = Presets[oldname], nil
          SaveHistory()
        end
      end
    ----------------------------------------------------------------------------
    elseif item.action == "export" and items[1] then
      local fname = far.InputBox(nil, M.PresetExportTitle, M.PresetExportPrompt)
      if fname then
        fname = far.ConvertPath(fname)
        if not win.GetFileAttr(fname) or 1==far.Message(
          fname.."\n"..M.PresetOverwriteQuery, M.Warning, ";YesNo", "w")
        then
          local fp = io.open(fname, "w")
          if fp then
            fp:write("local Presets\n", serial.SaveToString("Presets",Presets), "\nreturn Presets")
            fp:close()
            far.Message(M.PresetExportSuccess, M.TitlePresets)
          else
            ErrorMsg(M.PresetExportFailure)
          end
        end
      end
    ----------------------------------------------------------------------------
    elseif item.action == "import" then
      local fname = far.InputBox(nil, M.PresetImportTitle, M.PresetImportPrompt)
      if fname then
        local func, msg = loadfile(far.ConvertPath(fname))
        if func then
          local t = setfenv(func, {})()
          if type(t) == "table" then
            for k,v in pairs(t) do
              if type(k)=="string" and type(v)=="table" then
                if not Presets[k] then
                  Presets[k] = v
                else
                  local root = k:match("%(%d+%)(.*)") or k
                  for m=1,1000 do
                    local k2 = ("(%d)%s"):format(m, root)
                    if not Presets[k2] then
                      Presets[k2] = v; break
                    end
                  end
                end
              end
            end
            SaveHistory()
          else
            ErrorMsg(M.PresetImportDataNotTable)
          end
        else
          ErrorMsg(msg)
        end
      end
    ----------------------------------------------------------------------------
    end
  end
  hDlg:send("DM_SHOWDIALOG", 1)
end

return DoPresets
