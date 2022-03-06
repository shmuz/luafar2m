--[[
 Goal: evaluate Lua expression.
 Start: 2006-02-?? by Shmuel Zeigerman
--]]

local sd = require "far2.simpledialog"
local M = require "lf4ed_message"
local F = far.Flags

local function ErrMsg (msg)
  far.Message(msg, M.MError, M.MOk, "w")
end

local function GetNearestWord (pattern)
  local line = editor.GetString(nil, 2)
  local pos = editor.GetInfo().CurPos
  local r = regex.new(pattern)
  local start = 1
  while true do
    local from, to, word = r:find(line, start)
    if not from then break end
    if pos <= to then return from, to, word end
    start = to + 1
  end
end

local function GetAllText()
  local ei = editor.GetInfo()
  if ei then
    local t = {}
    for n = 1, ei.TotalLines do
      table.insert(t, editor.GetString(n, 2))
    end
    editor.SetPosition(ei)
    return table.concat(t, "\n")
  end
end

local function GetSelectedText()
  local ei = editor.GetInfo()
  if ei and ei.BlockType ~= F.BTYPE_NONE then
    local t = {}
    local n = ei.BlockStartLine
    while true do
      local s = editor.GetString(n, 1)
      if not s or s.SelStart == 0 then
        break
      end
      local sel = s.StringText:sub (s.SelStart, s.SelEnd)
      table.insert(t, sel)
      n = n + 1
    end
    editor.SetPosition(ei)
    return table.concat(t, "\n"), n-1
  end
end

local function CompileParams (s1, s2, s3, s4)
  local p1 = assert(loadstring("return "..s1, "Parameter #1"))
  local p2 = assert(loadstring("return "..s2, "Parameter #2"))
  local p3 = assert(loadstring("return "..s3, "Parameter #3"))
  local p4 = assert(loadstring("return "..s4, "Parameter #4"))
  return p1, p2, p3, p4
end

local function ParamsDialog (aData)
  local HIST_PARAM = "LuaFAR\\LuaScript\\Parameter"
  local Items = {
    width = 56;
    help = "ScriptParams";
    guid = "D0CDAE16-C402-4E54-9D23-7150A8D87787";
    {tp="dbox";  text=M.MScriptParams;                                      },
    {tp="text";  text="&1.";           ystep=2; width=2;                    },
    {tp="edit";  name="sParam1";       ystep=0; x1=8; hist=HIST_PARAM;      },
    {tp="text";  text="&2.";           ystep=2; width=2;                    },
    {tp="edit";  name="sParam2";       ystep=0; x1=8; hist=HIST_PARAM;      },
    {tp="text";  text="&3.";           ystep=2; width=2;                    },
    {tp="edit";  name="sParam3";       ystep=0; x1=8; hist=HIST_PARAM;      },
    {tp="text";  text="&4.";           ystep=2; width=2;                    },
    {tp="edit";  name="sParam4";       ystep=0; x1=8; hist=HIST_PARAM;      },
    {tp="chbox"; name="bParamsEnable"; ystep=2; text=M.MScriptParamsEnable; },
    {tp="sep";                                                              },
    {tp="butt";  text=M.MRunScript; default=1; centergroup=1; Run=1;        },
    {tp="butt";  text=M.MStoreParams;          centergroup=1; Store=1;      },
    {tp="butt";  text=M.MCancel;    cancel=1;  centergroup=1;               },
  }
  ------------------------------------------------------------------------------
  Items.closeaction = function(hDlg, par1, out)
    local ok, msg = pcall(CompileParams, out.sParam1, out.sParam2, out.sParam3, out.sParam4)
    if not ok then ErrMsg(msg); return 0; end
  end
  ------------------------------------------------------------------------------
  sd.LoadData(aData, Items)
  local out,pos = sd.Run(Items)
  if out then
    sd.SaveData(out, aData)
    return Items[pos].Run and "run" or Items[pos].Store and "store"
  end
end

-- WARNING:
--   don't change the string literals "selection" and "all text",
--   since export.OnError relies on them being exactly such.
local function LuaScript (data)
  local text, chunkname = GetSelectedText(), "selection"
  if not text then
    text, chunkname = GetAllText(), "all text"
    if text and text:sub(1,1)=="#" then text = "--"..text end
  end
  if text then
    local chunk, msg = loadstring(text, chunkname)
    if not chunk then error(msg,3) end
    if data.bParamsEnable then
      local p1,p2,p3,p4 = CompileParams(data.sParam1, data.sParam2,
                                        data.sParam3, data.sParam4)
      p1 = p1(); p2 = p2(); p3 = p3(); p4 = p4()
      return chunk (p1,p2,p3,p4)
    else
      return chunk()
    end
  end
end

