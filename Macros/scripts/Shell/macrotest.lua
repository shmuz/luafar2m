local F = far.Flags
local State

local function select_tests(mod)
  local sd = require "far2.simpledialog"
  local items = {
    width=45;
    {tp="dbox"; text="Macro tests"; },
  }

  local t = {}
  for nm in pairs(mod) do
    if nm ~= "test_all" then t[#t+1] = nm; end
  end
  table.sort(t, function(a,b) return utf8.ncasecmp(a,b) < 0 end)
  for _, nm in ipairs(t) do
    local it = { tp="chbox"; text=nm; name=nm; val=State and State[nm]; }
    table.insert(items, it)
  end

  table.insert(items, {tp="sep"})
  table.insert(items, {tp="butt"; text="&Run"; centergroup=1; default=1; })
  table.insert(items, {tp="butt"; text="&Clear"; centergroup=1;  btnnoclose=1; y1=""; name="clear" })
  table.insert(items, {tp="butt"; text="&Invert"; centergroup=1; btnnoclose=1; y1=""; name="invert" })

  local Dlg = sd.New(items)
  local Pos = Dlg:Indexes()

  items.proc = function(hDlg, msg, p1, p2)
    if msg==F.DN_BTNCLICK then
      for i=1,#items do
        if items[i].tp=="chbox" then
          if p1==Pos.clear then hDlg:SetCheck(i, false)
          elseif p1==Pos.invert then hDlg:SetCheck(i, hDlg:GetCheck(i)==0)
          end
        end
      end
    end
  end

  local out = Dlg:Run()
  if out then
    State = out
    local t = {}
    for nm in pairs(out) do
      if out[nm] then t[#t+1] = nm; end
    end
    table.sort(t)
    return t
  end
end

local function test_macroengine(interactive, verbose)
  local WaitMsg = function() far.Message("Please wait...", "Test macro engine", "") end
  local PassMsg = function() far.Message("PASS", "Macro engine tests") end

  Far.DisableHistory(0x0F)
  local mod = require "far2.test.macrotest"
  if interactive then
    local tests = select_tests(mod)
    if tests then
      WaitMsg()
      for _,nm in ipairs(tests) do mod[nm]() end
      actl.Commit() -- clear WaitMsg
      if verbose then PassMsg() end
    end
  else
    assert(mod.test_all, "function test_all not found")
    WaitMsg()
    mod.test_all()
    if verbose then PassMsg() end
  end
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
  test("CtrlF4")
  if verbose then
    far.Message("PASS", "Hex Editor tests")
  end
end

Macro {
  id="B7B0B120-A616-4CBF-AB83-34E2EC024083";
  id="8E8048B3-CC62-4D73-80AD-46941BFD655C";
  description="Test macro engine";
  area="Shell"; key="CtrlShiftF12";
  sortpriority=59;
  action = function() test_macroengine(false,true) end;
}

Macro {
  id="C003453B-A808-4BE3-B384-3E9BB732D4AC";
  id="92189F85-1E54-4F59-A450-2CA6FF2B7D28";
  description="Test macro engine (interactive)";
  area="Shell"; key="CtrlShiftF12";
  sortpriority=10;
  action = function() test_macroengine(true,true) end;
}

Macro {
  id="FBD67701-0158-4191-8C4F-A5C174680BEB";
  id="4310629D-5422-4F95-AB80-52D3E071AD7B";
  description="Test plugin Polygon";
  area="Shell"; key="CtrlShiftF12";
  sortpriority=57;
  action = function() test_polygon(true) end;
}

Macro {
  id="38147368-BE34-4556-840C-D2837A91C129";
  id="0A4FA7FF-7A30-461A-B7F5-4C764617C872";
  description="Test plugin LF Search";
  area="Shell"; key="CtrlShiftF12";
  sortpriority=58;
  action = function() test_lfsearch(true) end;
}

Macro {
  id="F5922F72-C7F8-4E53-A95F-AA86270B124D";
  id="4F89DA2D-714E-4A7E-831E-8CDF19DA14CF";
  description="Test plugin Sqlarc";
  area="Shell"; key="CtrlShiftF12";
  sortpriority=50;
  action = function() test_sqlarc(true) end;
}

if jit then
  Macro {
    id="FC08C387-41CE-47CC-9D43-05E775E6CC3C";
    id="03520D97-0F40-493A-9253-401023F3A7BE";
    description="Test Hex Editor";
    area="Shell"; key="CtrlShiftF12";
    sortpriority=40;
    action = function() test_hexed(true) end;
  }
end

Macro {
  id="5838EF38-4EB6-4104-BD41-EE80124827E6";
  id="4A6BD1F8-7782-47ED-89CD-871D26D73135";
  description="Test ALL";
  area="Shell"; key="CtrlShiftF12";
  sortpriority=60;
  action=function()
    test_macroengine(false,false)
    test_lfsearch()
    test_polygon()
    test_sqlarc()
    if jit then test_hexed() end
    far.Message("PASS", "ALL tests")
  end;
}
