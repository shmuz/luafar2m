-- Started     : 2023-07-01
-- Portability : Far3 (b5285+) / far2m

local osWindows = package.config:sub(1,1)=="\\"
local F = far.Flags
local Send = far.SendDlgMessage

local function DoTest()
  local sd = require "far2.simpledialog"
  local Width = 76
  local W1 = 3 + Width/2
  local Items = {
    width = Width;
    help = ":RegExp";

    {tp="dbox"; text="Regular expressions";                           },
    {tp="text"; text="&Regex:"; width=W1;                             },
    {tp="edit"; name="expr";   width=W1; hist="RegexTestRegex";       },
    {tp="text"; text="&Test string:"; width=W1; ystep=2;              },
    {tp="edit"; name="subj";   width=W1; hist="RegexTestTest";        },
    {tp="text"; text="&Substitution:"; width=W1;                      },
    {tp="edit"; name="subst"; width=W1; hist="RegexTestSubstitution"; },
    {tp="text"; text="Result:";  width=W1;                            },
    {tp="edit"; name="result";   width=W1;  readonly=1;               },

    {tp="listbox"; name="groups"; x1=W1+6; y1=2; width=24; height=10; text="Matches"; list={}; },

    {tp="text"; text="Status:"; width=W1; y1=11;                      },
    {tp="edit"; name="status";  readonly=1;                           },
    {tp="sep";                                                        },
    {tp="butt"; text="OK"; default=1; centergroup=1;                  },
  }

  local Dlg = sd.New(Items)
  local Pos = Dlg:Indexes()
  local Status

  function Items.proc(hDlg, Msg, Par1, Par2)
    if Msg == F.DN_EDITCHANGE and (Par1==Pos.expr or Par1==Pos.subj or Par1==Pos.subst) then
      Send(hDlg, F.DM_ENABLEREDRAW, 0)
      Send(hDlg, F.DM_LISTDELETE, Pos.groups)
      local expr  = Send(hDlg, F.DM_GETTEXT, Pos.expr)
      local ok, rex = pcall(regex.new, expr)
      if not ok then
        Status = "error"
        Send(hDlg, F.DM_SETTEXT, Pos.result, "")
        Send(hDlg, F.DM_SETTEXT, Pos.status, rex)
      else
        Status = "warning"
        local subj = Send(hDlg, F.DM_GETTEXT, Pos.subj)
        local fr,to,offs = rex:exec(subj)
        if fr then
          Status = "normal"
          local txt = ("$0: %d-%d %s"):format(fr, to, subj:sub(fr,to))
          Send(hDlg, F.DM_LISTADD, Pos.groups, {{Text=txt}})
          for k=1,#offs,2 do
            txt = ("$%d: %d-%d %s"):format((k+1)/2, offs[k], offs[k+1], subj:sub(offs[k],offs[k+1]))
            Send(hDlg, F.DM_LISTADD, Pos.groups, {{Text=txt}})
          end
        end

        local subst = Send(hDlg, F.DM_GETTEXT, Pos.subst)
        -- convert replace pattern to LuaFAR syntax ($3 -> %3, \$ -> $, \\ -> \)
        subst = subst:gsub("%%", "%%%%")
        subst = regex.gsub(subst, [[ \$([0-9a-zA-Z]) | \\([$\\]) ]],
          function(a,b) return a and "%"..a or b end, nil, "x")
        -- get replace result
        local result = rex:gsub(subj, subst)
        Send(hDlg, F.DM_SETTEXT, Pos.result, result)
        Send(hDlg, F.DM_SETTEXT, Pos.status, fr and "Found" or "Not found")
      end
      Send(hDlg, F.DM_ENABLEREDRAW, 1)

    elseif Msg==F.DN_CTLCOLORDLGITEM and Par1==Pos.status then
      local color =
        Status == "normal"  and 0x0B or
        Status == "warning" and 0x0E or
        Status == "error"   and 0x0C or 0x00
        Par2[1],Par2[3] = color,color
        return Par2
    end
  end

  Dlg:Run()
end

if not Macro then DoTest() return end
Macro {
  description="Test regular expressions";
  area="Common"; key="AltShiftF2";
  action=function() DoTest() end;
}
