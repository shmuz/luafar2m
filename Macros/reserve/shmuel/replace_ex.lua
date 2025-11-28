-- Started      : 2025-11-27

local osWindows = package.config:sub(1,1) == "\\"
local OpenFile = osWindows and io.open or win.OpenFile

local F = far.Flags
local sd = require "far2.simpledialog"
local sett = mf or require "far2.settings"
local set_key, set_name = "temp", "Replace_EX"

local W = 35
local Items = {
  guid = "E2661CE3-04DA-4106-A496-250C3924A331";
  -- help = "Contents";
  width = 2 * (W + 3);
  { tp="dbox";  text="Replace EX"; },

  { tp="chbox"; name="recurse"; text="&Recursively"; x1=W+5; },

  { tp="text";  text="&File mask:"; ystep=0; width=W; },
  { tp="edit";  name="filemask"; hist="Masks"; focus=1; },

  { tp="text";  text="&Search for:"; },
  { tp="edit";  name="search"; hist="SearchText"; },

  { tp="text";  text="R&eplace with:"; },
  { tp="edit";  name="replace"; hist="ReplaceText"; },

  { tp="chbox"; name="regex";      text="Re&gular expressions"; },
  { tp="chbox"; name="casesens";   text="&Case sensitive"; },
  { tp="chbox"; name="wholewords"; text="&Whole words"; },

  { tp="chbox"; name="extended";   text="&Ignore spaces"; ystep=-2; x1=5+W; },
  { tp="chbox"; name="multiline";  text="&Multi-line"; x1=5+W; },
  { tp="chbox"; name="fileasline"; text="File as a &line"; x1=5+W; },

  { tp="sep" },
  { tp="butt"; centergroup=1; default=1; text="OK"; },
  { tp="butt"; centergroup=1; cancel=1; text="Cancel"; },
}

local function GetData()
  local Dlg = sd.New(Items)
  local Pos = Dlg:Indexes()
  Dlg:LoadData(sett.mload(set_key, set_name) or {})

  local function OnRegexChange(hDlg)
    local enb = hDlg:GetCheck(Pos.regex)
    hDlg:Enable(Pos.extended, enb)
    hDlg:Enable(Pos.multiline, enb)
    hDlg:Enable(Pos.fileasline, enb)
  end

  Items.proc = function(hDlg, msg, param1, param2)
    if msg == F.DN_INITDIALOG then
      OnRegexChange(hDlg)
    elseif msg == F.DN_BTNCLICK then
      if param1 == Pos.regex then OnRegexChange(hDlg) end
    elseif msg == F.DN_CLOSE then
      if not far.CheckMask(param2.filemask, "PN_SHOWERRORMESSAGE") then
        return 0
      end
      --------------------------------
      local patt = param2.search
      if patt == "" or param2.regex and not pcall(regex.new, patt) then
        far.Message("Invalid search string", "Warning", nil, "w")
        return 0
      end
    end
  end

  local out = Dlg:Run()
  if out then
    sett.msave(set_key, set_name, out)
    --------------------------------
    if out.regex then
      out.replace = regex.gsub(out.replace,
          [[ \\(.) | \$ ( [0-9A-Z] ) ]],
          function(c1, c2) return c1 or "%"..c2 end,
          nil, "ix")
    end
    --------------------------------
    out.cflags = out.casesens and "" or "i"
    if out.regex then
      if out.extended   then out.cflags = out.cflags.."x" end
      if out.multiline  then out.cflags = out.cflags.."m" end
      if out.fileasline then out.cflags = out.cflags.."s" end
    else
      out.search = out.search:gsub("%p", "\\%0")
    end
    --------------------------------
    if out.wholewords then
      out.search = "\\b"..out.search.."\\b"
    end
  end
  return out
end

local function ReplaceInFile(item, fname, data)
  local fp, msg = OpenFile(fname, "rb")
  if not fp then
    far.Message(msg, "Open for read", nil, "w")
    return
  end

  local txt = fp:read(item.FileSize)
  fp:close()
  if txt:find("%z") then return end -- don't process files containing \0

  local txt2 = regex.gsub(txt, data.search, data.replace, nil, data.cflags)
  if txt2 == txt then return end -- nothing changed

  fp, msg = OpenFile(fname, "wb")
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

  if far.Message("Your files will be modified.\nContinue?", "Warning", "Yes;No", "w") ~= 1 then
    return
  end

  local start_dir = panel.GetPanelDirectory(nil,1).Name
  local n_total, n_changed = 0, 0
  far.RecursiveSearch(start_dir, data.filemask,
    function(item, fullpath)
      if not item.FileAttributes:find("d") then
        local res = ReplaceInFile(item, fullpath, data)
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
  id="11986160-83AE-474D-9E85-D615A77AF658";
  description="SUPER Replace";
  area="Shell"; key="CtrlAltE";
  flags="NoPluginPanels"; sortpriority=5;
  action=function() main() end;
}
