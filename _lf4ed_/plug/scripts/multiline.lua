-- coding: utf-8
--[[
1. +++ Установки диалога не запоминаются в файле.
2. Не работает "Wrap around"; пока поиск только - от курсора и до конца буфера;
3. Не работает "Line Filter"; нужно либо убрать из диалога, либо сделать что-то
   эквивалентное.
4. В отсутствии Line Filter и Replace Function, поля Initial и Final почти не
   имеют смысла.
5. Нужно было бы сделать возможность задавать из диалога параметры ф-ции
   IncrementalSearch:
     LEN_MATCH,        -- match: maximum length
     LEN_PRECONTEXT,   -- precontext: minimum length
     LEN_POSTCONTEXT,  -- postcontext: minimum length
6. Не работает операция "Show All".
7. Не работает операция замены найденного текста.
8. В связи с тем, что это - "multi-line search", возможно, имеет смысл иметь в
   диалоге управление опциями PCRE "s" (dotall) и "m" (multiline).
   [ Хотя их легко задавать и в образце поиска, как (?s) и (?m) соответственно ]
9. Проверять ВСЕ ошибки ввода диалога, не закрывая диалог - так же как ошибку
   "строка поиска пуста".
--]]

-- started: 2009-11-25 by Shmuel Zeigerman

local SETTINGS_KEY = "shmuz"
local SETTINGS_NAME = "multiline_search"

local fgsub = require "fgsub"
local sd = require "far2.simpledialog"
local rex = require "rex_pcre"

local _RequiredLuafarVersion = "1.0.0" -- earlier versions had a bug (DM_GETTEXT crash)

local M = {
  MTitle             = "Multiline Search",
  MSearch            = "Multiline Search",
  MReplace           = "Multiline Replace",
  MUserChoiceReplace = "Replace",
  MUserChoiceWith    = "with",
  MUserChoiceButtons = "&Replace;&All;&Skip;&Cancel",
  MDlgSearchPat      = "&Search:",
  MDlgCaseSens       = "&Case sensitive",
  MDlgRegExpr        = "Regular &Expression",
  MReplInBlock       = "In selec&tion",
  MDlgReplacePat     = "&Replace:",
  MDlgRepIsFunc      = "&Function Mode",
  MDlgWholeWords     = "&Whole words",
  MDlgUseFilterFunc  = "&Line Filter:",
  MDlgInitFunc       = "&Initial:",
  MDlgFinalFunc      = "Fi&nal:",
  MDlgBtnOk          = "OK",
  MDlgBtnCancel      = "Cancel",
  MUsrBrkPrompt      = "Break the operation?",
  MUsrBrkButtons     = "Yes;No",
  MDlgExtended       = "Ignore w&hitespace",
  MWrapAround        = "Wra&p around",
  MCount             = "Co&unt",
  MTotalReplaced     = "Total replacements done: ",
  MNotFound          = "Could not find the string\n\"",
  MTotalFound        = "Total found: ",
  MShowAll           = "Show &All",
  MConfigTitle       = "Configuration",
  MConfigButton      = "C&onfiguration",
  MPickFrom          = "Pick search string from:",
  MPickEditor        = "&Editor",
  MPickHistory       = "&History",
  MPickNowhere       = "&Nowhere",
  MSearchFieldEmpty  = "Search field is empty",
  MError             = "Error",
  MErrorCounterExpr  = "Invalid counter expression",
  MErrorGroupNumber  = "Invalid group number",
  MSyntaxError       = "syntax error",
  MSearchPattern     = "Search Pattern",
  MReplacePattern    = "Replace Pattern",
  MReplaceFunction   = "Replace Function",
}

