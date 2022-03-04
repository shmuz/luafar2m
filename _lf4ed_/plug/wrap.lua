--[[
 Goal: wrap long lines without breaking words.
--]]

local sd = require "far2.simpledialog"
local M  = require "lf4ed_message"
local F = far.Flags
local insert, concat = table.insert, table.concat


-- iterator factory
local function EditorBlock (start_line)
  start_line = start_line or editor.GetInfo().BlockStartLine
  return function()
    local lineInfo = editor.GetString (start_line, 1)
    if lineInfo and lineInfo.SelStart >= 1 and lineInfo.SelEnd ~= 0 then
      start_line = start_line + 1
      return lineInfo
    end
  end
end


local function EditorHasSelection (editInfo)
  return editInfo.BlockType ~= 0 and editInfo.BlockStartLine >= 1
end


local function EditorSelectCurLine (editInfo)
  return editor.Select ("BTYPE_STREAM", editInfo.CurLine, 1, nil, 1)
end


local function Incr (input, first, last)
  for k = #input, 1, -1 do
    if input[k] == last then
      input[k] = first
    else
      input[k] = string.char (string.byte(input[k]) + 1)
      return
    end
  end
  insert (input, 1, first)
end


-- Prefix can be made smart:
--     "S:12"     --  12 spaces
--     "L:>> "    --  prefix ">> "
--     "N:5."     --  automatic numbering, beginning from "5."
--     "N:5)"     --  automatic numbering, beginning from "5)"
--     "N:c"      --  automatic numbering, beginning from "c"
--     "N:C."     --  automatic numbering, beginning from "C."
--
local function GetPrefix (aCode)
  local op = aCode:sub(1,2):upper()
  local param = aCode:sub(3):gsub ("%:$", "")
  if op == "S:" then
    local n = assert (tonumber (param), "Prefix parameter must be a number")
    assert (n <= 1000, "Prefix length is limited at 1000")
    return string.rep (" ", n)

  elseif op == "L:" then
    return param

  elseif op == "N:" then
    local init, places, delim = param:match ("^(%w+)%,?(%d*)%,?(.*)")
    if not init then return end
    if places == "" then places = 0 end
    if tonumber(init) then
      init = tonumber(init)
      return function()
        local cur_init = tostring(init)
        init = init + 1
        return string.rep(" ", places - #cur_init) .. cur_init .. delim
      end
    else
      local first, last
      if init:find ("^[a-z]+$") then first,last = "a","z"
      elseif init:find ("^[A-Z]+$") then first,last = "A","Z"
      else error("Prefix Lines: invalid starting number")
      end
      local t = {}
      for k=1,#init do t[k] = init:sub(k,k) end
      init = t
      return function()
        local cur_init = concat(init)
        Incr(init, first, last)
        return string.rep(" ", places - #cur_init) .. cur_init .. delim
      end
    end

  end
end


local function Wrap (aColumn1, aColumn2, aPrefix, aJustify, aFactor)
  local editInfo = editor.GetInfo()
  if not EditorHasSelection (editInfo) then
    if EditorSelectCurLine (editInfo) then
      editInfo = editor.GetInfo()
    else
      return
    end
  end

  local linetable, jointable = {}, {}
  local function flush()
    if #jointable > 0 then
      insert (linetable, concat (jointable, " "))
      jointable = {}
    end
  end

  for line in EditorBlock (editInfo.BlockStartLine) do
    if line.StringText:find("%S") then
      insert (jointable, line.StringText)
    else
      flush()
      insert (linetable, "")
    end
  end
  flush()

  editor.DeleteBlock()

  local aMaxLineLen = aColumn2 - aColumn1 + 1
  local indent = (" "):rep(aColumn1 - 1)
  local lines_out = {} -- array for output lines

  -- Compile the next output line and store it.
  local function make_line (from, to, len, words)
    local prefix = type(aPrefix) == "string" and aPrefix or aPrefix()
    local extra = aMaxLineLen - len
    if aJustify and (aFactor * (to - from) >= extra) then
      for i = from, to - 1 do
        local sp = math.floor ((extra / (to - i)) + 0.5)
        words[i] = words[i] .. string.rep (" ", sp+1)
        extra = extra - sp
      end
      insert (lines_out, indent .. prefix .. concat (words, "", from, to))
    else
      insert (lines_out, indent .. prefix .. concat (words, " ", from, to))
    end
  end

  -- Iterate on selected lines (input lines); make and collect output lines.
  for _,line in ipairs(linetable) do
    -- Iterate on words on the currently processed line.
    local ind, start, len = 0, 1, -1
    local words = {}
    for w in line:gmatch ("%S+") do
      ind = ind + 1
      words[ind] = w
      local wlen = w:len()
      local newlen = len + 1 + wlen
      if newlen > aMaxLineLen then
        if len > 0 then
          make_line (start, ind-1, len, words)
          start, len = ind, wlen
        else
          make_line (ind, ind, wlen, words)
          start, len = ind+1, -1
        end
      else
        len = newlen
      end
    end

    if ind == 0 or len > 0 then
      make_line (start, #words, len, words)
    end
  end

  -- Put reformatted lines into the editor
  local Pos = { CurLine = editInfo.BlockStartLine, CurPos = 1 }
  editor.SetPosition (Pos)
  for i = #lines_out, 1, -1 do
    editor.InsertString()
    editor.SetPosition (Pos)
    editor.SetString(nil, lines_out[i])
  end
end


local function PrefixBlock (aPrefix)
  local bNotSelected
  local editInfo = editor.GetInfo()
  if not EditorHasSelection (editInfo) then
    assert (EditorSelectCurLine (editInfo))
    editInfo = editor.GetInfo()
    bNotSelected = true
  end

  if type(aPrefix) == "string" then
    local p = aPrefix
    aPrefix = function() return p end
  end

  for line in EditorBlock (editInfo.BlockStartLine) do
    editor.SetString(nil, aPrefix() .. line.StringText)
  end

  editor.SetPosition (editInfo)
  if bNotSelected then editor.Select("BTYPE_NONE") end
end


local function ExecuteWrapDialog (aData)
  local HIST_PREFIX = "LuaFAR\\Reformat\\Prefix"
  local Items = {
    guid = "6D5C7EC2-8C2F-413C-81E6-0CC8FFC0799A";
    width = 76;
    help = "Wrap";
    {tp="dbox";    text=M.MReformatBlock;                                 },
    {tp="chbox";   name="cbxReformat"; text=M.MReformatBlock2; val=1;     },
    {tp="text";    name="labStart";          x1=9;  text=M.MStartColumn;  },
    {tp="fixedit"; name="edtColumn1"; y1=""; x1=22; x2=25; val=1;         },
    {tp="text";    name="labEnd";     y1=""; x1=29; text=M.MEndColumn;    },
    {tp="fixedit"; name="edtColumn2"; y1=""; x1=41; x2=44; val=70;        },
    {tp="chbox";   name="cbxJustify";        x1=9; text=M.MJustifyBorder; },
    {tp="sep";                                                            },
    {tp="chbox";   name="cbxPrefix";  text=M.MPrefixLines;                },
    {tp="text";    name="labCommand"; x1=9; text=M.MCommand;              },
    {tp="edit";    name="edtPrefix";  x1=17; y1=""; hist=HIST_PREFIX; val="S:4"; },
    {tp="sep";                                                            },
    {tp="butt";    text=M.MOk;     centergroup=1; default=1;              },
    {tp="butt";    text=M.MCancel; centergroup=1; cancel=1;               },
  }
  local Pos = sd.Indexes(Items)
  ----------------------------------------------------------------------------
  -- Handlers of dialog events --
  local function Check (hDlg, c1, ...)
    local enbl = hDlg:GetCheck(c1)
    for _, elem in ipairs {...} do hDlg:Enable(elem, enbl) end
  end

  function Items.proc (hDlg, msg, param1, param2)
    if msg == F.DN_INITDIALOG then
      Check (hDlg, Pos.cbxReformat, Pos.labStart, Pos.edtColumn1, Pos.labEnd, Pos.edtColumn2, Pos.cbxJustify)
      Check (hDlg, Pos.cbxPrefix, Pos.edtPrefix, Pos.labCommand)
    elseif msg == F.DN_BTNCLICK then
      if param1 == Pos.cbxReformat then
        Check (hDlg, param1, Pos.labStart, Pos.edtColumn1, Pos.labEnd, Pos.edtColumn2, Pos.cbxJustify)
      elseif param1 == Pos.cbxPrefix then
        Check (hDlg, param1, Pos.edtPrefix, Pos.labCommand)
      end
    end
  end
  ----------------------------------------------------------------------------
  sd.LoadData(aData, Items)
  local out = sd.Run(Items)
  if out then
    sd.SaveData(out, aData)
    return true
  end
end


local function WrapWithDialog (aData)
  if not ExecuteWrapDialog(aData) then return end
  local prefix = aData.cbxPrefix and aData.edtPrefix and GetPrefix(aData.edtPrefix) or ""

  if aData.cbxReformat then
    local offs1 = assert(tonumber(aData.edtColumn1), "start column is not a number")
    local offs2 = assert(tonumber(aData.edtColumn2), "end column is not a number")
    assert(offs1 >= 1, "start column is less than 1")
    assert(offs2 >= offs1, "end column is less than start column")

    editor.UndoRedo("EUR_BEGIN")
    Wrap (offs1, offs2, prefix, aData.cbxJustify, 2.0)
    editor.UndoRedo("EUR_END")

  elseif prefix ~= "" then
    editor.UndoRedo("EUR_BEGIN")
    PrefixBlock(prefix)
    editor.UndoRedo("EUR_END")
  end
end

local history = ...
WrapWithDialog (history)
