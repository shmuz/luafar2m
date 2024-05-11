-- Started              : 2021-03-06
-- Platform             : Windows/Far3, Linux/far2m
-- Minimal Far3 version : 3.0.3300
-- Far plugin           : Either LuaMacro or LF4Ed
-- Description          : Customize the following operations in the Far Editor:
--                        (1) indent on Enter press (configurable per file extension)
--                        (2) dedent on Backspace press

local F = far.Flags
local OsWindows = package.config:sub(1,1) == "\\"
local FarBuild = OsWindows and select(4, far.AdvControl("ACTL_GETFARMANAGERVERSION",true))

--------------------------------------------------------------------------------
-- IMPORTANT: all keys (file extensions) in Config table must be in lower case
local Config = {
  lua = { pat= [[ \b(then|else|do)\b \s* (\-\-.*)? $ ]], indent= (" "):rep(2); },
  c   = { pat= [[ \{                 \s* (\/\/.*)? $ ]]; indent= (" "):rep(2); },
  py  = { pat= [[ \:                 \s* (\#  .*)? $ ]]; indent= (" "):rep(4); },
}
for _,v in pairs(Config) do v.pat = regex.new(v.pat,"x") end -- compile

Config.cpp = Config.c
Config.cxx = Config.c
Config.h   = Config.c
Config.hpp = Config.c
Config.pyw = Config.py
--------------------------------------------------------------------------------

local function GetConfig()
  local patt = OsWindows and "%.([^.\\]+)$" or "%.([^./]+)$"
  local ext = editor.GetFileName():match(patt)
  return ext and Config[ext:lower()]
end

-- 3.0.3425 (LuaFAR: API extension of editor.GetString)
local WrapGetString = OsWindows and FarBuild < 3425 and
  function(Id, LineNum)
    local data = editor.GetString(Id, LineNum)
    return data and data.StringText
  end
  or editor.GetString

local function OnEnter()
  local conf = GetConfig()
  if conf then
    local info = editor.GetInfo()
    local curline = WrapGetString(nil, info.CurLine, 3)
    local line1, line2 = curline:sub(1,info.CurPos-1), curline:sub(info.CurPos)
    local indent = curline:match("^%s*")
    if conf.pat:find(line1) then
      indent = (indent:sub(1,1)=="\t" and "\t" or conf.indent) .. indent
    end
    editor.UndoRedo(nil, "EUR_BEGIN")
    editor.InsertString()
    editor.SetString(nil, info.CurLine,   line1:match("(.-)%s*$"))
    editor.SetString(nil, info.CurLine+1, indent..line2:match("%s*(.-)%s*$"))
    editor.SetPosition(nil, info.CurLine+1, #indent+1)
    editor.Redraw()
    editor.UndoRedo(nil, "EUR_END")
    return true
  end
end

local function OnBackSpace()
  if not GetConfig() then return end

  local info = editor.GetInfo()
  if info.BlockType ~= F.BTYPE_NONE then return end

  if info.CurPos <= 2 then return end

  local line = WrapGetString(nil, info.CurLine, 3)
  local pos = line:find("%S")
  if not (pos and pos < info.CurPos) then
    local stop = math.max(1, info.CurLine-1000) -- limit search at 1000 lines above the current
    for k=info.CurLine-1,stop,-1 do
      local ln = WrapGetString(nil, k, 3)
      pos = ln:find("%S")
      if pos and pos < info.CurPos then
        editor.SetString(nil, info.CurLine, ln:sub(1,pos-1)..line:sub(info.CurPos))
        editor.SetPosition(nil, info.CurLine, pos)
        editor.Redraw()
        return true
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

local IsLuaMacro, IsLF4Ed
if OsWindows then
  local Id = far.PluginStartupInfo().PluginGuid
  IsLuaMacro = Id == win.Uuid("4EBBEFC8-2084-4B7F-94C0-692CE136894D")
  IsLF4Ed    = Id == win.Uuid("6F332978-08B8-4919-847A-EFBB6154C99A")
else
  local Id = far.GetPluginId()
  IsLuaMacro = Id == 0x4EBBEFC8
  IsLF4Ed    = Id == 0x6F332978
end

if IsLuaMacro then
  Event {
    description = "Auto-indent/dedent";
    group = "EditorInput";
    action = OnEditorInput;
  }
elseif IsLF4Ed then
  ProcessEditorInput = OnEditorInput -- luacheck: globals ProcessEditorInput
end
