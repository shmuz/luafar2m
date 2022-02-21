-- lfs_editmain.lua

local sd          = require "far2.simpledialog"
local Common      = require "lfs_common"
local EditEngine  = require "lfs_editengine"
local M           = require "lfs_message"

local F = far.Flags
local ErrorMsg = Common.ErrorMsg

local function FormatInt (num)
  return tostring(num):reverse():gsub("...", "%1,"):gsub(",$", ""):reverse()
end

local searchGuid  = win.Uuid("0B81C198-3E20-4339-A762-FFCBBC0C549C")
local replaceGuid = win.Uuid("FE62AEB9-E0A1-4ED3-8614-D146356F86FF")

local function SR_Dialog (aData, aReplace, aScriptCall)
  local insert = table.insert
  local sTitle = aReplace and M.MTitleReplace or M.MTitleSearch
  local regpath = _Plugin.RegPath
  local HIST_INITFUNC   = regpath .. "InitFunc"
  local HIST_FINALFUNC  = regpath .. "FinalFunc"
  local HIST_FILTERFUNC = regpath .. "FilterFunc"
  ------------------------------------------------------------------------------
  local Items = {
    width = 76;
    guid = aReplace and replaceGuid or searchGuid;
    help = "OperInEditor";
    { tp="dbox"; text=sTitle; },
  }
  local Frame = Common.CreateSRFrame(Items, aData, true)
  ------------------------------------------------------------------------------
  Frame:InsertInDialog(aReplace)
  insert(Items, { tp="sep"; })
  ------------------------------------------------------------------------------
  insert(Items, { tp="text";  text=M.MDlgScope; })
  insert(Items, { tp="rbutt"; name="rScopeGlobal";  text=M.MDlgScopeGlobal; x1=6; group=1; noauto=1; })
  insert(Items, { tp="rbutt"; name="rScopeBlock";   text=M.MDlgScopeBlock;  x1=6; noauto=1; })
  insert(Items, { tp="text";                        text=M.MDlgOrigin; ystep=-2; x1=26; })
  insert(Items, { tp="rbutt"; name="rOriginCursor"; text=M.MDlgOrigCursor; x1=27; group=1; noauto=1; })
  insert(Items, { tp="rbutt"; name="rOriginScope";  text=M.MDlgOrigScope;  x1=27; noauto=1; })
  insert(Items, { tp="chbox"; name="bSearchBack";   text=M.MDlgReverseSearch; ystep=-2; x1=50; })
  ------------------------------------------------------------------------------
  insert(Items, { tp="sep"; ystep=3; })
  ------------------------------------------------------------------------------
  insert(Items, { tp="chbox"; name="bAdvanced";            text=M.MDlgAdvanced; })
  insert(Items, { tp="text";  name="labFilterFunc"; x1=39; text=M.MDlgFilterFunc; y1=""; })
  insert(Items, { tp="edit";  name="sFilterFunc";   x1=39; hist=HIST_FILTERFUNC; })
  ------------------------------------------------------------------------------
  insert(Items, { tp="text";  name="labInitFunc";  text=M.MDlgInitFunc; })
  insert(Items, { tp="edit";  name="sInitFunc";    x2=36; hist=HIST_INITFUNC; })
  insert(Items, { tp="text";  name="labFinalFunc"; x1=39; text=M.MDlgFinalFunc; ystep=-1; })
  insert(Items, { tp="edit";  name="sFinalFunc";   x1=39; hist=HIST_FINALFUNC; })
  ------------------------------------------------------------------------------
  insert(Items, { tp="sep"; })
  ------------------------------------------------------------------------------
  insert(Items, { tp="butt"; name="btnOk"; centergroup=1; text=M.MOk; default=1; })
  insert(Items, { tp="butt"; name="btnCancel"; centergroup=1; text=M.MCancel; cancel=1; })
  if not aReplace then
    insert(Items, { tp="butt"; name="btnCount"; centergroup=1; text=M.MDlgBtnCount; })
    insert(Items, { tp="butt"; name="btnShowAll"; centergroup=1; text=M.MDlgBtnShowAll; })
  end
  insert(Items, { tp="butt"; name="btnConfig"; centergroup=1; text=M.MDlgBtnConfig; })
  ----------------------------------------------------------------------------
  function Items.proc (hDlg, msg, param1, param2)
    return Frame:DlgProc(hDlg, msg, param1, param2)
  end
  ----------------------------------------------------------------------------
  sd.LoadData(aData, Items)
  Frame.Pos, Frame.Elem = sd.Indexes(Items)
  local pp = Frame.Pos
  Frame:OnDataLoaded(aData, aScriptCall)
  local out, pos = sd.Run(Items)
  if not out then return "cancel" end
  return pos==pp.btnOk      and (aReplace and "replace" or "search") or
         pos==pp.btnConfig  and "config" or
         pos==pp.btnCount   and "count"  or
         pos==pp.btnShowAll and "showall",
         Frame.close_params
