-- lfs_common.lua

local M      = require "lfs_message"
local RepLib = require "lfs_replib"
local sd     = require "far2.simpledialog"

local F = far.Flags
local KEEP_DIALOG_OPEN = 0

local function ErrorMsg (text, title)
  far.Message (text, title or M.MError, nil, "w")
end

local function FormatInt (num)
  return tostring(num):reverse():gsub("...", "%1,"):gsub(",$", ""):reverse()
end

local function MakeGsub (mode)
  local sub, len
  if     mode == "widechar"  then sub, len = win.subW, win.lenW
  elseif mode == "byte"      then sub, len = string.sub, string.len
  elseif mode == "multibyte" then sub, len = ("").sub, ("").len
  else return nil
  end

  return function (aSubj, aRegex, aRepFunc, ...)
    local ufind_method = mode=="widechar" and aRegex.ufindW or aRegex.ufind
    local nFound, nReps = 0, 0
    local tOut = {}
    local x, last_to = 1, -1
    local len_limit = 1 + len(aSubj)

    while x <= len_limit do
      local collect = ufind_method(aRegex, aSubj, x)
      if not collect then break end
      local from, to = collect[1], collect[2]

      if to == last_to then
        -- skip empty match adjacent to previous match
        tOut[#tOut+1] = sub(aSubj, x, x)
        x = x + 1
      else
        last_to = to
        tOut[#tOut+1] = sub(aSubj, x, from-1)
        collect[2] = sub(aSubj, from, to)
        nFound = nFound + 1

        local sRepFinal, ret2 = aRepFunc(collect, ...)
        if type(sRepFinal) == "string" then
          tOut[#tOut+1] = sRepFinal
          nReps = nReps + 1
        else
          tOut[#tOut+1] = sub(aSubj, from, to)
        end

        if from <= to then
          x = to + 1
        else
          tOut[#tOut+1] = sub(aSubj, from, from)
          x = from + 1
        end

        if ret2 then break end
      end
    end
    tOut[#tOut+1] = sub(aSubj, x)
    return table.concat(tOut), nFound, nReps
  end
end


local hst_map = { ["\\"]="\\"; n="\n"; r="\r"; t="\t"; }

local function GetDialogHistory (name)
  local value
  local fname = os.getenv("HOME").."/.config/far2l/history/dialogs.hst"
  local fp = io.open(fname)
  if fp then
    local head = ("[SavedDialogHistory/%s]"):format(name)
    local in_section
    for line in fp:lines() do
      if in_section then
        if line:find("[", 1, true) == 1 then -- new section begins
          break
        end
        local v = line:match("^Lines=(.*)")
        if v then
          if v:sub(1,1) == '"' then
            v = v:sub(2,-2):gsub("\\(.)", hst_map)
            value = v:match("(.-)\n") or v
          else
            value = v
          end
          break
        end
      elseif line:find(head, 1, true) == 1 then
        in_section = true
      end
    end
    fp:close()
  end
  return value
end


local function EditorConfigDialog()
  local Items = {
    width = 76;
    help = "Contents";
    {tp="dbox";  text=M.MConfigTitle; },
    {tp="chbox"; name="bForceScopeToBlock";  text=M.MOptForceScopeToBlock; },
    {tp="chbox"; name="bSelectFound";        text=M.MOptSelectFound; },
    {tp="text";  text=M.MPickFrom; ystep=2; },
    {tp="rbutt"; x1=7;  name="rPickEditor";  text=M.MPickEditor; group=1; val=1; },
    {tp="rbutt"; x1=27; name="rPickHistory"; text=M.MPickHistory; y1=""; },
    {tp="rbutt"; x1=47; name="rPickNowhere"; text=M.MPickNowhere; y1=""; },
    {tp="sep"; ystep=2; },
    {tp="butt"; centergroup=1; text=M.MOk;    default=1; },
    {tp="butt"; centergroup=1; text=M.MCancel; cancel=1; },
  }
  ----------------------------------------------------------------------------
  local Data = _Plugin.History["config"]
  sd.LoadData(Data, Items)
  local out = sd.Run(Items)
  if out then
    sd.SaveData(out, Data)
    return true
  end
end

local function CreateUfindMethod (tb_methods)
  if tb_methods.ufind == nil then
    tb_methods.ufind = function(r, s, init)
      init = init and s:offset(init)
      local fr,to,t = r:tfind(s, init)
      if fr ~= nil then
        table.insert(t, 1, fr)
        table.insert(t, 2, to)
        return t
      end
    end
  end
end


local function GetRegexLib (engine_name)
  local base, deriv = nil, {}
  -----------------------------------------------------------------------------
  if engine_name == "far" then
    base = regex
    deriv.new = regex.new
    local tb_methods = getmetatable(regex.new(".")).__index
    if tb_methods.ufind == nil then
      local find = tb_methods.find
      tb_methods.ufind = function(r, s, init)
        local t = { find(r, s, init) }
        if t[1] ~= nil then return t end
      end
    end
  -----------------------------------------------------------------------------
  elseif engine_name == "pcre" then
    base = require "rex_pcre"
    local CFlags = 0x800 -- PCRE_UTF8
    local v1, v2 = base.version():match("(%d+)%.(%d+)")
    v1, v2 = tonumber(v1), tonumber(v2)
    if v1 > 8 or (v1 == 8 and v2 >= 10) then
      CFlags = bit.bor(CFlags, 0x20000000) -- PCRE_UCP
    end
    local TF = { i=1, m=2, s=4, x=8, U=0x200, X=0x40 }
    deriv.new = function (pat, cf)
      local cflags = CFlags
      if cf then
        for c in cf:gmatch(".") do cflags = bit.bor(cflags, TF[c] or 0) end
      end
      return base.new (pat, cflags)
    end
    local tb_methods = getmetatable(base.new(".")).__index
    CreateUfindMethod(tb_methods)
    tb_methods.gsub = function(regex, subj, rep) return base.gsub(subj, regex, rep) end
  -----------------------------------------------------------------------------
  elseif engine_name == "oniguruma" then
    base = require "rex_onig"
    deriv.new = function (pat, cf) return base.new (pat, cf, "UTF8", "PERL_NG") end
    local tb_methods = getmetatable(base.new(".")).__index
    CreateUfindMethod(tb_methods)
    tb_methods.gsub = function(regex, subj, rep) return base.gsub(subj, regex, rep) end
  -----------------------------------------------------------------------------
  else
    error "argument #1 invalid or missing"
  end
  return setmetatable(deriv, {__index=base})
end

-- If cursor is right after the word pick up the word too.
local function GetWordUnderCursor (select)
  local line = editor.GetString()
  local pos = editor.GetInfo().CurPos
  local r = regex.new("(\\w+)")
  local offset = r:find(line.StringText:sub(pos==1 and pos or pos-1, pos))
  if offset then
    local _, last = r:find(line.StringText, pos==1 and pos or (pos+offset-2))
    local from, to, word = r:find(line.StringText:reverse(), line.StringLength-last+1)
    if select then
      editor.Select("BTYPE_STREAM", nil, line.StringLength-to+1, to-from+1, 1)
    end
    return word:reverse()
  end
end


local function EscapeSearchPattern(pat)
  pat = string.gsub(pat, "[~!@#$%%^&*()%-+[%]{}\\|:;'\",<.>/?]", "\\%1")
  return pat
end


local function GetCFlags (aData, bInEditor)
  local cflags = aData.bCaseSens and "" or "i"
  if aData.bRegExpr then
    if aData.bExtended then cflags = cflags.."x" end
    if aData.bFileAsLine then cflags = cflags.."s" end
    if not bInEditor or aData.bMultiLine then cflags = cflags.."m" end
  end
  return cflags
end


local function ProcessSinglePattern (rex, aPattern, aData)
  aPattern = aPattern or ""
  local SearchPat = aPattern
  if not aData.bRegExpr then
    SearchPat = EscapeSearchPattern(SearchPat)
    if aData.bWholeWords then
      if rex.find(aPattern, "^\\w") then SearchPat = "\\b"..SearchPat end
      if rex.find(aPattern, "\\w$") then SearchPat = SearchPat.."\\b" end
    end
  end
  return SearchPat
end


-- There are 2 sequence types recognized:
-- (1) starts with non-space && non-quote, ends before a space
-- (2) enclosed in quotes, may contain inside pairs of quotes, ends before a space
local OnePattern = [[
  ([+\-] | (?! [+\-]))
  (?:
    ([^\s"]\S*) |
    "((?:[^"] | "")+)" (?=\s|$)
  ) |
  (\S)
]]

local function ProcessMultiPatterns (aData, rex)
  local subject = aData.sSearchPat or ""
  local cflags = GetCFlags(aData, false)
  local Plus, Minus, Usual = {}, {}, {}
  local PlusGuard = {}
  local NumPatterns = 0
  for sign, nonQ, Q, tail in regex.gmatch(subject, OnePattern, "x") do
    if tail then error("invalid multi-pattern") end
    local pat = nonQ or Q:gsub([[""]], [["]])
    pat = ProcessSinglePattern(rex, pat, aData)
    if sign == "+" then
      if not PlusGuard[pat] then
        Plus[ rex.new(pat, cflags) ] = true
        PlusGuard[pat] = true
      end
    elseif sign == "-" then
      Minus[#Minus+1] = "(?:"..pat..")"
    else
      Usual[#Usual+1] = "(?:"..pat..")"
    end
    NumPatterns = NumPatterns + 1
  end
  Minus = Minus[1] and table.concat(Minus, "|")
  Usual = Usual[1] and table.concat(Usual, "|")
  Minus = Minus and rex.new(Minus, cflags)
  Usual = Usual and rex.new(Usual, cflags)
  return { Plus=Plus, Minus=Minus, Usual=Usual, NumPatterns=NumPatterns }
end


local function ProcessDialogData (aData, bReplace, bInEditor, bUseMultiPatterns, bSkip)
  local params = {}
  params.bFileAsLine = aData.bFileAsLine
  params.bInverseSearch = aData.bInverseSearch
  params.bConfirmReplace = aData.bConfirmReplace
  params.bSearchBack = aData.bSearchBack
  params.bDelEmptyLine = aData.bDelEmptyLine
  params.bDelNonMatchLine = aData.bDelNonMatchLine
  params.sOrigin = aData.sOrigin
  params.sSearchPat = aData.sSearchPat or ""
  params.FileFilter = aData.bUseFileFilter and aData.FileFilter
  ---------------------------------------------------------------------------
  params.Envir = setmetatable({}, {__index=_G})
  params.Envir.dofile = function(fname)
    local f = assert(loadfile(fname))
    return setfenv(f, params.Envir)()
  end
  ---------------------------------------------------------------------------
  local libname = aData.sRegexLib or "far"
  local ok, rex = pcall(GetRegexLib, libname)
  if not ok then
    ErrorMsg(rex, "Error loading '"..libname.."'")
    return
  end
  params.Envir.rex = rex

  if bUseMultiPatterns and aData.bMultiPatterns then
    local ok, ret = pcall(ProcessMultiPatterns, aData, rex)
    if ok then params.tMultiPatterns, params.Regex = ret, rex.new(".")
    else ErrorMsg(ret, M.MSearchPattern..": "..M.MSyntaxError); return nil,"sSearchPat"
    end
  else
    local SearchPat = ProcessSinglePattern(rex, aData.sSearchPat, aData)
    local cflags = GetCFlags(aData, bInEditor)
    if libname=="far" then cflags = cflags.."o"; end -- optimize
    local ok, ret = pcall(rex.new, SearchPat, cflags)
    if not ok then
      ErrorMsg(ret, M.MSearchPattern..": "..M.MSyntaxError)
      return nil,"sSearchPat"
    end
    if bSkip then
      local SkipPat = ProcessSinglePattern(rex, aData.sSkipPat, aData)
      ok, ret = pcall(rex.new, SkipPat, cflags)
      if not ok then
        ErrorMsg(ret, M.MSkipPattern..": "..M.MSyntaxError)
        return nil,"sSkipPat"
        end
      local Pat = "("..SkipPat..")" .. "|" .. "(?:"..SearchPat..")" -- SkipPat has priority over SearchPat
      ret = assert(rex.new(Pat, cflags), "invalid combined reqular expression")
      params.bSkip = true
    end
    params.Regex = ret
  end
  ---------------------------------------------------------------------------
  if bReplace then
    if aData.bRepIsFunc then
      local func, msg = loadstring("local T,M,R,LN = ...\n" .. aData.sReplacePat, M.MReplaceFunction)
      if func then params.ReplacePat = setfenv(func, params.Envir)
      else ErrorMsg(msg, M.MReplaceFunction..": "..M.MSyntaxError); return
      end
    else
      params.ReplacePat = aData.sReplacePat
      if aData.bRegExpr then
        local ok, ret = pcall(RepLib.TransformReplacePat, params.ReplacePat)
        if ok then params.ReplacePat = ret
        else ErrorMsg(ret, M.MReplacePattern..": "..M.MSyntaxError); return
        end
      end
    end
  end
  ---------------------------------------------------------------------------
  if aData.bAdvanced then
    if aData.sFilterFunc then
      local func, msg = loadstring("local s,n=...\n"..aData.sFilterFunc, "Line Filter")
      if func then params.FilterFunc = setfenv(func, params.Envir)
      else ErrorMsg(msg, "Line Filter function: " .. M.MSyntaxError); return
      end
    end
    -------------------------------------------------------------------------
    local func, msg = loadstring (aData.sInitFunc or "", "Initial")
    if func then params.InitFunc = setfenv(func, params.Envir)
    else ErrorMsg(msg, "Initial Function: " .. M.MSyntaxError); return
    end
    func, msg = loadstring (aData.sFinalFunc or "", "Final")
    if func then params.FinalFunc = setfenv(func, params.Envir)
    else ErrorMsg(msg, "Final Function: " .. M.MSyntaxError); return
    end
    -------------------------------------------------------------------------
  end
  return params
end

local SRFrame = {}
SRFrame.Libs = {"far", "oniguruma", "pcre"}
local SRFrameMeta = {__index = SRFrame}

local function CreateSRFrame (Items, aData, bInEditor)
  local self = {Items=Items, Data=aData, bInEditor=bInEditor}
  return setmetatable(self, SRFrameMeta)
end

function SRFrame:InsertInDialog (aPanelsDialog, aOp)
  local insert = table.insert
  local Items = self.Items
  local md = 40 -- "middle"
  insert(Items, { tp="text"; text=M.MDlgSearchPat; })
  insert(Items, { tp="edit"; name="sSearchPat"; hist="SearchText"; })
  ------------------------------------------------------------------------------
  if aOp == "replace" then
    insert(Items, { tp="text";  text=M.MDlgReplacePat; })
    insert(Items, { tp="edit";  name="sReplacePat";      hist="ReplaceText"; })
    insert(Items, { tp="chbox"; name="bRepIsFunc";       x1=7,         text=M.MDlgRepIsFunc; })
    insert(Items, { tp="chbox"; name="bDelEmptyLine";    x1=md, y1=""; text=M.MDlgDelEmptyLine; })
    insert(Items, { tp="chbox"; name="bConfirmReplace";  x1=7,         text=M.MDlgConfirmReplace; })
    insert(Items, { tp="chbox"; name="bDelNonMatchLine"; x1=md, y1=""; text=M.MDlgDelNonMatchLine; })
  end
  ------------------------------------------------------------------------------
  insert(Items, { tp="sep"; })
  ------------------------------------------------------------------------------
  insert(Items, { tp="chbox"; name="bRegExpr";                         text=M.MDlgRegExpr;  })
  insert(Items, { tp="text";                         y1=""; x1=md;     text=M.MDlgRegexLib; })
  local x1 = md + M.MDlgRegexLib:len()
  insert(Items, { tp="combobox"; name="cmbRegexLib"; y1=""; x1=x1; width=14; dropdownlist=1; noauto=1;
           list = { {Text="Far regex"}, {Text="Oniguruma"}, {Text="PCRE"} };  })
  ------------------------------------------------------------------------------
  insert(Items, { tp="chbox"; name="bCaseSens";                        text=M.MDlgCaseSens; })
  insert(Items, { tp="chbox"; name="bExtended"; x1=md; y1="";          text=M.MDlgExtended; })
  insert(Items, { tp="chbox"; name="bWholeWords";                      text=M.MDlgWholeWords; })
  ------------------------------------------------------------------------------
  if aPanelsDialog and aOp=="search" then
    insert(Items, { tp="chbox"; name="bFileAsLine";    x1=md; y1="";   text=M.MDlgFileAsLine;    })
    insert(Items, { tp="chbox"; name="bMultiPatterns";                 text=M.MDlgMultiPatterns; })
    insert(Items, { tp="chbox"; name="bInverseSearch"; x1=md; y1="";   text=M.MDlgInverseSearch; })
  end
end

function SRFrame:CheckRegexInit (hDlg, Data)
  local Pos = self.Pos or sd.Indexes(self.Items)
  self.Pos = Pos
  hDlg:SetCheck (Pos.bWholeWords, Data.bWholeWords)
  hDlg:SetCheck (Pos.bExtended,   Data.bExtended)
  hDlg:SetCheck (Pos.bCaseSens,   Data.bCaseSens)
  self:CheckRegexChange(hDlg)
end

function SRFrame:CheckRegexChange (hDlg)
  local Pos = self.Pos or sd.Indexes(self.Items)
  self.Pos = Pos
  local bRegex = hDlg:GetCheck(Pos.bRegExpr)

  if bRegex then hDlg:SetCheck(Pos.bWholeWords, false) end
  hDlg:Enable(Pos.bWholeWords, not bRegex)

  if not bRegex then hDlg:SetCheck(Pos.bExtended, false) end
  hDlg:Enable(Pos.bExtended, bRegex)

  if Pos.bFileAsLine then
    if not bRegex then hDlg:SetCheck(Pos.bFileAsLine, false) end
    hDlg:Enable(Pos.bFileAsLine, bRegex)
  end
end

function SRFrame:CheckAdvancedEnab (hDlg)
  local Pos = self.Pos or sd.Indexes(self.Items)
  self.Pos = Pos
  local bEnab = hDlg:GetCheck(Pos.bAdvanced)
  hDlg:Enable(Pos.labFilterFunc, bEnab)
  hDlg:Enable(Pos.sFilterFunc  , bEnab)
  hDlg:Enable(Pos.labInitFunc  , bEnab)
  hDlg:Enable(Pos.sInitFunc    , bEnab)
  hDlg:Enable(Pos.labFinalFunc , bEnab)
  hDlg:Enable(Pos.sFinalFunc   , bEnab)
end

function SRFrame:OnDataLoaded (aData, aScriptCall)
  local Pos = self.Pos or sd.Indexes(self.Items)
  self.Pos = Pos
  self.ScriptCall = aScriptCall
  local Items = self.Items
  local bInEditor = self.bInEditor

  if not aScriptCall then
    if bInEditor then
      local data = _Plugin.History["config"]
      if data.rPickHistory then
        Items[Pos.sSearchPat].text = GetDialogHistory("SearchText") or aData.sSearchPat or ""
      elseif data.rPickNowhere then
        Items[Pos.sSearchPat].text = ""
        if Pos.sReplacePat then Items[Pos.sReplacePat].text = ""; end
      else -- (default) if data.rPickEditor then
        Items[Pos.sSearchPat].text = GetWordUnderCursor() or ""
      end
    else
      Items[Pos.sSearchPat].text = (aData.sSearchPat == "") and "" or
        GetDialogHistory("SearchText") or aData.sSearchPat or ""
    end
  end

  local item = Items[Pos.cmbRegexLib]
  item.val = 1
  for i,v in ipairs(self.Libs) do
    if aData.sRegexLib == v then item.val = i; break; end
  end
end

function SRFrame:GetLibName (hDlg)
  local pos = hDlg:ListGetCurPos(self.Pos.cmbRegexLib)
  return self.Libs[pos.SelectPos]
end

function SRFrame:DlgProc (hDlg, msg, param1, param2)
  local Pos = self.Pos or sd.Indexes(self.Items)
  self.Pos = Pos
  local Data, bInEditor = self.Data, self.bInEditor
  local bReplace = Pos.sReplacePat
  ----------------------------------------------------------------------------
  if msg == F.DN_INITDIALOG then
    if bInEditor then
      local EI = editor.GetInfo()
      if EI.BlockType == F.BTYPE_NONE then
        hDlg:SetCheck (Pos.rScopeGlobal, 1)
        hDlg:Enable   (Pos.rScopeBlock, 0)
      else
        local bScopeBlock
        local bForceBlock = _Plugin.History["config"].bForceScopeToBlock
        if self.ScriptCall or not bForceBlock then
          bScopeBlock = (Data.sScope == "block")
        else
          local line = editor.GetString(EI.BlockStartLine+1) -- test the 2-nd selected line
          bScopeBlock = line and line.SelStart>0
        end
        local name = bScopeBlock and "rScopeBlock" or "rScopeGlobal"
        hDlg:SetCheck(Pos[name], true)
      end
      local name = (Data.sOrigin=="scope") and "rOriginScope" or "rOriginCursor"
      hDlg:SetCheck(Pos[name], true)
      self:CheckAdvancedEnab(hDlg)
    end
    self:CheckRegexInit(hDlg, self.Data)
  ----------------------------------------------------------------------------
  elseif msg == F.DN_BTNCLICK then
    if param1==Pos.bRegExpr then
      self:CheckRegexChange(hDlg)
    elseif bInEditor and param1==Pos.bAdvanced then
      self:CheckAdvancedEnab(hDlg)
    end
  ----------------------------------------------------------------------------
  elseif msg == F.DN_EDITCHANGE then
    if param1 == Pos.cmbRegexLib then self:CheckRegexChange(hDlg) end
  ----------------------------------------------------------------------------
  elseif msg == F.DN_CLOSE then
    if (param1 == Pos.btnOk) or bInEditor and
      (Pos.btnCount and param1 == Pos.btnCount or Pos.btnShowAll and param1 == Pos.btnShowAll)
    then
      Data.sSearchPat  = hDlg:GetText(Pos.sSearchPat)
      Data.bCaseSens   = hDlg:GetCheck(Pos.bCaseSens)
      Data.bRegExpr    = hDlg:GetCheck(Pos.bRegExpr)
      Data.bWholeWords = hDlg:GetCheck(Pos.bWholeWords)
      Data.bExtended   = hDlg:GetCheck(Pos.bExtended)
      if Pos.bFileAsLine    then Data.bFileAsLine    = hDlg:GetCheck(Pos.bFileAsLine)    end
      if Pos.bMultiPatterns then Data.bMultiPatterns = hDlg:GetCheck(Pos.bMultiPatterns) end
      if Pos.bInverseSearch then Data.bInverseSearch = hDlg:GetCheck(Pos.bInverseSearch) end
      ------------------------------------------------------------------------
      if bInEditor then
        if Data.sSearchPat == "" then
          ErrorMsg(M.MSearchFieldEmpty)
          return KEEP_DIALOG_OPEN
        end
        Data.bSearchBack = hDlg:GetCheck(Pos.bSearchBack)

        Data.sScope  = hDlg:GetCheck(Pos.rScopeGlobal)  and "global" or "block"
        Data.sOrigin = hDlg:GetCheck(Pos.rOriginCursor) and "cursor" or "scope"
        Data.bAdvanced   = hDlg:GetCheck(Pos.bAdvanced)
        Data.sFilterFunc = hDlg:GetText(Pos.sFilterFunc)
        Data.sInitFunc   = hDlg:GetText(Pos.sInitFunc)
        Data.sFinalFunc  = hDlg:GetText(Pos.sFinalFunc)
      end
      ------------------------------------------------------------------------
      if bReplace then
        Data.sReplacePat      = hDlg:GetText (Pos.sReplacePat)
        Data.bRepIsFunc       = hDlg:GetCheck(Pos.bRepIsFunc)
        Data.bDelEmptyLine    = hDlg:GetCheck(Pos.bDelEmptyLine)
        Data.bConfirmReplace  = hDlg:GetCheck(Pos.bConfirmReplace)
        Data.bDelNonMatchLine = hDlg:GetCheck(Pos.bDelNonMatchLine)
      end
      ------------------------------------------------------------------------
      local lib = self:GetLibName(hDlg)
      local ok, err = pcall(GetRegexLib, lib)
      if not ok then
        (export.OnError or ErrorMsg)(err)
        return KEEP_DIALOG_OPEN
      end
      Data.sRegexLib = lib
      ------------------------------------------------------------------------
      self.close_params = ProcessDialogData(Data, bReplace, bInEditor, Pos.bMultiPatterns and Data.bMultiPatterns)
      if not self.close_params then
        return KEEP_DIALOG_OPEN
      end
    end
  end
end


local function GetReplaceFunction (aReplacePat)
  if type(aReplacePat) == "function" then
    return function(collect,nMatch,nReps,nLine)
      --local T = { [0]=collect[2], unpack(collect, 3) }

      collect[0] = collect[2]
      table.remove(collect, 2)
      table.remove(collect, 1)

      local R1,R2 = aReplacePat(collect, nMatch, nReps+1, nLine)
      if type(R1)=="number" then R1=tostring(R1) end
      return R1, R2
    end

  elseif type(aReplacePat) == "string" then
    return function() return aReplacePat end

  elseif type(aReplacePat) == "table" then
    return RepLib.GetReplaceFunction(aReplacePat)

  else
    error("invalid type of replace pattern")
  end
end


return {
  EditorConfigDialog = EditorConfigDialog;
  CreateSRFrame      = CreateSRFrame;
  ErrorMsg           = ErrorMsg;
  FormatInt          = FormatInt;
  GetDialogHistory   = GetDialogHistory;
  GetReplaceFunction = GetReplaceFunction;
  GetWordUnderCursor = GetWordUnderCursor;
  Gsub               = MakeGsub("byte");
  GsubW              = MakeGsub("widechar");
  GsubMB             = MakeGsub("multibyte");
  ProcessDialogData  = ProcessDialogData;
}
