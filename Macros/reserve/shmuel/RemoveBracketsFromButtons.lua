-- Remove brackets from dialog buttons.
-- http://forum.farmanager.com/viewtopic.php?p=128625#p128625
-- http://forum.farmanager.com/viewtopic.php?p=128653#p128653

local RemoveLevel = 0 -- 0:remove nothing;       1:remove only spaces;
                      -- 2:remove only brackets; 3:remove brackets and spaces;
local F = far.Flags

local function Work (Event, FarDialogEvent)
  if Event == F.DE_DLGPROCINIT and FarDialogEvent.Msg == F.DN_INITDIALOG then
    local hDlg = FarDialogEvent.hDlg
    for k=1,1000 do
      local Item = hDlg:send("DM_GETDLGITEM", k)
      if not Item then break end
      if Item[1]==F.DI_BUTTON and 0==bit64.band(Item[9], F.DIF_NOBRACKETS) then
        Item[9] = bit64.bor(Item[9], F.DIF_NOBRACKETS)
        if RemoveLevel==1 then
          Item[10] = Item[10]:sub(1,1)..Item[10]:sub(3,-3)..Item[10]:sub(-1)
        elseif RemoveLevel==2 then
          Item[10] = Item[10]:sub(2,-2)
        else
          Item[10] = Item[10]:sub(3,-3)
        end
        hDlg:send("DM_SETDLGITEM", k, Item)
      end
    end
  end
end

Event {
  description="Remove brackets from dialog buttons";
  group="DialogEvent"; condition = function() return RemoveLevel==1 or RemoveLevel==2 or RemoveLevel==3 end;
  action=Work;
}
