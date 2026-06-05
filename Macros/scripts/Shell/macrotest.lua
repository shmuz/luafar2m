-- Keys for running the macros
local MacroKeys = "CtrlShiftF12 RCtrlShiftF12"
local CommonKey = MacroKeys:match("%S+")

-- Required libraries
local Libs = {
  simpledialog = "far2.simpledialog";
  macrotest    = "far2.test.macrotest";
  test_polygon = "far2.test.test_polygon";
  test_sqlarc  = "far2.test.test_sqlarc";
  test_hexed   = "far2.test.test_hexed";
}

local F = far.Flags
local TestSet

local function PleaseWait(title)
  far.Message("Please wait...", title, "")
end

local function PassMessage(title)
  far.Message("PASS", title)
end

local function select_tests(mod)
  local sd = require(Libs.simpledialog)
  local items = {
    width=45;
    {tp="dbox"; text="Macro tests"; },
  }

  local t = {}
  for nm in pairs(mod) do
    if nm ~= "test_all" and nm ~= "SetMacroKeys" then
      t[#t+1] = nm;
    end
  end
  table.sort(t, function(a,b) return utf8.ncasecmp(a,b) < 0 end)
  for _, nm in ipairs(t) do
    local it = { tp="chbox"; text=nm; name=nm; val=TestSet and TestSet[nm]; }
    table.insert(items, it)
  end

  table.insert(items, {tp="sep"})
  table.insert(items, {tp="butt"; text="&Run"; centergroup=1; default=1; name="run"; })
  table.insert(items, {tp="butt"; text="&Clear"; centergroup=1;  btnnoclose=1; y1=""; name="clear" })
  table.insert(items, {tp="butt"; text="&Invert"; centergroup=1; btnnoclose=1; y1=""; name="invert" })

  local Dlg = sd.New(items)
  local Pos = Dlg:Indexes()

  items.proc = function(hDlg, msg, p1, p2)
    if msg == F.DN_BTNCLICK then
      if p1 == Pos.clear or p1 == Pos.invert then
        local flag = (p1 == Pos.clear) and F.BSTATE_UNCHECKED or F.BSTATE_TOGGLE
        for i=1,#items do
          if items[i].tp == "chbox" then hDlg:SetCheck(i, flag); end
        end
        hDlg:SetFocus(Pos.run)
      end
    end
  end

  local out = Dlg:Run()
  if out then
    TestSet = out
    local arr = {}
    for nm in pairs(out) do
      if out[nm] then arr[#arr+1] = nm; end
    end
    table.sort(arr)
    return arr
  end
end

local function test_macroengine(interactive, verbose)
  local WaitMsg = function() PleaseWait("Test macro engine") end
  local PassMsg = function() PassMessage("Macro engine tests") end

  mf.AddExitHandler(panel.SetPanelDirectory, nil, 1, panel.GetPanelDirectory(nil,1))
  Far.DisableHistory(0x0F)

  local mod = require(Libs.macrotest)
  mod.SetMacroKeys(MacroKeys)

  if interactive then
    local tests = select_tests(mod)
    if tests then
      WaitMsg()
      for _,nm in ipairs(tests) do
        local tp = type(mod[nm])
        local func = tp=="function" and mod[nm] or tp=="table" and mod[nm].test_all
        func()
      end
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
  local libname = Libs.test_polygon
  assert(Plugin.Exist(guid), "Plugin not found")
  PleaseWait("Test Polygon")
  Far.DisableHistory(0x0F)
  package.loaded[libname] = nil -- for debug
  require(libname).test_all()
  if verbose then PassMessage("Polygon tests"); end
  panel.RedrawPanel(nil,0)
  panel.RedrawPanel(nil,1)
end

local function test_sqlarc(verbose)
  local guid = 0xF309DDDB
  local libname = Libs.test_sqlarc
  assert(Plugin.Exist(guid), "Plugin not found")
  PleaseWait("Test Sqlarc")
  Far.DisableHistory(0x0F)
  package.loaded[libname] = nil -- for debug
  require(libname).test_all()
  if verbose then PassMessage("Sqlarc tests"); end
end

local function test_lfsearch(verbose)
  Far.DisableHistory(0x0F)
  local guid = 0x8E11EA75
  assert(Plugin.Exist(guid), "Plugin not found")
  PleaseWait("Test LF Search")
  Plugin.Command(guid, "test")
  assert(Area.Shell, "LF Search tests failed")
  if verbose then
    PassMessage("LF Search tests")
  end
end

local function test_hexed(verbose)
  PleaseWait("Test Hex Editor")
  local test = require(Libs.test_hexed)
  test("CtrlF4")
  if verbose then
    PassMessage("Hex Editor tests")
  end
end

local function test_farapi_lua(verbose)
  PleaseWait("Test farapi.lua")
  local root = os.getenv("HOME") .. "/repos/far2m"
  local script  = root .. "/luamacro/farapi/make_farapi.lua"
  local oldfile = root .. "/luafar/lua_share/far2/farapi.lua"
  local newfile = "/tmp/far2m_farapi.lua"
  local fp, strOld, strNew

  assert (loadfile(script)) (newfile)

  fp = assert(io.open(oldfile))
  strOld = fp:read("*all")
  fp:close()
  fp = assert(io.open(newfile))
  strNew = fp:read("*all")
  fp:close()
  assert(strOld == strNew, "Test farapi.lua failed")

  if verbose then
    PassMessage("Test farapi.lua")
  end
  for k=0,1 do panel.RedrawPanel(nil,k) end
end

Macro {
  id="B7B0B120-A616-4CBF-AB83-34E2EC024083";
  description="Test macro engine";
  area="Shell"; key=CommonKey;
  sortpriority=59;
  action = function() test_macroengine(false,true) end;
}

Macro {
  id="C003453B-A808-4BE3-B384-3E9BB732D4AC";
  description="Test macro engine (interactive)";
  area="Shell"; key=CommonKey;
  sortpriority=10;
  action = function() test_macroengine(true,true) end;
}

Macro {
  id="FBD67701-0158-4191-8C4F-A5C174680BEB";
  description="Test plugin Polygon";
  area="Shell"; key=CommonKey;
  sortpriority=57;
  action = function() test_polygon(true) end;
}

Macro {
  id="38147368-BE34-4556-840C-D2837A91C129";
  description="Test plugin LF Search";
  area="Shell"; key=CommonKey;
  sortpriority=58;
  action = function() test_lfsearch(true) end;
}

Macro {
  id="F5922F72-C7F8-4E53-A95F-AA86270B124D";
  description="Test plugin Sqlarc";
  area="Shell"; key=CommonKey;
  sortpriority=50;
  action = function() test_sqlarc(true) end;
}

if jit then
  Macro {
    id="FC08C387-41CE-47CC-9D43-05E775E6CC3C";
    description="Test Hex Editor";
    area="Shell"; key=CommonKey;
    sortpriority=40;
    action = function() test_hexed(true) end;
  }
end

Macro {
  id="0BD88546-AA06-4569-A80D-0E9EEAC2CB7B";
  description="Test farapi.lua";
  area="Shell"; key=CommonKey;
  sortpriority=15;
  action=function() test_farapi_lua(true) end;
}

Macro {
  id="5838EF38-4EB6-4104-BD41-EE80124827E6";
  description="Test ALL";
  area="Shell"; key=CommonKey;
  sortpriority=60;
  action=function()
    test_macroengine(false,false)
    test_lfsearch()
    test_polygon()
    test_sqlarc()
    test_farapi_lua()
    if jit then test_hexed() end
    PassMessage("ALL tests")
  end;
}
