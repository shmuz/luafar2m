local F = far.Flags

local function InsertTimestamp()
  local ar = far.MacroGetArea()
  if ar~=F.MACROAREA_SHELL and ar~=F.MACROAREA_DIALOG and ar~=F.MACROAREA_EDITOR
    then return; end
  local items = {
      { Pat="%Y-%m-%d"            },
      { Pat="%Y-%m-%d, %a"        },
      { Pat="%Y-%m-%d %H:%M"      },
      { Pat="%Y-%m-%d %H:%M:%S"   },
      { Pat="[%Y-%m-%d]"          },
      { Pat="[%Y-%m-%d, %a]"      },
      { Pat="[%Y-%m-%d %H:%M]"    },
      { Pat="[%Y-%m-%d %H:%M:%S]" },
    }
  for i,v in ipairs(items) do v.text="&"..i..". "..os.date(v.Pat) end
  local item = far.Menu({Title="Insert Timestamp"}, items)
  if not item then return end
  local s = ( [[
    %%ts = %q;
    %%comment = "far.Guids.MakeFolderId";
    $If (Dialog && Dlg.Info.Id == "{FAD00DBE-3FFF-4095-9232-E1CC70C67737}")
      %%ts = replace(%%ts, ":", "-");
    $End
    print(%%ts) ]] ):format(os.date(item.Pat))
  far.MacroPost(s)
end
AddCommand("timestamp", InsertTimestamp)

-- original: "Макросы для редактора Журко"
-- key='ShiftBS'; area='Common';
-- description='XLat: QWERTY-ЙЦУКЕН выделения или слова и смена языка ввода ОС';
local function XLat()
  if not Object.Selected then Keys('SelWord') end
  Keys('XLat')
  mf.xlat('', 1)
end
