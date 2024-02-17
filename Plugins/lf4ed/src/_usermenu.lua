-- luacheck: globals lf4ed AddCommand AddToMenu AddUserFile AutoInstall

local function ReloadUserFile()
  lf4ed.reload()
  far.Message("User file reloaded","LF4Ed","")
  win.Sleep(600)
  actl.RedrawAll()
end
AddCommand("reload", ReloadUserFile, "Reload user file")

-- main user menu file
AddToMenu ("e", nil, "Ctrl+1", 1)
AddToMenu ("e", nil, "Ctrl+2", 2)
AddToMenu ("e", nil, "Ctrl+3", 3)
AddToMenu ("e", nil, "Ctrl+4", 4)
AddToMenu ("e", nil, "Ctrl+5", 5)
AddToMenu ("e", nil, "Ctrl+6", 6)
AddToMenu ("e", ":sep:")
AddUserFile("scripts/test_sortlines.lua")

-- AutoInstall("scripts")
