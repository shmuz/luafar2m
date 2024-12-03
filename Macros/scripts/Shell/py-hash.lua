-- Started:                 <= 2016-01-19
-- Minimal Far 3 version:   3.0.3300
-- First published:         2016-01-19 (https://forum.farmanager.com/viewtopic.php?f=15&t=10017)
-- Ported to far2m:         2023-06-07
-- luacheck: globals python

local Config = {
  x86 = true;           -- specify any combination of bitnesses
  x64 = true;           -- +++
  key = "CtrlShiftF1";  -- key for calling this macro
}

do
  local arch = jit and jit.arch
                    or tostring({}):find(("%x"):rep(16)) and "x64" or "x86"
  if not Config[arch] then return end
end

local pyscript = [=[

def CalcHashes(filename):
    import hashlib
    from os.path import getsize
    import lua

    with open(filename,"rb") as f_src:
        select_hash_types = lua.eval("python._select_hash_types")
        display_progress = lua.eval("python._display_progress")

        # hlist = hashlib.algorithms_guaranteed
        hlist = hashlib.algorithms_available

        hlist = select_hash_types([name for name in hlist])
        if not hlist: return

        hlist = [hlist[idx] for idx in hlist]
        hashers = [hashlib.new(name) for name in hlist]

        CHUNK = 16 * 1024
        nLeft = nSize = getsize(filename)
        nDisplayCount = 0
        while nLeft > 0:
            buf = f_src.read(min(CHUNK, nLeft))
            nRead = len(buf)
            if nRead == 0: break
            for h in hashers: h.update(buf)
            nLeft -= nRead
            nDisplayCount += 1
            if nSize > 4*1024*1024 and nDisplayCount%201==1:
                if display_progress(filename, nSize-nLeft+0.0, nSize+0.0, 1.0-nLeft/nSize):
                    return
        res = []
        for name,h in zip(hlist,hashers):
            res.append(name)
            if name == "shake_128" or name == "shake_256":
                res.append(h.hexdigest(128))
            else:
                res.append(h.hexdigest())
        return res
]=]

local uchar = ("").char

local function set_progress (LEN, ratio)
  local uchar1, uchar2 = uchar(9608), uchar(9617)
  local len = math.floor(ratio*LEN + 0.5)
  return uchar1:rep(len) .. uchar2:rep(LEN-len) .. (" %3d%%"):format(ratio*100)
end

local function format_num(num)
  local s = tostring(num)
  local len = #s
  s = s:gsub("()", function(pos) return pos>1 and pos<len and (len-pos)%3==2 and "," end)
  return s
end

local function display_progress (fullname, cntFound, cntTotal, ratio)
  if win.ExtractKey()=="ESCAPE" then
    if 1 == far.Message("Break the operation?","Hashes","Yes;No","w") then
      far.AdvControl("ACTL_REDRAWALL"); return true
    end
  end
  local WID, W1 = 60, 3
  local W2 = WID - W1 - 3
  local len = fullname:len()
  local fname = len<=WID and fullname..(" "):rep(WID-len)
                          or fullname:sub(1,W1).. "..." .. fullname:sub(-W2)
  local msg = ("%s\n%s\nProcessed: %s/%s"):format(
    fname, set_progress(W2,ratio), format_num(cntFound), format_num(cntTotal))
  far.Message(msg, "Calculating file hashes...", "")
end

local function select_hash_types (list)
  local sDialog = require("far2.simpledialog")
  local arr = {}
  for i=1,math.huge do -- convert userdata to Lua table (for sorting)
    local hash = list[i-1]
    if not hash then break end
    arr[i] = hash
  end
  table.sort(arr)

  local Items = {
    width=40;
    {tp="dbox"; text="Select hashes"; },
  }
  for i,v in ipairs(arr) do
    table.insert( Items, {tp="chbox"; text=v; name=i; } )
  end
  table.insert(Items, {tp="sep"; })
  table.insert(Items, {tp="butt"; text="OK",    default=1; centergroup=1; })
  table.insert(Items, {tp="butt"; text="Cancel", cancel=1; centergroup=1; })
  local out = sDialog.New(Items):Run()
  if out then
    local arr2 = {}
    for i=1,#arr do
      if out[i] then table.insert(arr2, arr[i]) end
    end
    if next(arr2) then
      return arr2
    end
  end
end

local function GetHashes()
  local sDialog = require("far2.simpledialog")

  -- Preparations --
  python._display_progress = display_progress
  python._select_hash_types = select_hash_types
  python.execute(pyscript)
  local CalcHashes = python.eval("CalcHashes") -- returns a Lua function
  local fname = panel.GetCurrentPanelItem(nil,1).FileName
  local fullname = fname:find("/") and fname or win.JoinPath(panel.GetPanelDirectory(nil,1).Name, fname)
  if not win.GetFileAttr(fullname) then return end

  -- Execution --
  local pylist = CalcHashes(fullname) -- returns a Python List represented as a Lua userdata
  if not pylist then return end

  -- Showing the results --
  local pb = python.builtins()
  local names, hashes, nums = {}, {}, {}
  local maxlen = 0
  for k=1,pb.len(pylist)/2 do
    nums  [k] = k
    names [k] = pylist[2*k-2] -- Python List is indexed from 0
    hashes[k] = pylist[2*k-1]
    maxlen = math.max(maxlen, names[k]:len())
  end
  table.sort(nums, function(a,b) return far.LStricmp(names[a], names[b]) < 0 end)

  local rect = far.AdvControl("ACTL_GETFARRECT")
  local items = {
    guid = "3417EE88-021E-4BEC-9F46-E3EF8FE8CBE9";
    width = math.min(100, rect.Right - rect.Left + 1);
    {tp="dbox"; text=fname}
  }
  for i,v in ipairs(nums) do
    items[2*i]   = {tp="text"; val=names[v]}
    items[2*i+1] = {tp="edit"; val=hashes[v];  ystep=0; x1=6+maxlen; readonly=1; selectonentry=1}
  end
  items[#items+1] = {tp="sep"}
  items[#items+1] = {tp="butt"; default=1; centergroup=1; text="OK"}
  sDialog.New(items):Run()
end

Macro {
  id="EEAA0BC3-3567-43D5-A0C7-64E41ED917C3";
  id="1D7F9269-56BC-4402-9C0B-1B69F33B7D65";
  description="Lunatic Python - HASHES";
  area="Shell"; key=Config.key;
  flags="NoFolders";
  action=GetHashes;
  -- The condition function is not used here for its intended purpose; rather we take
  -- advantage of the fact that lua_State here is "main" (not that of a coroutine)
  condition = function()
    local ok
    ok, _G.python = pcall(require, "python")
    return ok
  end;
}
