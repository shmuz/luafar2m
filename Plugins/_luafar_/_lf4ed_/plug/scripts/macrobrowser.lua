-- coding: utf-8
-- started: 2022-01-20

local Title = "Macro Browser"
local ini = require "inifile"
local mdialog = require "scripts.macrodialog"
local mfile = os.getenv("HOME") .. "/.config/far2l/settings/key_macros.ini"
local cfg = ini.New(mfile, "nocomment")

local function MakeMenuItem(sec)
  local name, area, key = sec.name:match("^(%w+)/(%w+)/(%w+)")
  if name and name:lower()=="keymacros" then
    local descr = cfg:GetString(sec.name, "Description") or "<no description>"
    local seq = cfg:GetString(sec.name, "Sequence") or "<no sequence>"
    local txt = ("%-12s│ %-16s│ %s"):format(area, key, descr)
    return {text=txt; columns={area,key,descr,seq}; section=sec; }
  end
end

local function CreateItems()
  local Items = {}
  for sec in cfg:sections() do
    local item = MakeMenuItem(sec)
    if item then table.insert(Items,item) end
  end
  return Items
end

local Items = CreateItems()
local Props = { Title=Title, Bottom="F1, F4, ShiftF4, F8" }
local Bkeys = {
  {BreakKey = "C+F1"; sortcol=1; },
  {BreakKey = "C+F2"; sortcol=2; },
  {BreakKey = "C+F3"; sortcol=3; },
  {BreakKey = "F4";   edit=1;    },
  {BreakKey = "S+F4"; insert=1;  }, -- Ins
  {BreakKey = "F8";   delete=1;  }, -- Del
  {BreakKey = "F1";   help=1;    }, -- Help
}
local Col, Rev = 1, false

local function SortItems()
  local t = {} -- needed for stable sort
  for i,v in ipairs(Items) do t[v.section] = i; end

  table.sort(Items,
    function(a,b)
      if a.columns[Col] < b.columns[Col] then return not Rev end
      if a.columns[Col] > b.columns[Col] then return Rev end
      if t[a.section] < t[b.section] then return not Rev end
      return Rev
    end)
    Props.Title = ("%s [ %d%s ]"):format(Title,Col,Rev and "↓" or "↑")
end

local function SetSelected(section)
  for _,v in ipairs(Items) do
    v.selected = (v.section==section) or nil
  end
  SortItems()
end

local function RunMenu()
  local modified = false
  SortItems()
  while true do
    local item,pos = far.Menu(Props, Items, Bkeys)
    if not item then
      if modified then
        local r = far.Message("Do you want to save the changes?", Title, ";YesNoCancel", "w")
        if r == 1 then
          cfg:write(mfile)
          far.Timer(10, function(hnd) hnd:Close(); far.MacroLoadAll(); end) -- another bug in FAR ?
        end
        if r==1 or r==2 then
          break
        else
          item, pos = {}, 0
          SetSelected(nil)
        end
      else
        break
      end
    end

    if pos >= 1 then
      SetSelected(Items[pos].section)
    end
    --------------------------------------------------------------------------------------------
    if item.sortcol then -- sort requested
      if item.sortcol == Col then Rev = not Rev
      else Col,Rev = item.sortcol,false
      end
      SetSelected(nil)
    --------------------------------------------------------------------------------------------
    elseif item.delete and pos >= 1 then -- F8 pressed
      local fullname = Items[pos].section.name
      local shortname = fullname:match(".-/(.*)")
      local msg = ("Delete '%s' macro?"):format(shortname)
      if 1 == far.Message(msg, "Confirm", ";YesNo", "w") then
        cfg:del_section(fullname)
        Items = CreateItems()
        SetSelected(nil)
        modified = true
      end
    --------------------------------------------------------------------------------------------
    elseif (item.section or item.edit) and pos >= 1 then -- Enter or F4 pressed
      local sec = Items[pos].section
      local data = sec:dict()
      data.WorkArea, data.MacroKey = sec.name:match("KeyMacros/(%w+)/(%w+)")
      local out = mdialog(data)
      if out then
        local newname = ("KeyMacros/%s/%s"):format(out.WorkArea, out.MacroKey)
        if newname:lower() ~= sec.name:lower() then
          local sec_existing = cfg:get_section(newname)
          if sec_existing then
            local msg = "Replace the existing macro ["..newname.."] ?"
            if 1 == far.Message(msg, "Confirm", ";YesNo", "w") then
              cfg:del_section(sec.name)
              sec = sec_existing
            else
              sec = nil
            end
          else
            cfg:del_section(sec.name)
            sec = cfg:add_section(newname)
          end
        end

        if sec then
          sec:clear()
          out.WorkArea, out.MacroKey = nil, nil
          for k,v in pairs(out) do
            if type(v)=="number" then
              sec:set(k, ("0x%X"):format(v))
            else
              sec:set(k,v)
            end
          end
          Items = CreateItems()
          SetSelected(sec)
          modified = true
        end
      end
    --------------------------------------------------------------------------------------------
    elseif item.insert then -- ShiftF4 pressed
      local sec = nil
      local out = mdialog(nil)
      if out then
        local newname = ("KeyMacros/%s/%s"):format(out.WorkArea, out.MacroKey)
        local sec_existing = cfg:get_section(newname)
        if sec_existing then
          local msg = "Replace the existing macro ["..newname.."] ?"
          if 1 == far.Message(msg, "Confirm", ";YesNo", "w") then
            cfg:del_section(sec_existing.name)
            sec = cfg:add_section(newname)
          end
        else
          sec = cfg:add_section(newname)
        end

        if sec then
          out.WorkArea, out.MacroKey = nil, nil
          for k,v in pairs(out) do
            if type(v)=="number" then
              sec:set(k, ("0x%X"):format(v))
            else
              sec:set(k,v)
            end
          end
          Items = CreateItems()
          SetSelected(sec)
          modified = true
        end
      end
    --------------------------------------------------------------------------------------------
    elseif item.help then -- F1 pressed
    far.Message([[
F4, Enter - Edit a macro
ShiftF4   - Insert a new macro
F8        - Delete a macro
F1        - Help window
CtrlF1    - Sort by the 1-st column
CtrlF2    - Sort by the 2-nd column
CtrlF3    - Sort by the 3-rd column]],
"Help", nil, "l")
    --------------------------------------------------------------------------------------------
    end
  end
end

RunMenu()
