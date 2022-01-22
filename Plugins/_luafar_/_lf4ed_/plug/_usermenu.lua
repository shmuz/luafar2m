-- main user menu file
local PluginDir = far.PluginStartupInfo().ModuleName:match(".+/")

AddToMenu ("e", true, "Ctrl+1", 1)
AddToMenu ("e", true, "Ctrl+2", 2)
AddToMenu ("e", true, "Ctrl+3", 3)
AddToMenu ("e", true, "Ctrl+4", 4)
AddToMenu ("e", true, "Ctrl+5", 5)
AddToMenu ("e", true, "Ctrl+6", 6)

AddToMenu ("e", ":sep:")
AddToMenu ("e", "Multiline Search",       "Ctrl+7", "scripts/multiline.lua")
AddToMenu ("e", "Multiline Search Again", "Ctrl+8", "scripts/multiline.lua", true)
AddToMenu ("e", "Test: Sort Lines", nil, "scripts/test_sortlines.lua")
AddToMenu ("e", ("%-30s(Ctrl+E)" ):format("Match bracket"), "Ctrl+E", "scripts/bracket.lua")
AddToMenu ("e", nil, "Ctrl+F9", "scripts/calc.lua")

AddCommand("macrobrowser", "scripts/macrobrowser.lua")
AddCommand("reload", function()
    lf4ed.reload(); far.Message("User file reloaded","LF4Ed","")
    win.Sleep(600); far.AdvControl("ACTL_REDRAWALL")
  end)

-- WARNING: The following 2 utilities may rename or delete your files.
--          They are not tested enough. Do not run them.
--AddToMenu("p", "Delete Trees", nil, "scripts/del_trees.lua",
--          "<"..PluginDir.."scripts/>DeleteTrees") -- help topic
--AddToMenu("p", "Rename", nil, "scripts/lf_rename.lua",
--          "<"..PluginDir.."scripts/>Rename")      -- help topic

------------------------------------------------------------------------------
--MakeResident("scripts/scite_like.lua")
