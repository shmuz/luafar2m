-- Started      : 2025-11-27

local MAX_SIZE = 2 ^ 27 -- (128 MiB) skip files larger than this value

-- far2m / far3 compatibility
local OpenFile = win.OpenFile or io.open --luacheck:ignore
local Clock = win.Clock or function() return far.FarClock()/1e6 end --luacheck:ignore
local DirSep = package.config:sub(1,1)

local F = far.Flags
local sd = require "far2.simpledialog"
local sett = mf or require "far2.settings"
local libMessage = require "far2.message"
local set_key, set_name = "temp", "Replace_EX"
local Title = "Replace in files"


local function transform_repl(repl)
  local pos, idx, acc = 1, 0, { max_bracket = 0; }

  local add_string = function(str)
    if type(acc[idx])  == "string" then
      acc[idx] = acc[idx] .. str
    else
      idx = idx + 1
      acc[idx] = str
    end
  end

  repl = repl:gsub("\\(.)", { ["\\"]="\\"; a="\a"; e="\27"; f="\f"; n="\n"; r="\r"; t="\t"; })

  while true do
    local from, to, cap = repl:find("%$(.?)", pos)
    if from then
      add_string(repl:sub(pos, from-1))
      if cap:match("[0-9A-Za-z]") then
        idx = idx + 1
        acc[idx] = tonumber(cap, 36) -- 36 corresponds to [0-9A-Za-z]
        acc.max_bracket = math.max(acc.max_bracket, acc[idx])
      else
        add_string(cap)
      end
      pos = to + 1
    else
      add_string(repl:sub(pos))
      return acc
    end
  end
end


