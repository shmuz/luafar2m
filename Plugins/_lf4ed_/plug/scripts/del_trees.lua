-- started 2010-07-18 by Shmuel Zeigerman

local Title = "Delete Trees"
local RegPath = "LuaFAR\\DelTrees\\"
local far2_dialog = require "far2.dialog"
local F = far.Flags


local function UserDialog (aData, aHelpTopic)
  local HIST_DIRPAT = RegPath .. "DirPattern"
  ------------------------------------------------------------------------------
  local D = far2_dialog.NewDialog()
  D._         = {"DI_DOUBLEBOX",3, 1,72,6, 0, 0, 0, 0, Title}
  D.lab       = {"DI_TEXT",     5, 2, 0,0, 0, 0, 0, 0, "Directory pattern:"}
  D.edtDirPat = {"DI_EDIT",     5, 3,70,6, 0, HIST_DIRPAT, {DIF_HISTORY=1,DIF_USELASTHISTORY=1}, 0, ""}
  D.sep       = {"DI_TEXT",     5, 4, 0,0, 0, 0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, 0, ""}
  D.btnOk     = {"DI_BUTTON",   0, 5, 0,0, 0, 0, "DIF_CENTERGROUP", 1, "Ok"}
  D.btnCancel = {"DI_BUTTON",   0, 5, 0,0, 0, 0, "DIF_CENTERGROUP", 0, "Cancel"}
  ------------------------------------------------------------------------------

  local function DlgProc (hDlg, msg, param1, param2)
    if msg == F.DN_INITDIALOG then
    elseif msg == F.DN_CLOSE then
      if param1 == D.btnOk.id then
        local pat = D.edtDirPat:GetText(hDlg)
        local ok, regex = pcall(regex.new, pat, "i")
        if ok then
          aData.regex = regex
        else
          far.Message(regex, "Error", ";Ok", "w")
          return 0
        end
      end
    end
  end
  local ret = far.Dialog (-1, -1, 76, 8, aHelpTopic, D, 0, DlgProc)
  return (ret == D.btnOk.id)
end


local function GetUserChoice(f)
  local r = far.Message("Do you wish to delete\n"..f, "Delete",
                        "&Delete;&All;&Skip;&Cancel", "w")
  return r==0 and "yes" or r==1 and "all" or r==2 and "no" or "cancel"
end


local function DeleteTrees (aDirRegex)
  require "sysutils"
  local RecurseFunc = require "sysutils.recurse"

  local panelInfo = panel.GetPanelInfo (nil, 1)
  local nFiles, nDirs, nFailed = 0, 0, 0
  local choice = "no"
  local depth = 0

  for i=1, panelInfo.SelectedItemsNumber do
    local item = panel.GetSelectedPanelItem (nil, 1, i)
    local fd = item.FindData
    if fd.FileAttributes:find("d") then
      for path,file,stage,control in RecurseFunc(fd.FileName.."\\*", "bfE") do
        if stage == "b" then
          if depth > 0 or aDirRegex:find(path) then depth = depth + 1
          else control("skipf")
          end
        elseif stage == "f" then
          local f = path.."\\"..file.name
          if choice ~= "all" then choice = GetUserChoice(f) end
          if choice == "all" or choice == "yes" then
            sysutils.FileSetAttr(f,"")
            if sysutils.DeleteFile(f) then nFiles = nFiles+1
            else nFailed = nFailed+1
            end
          elseif choice == "cancel" then
            break
          end
        elseif stage == "E" then
          if depth > 0 then
            depth = depth - 1
            if choice ~= "all" then choice = GetUserChoice(path) end
            if choice == "all" or choice == "yes" then
              sysutils.FileSetAttr(path,"d")
              if sysutils.RemoveDir(path) then nDirs = nDirs+1
              else nFailed = nFailed+1
              end
            elseif choice == "cancel" then
              break
            end
          end
        end
      end -- subitems loop
      if choice == "cancel" then break end
    end -- if selected item is directory
  end -- selected items loop

  far.Message(("Deleted files:       %d\n" ..
               "Deleted directories: %d\n" ..
               "Failed deletions:    %d"):format(nFiles, nDirs, nFailed),
               Title, ";OK", "l")
end


do
  local arg = ...
  local helpTopic = arg and arg[1]
  local data = {}
  if UserDialog(data, helpTopic) then
    DeleteTrees(data.regex)
  end
end
