-- started: 2023-05-06
local inifile = require "inifile"
local sdialog = require "far2.simpledialog"

local function EditItem(aName, aVal)
  local Items = {
    {tp="dbox"; text="Groups of file masks"; },
    {tp="text"; text="&Name:"; },
    {tp="edit"; text=aName; name="name"; },
    {tp="text"; text="A file &mask or several file masks:"; },
    {tp="edit"; text=aVal; name="val"; },
    {tp="sep"; },
    {tp="butt"; text="OK";     centergroup=1; default=1; },
    {tp="butt"; text="Cancel"; centergroup=1; cancel=1;  },
  }
  local Dlg=sdialog.New(Items)
  local out = Dlg:Run()
  if out then return out.name, out.val end
end

local function Trim(txt)
  return txt:match("%s*(.-)%s*$")
end

local function CreateMenuItem(name, val)
  local s = ("%-11s│ %s"):format(name,val)
  return { text=s; Name=name; Val=val; }
end

local function main()
  local filename = far.InMyConfig("settings/masks.ini")
  local Ini = inifile.New(filename, true)
  local Sec = Ini:add_section("Masks")

  local Props = { Title="Groups of file masks"; Bottom="F4 Ins Del"; }
  local Items = {}
  local Bkeys = {
    {BreakKey="F4";  action="edit";   },
    {BreakKey="Ins"; action="insert"; },
    {BreakKey="Del"; action="delete"; },
  }
  for k,v in Sec:records() do
    table.insert(Items, CreateMenuItem(k,v))
  end

  local WasEdited
  while true do
    table.sort(Items, function(a,b) return a.Name:lower() < b.Name:lower() end)
    local item,pos = far.Menu(Props, Items, Bkeys)
    if not item then
      if not WasEdited then break end
      local choice = far.Message("Do you want to save the changes?", "Save", ";YesNoCancel", "w")
      if choice == 1  then
        Sec:clear()
        for _,v in ipairs(Items) do Sec:set(v.Name, v.Val) end
        Ini:write(filename)
        break
      elseif choice == 2 then
        break
      end
    elseif item.action==nil or item.action=="edit" then
      if pos > 0 then
        local name,val = EditItem(Items[pos].Name, Items[pos].Val)
        if name then
          name,val = Trim(name),Trim(val)
          if name~="" and val~="" then
            Items[pos] = CreateMenuItem(name,val)
            WasEdited = true
          end
        end
      end
    elseif item.action=="insert" then
      local name,val = EditItem("", "")
      if name then
        name,val = Trim(name),Trim(val)
        if name~="" and val~="" then
          table.insert(Items, CreateMenuItem(name,val))
          WasEdited = true
        end
      end
    elseif item.action=="delete" then
      if pos > 0 then
        table.remove(Items, pos)
        WasEdited = true
      end
    end
  end
end

Macro {
  description="Groups of file masks";
  area="Shell"; key="AltShiftF5";
  action=main;
}
