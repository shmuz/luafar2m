-- coding: utf-8
-- started: 2022-01-20

local ini = require "inifile"
local mfile = os.getenv("HOME") .. "/.config/far2l/settings/key_macros.ini"
local cfg = ini.New(mfile, "nocomment")
local items = {}
for sec in cfg:sections() do
  local name, area, key = sec.name:match("^(%w+)/(%w+)/(%w+)")
  if name and name:lower()=="keymacros" then
    local descr = cfg:GetString(sec.name, "Description") or "<no description>"
    local seq = cfg:GetString(sec.name, "Sequence") or "<no sequence>"
    local txt = ("%-12s│ %-16s│ %s"):format(area, key, descr)
    table.insert(items, {text=txt; data={area,key,descr,seq}; })
  end
end

local Title = "Macro Browser"
local props = { Title=Title, Bottom="Sort: CtrlF1/F2/F3" }
local bkeys = {
  {BreakKey = "C+F1"; sort=1; },
  {BreakKey = "C+F2"; sort=2; },
  {BreakKey = "C+F3"; sort=3; },
}

local col, rev = 1, false
local function sort()
  table.sort(items,
    function(a,b)
      if rev then return a.data[col] > b.data[col]
      else return a.data[col] < b.data[col]
      end
    end)
    props.Title = ("%s [ %d%s ]"):format(Title,col,rev and "↓" or "↑")
end

sort()
while true do
  local item,pos = far.Menu(props, items, bkeys)
  if not item then break; end
  if item.sort then
    if item.sort == col then rev = not rev
    else col,rev = item.sort,false
    end
    sort()
  end
end
