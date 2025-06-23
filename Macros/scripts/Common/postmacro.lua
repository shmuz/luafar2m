------------------------------------------------------------------------------------------------
-- Started:                 2015-11-23
-- Author:                  Shmuel Zeigerman
-- Published:               2015-11-24 (https://forum.farmanager.com/viewtopic.php?f=60&t=9940)
-- Language:                Lua 5.1
-- Portability:             far3 (>= 3777), far2m
-- Far plugin:              LuaMacro
-- Dependencies:            Lua module far2.simpledialog
------------------------------------------------------------------------------------------------

local MacroKey = "CtrlShiftM"
local LE       = "far2.lua_explorer"
local Title    = "Post macro"
local DlgGuid  = "2C4EFD54-A419-47E5-99B6-C9FD2D386AEC"
local HelpGuid = "59154DF0-40D8-495C-BDF2-B97803745D8F"
local DB_Key   = "shmuz"
local DB_Name  = "Post macro"
local osWindows = package.config:sub(1,1) == "\\"
local F = far.Flags
local SendMsg = far.SendDlgMessage

-- Options
local DefaultOpt = {
  lang = "lua";   -- "lua" or "moonscript"
  reuse = false;  -- true: reuse environment
  loop = false;   -- true: call the dialog again after the macro execution is finished
}

local GetPanelInfo = function(whatPanel)
  return panel.GetPanelInfo(nil, whatPanel)
end

local ExpandEnv
if osWindows then
  local build = select(4, far.AdvControl("ACTL_GETFARMANAGERVERSION",true))
  if build < 3777 then return end
  ExpandEnv = function(aStr) return (aStr:gsub("%%(.-)%%", win.GetEnv)) end
else
  ExpandEnv = win.ExpandEnv
end

local Env = {}

local Help = [[
Controls:
  Sequence   - either Lua/MoonScript chunk or @<filename>
               if it begins with an '=' then far.Show is called on it
               if it begins with an '>' then Lua Explorer is called on it
  Parameters - comma separated list of Lua/MoonScript expressions
  [x] Reuse environment - use the previous Lua environment for the new run
  [x] Loop this dialog  - call this dialog again after the execution

Preset "global" variables:
  F       = far.Flags
  Message = far.Message
  Show    = far.Show
  WI      = far.AdvControl("ACTL_GETWINDOWINFO") -- window info
  API     = panel.GetPanelInfo(nil,1)            -- active panel info
  PPI     = panel.GetPanelInfo(nil,0)            -- passive panel info
  EI      = editor.GetInfo()                     -- editor info
  VI      = viewer.GetInfo()                     -- viewer info
  Cnt     = automatic counter of runs in the current Lua environment]]

local function GetText (aOpt)
  local sDialog = require ("far2.simpledialog")
  local edtFlags = F.DIF_HISTORY + F.DIF_USELASTHISTORY + F.DIF_MANUALADDHISTORY
  local Items =
  {
    guid = DlgGuid;
    width = 76;
    {tp="dbox"; text=Title;                                                  };
    {tp="text"; text="&Sequence:";                                           };
    {tp="edit"; hist="PostMacroSequence"; flags=edtFlags;   name="sequence"; };
    {tp="text"; text="&Parameters:";                                         };
    {tp="edit"; hist="PostMacroParams";   flags=edtFlags;   name="params";   };
    {tp="rbutt"; group=1; text="&Lua"; ystep=2;              name="lua";     };
    {tp="rbutt"; text="&MoonScript";                         name="moon";    };
    {tp="chbox"; x1=35; text="&Reuse environment"; ystep=-1; name="reuse";   };
    {tp="chbox"; x1=""; text="Loop this &dialog";            name="loop";    };
    {tp="sep";  ystep=2;                                                     };
    {tp="butt"; text="OK";     default=1; centergroup=1;                     };
    {tp="butt"; text="Cancel"; cancel=1;  centergroup=1;                     };
  }

  local dlg = sDialog.New(Items)
  local Pos, Elem = dlg:Indexes()
  Elem.lua.val   = aOpt.lang~="moonscript"
  Elem.moon.val  = aOpt.lang=="moonscript"
  Elem.reuse.val = aOpt.reuse
  Elem.loop.val  = aOpt.loop

  Items.help = function()
    far.Message(Help, Title.." HELP", nil, "l", nil, win.Uuid(HelpGuid))
  end

  local function set_ext(hDlg)
    local ext = SendMsg(hDlg, "DM_GETCHECK", Pos.moon)==F.BSTATE_CHECKED and "moon" or "lua"
    Elem.sequence.ext, Elem.params.ext = ext, ext
  end

  local f, f2, msg
  local function closeaction (hDlg, Param1, tOut)
    local ms = tOut.moon and require "moonscript"
    local loadstring, loadfile = (ms or _G).loadstring, (ms or _G).loadfile
    local seq = tOut.sequence
    if seq:find("^@") then
      local fname = ExpandEnv(tOut.sequence:sub(2))
      fname  = far.ConvertPath(fname, "CPM_NATIVE") or fname
      f, msg = loadfile(fname)
    else
      if seq:find("^=") then
        seq = "far.Show("..seq:sub(2)..")"
      elseif seq:find("^>") then
        local fmt = ms and '(require %q) %s, "obj"' or 'require %q (%s, "obj")'
        seq = fmt:format(LE, seq:sub(2))
      end
      f, msg = loadstring(seq)
    end
    if not f then far.Message(msg, Title, nil, "w"); return 0; end
    f2, msg = loadstring("return "..tOut.params)
    if not f2 then far.Message(msg, Title, nil, "w"); return 0; end
    SendMsg(hDlg, "DM_ADDHISTORY", Pos.sequence, tOut.sequence)
    SendMsg(hDlg, "DM_ADDHISTORY", Pos.params, tOut.params)
  end

  Items.proc = function(hDlg, Msg, Par1, Par2)
    if Msg == F.DN_INITDIALOG then
      set_ext(hDlg)
    elseif Msg == F.DN_BTNCLICK then
      if Par1 == Pos.lua or Par1 == Pos.moon then
        set_ext(hDlg)
      end
    elseif Msg == F.DN_CLOSE then
      return closeaction(hDlg, Par1, Par2)
    end
  end

  local out = dlg:Run()
  if out then
    aOpt.lang  = out.lua and "lua" or "moonscript"
    aOpt.reuse = out.reuse
    aOpt.loop  = out.loop
    return f, f2
  end
end

local function LoadOptions()
  local Opt = mf.mload(DB_Key, DB_Name)
  if type(Opt) ~= "table" then Opt = {} end
  for k,v in pairs(DefaultOpt) do -- set invalid option values to defaults
    if type(Opt[k]) ~= type(v) then Opt[k]=v end
  end
  return Opt
end

local function SaveOptions(aOpt)
  for k,v in pairs(aOpt) do -- remove invalid key-value pairs
    if type(v) ~= type(DefaultOpt[k]) then aOpt[k]=DefaultOpt[k] end
  end
  mf.msave(DB_Key, DB_Name, aOpt)
end

local function Execute()
  local Opt = LoadOptions()
  local oldReuse = Opt.reuse
  local f, f2 = GetText(Opt)
  if not f then return end
  SaveOptions(Opt)

  Env = oldReuse and Opt.reuse and Env or {}
  setmetatable(Env, {__index=_G})
  setfenv(f, Env)
  setfenv(f2, Env)

  Env.F = far.Flags
  Env.Cnt = (type(Env.Cnt)=="number" and Env.Cnt or 0) + 1
  Env.Message = far.Message
  Env.Show = far.Show
  Env.WI = far.AdvControl("ACTL_GETWINDOWINFO")
  Env.EI = Area.Editor and editor.GetInfo() or nil
  Env.VI = Area.Viewer and viewer.GetInfo() or nil
  if panel.CheckPanelsExist() then Env.API, Env.PPI = GetPanelInfo(1), GetPanelInfo(0) end

  mf.postmacro(f, f2())
  if Opt.loop then mf.postmacro(Execute) end
end

Macro {
  id="31D9A3DE-A578-4B4B-969C-6C938727191E";
  description=Title; area="Common"; key=MacroKey;
  condition=function() return (not Area.Dialog) or (Dlg.Id~=DlgGuid and Dlg.Id~=HelpGuid) end;
  action=Execute;
}
