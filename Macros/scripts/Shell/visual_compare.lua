-- Started: 2017-08-02
-- Portable Far3/far2m: 2023-12-22

-- The algorithm for choosing a file pair for visual comparison (in descending priorities):
--     1. Active panel: 2 selected
--     2. Active panel: 1 selected;  passive panel: 1 selected
--     3. Active panel: 1 selected;  passive panel: the same name
--     4. Active panel: has current; passive panel: the same name

local SLASH = string.sub(package.config,1,1)
local FAR3 = SLASH=="\\"

local CommonKey = FAR3 and "CtrlAltF2" or "CtrlShiftF2"
local Modes = { -- uncomment those modes you will actually use
    meld = not FAR3;
    winmerge = FAR3;
--  diff_console = true;
--  diff_edit = true;
--  diff_view = true;
}

local F = far.Flags
local FarCmdsId = FAR3 and "3A2AF458-43E2-4715-AFEA-93D33D56C0C2" or far.GetPluginId()

local function GetPanelDirectory(pan)
  return panel.GetPanelDirectory(nil,pan)
end

local function isfile(item)      return not item.FileAttributes:find("d") end
local function isselected(item)  return bit64.band(item.Flags,F.PPIF_SELECTED) ~= 0 end

local function extract_name(s)
  if FAR3 then return s:match("[^\\]+$")
  else return s:match("[^/]+$")
  end
end

local function fexist(file)
  local attr = win.GetFileAttr(file)
  return attr and not attr:find("d")
end

local function join(dir, file)
  return dir=="" and file
    or dir:find(SLASH.."$") and dir..file
    or dir..SLASH..file
end

local function fullname(dir, file)
  return file:find(SLASH) and file or join(dir, file)
end

-- collect items, skip directories
local function Collect(whatPanel, limit)
  local selTable = {}
  local aInfo = panel.GetPanelInfo(nil,whatPanel)
  for k=1,aInfo.SelectedItemsNumber do
    local item = panel.GetSelectedPanelItem(nil,whatPanel,k)
    if isfile(item) and isselected(item) then
      if #selTable < limit then
        table.insert(selTable,item)
      else
        selTable = {}; break -- too many selected items, discard all
      end
    end
  end
  local item = panel.GetCurrentPanelItem(nil, whatPanel)
  if isfile(item) then selTable.Current=item; end
  return selTable
end

local function GetPairForCompare()
  local ACT,PSV = 1,0 -- active and passive panels
  local dirActive  = GetPanelDirectory(ACT)
  local dirPassive = GetPanelDirectory(PSV)
  local trgActive, trgPassive
  --------------------------------------------------------------------------------------------------
  local selAct, selPass = Collect(ACT,2), Collect(PSV,1)
  if #selAct == 2 then
    trgActive  = fullname(dirActive, selAct[1].FileName)
    trgPassive = fullname(dirActive, selAct[2].FileName)
  elseif #selAct == 1 and #selPass == 1 then
    trgActive  = fullname(dirActive,  selAct[1].FileName)
    trgPassive = fullname(dirPassive, selPass[1].FileName)
  elseif next(selAct) and dirPassive ~= "" then
    local name1 = (selAct[1] or selAct.Current).FileName
    local fullname2 = join(dirPassive, extract_name(name1))
    if fexist(fullname2) then
      trgActive  = fullname(dirActive, name1)
      trgPassive = fullname2
    end
  end
  return trgActive, trgPassive
end

local function Run(trgActive, trgPassive)
  -- prepare the menu
  local items = {}
  for k,v in pairs(Modes) do
    if v then table.insert(items, {Val=k}) end
  end

  local mode
  if items[1] == nil then
    far.Message("No mode is specified", "Error", nil, "w")
    return
  elseif items[2] == nil then
    mode = items[1].Val -- only 1 mode available; no menu needed
  else
    table.sort(items, function(a,b) return a.Val < b.Val; end)
    for i,v in ipairs(items) do
      v.text = ("&%d. %s"):format(i, v.Val)
    end
    local item = far.Menu({Title="Select compare mode"},items)
    if item then mode = item.Val
    else return
    end
  end

  if mode == "meld" then
    local command = ("meld %q %q &"):format(trgActive,trgPassive)
    os.execute(command)

  elseif mode == "winmerge" then
    local command = ("%q %q"):format(trgActive,trgPassive)
    win.ShellExecute(nil, nil, "winmerge", command)

  elseif mode == "diff_console" then
    local command = ("diff -u %q %q"):format(trgActive,trgPassive)
    if FAR3 then
      panel.GetUserScreen(); win.system(command); panel.SetUserScreen()
    else
      far.Execute(command)
    end
    far.AdvControl("ACTL_REDRAWALL")
    Keys("CtrlO")

  elseif mode == "diff_edit" then
    local command = ("diff -u %q %q"):format(trgActive,trgPassive)
    Plugin.Command(FarCmdsId, "edit:<"..command)

  elseif mode == "diff_view" then
    local command = ("diff -u %q %q"):format(trgActive,trgPassive)
    Plugin.Command(FarCmdsId, "view:<"..command)

  end
end

Macro {
  description="Visual compare";
  area="Shell"; key=CommonKey;
  action=function()
    local file1,file2 = GetPairForCompare()
    if file1 then
      Run(file1,file2)
    else
      far.Message("No suitable file pair found", "Visual compare", nil, "w")
    end
  end;
}
