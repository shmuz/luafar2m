-- started: 2026-03-23

local Title = "Convert files to UTF-8"
local F = far.Flags

local function CheckMask (mask)
  return far.ProcessName("PN_CHECKMASK", mask, nil, "PN_SHOWERRORMESSAGE")
end

local function ConvertToUtf8(text, codepage)
  text = win.MultiByteToWideChar(text, codepage)
  text = win.WideCharToMultiByte(text, 65001)
  return text
end

local function RunDialog()
  local Items = {
    guid = "B7FC54C4-13A2-4F84-AF1E-5FD89F8C1B7A";
    { tp="dbox"; text=Title;         },
    { tp="text"; text="File &mask:"; },
    { tp="edit"; name="filemask"; hist="Masks"; uselasthistory=1; },
    ------------------------------------------------------------------
    { tp="text"; text="Convert &from:"; },
    { tp="combobox"; name="codepage"; dropdown=1;
        list={
          {Text="ANSI";Flags="LIF_SELECTED"},
          {Text="OEM"},
        }; },
    ------------------------------------------------------------------
    { tp="text"; text="Search &area:"; },
    { tp="combobox"; name="searcharea"; dropdown=1;
        list={
          {Text="From the current folder";Flags="LIF_SELECTED"},
          {Text="The current folder only"},
        }; },
    ------------------------------------------------------------------
    { tp="sep"; },
    { tp="butt"; centergroup=1; default=1; text="OK";    },
    { tp="butt"; centergroup=1; cancel=1; text="Cancel"; },
  }

  local sd = require "far2.simpledialog"
  local Dlg = sd.New(Items)

  Items.proc = function(hDlg, msg, param1, param2)
    if msg == F.DN_CLOSE then
      if not CheckMask(param2.filemask) then return 0 end
    end
  end

  return Dlg:Run()
end

local ANS_YES, ANS_NO, ANS_ALL, ANS_CANCEL = 1,2,3,4 -- must match the buttons' order

local function AskUser(fname, text)
  text = text:gsub("^%s+", "")
  local msg = ("File: %s\nText: %s"):format(fname, text)
  local ret = far.Message(msg, "Check the converted text",
      "&OK for file;&Skip file;OK for &All files;&Cancel", "l")
  return ret >= 1 and ret or ANS_CANCEL
end

local function ConvertFile(item, path, param)
  if item.FileAttributes:find("d") then
    return
  end
  local fp = assert(io.open(path))
  param.Total = param.Total + 1
  local lines = {}
  local dirty = false
  local answer = (param.answer == ANS_ALL) and ANS_ALL

  for ln in fp:lines() do
    if ln:isvalid() then
      table.insert(lines, ln)
    else
      dirty = true
      local ln2 = ConvertToUtf8(ln, param.CodePage)
      table.insert(lines, ln2)
      if answer ~= ANS_ALL and answer ~= ANS_YES then
        answer = AskUser(item.FileName, ln2)
        param.answer = answer
        if answer == ANS_NO or answer == ANS_CANCEL then
          break
        end
      end
    end
  end
  fp:close()

  if dirty then
    if answer == ANS_NO then return false end
    if answer == ANS_CANCEL then return true end
    fp = assert(io.open(path,"w"))
    param.Changed = param.Changed + 1
    for _,ln in ipairs(lines) do
      fp:write(ln, "\n")
    end
    fp:close()
  end
end

local function main()
  local data = RunDialog()
  if not data then return end

  local param = {
    CodePage = data.codepage == 1 and win.GetACP() or win.GetOEMCP();
    Total = 0; Changed = 0;
  }

  local paneldir = panel.GetPanelDirectory(nil, 1)
  local startdir = far.ConvertPath(paneldir.Name)
  local flags = data.searcharea==1 and "FRS_RECUR" or 0
  far.RecursiveSearch(startdir, data.filemask, ConvertFile, flags, param)
  local msg = [[
Files processed: %d
Files modified:  %d]]
  far.Message(msg:format(param.Total, param.Changed), Title, nil, "l")
end

if not Macro then main() return end

Macro {
  id="C486B6C4-0E7D-4D99-92DA-127A4BBD4635";
  description="Convert files to UTF-8";
  area="Shell"; key="CtrlAltE";
  flags="NoPluginPanels"; sortpriority=9;
  action=function() main()
  end;
}
