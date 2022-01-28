-- coding: utf-8
-- started: 2022-01-20

local ini = require "inifile"
local mdialog = require "scripts.macrodialog"

local mfile = os.getenv("HOME") .. "/.config/far2l/settings/key_macros.ini"
local cfg = ini.New(mfile, "nocomment")
local items = {}
for sec in cfg:sections() do
  local name, area, key = sec.name:match("^(%w+)/(%w+)/(%w+)")
  if name and name:lower()=="keymacros" then
    local descr = cfg:GetString(sec.name, "Description") or "<no description>"
    local seq = cfg:GetString(sec.name, "Sequence") or "<no sequence>"
    local txt = ("%-12s│ %-16s│ %s"):format(area, key, descr)
    table.insert(items, {text=txt; columns={area,key,descr,seq}; section=sec; })
  end
end

local Title = "Macro Browser"
local props = { Title=Title, Bottom="Sort: CtrlF1/F2/F3" }
local bkeys = {
  {BreakKey = "C+F1"; sortcol=1; },
  {BreakKey = "C+F2"; sortcol=2; },
  {BreakKey = "C+F3"; sortcol=3; },
  {BreakKey = "F4";   edit=1; },
}

local Col, Rev = 1, false
local function sort_items()
  table.sort(items,
    function(a,b)
      if Rev then return a.columns[Col] > b.columns[Col]
      else return a.columns[Col] < b.columns[Col]
      end
    end)
    props.Title = ("%s [ %d%s ]"):format(Title,Col,Rev and "↓" or "↑")
end

sort_items()
while true do
  local item,pos = far.Menu(props, items, bkeys)
  if not item then break; end
  props.SelectIndex = pos
  if item.sortcol then
    if item.sortcol == Col then Rev = not Rev
    else Col,Rev = item.sortcol,false
    end
    sort_items()
    props.SelectIndex = 1
  elseif (item.section or item.edit) and pos >= 1 then
    local sec = items[pos].section
    local data = sec:dict()
    local area,key = sec.name:match("KeyMacros/(%w+)/(%w+)")
    if area then
      data.WorkArea, data.MacroKey = area, key
      mdialog(data)
    end
  end
end
--cfg:write(mfile..".backup")
