-- coding: utf-8
------------------------------------------------------------------------------------------------
-- Started:                 2015-10-29
-- Author:                  Shmuel Zeigerman
-- Published:               2015-10-29 (http://forum.farmanager.com/viewtopic.php?p=133298#p133298)
-- Language:                Lua 5.1
-- Minimal Far version:     3.0.3300 (Windows), 2.4 (Linux)
-- Far plugin:              LuaMacro, LF4Editor, LFSearch, LFHistory (any of them)
-- Depends on:              Lua modules 'far2.simpledialog' and 'far2.settings'
------------------------------------------------------------------------------------------------

-- OPTIONS --
local OptAddToPluginsMenu = true
local OptUseMacro = true
-- END OF OPTIONS --

local dirsep = package.config:sub(1,1)
local FarVer = dirsep == "\\" and 3 or 2
local F = far.Flags
local SendMsg = far.SendDlgMessage

local thisDir do
  -- handle the script argument to ensure correct work in both LuaMacro and LF4Ed plugins
  local arg = ...
  if type(arg)=="table" then arg = arg[1] end -- old LF4Ed
  if type(arg)=="string" then thisDir = mf and arg:match(".+"..dirsep) or arg end -- LuaMacro or LF4Ed
end

local ed = editor
if FarVer == 3 then
  ed = setmetatable({}, {__index=
    function(self,name)
      return function(...) return editor[name](nil, ...) end
    end})
end

local SETTINGS_KEY  = FarVer==3 and "Duplicate Fighter" or "shmuz"
local SETTINGS_NAME = FarVer==3 and "settings"          or "Duplicate Fighter"

local mEng = {
  OK          = "OK";
  CANCEL      = "Cancel";
  TITLE       = "Duplicate Fighter";
  REMDUP      = "&1 Remove duplicates";
  CLRDUP      = "&2 Clear duplicates";
  REMNONUNIQ  = "&3 Remove non-uniques";
  CLRNONUNIQ  = "&4 Clear non-uniques";
  KEEPLASTDUP = "Keep &last duplicate";
  KEEPEMPTY   = "&Keep empty lines";
  SHOWSTATS   = "&Show statistics";
  USEEXPR     = "&Use Expression";
  EXPRESSION  = "&Expression:";
  TOBOOLEAN   = "&Convert to boolean";
  STAT_TITLE  = "Statistics";
  STAT_DUP    = "Duplicate groups:",
  STAT_UNIQ   = "Unique lines:",
  STAT_CLEAR  = "Cleared lines:",
  STAT_DEL    = "Deleted lines:",
  STAT_SKIP   = "Skipped lines:",
}

local mRus = {
  OK          = "OK";
  CANCEL      = "Отмена";
  TITLE       = "Анти-дубликатор";
  REMDUP      = "&1 Удалить дубликаты";
  CLRDUP      = "&2 Очистить дубликаты";
  REMNONUNIQ  = "&3 Удалить неуникальные";
  CLRNONUNIQ  = "&4 Очистить неуникальные";
  KEEPLASTDUP = "&Сохранять последний дубликат";
  KEEPEMPTY   = "Сохр&анять пустые строки";
  SHOWSTATS   = "&Показывать статистику";
  USEEXPR     = "&Использовать выражение";
  EXPRESSION  = "&Выражение:";
  TOBOOLEAN   = "Преобразовать в &булевое";
  STAT_TITLE  = "Статистика";
  STAT_DUP    = "Групп дубликатов:",
  STAT_UNIQ   = "Уникальных строк:",
  STAT_CLEAR  = "Очищенных строк:",
  STAT_DEL    = "Удалённых строк:",
  STAT_SKIP   = "Пропущенных строк:",
}

local function SetLanguage() return win.GetEnv("FARLANG")=="Russian" and mRus or mEng end
local M = SetLanguage()

local function GetDups(keepempty, func, toboolean)
  local info = ed.GetInfo()
  local isSel = (info.BlockType ~= F.BTYPE_NONE)
  local isColumn = (info.BlockType == F.BTYPE_COLUMN)
  local groups = {}
  local nSkipped = 0
  for lnum = isSel and info.BlockStartLine or 1,info.TotalLines do
    local S = ed.GetString(lnum)
    if not S
      or (isSel and not (S.SelStart>0 and S.SelEnd~=0))
      or (lnum==info.TotalLines and S.StringText=="")
        then break
    end
    local text = isColumn and S.StringText:sub(S.SelStart,S.SelEnd) or S.StringText
    if keepempty and text:match("^%s*$") then
      text = false
      nSkipped = nSkipped + 1 -- this is by convention NOT a duplicate; skip this line.
    elseif func then
      text = func(text)
      if toboolean or (type(text)~="string" and type(text)~="number") then
        text = not not text
      end
    end
    if text ~= false then -- text==false is NOT a duplicate
      groups[text] = groups[text] or {}
      table.insert(groups[text], lnum)
    end
  end

  return groups, nSkipped
end

local function HandleDups(op, keepWhat, keepempty, showstats, func, toboolean)
  local nUniq, nDup = 0,0
  local groups, nSkipped = GetDups(keepempty, func, toboolean)
  local duplines = {}
  for text,grp in pairs(groups) do
    if grp[2] == nil then
      groups[text] = nil
      nUniq = nUniq + 1
    else
      local N = keepWhat=="first" and 1 or keepWhat=="last" and #grp
      if N then
        grp[N] = -grp[N] -- the minus "marks" a duplicate to keep rather than remove
      end
      for _,lnum in ipairs(grp) do table.insert(duplines, lnum) end
      nDup = nDup + 1
    end
  end
  table.sort(duplines, function(a,b) return math.abs(a) < math.abs(b) end)


  local nClear, nDel = 0, 0
  ed.UndoRedo("EUR_BEGIN")
  for _,n in ipairs(duplines) do
    if n > 0 then
      if op == "clear" then
        ed.SetString(n, "")
        nClear = nClear+1
      elseif op == "delete" then
        ed.SetPosition(n - nDel)
        ed.DeleteString()
        nDel = nDel+1
      end
    end
  end
  ed.UndoRedo("EUR_END")
  ed.Redraw()
  if showstats then
    local len1 = math.max(M.STAT_DUP:len(), M.STAT_UNIQ:len(), M.STAT_SKIP:len(),
                          M.STAT_DEL:len(), M.STAT_CLEAR:len())
    local len2 = tostring(math.max(nDup, nUniq, nSkipped, nDel, nClear)):len()
    local fmt = (("%%-%ds    %%%dd\n"):format(len1,len2)):rep(5):sub(1,-2)
    local msg = fmt:format(M.STAT_DUP, nDup, M.STAT_UNIQ, nUniq, M.STAT_SKIP, nSkipped,
                           M.STAT_DEL, nDel, M.STAT_CLEAR, nClear)
    far.Message(msg, M.STAT_TITLE)
  end
end

local function Main()
  M = SetLanguage()
  local sDialog     = require("far2.simpledialog")
  local libSettings = mf or require("far2.settings")
  local ST = libSettings.mload(SETTINGS_KEY, SETTINGS_NAME) or {}

  local dItems = {
    guid = "85FA90FE-4068-4FFB-962E-F961F46BE867";
    help = function() far.ShowHelp(thisDir, nil, F.FHELP_CUSTOMPATH) end;
    width = 73;
    -------------------------------------------------------------------------------
    {tp="dbox";  text=M.TITLE;                                                   },
    {tp="rbutt"; text=M.REMDUP;      name="remdup"; group=1; ystep=2; val=1;     },
    {tp="rbutt"; text=M.CLRDUP;      name="clrdup";                              },
    {tp="rbutt"; text=M.REMNONUNIQ;  name="remnonuniq";                          },
    {tp="rbutt"; text=M.CLRNONUNIQ;  name="clrnonuniq";                          },
    -------------------------------------------------------------------------------
    {tp="chbox"; text=M.KEEPLASTDUP; name="keeplast";   x1=35; ystep=-3;         },
    {tp="chbox"; text=M.KEEPEMPTY;   name="keepempty";  x1=35;                   },
    {tp="chbox"; text=M.SHOWSTATS;   name="statistics"; x1=35;                   },
    -------------------------------------------------------------------------------
    {tp="chbox"; text=M.USEEXPR;     name="useexpr";   ystep=3;                  },
    {tp="chbox"; text=M.TOBOOLEAN;   name="toboolean"; ystep=0; x1=35;           },
    {tp="text";  text=M.EXPRESSION;  name="lbExpr";                              },
    {tp="edit";  uselasthistory=1;   name="edExpr"; hist="DupFighterExpression"; },
    -------------------------------------------------------------------------------
    {tp="sep";   ystep=2;                                                        },
    {tp="butt";  text=M.OK;     centergroup=1; default=1;                        },
    {tp="butt";  text=M.CANCEL; centergroup=1; cancel=1;                         },
  }
  local dlg = sDialog.New(dItems)
  local Pos, Elem = dlg:Indexes()

  dItems.initaction = function(hDlg)
    local val = FarVer==3 and (ST.useexpr and 1 or 0) or ST.useexpr
    SendMsg(hDlg, F.DM_ENABLE, Pos.toboolean, val)
    SendMsg(hDlg, F.DM_ENABLE, Pos.lbExpr,    val)
    SendMsg(hDlg, F.DM_ENABLE, Pos.edExpr,    val)
  end

  Elem.useexpr.action = function(hDlg, p1, p2)
    SendMsg(hDlg, F.DM_ENABLE, Pos.toboolean, p2)
    SendMsg(hDlg, F.DM_ENABLE, Pos.lbExpr,    p2)
    SendMsg(hDlg, F.DM_ENABLE, Pos.edExpr,    p2)
  end

  local function GetFunc(txt)
    return loadstring("local L=... return "..txt)
  end

  dItems.closeaction = function(hDlg, p1, tOut)
    if tOut.useexpr then
      local f, msg = GetFunc(tOut.edExpr)
      if f then
        f, msg = pcall(f,"")
      end
      if not f then
        far.Message(msg, M.TITLE, nil, "w")
        return 0
      end
    end
  end

  dlg:LoadData(ST)
  local out = dlg:Run()
  if out then
    local op, keepWhat
    if     out.remdup     then op = "delete"; keepWhat = out.keeplast and "last" or "first"
    elseif out.clrdup     then op = "clear" ; keepWhat = out.keeplast and "last" or "first"
    elseif out.remnonuniq then op = "delete"; keepWhat = "none"
    elseif out.clrnonuniq then op = "clear" ; keepWhat = "none"
    end
    if op then
      libSettings.msave(SETTINGS_KEY, SETTINGS_NAME, out)
      local func = out.useexpr and GetFunc(out.edExpr)
      HandleDups(op, keepWhat, out.keepempty, out.statistics, func, out.toboolean)
    end
  end
end

if Macro then
  if OptUseMacro then
    Macro {
      description = M.TITLE;
      area="Editor"; key="CtrlShiftP"; action=Main;
    }
  end
  if FarVer==3 and OptAddToPluginsMenu and MenuItem then
    MenuItem {
      description = M.TITLE;
      menu   = "Plugins";
      area   = "Editor";
      guid   = "D1F37D2D-20F4-4151-820E-236E7B4A42CC";
      text   = function(menu, area) M = SetLanguage(); return M.TITLE; end;
      action = function(OpenFrom, Item) mf.postmacro(Main) end;
    }
  end
else
  Main()
end