local function mkReadFunc (row, pos)
  local linebuf, linebuflen = {}, 0
  local tOffs = { 0, startRow=row, startPos=pos }
  return function (numBytes)
    while linebuflen < numBytes do
      local line = editor.GetString(row+1, 2)
      if not line then break end
      if pos then
        line = line:sub(pos+1); pos = nil
      end
      linebuf[#linebuf+1] = line .. "\n"
      linebuflen = linebuflen + line:len() + 1
      row = row+1
      tOffs[#tOffs+1] = tOffs[#tOffs] + line:len() + 1
    end
    local s = table.concat(linebuf)
    local ret = s:sub(1, numBytes)
    linebuf = { s:sub(numBytes+1) }
    linebuflen = linebuf[1]:len()
    return ret
  end, tOffs
end

local function mkFindFunc (pattern)
  return function (s, init)
    return rex.find(s, pattern, init)
  end
end

local function getRows (tOffs, str, from)
  local row1, row2
  for i=1, #tOffs do -- should be binary search
    if from > tOffs[i] then row1 = i; else break; end
  end
  assert(row1)

  local to = from + str:len()
  for i=row1, #tOffs do -- should be binary search
    if to > tOffs[i] then row2 = i; else break; end
  end
  assert(row2)

  return row1, row2
end

local function mkSelect (tOffs)
  return function (str, from)
    local to = from + str:len()
    local row1, row2 = getRows(tOffs, str, from)

    if row1 == 1 then from = from + tOffs.startPos; end
    if row2 == 1 then to = to + tOffs.startPos; end

    local startLine = tOffs.startRow + row1
    local startPos = from - tOffs[row1]
    local width = (to - tOffs[row2]) - (from - tOffs[row1])
    local height = row2 - row1 + 1
    local endLine = tOffs.startRow + row2
    local endPos = to - tOffs[row2]
    local screenTop = startLine-1 >= 0 and startLine-1 or 0

    editor.Select("BTYPE_STREAM", startLine, startPos, width, height)
    editor.SetPosition(endLine, endPos, nil, screenTop)
    return true
  end
end

local function mkShowAll (tOffs, items)
  return function (str, from)
    local row1, row2 = getRows(tOffs, str, from)
    items[#items+1] = { lineno=row1, text="item text", init=1 }
    return false
  end
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
local F = far.Flags

local _regpath = "LuaFAR\\LuaReplace\\"

local _lastclock = math.huge

local function ErrorMsg (text, title)
  far.Message (text, title or M.MError, nil, "w")
end

local function CheckLuafarVersion()
  if far.LuafarVersion then
    local v1, v2 = far.LuafarVersion():match("^(%d+)%.(%d+)")
    local r1, r2 = _RequiredLuafarVersion:match("^(%d+)%.(%d+)")
    if (v1-r1 > 0) or (v1-r1 == 0 and v2-r2 >= 0) then return end
  end
  error("luafar.dll version " .._RequiredLuafarVersion.. " is required", 3)
end


-- change in Far version 2.0.1208
local function HasChange1208()
  --local v1,v2,v3 = SplitVersion(far.AdvControl("ACTL_GETFARVERSION"))
  --return v1>2 or (v1==2 and (v2>0 or v3>=1208))
  return true
end


local function EditorSetString(...)
  if not editor.SetString(...) then error("EditorSetString failed") end
end

local function FormatInt (num)
  return tostring(num):reverse():gsub("...", "%1,"):gsub(",$", ""):reverse()
end

local function ConfigDialog (aData)
  local Items = {
    width = 76;
    help = "Contents";
    { tp="dbox"; text=M.MConfigTitle; },

    { tp="text"; text=M.MPickFrom; },
    { tp="rbutt"; name="rbtPickEditor";  x1=7; group=1; text=M.MPickEditor; val=1; },
    { tp="rbutt"; name="rbtPickHistory"; x1=23; y1=""; text=M.MPickHistory; },
    { tp="rbutt"; name="rbtPickNowhere"; x1=39; y1=""; text=M.MPickNowhere; },

    { tp="sep"; ystep=4; },
    { tp="butt"; centergroup=1; default=1; text=M.MDlgBtnOk; },
    { tp="butt"; centergroup=1; cancel=1;  text=M.MDlgBtnCancel; },
  }

  sd.LoadData(aData, Items)
  local out = sd.Run(Items)
  if out then
    sd.SaveData(out, aData)
    return true
  end
end

local function GetWordAboveCursor ()
  local line = editor.GetString(nil, 2)
  local pos = editor.GetInfo().CurPos
  local r = regex.new("\\w+")
  local start = 1
  while true do
    local from, to = r:find(line, start)
    if not from or from > pos then break end
    if pos <= (to + 1) then return line:sub(from, to) end
    start = to + 1
  end
end

local function SR_Dialog (aTitle, aData, aReplace, aFirstCall)
  local insert = table.insert
  local HIST_INITFUNC   = _regpath .. "InitFunc"
  local HIST_FINALFUNC  = _regpath .. "FinalFunc"
  local HIST_FILTERFUNC = _regpath .. "FilterFunc"
  ------------------------------------------------------------------------------
  local Items = {
    width = 76;
    help = "Contents";
    { tp="dbox"; text=aTitle; },
    { tp="text"; text=M.MDlgSearchPat; },
    { tp="edit"; name="sSearchPat"; y1=""; x1=14; hist="SearchText"; noload=aFirstCall; },
  }
  ------------------------------------------------------------------------------
  if aReplace then
    insert(Items, { tp="text"; ystep=2; text=M.MDlgReplacePat; })
    insert(Items, { tp="edit"; name="sReplacePat"; y1=""; x1=14; hist="ReplaceText";
                                          uselasthistory=1;   noload=aFirstCall; })
    insert(Items, { tp="chbox"; name="bReplInBlock"; x1=15; text=M.MReplInBlock; })
    insert(Items, { tp="chbox"; name="bRepIsFunc";   x1=37; y1=""; text=M.MDlgRepIsFunc; })
  end
  ------------------------------------------------------------------------------
  insert(Items, { tp="sep"; })
  ------------------------------------------------------------------------------
  insert(Items, { tp="chbox"; name="bCaseSens"; text=M.MDlgCaseSens; })
  insert(Items, { tp="chbox"; name="bRegExpr";   x1=37; y1=""; text=M.MDlgRegExpr; })
  ------------------------------------------------------------------------------
  insert(Items, { tp="chbox"; name="bWholeWords"; text=M.MDlgWholeWords; })
  insert(Items, { tp="chbox"; name="bExtended"; x1=37; y1=""; text=M.MDlgExtended; })
  ------------------------------------------------------------------------------
  insert(Items, { tp="chbox"; name="bWrapAround"; text=M.MWrapAround; })
--~   Dlg.bUseProfiler= {"DI_CHECKBOX",    37,Y, 0, 0,  0, 0,  0,  0, "Use &Profiler"}
  insert(Items, { tp="sep"; })
  ------------------------------------------------------------------------------
--~   Y = Y + 2
--~   Dlg.bFilterFunc = {"DI_CHECKBOX",    5,Y, 0, 0,  0, 0,  0,  0, M.MDlgUseFilterFunc}
--~   Dlg.sFilterFunc = {"DI_EDIT",       24,Y,70, 4,  1, HIST_FILTERFUNC, "DIF_HISTORY", 0, ""}
  ------------------------------------------------------------------------------
--~   Y = Y + 2
--~   Dlg.lab         = {"DI_TEXT",        5,Y,0, 0,  0, 0,  0,  0, M.MDlgInitFunc}
--~   Dlg.sInitFunc   = {"DI_EDIT",       14,Y,70,6,  0, HIST_INITFUNC, "DIF_HISTORY", 0, ""}
--~   ------------------------------------------------------------------------------
--~   Y = Y + 2
--~   Dlg.lab         = {"DI_TEXT",        5,Y,0, 0,  0, 0,  0,  0, M.MDlgFinalFunc}
--~   Dlg.sFinalFunc  = {"DI_EDIT",       14,Y,70,6,  0, HIST_FINALFUNC, "DIF_HISTORY", 0, ""}
--~   ------------------------------------------------------------------------------
---   Y = Y + 1
---   Dlg.sep         = {"DI_TEXT",        5,Y,0, 0,  0, 0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, 0, ""}
  ------------------------------------------------------------------------------
  insert(Items, { tp="butt"; centergroup=1; default=1; name="btnOk"; text=M.MDlgBtnOk; })
  insert(Items, { tp="butt"; centergroup=1; cancel=1;            text=M.MDlgBtnCancel; })
  insert(Items, { tp="butt"; centergroup=1; name="btnConfig";    text=M.MConfigButton; })
  if not aReplace then
    insert(Items, { tp="butt"; centergroup=1; name="btnCount";   text=M.MCount;   })
    insert(Items, { tp="butt"; centergroup=1; name="btnShowAll"; text=M.MShowAll; })
  end
  ------------------------------------------------------------------------------
  local Pos,Elem = sd.Indexes(Items)
  -- Load Data
  sd.LoadData(aData, Items)
  if aFirstCall then
    if aData.rbtPickEditor ~= false then --> default value
      Elem.sSearchPat.text = GetWordAboveCursor() or ""
    elseif aData.rbtPickHistory then
      Elem.sSearchPat.uselasthistory = true
    end
  end
  ----------------------------------------------------------------------------
  -- Handlers of dialog events --
  ----------------------------------------------------------------------------
  local function CheckLineFilter (hDlg)
    local enbl = hDlg:GetCheck(Pos.bFilterFunc)
    hDlg:Enable(Pos.sFilterFunc, enbl)
  end

  local function CheckRegExpr (hDlg)
    local enbl = hDlg:GetCheck(Pos.bRegExpr)
    hDlg:Enable(Pos.bExtended, enbl)
    hDlg:Enable(Pos.bWholeWords, not enbl)
  end

  local function CheckReplInBlock (hDlg)
    local enbl = not hDlg:GetCheck(Pos.bReplInBlock)
    hDlg:Enable(Pos.bWrapAround, enbl)
  end

  function Items.proc (hDlg, msg, param1, param2)
    if msg == F.DN_INITDIALOG then
      if aReplace then
        if editor.GetInfo().BlockType == F.BTYPE_NONE then
          hDlg:SetCheck(Pos.bReplInBlock, false)
          hDlg:Enable(Pos.bReplInBlock, false)
        end
        CheckReplInBlock(hDlg)
      end
--~       CheckLineFilter(hDlg)
      CheckRegExpr(hDlg)
    elseif msg == F.DN_BTNCLICK then
--~       if param1==Pos.bFilterFunc.id then CheckLineFilter(hDlg)
      if nil then
      elseif param1==Pos.bRegExpr then CheckRegExpr(hDlg)
      elseif aReplace and param1==Pos.bReplInBlock then CheckReplInBlock(hDlg)
      end
    elseif msg == F.DN_CLOSE then
      if param1 == Pos.btnOk or not aReplace and
        (param1 == Pos.btnCount or param1 == Pos.btnShowAll)
      then
        if hDlg:GetText(Pos.sSearchPat) == "" then
          ErrorMsg(M.MSearchFieldEmpty)
          return 0
        end
      end
    end
  end
  ----------------------------------------------------------------------------
  -- Run the dialog and check its return value
  local out, pos = sd.Run(Items)
  if not out then return "cancel" end
  sd.SaveData(out, aData)
  return pos==Pos.btnOk      and "ok"      or
         pos==Pos.btnConfig  and "config"  or
         pos==Pos.btnCount   and "count"   or
         pos==Pos.btnShowAll and "showall"
end


local function TransformReplacePat (aStr)
  local map = { a="\a", e="\27", f="\f", n="\n", r="\r", t="\t" }
  aStr = rex.gsub(aStr, [[
      \\([LlUuE]) |
      \\(R\{[-]?\d+(?:,\d*)?\}) |
      \\(R\{?) |
      \\x([0-9a-fA-F]{0,2}) |
      \\(.?) |
      \$(.?)
    ]],
    function(c0,cr1,cr2,c1,c2,c3)
      return
        c0  and (c0 == "E" and "%Z" or "%" .. c0) or --> workaround: "E" is hexadecimal
        cr1 and ("%" .. cr1:gsub("{", "%%{", 1)) or
        cr2 and (cr2=="R" and "%R" or error(M.MErrorCounterExpr)) or
        c1  and string.char(tonumber(c1,16) or 0) or
        c2  and (c2:match("%p") or map[c2] or error("invalid escape: \\"..c2)) or
        c3  and (tonumber(c3,16) and ("%"..c3) or error(M.MErrorGroupNumber..": $"..c3))
    end, nil, "x")
  return aStr
end

local function GetUserChoice (aTitle, s_found, s_rep)
  s_found = s_found:gsub ("%z", " ")
  s_rep = s_rep:gsub ("%z", " ")
  local c = far.Message(
    M.MUserChoiceReplace ..
    "\n\"" .. s_found .. "\"\n" ..
    M.MUserChoiceWith ..
    "\n\"" .. s_rep .. "\"\n\001",
    aTitle,
    M.MUserChoiceButtons)
  if c==1 or c==2 then
    _lastclock = os.clock()
--~     if profiler and c==1 then profiler.start(logfile) end
  end
  return c==1 and "yes" or c==2 and "all" or c==3 and "no" or "cancel"
end


local function CheckUserBreak (aTitle)
  return (win.ExtractKey() == "ESCAPE") and
    1 == far.Message(M.MUsrBrkPrompt, aTitle, M.MUsrBrkButtons, "w")
end


-- Note: argument 'row' can be nil (using current line)
local function ScrollToPosition (row, from, to, scroll)
  local editInfo = editor.GetInfo()
  local LeftPos = editInfo.LeftPos - 1
  -- left-most (or right-most) char is not visible
  if (from <= LeftPos) or (to > LeftPos + editInfo.WindowSizeX) then
    if to - from + 1 >= editInfo.WindowSizeX then
      LeftPos = from - 1
    else
      LeftPos = math.floor((to + from - 1 - editInfo.WindowSizeX) / 2)
      if LeftPos < 0 then LeftPos = 0 end
    end
  end
  -----------------------------------------------------------------------------
  local top
  local halfscreen = editInfo.WindowSizeY / 2
  scroll = scroll or 0
  row = row and (row - 1) or editInfo.CurLine
  if row < halfscreen - scroll then
    top = 0
  elseif row > halfscreen + scroll then
    top = row - math.floor(halfscreen + scroll - 0.5)
  else
    top = row - math.floor(halfscreen - scroll - 0.5)
  end
  -----------------------------------------------------------------------------
  editor.SetPosition { TopScreenLine=top, CurLine=row+1, LeftPos=LeftPos+1, CurPos=to+1 }
end


local function ShowCollectedLines (items, regex)
  if #items > 0 then
    table.sort(items, function(a,b) return a.lineno < b.lineno end)
    local maxno = math.floor(math.log10(items[#items].lineno)) + 1
    local fmt = string.format("%%%dd%c %%s", maxno, 179)
    for _, item in ipairs(items) do
      local s = item.text:gsub("%z"," "):gsub("^%s+", "")
      item.text = string.format(fmt, item.lineno, s)
    end
    local bottom = #items .. " lines shown"
    local item = far.Menu({Title="Search results", Bottom=bottom,
      Flags=F.FMENU_SHOWAMPERSAND}, items)
    if item then
      ScrollToPosition(item.lineno, 1, 0)
      local s = editor.GetString(nil, 2)
      local from, to = rex.find(s, regex, item.init)
      if from then
        ScrollToPosition(item.lineno, from, to)
        editor.Select("BTYPE_STREAM", nil, from, to-from+1, 1)
      end
      editor.Redraw()
    end
  end
end


local function DoAction (aOperation, aRegex, aReplacePat, aFilterFunc, aWrap,
                         aBlockMode, aWithDialog, aTitle)
  local info = editor.GetInfo()
  local readFunc, tOffs = mkReadFunc(info.CurLine-1, info.CurPos-1)
  local callback, items
  if aOperation == "search" then callback = mkSelect(tOffs)
  elseif aOperation == "showall" then
    items = {}
    callback = mkShowAll(tOffs, items)
  end
  local cnt = fgsub.IncrementalSearch (readFunc, mkFindFunc(aRegex),
              nil, nil, nil, callback)
  if cnt == 0 or aOperation ~= "search" then
    editor.SetPosition(info)
  end
  editor.Redraw()
  return cnt, 0, nil
end


local function MultilineSearch (aOp, aData, aStrings)
  M = aStrings or M
  CheckLuafarVersion()
  if aOp == "config" then ConfigDialog(aData) return end
  ---------------------------------------------------------------------------
  local params = {}
  local bReplace = (aOp=="replace") or (aOp=="repeat" and aData.sLastOp=="replace")
  params.WithDialog = (aOp=="search") or (aOp=="replace") or
                  not ((aData.sLastOp=="search") or (aData.sLastOp=="replace"))
  params.Title = M[bReplace and "MReplace" or "MSearch"]
  if params.WithDialog then
    local ret = SR_Dialog(params.Title, aData, bReplace, true)
    while true do
      if ret == "cancel" then return end
      if ret == "config" then
        if ConfigDialog(aData) then
        end
      else params.Operation = ret; break -- either of "ok", "count", "showall"
      end
      ret = SR_Dialog(params.Title, aData, bReplace, false)
    end
  else
    local name = HasChange1208() and "lines" or "line0"
    local FarSrchPat = win.GetRegKey("HKCU", "SavedDialogHistory\\SearchText", name)
    local FarReplPat = win.GetRegKey("HKCU", "SavedDialogHistory\\ReplaceText", name)
    if name == "lines" then
      FarSrchPat = FarSrchPat and FarSrchPat:match"^%Z*"
      FarReplPat = FarReplPat and FarReplPat:match"^%Z*"
    end
    if bReplace and (FarSrchPat~=aData.sSearchPat or FarReplPat~=aData.sReplacePat) then
      bReplace = false
      params.Title = M.MSearch
    end
    aData.sSearchPat = FarSrchPat or aData.sSearchPat or ""
    if bReplace then
      aData.sReplacePat = FarReplPat or aData.sReplacePat or ""
    end
  end
  if params.Operation==nil or params.Operation=="ok" then
    params.Operation = bReplace and "replace" or "search"
  end
  aData.sLastOp = bReplace and "replace" or "search"
  ---------------------------------------------------------------------------
  local function LocalError (msg, title)
    ErrorMsg(msg, title)
    if params.WithDialog then return SearchAndReplace(aOp, aData, aStrings) end
  end
  ---------------------------------------------------------------------------
  local envir = setmetatable({rex=rex}, {__index=_G})
  envir.dofile = function(fname)
    local f = assert(loadfile(fname))
    return setfenv(f, envir)()
  end
  ---------------------------------------------------------------------------
  local SearchPat = aData.sSearchPat
  local cflags = aData.bCaseSens and "" or "i"
  if aData.bRegExpr then
    if aData.bExtended then cflags = cflags.."x" end
  else
    SearchPat = SearchPat:gsub("[~!@#$%%^&*()%-+[%]{}\\|:;'\",<.>/?]", "\\%1")
    if aData.bWholeWords then SearchPat = "\\b"..SearchPat.."\\b" end
  end
  local ok, result1 = pcall(rex.new, SearchPat, cflags, nil)
  if ok then params.Regex = result1
  else return LocalError(result1, M.MSearchPattern..": "..M.MSyntaxError)
  end
  ---------------------------------------------------------------------------
  if bReplace then
    if aData.bRepIsFunc then
      local pat, msg = loadstring("local c1,c2,c3,c4,c5,c6,c7,c8,c9=...\n" ..
        aData.sReplacePat, M.MReplaceFunction)
      if pat then params.ReplacePat = setfenv(pat, envir)
      else return LocalError(msg, M.MReplaceFunction..": "..M.MSyntaxError)
      end
    else
      params.ReplacePat = aData.sReplacePat:gsub("%%", "%%%%")
      if aData.bRegExpr then
        local ok, result1 = pcall(TransformReplacePat, params.ReplacePat)
        if ok then params.ReplacePat = result1
        else return LocalError(result1, M.MReplacePattern..": "..M.MSyntaxError)
        end
      end
    end
    params.ReplaceInBlock = aData.bReplInBlock
  end
  ---------------------------------------------------------------------------
  if aData.bFilterFunc then
    local func, msg = loadstring("local s,n=...\n" .. aData.sFilterFunc,
      "Line Filter")
    if func then params.FilterFunc = setfenv(func, envir)
    else return LocalError(msg, "Line Filter function: " .. M.MSyntaxError)
    end
  end
  ---------------------------------------------------------------------------
--~   local func, msg = loadstring (aData.sInitFunc, "Initial")
--~   if func then params.InitFunc = setfenv(func, envir)
--~   else return LocalError(msg, "Initial Function: " .. M.MSyntaxError)
--~   end
--~   func, msg = loadstring (aData.sFinalFunc, "Final")
--~   if func then params.FinalFunc = setfenv(func, envir)
--~   else return LocalError(msg, "Final Function: " .. M.MSyntaxError)
--~   end
  ---------------------------------------------------------------------------
--~   if aData.bUseProfiler then
--~     profiler = require "profiler"
--~     if params.Operation ~= "replace" then profiler.start(logfile) end
--~   end
--~   params.InitFunc()
  local nFound, nReps, choice = DoAction(
      params.Operation,
      params.Regex,
      params.ReplacePat,
      params.FilterFunc,
      aData.bWrapAround,
      params.ReplaceInBlock,
      params.WithDialog,
      params.Title)
--~   if profiler then profiler.stop() end
--~   params.FinalFunc()
  ---------------------------------------------------------------------------
  if choice ~= "broken" then
    if nFound == 0 then
      ErrorMsg (M.MNotFound .. aData.sSearchPat .. "\"", params.Title)
    elseif params.Operation == "count" then
      far.Message (M.MTotalFound .. FormatInt(nFound), params.Title)
    elseif bReplace and nReps > 0 and choice ~= "cancel" then
      far.Message (M.MTotalReplaced .. FormatInt(nReps), params.Title)
    end
  end
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
local function Run(params)
  local libSettings = require("far2.settings")
  local ST = libSettings.mload(SETTINGS_KEY, SETTINGS_NAME) or {}
  MultilineSearch (params[1] and "repeat" or "search", ST, nil)
  libSettings.msave(SETTINGS_KEY, SETTINGS_NAME, ST)
end

AddToMenu ("e", "Multiline Search",       "Ctrl+7", Run)
AddToMenu ("e", "Multiline Search Again", "Ctrl+8", Run, true)
