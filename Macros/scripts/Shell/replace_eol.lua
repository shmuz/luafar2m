-- Started: 2025-11-23
-- Replace line ends
-- Files found to contain \0 (binary nulls) are skipped

local F = far.Flags
local sd = require "far2.simpledialog"
local Recurse

local Items = {
  guid = "7B3E3B04-EE2B-4DDB-BFE5-E14390B3098E";
  -- help = "Contents";
  -- width = 76;
  { tp="dbox";  text="Replace line endings"; },
  { tp="text";  text="&File mask:"; },
  { tp="edit";  name="filemask"; hist="Masks"; uselasthistory=1; },
  { tp="chbox"; name="recurse"; text="&Recursively"; },
  { tp="sep" },
  { tp="rbutt"; name="win";  text="&Dos/Windows format (CR LF)"; },
  { tp="rbutt"; name="unix"; text="&Unix format (LF)"; val=1; },
  { tp="rbutt"; name="mac";  text="&Mac format (CR)"; },
  { tp="sep" },
  { tp="butt"; centergroup=1; default=1; text="OK"; },
  { tp="butt"; centergroup=1; cancel=1; text="Cancel"; },
}

local function GetData()
  local Dlg = sd.New(Items)
  local Pos, Elem = Dlg:Indexes()
  Elem.recurse.val = Recurse

  Items.proc = function(hDlg, msg, param1, param2)
    if msg == F.DN_CLOSE then
      if hDlg:GetText(Pos.filemask) == "" then
        far.Message("File mask field is empty", "Warning", nil, "w" ); return 0;
      end
    end
  end

  local out = Dlg:Run()
  if out then
    Recurse = out.recurse
    out.EOL = out.win and "\r\n" or out.unix and "\n" or out.mac and "\r"
  end
  return out
end

local function ReplaceEOL(fname, EOL)
  local fp, msg = io.open(fname, "rb")
  if not fp then
    far.Message(msg, "Open for read", nil, "w")
    return
  end

  local txt = fp:read("*all")
  fp:close()
  if txt:find("%z") then return end -- don't process files containing \0

  local txt2 = regex.gsub(txt, "\r\n|\n|\r", EOL)
  if txt2 == txt then return end -- nothing changed

  fp, msg = io.open(fname, "wb")
  if not fp then
    far.Message(msg, "Open for write", nil, "w")
    return
  end
  fp:write(txt2)
  fp:close()
  return true
end

local function main()
  local data = GetData()
  if not data then return end

  local start_dir = panel.GetPanelDirectory(nil,1).Name
  local n_total, n_changed = 0, 0
  far.RecursiveSearch(start_dir, data.filemask,
    function(item, fullpath)
      if not item.FileAttributes:find("d") then
        local res = ReplaceEOL(fullpath, data.EOL)
        n_total = n_total + 1
        if res then n_changed = n_changed + 1 end
      end
    end,
    data.recurse and "FRS_RECUR" or 0)

  local msg = ("%d files processed\n%d files modified"):format(n_total, n_changed)
  far.Message(msg, "Done")
end

if not Macro then main() return end

Macro {
  id="ACA00D6B-BE9D-4FBA-9342-4702BE4B066D";
  description="Replace line ends in files";
  area="Shell"; key="CtrlAltE";
  flags="NoPluginPanels"; sortpriority=10;
  action=function() main()
  end;
}
