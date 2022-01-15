-- main user menu file
local PluginDir = far.PluginStartupInfo().ModuleName:match(".+/")

AddToMenu("p", "Delete Trees", nil, "scripts/del_trees.lua",
  "<"..PluginDir.."scripts/>DeleteTrees") -- help topic
AddToMenu("p", "Rename", nil, "scripts/lf_rename.lua",
  "<"..PluginDir.."scripts/>Rename")      -- help topic

AddToMenu ("e", ":sep:")
AddToMenu ("e", "Multiline Search",       "Ctrl+7", "scripts/multiline.lua")
AddToMenu ("e", "Multiline Search Again", "Ctrl+8", "scripts/multiline.lua", true)

AddToMenu ("e", true, "Ctrl+1", 1)
AddToMenu ("e", true, "Ctrl+2", 2)
AddToMenu ("e", true, "Ctrl+3", 3)
AddToMenu ("e", true, "Ctrl+4", 4)
AddToMenu ("e", true, "Ctrl+5", 5)
AddToMenu ("e", true, "Ctrl+6", 6)

AddToMenu ("e", ("%-30s(Ctrl+F9)"):format("Test: Sort Lines"), "Ctrl+F9", "scripts/test_sortlines.lua")
AddToMenu ("e", ("%-30s(Ctrl+E)" ):format("Match bracket"),    "Ctrl+E",  "scripts/bracket.lua")
------------------------------------------------------------------------------
