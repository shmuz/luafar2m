-- lfs_common.lua

local sd = require "far2.simpledialog"
local Sett  = require "far2.settings"
local field = Sett.field

local M = require "lfs_message"
local F = far.Flags


local function ErrorMsg (text, title)
  far.Message (text, title or M.MError, nil, "w")
end


local hst_map = { ["\\"]="\\"; n="\n"; r="\r"; t="\t"; }

local function GetFarHistory (name)
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


local function ConfigDialog()
  local Items = {
    width = 76;
    help = "Contents";
    {tp="dbox"; text=M.MConfigTitle; },
    {tp="text"; text=M.MPickFrom; },
    {tp="rbutt"; x1=7; name="rPickEditor";  text=M.MPickEditor; group=1; val=1; },
    {tp="rbutt"; x1=7; name="rPickHistory"; text=M.MPickHistory; },
    {tp="rbutt"; x1=7; name="rPickNowhere"; text=M.MPickNowhere; },
    {tp="sep"; ystep=2; },
    {tp="butt"; centergroup=1; text=M.MOk;    default=1; },
    {tp="butt"; centergroup=1; text=M.MCancel; cancel=1; },
  }
  ----------------------------------------------------------------------------
  local Data = field(_Plugin.History, "config")
  sd.LoadData(Data, Items)
  local out = sd.Run(Items)
  if out then
    sd.SaveData(out, Data)
  end
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
  regex.gsub(aStr, [[
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

local function CreateSRFrame (Items, aData, bInEditor)
  local self = {Items=Items, Data=aData, bInEditor=bInEditor}
  return setmetatable(self, SRFrameMeta)
end

function SRFrameBase:GetLibName (hDlg)
  local pos = hDlg:ListGetCurPos(self.Pos.cmbRegexLib)
  return self.Libs[pos.SelectPos]
end

function SRFrameBase:CheckRegexInit (hDlg)
  local Data = self.Data
  local Pos = self.Pos or sd.Indexes(self.Items)
  self.Pos = Pos
  local bRegex = hDlg:GetCheck(Pos.bRegExpr)
  local lib = self:GetLibName(hDlg)
  local bLua = (lib == "lua")
  self.PrevLib = lib
  hDlg:SetCheck (Pos.bWholeWords, not (bRegex or bLua) and Data.bWholeWords)
  hDlg:Enable   (Pos.bWholeWords, not (bRegex or bLua))
  hDlg:SetCheck (Pos.bExtended, bRegex and Data.bExtended)
  hDlg:Enable   (Pos.bExtended, bRegex)
  hDlg:SetCheck (Pos.bCaseSens, bLua or Data.bCaseSens)
  hDlg:Enable   (Pos.bCaseSens, not bLua)
end

function SRFrameBase:CheckRegexEnab (hDlg)
  local Pos = self.Pos or sd.Indexes(self.Items)
  self.Pos = Pos
  local bRegex = hDlg:GetCheck(Pos.bRegExpr)
  if self:GetLibName(hDlg) ~= "lua" then
    if bRegex then hDlg:SetCheck(Pos.bWholeWords, 0) end
    hDlg:Enable(Pos.bWholeWords, not bRegex)
  end
  if not bRegex then hDlg:SetCheck(Pos.bExtended, 0) end
  hDlg:Enable(Pos.bExtended, bRegex)
end

function SRFrameBase:CheckRegexLib (hDlg)
  local Pos = self.Pos or sd.Indexes(self.Items)
  self.Pos = Pos
  local bRegex = hDlg:GetCheck(Pos.bRegExpr)
  local lib = self:GetLibName(hDlg)
  local bPrevLua = (self.PrevLib == "lua")
  local bLua = (lib == "lua")
  if bLua ~= bPrevLua then
    if not bRegex then
      if bLua then hDlg:SetCheck(Pos.bWholeWords, 0) end
      hDlg:Enable(Pos.bWholeWords, not bLua)
    end
    if bLua then hDlg:SetCheck(Pos.bCaseSens, 1) end
    hDlg:Enable(Pos.bCaseSens, not bLua)
  end
  self.PrevLib = lib
end

function SRFrameBase:CheckAdvancedEnab (hDlg)
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

function SRFrameBase:InsertInDialog (aReplace)
  local insert = table.insert
  local Items = self.Items
  local s1, s2 = M.MDlgSearchPat, M.MDlgReplacePat
  local x = aReplace and math.max(M.MDlgSearchPat:len(), M.MDlgReplacePat:len())
    or M.MDlgSearchPat:len()
  insert(Items, { tp="text"; text=s1; })
  insert(Items, { tp="edit"; name="sSearchPat"; y1=""; x1=5+x, hist="SearchText"; })
  ------------------------------------------------------------------------------
  if aReplace then
    insert(Items, { tp="text";  text=s2; ystep=2; })
    insert(Items, { tp="edit";  name="sReplacePat"; y1=""; x1=5+x, hist="ReplaceText"; })
    insert(Items, { tp="chbox"; name="bRepIsFunc";  x1=6+x, text=M.MDlgRepIsFunc; })
    insert(Items, { tp="chbox"; name="bDelEmptyLine"; x1=45, y1=""; text=M.MDlgDelEmptyLine; })
  end
  ------------------------------------------------------------------------------
  insert(Items, { tp="sep"; })
  ------------------------------------------------------------------------------
  insert(Items, { tp="chbox"; name="bCaseSens";              text=M.MDlgCaseSens; })
  insert(Items, { tp="chbox"; name="bRegExpr"; y1=""; x1=26; text=M.MDlgRegExpr;  })
  insert(Items, { tp="text";                   y1=""; x1=50; text=M.MDlgRegexLib; })
  insert(Items, { tp="combobox"; name="cmbRegexLib";  x1=51; x2=63; dropdownlist=1; noauto=1;
           list = { {Text="Far regex"}, {Text="Lua regex"}, {Text="Oniguruma"}, {Text="PCRE"} };  })
  ------------------------------------------------------------------------------
  insert(Items, { tp="chbox"; name="bWholeWords";      y1=""; text=M.MDlgWholeWords; })
  insert(Items, { tp="chbox"; name="bExtended"; x1=26; y1=""; text=M.MDlgExtended; })
end


function SRFrameBase:OnDataLoaded (aData, aScriptCall)
  local Pos = self.Pos or sd.Indexes(self.Items)
  self.Pos = Pos
  local Items = self.Items
  local bInEditor = self.bInEditor

  if not aScriptCall then
    if bInEditor then
      local data = field(_Plugin.History, "config")
      if data.rPickHistory then
        Items[Pos.sSearchPat].text = GetFarHistory("SearchText") or aData.sSearchPat or ""
      elseif data.rPickNowhere then
        Items[Pos.sSearchPat].text = ""
        if Pos.sReplacePat then Items[Pos.sReplacePat].text = ""; end
      else -- (default) if data.rPickEditor then
        Items[Pos.sSearchPat].text = GetWordAboveCursor() or ""
      end
    else
      Items[Pos.sSearchPat].text = (aData.sSearchPat == "") and "" or
        GetFarHistory("SearchText") or aData.sSearchPat or ""
    end
  end

  local item = Items[Pos.cmbRegexLib]
  item.val = 1
  for i,v in ipairs(self.Libs) do
    if aData.sRegexLib == v then item.val = i; break; end
  end
end


function SRFrameBase:DlgProc (hDlg, msg, param1, param2)
  local Pos = self.Pos or sd.Indexes(self.Items)
  self.Pos = Pos
  local Data, bInEditor = self.Data, self.bInEditor
  local bReplace = Pos.sReplacePat
  local name
  ----------------------------------------------------------------------------
  if msg == F.DN_INITDIALOG then
    if bInEditor then
      if editor.GetInfo().BlockType == F.BTYPE_NONE then
        hDlg:SetCheck (Pos.rScopeGlobal, 1)
        hDlg:Enable   (Pos.rScopeBlock, 0)
      else
        name = (Data.sScope=="block") and "rScopeBlock" or "rScopeGlobal"
        hDlg:SetCheck(Pos[name], 1)
      end
      name = (Data.sOrigin=="scope") and "rOriginScope" or "rOriginCursor"
      hDlg:SetCheck(Pos[name], 1)
      self:CheckAdvancedEnab(hDlg)
    end
    self:CheckRegexInit(hDlg)
  ----------------------------------------------------------------------------
  elseif msg == F.DN_BTNCLICK then
    if param1==Pos.bRegExpr then
      self:CheckRegexEnab(hDlg)
    elseif bInEditor and param1==Pos.bAdvanced then
      self:CheckAdvancedEnab(hDlg)
    end
  ----------------------------------------------------------------------------
  elseif msg == F.DN_EDITCHANGE then
    if param1 == Pos.cmbRegexLib then self:CheckRegexLib(hDlg) end
  ----------------------------------------------------------------------------
  elseif msg == F.DN_CLOSE then
    if (param1 == Pos.btnOk) or bInEditor and
      (Pos.btnCount and param1 == Pos.btnCount or
      Pos.btnShowAll and param1 == Pos.btnShowAll)
    then
      Data.sSearchPat  = hDlg:GetText(Pos.sSearchPat)
      Data.bCaseSens   = hDlg:GetCheck(Pos.bCaseSens)
      Data.bRegExpr    = hDlg:GetCheck(Pos.bRegExpr)
      Data.bWholeWords = hDlg:GetCheck(Pos.bWholeWords)
      Data.bExtended   = hDlg:GetCheck(Pos.bExtended)
      ------------------------------------------------------------------------
      if bInEditor then
        if Data.sSearchPat == "" then
          ErrorMsg(M.MSearchFieldEmpty); return 0
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
        Data.sReplacePat   = hDlg:GetText (Pos.sReplacePat)
        Data.bRepIsFunc    = hDlg:GetCheck(Pos.bRepIsFunc)
        Data.bDelEmptyLine = hDlg:GetCheck(Pos.bDelEmptyLine)
      end
      ------------------------------------------------------------------------
      local lib = self:GetLibName(hDlg)
      local ok, err = pcall(GetRegexLib, lib)
      if not ok then (export.OnError or ErrorMsg)(err) return 0 end
      Data.sRegexLib = lib
      ------------------------------------------------------------------------
      self.close_params = ProcessDialogData(Data, bReplace)
      if not self.close_params then return 0 end -- do not close the dialog
    end
  end
end


return {
  ConfigDialog      = ConfigDialog;
  CreateSRFrame     = CreateSRFrame;
  ErrorMsg          = ErrorMsg;
  GetFarHistory     = GetFarHistory;
  ProcessDialogData = ProcessDialogData;
}