end


local ValidOperations = {
  [ "config"       ] = true;
  [ "repeat"       ] = true;
  [ "repeat_rev"   ] = true;
  [ "replace"      ] = true;
  [ "search"       ] = true;
  [ "test:count"   ] = true;
  [ "test:replace" ] = true;
  [ "test:search"  ] = true;
  [ "test:showall" ] = true;
}


--[[-------------------------------------------------------------------------
  *  'aScriptCall' being true means we are called from a script rather than from
     the standard user interface.
  *  If it is true, then the search pattern in the dialog should be initialized
     strictly from aData.sSearchPat, otherwise it will depend on the global
     value 'config.rPickFrom'.
------------------------------------------------------------------------------]]
local function EditorAction (aOp, aData, aScriptCall)
  assert(ValidOperations[aOp], "invalid operation")
  ---------------------------------------------------------------------------
  if aOp == "config" then Common.ConfigDialog() return end
  ---------------------------------------------------------------------------
  local bReplace, bWithDialog, sOperation, tParams
  aData.sSearchPat = aData.sSearchPat or ""
  aData.sReplacePat = aData.sReplacePat or ""
  local bTest = aOp:find("^test:")
  if bTest then
    bWithDialog = true
    bReplace = (aOp == "test:replace")
    sOperation = aOp:sub(6) -- skip "test:"
    tParams = assert(Common.ProcessDialogData (aData, bReplace))
  elseif aOp == "search" or aOp == "replace" then
    bWithDialog = true
    bReplace = (aOp == "replace")
    while true do
      sOperation, tParams = SR_Dialog(aData, bReplace, aScriptCall)
      if sOperation ~= "config" then break end
      Common.ConfigDialog()
    end
    if sOperation == "cancel" then return end
    -- sOperation : either of "search", "count", "showall", "replace"
  else -- if aOp == "repeat"
    bReplace = (aData.sLastOp == "replace")
    local searchtext = Common.GetFarHistory("SearchText")
    if searchtext ~= aData.sSearchPat then
      bReplace = false
      --aData.bSearchBack = false
      aData.bSearchBack = (aOp == "repeat_rev")
      if searchtext then aData.sSearchPat = searchtext end
    end
    sOperation = bReplace and "replace" or "search"
    tParams = assert(Common.ProcessDialogData (aData, bReplace))
  end
  aData.sLastOp = bReplace and "replace" or "search"
  tParams.sScope = bWithDialog and aData.sScope or "global"
  ---------------------------------------------------------------------------
  if aData.bAdvanced then tParams.InitFunc() end
----profiler.start[[e:\bb\f\today\projects\luafar\log11.log]]
  local nFound, nReps, sChoice = EditEngine.DoAction(
      sOperation,
      tParams,
      bWithDialog,
      aData.fUserChoiceFunc)
----profiler.stop()
  if aData.bAdvanced then tParams.FinalFunc() end
  ---------------------------------------------------------------------------
  if not bTest and sChoice ~= "broken" then
    if nFound == 0 then
      ErrorMsg (M.MNotFound .. aData.sSearchPat .. "\"", M.MMenuTitle)
    elseif sOperation == "count" then
      far.Message (M.MTotalFound .. FormatInt(nFound), M.MMenuTitle)
    elseif bReplace and nReps > 0 and sChoice ~= "cancel" then
      far.Message (M.MTotalReplaced .. FormatInt(nReps), M.MMenuTitle)
    end
  end
  editor.SetTitle("")
  return nFound, nReps, sChoice
end

--[[-------------------------------------------------------------------------]]
return {
  EditorAction = EditorAction;
}
