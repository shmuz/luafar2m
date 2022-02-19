-- lfs_editmain.lua

local far2_dialog = require "far2.dialog"
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
  local sTitle = aReplace and M.MTitleReplace or M.MTitleSearch
  local regpath = _Plugin.RegPath
  local HIST_INITFUNC   = regpath .. "InitFunc"
  local HIST_FINALFUNC  = regpath .. "FinalFunc"
  local HIST_FILTERFUNC = regpath .. "FilterFunc"
  ------------------------------------------------------------------------------
  local Dlg = far2_dialog.NewDialog()
  local Frame = Common.CreateSRFrame(Dlg, aData, true)
  Dlg.frame       = {"DI_DOUBLEBOX",    3,1, 72,17, 0, 0, 0, 0, sTitle}
  ------------------------------------------------------------------------------
  local Y = Frame:InsertInDialog(aReplace, 2)
  Dlg.sep = {"DI_TEXT", 5,Y,0,0, 0,0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, 0, ""}
  ------------------------------------------------------------------------------
  Y = Y + 1
  Dlg.lab         = {"DI_TEXT",        5,Y,   0, 0, 0, 0, 0, 0, M.MDlgScope}
  Dlg.rScopeGlobal= {"DI_RADIOBUTTON", 6,Y+1, 0, 0, 0, 0, "DIF_GROUP", 0,
                                              M.MDlgScopeGlobal, _noauto=true}
  Dlg.rScopeBlock = {"DI_RADIOBUTTON", 6,Y+2, 0, 0, 0, 0, 0, 0,
                                              M.MDlgScopeBlock, _noauto=true}
  Dlg.lab         = {"DI_TEXT",       26,Y,0, 0, 0, 0, 0, 0,    M.MDlgOrigin}
  Dlg.rOriginCursor={"DI_RADIOBUTTON",27,Y+1, 0, 0, 0, 0, "DIF_GROUP",0,
                                              M.MDlgOrigCursor, _noauto=true}
  Dlg.rOriginScope= {"DI_RADIOBUTTON",27,Y+2, 0, 0, 0, 0, 0, 0,
                                              M.MDlgOrigScope, _noauto=true}
  Dlg.bSearchBack = {"DI_CHECKBOX",   50,Y,   0, 0, 0, 0, 0, 0, M.MDlgReverseSearch}
  ------------------------------------------------------------------------------
  Y = Y + 3
  Dlg.sep = {"DI_TEXT", 5,Y,0,0, 0,0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, 0, ""}
  ------------------------------------------------------------------------------
  Y = Y + 1
  Dlg.bAdvanced   = {"DI_CHECKBOX",    5,Y,  0, 0, 0, 0, 0, 0, M.MDlgAdvanced}
  Dlg.labFilterFunc={"DI_TEXT",       39,Y,   0, 0, 0, 0, 0, 0, M.MDlgFilterFunc}
  Y = Y + 1
  Dlg.sFilterFunc = {"DI_EDIT",       39,Y,  70, 4, 0, HIST_FILTERFUNC, "DIF_HISTORY", 0, ""}
  ------------------------------------------------------------------------------
  Y = Y + 1
  Dlg.labInitFunc = {"DI_TEXT",        5,Y,   0, 0, 0, 0, 0, 0, M.MDlgInitFunc}
  Dlg.sInitFunc   = {"DI_EDIT",        5,Y+1,36, 0, 0, HIST_INITFUNC, "DIF_HISTORY", 0, ""}
  Dlg.labFinalFunc= {"DI_TEXT",       39,Y,   0, 0, 0, 0, 0, 0, M.MDlgFinalFunc}
  Dlg.sFinalFunc  = {"DI_EDIT",       39,Y+1,70, 6, 0, HIST_FINALFUNC, "DIF_HISTORY", 0, ""}
  ------------------------------------------------------------------------------
  Y = Y + 2
  Dlg.sep = {"DI_TEXT", 5,Y,0,0, 0,0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, 0, ""}
  ------------------------------------------------------------------------------
  Y = Y + 1
  Dlg.btnOk       = {"DI_BUTTON",      0,Y,   0, 0, 0, 0, "DIF_CENTERGROUP", 1, M.MOk}
  Dlg.btnCancel   = {"DI_BUTTON",      0,Y,   0, 0, 0, 0, "DIF_CENTERGROUP", 0, M.MCancel}
  if not aReplace then
    Dlg.btnCount  = {"DI_BUTTON",      0,Y,   0, 0, 0, 0, "DIF_CENTERGROUP", 0, M.MDlgBtnCount}
    Dlg.btnShowAll= {"DI_BUTTON",      0,Y,   0, 0, 0, 0, "DIF_CENTERGROUP", 0, M.MDlgBtnShowAll}
  end
  Dlg.btnConfig   = {"DI_BUTTON",      0,Y,   0, 0, 0, 0, "DIF_CENTERGROUP", 0, M.MDlgBtnConfig}
  Dlg.frame.Y2 = Y+1
  ----------------------------------------------------------------------------
  local function DlgProc (hDlg, msg, param1, param2)
    if msg == F.DN_GETDIALOGINFO then
      return aReplace and replaceGuid or searchGuid
    end
    return Frame:DlgProc(hDlg, msg, param1, param2)
  end
  ----------------------------------------------------------------------------
  far2_dialog.LoadData(Dlg, aData)
  Frame:OnDataLoaded(aData, aScriptCall)
  local ret = far.Dialog (-1,-1,76,Y+3,"OperInEditor",Dlg,0,DlgProc)
  if ret < 0 or ret == Dlg.btnCancel.id then return "cancel" end
  return ret==Dlg.btnOk.id and (aReplace and "replace" or "search") or
         ret==Dlg.btnConfig.id and "config" or
         ret==Dlg.btnCount.id and "count" or
         ret==Dlg.btnShowAll.id and "showall",
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
