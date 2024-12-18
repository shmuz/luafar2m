---- Debug lines ----
--far.ReloadDefaultScript = true
--package.loaded.macrosyn = nil
---- End debug lines ----

local F = far.Flags
local macrosyn = require "macrosyn"

local function ErrMsg (str, flags)
  local info = far.GetPluginGlobalInfo()
  local ver = table.concat(info.Version, ".", 1, 2)
  local title = ("%s ver.%s"):format(info.Title, ver)
  far.Message(str, title, nil, flags or "w")
end

-- Split command line into separate arguments.
-- * An argument is either of:
--     a) a sequence of 0 or more characters enclosed within a pair of non-escaped
--        double quotes; can contain spaces; enclosing double quotes are stripped
--        from the argument.
--     b) a sequence of 1 or more non-space characters.
-- * Backslashes only escape double quotes.
-- * The function does not raise errors.
local function SplitCommandLine (str)
  local pat = [["((?:\\"|[^"])*)"|((?:\\"|\S)+)]]
  local out = {}
  for c1, c2 in regex.gmatch(str, pat) do
    out[#out+1] = regex.gsub(c1 or c2, [[\\(")|(.)]], "%1%2")
  end
  return out
end

local function ExpandPath (path)
  return path
end

local PluginInfo = {
  CommandPrefix = "m2l",
  Flags = PF_DISABLEPANELS,
}

function export.GetPluginInfo()
  return PluginInfo
end

-- AVAILABLE OPERATIONS
-- "xml_file"
-- "xml_macros"
-- "xml_keymacros"
-- "xml_macro"

-- "fml_file"
-- "fml_macro"

-- "chunk"
-- "expression"
local function ConvertFile (srcfile, trgfile, syntax)
  local fp, err = io.open(srcfile)
  if not fp then ErrMsg(err) return end

  local text = fp:read("*all")
  fp:close()
  local Bom = "\239\187\191" -- UTF-8 BOM
  if string.sub(text,1,3)==Bom then
    text=string.sub(text,4)
  end

  local text,msg = macrosyn.Convert(syntax,text)

  if not text and msg == "" then msg = "conversion failed" end
  if msg ~= "" then ErrMsg(srcfile.."\n"..msg, text and "l" or "lw") end
  if text then
    local fp, err = io.open(trgfile, "w")
    if not fp then ErrMsg(err) return end
    fp:write(text)
    fp:close()
  end
end

local function RunFile (file, ...)
  local func,msg = loadfile(file)
  if not func then ErrMsg(msg) return end
  local env = { Convert=macrosyn.Convert }
  setmetatable(env, {__index=_G})
  setfenv(func, env)(...)
end

local function ShowSyntax()
  ErrMsg([=[
M2L: convert <input file> <output file> [<syntax>]
M2L: run <script file> [<arguments>]]=], "l")
end

local function ProcessArgs (args)
  if #args==0 then ShowSyntax() return end
  local command = args[1]:lower()
  if command == "convert" then
    if #args<3 then ShowSyntax() return end
    local srcfile, trgfile = ExpandPath(args[2]), ExpandPath(args[3])
    local syntax = (args[4] or "xml_file"):lower()
    ConvertFile(srcfile, trgfile, syntax)
  elseif command == "run" then
    if #args<2 then ShowSyntax() return end
    RunFile(ExpandPath(args[2]), unpack(args,3))
  else
    ShowSyntax()
  end
end

function export.Open (OpenFrom, Guid, Item)
  local area = bit64.band(0xFF, OpenFrom)
  if area == F.OPEN_COMMANDLINE then
    ProcessArgs(SplitCommandLine(Item))
  elseif area == F.OPEN_PLUGINSMENU then
  elseif area == F.OPEN_EDITOR then
  elseif area == F.OPEN_FROMMACRO then
    if type(Item)=="table" then
      local syntax,input = Item[1],Item[2]
      if type(syntax)=="string" and type(input)=="string" then
        return macrosyn.Convert(syntax, input)
      end
    end
  end
end
