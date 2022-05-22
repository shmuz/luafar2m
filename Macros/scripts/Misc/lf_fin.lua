-----------------------------------------------------------------------------
-- Name:     FIN == "Fix Incorrect Names"
-- Started:  2010-08-26
-- Author:   Shmuel Zeigerman
-- Original author of plugin in Pascal: Андрей Подлазов aka Тигрёнок.
-----------------------------------------------------------------------------

local Pattern = "%s+$"
local F = far.Flags

local GUIDs = {
  [win.Uuid("fcef11c4-5490-451d-8b4a-62fa03f52759")] = "CopyFilesId",
  [win.Uuid("431a2f37-ac01-4ecd-bb6f-8cde584e5a03")] = "MoveFilesId",
  [win.Uuid("1d07cee2-8f4f-480a-be93-069b4ff59a2b")] = "FileOpenCreateId",
  [win.Uuid("9162f965-78b8-4476-98ac-d699e5b6afe7")] = "FileSaveAsId",
  [win.Uuid("5eb266f4-980d-46af-b3d2-2c50e64bca81")] = "HardSymLinkId",
  [win.Uuid("fad00dbe-3fff-4095-9232-e1cc70c67737")] = "MakeFolderId",
  [win.Uuid("d2750b57-d3e6-42f4-8137-231c50ddc6e4")] = "UserMenuUserInputId",
  [win.Uuid("502d00df-ee31-41cf-9028-442d2e352990")] = "CopyCurrentOnlyFileId",
  [win.Uuid("89664ef4-bb8c-4932-a8c0-59cafd937aba")] = "MoveCurrentOnlyFileId",
}

local function FIN (Event, FarDialogEvent)
  if Event == F.DE_DLGPROCINIT and FarDialogEvent.Msg == F.DN_CLOSE
                               and FarDialogEvent.Param1 >= 1 then
    local hDlg = FarDialogEvent.hDlg
    local DialogInfo = hDlg:GetDialogInfo()
    if DialogInfo and GUIDs[DialogInfo.Id] then
      for item = 1, 1e6 do
        local FarDialogItem = hDlg:GetDlgItem(item)
        if not FarDialogItem then break end
        if FarDialogItem[1] == F.DI_EDIT then
          local str, n = FarDialogItem[10]:gsub(Pattern, "")
          if n > 0 then
            hDlg:SetText(item, str)
          end
          break
        end
      end
    end
  end
end

Event {
  description="Fix Incorrect Names";
  group="DialogEvent";
  action=FIN;
}
