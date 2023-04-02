-- Started               : 2021-01-20
-- Minimal Far3 version  : 3.0.3300
-- Far3 plugin           : LuaMacro, LF4Editor, LFSearch, LFHistory (any of them)
-- Dependencies          : Lua modules 'far2.simpledialog' and 'far2.settings'
-- Minimal far2l version : https://github.com/shmuz/far2l
-- Far2l plugin          : LuaMacro, LF4Editor (any of them)

local MacroKey = "CtrlF2"
local SETTINGS_KEY    = "shmuz"
local SETTINGS_SUBKEY = "editor_multiline_sort"
local Title = "Multiline sort"
local Info = { --luacheck: no unused
  Author        = "Shmuel Zeigerman";
  Guid          = "4F6D1949-B9D9-4F36-8015-309D4BD13E60";
  MinFarVersion = "3.0.3300";
  Started       = "2021-01-20";
  Title         = Title;
}
local FarVer = package.config:sub(1,1) == "\\" and 3 or 2
local F = far.Flags
local Send = far.SendDlgMessage
local KEEP_DIALOG_OPEN = 0

local Ed = editor
if FarVer == 3 then
  Ed = setmetatable({Editor=editor.Editor}, {__index=
    function(self,name)
      return function(...) return editor[name](nil, ...) end
    end})
end

local function ShowHelp()
  -- Note: the text parts in a line enclosed in ## get highlighted
  local msg = [[
#Split by:#
  - How the text is split into multi-line chunks:
    either by the 1-st line, the last line or a delimiter line
  - The adjacent edit control specifies a regular expression
    for that line
  The text for search is all selected lines concatenated with \n
#Weight regular expression:#
  - captures the block parts needed for sorting
#Lua weight function:#
  - processes found captures; returns block weight
  - T[1], T[2], etc. are the captures; T[0] is the whole match
  - variable a is the whole block text
  - variable i is the block number (1 for the uppermost block)
  - variable I is the total number of blocks
  - returns a string or a number (consistently for all calls)
#Output parts delimiter:#
  - if left empty then no delimiter is inserted
  - recognizes \t as TAB and \n as NL]]

  if far.CreateUserControl then -- since Far 3.0.3590
    local sd = require ("far2.simpledialog")
    local Dlg = sd.New {
      {tp="dbox"; text=Title.." Help";                 },
      {tp="user2"; text=msg;                           },
      {tp="sep";                                       },
      {tp="butt"; text="OK"; centergroup=1; default=1; },
    }
    Dlg:Run()
  else
    far.Message(msg:gsub("#",""), Title.." Help", nil, "l")
  end
end