local function ResultDialog (aHelpTopic, aData, result)
  local Title = (aHelpTopic=="LuaExpression") and M.MExpr or M.MBlockSum
  local XX1 = 5 + M.MResult:gsub("&",""):len() + 1
  local Items = {
    width = 46;
    help = aHelpTopic;
    {tp="dbox";  text=Title;                                },
    {tp="text";  text=M.MResult;                            },
    {tp="edit";  name="edtResult"; ystep=0; x1=XX1; val=result; noload=1; },
    {tp="chbox"; name="cbxInsert"; text=M.MInsertText;      },
    {tp="chbox"; name="cbxCopy";   text=M.MCopyToClipboard; },
    {tp="sep";                                              },
    {tp="butt";  text=M.MOk;     default=1; centergroup=1;  },
    {tp="butt";  text=M.MCancel; cancel=1;  centergroup=1;  },
  }
  ------------------------------------------------------------------------------
  sd.LoadData(aData, Items)
  local out = sd.Run(Items)
  if out then
    sd.SaveData(out, aData)
    return true
  end
end

local function BlockSum (history)
  local ei = assert(editor.GetInfo(), "EditorGetInfo failed")
  local blockEndLine
  local sum = 0
  local x_start, x_dot, has_dots
  local pattern = [[(\S[\w.]*)]]

  if ei.BlockType ~= F.BTYPE_NONE then
    local r = regex.new(pattern)
    for n=ei.BlockStartLine, ei.TotalLines do
      local s = editor.GetString (n)
      if s.SelEnd == 0 or s.SelStart < 1 then
        blockEndLine = n - 1
        break
      end
      local start, fin, sel = r:find( s.StringText:sub(s.SelStart, s.SelEnd) ) -- 'start' in selection
      if start then
        x_start = editor.RealToTab(n, s.SelStart + start - 1) -- 'start' column in line
        local num = tonumber(sel)
        if num then
          sum = sum + num
          local x = regex.find(sel, "\\.")
          if x then
            has_dots = true
            x_dot = x_start + x - 1  -- 'dot' column in line
          else
            x_dot = editor.RealToTab(n, s.SelStart + fin)
          end
        end
      end
    end
  else
    local start, fin, word = GetNearestWord(pattern)
    if start then
      x_start = editor.RealToTab(nil, start)
      local num = tonumber(word)
      if num then
        sum = sum + num
        local x = regex.find(word, "\\.")
        if x then
          has_dots = true
          x_dot = x_start + x - 1
        else
          x_dot = editor.RealToTab(nil, 1 + fin)
        end
      end
    end
  end

  if has_dots then
    sum = tostring(sum)
    local last = sum:match("%.(%d+)$")
    sum = sum .. (last and ("0"):rep(2 - #last) or ".00")
  end
  if not ResultDialog("BlockSum", history, sum) then return end

  sum = history.edtResult
  if history.cbxCopy then
    far.CopyToClipboard(sum)
  end
  if history.cbxInsert then
    local y = blockEndLine or ei.CurLine -- position of the last line
    local s = editor.GetString(y)                     -- get last line
    editor.SetPosition (y, s.StringText:len()+1)      -- insert a new line
    editor.InsertString()                             -- +
    local prefix = "="
    if x_dot then
      local x = regex.find(tostring(sum), "\\.") or #sum+1
      if x then x_start = x_dot - (x - 1) end
    end
    if x_start then
      x_start = x_start>#prefix and x_start-#prefix or 1
    else
      x_start = (ei.BlockType==F.BTYPE_COLUMN) and s.SelStart or 1
    end
    editor.SetPosition (y+1, x_start, nil, nil, ei.LeftPos)
    editor.InsertText(prefix .. sum)
    editor.Redraw()
  else
    editor.SetPosition (ei) -- restore the position
  end
end

local function LuaExpr (history)
  local edInfo = editor.GetInfo()
  local text, numline = GetSelectedText()
  if not text then
    numline = edInfo.CurLine
    text = editor.GetString(numline, 2)
  end

  local func, msg = loadstring("return " .. text)
  if not func then
    ErrMsg(msg) return
  end

  local env = {}
  for k,v in pairs(math) do env[k]=v end
  setmetatable(env, { __index=_G })
  setfenv(func, env)
  local ok, result = pcall(func)
  if not ok then
    ErrMsg(result) return
  end

  result = tostring(result)
  if not ResultDialog("LuaExpression", history, result) then
    return
  end

  result = history.edtResult
  if history.cbxInsert then
    local line = editor.GetString(numline)
    local pos = (edInfo.BlockType==F.BTYPE_NONE) and line.StringLength or line.SelEnd
    editor.SetPosition(numline, pos+1)
    editor.InsertText(" = " .. result .. " ;")
    editor.Redraw()
  end
  if history.cbxCopy then
    far.CopyToClipboard(result)
  end
end

local funcs = {
  BlockSum     = BlockSum,
  LuaExpr      = LuaExpr,
  LuaScript    = function(aData) return LuaScript(aData) end, -- keep errorlevel==3
  ScriptParams = function(aData)
      if ParamsDialog(aData) == "run" then return LuaScript(aData) end
    end,
}

do
  local op, data = ...
  return assert (funcs[op])(data)
end

