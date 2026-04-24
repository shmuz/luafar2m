-- started: 2013-12-14
-- http://forum.farmanager.com/viewtopic.php?p=115210#p115210

local Sep = package.config:sub(1,1)
local Patt = ("(.*)%s[^%s]+$"):format(Sep,Sep)

local function FillTable(t, path)
  while true do
    path = path:match(Patt)
    if path==nil then break end
    t[#t+1] = {path=path..Sep}
  end
end

local function ToRadix36(k)
  return k < 10 and "&"..tostring(k)
      or k < 36 and "&"..string.char(k - 10 + ("A"):byte())
      or " "
end

local function ShowMenu()
  local items = {}
  if APanel.Plugin then
    FillTable(items, APanel.Path)
    if items[1] then items[#items+1] = { separator=true } end
    items[#items+1] = { path=APanel.Path0 }
  end
  FillTable(items, APanel.Path0)
  if items[1] then
    local inum = 0
    for _,v in ipairs(items) do
      if v.path then
        local extra = v.path:len() - Far.Width + 11 -- use "+ 11" to handle scrollbar too
        v.text = extra<=0 and v.path or "..."..v.path:sub(extra+4)
        v.text = ToRadix36(inum) .. " " .. v.text
        inum = inum + 1
      end
    end
    local item = far.Menu({Title="Go to ..."}, items)
    if item then Panel.SetPath(0, item.path) end
  end
end

Macro {
  description="Menu with list of parent directories (CD up)";
  area="Shell"; key="CtrlBS";
  condition=function() return CmdLine.Empty and APanel.Visible end;
  action=ShowMenu;
}
