local function test_macroengine(verbose)
  far.Message("Please wait...", "Test macro engine", "")
  Far.DisableHistory(0x0F)
  local f = assert(loadfile(far.PluginStartupInfo().ShareDir.."/macrotest.lua"))
  local t = setfenv(f, getfenv())()
  if t and t.test_all then t.test_all(); end
  if verbose then far.Message("PASS", "Macro engine tests"); end
end

local function test_polygon(verbose)
  local guid = 0xD4BC5EA7
  local libname = "far2.test.test_polygon"
  assert(Plugin.Exist(guid), "Plugin not found")
  far.Message("Please wait...", "Test Polygon", "")
  Far.DisableHistory(0x0F)
  package.loaded[libname] = nil -- for debug
  require(libname).test_all()
  if verbose then far.Message("PASS", "Polygon tests"); end
end

local function test_lfsearch(verbose)
  Far.DisableHistory(0x0F)
  local guid = 0x8E11EA75
  assert(Plugin.Exist(guid), "Plugin not found")
  far.Message("Please wait...", "Test LF Search", "")
  Plugin.Command(guid, "test")
  assert(Area.Shell, "LF Search tests failed")
  if verbose then
    far.Message("PASS", "LF Search tests")
  end
end

Macro {
  description="Test macro engine";
  area="Shell"; key="CtrlShiftF12";
  sortpriority=59;
  action = function() test_macroengine(true) end;
}

Macro {
  description="Test plugin Polygon";
  area="Shell"; key="CtrlShiftF12";
  sortpriority=57;
  action = function() test_polygon(true) end;
}

Macro {
  description="Test plugin LF Search";
  area="Shell"; key="CtrlShiftF12";
  sortpriority=58;
  action = function() test_lfsearch(true) end;
}

Macro {
  description="Test ALL";
  area="Shell"; key="CtrlShiftF12";
  sortpriority=60;
  action=function()
    test_macroengine()
    test_lfsearch()
    test_polygon()
    far.Message("PASS", "ALL tests")
  end;
}
