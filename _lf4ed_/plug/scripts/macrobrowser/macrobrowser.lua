-- coding: utf-8
-- started: 2022-01-20

local Title = "Macro Browser"
local ThisDir = (...):match(".*/")
local MacroFile = os.getenv("HOME") .. "/.config/far2l/settings/key_macros.ini"
local F = far.Flags

local Browser = {
  cfg    = nil;
  hidden = nil;
  items  = nil;
  macrodialog = nil;
}
local Browser_meta = { __index=Browser }

local function NewBrowser()
  return setmetatable({}, Browser_meta)
end

local function MakeMenuItem(cfg, sec)
  local name, area, tilde, key = sec.name:match("^(%w+)/(%w+)/(~?)(%w+)")
  if name and name:lower()=="keymacros" then
    local descr = cfg:GetString(sec.name, "Description") or "<no description>"
    local seq = cfg:GetString(sec.name, "Sequence") or "<no sequence>"
    local txt = ("%-12s│ %-16s│ %s"):format(area, key, descr)
    tilde = tilde=="~" and "~" or nil
    return {text=txt; area=area; columns={area,key,descr,seq}; section=sec; checked=tilde; }
  end
end

function Browser:CreateItems()
  self.items = {}
  local area = self.macrodialog.GetArea()
  for sec in self.cfg:sections() do
    local item = MakeMenuItem(self.cfg, sec)
    if item then
      if not self.hidden or item.area=="Common" or item.area==area then
        table.insert(self.items,item)
      end
    end
  end
end

local Props = { Title=Title; Bottom="F1, F4, F5, Ins, F8, Space, Ctrl-H";
                Flags=F.FMENU_SHOWAMPERSAND+F.FMENU_WRAPMODE+F.FMENU_CHANGECONSOLETITLE; }
local Bkeys = {
  {BreakKey = "C+H";      hide=1;     },
  {BreakKey = "C+F1";     sortcol=1;  },
  {BreakKey = "C+F2";     sortcol=2;  },
  {BreakKey = "C+F3";     sortcol=3;  },
  {BreakKey = "F4";       edit=1;     },
  {BreakKey = "F5";       copy=1;     },
  {BreakKey = "NUMPAD0";  insert=1;   }, -- Ins
  {BreakKey = "F8";       delete=1;   },
  {BreakKey = "F1";       help=1;     },
  {BreakKey = "SPACE";    activate=1; },
}
local Col, Rev = 1, false

local function CompareByCol(a, b, aCol)
  if a.columns[aCol] < b.columns[aCol] then return -1 end
  if a.columns[aCol] > b.columns[aCol] then return  1 end
  return 0
end

