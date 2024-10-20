local State

local function test_macroengine_interactive(mod)
  local sd = require "far2.simpledialog"
  local items = { width=0; {tp="dbox"; text="Macro tests";} }
  local t = {}
  for nm in pairs(mod) do
    if nm ~= "test_all" then t[#t+1] = nm; end
  end
  table.sort(t)
  for _, nm in ipairs(t) do
    local it = { tp="chbox"; text=nm; name=nm; val=State and State[nm]; }
    table.insert(items, it)
  end
  local out = sd.New(items):Run()
  if out then
    State = out
    local t = {}
    for nm in pairs(out) do
      if out[nm] then t[#t+1] = nm; end
    end
    table.sort(t)
    for _,nm in ipairs(t) do mod[nm]() end
    return true
  end
end

local function test_macroengine(verbose)
  far.Message("Please wait...", "Test macro engine", "")
  Far.DisableHistory(0x0F)
  local fname = far.PluginStartupInfo().ShareDir .. "/macrotest.lua"
  local f = assert(loadfile(fname))
  local mod = setfenv(f, getfenv())()
  local show_msg = (verbose ~= 0)
  if verbose==0 or verbose==1 then
    if mod and mod.test_all then mod.test_all(); end
  elseif verbose == 2 then
    show_msg = test_macroengine_interactive(mod)
    actl.RedrawAll()
  end
  if show_msg then far.Message("PASS", "Macro engine tests"); end
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

local function test_sqlarc(verbose)
  local guid = 0xF309DDDB
  local libname = "far2.test.test_sqlarc"
  assert(Plugin.Exist(guid), "Plugin not found")
  far.Message("Please wait...", "Test Sqlarc", "")
  Far.DisableHistory(0x0F)
  package.loaded[libname] = nil -- for debug
  require(libname).test_all()
  if verbose then far.Message("PASS", "Sqlarc tests"); end
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

local function test_hexed(verbose)
  far.Message("Please wait...", "Test Hex Editor", "")
  local test = require "far2.test.test_hexed"
  test()
  if verbose then
    far.Message("PASS", "Hex Editor tests")
  end
end

Macro {
  description="Test macro engine";
  area="Shell"; key="CtrlShiftF12";
  sortpriority=59;
  action = function() test_macroengine(1) end;
}

Macro {
  description="Test macro engine (interactive)";
  area="Shell"; key="CtrlShiftF12";
  sortpriority=10;
  action = function() test_macroengine(2) end;
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
  description="Test plugin Sqlarc";
  area="Shell"; key="CtrlShiftF12";
  sortpriority=50;
  action = function() test_sqlarc(true) end;
}

Macro {
  description="Test Hex Editor";
  area="Shell"; key="CtrlShiftF12";
  sortpriority=40;
  action = function() test_hexed(true) end;
}

Macro {
  description="Test ALL";
  area="Shell"; key="CtrlShiftF12";
  sortpriority=60;
  action=function()
    test_macroengine(0)
    test_lfsearch()
    test_polygon()
    test_sqlarc()
    test_hexed()
    far.Message("PASS", "ALL tests")
  end;
}
