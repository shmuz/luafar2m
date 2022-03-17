------------------------------------------------------------------------------------------------
-- Started:                 2015-11-23
-- Author:                  Shmuel Zeigerman
-- Published:               2015-11-24 (https://forum.farmanager.com/viewtopic.php?f=60&t=9940)
-- Language:                Lua 5.1
-- Minimal Far version:     3.0.3777
-- Far plugin:              LuaMacro
-- Dependencies:            Lua module far2.simpledialog
------------------------------------------------------------------------------------------------

local MacroKey = "CtrlShiftM" -- luacheck: ignore (unused)
--local Title    = "Post macro"
local Title    = "Run code"
local DlgGuid  = "2C4EFD54-A419-47E5-99B6-C9FD2D386AEC"
local HelpGuid = "59154DF0-40D8-495C-BDF2-B97803745D8F"
local DB_Key   = "shmuz"
local DB_Name  = "postmacro"
local F = far.Flags

-- Options
local DefaultOpt = {
  lang = "lua";   -- "lua" or "moonscript"
  reuse = false;  -- true: reuse environment
  loop = false;   -- true: call the dialog again after the macro execution is finished
}
local Env = {}

local Help = [[
Controls:
  Sequence   - either Lua/MoonScript chunk or @<filename>
               if it begins with an '=' then far.Show() is called on it.
  Parameters - comma separated list of Lua/MoonScript expressions
  [x] Reuse environment - use the previous Lua environment for the new run
  [x] Loop this dialog  - call this dialog again after the execution

Preset "global" variables:
  F       = far.Flags
  Message = far.Message
  Show    = far.Show
  WI      = far.AdvControl("ACTL_GETWINDOWINFO") -- window info
  API     = panel.GetPanelInfo(1)                -- active panel info
  PPI     = panel.GetPanelInfo(0)                -- passive panel info
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
    {tp="dbox";  text=Title;                                                  };
    {tp="text";  text="&Sequence:";                                           };
    {tp="edit";  hist="PostMacroSequence"; flags=edtFlags;   name="sequence"; };
    {tp="text";  text="&Parameters:";                                         };
    {tp="edit";  hist="PostMacroParams";   flags=edtFlags;   name="params";   };
    {tp="rbutt"; group=1; text="&Lua"; ystep=2;              name="lua";      };
    {tp="rbutt"; text="&MoonScript";                         name="moon";     };
    {tp="chbox"; x1=35; text="&Reuse environment"; ystep=-1; name="reuse";    };
    {tp="chbox"; x1=""; text="Loop this &dialog";            name="loop";     };
    {tp="sep";   ystep=2;                                                     };
    {tp="butt";  text="OK";     default=1; centergroup=1;                     };
    {tp="butt";  text="Cancel"; cancel=1;  centergroup=1;                     };
  }

  local Pos, Elem = sDialog.Indexes(Items)
  Elem.lua.val   = aOpt.lang~="moonscript"
  Elem.moon.val  = aOpt.lang=="moonscript"
  Elem.reuse.val = aOpt.reuse
  Elem.loop.val  = aOpt.loop

  Items.help = function()
    far.Message(Help, Title.." HELP", nil, "l", nil, win.Uuid(HelpGuid))
  end

  local function set_ext(hDlg)
    local ext = hDlg:GetCheck(Pos.moon) and "moon" or "lua"
    Elem.sequence.ext, Elem.params.ext = ext, ext
  end

  Items.initaction, Elem.lua.action, Elem.moon.action = set_ext, set_ext, set_ext

  local f, f2, msg
  Items.closeaction = function (hDlg, Param1, tOut)
    local ms, ok
    if tOut.moon then
      ok, ms = pcall(require, "moonscript")
      if not ok then far.Message("MoonScript not found", Title, nil, "w"); return 0; end
    end
    local loadstring, loadfile = (ms or _G).loadstring, (ms or _G).loadfile
    if tOut.sequence:find("^@") then
      local fname = tOut.sequence:sub(2):gsub("%%(.-)%%", win.GetEnv)
      fname  = far.ConvertPath(fname, "CPM_NATIVE") or fname
      f, msg = loadfile(fname)
    else
      local s = tOut.sequence:find("^=") and "far.Show("..tOut.sequence:sub(2)..")"
      f, msg = loadstring(s or tOut.sequence)
    end
    if not f then far.Message(msg, Title, nil, "w"); return 0; end
    f2, msg = loadstring("return "..tOut.params)
    if not f2 then far.Message(msg, Title, nil, "w"); return 0; end
    hDlg:AddHistory(Pos.sequence, tOut.sequence)
    hDlg:AddHistory(Pos.params, tOut.params)
  end

  local out = sDialog.Run(Items)
  if out then
    aOpt.lang  = out.lua and "lua" or "moonscript"
    aOpt.reuse = out.reuse
    aOpt.loop  = out.loop
    return f, f2
  end
end

local function LoadOptions(sett)
  local Opt = sett.mload(DB_Key, DB_Name)
  if type(Opt) ~= "table" then Opt = {} end
  for k,v in pairs(DefaultOpt) do -- set invalid option values to defaults
    if type(Opt[k]) ~= type(v) then Opt[k]=v end
  end
  return Opt
end

local function SaveOptions(sett, aOpt)
  for k,v in pairs(aOpt) do -- remove invalid key-value pairs
    if type(v) ~= type(DefaultOpt[k]) then aOpt[k]=DefaultOpt[k] end
  end
  sett.msave(DB_Key, DB_Name, aOpt)
end

local function Execute()
  local sett = require "far2.settings"
  local Opt = LoadOptions(sett)
  local oldReuse = Opt.reuse
  local f, f2 = GetText(Opt)
  if not f then return end
  SaveOptions(sett, Opt)

  Env = oldReuse and Opt.reuse and Env or {}
  setmetatable(Env, {__index=_G})
  setfenv(f, Env)
  setfenv(f2, Env)

  Env.F = far.Flags
  Env.Cnt = (type(Env.Cnt)=="number" and Env.Cnt or 0) + 1
  Env.Message = far.Message
  Env.Show = far.Show
  Env.WI = actl.GetWindowInfo()
  Env.EI = far.MacroGetArea()==F.MACROAREA_EDITOR and editor.GetInfo() or nil
  Env.VI = far.MacroGetArea()==F.MACROAREA_VIEWER and viewer.GetInfo() or nil
  if panel.CheckPanelsExist() then Env.API, Env.PPI = panel.GetPanelInfo(1), panel.GetPanelInfo(0) end

  --mf.postmacro(f, f2())
  f( f2() )
  --if Opt.loop then mf.postmacro(Execute) end
  if not Opt.loop then return end
  return Execute()
end

-- Macro {
--   description=Title; area="Common"; key=MacroKey;
--   condition=function() return (not Area.Dialog) or (Dlg.Id~=DlgGuid and Dlg.Id~=HelpGuid) end;
--   action=Execute;
-- }

AddCommand("run_code", Execute)