function Browser:SortItems()
  -- This sort algorithm is stable because the combination of 1-st
  -- and 2-nd columns (area/key) cannot be the same for 2 macros.
  table.sort(self.items,
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

function Browser:SetSelected(section)
  for _,v in ipairs(self.items) do
    v.selected = (v.section==section) or nil
  end
end

local function ConfirmReplace(newname)
  local msg = "Replace the existing macro ["..newname.."] ?"
  return 1 == far.Message(msg, "Confirm", "&Yes;&No", "w")
end

local function RunMenu()
  local self = NewBrowser()

  local inifile = require "inifile"
  local cfg, msg = inifile.New(MacroFile, "nocomment")
  if not cfg then
    far.Message(msg, Title, nil, "w")
    return
  end

  self.cfg = cfg
  self.hidden = true
  self.macrodialog = dofile(ThisDir.."_macrodialog.lua")

  self:CreateItems()
  local mdialog = self.macrodialog.Dialog
  local modified = false

  while true do
    self:SortItems()
    local item,pos = far.Menu(Props, self.items, Bkeys)

    if not item then
      if not modified then break end
      local r = far.Message("Do you want to save the changes?", Title, "&Yes;&No;Cancel", "w")
      if r == 1 then
        cfg:write(MacroFile)
        far.Timer(100, function(hnd) hnd:Close(); far.MacroLoadAll(); end) -- another bug in FAR ?
        break
      elseif r == 2 then
        break
      end
      item, pos = {}, 0
      self:SetSelected(nil)
    else
      if pos >= 1 then
        self:SetSelected(self.items[pos].section)
      end
    end
    --------------------------------------------------------------------------------------------
    if item.hide then --
      self.hidden = not self.hidden
      self:CreateItems()
      self:SetSelected(nil)
    --------------------------------------------------------------------------------------------
    elseif item.sortcol then -- sort requested
      if item.sortcol == Col then Rev = not Rev
      else Col,Rev = item.sortcol,false
      end
      self:SetSelected(nil)
    --------------------------------------------------------------------------------------------
    elseif item.delete and pos >= 1 then -- F8 pressed
      local fullname = self.items[pos].section.name
      local shortname = fullname:match(".-/(.*)")
      local msg = ("Delete '%s' macro?"):format(shortname)
      if 1 == far.Message(msg, "Confirm", "&Yes;&No", "w") then
        cfg:del_section(fullname)
        self:CreateItems()
        self:SetSelected(nil)
        modified = true
      end
    --------------------------------------------------------------------------------------------
    elseif (item.section or item.edit) and pos >= 1 then -- Enter or F4 pressed
      local sec = self.items[pos].section
      local CanClose = function(out)
        local tilde = out.Deactivate and "~" or ""
        local newname = ("KeyMacros/%s/%s%s"):format(out.WorkArea, tilde, out.MacroKey)
        return newname:lower()==sec.name:lower() or not cfg:get_section(newname)
               or ConfirmReplace(newname)
      end

      local tilde
      local data = sec:dict()
      data.WorkArea, tilde, data.MacroKey = sec.name:match("KeyMacros/(%w+)/(~?)(%w+)")
      data.Deactivate = tilde ~= ""
      local out = mdialog("Edit a macro", data, CanClose)
      if out then
        tilde = out.Deactivate and "~" or ""
        local newname = ("KeyMacros/%s/%s%s"):format(out.WorkArea, tilde, out.MacroKey)
        if newname:lower() ~= sec.name:lower() then
          cfg:del_section(sec.name)
          sec = cfg:get_section(newname) or cfg:add_section(newname)
        end
        sec:clear()
        out.WorkArea, out.MacroKey, out.Deactivate = nil, nil, nil
        for k,v in pairs(out) do
          if type(v)=="number" then
            sec:set(k, ("0x%X"):format(v))
          else
            sec:set(k,v)
          end
        end
        self:CreateItems()
        self:SetSelected(sec)
        modified = true
      end
    --------------------------------------------------------------------------------------------
    elseif item.insert or (item.copy and pos >= 1) then -- Ins or F5 pressed
      local CanClose = function(out)
        local tilde = out.Deactivate and "~" or ""
        local newname = ("KeyMacros/%s/%s%s"):format(out.WorkArea, tilde, out.MacroKey)
        return not cfg:get_section(newname) or ConfirmReplace(newname)
      end

      local data = nil
      if item.copy then
        local tilde
        local sec = self.items[pos].section
        data = sec:dict()
        data.WorkArea, tilde, data.MacroKey = sec.name:match("KeyMacros/(%w+)/(~?)(%w+)")
        data.Deactivate = tilde ~= ""
      end
      local title = item.insert and "Add a new macro" or "Copy a macro"
      local out = mdialog(title, data, CanClose)
      if out then
        local tilde = out.Deactivate and "~" or ""
        local newname = ("KeyMacros/%s/%s%s"):format(out.WorkArea, tilde, out.MacroKey)
        local sec_existing = cfg:get_section(newname)
        if sec_existing then
          cfg:del_section(sec_existing.name)
        end
        local sec = cfg:add_section(newname)
        out.WorkArea, out.MacroKey, out.Deactivate = nil, nil, nil
        for k,v in pairs(out) do
          if type(v)=="number" then
            sec:set(k, ("0x%X"):format(v))
          else
            sec:set(k,v)
          end
        end
        self:CreateItems()
        self:SetSelected(sec)
        modified = true
      end
    --------------------------------------------------------------------------------------------
    elseif item.activate and pos >= 1 then -- Space pressed
      local sec = self.items[pos].section
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
        self:CreateItems()
        self:SetSelected(sec)
        modified = true
      end
    --------------------------------------------------------------------------------------------
    elseif item.help then -- F1 pressed
    far.Message([[
Ctrl-F1   - Sort by the 1-st column
Ctrl-F2   - Sort by the 2-nd column
Ctrl-F3   - Sort by the 3-rd column
Ctrl-H    - Hide macros from other areas
F1        - Help window
F4, Enter - Edit a macro
F5        - Copy a macro
F8        - Delete a macro
Ins       - Add a new macro
Space     - Deactivate / activate a macro]],
"Help", nil, "l")
    --------------------------------------------------------------------------------------------
    end
  end
end

AddToMenu("depv", "Macro Browser", nil, RunMenu)
AddCommand("macrobrowser", RunMenu)
