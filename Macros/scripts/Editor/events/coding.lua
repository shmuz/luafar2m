-- Started             : 2021-03-06
-- Minimal Far version : 3.0.3300
-- Far plugin          : Either LuaMacro or LF4Ed
-- Description         : Customize the following operations in the Far Editor:
--                       (1) indent on Enter press (configurable per file extension)
--                       (2) dedent on Backspace press

local F = far.Flags
--------------------------------------------------------------------------------
-- IMPORTANT: all keys (file extensions) in Config table must be in lower case
local Config = {
  lua = { pat= [[ \b(then|else|do)\b \s* (\-\-.*)? $ ]], indent= "  ";   },
  c   = { pat= [[ \{                 \s* (\/\/.*)? $ ]]; indent= "  ";   },
  py  = { pat= [[ \:                 \s* (\#  .*)? $ ]]; indent= "    "; },
}
for _,v in pairs(Config) do v.pat = regex.new(v.pat,"x") end -- compile

Config.cpp = Config.c
Config.cxx = Config.c
Config.h   = Config.c
Config.hpp = Config.c
Config.pyw = Config.py
--------------------------------------------------------------------------------

local function GetConfig()
  local ext = editor.GetFileName():match("%.([^.\\]+)$") or ""
  return Config[ext:lower()]
end

local function OnEnter()
  local conf = GetConfig()
  if conf then
    local info = editor.GetInfo()
    local curline = editor.GetString(info.CurLine, 2)
    local line1, line2 = curline:sub(1,info.CurPos-1), curline:sub(info.CurPos)
    local indent = curline:match("^%s*")
    if conf.pat:find(line1) then
      indent = (indent:sub(1,1)=="\t" and "\t" or conf.indent) .. indent
    end
    editor.UndoRedo("EUR_BEGIN")
    editor.InsertString()
    editor.SetString(info.CurLine,   line1:match("(.-)%s*$"))
    editor.SetString(info.CurLine+1, indent..line2:match("%s*(.-)%s*$"))
    editor.SetPosition(info.CurLine+1, #indent+1)
    editor.Redraw()
    editor.UndoRedo("EUR_END")
    return true
  end
end

local function OnBackSpace()
  local conf = GetConfig()
  if conf then
    local info = editor.GetInfo()
    if info.CurPos > 2 then
      local line = editor.GetString(info.CurLine, 3)
      local pos = line:find("%S")
      if not (pos and pos < info.CurPos) then
        local stop = math.max(1, info.CurLine-1000) -- limit search at 1000 lines above the current
        for k=info.CurLine-1,stop,-1 do
          local ln = editor.GetString(k, 3)
          pos = ln:find("%S")
          if pos and pos < info.CurPos then
            editor.SetString(info.CurLine, ln:sub(1,pos-1)..line:sub(info.CurPos))
            editor.SetPosition(info.CurLine, pos)
            editor.Redraw()
            return true
          end
        end
      end
    end
  end
end

local function OnEditorInput(Rec)
  if Rec.EventType == F.KEY_EVENT then
    local key = far.InputRecordToName(Rec)
    if key == "Enter" or key == "NumEnter" then
      return OnEnter()
    elseif key == "BS" then
      return OnBackSpace()
    end
  end
end

Event {
  description="Auto-indent/dedent";
  group="EditorInput";
  action=OnEditorInput;
}
