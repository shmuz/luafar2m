-- Started: on or earlier than 2014-07-30 (the date of initial import to SVN repository).

-- settings --------------------------------------------------------------------
local Editor_FileName
local Message_Title
local ProgressBar_MinFileSize = 50e6
local ProgressBar_Length = 40
-- /settings -------------------------------------------------------------------

local F = far.Flags
local char = ("").char
local band = bit64.band

local function create_callback(aCurr, aCount, aFname)
  local title = ("%s: %d/%d"):format(Message_Title, aCurr, aCount)
  if aFname:len() > ProgressBar_Length + 5 then
    aFname = "..."..aFname:sub(-(ProgressBar_Length+2))
  end
  return function (progress)
    local len = math.floor(progress*ProgressBar_Length + 0.5)
    local text = char(9608):rep(len) .. char(9617):rep(ProgressBar_Length-len)
    text = ("%s\n%s %3d%%"):format(aFname, text, progress*100)
    far.Message(text, title, "", "l")
  end
end

local function sha1_sum(fname, callback)
  local crypto = require "crypto"
  local fp = assert(io.open(fname, "rb"))
  local chunk = 0x10000 -- must be multiple of 64 bytes
  local state = ""
  local nbytes, N = 0, 0
  local data = fp:read(chunk) or "" -- prevent nil here
  while data do
    state = crypto.sha1(data, state)
    if callback then
      nbytes = nbytes + #data
      N = (N + 1) % 32 -- call back every 32 chunks (2 MiB)
      if N == 1 and callback(nbytes) then
        fp:close(); return nil
      end
    end
    data = fp:read(chunk)
  end
  if state:find(" ") then
    state = crypto.sha1("", state)
  end
  fp:close()
  return state
end

local function Work()
  local panelInfo = panel.GetPanelInfo(1)
  if not panelInfo then return end

  local filelist = {}
  local hasSelection = false
  for i=1,panelInfo.ItemsNumber do
    local item = panel.GetPanelItem(1,i)
    if 0~=band(item.Flags,F.PPIF_SELECTED) then
      hasSelection = true
      if not item.FileAttributes:find"d" then
        item.Index = i
        table.insert(filelist, item)
      end
    end
  end
  if not hasSelection then
    local item = panel.GetCurrentPanelItem(1)
    if not item.FileAttributes:find("d") then
      table.insert(filelist, item)
    end
  end
  if not filelist[1] then return end

  --local ret = far.Message("Select hash type", "Hash type", "&MD5;&SHA1")
  local ret = 1
  local hashtype = ret==1 and "md5" or ret==2 and "sha1"
  if hashtype == "md5" then
    Editor_FileName, Message_Title = "hashes.md5", "md5 hash"
  elseif hashtype == "sha1" then
    Editor_FileName, Message_Title = "hashes.sha1", "sha1 hash"
  else
    return
  end

  local count = #filelist
  for i,item in ipairs(filelist) do
    local fname = item.FileName
    if not fname:find("[\\/]") then
      local dir = assert(panel.GetPanelDirectory(1))
      fname = (dir:find("[\\/]$") and dir or dir.."/") .. fname
    end
    item.FullName = fname
    local set_progress = create_callback(i, count, item.FileName)
    local callback = (item.FileSize >= ProgressBar_MinFileSize) and
      function(n)
        set_progress(n / item.FileSize)
        return win.ExtractKey()=="ESCAPE" -- return mf.waitkey(1)=="Esc"
      end
    set_progress(0)
    if hashtype == "md5" then
      local md5 = require "md5ex"
      local hash, status = md5.fsum(fname,nil,nil,callback,0x200000) -- call back every 2 MiB
      if status then item.Hash = md5.tohex(hash) end
    else -- "sha1"
      local hash = sha1_sum(fname, callback)
      item.Hash = hash and string.lower(hash)
    end
    if win.ExtractKey()=="ESCAPE" then break end
  end

  local selected, msg = {}, {}
  for _,item in ipairs(filelist) do
    if item.Hash then
      selected[#selected+1] = item.Index
      local shortname = item.FullName:match("[^\\/]+$")
      msg[#msg+1] = item.Hash.." *"..shortname
    end
  end

  if selected[1] then
    panel.SetSelection (1,selected,false)
    panel.RedrawPanel(1)
  end
  far.AdvControl("ACTL_REDRAWALL")

  if msg[1] then
    table.sort(msg)
    local items = {}
    for k,v in ipairs(msg) do items[k]={text=v} end
    local r = far.AdvControl("ACTL_GETFARRECT")
    local item = far.Menu(
      { Title = ("%s - %d file%s"):format(Message_Title,#msg,#msg==1 and "" or "s"),
        Bottom = "CtrlC - Copy, F4 - Editor",
        MaxHeight = r and (r.Bottom - r.Top + 1 - 10),
      },
      items,
      { {BreakKey="CONTROL+C"},{BreakKey="F4"} })
    if item then
      if item.BreakKey=="CONTROL+C" then
        msg[#msg+1] = ""
        far.CopyToClipboard(table.concat(msg,"\r\n"))
      elseif item.BreakKey=="F4" then
        editor.Editor(Editor_FileName,nil,nil,nil,nil,nil,
          {EF_CREATENEW=1,EF_NONMODAL=1,EF_IMMEDIATERETURN=1},nil,nil,65001)
        editor.SetPosition(1,1)
        editor.InsertText(table.concat(msg,"\r"))
        editor.InsertString()
      end
    end
  else
    far.Message("No hash is available", Message_Title)
  end
end

if Macro then
  Macro {
    description="Calculate MD5 or SHA1 hash for selected files";
    area="Shell"; key="CtrlAltH"; action=Work;
  }
else
  AddCommand("hashes", Work)
end
