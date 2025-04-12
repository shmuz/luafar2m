-- Started:    2025-04-11, by Shmuel Zeigerman
-- Published:  2025-04-11, at https://t.me/FarManager/19406
-- Goal:       Select all files whose size is not unique within the panel
-- Language:   Lua 5.1
-- Category:   Far Manager macro
-- Works on:   Windows: Far Manager >= "3.0.3008"
-- Works on:   Linux: far2m >= "2024-02-08"

Macro {
  area="Shell"; key="F1";
  action=function()
    local cache, list = {}, {}
    local inf = panel.GetPanelInfo(nil,1)
    for i=1, inf.ItemsNumber do
      local it = panel.GetPanelItem(nil,1,i)
      if not it.FileAttributes:find("d") then
        if cache[it.FileSize] then
          if cache[it.FileSize] > 0 then
            list[#list+1] = cache[it.FileSize]
            cache[it.FileSize] = -1
          end
          list[#list+1] = i
        else
          cache[it.FileSize] = i
        end
      end
    end
    panel.SetSelection(nil,1,list,true)
    panel.RedrawPanel(nil,1)
  end;
}
