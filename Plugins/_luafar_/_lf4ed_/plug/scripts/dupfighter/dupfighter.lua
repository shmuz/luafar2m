------------------------------------------------------------------------------------------------
-- Started:                 2015-10-29
-- Author:                  Shmuel Zeigerman
-- Published:               2015-10-29 (http://forum.farmanager.com/viewtopic.php?p=133298#p133298)
-- Language:                Lua 5.1
-- Minimal Far version:     3.0.3300
-- Far plugin:              LuaMacro, LF4Editor, LFSearch, LFHistory (any of them)
-- Depends on:              Lua modules 'far2.simpledialog' and 'far2.settings'
------------------------------------------------------------------------------------------------

-- OPTIONS --
local OptAddToPluginsMenu = true
local OptUseMacro = true
-- END OF OPTIONS --

local F = far.Flags
local SendMsg = far.SendDlgMessage
local thisDir = (...):match(".*/")

local mEng = {
  OK          = "OK";
  CANCEL      = "Cancel";
  TITLE       = "Duplicate Fighter";
  REMDUP      = "&1 Remove duplicates";
  CLRDUP      = "&2 Clear duplicates";
  REMNONUNIQ  = "&3 Remove non-uniques";
  CLRNONUNIQ  = "&4 Clear non-uniques";
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
  KEEPEMPTY   = "&Сохранять пустые строки";
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
  local info = editor.GetInfo()
  local isSel = (info.BlockType ~= F.BTYPE_NONE)
  local isColumn = (info.BlockType == F.BTYPE_COLUMN)
  local uniqs,dups,duplines = {},{},{}
  local nSkipped = 0
  for nl = isSel and info.BlockStartLine or 1,info.TotalLines do
    local S = editor.GetString(nl)
    if not S
      or (isSel and not (S.SelStart>0 and S.SelEnd~=0))
      or (nl==info.TotalLines and S.StringText=="")
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
    if text == false then -- luacheck: ignore
      -- NOT a duplicate; keep this line
    elseif uniqs[text] then
      duplines[#duplines+1] = -uniqs[text] -- the minus "marks" a duplicate as being the first one
      duplines[#duplines+1] = nl
      dups[text] = true
      uniqs[text] = nil
    elseif dups[text] then
      duplines[#duplines+1] = nl
    else
      uniqs[text] = nl
    end
  end

  local nUniq,nDup = 0,0
  for _ in pairs(uniqs) do nUniq = nUniq+1 end
  for _ in pairs(dups) do nDup = nDup+1 end

  table.sort(duplines, function(a,b) return math.abs(a) < math.abs(b) end)
  return duplines, nUniq, nDup, nSkipped
end

local function HandleDups(op, removeFirst, keepempty, showstats, func, toboolean)
  local duplines, nUniq, nDup, nSkipped = GetDups(keepempty, func, toboolean)
  local nClear, nDel = 0,0
  editor.UndoRedo("EUR_BEGIN")
  for _,n in ipairs(duplines) do
    if removeFirst or n>0 then
      if op == "clear" then
        editor.SetString(math.abs(n), "")
        nClear = nClear+1
      elseif op == "delete" then
        editor.SetPosition(math.abs(n) - nDel)
        editor.DeleteString()
        nDel = nDel+1
      end
    end
  end
  editor.UndoRedo("EUR_END")
  editor.Redraw()
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

local STdefault = { -- default settings
  method     = 1;
  keepempty  = false;
  statistics = false;
  useexpr    = false;
  toboolean  = true;
}

local function Main()
  M = SetLanguage()
  local sDialog     = require("far2.simpledialog")
--TODO  local libSettings = require("far2.settings")
--TODO  local ST = libSettings.mload("Duplicate Fighter", "settings") or STdefault
  local ST = STdefault

  local dItems = {
    guid = "85FA90FE-4068-4FFB-962E-F961F46BE867";
    width = 73;
    -------------------------------------------------------------------------------
    {tp="dbox";  text=M.TITLE;                                                   },
    {tp="rbutt"; text=M.REMDUP;      name="remdup"; group=1; ystep=2;            },
    {tp="rbutt"; text=M.CLRDUP;      name="clrdup";                              },
    {tp="rbutt"; text=M.REMNONUNIQ;  name="remnonuniq";                          },
    {tp="rbutt"; text=M.CLRNONUNIQ;  name="clrnonuniq";                          },
    -------------------------------------------------------------------------------
    {tp="cbox";  text=M.KEEPEMPTY;   name="cbEmpty"; x1=35; ystep=-3;            },
    {tp="cbox";  text=M.SHOWSTATS;   name="cbStat";  x1=35                       },
    -------------------------------------------------------------------------------
    {tp="cbox";  text=M.USEEXPR;     name="cbExpr"; ystep=4;                     },
    {tp="cbox";  text=M.TOBOOLEAN;   name="cbBool"; ystep=0; x1=35;              },
    {tp="text";  text=M.EXPRESSION;  name="lbExpr";                              },
    {tp="edit";  uselasthistory=1;   name="edExpr"; hist="DupFighterExpression"; },
    -------------------------------------------------------------------------------
    {tp="sep";   ystep=2;                                                        },
    {tp="butt";  text=M.OK;     centergroup=1; default=1;                        },
    {tp="butt";  text=M.CANCEL; centergroup=1; cancel=1;                         },
  }
  local Pos, Elem = sDialog.Indexes(dItems)

  dItems.initaction = function(hDlg)
    if not (ST.method>=1 and ST.method<=4) then ST.method=1; end
    local rb = Pos.remdup + ST.method - 1
    SendMsg(hDlg, "DM_SETCHECK", rb, 1)
    SendMsg(hDlg, "DM_SETFOCUS", rb)

    SendMsg(hDlg, "DM_SETCHECK", Pos.cbEmpty, ST.keepempty  and 1 or 0)
    SendMsg(hDlg, "DM_SETCHECK", Pos.cbStat,  ST.statistics and 1 or 0)
    SendMsg(hDlg, "DM_SETCHECK", Pos.cbExpr,  ST.useexpr    and 1 or 0)
    SendMsg(hDlg, "DM_SETCHECK", Pos.cbBool,  ST.toboolean  and 1 or 0)
    SendMsg(hDlg, "DM_ENABLE",   Pos.cbBool,  ST.useexpr    and 1 or 0)
    SendMsg(hDlg, "DM_ENABLE",   Pos.lbExpr,  ST.useexpr    and 1 or 0)
    SendMsg(hDlg, "DM_ENABLE",   Pos.edExpr,  ST.useexpr    and 1 or 0)
  end

  Elem.cbExpr.action = function(hDlg, p1, p2)
    SendMsg(hDlg, "DM_ENABLE", Pos.cbBool, p2)
    SendMsg(hDlg, "DM_ENABLE", Pos.lbExpr, p2)
    SendMsg(hDlg, "DM_ENABLE", Pos.edExpr, p2)
  end

  dItems.help = function() far.ShowHelp(thisDir, nil, F.FHELP_CUSTOMPATH) end

  dItems.closeaction = function(hDlg, p1, tOut)
    if SendMsg(hDlg, "DM_GETCHECK", Pos.cbExpr) ~= 0 then
      local expr = "return " .. SendMsg(hDlg, "DM_GETTEXT", Pos.edExpr)
      local f, msg = loadstring(expr)
      if not f then
        far.Message(msg, M.TITLE, nil, "w"); return 0;
      end
    end
  end

  local out = sDialog.Run(dItems)
  if out then
    ST.keepempty  = out.cbEmpty
    ST.statistics = out.cbStat
    ST.useexpr    = out.cbExpr
    ST.toboolean  = out.cbBool
    local op, removeFirst, method
    if     out.remdup     then op, removeFirst, method = "delete",false, 1
    elseif out.clrdup     then op, removeFirst, method = "clear", false, 2
    elseif out.remnonuniq then op, removeFirst, method = "delete",true , 3
    elseif out.clrnonuniq then op, removeFirst, method = "clear", true , 4
    end
    if op then
      ST.method = method
--TODO      libSettings.msave("Duplicate Fighter", "settings", ST)
      local func = ST.useexpr and loadstring("local L=... return "..out.edExpr)
      HandleDups(op, removeFirst, ST.keepempty, ST.statistics, func, ST.toboolean)
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
  if OptAddToPluginsMenu and MenuItem then
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
  AddToMenu("e", mEng.TITLE, "Ctrl+Shift+P", Main)
end
