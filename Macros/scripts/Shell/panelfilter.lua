-- coding: utf-8
--[[
Author: Maxim Gonchar
Modifications: Shmuel Zeigerman
URL: https://forum.farmanager.com/viewtopic.php?f=15&t=9990#p134643

Скрипт реализует фильтр панели. Действие скрипта аналогично действию плагина panelfilter от jbak.

Как это работает:
    После запуска фильтра над панелью (над пунктом ..) появляется область, отображающая текущее состояние фильтра.
    Фильтрация элементов панели осуществляется после добавления к фильтру любого символа.
    Esc выходит из режима фильтрации, выключает и удаляет фильтр.
    Enter закрывает диалог, но оставляет фильтр включенным.

    После любого изменения строки фильтра скрипт закрывает свой диалог и вызывает список фильтров,
    создает/изменяет фильтр _luafilter_ и вызывает свой диалог снова.
--]]

if not mf.postmacro then return end

local FilterName = "_luafilter_"
local MacroKey = "CtrlShiftS"

local F = far.Flags
local OffsMask, OffsAttrDir = 2, 11
local redirect_keys = { Ins=1, Up=1, Down=1, PgUp=1, PgDn=1, Home=1, End=1 }
local Mask, Coord = "", nil
local Filter -- forward declaration
local EditPos = 1

local function FiltersConfig(key)
  Keys(key)
  assert(Dlg.Id == far.Guids.FiltersConfigId, "Wrong Dialog Id")
  assert(Dlg.ItemCount == 71, "The FiltersConfig dialog was redesigned, this macro must be corrected")
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
  local mask = ""
  Keys("CtrlI")
  if Menu.Select(FilterName,1) > 0 then
    FiltersConfig("F4")
    for _=1,OffsMask do Keys("Tab") end
    local v = Dlg.GetValue(-1)
    if type(v)=="string" then mask=v:match("^%*?(.-)%*?$") end
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
      Keys("CtrlY")
      print(FilterName)
      for _=1,OffsAttrDir do Keys("Tab") end
      Keys("Space Space Home")
    else
      FiltersConfig("F4")
    end
    for _=1,OffsMask do Keys("Tab") end
    Keys("CtrlY")
    print("*"..Mask.."*")
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
    if keyname=="Esc" then
      mf.postmacro(DelFilter)
    elseif redirect_keys[keyname] then
      Coord = hDlg:GetCursorPos(EditPos)
      mf.postmacro(ProcessKey, keyname)
    end
  end
end

Filter = function()
  local guid = win.Uuid("1d150046-d526-47b5-b35b-7856c8861a4e")
  local item = { "DI_EDIT",0,0,20,0,  0,  "","",0,"" }
  local flags = { FDLG_SMALLDIALOG=1, FDLG_NODRAWSHADOW=1, FDLG_NODRAWPANEL=1 }
  local rect = panel.GetPanelInfo(nil, 1).PanelRect
  item[4] = rect.right-rect.left-2
  item[10] = Mask
  far.Dialog(guid, rect.left+1, rect.top+1, rect.right-1, rect.top+1, nil,
             {item}, flags, dlg_handler)
end

Macro {
  description="Panel Filter";
  id="53F8A531-F64F-476B-9793-FBF74792AB0D";
  area="Shell"; key=MacroKey;
  condition=function() return APanel.Visible end;
  action=function()
    Coord = nil
    Mask = GetFilter()
    Filter()
  end;
}
