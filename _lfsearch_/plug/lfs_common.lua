-- lfs_common.lua
-- luacheck: globals _Plugin

local M       = require "lfs_message"
local RepLib  = require "lfs_replib"
local sd      = require "far2.simpledialog"

local band, bnot, bor = bit64.band, bit64.bnot, bit64.bor
local Utf8, Utf32 = win.Utf32ToUtf8, win.Utf8ToUtf32
local uchar = ("").char
local F = far.Flags
local KEEP_DIALOG_OPEN = 0

local function ErrorMsg (text, title)
  far.Message (text, title or M.MError, nil, "w")
end

local function FormatInt (num)
  return tostring(num):reverse():gsub("...", "%1,"):gsub(",$", ""):reverse()
end

local function FormatTime (tm)
  if tm < 0 then tm = 0 end
  local fmt = (tm < 10) and "%.2f" or (tm < 100) and "%.1f" or "%.0f"
  return fmt:format(tm)
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
      local from, to, collect = ufind_method(aRegex, aSubj, x)
      if not from then break end

      if to == last_to then
        -- skip empty match adjacent to previous match
        tOut[#tOut+1] = sub(aSubj, x, x)
        x = x + 1
      else
        last_to = to
        tOut[#tOut+1] = sub(aSubj, x, from-1)
        collect[0] = sub(aSubj, from, to)
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


local function SaveCodePageCombo (hDlg, combo_pos, combo_list, aData, aSaveCurPos)
  if aSaveCurPos then
    local pos = hDlg:ListGetCurPos(combo_pos).SelectPos
    aData.iSelectedCodePage = combo_list[pos].CodePage
  end
  aData.tCheckedCodePages = {}
  local info = hDlg:ListInfo(combo_pos)
  for i=1,info.ItemsNumber do
    local item = hDlg:ListGetItem(combo_pos, i)
    if 0 ~= band(item.Flags, F.LIF_CHECKED) then
      local t = hDlg:ListGetData(combo_pos, i)
      if t then table.insert(aData.tCheckedCodePages, t) end
    end
  end
end


local SearchAreas = {
  { name = "FromCurrFolder",  msg = "MSaFromCurrFolder" },
  { name = "OnlyCurrFolder",  msg = "MSaOnlyCurrFolder" },
  { name = "SelectedItems",   msg = "MSaSelectedItems"  },
  { name = "RootFolder",      msg = ""                  },
--{ name = "NonRemovDrives",  msg = "MSaNonRemovDrives" },
--{ name = "LocalDrives",     msg = "MSaLocalDrives"    },
  { name = "PathFolders",     msg = "MSaPathFolders"    },
}
for k,v in ipairs(SearchAreas) do SearchAreas[v.name]=k end

local function IndexToSearchArea(index)
  index = index or 1
  if index < 1 or index > #SearchAreas then index = 1 end
  return SearchAreas[index].name
end

local function SearchAreaToIndex(area)
  return type(area)=="string" and SearchAreas[area] or 1
end

local function CheckSearchArea(area)
  assert(not area or SearchAreas[area], "invalid search area")
  return SearchAreas[SearchAreaToIndex(area)].name
end

local function GetSearchAreas(aData)
  local Info = panel.GetPanelInfo(1)
  local RootFolderItem = {}
  if Info.PanelType==F.PTYPE_FILEPANEL and not Info.Plugin then
    RootFolderItem.Text = M.MSaRootFolder .. panel.GetPanelDirectory(1):match("/[^/]*")
  else
    RootFolderItem.Text = M.MSaRootFolder
    RootFolderItem.Flags = F.LIF_GRAYED
  end

  local T = {}
  for k,v in ipairs(SearchAreas) do
    T[k] = v.name == "RootFolder" and RootFolderItem or { Text = M[v.msg] }
  end

  local idx = SearchAreaToIndex(aData.sSearchArea)
  if (idx < 1) or (idx > #T) or (T[idx].Flags == F.LIF_GRAYED) then
    idx = 1
  end
  T.SelectIndex = idx
  return T
end


local hst_map = { ["\\"]="\\"; n="\n"; r="\r"; t="\t"; }

local function GetDialogHistory (name)
  local value
  local fname = far.GetConfigDir().."/history/dialogs.hst"
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
  local offset = 5 + M.MBtnHighlightColor:len() + 5
  ----------------------------------------------------------------------------
  local Items = {
    width = 76;
    help = "Contents";
    {tp="dbox";  text=M.MConfigTitle; },
    {tp="chbox"; name="bForceScopeToBlock";  text=M.MOptForceScopeToBlock; },
    {tp="chbox"; name="bSelectFound";        text=M.MOptSelectFound; },
    {tp="chbox"; name="bShowSpentTime";      text=M.MOptShowSpentTime; },
    {tp="text";  text=M.MPickFrom; ystep=2; },
    {tp="rbutt"; x1=7;  name="rPickEditor";  text=M.MPickEditor; group=1; val=1; },
    {tp="rbutt"; x1=27; name="rPickHistory"; text=M.MPickHistory; y1=""; },
    {tp="rbutt"; x1=47; name="rPickNowhere"; text=M.MPickNowhere; y1=""; },

    {tp="sep"; ystep=2; },
    {tp="butt"; name="btnHighlight"; text=M.MBtnHighlightColor; btnnoclose=1; },
    {tp="text"; name="labHighlight"; text=M.MTextSample; x1=offset; y1=""; width=M.MTextSample:len(); },

    {tp="sep"; },
    {tp="butt"; centergroup=1; text=M.MOk;    default=1; },
    {tp="butt"; centergroup=1; text=M.MCancel; cancel=1; },
  }
  ----------------------------------------------------------------------------
  local Pos = sd.Indexes(Items)
  local Data = _Plugin.History["config"]
  sd.LoadData(Data, Items)

  local hColor0 = Data.EditorHighlightColor

  Items.proc = function(hDlg, msg, param1, param2)
    if msg == F.DN_BTNCLICK then
      if param1 == Pos.btnHighlight then
        local c = far.ColorDialog(hColor0)
        if c then hColor0 = c; hDlg:Redraw(); end
      end

    elseif msg == F.DN_CTLCOLORDLGITEM then
      if param1 == Pos.labHighlight then param2 = hColor0; return param2; end
    end
  end

  local out = sd.Run(Items)
  if out then
    sd.SaveData(out, Data)
    Data.EditorHighlightColor = hColor0
    _Plugin.SaveSettings()
    return true
  end
end


local TUserBreak = {
  time       = nil;
  cancel     = nil;
  fullcancel = nil;
}
local UserBreakMeta = { __index=TUserBreak }

local function NewUserBreak()
  return setmetatable({ time=0 }, UserBreakMeta)
end

function TUserBreak:ConfirmEscape (in_file)
  local ret
  if win.ExtractKey() == "ESCAPE" then
    local hScreen = far.SaveScreen()
    local msg = M.MInterrupted.."\n"..M.MConfirmCancel
    local t1 = os.clock()
    if in_file then
      -- [Cancel current file] [Cancel all files] [Continue]
      local r = far.Message(msg, M.MMenuTitle, M.MButtonsCancelOnFile, "w")
      if r == 2 then
        self.fullcancel = true
      end
      ret = r==1 or r==2
    else
      -- [Yes] [No]
      local r = far.Message(msg, M.MMenuTitle, M.MBtnYesNo, "w")
      if r == 1 then
        self.fullcancel = true
        ret = true
      end
    end
    self.time = self.time + os.clock() - t1
    far.RestoreScreen(hScreen); far.Text();
  end
  return ret
end

function TUserBreak:fInterrupt()
  local c = self:ConfirmEscape("in_file")
  self.cancel = c
  return c
end


local function set_progress (LEN, ratio, space)
  space = space or ""
  local uchar1, uchar2 = uchar(9608), uchar(9617)
  local len = math.floor(ratio*LEN + 0.5)
  local text = uchar1:rep(len) .. uchar2:rep(LEN-len) .. space .. ("%3d%%"):format(ratio*100)
  return text
end


local DisplaySearchState do
  local lastclock = 0
  local wMsg, wHead = 60, 10
  local wTail = wMsg - wHead - 3
  DisplaySearchState = function (fullname, cntFound, cntTotal, ratio, userbreak)
    local newclock = win.Clock()
    if newclock >= lastclock then
      lastclock = newclock + 0.2 -- period = 0.2 sec
      local len = fullname:len()
      local s = len<=wMsg and fullname..(" "):rep(wMsg-len) or
                fullname:sub(1,wHead).. "..." .. fullname:sub(-wTail)
      far.Message(
        (s.."\n") .. (set_progress(wMsg-4, ratio).."\n") .. (M.MFilesFound..cntFound.."/"..cntTotal),
        M.MTitleSearching, "")
      return userbreak and userbreak:ConfirmEscape()
    end
  end
end


-- Same as tfind, but all input and output offsets are in characters rather than bytes.
local function WrapTfindMethod (tfind)
  local usub, ssub = ("").sub, string.sub
  local ulen = ("").len
  return function(patt, s, init)
    init = init and #(usub(s, 1, init-1)) + 1
    local from, to, t = tfind(patt, s, init)
    if from == nil then return nil end
    return ulen(ssub(s, 1, from-1)) + 1, ulen(ssub(s, 1, to)), t
  end
end


--------------------------------------------------------------------------------
-- @param lib_name
--    Either of ("far", "pcre", "pcre2", "oniguruma").
-- @return
--    A table that "mirrors" the specified library's table (via
--    metatable.__index) and that may have its own version of function "new".

--    This function also inserts some methods into the existing methods table
--    of the compiled regex for the specified library.
--    Inserted are methods "ufind", "gsub" and/or "gsubW".
--------------------------------------------------------------------------------
local function GetRegexLib (lib_name)
  local base, deriv = nil, {}
  -----------------------------------------------------------------------------
  if lib_name == "far" then
    base = regex
    local tb_methods = getmetatable(regex.new(".")).__index
    tb_methods.ufind = tb_methods.tfind
    tb_methods.ufindW = tb_methods.tfindW
    tb_methods.capturecount = function(r) return r:bracketscount() - 1 end
  -----------------------------------------------------------------------------
  elseif lib_name == "pcre" then
    base = require("rex_pcre")
    local ff = base.flags()
    local CFlags = bor(ff.NEWLINE_ANYCRLF, ff.UTF8)
    local v1, v2 = base.version():match("(%d+)%.(%d+)")
    v1, v2 = tonumber(v1), tonumber(v2)
    if 1000*v1 + v2 >= 8010 then
      CFlags = bor(CFlags, ff.UCP)
    end
    local TF = { i=ff.CASELESS, m=ff.MULTILINE, s=ff.DOTALL, x=ff.EXTENDED, U=ff.UNGREEDY, X=ff.EXTRA }
    deriv.new = function (pat, cf)
      local cflags = CFlags
      if cf then
        for c in cf:gmatch(".") do cflags = bor(cflags, TF[c] or 0) end
      end
      return base.new (pat, cflags)
    end
    local tb_methods = getmetatable(base.new(".")).__index
    tb_methods.ufind = WrapTfindMethod(tb_methods.tfind)
    tb_methods.gsub = function(patt, subj, rep) return base.gsub(subj, patt, rep) end
    tb_methods.capturecount = function(patt) return patt:fullinfo().CAPTURECOUNT end
  -----------------------------------------------------------------------------
  elseif lib_name == "oniguruma" then
    base = require("rex_onig")
    deriv.new = function (pat, cf) return base.new (pat, cf, "UTF8", "PERL_NG") end
    local tb_methods = getmetatable(base.new(".")).__index
    tb_methods.ufind = WrapTfindMethod(tb_methods.tfind)
    -- tb_methods.capturecount = tb_methods.capturecount -- this method is already available
  -----------------------------------------------------------------------------
  else
    error "unsupported name of regexp library"
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
  params.bWrapAround = aData.bWrapAround
  params.bSearchBack = aData.bSearchBack
  params.bDelEmptyLine = aData.bDelEmptyLine
  params.bDelNonMatchLine = aData.bDelNonMatchLine
  params.bHighlight = aData.bHighlight
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
  if Pos.bAdvanced then
    local bEnab = hDlg:GetCheck(Pos.bAdvanced)
    hDlg:Enable(Pos.labFilterFunc, bEnab)
    hDlg:Enable(Pos.sFilterFunc  , bEnab)
    hDlg:Enable(Pos.labInitFunc  , bEnab)
    hDlg:Enable(Pos.sInitFunc    , bEnab)
    hDlg:Enable(Pos.labFinalFunc , bEnab)
    hDlg:Enable(Pos.sFinalFunc   , bEnab)
  end
end

function SRFrame:CheckWrapAround (hDlg)
  local Pos = self.Pos or sd.Indexes(self.Items)
  self.Pos = Pos
  if self.bInEditor and Pos.bWrapAround then
    local bEnab = hDlg:GetCheck(Pos.rScopeGlobal) and hDlg:GetCheck(Pos.rOriginCursor)
    hDlg:Enable(Pos.bWrapAround, bEnab)
  end
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

function SRFrame:CompleteLoadData (hDlg, Data, LoadFromPreset)
  local Pos = self.Pos
  local bScript = self.bScriptCall or LoadFromPreset

  if self.bInEditor then
    -- Set scope
    local EI = editor.GetInfo()
    if EI.BlockType == F.BTYPE_NONE then
      hDlg:SetCheck(Pos.rScopeGlobal, true)
      hDlg:Enable(Pos.rScopeBlock, false)
    else
      local bScopeBlock
      local bForceBlock = _Plugin.History.config.bForceScopeToBlock
      if bScript or not bForceBlock then
        bScopeBlock = (Data.sScope == "block")
      else
        local line = editor.GetString(EI.BlockStartLine+1) -- test the 2-nd selected line
        bScopeBlock = line and line.SelStart>0
      end
      hDlg:SetCheck(bScopeBlock and Pos.rScopeBlock or Pos.rScopeGlobal, true)
    end

    -- Set origin
    local key = bScript and "sOrigin"
                or hDlg:GetCheck(Pos.rScopeGlobal) and "sOriginInGlobal"
                or "sOriginInBlock"
    local name = Data[key]=="scope" and "rOriginScope" or "rOriginCursor"
    hDlg:SetCheck(Pos[name], true)

    self:CheckWrapAround(hDlg)
  end

  self:CheckAdvancedEnab(hDlg)
  self:CheckRegexInit(hDlg, Data)
end

function SRFrame:SaveDataDyn (hDlg, Data)
  local Pos = self.Pos
  ------------------------------------------------------------------------
  if self.bInEditor then
    Data.sScope  = hDlg:GetCheck(Pos.rScopeGlobal) and "global" or "block"
    Data.sOrigin = hDlg:GetCheck(Pos.rOriginCursor) and "cursor" or "scope"

    if not self.bScriptCall then
      local key = Data.sScope == "global" and "sOriginInGlobal" or "sOriginInBlock"
      Data[key] = Data.sOrigin -- to be passed to execution
    end
  else
    Data.sSearchArea = IndexToSearchArea(hDlg:ListGetCurPos(Pos.cmbSearchArea).SelectPos)
  end
  ------------------------------------------------------------------------
  Data.sRegexLib = self.Libs[ hDlg:ListGetCurPos(Pos.cmbRegexLib).SelectPos ]
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
    else
      if bInEditor then
        self:CheckWrapAround(hDlg)
      end
      if param1==Pos.bAdvanced then
        self:CheckAdvancedEnab(hDlg)
      end
    end
  ----------------------------------------------------------------------------
  elseif msg == F.DN_KEY and param2 == F.KEY_F4 then
    if param1 == Pos.sReplacePat and hDlg:GetCheck(Pos.bRepIsFunc) then
      local txt = sd.OpenInEditor(hDlg:GetText(Pos.sReplacePat), "lua")
      if txt then hDlg:SetText(Pos.sReplacePat, txt) end
      return true
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
        Data.bWrapAround = hDlg:GetCheck(Pos.bWrapAround)
        Data.bSearchBack = hDlg:GetCheck(Pos.bSearchBack)
        Data.bHighlight  = hDlg:GetCheck(Pos.bHighlight)

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


function SRFrame:DoPresets (hDlg)
  local Pos = self.Pos
  local HistPresetNames = _Plugin.DialogHistoryPath .. "Presets"
  hDlg:send("DM_SHOWDIALOG", 0)
  local props = { Title=M.MTitlePresets, Bottom = "Esc,Enter,F2,Ins,F6,Del", HelpTopic="Presets", }
  local presets = _Plugin.History.presets
  local bkeys = { {BreakKey="F2"}, {BreakKey="INSERT"}, {BreakKey="DELETE"}, {BreakKey="F6"} }

  while true do
    local items = {}
    for name, preset in pairs(presets) do
      local t = { text=name, preset=preset }
      items[#items+1] = t
      if name == self.PresetName then t.selected,t.checked = true,true; end
    end
    table.sort(items, function(a,b) return win.CompareString(a.text,b.text,nil,"cS") < 0; end)
    ----------------------------------------------------------------------------
    local item, pos = far.Menu(props, items, bkeys)
    ----------------------------------------------------------------------------
    if not item then break end
    ----------------------------------------------------------------------------
    if item.preset then
      self.PresetName = item.text
      local data = item.preset
      sd.SetDialogState(hDlg, self.Items, data)

      if Pos.cmbSearchArea and data.sSearchArea then
        hDlg:ListSetCurPos(Pos.cmbSearchArea, {SelectPos=SearchAreaToIndex(data.sSearchArea)} )
      end

      if Pos.cmbCodePage then
        local info = hDlg:send(F.DM_LISTINFO, Pos.cmbCodePage)
        if data.tCheckedCodePages then
          local map = {}
          for i,v in ipairs(data.tCheckedCodePages) do map[v]=i end
          for i=3,info.ItemsNumber do -- skip "Default code pages" and "Checked code pages"
            local cp = hDlg:send(F.DM_LISTGETDATA, Pos.cmbCodePage, i)
            if cp then
              local listItem = hDlg:send(F.DM_LISTGETITEM, Pos.cmbCodePage, i)
              listItem.Index = i
              if map[cp] then listItem.Flags = bor(listItem.Flags, F.LIF_CHECKED)
              else listItem.Flags = band(listItem.Flags, bnot(F.LIF_CHECKED))
              end
              hDlg:send(F.DM_LISTUPDATE, Pos.cmbCodePage, listItem)
            end
          end
        end
        if data.iSelectedCodePage then
          local scp = data.iSelectedCodePage
          for i=1,info.ItemsNumber do
            if scp == hDlg:send(F.DM_LISTGETDATA, Pos.cmbCodePage, i) then
              hDlg:ListSetCurPos(Pos.cmbCodePage, {SelectPos=i})
              break
            end
          end
        end
      end

      local index
      for i,v in ipairs(self.Libs) do
        if data.sRegexLib == v then index = i; break; end
      end
      hDlg:ListSetCurPos(Pos.cmbRegexLib, {SelectPos=index or 1})

      self:CompleteLoadData(hDlg, data, true)
      break
    ----------------------------------------------------------------------------
    elseif item.BreakKey == "F2" or item.BreakKey == "INSERT" then
      local pure_save_name = item.BreakKey == "F2" and self.PresetName
      local name = pure_save_name or
        far.InputBox(M.MSavePreset, M.MEnterPresetName, HistPresetNames,
                     self.PresetName, nil, nil, F.FIB_NOUSELASTHISTORY)
      if name then
        if pure_save_name or not presets[name] or
          far.Message(M.MPresetOverwrite, M.MConfirm, M.MBtnYesNo, "w") == 1
        then
          local data = sd.GetDialogState(hDlg, self.Items)
          presets[name] = data
          self.PresetName = name
          self:SaveDataDyn(hDlg, data)
          if Pos.cmbCodePage then
            SaveCodePageCombo(hDlg, Pos.cmbCodePage, self.Items[Pos.cmbCodePage].list, data, true)
          end
          _Plugin.SaveSettings()
          if pure_save_name then
            far.Message(M.MPresetWasSaved, M.MMenuTitle)
            break
          end
        end
      end
    ----------------------------------------------------------------------------
    elseif item.BreakKey == "DELETE" and items[1] then
      local name = items[pos].text
      local msg = ([[%s "%s"?]]):format(M.MDeletePreset, name)
      if far.Message(msg, M.MConfirm, M.MBtnYesNo, "w") == 1 then
        if self.PresetName == name then
          self.PresetName = nil
        end
        presets[name] = nil
        _Plugin.SaveSettings()
      end
    ----------------------------------------------------------------------------
    elseif item.BreakKey == "F6" and items[1] then
      local oldname = items[pos].text
      local name = far.InputBox(M.MRenamePreset, M.MEnterPresetName, HistPresetNames, oldname)
      if name and name ~= oldname then
        if not presets[name] or far.Message(M.MPresetOverwrite, M.MConfirm, M.MBtnYesNo, "w") == 1 then
          if self.PresetName == oldname then
            self.PresetName = name
          end
          presets[name], presets[oldname] = presets[oldname], nil
          _Plugin.SaveSettings()
        end
      end
    ----------------------------------------------------------------------------
    end
  end
  hDlg:send("DM_SHOWDIALOG", 1)
end


local function GetReplaceFunction (aReplacePat, is_wide)
  local fSame = function(s) return s end
  local U8 = is_wide and Utf8 or fSame
  local U32 = is_wide and Utf32 or fSame

  if type(aReplacePat) == "function" then
    return is_wide and
      function(collect,nMatch,nReps,nLine) -- this implementation is inefficient as it works in UTF-8 !
        local ccopy = {}
        for k,v in pairs(collect) do
          local key = type(k)=="number" and k or U8(k)
          ccopy[key] = v and U8(v)
        end
        local R1,R2 = aReplacePat(ccopy,nMatch,nReps+1,nLine)
        local tp1 = type(R1)
        if     tp1 == "string" then R1 = U32(R1)
        elseif tp1 == "number" then R1 = U32(tostring(R1))
        end
        return R1, R2
      end or
      function(collect,nMatch,nReps,nLine)
        local R1,R2 = aReplacePat(collect,nMatch,nReps+1,nLine)
        if type(R1)=="number" then R1=tostring(R1) end
        return R1, R2
      end

  elseif type(aReplacePat) == "string" then
    return function() return U32(aReplacePat) end

  elseif type(aReplacePat) == "table" then
    return RepLib.GetReplaceFunction(aReplacePat, is_wide)

  else
    error("invalid type of replace pattern", 2)
  end
end


return {
  EditorConfigDialog = EditorConfigDialog;
  CheckSearchArea    = CheckSearchArea;
  CreateSRFrame      = CreateSRFrame;
  DisplaySearchState = DisplaySearchState;
  ErrorMsg           = ErrorMsg;
  FormatInt          = FormatInt;
  FormatTime         = FormatTime;
  GetDialogHistory   = GetDialogHistory;
  GetReplaceFunction = GetReplaceFunction;
  GetSearchAreas     = GetSearchAreas;
  GetWordUnderCursor = GetWordUnderCursor;
  Gsub               = MakeGsub("byte");
  GsubMB             = MakeGsub("multibyte");
  GsubW              = MakeGsub("widechar");
  IndexToSearchArea  = IndexToSearchArea;
  NewUserBreak       = NewUserBreak;
  ProcessDialogData  = ProcessDialogData;
  SaveCodePageCombo  = SaveCodePageCombo;
}
