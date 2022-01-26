-- luarepl.lua

local Package = {}

local far2_dialog = require "far2.dialog"

local M = require "lfs_message"
local F = far.Flags

package.loaded["lfs_engine"] = nil
local DoAction = require "lfs_engine"

local function ErrorMsg (text, title)
  far.Message (text, title or M.MError, nil, "w")
end

local function FormatInt (num)
  return tostring(num):reverse():gsub("...", "%1,"):gsub(",$", ""):reverse()
end


local function GetFarHistory (name)
  local lines = win.GetRegKey("HKCU", "SavedDialogHistory\\"..name, "lines")
  return lines and lines:match"^%Z*"
end


local function CreateUfindMethod (tb_methods)
  if tb_methods.ufind == nil then
    local find = tb_methods.find
    local ssub = string.sub
    local ulen = ("").len -- length in utf8 chars
    tb_methods.ufind = function(r, s, init)
      init = init and s:offset(init)
      local t = { find(r, s, init) }
      if t[1] ~= nil then
        t[1], t[2] = ulen(ssub(s, 1, t[1]-1)) + 1, ulen(ssub(s, 1, t[2]))
        return t
      end
    end
  end
end


local function CreateUfindMethod_Lua (tb_methods)
  if tb_methods.ufind == nil then
    local find = tb_methods.find
    tb_methods.ufind = function(r, s, init)
      local t = { find(r, s, init) }
      if t[1] ~= nil then
        return t
      end
    end
  end
end


