-- Started             : 2021-01-20
-- Minimal Far version : 3.0.3300
-- Far plugin          : LuaMacro, LF4Editor, LFSearch, LFHistory (any of them)
-- Dependencies        : Lua modules 'far2.simpledialog' and 'far2.settings'

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
local F = far.Flags

local function ShowHelp()
  -- Note: the text parts in a line enclosed in ## get highlighted
  local msg = [[
#Block regular expression:#
  - matches a single block (sorting unit)
  - the text for search is all selected lines concatenated with \n
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
    local dlg = sd.New {
      {tp="dbox"; text=Title.." Help";                 },
      {tp="user2"; text=msg;                           },
      {tp="sep";                                       },
      {tp="butt"; text="OK"; centergroup=1; default=1; },
    }
    dlg:Run()
  else
    far.Message(msg:gsub("#",""), Title.." Help", nil, "l")
  end
end

local function get_data_from_dialog()
  local sdialog = require "far2.simpledialog"
  local settings = require "far2.settings"

  local items = {
    guid="453DF58C-D19B-4EAC-AFA9-A9125FA7C7C4";
    help=ShowHelp;
    ------------------------------------------------------------------
    {tp="dbox"; text=Title;                                   },
    ------------------------------------------------------------------
    {tp="text"; text="&Block regular expression:"             },
    {tp="edit"; name="sBlockPat";                             },
    ------------------------------------------------------------------
    {tp="text"; text="&Weight regular expression:"            },
    {tp="edit"; name="sWeightPat";                            },
    ------------------------------------------------------------------
    {tp="chbox"; name="bCaseSens";   text="&Case sensitive";  },
    {tp="chbox"; name="bFileAsLine"; text="&File as a line";  },
    {tp="chbox"; name="bMultiLine";  text="&Multi-line mode"; ystep=0; x1=26; },
    {tp="sep"                                                 },
    ------------------------------------------------------------------
    {tp="text"; text="&Lua weight function:"                  },
    {tp="edit"; name="sWeightCode"; ext="lua";                },
    ------------------------------------------------------------------
    {tp="text"; text="&Output parts delimiter:"               },
    {tp="edit"; name="sOutDelim";                             },
    ------------------------------------------------------------------
    {tp="chbox"; name="bReverse"; text="&Reverse sort order"; },
    {tp="sep"                                                 },
    ------------------------------------------------------------------
    {tp="butt"; text="OK";     centergroup=1; default=1;      },
    {tp="butt"; text="Cancel"; centergroup=1; cancel=1;       },
  }
  ---- callback on dialog close (data validity checking)
  items.closeaction = function(hDlg, Par1, tOut)
    local _, msg
    if tOut.sBlockPat == ""                      then msg = "Empty Block regular expression"
    elseif not pcall(regex.new, tOut.sBlockPat)  then msg = "Invalid Block regular expression"
    elseif tOut.sWeightPat == ""                 then msg = "Empty Weight regular expression"
    elseif not pcall(regex.new, tOut.sWeightPat) then msg = "Invalid Weight regular expression"
    else _, msg = loadstring(tOut.sWeightCode, "Lua weight function")
    end
    if msg then
      far.Message(msg, Title, nil, "w"); return 0;
    end
  end
  ---- load settings
  local data = settings.mload(SETTINGS_KEY, SETTINGS_SUBKEY) or {}
  for _,v in ipairs(items) do
    if v.tp=="edit" and v.name then
      v.hist = "multilinesort_"..v.name
      v.uselasthistory = true
    end
    if v.tp=="chbox" then v.val = data[v.name]; end
  end
  ---- run the dialog
  local out = sdialog.New(items):Run()
  ---- save settings
  if out then
    for _,v in ipairs(items) do
      if v.tp=="chbox" then data[v.name] = out[v.name]; end
    end
    settings.msave(SETTINGS_KEY, SETTINGS_SUBKEY, data)
  end
  return out
end

local function GetSelection()
  local EI = editor.GetInfo()
  if EI.BlockType == F.BTYPE_STREAM then
    local tt = {}
    for i=EI.BlockStartLine, math.huge do
      local s = editor.GetString(i)
      if s.SelEnd == 0 then break end
      tt[#tt+1] = s.StringText
    end
    tt[#tt+1] = "" -- add EOL to the last line (to make it uniform with other lines)
    return table.concat(tt, "\n")
  end
end

local function InsertLine(lnum, text)
  editor.SetPosition(lnum,1,1)
  editor.InsertString()
  editor.SetString(lnum, text)
  return lnum + 1
end

local function Work(data)
  local text = GetSelection()
  if not text then
    far.Message("No stream-type selection found", Title, nil, "w"); return;
  end

  -- extract all chunks/blocks into a table for future sorting
  local cflags = ""
  if not data.bCaseSens then cflags = cflags.."i" end
  if data.bFileAsLine   then cflags = cflags.."s" end
  if data.bMultiLine    then cflags = cflags.."m" end
  local chunks, index = {}, 0
  local blockPat = "("..data.sBlockPat..")" -- the whole block is matched not just the 1st capture
  local WeightPat = regex.new(data.sWeightPat, cflags)
  for chunk in regex.gmatch(text, blockPat, cflags) do
    local caps = { WeightPat:find(chunk) }
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
    tt.weight = ff(tt.captures, tt.chunk, i, I) or 0
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
  editor.UndoRedo("EUR_BEGIN")
  editor.DeleteBlock()
  local lnum = editor.GetInfo().CurLine
  local delim = data.sOutDelim:gsub("\\(.)", { n="\n";t="\t"; })
  for _,v in ipairs(chunks) do
    for line in v.chunk:gmatch("([^\n]*)\n?") do
      if line ~= "" then
        lnum = InsertLine(lnum, line)
      end
    end
    for line,text in delim:gmatch("(([^\n]*)\n?)") do
      if line ~= "" then
        lnum = InsertLine(lnum, text)
      end
    end
  end
  editor.UndoRedo("EUR_END")
end

if Macro then
  Macro {
    description=Title;
    area="Editor"; key=MacroKey;
    action=function()
      local data = get_data_from_dialog()
      if data then Work(data) end
    end;
  }
else
  local w = far.AdvControl("ACTL_GETWINDOWTYPE")
  if w and w.Type == F.WTYPE_EDITOR then
    local data = get_data_from_dialog()
    if data then Work(data) end
  end
end
