local Info = Info or package.loaded.regscript or function(...) return ... end --luacheck: ignore 113/Info
local nfo = Info { _filename or ...,
  name        = "MacroEx"; --запуск макросов нетрадиционными способами
  description = "launching macros in unconventional ways";
  version     = "3.2.1";
  author      = "jd";
  url         = "http://forum.farmanager.com/viewtopic.php?f=15&t=8764";
  id          = "115C9534-8273-4F5A-94EB-E321D6DC8618";
  minfarversion = {3,0,0,5553,0}; --FreeScreen

  options     = {
    break_sequence_on_mod_release = true,
    Delay = 300,
    SeqDelay = 1000,
    dbg = false,
  };
  --disabled=true;
}
if not nfo or nfo.disabled then return end
local O = nfo.options

local F = far.Flags

local function errmsg(msg,...)
  local msg2 = msg.."\n\2"..debug.traceback("",2):gsub("\t","   ")
  local buttons = select('#',...)>0 and "Ok;&Lua explorer" or "Ok"
  repeat
    local a = far.Message(msg2,"MacroEx: error in macro definition",buttons,"wl")
    if a==2 then
      require"far2.lua_explorer"({...},msg) --to view args
    end
  until a~=2
end

local killAutorepeat,isHolding do
  local norepeat
  Event { description="MacroEx helper";
    group="ConsoleInput";
    action=function(Rec)
      if norepeat and Rec.EventType==F.KEY_EVENT and Rec.VirtualKeyCode~=0 then -- KEY_NONE? Rec.VirtualKeyCode==0
        if Rec.VirtualKeyCode==norepeat and Rec.KeyDown then
          return 1 -- eat repetitions
        else
          norepeat = false
        end
      end
    end;
  }
  function killAutorepeat(vk)
    norepeat = vk
  end
  function isHolding(vk)
    return norepeat==vk
  end
end

local function isReleased(Mod) return band(Mouse.LastCtrlState,Mod)==0 end -- State after last mf.waitkey!!

local C = far.Colors
local Color = far.AdvControl(F.ACTL_GETCOLOR,C.COL_MENUHIGHLIGHT) --C.COL_MENUTITLE
local function setStatus(text,color)
  if text and type(text)=="string" then
    far.Text(1,0,color," "..text.." ")
    far.Text()
  end
end

local function getSeqHelp(key) --?? premake help or store macros
  local help = {}
  local area_re = "%f[%a]"..Area.Current:lower().."%f[%A]"
  local key_re = "%f[%a]"..key:lower().."%-"
  for i=1,math.huge do
    local m = mf.GetMacroCopy(i)
    if not m then break end
    if m.key and not m.keyregex then --?? use GetMacro
      if string.match(m.key:lower(),key_re) then
        if (m.area=="common" or string.find(m.area:lower(),area_re))
           and not m.disabled
           --?? checkFlags, CheckFileName
           and (not m.condition or m.condition(key)) then --?? pcall
          table.insert(help,m.description or m.key)
        end
      end
    end
  end
  return next(help) and table.concat(help,"\n")
end

local function runMacro(key,Ex) return mf.eval(key..Ex,2)~=-2 end
local function runMacroOrKey(key)
  if mf.eval(key,2)==-2 then
    -- Enable output is required to handle this known cases:
    -- * CtrlO in Editor/Viewer (but better CtrlO handling is recommended)
    --   https://forum.farmanager.com/viewtopic.php?f=15&t=10983
    -- * Show progress of Far operations, such as F3/CtrlQ in Shell
    -- * For some operations, such as copy on F5 and Tree building on CtrlT this is critical,
    --   otherwise it's even impossible to interrupt them with Esc/CtrlBreak:
    --   https://bugs.farmanager.com/view.php?id=579
    mf.Keys("EnOut",key)
  end
end