local lua_methods = {
  find = function(self, s, init)
    -- string.find treats ^ irrespectively of `init'; let's correct that.
    if self.pat:find("^%^") and not self.plain and init then
      if (init > 1) or (init < 0 and init > -s:len()) then return nil end
    end
    return s:find(self.pat, init) -- , self.plain)
  end,
  gsub = function(self, s, r) return s:gsub(self.pat, r) end
}
local lua_functions = setmetatable({
    new = function (pat, plain)
      local p = { pat=pat, plain=plain }
      return setmetatable(p, {__index = lua_methods})
    end
  }, {__index = utf8})


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
  elseif engine_name == "lua" then
    base = lua_functions
    CreateUfindMethod_Lua(lua_methods)
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
    deriv.new = function (pat, cf) return base.new (pat, cf, "UTF8", "PERL") end
    local tb_methods = getmetatable(base.new(".")).__index
    CreateUfindMethod(tb_methods)
    tb_methods.gsub = function(regex, subj, rep) return base.gsub(subj, regex, rep) end
  -----------------------------------------------------------------------------
  else
    error "argument #1 invalid or missing"
  end
  return setmetatable(deriv, {__index=base})
end


local function ConfigDialog()
  local Dlg = far2_dialog.NewDialog()
  Dlg.frame           = {"DI_DOUBLEBOX",   3, 1,72, 9,  0, 0,  0,  0, M.MConfigTitle}
  Dlg.lab             = {"DI_TEXT",        5, 2, 0, 0,  0, 0,  0,  0, M.MPickFrom}
  Dlg.rPickEditor     = {"DI_RADIOBUTTON", 7, 3, 0, 0,  0, 0, "DIF_GROUP", 0, M.MPickEditor, _noauto=1}
  Dlg.rPickHistory    = {"DI_RADIOBUTTON", 7, 4, 0, 0,  0, 0,  0,          0, M.MPickHistory, _noauto=1}
  Dlg.rPickNowhere    = {"DI_RADIOBUTTON", 7, 5, 0, 0,  0, 0,  0,          0, M.MPickNowhere, _noauto=1}
  Dlg.sep             = {"DI_TEXT",        5, 7, 0, 0,  0, 0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, 0, ""}
  Dlg.btnOk           = {"DI_BUTTON",      0, 8, 0, 0,  0, 0,  "DIF_CENTERGROUP", 1, M.MOk}
  Dlg.btnCancel       = {"DI_BUTTON",      0, 8, 0, 0,  0, 0,  "DIF_CENTERGROUP", 0, M.MCancel}
  ----------------------------------------------------------------------------
  local function DlgProc (hDlg, msg, param1, param2)
    if msg == F.DN_CLOSE then
      if param1 == Dlg.btnOk.id then
      end
    end
  end
  ----------------------------------------------------------------------------
  local Data = _Plugin.History:field("config")
  far2_dialog.LoadData(Dlg, Data)
  if Data.rPickFrom     == "history" then Dlg.rPickHistory.Selected = 1
  elseif Data.rPickFrom == "nowhere" then Dlg.rPickNowhere.Selected = 1
  else                                    Dlg.rPickEditor.Selected  = 1
  end
  local ret = far.Dialog (-1, -1, 76, 11, "Contents", Dlg, 0, DlgProc)
  if ret == Dlg.btnOk.id then
    far2_dialog.SaveData(Dlg, Data)
    Data.rPickFrom =
      Dlg.rPickHistory.Selected ~= 0 and "history" or
      Dlg.rPickNowhere.Selected ~= 0 and "nowhere" or
      Dlg.rPickEditor.Selected  ~= 0 and "editor"
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

local function TransformReplacePat (aStr)
  local T = {}
  local map = { a="\a", e="\27", f="\f", n="\n", r="\r", t="\t" }
  aStr = regex.gsub(aStr, [[
      \\([LlUuE]) |
      (\\R \{ ([-]?\d+) , (\d+) \}) |
      (\\R \{ ([-]?\d+) \}) |
      (\\R) |
      \\x([0-9a-fA-F]{0,4}) |
      \\(.?) |
      \$(.?) |
      (.)
    ]],
    function(c0, R1,R11,R12, R2,R21, R3, c1,c2,c3,c4)
      if c0 then
        T[#T+1] = { "case", c0 }
      elseif R1 or R2 or R3 then
        -- trying to work around the Far regex capture bug
        T[#T+1] = { "counter", R1 and tonumber(R11) or R2 and tonumber(R21) or 1,
                               R1 and tonumber(R12) or 0 }
      elseif c1 then
        c1 = tonumber(c1,16) or 0
        T[#T+1] = { "hex", ("").char(c1) }
      elseif c2 then
        T[#T+1] = { "literal", c2:match("[%p%-+^$&]") or map[c2]
          or error("invalid escape: \\"..c2) }
      elseif c3 then
        T[#T+1] = { "group", tonumber(c3,16)
          or error(M.MErrorGroupNumber..": $"..c3) }
      elseif c4 then
        if T[#T] and T[#T][1]=="literal" then T[#T][2] = T[#T][2] .. c4
        else T[#T+1] = { "literal", c4 }
        end
      end
    end, nil, "sx")
  return T
end


-- DON'T use loadstring here, that would be a security hole
-- (and just incorrect solution).
local map_unescape = {
  a='\a', b='\b', f='\f', n='\n', r='\r', t='\t',
  v='\v', ['\\']='\\', ['\"']='\"', ['\'']='\''
}
local function unescape (str)
  str = regex.gsub (str, [[\\(\d\d?\d?)|\\(.?)]],
    function (c1, c2)
      if c2 then return map_unescape[c2] or c2 end
      c1 = tonumber (c1)
      assert (c1 < 256, "escape sequence too large")
      return string.char(c1)
    end)
  return str
end


local function ProcessDialogData (aData, bReplace)
  local params = {}
  params.bSearchBack = aData.bSearchBack
  params.bDelEmptyLine = aData.bDelEmptyLine
  params.sOrigin = aData.sOrigin
  params.sSearchPat = aData.sSearchPat
  ---------------------------------------------------------------------------
  params.Envir = setmetatable({}, {__index=_G})
  params.Envir.dofile = function(fname)
    local f = assert(loadfile(fname))
    return setfenv(f, params.Envir)()
  end
  ---------------------------------------------------------------------------
  local bRegexLua = (aData.sRegexLib == "lua")
  local rex
  local ok, ret = pcall(GetRegexLib, aData.sRegexLib or "far")
  if ok then rex, params.Envir.rex = ret, ret
  else ErrorMsg(ret); return
  end

  local SearchPat = aData.sSearchPat or ""
  local cflags
  if aData.bRegExpr then
    if bRegexLua then
      if aData.bExtended then
        SearchPat = SearchPat:gsub("(%%?)(.)",
          function(a,b) if a=="" and b:find("^%s") then return "" end
          end)
      end
      ok, ret = pcall(unescape, SearchPat)
      if ok then
        SearchPat = ret
        ok, ret = pcall(("").match, "", SearchPat) -- syntax check
      end
      if not ok then ErrorMsg(ret) return end
    else
      cflags = aData.bCaseSens and "" or "i"
      if aData.bExtended then cflags = cflags.."x" end
    end
  else
    local sNeedEscape = "[~!@#$%%^&*()%-+[%]{}\\|:;'\",<.>/?]"
    if bRegexLua then
      cflags = true
      SearchPat = SearchPat:gsub(sNeedEscape, "%%%1")
    else
      cflags = aData.bCaseSens and "" or "i"
      SearchPat = SearchPat:gsub(sNeedEscape, "\\%1")
      if aData.bWholeWords then SearchPat = "\\b"..SearchPat.."\\b" end
    end
  end

  ok, ret = pcall(rex.new, SearchPat, cflags)
  if ok then params.Regex = ret
  else ErrorMsg(ret, M.MSearchPattern..": "..M.MSyntaxError); return
  end
  ---------------------------------------------------------------------------
  if bReplace then
    if aData.bRepIsFunc then
      local func, msg = loadstring("local c0,c1,c2,c3,c4,c5,c6,c7,c8,c9=...\n" ..
        aData.sReplacePat, M.MReplaceFunction)
      if func then params.ReplacePat = setfenv(func, params.Envir)
      else ErrorMsg(msg, M.MReplaceFunction..": "..M.MSyntaxError); return
      end
    else
      params.ReplacePat = aData.sReplacePat
      if aData.bRegExpr then
        local ok, ret = pcall(TransformReplacePat, params.ReplacePat)
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

local SRFrameBase = {}
SRFrameBase.Libs = {"far", "lua", "oniguruma", "pcre"}
local SRFrameMeta = {__index = SRFrameBase}

function Package.CreateSRFrame (Dlg, aData, bInEditor)
  local self = {Dlg=Dlg, Data=aData, bInEditor=bInEditor}
  return setmetatable(self, SRFrameMeta)
end

function SRFrameBase:CheckRegexInit (hDlg)
  local Dlg, Data = self.Dlg, self.Data
  local bRegex = Dlg.bRegExpr:GetCheck(hDlg)
  local lib = self.Libs[ Dlg.cmbRegexLib:GetListCurPos(hDlg) ]
  local bLua = (lib == "lua")
  self.PrevLib = lib
  Dlg.bWholeWords :SetCheck(hDlg, not (bRegex or bLua) and Data.bWholeWords)
  Dlg.bWholeWords :Enable  (hDlg, not (bRegex or bLua))
  Dlg.bExtended   :SetCheck(hDlg, bRegex and Data.bExtended)
  Dlg.bExtended   :Enable  (hDlg, bRegex)
  Dlg.bCaseSens   :SetCheck(hDlg, bLua or Data.bCaseSens)
  Dlg.bCaseSens   :Enable  (hDlg, not bLua)
end

function SRFrameBase:CheckRegexEnab (hDlg)
  local Dlg = self.Dlg
  local bRegex = Dlg.bRegExpr:GetCheck(hDlg)
  if self.Libs[ Dlg.cmbRegexLib:GetListCurPos(hDlg) ] ~= "lua" then
    if bRegex then Dlg.bWholeWords:SetCheck(hDlg, false) end
    Dlg.bWholeWords:Enable(hDlg, not bRegex)
  end
  if not bRegex then Dlg.bExtended:SetCheck(hDlg, false) end
  Dlg.bExtended:Enable(hDlg, bRegex)
end

function SRFrameBase:CheckRegexLib (hDlg)
  local Dlg = self.Dlg
  local bRegex = Dlg.bRegExpr:GetCheck(hDlg)
  local pos = Dlg.cmbRegexLib:GetListCurPos(hDlg)
  local bPrevLua = (self.PrevLib == "lua")
  local bLua = (self.Libs[pos] == "lua")
  if bLua ~= bPrevLua then
    if not bRegex then
      if bLua then Dlg.bWholeWords:SetCheck(hDlg, false) end
      Dlg.bWholeWords:Enable(hDlg, not bLua)
    end
    if bLua then Dlg.bCaseSens:SetCheck(hDlg, true) end
    Dlg.bCaseSens:Enable(hDlg, not bLua)
  end
  self.PrevLib = self.Libs[pos]
end

function SRFrameBase:CheckAdvancedEnab (hDlg)
  local Dlg = self.Dlg
  local bEnab = Dlg.bAdvanced:GetCheck(hDlg)
  Dlg.labFilterFunc :Enable(hDlg, bEnab)
  Dlg.sFilterFunc   :Enable(hDlg, bEnab)
  Dlg.labInitFunc   :Enable(hDlg, bEnab)
  Dlg.sInitFunc     :Enable(hDlg, bEnab)
  Dlg.labFinalFunc  :Enable(hDlg, bEnab)
  Dlg.sFinalFunc    :Enable(hDlg, bEnab)
end

function SRFrameBase:InsertInDialog (aReplace, Y)
  local Dlg = self.Dlg
  local s1, s2 = M.MDlgSearchPat, M.MDlgReplacePat
  local x = aReplace and math.max(M.MDlgSearchPat:len(), M.MDlgReplacePat:len())
    or M.MDlgSearchPat:len()
  Dlg.lab         = {"DI_TEXT",         5,Y,  0, 0, 0, 0, 0, 0, s1}
  Dlg.sSearchPat  = {"DI_EDIT",       5+x,Y, 70, 4, 0, "SearchText", F.DIF_HISTORY, 0, ""}
  ------------------------------------------------------------------------------
  if aReplace then
    Y = Y + 2
    Dlg.lab         = {"DI_TEXT",       5,Y,  0, 0, 0, 0, 0, 0, s2}
    Dlg.sReplacePat = {"DI_EDIT",     5+x,Y, 70, Y, 0, "ReplaceText", F.DIF_HISTORY, 0, ""}
    Y = Y + 1
    Dlg.bRepIsFunc  = {"DI_CHECKBOX", 6+x,Y,  0, 0, 0, 0, 0, 0, M.MDlgRepIsFunc}
    Dlg.bDelEmptyLine={"DI_CHECKBOX",  45,Y,  0, 0, 0, 0, 0, 0, M.MDlgDelEmptyLine}
  end
  ------------------------------------------------------------------------------
  Y = Y + 1
  Dlg.sep = {"DI_TEXT", 5,Y,0,0, 0,0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, 0, ""}
  ------------------------------------------------------------------------------
  Y = Y + 1
  Dlg.bCaseSens   = {"DI_CHECKBOX",     5,Y,  0, 0, 0, 0, 0, 0, M.MDlgCaseSens}
  Dlg.bRegExpr    = {"DI_CHECKBOX",    26,Y,  0, 0, 0, 0, 0, 0, M.MDlgRegExpr}

  Dlg.lab        = {"DI_TEXT",         50,Y,  0, 0, 0, 0, 0, 0, M.MDlgRegexLib}
  Dlg.cmbRegexLib= {"DI_COMBOBOX",     51,Y+1,63,0, 0, {
                       {Text="Far regex"},
                       {Text="Lua regex"},
                       {Text="Oniguruma"},
                       {Text="PCRE"}
                     }, {DIF_DROPDOWNLIST=1}, 0, "", _noauto=true}
  ------------------------------------------------------------------------------
  Y = Y + 1
  Dlg.bWholeWords = {"DI_CHECKBOX",    5, Y,  0, 0, 0, 0, 0, 0, M.MDlgWholeWords}
  Dlg.bExtended   = {"DI_CHECKBOX",    26,Y,  0, 0, 0, 0, 0, 0, M.MDlgExtended}
  return Y + 1
end


function SRFrameBase:OnDataLoaded (aData, aScriptCall)
  local Dlg, bInEditor = self.Dlg, self.bInEditor

  if not aScriptCall then
    if bInEditor then
      local from = _Plugin.History:field("config").rPickFrom
      if from == "history" then
        Dlg.sSearchPat.Data = GetFarHistory("SearchText") or aData.sSearchPat or ""
      elseif from == "nowhere" then
        Dlg.sSearchPat.Data = ""
        if Dlg.sReplacePat then Dlg.sReplacePat.Data = ""; end
      else -- (default) if from == "editor" then
        Dlg.sSearchPat.Data = GetWordAboveCursor() or ""
      end
    else
      Dlg.sSearchPat.Data = (aData.sSearchPat == "") and "" or
        GetFarHistory("SearchText") or aData.sSearchPat or ""
    end
  end

  local items = Dlg.cmbRegexLib.ListItems
  items.SelectIndex = 1
  for i,v in ipairs(self.Libs) do
    if aData.sRegexLib == v then items.SelectIndex = i; break; end
  end
end


function SRFrameBase:DlgProc (hDlg, msg, param1, param2)
  local Dlg, Data, bInEditor = self.Dlg, self.Data, self.bInEditor
  local bReplace = Dlg.sReplacePat
  local name
  ----------------------------------------------------------------------------
  if msg == F.DN_INITDIALOG then
    if bInEditor then
      if editor.GetInfo().BlockType == F.BTYPE_NONE then
        Dlg.rScopeGlobal:SetCheck(hDlg, true)
        Dlg.rScopeBlock:Enable(hDlg, false)
      else
        name = (Data.sScope=="block") and "rScopeBlock" or "rScopeGlobal"
        Dlg[name]:SetCheck(hDlg, true)
      end
      name = (Data.sOrigin=="scope") and "rOriginScope" or "rOriginCursor"
      Dlg[name]:SetCheck(hDlg, true)
      self:CheckAdvancedEnab(hDlg)
    end
    self:CheckRegexInit(hDlg)
  ----------------------------------------------------------------------------
  elseif msg == F.DN_BTNCLICK then
    if param1==Dlg.bRegExpr.id then self:CheckRegexEnab(hDlg)
    else
      if bInEditor and param1==Dlg.bAdvanced.id then
        self:CheckAdvancedEnab(hDlg)
      end
    end
  ----------------------------------------------------------------------------
  elseif msg == F.DN_EDITCHANGE then
    if param1 == Dlg.cmbRegexLib.id then self:CheckRegexLib(hDlg) end
  ----------------------------------------------------------------------------
  elseif msg == F.DN_CLOSE then
    if (param1 == Dlg.btnOk.id) or bInEditor and
      (Dlg.btnCount and param1 == Dlg.btnCount.id or
      Dlg.btnShowAll and param1 == Dlg.btnShowAll.id)
    then
      Dlg.sSearchPat:SaveText(hDlg, Data)
      Dlg.bCaseSens:SaveCheck(hDlg, Data)
      Dlg.bRegExpr:SaveCheck(hDlg, Data)

      Dlg.bWholeWords:SaveCheck(hDlg, Data)
      Dlg.bExtended:SaveCheck(hDlg, Data)
      ------------------------------------------------------------------------
      if bInEditor then
        if Data.sSearchPat == "" then
          ErrorMsg(M.MSearchFieldEmpty); return 0
        end
        Dlg.bSearchBack:SaveCheck(hDlg, Data)
        Data.sScope = Dlg.rScopeGlobal:GetCheck(hDlg) and "global" or "block"
        Data.sOrigin = Dlg.rOriginCursor:GetCheck(hDlg) and "cursor" or "scope"
        Dlg.bAdvanced   :SaveCheck(hDlg, Data)
        Dlg.sFilterFunc :SaveText(hDlg, Data)
        Dlg.sInitFunc   :SaveText(hDlg, Data)
        Dlg.sFinalFunc  :SaveText(hDlg, Data)
      end
      ------------------------------------------------------------------------
      if bReplace then
        Dlg.sReplacePat   :SaveText(hDlg, Data)
        Dlg.bRepIsFunc    :SaveCheck(hDlg, Data)
        Dlg.bDelEmptyLine :SaveCheck(hDlg, Data)
      end
      ------------------------------------------------------------------------
      local lib = self.Libs[ Dlg.cmbRegexLib:GetListCurPos(hDlg) ]
      local ok, err = pcall(GetRegexLib, lib)
      if not ok then (export.OnError or ErrorMsg)(err) return 0 end
      Data.sRegexLib = lib
      ------------------------------------------------------------------------
      self.close_params = ProcessDialogData(Data, bReplace)
      if not self.close_params then return 0 end -- do not close the dialog
    end
  end
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
  local Frame = Package.CreateSRFrame(Dlg, aData, true)
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
  config=1, search=1, replace=1, ["repeat"]=1,
  ["test:search"]=1, ["test:count"]=1, ["test:showall"]=1, ["test:replace"]=1,
}


--[[-------------------------------------------------------------------------
  *  'aScriptCall' being true means we are called from a script rather than from
     the standard user interface.
  *  If it is true, then the search pattern in the dialog should be initialized
     strictly from aData.sSearchPat, otherwise it will depend on the global
     value 'config.rPickFrom'.
------------------------------------------------------------------------------]]
function Package.SearchOrReplace (aOp, aData, aScriptCall)
  assert(ValidOperations[aOp], "invalid operation")
  ---------------------------------------------------------------------------
  if aOp == "config" then ConfigDialog() return end
  ---------------------------------------------------------------------------
  local bReplace, bWithDialog, sOperation, tParams
  aData.sSearchPat = aData.sSearchPat or ""
  aData.sReplacePat = aData.sReplacePat or ""
  local bTest = aOp:find("^test:")
  if bTest then
    bWithDialog = true
    bReplace = (aOp == "test:replace")
    sOperation = aOp:sub(6) -- skip "test:"
    tParams = assert(ProcessDialogData (aData, bReplace))
  elseif aOp == "search" or aOp == "replace" then
    bWithDialog = true
    bReplace = (aOp == "replace")
    while true do
      sOperation, tParams = SR_Dialog(aData, bReplace, aScriptCall)
      if sOperation ~= "config" then break end
      ConfigDialog()
    end
    if sOperation == "cancel" then return end
    -- sOperation : either of "search", "count", "showall", "replace"
  else -- if aOp == "repeat"
    bReplace = (aData.sLastOp == "replace")
    local searchtext = GetFarHistory("SearchText")
    if searchtext ~= aData.sSearchPat then
      bReplace = false
      aData.bSearchBack = false
      if searchtext then aData.sSearchPat = searchtext end
    end
    sOperation = bReplace and "replace" or "search"
    tParams = assert(ProcessDialogData (aData, bReplace))
  end
  aData.sLastOp = bReplace and "replace" or "search"
  tParams.sScope = bWithDialog and aData.sScope or "global"
  ---------------------------------------------------------------------------
  if aData.bAdvanced then tParams.InitFunc() end
----profiler.start[[e:\bb\f\today\projects\luafar\log11.log]]
  local nFound, nReps, sChoice = DoAction(
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
return Package
