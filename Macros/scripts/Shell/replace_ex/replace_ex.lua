-- Started      : 2025-11-27

local MAX_SIZE = 2 ^ 28 -- (256 MiB) skip files larger than this value

local osWindows = package.config:sub(1,1) == "\\"
local OpenFile = osWindows and io.open or win.OpenFile --luacheck:ignore
local Clock = osWindows and function() return far.FarClock()/1e6 end or win.Clock --luacheck:ignore

local F = far.Flags
local sd = require "far2.simpledialog"
local sett = mf or require "far2.settings"
local libMessage = require "far2.message"
local set_key, set_name = "temp", "Replace_EX"
local Title = "Replace in files"

-- Get data from the dialog
local function GetData()
  local W = 35
  local Items = {
    guid = "E2661CE3-04DA-4106-A496-250C3924A331";
    -- help = "Contents";
    width = 2 * (W + 3);
    { tp="dbox";  text="Replace EX"; },

    { tp="chbox"; name="recurse"; text="&Recursively"; x1=W+5; },
    { tp="text";  text="&File mask:"; y1=""; width=W; },
    { tp="edit";  name="filemask"; hist="Masks"; focus=1; },

    { tp="text";  text="&Search for:"; },
    { tp="edit";  name="search"; hist="SearchText"; },
    { tp="text";  text="R&eplace with:"; },
    { tp="edit";  name="replace"; hist="ReplaceText"; },

    { tp="chbox"; name="regex";      text="Re&gular expressions"; },
    { tp="chbox"; name="casesens";   text="&Case sensitive"; },
    { tp="chbox"; name="wholewords"; text="&Whole words"; },
    { tp="chbox"; name="extended";   text="&Ignore spaces"; ystep=-2; x1=5+W; },
    { tp="chbox"; name="multiline";  text="&Multi-line"; x1=""; },
    { tp="chbox"; name="fileasline"; text="File as a &line"; x1=""; },
    { tp="sep" },

    { tp="chbox"; name="funcmode";  text="Functi&on mode"; },
    { tp="text";  text="I&nitial code:"; width=16; },
    { tp="edit";  name="initfunc";  hist="InitFunc"; y1=""; x1=19; ext="lua"; },
    { tp="text";  text="Final co&de:"; width=16; },
    { tp="edit";  name="finalfunc"; hist="FinalFunc"; y1=""; x1=19; ext="lua"; },

    { tp="sep" },
    { tp="butt"; centergroup=1; text="Run"; default=1; },
    { tp="butt"; centergroup=1; text="Clear";  btnnoclose=1; name="clear"; },
    { tp="butt"; centergroup=1; text="Reload"; btnnoclose=1; name="reload"; },
    { tp="butt"; centergroup=1; text="Save";   btnnoclose=1; name="save"; },
    { tp="butt"; centergroup=1; text="Cancel"; cancel=1; },
  }

  local Dlg = sd.New(Items)
  local Pos, Elem = Dlg:Indexes()
  local RepFunc, InitFunc, FinalFunc -- make upvalues for dialog procedure for reusing later

  local function OnFuncModeChange(hDlg)
    local enb = hDlg:GetCheck(Pos.funcmode)
    for k=1,4 do
      hDlg:Enable(Pos.funcmode + k, enb)
    end
    Elem.replace.ext = (enb ~= 0) and "lua" or nil
  end

  local function OnRegexChange(hDlg)
    local enb = hDlg:GetCheck(Pos.regex)
    hDlg:Enable(Pos.extended, enb)
    hDlg:Enable(Pos.multiline, enb)
    hDlg:Enable(Pos.fileasline, enb)
    hDlg:Enable(Pos.funcmode, enb)
    if enb == 0 then
      hDlg:SetCheck(Pos.funcmode, 0)
    end
    OnFuncModeChange(hDlg)
  end

  local function ClearControls(hDlg)
    Dlg:ClearControls(hDlg)
    OnRegexChange(hDlg)
    hDlg:SetFocus(Pos.filemask)
  end

  local function ReloadControls(hDlg)
    Dlg:SetDialogState(hDlg, sett.mload(set_key, set_name) or {})
    OnRegexChange(hDlg)
    hDlg:SetFocus(Pos.filemask)
  end

  local function SaveControls(hDlg)
    sett.msave(set_key, set_name, Dlg:GetDialogState(hDlg))
    hDlg:SetFocus(Pos.filemask)
  end

  local function OnCloseDialog(hDlg, param1, out)
    if not far.CheckMask(out.filemask, "PN_SHOWERRORMESSAGE") then
      return 0
    end
    --------------------------------
    local patt = out.search
    if patt == "" or out.regex and not pcall(regex.new, patt) then
      far.Message("Invalid search string", "Search field error", nil, "w")
      return 0
    end
    --------------------------------
    if out.funcmode then
      local msg

      local str = "T = { [0]=select(1,...); select(2, ...) }\n" .. out.replace
      RepFunc, msg = loadstring(str)
      if not RepFunc then
        far.Message(msg, "Replace field error", nil, "w")
        return 0
      end

      InitFunc, msg = loadstring(out.initfunc)
      if not InitFunc then
        far.Message(msg, "Initial code error", nil, "w")
        return 0
      end

      FinalFunc, msg = loadstring(out.finalfunc)
      if not FinalFunc then
        far.Message(msg, "Final code error", nil, "w")
        return 0
      end
    end
  end

  Items.proc = function(hDlg, msg, param1, param2)
    if msg == F.DN_INITDIALOG then
      OnRegexChange(hDlg)
    elseif msg == F.DN_BTNCLICK then
      if param1 == Pos.regex then OnRegexChange(hDlg)
      elseif param1 == Pos.funcmode then OnFuncModeChange(hDlg)
      elseif param1 == Pos.clear  then ClearControls(hDlg)
      elseif param1 == Pos.reload then ReloadControls(hDlg)
      elseif param1 == Pos.save   then SaveControls(hDlg)
      end
    elseif msg == F.DN_CLOSE then
      return OnCloseDialog(hDlg, param1, param2)
    end
  end

  Dlg:LoadData(sett.mload(set_key, set_name) or {})
  local out = Dlg:Run()
  if out then
    --------------------------------
    sett.msave(set_key, set_name, out)
    --------------------------------
    out.initfunc, out.finalfunc = nil, nil
    if out.funcmode then
      out.env = setmetatable({ N1=0;N2=0;A1={};A2={}; }, {__index=_G})
      out.search = "("..out.search..")" -- make regex.gsub produce T[0]
      out.replace = setfenv(RepFunc, out.env)
      out.initfunc = setfenv(InitFunc, out.env)
      out.finalfunc = setfenv(FinalFunc, out.env)
    elseif out.regex then
      -- provide the expected meaning of \n, \r, etc.
      out.replace = out.replace:gsub("\\(.)", { a="\a"; e="\27"; f="\f"; n="\n"; r="\r"; t="\t"; })
      -- remove special meaning of % character
      out.replace = out.replace:gsub("%%", "%%%%")
      -- remove backslashes from the characters escaped with them
      -- and replace $0, $1, etc. with %0, %1, etc., as regex.gsub expects %
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


