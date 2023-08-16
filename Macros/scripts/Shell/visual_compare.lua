-- Started: 2017-08-02

-- The algorithm for choosing a file pair for visual comparison:
--     1. Active panel:  either 1 selected or valid current file    --> file1
--        Passive panel: either 1 selected or having the same name  --> file2
--     2. Active panel: 2 selected                                  --> file1, file2
--     3. Active panel: >2 selected and valid current file          --> file1
--        Passive panel: either 1 selected or having the same name  --> file2

local CommonKey = "CtrlShiftF2"
local Modes = { -- uncomment those modes you will actually use
  meld = true;
--diff_console = true;
--diff_edit = true;
--diff_view = true;
}

local F = far.Flags
local function GetCurrentItem(pan)         return panel.GetCurrentPanelItem(pan) end
local function GetSelectedItem(pan,index)  return panel.GetSelectedPanelItem(pan,index) end
local function isfile(item)                return not item.FileAttributes:find("d") end
local function extract_name(s)             return s:match("[^/]+$") end

local function fexist(file)
  return not (win.GetFileAttr(file) or "d"):find("d")
end

local function join(s1, s2)
  return s1=="" and s2 or s1:find("/$") and s1..s2 or s1.."/"..s2
end

local function Run(mode)
  local ACT,PSV = 1,0 -- active and passive panels
  local aInfo = panel.GetPanelInfo(ACT)
  local pInfo = panel.GetPanelInfo(PSV)
  local dirActive  = panel.GetPanelDirectory(ACT)
  local dirPassive = panel.GetPanelDirectory(PSV)
  local trgActive, trgPassive

  if aInfo.SelectedItemsNumber == 1 or aInfo.SelectedItemsNumber > 2 then
    local aItem = aInfo.SelectedItemsNumber == 1 and GetSelectedItem(ACT,1) or GetCurrentItem(ACT)
    if isfile(aItem) then
      trgActive = join(dirActive, aItem.FileName)
      if pInfo.SelectedItemsNumber == 1 then
        local pItem = GetSelectedItem(PSV,1)
        if bit64.band(pItem.Flags, F.PPIF_SELECTED) ~= 0 then
          trgPassive = join(dirPassive, pItem.FileName)
        end
      end
      if not trgPassive then
        local trg2 = join(dirPassive, extract_name(aItem.FileName))
        if fexist(trg2) then trgPassive = trg2 end
      end
    end
  elseif aInfo.SelectedItemsNumber == 2 then
    local item1, item2 = GetSelectedItem(ACT,1), GetSelectedItem(ACT,2)
    if isfile(item1) and isfile(item2) then
      trgActive = join(dirActive, item1.FileName)
      trgPassive = join(dirActive, item2.FileName)
    end
  end

  if trgActive and trgPassive then
    if mode == "meld" then
      local command = ("meld %q %q &"):format(trgActive,trgPassive)
      os.execute(command)

    elseif mode == "diff_console" then
      local command = ("diff -u %q %q"):format(trgActive,trgPassive)
      far.Execute(command)
      far.AdvControl("ACTL_REDRAWALL")
      Keys("CtrlO")

    elseif mode == "diff_edit" then
      local command = ("diff -u %q %q"):format(trgActive,trgPassive)
      Plugin.Command(far.GetPluginId(), "edit:<"..command)

    elseif mode == "diff_view" then
      local command = ("diff -u %q %q"):format(trgActive,trgPassive)
      Plugin.Command(far.GetPluginId(), "view:<"..command)

    end
  else
    far.Message("No suitable file pair found", "Visual compare", nil, "w")
  end
end

if Modes.meld then Macro {
    description="Visual compare (meld)";
    area="Shell"; key=CommonKey;
    action=function() Run("meld") end;
} end

if Modes.diff_console then Macro {
    description="Visual compare (diff in console)";
    area="Shell"; key=CommonKey;
    action=function() Run("diff_console") end;
} end

if Modes.diff_edit then Macro {
    description="Visual compare (diff in editor)";
    area="Shell"; key=CommonKey;
    action=function() Run("diff_edit") end;
} end

if Modes.diff_view then Macro {
    description="Visual compare (diff in viewer)";
    area="Shell"; key=CommonKey;
    action=function() Run("diff_view") end;
} end
