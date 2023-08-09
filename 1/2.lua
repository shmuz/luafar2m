local F=far.Flags
local sd=require'far2.simpledialog'
local items={
  {tp="dbox"; text="TEST"; },
  {tp="text"; text="Enter color parameters:"; },
  {tp="edit"; name="params"; },
  {tp="text"; text="Text"; width=4; centergroup=1; name=1; },
  {tp="text"; text="Text"; width=4; centergroup=1; name=2; },
  {tp="text"; text="Text"; width=4; centergroup=1; name=3; },
  {tp="text"; text="Text"; width=4; centergroup=1; name=4; },
  {tp="text"; text="Text"; width=4; centergroup=1; name=5; },
  {tp="text"; text="Text"; width=4; centergroup=1; name=6; },
  {tp="text"; text="Text"; width=4; centergroup=1; name=7; },
  {tp="text"; text="Text"; width=4; centergroup=1; name=8; },
  {tp="sep"; },
  {tp="butt"; text="&Apply"; btnnoclose=true; name="apply"; centergroup=1; },
  {tp="butt"; text="&Get";   btnnoclose=true; name="get";   centergroup=1; },
}

local dlg = sd.New(items)
local Pos = dlg:Indexes()

function items.proc(hDlg,Msg,P1,P2)
  if Msg==F.DN_BTNCLICK then
    if P1==Pos.apply then
      for k=1,8 do
        hDlg:SetTrueColor(Pos[k],
          { Normal = { Fore={R=200;G=100;B=0;}, Back={R=13*k;G=26*k;B=255;} } } )
      end
    elseif P1==Pos.get then
      local color = hDlg:GetTrueColor(Pos[4])
      require "far2.lua_explorer" (color, "color")
    end
  end
end

dlg:Run()