local n_total, n_changed
local function PleaseWait()
  local msg = ("%d/%d files modified. Please wait..."):format(n_changed, n_total)
  far.Message(msg, Title, "")
end


local function MessageAndWait(...)
  local res = far.Message(...)
  PleaseWait()
  return res
end


local function BreakQuery(fname, msg, title)
  msg = fname .."\n".. msg
  return MessageAndWait(msg, title, "&Continue;&Terminate", "w") ~= 1
end


local function AskForReplace(fname, src, trg)
  local color = libMessage.GetInvertedColor("COL_DIALOGTEXT")
  local msg = {
      fname, "\n",
      {separator=1, text=" Replace "},
      {text=src, color=color}, "\n",
      {separator=1, text=" with "},
      {text=trg, color=color},
  }
  local btns = "&Yes;Yes &for this file;Yes for &all files\n"
              .. "&Skip;Skip for &this file;&Cancel"

  local res = libMessage.Message(msg, Title, btns, "cl", nil,
      win.Uuid("CADC0532-6A02-42C9-94D9-6F9B3EDDA55E"))
  PleaseWait()
  return res
end


local function ReplaceInFile(item, fname, data, yes_to_all)
  if item.FileSize > MAX_SIZE then
    local msg = ("%s\nFile is too large (%.1f Mib)"):format(fname, item.FileSize/2^20)
    local ret = MessageAndWait(msg, Title, "&Skip;&Process anyway;&Terminate", "w")
    if     ret == 1 then return false, false
    elseif ret ~= 2 then return false, "cancel"
    end
  end

  local fp, msg = OpenFile(fname, "rb")
  if not fp then
    return false, BreakQuery(fname, msg, "Open for read") and "cancel"
  end

  -- Lua 5.1 and LuaJIT return nil on reading an empty file. Workaround that.
  local txt = (item.FileSize == 0) and "" or fp:read(item.FileSize)
  fp:close()

  -- Don't process some corner cases
  if not txt or #txt ~= item.FileSize then -- more processing is required
    return
  end

  -- Don't process files containing either \0 or invalid UTF-8 (it's by design).
  if string.find(txt,"%z") or not txt:isvalid() then
    return
  end

  -- env. variables for the current file processing
  local env = data.env
  local freplace = data.replace

  local file_yes, file_no = yes_to_all, false
  local cancel_all = false

  if data.funcmode then
    env.FN = fname            -- file name; as in LF Search
    env.M, env.R = 0, 0       -- counters of matches and replacements; as in LF Search
    env.item = item           -- access to file parameters
    env.n1, env.n2 = 0, 0     -- counters
    env.a1, env.a2 = {}, {}   -- tables

    freplace = function(...)
      env.M = env.M + 1
      if file_no then return end

      local val = data.replace(...)
      if not val then return end -- false value = no replace now

      local tp = type(val)
      if tp ~= "string" and tp ~= "number" then
        file_no = true -- true non-string non-number value = no further replaces
        return
      end

      local ret
      if not file_yes then
        ret = AskForReplace(fname, env.T[0], val)
        if     ret == 1 then  ret = ret
        elseif ret == 2 then  file_yes = true
        elseif ret == 3 then  file_yes, yes_to_all = true, true
        elseif ret == 4 then  ret = ret
        elseif ret == 5 then  file_no = true
        else                  file_no, cancel_all = true, true
        end
      end

      if file_yes or ret == 1 then
        env.R = env.R + 1
        return val
      end
    end
  end

  -- Do the main work.
  local txt2 = regex.gsub(txt, data.search, freplace, nil, data.cflags)

  local result = false
  if txt2 ~= txt then -- if something changed
    fp, msg = OpenFile(fname, "wb")
    if fp then
      fp:write(txt2)
      fp:close()
      result = true
    else
      if BreakQuery(fname, msg, "Open for write") then
        cancel_all = true
      end
    end
  end

  return result, (cancel_all and "cancel") or (yes_to_all and "all")
