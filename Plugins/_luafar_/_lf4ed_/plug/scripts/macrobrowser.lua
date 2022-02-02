-- coding: utf-8
-- started: 2022-01-20

local Title = "Macro Browser"
local ini = require "inifile"
local mdialog = require "scripts.macrodialog"
local mfile = os.getenv("HOME") .. "/.config/far2l/settings/key_macros.ini"
local F = far.Flags

local cfg, msg1 = ini.New(mfile, "nocomment")
if not cfg then far.Message(msg1, Title, nil, "w"); return; end

local function MakeMenuItem(sec)
  local name, area, tilde, key = sec.name:match("^(%w+)/(%w+)/(~?)(%w+)")
  if name and name:lower()=="keymacros" then
    local descr = cfg:GetString(sec.name, "Description") or "<no description>"
    local seq = cfg:GetString(sec.name, "Sequence") or "<no sequence>"
    local txt = ("%-12s│ %-16s│ %s"):format(area, key, descr)
    tilde = tilde=="~" and "~" or nil
    return {text=txt; columns={area,key,descr,seq}; section=sec; checked=tilde; }
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
local Props = { Title=Title; Bottom="F1, F4, ShiftF4, F8, Space";
                Flags=F.FMENU_SHOWAMPERSAND+F.FMENU_WRAPMODE; }
local Bkeys = {
  {BreakKey = "C+F1";  sortcol=1;  },
  {BreakKey = "C+F2";  sortcol=2;  },
  {BreakKey = "C+F3";  sortcol=3;  },
  {BreakKey = "F4";    edit=1;     },
  {BreakKey = "S+F4";  insert=1;   },
  {BreakKey = "F8";    delete=1;   },
  {BreakKey = "F1";    help=1;     },
  {BreakKey = "SPACE"; activate=1; },
}
local Col, Rev = 1, false

local function CompareByCol(a, b, aCol)
  if a.columns[aCol] < b.columns[aCol] then return -1 end
  if a.columns[aCol] > b.columns[aCol] then return  1 end
  return 0
end

local function SortItems()
  -- This sort algorithm is stable because the combination of 1-st
  -- and 2-nd columns (area/key) cannot be the same for 2 macros.
  table.sort(Items,
    function(a,b)
      local res = 0
      if Col == 1 then     -- sort by 1-st then 2-nd col.
        for k=1,2 do
          res = CompareByCol(a,b,k)
          if res ~= 0 then break end
        end
      elseif Col == 2 then -- sort by 2-nd then 1-st col.
        for k=2,1,-1 do
          res = CompareByCol(a,b,k)
          if res ~= 0 then break end
        end
      elseif Col == 3 then -- sort by 3-rd then 1-st then 2-nd col.
        for i=1,3 do
          local k = i==1 and 3 or i==2 and 1 or 2
          res = CompareByCol(a,b,k)
          if res ~= 0 then break end
        end
      end
      if res < 0 then return not Rev end
      if res > 0 then return Rev end
      return false
    end)
    Props.Title = ("%s [ %d%s ]"):format(Title,Col,Rev and "↓" or "↑")
end

local function SetSelected(section)
  for _,v in ipairs(Items) do
    v.selected = (v.section==section) or nil
  end
end

local function RunMenu()
  local modified = false
  while true do
    SortItems()
    local item,pos = far.Menu(Props, Items, Bkeys)
    if not item then
      if modified then
        local r = far.Message("Do you want to save the changes?", Title, "&Yes;&No;Cancel", "w")
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
      if 1 == far.Message(msg, "Confirm", "&Yes;&No", "w") then
        cfg:del_section(fullname)
        Items = CreateItems()
        SetSelected(nil)
        modified = true
      end
    --------------------------------------------------------------------------------------------
    elseif (item.section or item.edit) and pos >= 1 then -- Enter or F4 pressed
      local tilde
      local sec = Items[pos].section
      local data = sec:dict()
      data.WorkArea, tilde, data.MacroKey = sec.name:match("KeyMacros/(%w+)/(~?)(%w+)")
      data.Deactivate = tilde ~= ""
      local out = mdialog(data)
      if out then
        tilde = out.Deactivate and "~" or ""
        local newname = ("KeyMacros/%s/%s%s"):format(out.WorkArea, tilde, out.MacroKey)
        if newname:lower() ~= sec.name:lower() then
          local sec_existing = cfg:get_section(newname)
          if sec_existing then
            local msg = "Replace the existing macro ["..newname.."] ?"
            if 1 == far.Message(msg, "Confirm", "&Yes;&No", "w") then
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
          out.WorkArea, out.MacroKey, out.Deactivate = nil, nil, nil
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
        local tilde = out.Deactivate and "~" or ""
        local newname = ("KeyMacros/%s/%s%s"):format(out.WorkArea, tilde, out.MacroKey)
        local sec_existing = cfg:get_section(newname)
        if sec_existing then
          local msg = "Replace the existing macro ["..newname.."] ?"
          if 1 == far.Message(msg, "Confirm", "&Yes;&No", "w") then
            cfg:del_section(sec_existing.name)
            sec = cfg:add_section(newname)
          end
        else
          sec = cfg:add_section(newname)
        end

        if sec then
          out.WorkArea, out.MacroKey, out.Deactivate = nil, nil, nil
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
    elseif item.activate and pos >= 1 then -- Space pressed
      local sec = Items[pos].section
      local area, tilde, key = sec.name:match("KeyMacros/(%w+)/(~?)(%w+)")
      tilde = tilde=="" and "~" or "" -- toggle
      local newname = ("KeyMacros/%s/%s%s"):format(area, tilde, key)
      if cfg:get_section(newname) then
        local msg = "Replace the existing macro ["..newname.."] ?"
        if 1 == far.Message(msg, "Confirm", "&Yes;&No", "w") then
          cfg:del_section(newname)
          cfg:ren_section(sec.name, newname)
        else
          sec = nil
        end
      else
        cfg:ren_section(sec.name, newname)
      end

      if sec then
        Items = CreateItems()
        SetSelected(sec)
        modified = true
      end
    --------------------------------------------------------------------------------------------
    elseif item.help then -- F1 pressed
    far.Message([[
F4, Enter - Edit a macro
ShiftF4   - Insert a new macro
F8        - Delete a macro
Space     - Deactivate / activate a macro
CtrlF1    - Sort by the 1-st column
CtrlF2    - Sort by the 2-nd column
CtrlF3    - Sort by the 3-rd column
F1        - Help window]],
"Help", nil, "l")
    --------------------------------------------------------------------------------------------
    end
  end
end

RunMenu()