local modmask = bit64.bor(F.LEFT_ALT_PRESSED,F.RIGHT_ALT_PRESSED,F.LEFT_CTRL_PRESSED,F.RIGHT_CTRL_PRESSED,F.SHIFT_PRESSED)
local Macro,FileName = Macro,...
local function setHandler(mkey,AKey,modslen,m)
  local r = far.NameToInputRecord(AKey)
  if not r then
    if O.dbg then errmsg(("Unexpected AKey: %q"):format(AKey),m) end
    return
  end
  local mod = band(r.ControlKeyState,modmask)
  --todo xmod ??no mod
  if mod==0 then
    if O.dbg then errmsg(("Unexpected ControlKeyState in %q: %q"):format(AKey,r.ControlKeyState),r) end
    return
  end
  if AKey:match"r?ctrlnumlock" then r = far.NameToInputRecord"Pause" end  --http://bugs.farmanager.com/view.php?id=2947
  local base_vk = r.VirtualKeyCode
  -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
  local k = {double={},hold={},sequence={},priority={}}--,mod={},
  local locked --to disable handler in order to run original macro
  Macro {
    description=("MacroEx handler for %q"):format(mkey);
    area="Common"; key=mkey; id=mkey; FileName=FileName;
    condition=function()
      return not locked and (k.priority[Area.Current:lower()] or k.priority.common)
    end;
    action=function()
      if isHolding(base_vk) then return end --prevent autorepeat
      killAutorepeat(base_vk)
      local area = Area.Current:lower()
      local has_double   = k.double[area] or k.double.common --?? inheritance (Autocompletion,Search)
      local has_hold     = k.hold[area]    or k.hold.common
      local has_sequence = k.sequence[area] or k.sequence.common
      --local is_mod       = k.mod[area] or k.mod.common --todo xmod
      local key = ""
      local timeout
    -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
      local start = Far.UpTime
      while not (timeout or key~="" or isReleased(mod)) do
        key = mf.waitkey(10)
        timeout = Far.UpTime-start>O.Delay
      end
      if timeout then
        if has_hold and isHolding(base_vk) then
          if runMacro(AKey,":Hold") then return end
        end
      elseif has_double and key:lower()==AKey then
        killAutorepeat(base_vk)
        if runMacro(AKey,":Double") then return end
      end
    -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
      if has_sequence then
        AKey = mf.akey(1,1) --ctrlaltshiftkey->CtrlAltShiftKey --todo (match)
        local h = far.SaveScreen()
        setStatus(AKey,Color)
        local endkey = ("^%s(.+)"):format(AKey:sub(1,modslen))
        local help
        while not(O.break_sequence_on_mod_release and isReleased(mod)) do
          if key~="" then
            far.RestoreScreen(h)
            local key2 = key:match(endkey)
            key2 = key2~="" and key2 or key --false==break_sequence_on_mod_release
            if runMacro(AKey,"-"..key2) then return else timeout = true end --set timeout var to prevent key post..
            far.FreeScreen(h); h = nil; break
          end
          key = mf.waitkey(10)
          if not help and Far.UpTime-start>O.SeqDelay then
            timeout = true
            help = getSeqHelp(AKey)
            if not help then break end
            far.Message(help,AKey,"","l")
          end
        end
        if h then far.RestoreScreen(h) end
      end
    -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
      if not timeout then
        locked = true
        runMacroOrKey(AKey) --??mf.akey(1,0)
        if key~="" then runMacroOrKey(key) end
        locked = false
        return
      end

      setStatus("unassigned",Color) --http://forum.farmanager.com/viewtopic.php?p=131249#p131249
--    mf.beep() -- not implemented in far2m
      win.Sleep(100)
    end;
  }
  return k
end

local parse = regex.new"^(?:([rl]?)ctrl)?(?:([rl]?)alt)?(shift)?(.+)$"
local function expandKey(key,callback)
  --assert(key:match"^%l+$")
  local c1,a1,shift,base_key = parse:match(key)
  if not base_key or base_key=="" then
    if O.dbg then errmsg(("Unable to parse key %q"):format(key),c1,a1,shift,base_key) end
    return
  end
  local c = c1=="" and "l"
  repeat
    local a = a1=="" and "l"
    repeat
      callback(c or c1,a or a1,shift,base_key) --
      a = a=="l" and "r"
    until not a
    c = c=="l" and "r"
  until not c
end

local function concat(c1,a1,shift,key)
  return (c1 and c1.."ctrl" or "")..(a1 and a1.."alt" or "")..(shift or "")..(key or "")
end

local Valid = {["hold"]=1,["double"]=1}
mf.postmacro(function()
  local handlers = {}
  for i=1,math.huge do
    local m = mf.GetMacroCopy(i)
    if not m then break end
    if m.key and not m.keyregex then
      local UniqKeys = {}
      for Key in m.key:lower():gmatch"%S+" do
        if not UniqKeys[Key] then --prevent multiple inclusions
          UniqKeys[Key] = true
          local key,Ex = Key:match"^(.+):(.+)$"
          if Ex and not Valid[Ex] then key = false end
          if not key then key,Ex = Key:match"^(.+)%-.","sequence" end
          --if not key then key,Ex = Key:match"^.+%+.+$","xmod" end --todo
          if key then expandKey(key,function(c,a,shift,base_key)
            local mkey = concat(c,a,shift,base_key)
            local k = handlers[mkey]
            if not k then --register hotkey's handler
              local fkey = concat(c=="l" and "" or c,a=="l" and "" or a,shift,base_key)
              k = setHandler(mkey,fkey,fkey:len()-base_key:len(),m)
              handlers[mkey] = k
            end
            --calculate handler's priority by area --??use GetMacro??
            if k then
              local UniqAreas = {}
              for area in m.area:lower():gmatch"%S+" do
                if not UniqAreas[area] then --prevent multiple inclusions
                  UniqAreas[area] = true
                  k[Ex][area] = true
                  k.priority[area] = math.max(k.priority[area] or 0, (m.priority or 50)+5)
                  -- -- --
                  m[Ex] = true
                  --m.base_key = base_key --debug
                  --table.insert(k,m)     --debug
                end
              end
            end
          end)
          end
        end
      end
    end
  end
 --le(handlers) --debug
end)
