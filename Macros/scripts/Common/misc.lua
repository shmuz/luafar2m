Macro {
  id="F44159F4-556B-4593-A28B-EF3FD0B34FBE";
  id="D51070D3-3E54-4721-ACE8-8CBB061B3FFF";
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
  id="BFC9624A-51AA-475C-B30E-3ECB8A73D22B";
  id="9BABCF7F-A748-484D-915F-5E17BD83E087";
  description="Macro Browser";
  area="Common"; key="AltShiftF1";
  action=function() Plugin.Call(0x4EBBEFC8, "browser") end;
}

Macro {
  id="71A8298A-0237-429D-83F3-FC8EB5630979";
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
  id="D4CFCC5C-ABD3-4C25-8245-621990382224";
  id="2A8F9E8C-9503-47EF-A7BD-E45D0DE6C82F";
  description="Lua Calculator";
  area="Common"; key="CtrlShiftF4";
  action=function() mf.acall(require("far2.calc")); end;
}

Macro {
  id="00B425EF-B832-426A-BC8C-04F22E5FA3AC";
  id="32903C43-95FD-409B-AAF1-A05E20CA51FA";
  area="Common"; key="Ctrl/"; description="Получение названия клавиши. © SimSU";
  action = function()
    local rus = win.GetEnv("farlang")=="Russian"
    far.Message(rus and " Нажмите клавишу... " or " Press key... ","","")
    local VK=mf.waitkey(0,1)
    VK = far.InputBox(nil, rus and "Название клавиши" or "Key name",
      (rus and "Код клавиши: %d (0x%X)" or "Key code: %d (0x%X)"):
      format(VK,VK), nil, mf.key(VK))
    if VK then print(VK) end
  end;
}

Macro {
  id="4244A0FA-CFD6-4905-B266-D5235AD81990";
  id="C2466A13-A65D-46A0-BA7C-408FD1C762D5";
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

