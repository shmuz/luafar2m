-- coding: utf-8
--[[
Author: Maxim Gonchar
Modifications: Shmuel Zeigerman
URL: https://forum.farmanager.com/viewtopic.php?f=15&t=9990#p134643

Скрипт реализует фильтр панели. Действие скрипта аналогично действию плагина panelfilter от jbak.
--]]

-- Parameters of Filter configuration dialog: update them whenever the dialog is redesigned
local FC_PosName, FC_PosMask, FC_PosAttrDir, FC_ItemCount = 3, 6, 34, 71

-- Settings
local MacroKey = "CtrlShiftS"
local ToggleFoldersKey = "CtrlF"
local ToggleSubstringKey = "CtrlS"
local bFilterFolders = true
local bSubstring = true
-- /Settings

local FilterName = "_luafilter_"
local F = far.Flags
local redirect_keys = { Ins=1, Up=1, Down=1, PgUp=1, PgDn=1, Home=1, End=1 }
local Filter -- forward declaration
local EditPos = 2
local Mask, Coord = "", nil

local function ShowHelp()
  local Eng = [[
After starting the filter, an area appears above the panel
(above the .. item) displaying the current state of the filter.
Filtering of panel elements is performed after adding any symbol
to the filter. [Esc] exits the filtering mode, turns off and
deletes the filter. [Enter] closes the dialog, but leaves the
filter on.

Either files and folders or just files can be filtered.
Mode switching is done with [{FoldersKey}] when editing a filter.
Indicator: 'F' = "files and folders"; 'f' = "files only".

The filter string may be treated either as a substring in file
name or as a file mask. Mode switching is done with [{SubstringKey}]
when editing a filter.
Indicator: 'S' = "substring"; 's' = "file mask".]]

  local Rus = [[
После запуска фильтра над панелью (над пунктом ..) появляется
область, отображающая текущее состояние фильтра. Фильтрация
элементов панели осуществляется после добавления к фильтру любого
символа. [Esc] выходит из режима фильтрации, выключает и удаляет
фильтр. [Enter] закрывает диалог, но оставляет фильтр включенным.

Фильтроваться могут либо файлы и папки, либо только файлы. Переключение
осуществляется ключом [{FoldersKey}] при редактировании фильтра.
Индикатор: 'F' = "файлы и папки"; 'f' = "только файлы".

Введенный текст интерпретируется либо как подстрока в имени файла,
либо как маска файла. Переключение осуществляется ключом [{SubstringKey}]
при редактировании фильтра.
Индикатор: 'S' = "подстрока"; 's' = "маска файла".]]

  local lang = Far.GetConfig("Language.Help")
  local txt = lang == "Russian" and Rus or Eng
  txt = txt:gsub("{FoldersKey}", ToggleFoldersKey):gsub("{SubstringKey}", ToggleSubstringKey)
  local title = lang=="Russian" and "Фильтр панели, справка" or "Panel filter help"
  far.Message(txt, title, ";OK", "l")
end

local function FiltersConfig(key)
  Keys(key)
  assert(Dlg.Id == far.Guids.FiltersConfigId, "Wrong Dialog Id")
  assert(Dlg.ItemCount == FC_ItemCount,
    "The FiltersConfig dialog was redesigned, this macro must be corrected")
end

local function SetText(pos, text)
  Dlg.SetFocus(pos)
  Keys("CtrlY")
  print(text)
end

local function DelFilter()
  Mask = ""
  Keys("CtrlI")
  if Menu.Select(FilterName,1) > 0 then
    Keys("Del Enter")
  end
  Keys("Esc")
end

local function GetFilter()
  local mask
  Keys("CtrlI")
  if Menu.Select(FilterName,1) > 0 then
    FiltersConfig("F4")
    local v = Dlg.GetValue(FC_PosMask,0)
    mask = bSubstring and v:match("^%*?(.-)%*?$") or v
    Keys("Esc")
  end
  Keys("Esc")
  return mask
end

local function UpdateFilter()
  Keys("Enter")
  if Mask=="" then
    DelFilter()
  else
    Keys("CtrlI")
    local pos = Menu.Select(FilterName,1)
    if pos == 0 then
      FiltersConfig("Ins")
      SetText(FC_PosName, FilterName)
    else
      FiltersConfig("F4")
    end
    Dlg.SetFocus(FC_PosAttrDir)
    Keys(bFilterFolders and "Multiply" or "Subtract")

    local dMask = bSubstring and ("*"..Mask.."*") or Mask
    dMask = far.CheckMask(dMask) and dMask or "|*"
    SetText(FC_PosMask, dMask)

    Keys("Enter BS Up + Enter")
  end
  return Filter()
end

local function ProcessKey(keyname)
  Keys("Enter")
  Keys(keyname)
  return Filter()
end

local function dlg_handler(hDlg, msg, p1, p2)
  if msg == F.DN_INITDIALOG then
    hDlg:EditUnchangedFlag(EditPos, 0)
    if Coord then hDlg:SetCursorPos(EditPos, Coord) end
    mf.postmacro(hDlg.SetSelection, hDlg, EditPos, {BlockType=0}) -- neutralize DlgSelect plugin
  elseif msg == F.DN_EDITCHANGE then
    Mask = p2[10]
    Coord = hDlg:GetCursorPos(EditPos)
    mf.postmacro(UpdateFilter)
  elseif msg == F.DN_KEY then
    local keyname = far.KeyToName(p2)
    if keyname == "Esc" then
      mf.postmacro(DelFilter)
    elseif keyname == "F1" then
      ShowHelp()
    elseif keyname == ToggleFoldersKey then
      bFilterFolders = not bFilterFolders
      mf.postmacro(UpdateFilter)
    elseif keyname == ToggleSubstringKey then
      bSubstring = not bSubstring
      mf.postmacro(UpdateFilter)
    elseif redirect_keys[keyname] then
      Coord = hDlg:GetCursorPos(EditPos)
      mf.postmacro(ProcessKey, keyname)
    end
  end
end

Filter = function()
  local guid = win.Uuid("1d150046-d526-47b5-b35b-7856c8861a4e")
  local state = { "DI_TEXT",0,0, 3,0,  0,  "","",0,"" } -- indicator
  local item  = { "DI_EDIT",4,0,20,0,  0,  "","",0,"" }
  local flags = { FDLG_SMALLDIALOG=1, FDLG_NODRAWSHADOW=1, FDLG_NODRAWPANEL=1 }
  local rect = panel.GetPanelInfo(nil, 1).PanelRect
  item[4] = rect.right-rect.left-2
  item[10] = Mask
  state[10] = ("[%s%s]"):format(bFilterFolders and "F" or "f", bSubstring and "S" or "s")
  far.Dialog(guid, rect.left+1, rect.top+1, rect.right-1, rect.top+1, nil,
             {state,item}, flags, dlg_handler)
end

Macro {
  description="Panel Filter";
  id="53F8A531-F64F-476B-9793-FBF74792AB0D";
  area="Shell"; key=MacroKey;
  condition=function() return APanel.Visible end;
  action=function()
    Coord = nil
    Mask = GetFilter() or ""
    Filter()
  end;
}