end


local function main()
  local data = GetData()
  if not data then return end

  if data.initfunc then
    data.initfunc()
  end

  local start_dir = panel.GetPanelDirectory(nil,1).Name
  n_total, n_changed = 0, 0
  local Ask = not data.funcmode
  local YesToAll = false
  local last_clock = Clock()

  PleaseWait()
  far.RecursiveSearch(start_dir, data.filemask,
    function(item, fullpath)
      if item.FileAttributes:find("[dejk]") then -- dir | reparse point | device_block | device_sock
        return
      end
      local ProcessFile = not Ask
      if Ask then
        -- ask user what to do
        local msg = ("File will be modified\n%s"):format(fullpath)
        local res = MessageAndWait(msg, Title, "&Modify;&All;&Skip;&Cancel")
        if     res == 1 then ProcessFile = true
        elseif res == 2 then ProcessFile,Ask = true,false
        elseif res == 3 then ProcessFile = false
        else return true
        end
      end
      if ProcessFile then
        -- process the file
        local mod, act = ReplaceInFile(item, fullpath, data, YesToAll)
        n_total = n_total + 1
        if mod then
          n_changed = n_changed + 1
        end
        if act == "cancel" then
          return true
        elseif act == "all" then
          YesToAll = true
        end
        -- check if the user pressed Esc
        local now = Clock()
        if now - last_clock >= 0.2 then
          last_clock = now
          if win.ExtractKey() == "ESCAPE" then
            if 1 == MessageAndWait("Break the operation?", Title, "Yes;No", "w") then
              return true
            end
          end
          PleaseWait()
        end
      end
    end,
    data.recurse and "FRS_RECUR" or 0)

  if data.finalfunc then
    data.finalfunc()
  end

  panel.RedrawPanel(nil,0)
  panel.RedrawPanel(nil,1)
  local msg = ("%d files processed\n%d files modified"):format(n_total, n_changed)
  far.Message(msg, Title)
end


if not Macro then main() return end

Macro {
  id="11986160-83AE-474D-9E85-D615A77AF658";
  description="SUPER Replace";
  area="Shell"; key="CtrlAltE";
  flags="NoPluginPanels"; sortpriority=5;
  action=function() main() end;
}
