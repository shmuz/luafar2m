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

  { tp="chbox"; name="funcmode";  text="Functi&on mode"; x1=8; },
  { tp="text";  text="I&nitial code:"; width=16; },
  { tp="edit";  name="initfunc";  hist="InitFunc"; y1=""; x1=19; },
  { tp="text";  text="Final co&de:"; width=16; },
  { tp="edit";  name="finalfunc"; hist="FinalFunc"; y1=""; x1=19; },
  { tp="sep" },

  { tp="chbox"; name="regex";      text="Re&gular expressions"; },
  { tp="chbox"; name="casesens";   text="&Case sensitive"; },
  { tp="chbox"; name="wholewords"; text="&Whole words"; },
  { tp="chbox"; name="extended";   text="&Ignore spaces"; ystep=-2; x1=5+W; },
  { tp="chbox"; name="multiline";  text="&Multi-line"; x1=5+W; },
  { tp="chbox"; name="fileasline"; text="File as a &line"; x1=5+W; },

  { tp="sep" },
  { tp="butt"; centergroup=1; default=1; text="OK"; },
  { tp="butt"; centergroup=1; cancel=1; text="Clear"; btnnoclose=1; name="clear"; },
  { tp="butt"; centergroup=1; cancel=1; text="Cancel"; },
}

-- Get data from the dialog
local function GetData()
  local Dlg = sd.New(Items)
  local Pos = Dlg:Indexes()
  local RepFunc, InitFunc, FinalFunc -- make upvalues for dialog procedure for reusing later

  Dlg:LoadData(sett.mload(set_key, set_name) or {})

  local function OnRegexChange(hDlg)
    local enb = hDlg:GetCheck(Pos.regex)
    hDlg:Enable(Pos.extended, enb)
    hDlg:Enable(Pos.multiline, enb)
    hDlg:Enable(Pos.fileasline, enb)
  end

  local function OnFuncModeChange(hDlg)
    local enb = hDlg:GetCheck(Pos.funcmode)
    for k=1,4 do
      hDlg:Enable(Pos.funcmode + k, enb)
    end
  end

  local function Clear(hDlg)
    for pos,elem in ipairs(Items) do
      if elem.tp == "chbox" then hDlg:SetCheck(pos,false)
      elseif elem.tp == "edit" then hDlg:SetText(pos,"")
      end
    end
    OnRegexChange(hDlg)
    OnFuncModeChange(hDlg)
  end

  Items.proc = function(hDlg, msg, param1, param2)
    if msg == F.DN_INITDIALOG then
      OnRegexChange(hDlg)
      OnFuncModeChange(hDlg)

    elseif msg == F.DN_BTNCLICK then
      if param1 == Pos.regex then OnRegexChange(hDlg)
      elseif param1 == Pos.funcmode then OnFuncModeChange(hDlg)
      elseif param1 == Pos.clear then Clear(hDlg)
      end

    elseif msg == F.DN_CLOSE then
      if not far.CheckMask(param2.filemask, "PN_SHOWERRORMESSAGE") then
        return 0
      end
      --------------------------------
      local patt = param2.search
      if patt == "" or param2.regex and not pcall(regex.new, patt) then
        far.Message("Invalid search string", "Search field error", nil, "w")
        return 0
      end
      --------------------------------
      if param2.funcmode then
        local str = "local T = { [0]=select(1,...); select(2, ...) }\n"
        local chunk, msg2 = loadstring(str..param2.replace)
        if chunk then
          RepFunc = chunk
        else
          far.Message(msg2, "Replace field error", nil, "w")
          return 0
        end

        InitFunc, msg2 = loadstring(param2.initfunc)
        if not InitFunc then
          far.Message(msg2, "Initial code error", nil, "w")
          return 0
        end

        FinalFunc, msg2 = loadstring(param2.finalfunc)
        if not FinalFunc then
          far.Message(msg2, "Final code error", nil, "w")
          return 0
        end
      end
    end
  end

  local out = Dlg:Run()
  if out then
    --------------------------------
    sett.msave(set_key, set_name, out)
    --------------------------------
    out.env = setmetatable({}, {__index=_G})
    --------------------------------
    out.initfunc, out.finalfunc = nil, nil
    if out.funcmode then
      out.search = "("..out.search..")" -- make regex.gsub produce T[0]
      out.replace = setfenv(RepFunc, out.env)
      out.initfunc = setfenv(InitFunc, out.env)
      out.finalfunc = setfenv(FinalFunc, out.env)
    elseif out.regex then
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
    --------------------------------
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

  if data.initfunc then data.initfunc() end
  local txt2 = regex.gsub(txt, data.search, data.replace, nil, data.cflags)
  if data.finalfunc then data.finalfunc() end

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
