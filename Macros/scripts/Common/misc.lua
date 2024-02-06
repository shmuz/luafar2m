Macro {
  description="Reload macros";
  area="Common"; key="CtrlShiftR";
  action=function()
    local msg = win.GetEnv("FARLANG")=="Russian" and "Перезагрузка макросов" or "Reload macros"
    far.Message(msg,"","")
    far.MacroLoadAll()
    win.Sleep(400)
    far.AdvControl("ACTL_REDRAWALL")
  end;
}

Macro {
  description="Macro Browser";
  area="Common"; key="AltShiftF1";
  action=function() Plugin.Call(0x4EBBEFC8, "browser") end;
}

Macro {
  description="Insert Timestamp";
  area="Shell Dialog Editor"; key="CtrlShiftT";
  id="EDB86ABD-C0C8-4EE8-B320-339E295446F0";
  action=function()
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
    local guid = "FAD00DBE-3FFF-4095-9232-E1CC70C67737" --far.Guids.MakeFolderId
    if Area.Dialog and Dlg.Id==guid then item.Pat = item.Pat:gsub(":","-") end
    print(os.date(item.Pat))
  end;
}

Macro {
  description="Lua Calculator";
  area="Common"; key="CtrlShiftF4";
  action=function() mf.acall(require("far2.calc")); end;
}

Macro {
  area="Common"; key="Ctrl/"; description="Получение названия клавиши. © SimSU";
  action = function()
    local rus = win.GetEnv("farlang")=="Russian"
    far.Message(rus and " Нажмите клавишу... " or " Press key... ","","")
    local VK=mf.waitkey(0,1)
    VK=prompt(rus and "Название клавиши" or "Key name",
      (rus and "Код клавиши: %d (0x%X)" or "Key code: %d (0x%X)"):
      format(VK,VK),0x01+0x10,mf.key(VK))
    if VK then print(VK) end
  end;
}

Macro {
  -- original: "Макросы для редактора Журко"
  key='ShiftBS'; area='Common';
  description='XLat: QWERTY-ЙЦУКЕН выделения или слова и смена языка ввода ОС';
  action=function()
    if not Object.Selected then Keys('SelWord') end
    Keys('XLat')
    mf.xlat('', 1)
  end;
}

NoMacro {
  description="Key logger";
  area="Common"; key="/.+/";
  condition=function(key) far.Log(key) end;
}