local function GetDataFromDialog()
  local W = 35
  local Items = {
    guid = "E2661CE3-04DA-4106-A496-250C3924A331";
    -- help = "Contents";
    width = 2 * (W + 3);
    { tp="dbox";  text="Replace EX"; },

    { tp="chbox"; name="recurse"; text="&Recursively"; x1=W+5; },
    { tp="text";  text="&File mask:"; y1=""; width=W; },
    { tp="edit";  name="filemask"; hist="Masks"; focus=1; },

    { tp="chbox"; name="dest_enable"; text="Destination &path:"; },
    { tp="edit";  name="dest_path"; hist="RepExDestPath"; },

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
  local OutTable

  local function OnDestEnableChange(hDlg, btn_click)
    local enb = hDlg:GetCheck(Pos.dest_enable)
    hDlg:Enable(Pos.dest_path, enb)
    if btn_click then
      hDlg:SetFocus(enb ~= 0 and Pos.dest_path or Pos.search)
    end
  end

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
    -- store 'out' for reusing on exit
    OutTable = out

    -- check mask
    if not far.CheckMask(out.filemask, "PN_SHOWERRORMESSAGE") then
      return 0
    end

    -- check if search string is empty
    if out.search == "" then
      far.Message("Empty search string", "Search field error", nil, "w");
      return 0
    end

    -- set cflags
    out.cflags = out.casesens and "" or "i"
    if out.regex then
      if out.extended   then out.cflags = out.cflags.."x" end
      if out.multiline  then out.cflags = out.cflags.."m" end
      if out.fileasline then out.cflags = out.cflags.."s" end
    end

    -- (1) process search pattern
    if out.regex then
      out.search = "("..out.search..")" -- make gsub produce T[0]
    else
      out.search = out.search:gsub("%p", "\\%0")
    end

    -- (2) process search pattern
    if out.wholewords then
      out.search = "\\b"..out.search.."\\b"
    end

    -- (3) process search pattern
    local ok, patt = pcall(regex.new, out.search, out.cflags)
    if ok then
      out.search = patt
    else
      far.Message(patt, "Search field error", nil, "w")
      return 0
    end

    -- process replace pattern versus search pattern
    if not out.funcmode then
      out.trepl = transform_repl(out.replace)
      local m, n = out.trepl.max_bracket, out.search:bracketscount() - 1
      if m > n or (m == n and m ~= 1) then
        far.Message("Invalid group number $"..m, "Replace field error", nil, "w")
        return 0
      end
    end

    -- process function mode
    if out.funcmode then
      local str = "T = { [0]=select(1,...); select(2, ...) }\n" .. out.replace
      local RepFunc, msg1 = loadstring(str)
      if not RepFunc then
        far.Message(msg1, "Replace field error", nil, "w")
        return 0
      end

      local InitFunc, msg2 = loadstring(out.initfunc)
      if not InitFunc then
        far.Message(msg2, "Initial code error", nil, "w")
        return 0
      end

      local FinalFunc, msg3 = loadstring(out.finalfunc)
      if not FinalFunc then
        far.Message(msg3, "Final code error", nil, "w")
        return 0
      end

      out.env = setmetatable({ N1=0;N2=0;A1={};A2={}; }, {__index=_G})
      out.replace = setfenv(RepFunc, out.env)
      out.initfunc = setfenv(InitFunc, out.env)
      out.finalfunc = setfenv(FinalFunc, out.env)
    else
      out.initfunc, out.finalfunc = nil, nil
    end
  end

  Items.proc = function(hDlg, msg, param1, param2)
    if msg == F.DN_INITDIALOG then
      OnDestEnableChange(hDlg, false)
      OnRegexChange(hDlg)
    elseif msg == F.DN_BTNCLICK then
      if param1 == Pos.regex then OnRegexChange(hDlg)
      elseif param1 == Pos.dest_enable then OnDestEnableChange(hDlg, true)
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
    sett.msave(set_key, set_name, out)
    return OutTable
  end
end


local Maker = {}
local MakerMeta = { __index=Maker; }

local function NewMaker(delta)
  local obj = {
    delta = delta;
    last = delta;
    n_total = 0;
    n_changed = 0;
  }
  return setmetatable(obj, MakerMeta)
end


function Maker:PleaseWait()
  local msg = ("%d/%d files modified. Please wait..."):format(self.n_changed, self.n_total)
  far.Message(msg, Title, "")
end


function Maker:MessageAndWait(...)
  local res = far.Message(...)
  self:PleaseWait()
  return res
end


function Maker:BreakQuery(fname, msg, title)
  msg = fname .."\n".. msg
  return self:MessageAndWait(msg, title, "&Continue;&Terminate", "w") ~= 1
end


-- return values of AskForReplace()
local YES_NOW, YES_FILE, YES_ALL, SKIP_NOW, SKIP_FILE, SKIP_ALL = 1,2,3,4,5,6

function Maker:AskForReplace(fname, src, trg)
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
  self:PleaseWait()
  return res
end


local function GetDestFileName(fname, dest_path, rel_path)
  local full_path = win.JoinPath(dest_path, rel_path)
  local dir = full_path:match("^.*" .. DirSep)
  if dir then
    win.CreateDir(dir)
  end
  return full_path
end


function Maker:ReplaceInFile(item, data, yes_to_all)
  local fname = item.FullPath

  if item.FileSize > MAX_SIZE then
    local msg = ("%s\nFile is too large (%.1f Mib)"):format(fname, item.FileSize/2^20)
    local ret = self:MessageAndWait(msg, Title, "&Skip;&Process anyway;&Terminate", "w")
    if     ret == 1 then return false, false
    elseif ret ~= 2 then return false, "cancel"
    end
  end

  local fp, msg = OpenFile(fname, "rb")
  if not fp then
    return false, self:BreakQuery(fname, msg, "Open for read") and "cancel"
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

  local br_count = data.search:bracketscount()
  local insert = table.insert

  local file_yes = yes_to_all
  local file_no = false
  local cancel_all = false

  local env = data.env or {} -- env. variables for the current file processing
  env.FN = fname             -- file name; as in LF Search
  env.M, env.R = 0, 0        -- counters of matches and replacements; as in LF Search
  env.item = item            -- access to file parameters
  env.n1, env.n2 = 0, 0      -- counters
  env.a1, env.a2 = {}, {}    -- tables

  local function freplace(...)
    env.M = env.M + 1
    if file_no then return end

    local caps = {...}
    local val
    if data.funcmode then
      val = data.replace(...)
      if val then
        local tp = type(val)
        if tp ~= "string" and tp ~= "number" then
          file_no = true -- true non-string non-number value = no further replaces
          return
        end
      else
        return -- false value = no replace now
      end
    else
      local cur_rep = {}
      for _,v in ipairs(data.trepl) do
        if type(v) == "string" then
          insert(cur_rep, v)
        elseif v == 0 or (v == 1 and br_count == 2) then
          insert(cur_rep, caps[1])
        elseif caps[v+1] then
          insert(cur_rep, caps[v+1])
        end
      end
      val = table.concat(cur_rep)
    end

    local ret = SKIP_ALL
    if not file_yes then
      ret = self:AskForReplace(fname, caps[1], val)
      if     ret == YES_NOW   then  ret = ret
      elseif ret == YES_FILE  then  file_yes = true
      elseif ret == YES_ALL   then  file_yes, yes_to_all = true, true
      elseif ret == SKIP_NOW  then  ret = ret
      elseif ret == SKIP_FILE then  file_no = true
      else                          file_no, cancel_all = true, true
      end
    end

    if file_yes or ret == YES_NOW then
      env.R = env.R + 1
      return val
    end
  end

  -- Do the main work.
  local txt2 = data.search:gsub(txt, freplace)

  local result = false

  if (not cancel_all) and (txt2 ~= txt) then -- not canceled and text changed
    local destname = fname
    if data.dest_enable then
      destname = GetDestFileName(fname, data.dest_path, item.RelPath)
    end
    fp, msg = OpenFile(destname, "wb")
    if fp then
      fp:write(txt2)
      fp:close()
      result = true
    else
      if self:BreakQuery(destname, msg, "Open for write") then
        cancel_all = true
      end
    end
  end

  return result, (cancel_all and "cancel") or (yes_to_all and "all")
end


function Maker:CheckForEscape(obj)
  local now = Clock()
  if now > self.last then
    if win.ExtractKey() == "ESCAPE" then
      if 1 == self:MessageAndWait("Break the operation?", Title, "Yes;No", "w") then
        return true
      end
      now = Clock()
    end
    self.last = now + self.delta
    self:PleaseWait()
  end
end


local function main()
  local data = GetDataFromDialog()
  if not data then return end

  if data.initfunc then
    data.initfunc()
  end

  local userbreak
  local start_dir = panel.GetPanelDirectory(nil,1).Name
  local start_dir_len = start_dir:len()
  local obj = NewMaker(0.2)

  -- 1-st stage: collect files (prevents picking up files created by this utility)
  local Files = {}
  far.RecursiveSearch(start_dir, data.filemask,
    function(item, fullpath)
      if not item.FileAttributes:find("[dejk]") then -- dir | reparse point | device_block | device_sock
        item.FullPath = fullpath
        item.RelPath = fullpath:sub(start_dir_len + 1):gsub("^"..DirSep, "") -- remove leading slash if any
        table.insert(Files, item)
      end
      if obj:CheckForEscape() then
        userbreak = true
        return true
      end
    end,
    data.recurse and "FRS_RECUR" or 0)

  if userbreak then
    far.Message("User break. No changes were made.", Title)
    return
  end

  data.dest_path = far.ConvertPath(data.dest_path, "CPM_FULL") -- necessary for far3
  local YesToAll = false

  -- 2-nd stage: process collected files
  obj:PleaseWait()
  for _, item in ipairs(Files) do
    local mod, act = obj:ReplaceInFile(item, data, YesToAll)
    obj.n_total = obj.n_total + 1
    if mod then
      obj.n_changed = obj.n_changed + 1
    end
    if act == "cancel" then
      return true
    elseif act == "all" then
      YesToAll = true
    end

    if obj:CheckForEscape() then
      break
    end
  end

  if data.finalfunc then
    data.finalfunc()
  end

  panel.RedrawPanel(nil,0)
  panel.RedrawPanel(nil,1)
  local msg = ("%d files processed\n%d files modified"):format(obj.n_total, obj.n_changed)
  far.Message(msg, Title)
end


if select(1, ...) == "test" then
  return {
    transform_repl = transform_repl;
  }
end

if not Macro then
  main()
  return
end

Macro {
  id="11986160-83AE-474D-9E85-D615A77AF658";
  description="SUPER Replace";
  area="Shell"; key="CtrlAltE";
  flags="NoPluginPanels"; sortpriority=5;
  action=function() main() end;
}