local function get_data_from_dialog()
  local sdialog = require "far2.simpledialog"
  local settings = mf or require "far2.settings"

  local items = {
    guid="453DF58C-D19B-4EAC-AFA9-A9125FA7C7C4";
    help=ShowHelp;
    ----------------------------------------------------------------------
    {tp="dbox"; text=Title;                                                    },
    ----------------------------------------------------------------------
    {tp="rbutt"; text="&1-st line";          x1=18; name="rb1st"; val=1;       },
    {tp="rbutt"; text="&Last line";   y1=""; x1=33; name="rbLast";             },
    {tp="rbutt"; text="&Delimiter";   y1=""; x1=48; name="rbDelim";            },
    {tp="text";  text="&Split by:";   y1=""; width=10;                         },
    {tp="edit";  name="sBlockPat";    focus=1;                                 },
    ----------------------------------------------------------------------
    {tp="text";  text="&Weight regular expression:"                            },
    {tp="edit";  name="sWeightPat";                                            },
    ----------------------------------------------------------------------
    {tp="chbox"; name="bCaseSens";   text="&Case sensitive";                   },
    {tp="chbox"; name="bFileAsLine"; text="&File as a line";                   },
    {tp="chbox"; name="bMultiLine";  text="&Multi-line mode"; ystep=0; x1=26;  },
    {tp="sep"                                                                  },
    ----------------------------------------------------------------------
    {tp="text";  text="Lua &Weight function:"                                  },
    {tp="edit";  name="sWeightCode"; ext="lua";                                },
    ----------------------------------------------------------------------
    {tp="text";  text="&Output parts delimiter:"                               },
    {tp="edit";  name="sOutDelim";                                             },
    ----------------------------------------------------------------------
    {tp="chbox"; name="bReverse"; text="&Reverse sort order";                  },
    {tp="sep"                                                                  },
    ----------------------------------------------------------------------
    {tp="butt";  text="OK";       centergroup=1; default=1;    name="btnOK";   },
    {tp="butt";  text="&Presets"; centergroup=1; btnnoclose=1; name="Presets"; },
    {tp="butt";  text="Cancel";   centergroup=1; cancel=1;                     },
  }

  local PresetParams = { PresetName=nil; }
  local Dlg = sdialog.New(items)
  local Pos, Elem = Dlg:Indexes()
  local Data = settings.mload(SETTINGS_KEY, SETTINGS_SUBKEY) or {}
  Dlg:LoadData(Data)

  ---- callback on dialog close (Data validity checking)
  items.closeaction = function(hDlg, Par1, tOut)
    local _, msg
    if tOut.sBlockPat == ""                      then msg = "Empty Block regular expression"
    elseif not pcall(regex.new, tOut.sBlockPat)  then msg = "Invalid Block regular expression"
    elseif tOut.sWeightPat == ""                 then msg = "Empty Weight regular expression"
    elseif not pcall(regex.new, tOut.sWeightPat) then msg = "Invalid Weight regular expression"
    else _, msg = loadstring(tOut.sWeightCode, "Lua weight function")
    end
    if msg then
      far.Message(msg, Title, nil, "w")
      return KEEP_DIALOG_OPEN
    end
  end

  function Elem.Presets.action (hDlg,Par1,Par2)
    local PrMenu = require "far2.presets"
    Data.presets = Data.presets or {}
    Send(hDlg, F.DM_SHOWDIALOG, 0)

    local preset, modified = PrMenu(PresetParams, Data.presets,
      function() return Dlg:GetDialogState(hDlg) end,
      "presets_multiline_sort")

    if preset then
      Dlg:SetDialogState(hDlg, preset)
    end
    if modified then
      settings.msave(SETTINGS_KEY, SETTINGS_SUBKEY, Data)
    end

    Send(hDlg, F.DM_SHOWDIALOG, 1)
    Send(hDlg, F.DM_SETFOCUS, Pos.btnOK)
  end

  for _,v in ipairs(items) do
    if v.tp=="edit" and v.name then
      v.hist = "multilinesort_"..v.name
    end
  end

  local out = Dlg:Run()
  if out then
    settings.msave(SETTINGS_KEY, SETTINGS_SUBKEY, out)
  end
  return out
end

