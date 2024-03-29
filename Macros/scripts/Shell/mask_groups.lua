-- Started: 2023-05-06
-- Depends on modules: inifile, far2.simpledialog

local F = far.Flags

local function Trim(txt)
  return txt:match("%s*(.-)%s*$")
end

local function EditItem(aName, aVal, aGuard)
  local sdialog = require "far2.simpledialog"
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

  local function closeaction(hDlg, Par1, tOut)
    local name,val = Trim(tOut.name),Trim(tOut.val)
    if name=="" or val=="" then
      far.Message("Either Name or Mask is empty", "Error", nil, "w")
      return 0
    elseif name ~= aName and aGuard[name] then
      far.Message(("The entry '%s' already exists"):format(name), "Error", nil, "w")
      return 0
    end
  end

  Items.proc = function(hDlg, Msg, Par1, Par2)
    if Msg == F.DN_CLOSE then
      return closeaction(hDlg, Par1, Par2)
    end
  end

  local Dlg=sdialog.New(Items)
  local out = Dlg:Run()
  if out then
    local name,val = Trim(out.name),Trim(out.val)
    if name ~= aName then
      aGuard[aName] = nil
      aGuard[name] = true
    end
    return name, val
  end
end

local function CreateMenuItem(name, val)
  local s = ("%-11s│ %s"):format(name,val)
  return { text=s; Name=name; Val=val; }
end

local function main()
  local inifile = require "inifile"
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
  local Guard = {}
  for k,v in Sec:records() do
    table.insert(Items, CreateMenuItem(k,v))
    Guard[k] = true
  end

  local WasEdited
  while true do
    table.sort(Items, function(a,b) return a.Name:lower() < b.Name:lower() end)
    local item,pos = far.Menu(Props, Items, Bkeys)
    Props.SelectIndex = pos
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
        local name,val = EditItem(Items[pos].Name, Items[pos].Val, Guard)
        if name then
          Items[pos] = CreateMenuItem(name,val)
          WasEdited = true
        end
      end
    elseif item.action=="insert" then
      local name,val = EditItem("", "", Guard)
      if name then
        table.insert(Items, CreateMenuItem(name,val))
        WasEdited = true
      end
    elseif item.action=="delete" then
      if pos > 0 then
        if 1==far.Message("Are you sure?", "Delete a named mask", ";OkCancel", "w") then
          local name = Items[pos].Name
          table.remove(Items, pos)
          Guard[name] = nil
          WasEdited = true
        end
      end
    end
  end
end

Macro {
  description="Groups of file masks";
  area="Shell"; key="AltShiftF5";
  action=main;
}
