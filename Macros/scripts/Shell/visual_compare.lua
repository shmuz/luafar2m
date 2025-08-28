-- Started: 2017-08-02
-- Portable Far3/far2m: 2023-12-22

-- The algorithm for choosing a file pair for visual comparison (in descending priorities):
--     1. Active panel: 2 selected
--     2. Active panel: 1 selected;  passive panel: 1 selected
--     3. Active panel: 1 selected;  passive panel: the same name
--     4. Active panel: has current; passive panel: the same name

local dirsep = string.sub(package.config,1,1)
local osWindows = dirsep=="\\"

local CommonKey = osWindows and "CtrlAltF2" or "CtrlShiftF2"
local Modes = { -- uncomment those modes you will actually use
    meld = not osWindows;
    winmerge = osWindows;
--  diff_console = true;
--  diff_edit = true;
--  diff_view = true;
}

local F = far.Flags

local function isfile(item)      return not item.FileAttributes:find("d") end
local function isselected(item)  return bit64.band(item.Flags,F.PPIF_SELECTED) ~= 0 end

local function extract_name(s)
  if osWindows then return s:match("[^\\]+$")
  else return s:match("[^/]+$")
  end
end

local function fexist(file)
  local attr = win.GetFileAttr(file)
  return attr and not attr:find("d")
end

local function fullname(dir, file)
  return file:find(dirsep) and file or win.JoinPath(dir, file)
end

local function MkTempFileName()
  local fname = os.date("%Y-%m-%d-%H-%M-%S.diff")
  if osWindows then
    local Temp = assert(os.getenv("TEMP"), "env. var. TEMP is not set")
    return win.JoinPath(Temp, fname)
  else
    return far.InMyTemp(fname)
  end
end

local function CreateTempFile(trgActive, trgPassive)
  local file = MkTempFileName()
  local command = ("diff -u %q %q > %s"):format(trgActive, trgPassive, file)
  local fp = io.popen(command)
  if fp then
    fp:close()
    return file
  end
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
  local dirActive  = panel.GetPanelDirectory(ACT).Name
  local dirPassive = panel.GetPanelDirectory(PSV).Name
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
    local fullname2 = win.JoinPath(dirPassive, extract_name(name1))
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
    if osWindows then
      panel.GetUserScreen(); win.system(command); panel.SetUserScreen()
    else
      far.Execute(command)
    end
    far.AdvControl("ACTL_REDRAWALL")
    Keys("CtrlO")

  elseif mode == "diff_edit" then
    local file = CreateTempFile(trgActive, trgPassive)
    if file then
      local flags = "EF_NONMODAL EF_IMMEDIATERETURN EF_ENABLE_F6 EF_DISABLEHISTORY EF_DELETEONLYFILEONCLOSE"
      editor.Editor(file,nil,nil,nil,nil,nil,flags)
      editor.SetPosition(nil,1,1)
    end

  elseif mode == "diff_view" then
    local file = CreateTempFile(trgActive, trgPassive)
    if file then
      local flags = "VF_NONMODAL VF_IMMEDIATERETURN VF_ENABLE_F6 VF_DISABLEHISTORY VF_DELETEONLYFILEONCLOSE"
      viewer.Viewer(file,nil,nil,nil,nil,nil,flags)
      viewer.SetPosition(nil,0,1)
    end

  end
end

Macro {
  id="6419C126-45C0-4D13-8C36-C02022F95A74";
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
