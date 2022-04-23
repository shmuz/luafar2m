local function ReloadUserFile()
  lf4ed.reload()
  far.Message("User file reloaded","LF4Ed","")
  win.Sleep(600)
  actl.RedrawAll()
end
AddCommand("reload", ReloadUserFile, "Reload user file")

local function SmartHome()
  local info, str = editor.GetInfo(), editor.GetString()
  local pos = str.StringText:find("%S") or 1
  editor.SetPosition(nil, pos==info.CurPos and 1 or pos)
  editor.Redraw()
end
AddToMenu("e", nil, "Home", SmartHome)

-- main user menu file
AddToMenu ("e", nil, "Ctrl+1", 1)
AddToMenu ("e", nil, "Ctrl+2", 2)
AddToMenu ("e", nil, "Ctrl+3", 3)
AddToMenu ("e", nil, "Ctrl+4", 4)
AddToMenu ("e", nil, "Ctrl+5", 5)
AddToMenu ("e", nil, "Ctrl+6", 6)

AddToMenu ("e", ":sep:")
AddUserFile("scripts/calc.lua")
AddUserFile("scripts/editor_luacheck.lua")
AddUserFile("scripts/macrobrowser/macrobrowser.lua")
AddUserFile("scripts/dupfighter/dupfighter.lua")

AddToMenu ("depv", "Lua Calc", nil,
  function(...)
    --far.Show(...)
    require("far2.calc")()
  end
    )

AddCommand("luacalc", require("far2.calc"))
------------------------------------------------------------------------------

if os.getenv("USER") == "shmuel" then
  AddToMenu ("e", ":sep:")
  AddUserFile("scripts/bracket.lua")
  AddUserFile("scripts/dup_line.lua")
  AddUserFile("scripts/editor_events.lua")
  AddUserFile("scripts/lf_fin.lua")
  AddUserFile("scripts/scite_like.lua")
  AddUserFile("scripts/test_sortlines.lua")
  AddUserFile("scripts/run_code.lua")
  AddUserFile("scripts/visual_compare.lua")
  AddUserFile("scripts/misc.lua")
  AddUserFile("scripts/coding.lua")
  AddUserFile("scripts/compare_by_hash.lua")
  AddUserFile("scripts/hashes.lua")
  AddUserFile("scripts/file2hex.lua")
  AddUserFile("scripts/Editor.ColorWord.moon")

  AddToMenu("e", nil, "Ctrl+F11", function() -- insert a new GUID
    editor.InsertText('"'..win.Uuid(win.Uuid()):upper()..'"', true) end)
end
