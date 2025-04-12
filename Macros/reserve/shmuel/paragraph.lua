-- Author: Shmuel Zeigerman
-- Started: 2023-01-12
-- Published in: Telegram messenger
-- https://t.me/FarManager/1/6068
-- https://t.me/FarManager/1/6071
-- https://t.me/FarManager/1/6075

Macro {
  description="Jump to next paragraph";
  area="Editor"; key="F1";
  action=function()
    local found
    local info=editor.GetInfo()
    for k=info.CurLine,info.TotalLines do
      local str = editor.GetString(nil,k,3)
      if found then
        if str:find("%S") then
          editor.SetPosition(nil,k,1); break
        end
      else
        if str:find("^%s*$") then found=true end
      end
    end
  end;
}

Macro {
  description="Jump to previous paragraph";
  area="Editor"; key="F12";
  action=function()
    local found
    local info=editor.GetInfo()
    for k=info.CurLine,1,-1 do
      local str = editor.GetString(nil,k,3)
      if found then
        if str:find("%S") then found=nil end
      else
        if str:find("^%s*$") then
          if k+1 < info.CurLine then
            editor.SetPosition(nil,k+1,1); return
          end
          found=true
        end
      end
    end
    editor.SetPosition(nil,1,1)
  end;
}

Macro {
  description="Select current paragraph";
  area="Editor"; key="CtrlShiftU";
  action=function()
    local info=editor.GetInfo()
    local str=editor.GetString(nil,info.CurLine,3)
    if not str:find("%S") then return end
    local line1,line2 = 1,info.TotalLines
    for k=info.CurLine-1,1,-1 do
      str=editor.GetString(nil,k,3)
      if not str:find("%S") then line1=k+1 break end
    end
    for k=info.CurLine+1,info.TotalLines do
      str=editor.GetString(nil,k,3)
      if not str:find("%S") then line2=k-1 break end
    end
    editor.Select(nil,"BTYPE_STREAM",line1,1,-1,line2-line1+1)
  end;
}