local function GetSelection()
  local EI = Ed.GetInfo()
  if EI.BlockType == F.BTYPE_STREAM then
    local tt = {}
    for i=EI.BlockStartLine, math.huge do
      local s = Ed.GetString(i)
      if s.SelEnd == 0 then break end
      tt[#tt+1] = s.StringText
    end
    tt[#tt+1] = "" -- add EOL to the last line (to make it uniform with other lines)
    return table.concat(tt, "\n")
  end
end

local function InsertLine(lnum, text)
  Ed.SetPosition(lnum,1,1)
  Ed.InsertString()
  Ed.SetString(lnum, text)
end

local function SplitBy1stLine(aText, aPatt)
  local chunks = {}
  local curr
  for line in aText:gmatch("[^\n]*\n?") do
    local last = line==""
    local ok = aPatt:match(line)
    if ok or last then
      if curr then      -- save the current chunk
        table.insert(chunks,curr)
      end
      curr = { line }
    else
      if curr then      -- add to the current chunk
        table.insert(curr,line)
      else
        curr = { line } -- create a new chunk, despite the pattern didn't match
      end
    end
  end
  return chunks
end

local function SplitByLastLine(aText, aPatt)
  local chunks = {}
  local curr
  for line in aText:gmatch("[^\n]*\n?") do
    local last = line==""
    local ok = aPatt:match(line)
    curr = curr or {}
    table.insert(curr, line)
    if ok or last then
      table.insert(chunks, curr)
      curr = nil
    end
  end
  return chunks
end

local function SplitByDelimiter(aText, aPatt)
  local chunks = {}
  local curr
  for line in aText:gmatch("[^\n]*\n?") do
    local last = line==""
    local ok = aPatt:match(line)
    if ok or last then
      if curr then
        table.insert(chunks, curr)
        curr = nil
      end
    else
      curr = curr or {}
      table.insert(curr, line)
    end
  end
  return chunks
end

local function Work(data)
  local text = GetSelection()
  if not text then
    far.Message("BTYPE_STREAM selection not found", Title, nil, "w"); return;
  end

  -- extract all chunks/blocks into a table for future sorting
  local cflags = ""
  if not data.bCaseSens then cflags = cflags.."i" end
  if data.bFileAsLine   then cflags = cflags.."s" end
  if data.bMultiLine    then cflags = cflags.."m" end
  local blockPat = regex.new(data.sBlockPat, cflags)
  local chunks = (data.rb1st and SplitBy1stLine or data.rbLast  and SplitByLastLine or
                  data.rbDelim and SplitByDelimiter)(text, blockPat)

  local index = 0
  local weightPat = regex.new(data.sWeightPat, cflags)
  for _, chunk in ipairs(chunks) do
    chunk = table.concat(chunk)
    local caps = { weightPat:find(chunk) }
    if caps[1] then
      local fullmatch = chunk:sub(caps[1],caps[2])
      table.remove(caps,2) -- remove "to"
      table.remove(caps,1) -- remove "from"
      caps[0] = fullmatch
    end
    index = index + 1
    chunks[index] = { index=index; chunk=chunk; captures=caps; }
  end
  assert(index > 0, "number of blocks is zero")

  -- make weight function
  local ff, msg = loadstring("local T,a,i,I = ...\n" .. data.sWeightCode)
  if not ff then far.Message(msg, Title, nil, "w"); return; end
  setfenv(ff, setmetatable({}, {__index=_G})) -- for not modifying globals by accident

  -- get chunks' weights
  local I = #chunks
  for i,tt in ipairs(chunks) do
    tt.weight = ff(tt.captures, tt.chunk, i, I) or ""
  end

  -- the sort is stable due to use of "index"
  table.sort(chunks,
    type(chunks[1].weight) == "number" and
      function(a,b)
        if data.bReverse then a,b=b,a end -- full reverse, including equals
        return (a.weight<b.weight) or (a.weight==b.weight and a.index<b.index)
      end or
      function(a,b)
        if data.bReverse then a,b=b,a end -- full reverse, including equals
        local res = win.CompareString(a.weight, b.weight, nil, "S")
        return res < 0 or res==0 and a.index < b.index
      end)

  -- actions on editor
  Ed.UndoRedo(nil,"EUR_BEGIN")
  Ed.DeleteBlock()
  local lnum = Ed.GetInfo().CurLine
  local delim = data.sOutDelim:gsub("\\(.)", { n="\n";t="\t"; })
  for _,v in ipairs(chunks) do
    for line, eol in v.chunk:gmatch("([^\n]*)(\n?)") do
      if line ~= "" or eol ~= "" then
        InsertLine(lnum, line)
        lnum = lnum + 1
      end
    end
    for line,text in delim:gmatch("(([^\n]*)\n?)") do
      if line ~= "" then
        InsertLine(lnum, text)
        lnum = lnum + 1
      end
    end
  end
  Ed.UndoRedo(nil,"EUR_END")
  Ed.Redraw()
end

if Macro then
  Macro {
    description=Title;
    area="Editor"; key=MacroKey;
    condition=function()
      local data = get_data_from_dialog()
      if data then Work(data) end
      return true
    end;
    action=function() end;
  }
else
  local w = far.AdvControl("ACTL_GETWINDOWTYPE")
  if w and w.Type == F.WTYPE_EDITOR then
    local data = get_data_from_dialog()
    if data then Work(data) end
  end
end
