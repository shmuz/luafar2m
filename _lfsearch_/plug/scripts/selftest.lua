-- coding: utf-8
-- started: 2009-12-04 by Shmuel Zeigerman
-- luacheck: read_globals lfsearch

local F = far.Flags
local russian_alphabet_utf8 = "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдеёжзийклмнопрстуфхцчшщъыьэюя"

local function fReturnAll() return "all" end
local function fReturnYes() return "yes" end

local function OpenHelperEditor()
  local ret = editor.Editor ("/tmp/lfsearch.tmp", nil, nil,nil,nil,nil,
              {EF_NONMODAL=1, EF_IMMEDIATERETURN=1, EF_CREATENEW=1}, 0, 0)
  assert (ret == F.EEC_MODIFIED, "could not open file")
end

local function CloseHelperEditor()
  editor.Quit()
  actl.Commit()
end

local function ProtectedError(msg, level)
  CloseHelperEditor()
  error(msg, level)
end

local function ProtectedAssert(condition, msg)
  if not condition then ProtectedError(msg or "assertion failed") end
end

local function GetEditorText()
  local t = {}
  editor.SetPosition(1,1)
  for i=1, editor.GetInfo().TotalLines do t[i]=editor.GetString(i, 2) end
  return table.concat(t, "\r")
end

local function SetEditorText(str)
  editor.SetPosition(1,1)
  for _=1, editor.GetInfo().TotalLines do editor.DeleteString() end
  editor.InsertText(str)
end

local function AssertEditorText(ref, msg)
  ProtectedAssert(GetEditorText()==ref, msg)
end

local function TestEditorAction(aLibs)

  local function RunEditorAction(lib, op, data, refFound, refReps)
    data.sRegexLib = lib
    editor.SetPosition(data.CurLine or 1, data.CurPos or 1)
    local nFound, nReps = lfsearch.EditorAction(op, data)
    if nFound ~= refFound or nReps ~= refReps then
      ProtectedError(
        "nFound="        .. nFound..
        "; refFound="    .. refFound..
        "; nReps="       .. nReps..
        "; refReps="     .. refReps..
        "; sRegexLib="   .. tostring(data.sRegexLib)..
        "; bCaseSens="   .. tostring(data.bCaseSens)..
        "; bRegExpr="    .. tostring(data.bRegExpr)..
        "; bWholeWords=" .. tostring(data.bWholeWords)..
        "; bExtended="   .. tostring(data.bExtended)..
        "; bSearchBack=" .. tostring(data.bSearchBack)..
        "; sScope="      .. tostring(data.sScope)..
        "; sOrigin="     .. tostring(data.sOrigin)
      )
    end
  end

  local function test_Switches(lib)
    SetEditorText("line1\rline2\rline3\rline4\r")
    local dt = { CurLine=2, CurPos=2 }
    local lua0, lua1
    if lib == "lua" then lua0, lua1 = 0, 1 else lua0, lua1 = 1, 0 end

    for k1=lua1,1 do dt.bCaseSens   = (k1==1)
    for k2=0,1    do dt.bRegExpr    = (k2==1)
    for k3=0,lua0 do dt.bWholeWords = (k3==1)
    for k4=0,1    do dt.bExtended   = (k4==1)
    for k5=0,1    do dt.bSearchBack = (k5==1)
    for k6=0,1    do dt.sOrigin     = (k6==1 and "scope" or nil)
      local bEnable
      ---------------------------------
      dt.sSearchPat = "a"
      RunEditorAction(lib, "test:search", dt, 0, 0)
      RunEditorAction(lib, "test:count",  dt, 0, 0)
      ---------------------------------
      dt.sSearchPat = "line"
      bEnable = dt.bRegExpr or not dt.bWholeWords
      RunEditorAction(lib, "test:search", dt, bEnable and 1 or 0, 0)
      RunEditorAction(lib, "test:count",  dt, bEnable and (dt.sOrigin=="scope" and 4 or
                 dt.bSearchBack and 1 or 2) or 0, 0)
      ---------------------------------
      dt.sSearchPat = "LiNe"
      bEnable = (dt.bRegExpr or not dt.bWholeWords) and not dt.bCaseSens
      RunEditorAction(lib, "test:search", dt, bEnable and 1 or 0, 0)
      RunEditorAction(lib, "test:count",  dt, bEnable and (dt.sOrigin=="scope" and 4 or
                 dt.bSearchBack and 1 or 2) or 0, 0)
      ---------------------------------
      dt.sSearchPat = "."
      bEnable = dt.bRegExpr
      RunEditorAction(lib, "test:search", dt, bEnable and 1 or 0, 0)
      RunEditorAction(lib, "test:count", dt, bEnable and (dt.sOrigin=="scope" and 20 or
        dt.bSearchBack and 6 or 14) or 0, 0)
      ---------------------------------
      dt.sSearchPat = " . "
      bEnable = dt.bRegExpr and dt.bExtended
      RunEditorAction(lib, "test:search", dt, bEnable and 1 or 0, 0)
      RunEditorAction(lib, "test:count", dt, bEnable and (dt.sOrigin=="scope" and 20 or
        dt.bSearchBack and 6 or 14) or 0, 0)
      ---------------------------------
    end end end end end end
  end

  local function test_LineFilter(lib)
    SetEditorText("line1\rline2\rline3\r")
    local dt = { sSearchPat="line" }

    RunEditorAction(lib, "test:search", dt, 1, 0)
    RunEditorAction(lib, "test:count",  dt, 3, 0)

    dt.bAdvanced = true
    dt.sFilterFunc = "  "
    RunEditorAction(lib, "test:search", dt, 1, 0)
    RunEditorAction(lib, "test:count",  dt, 3, 0)

    dt.sFilterFunc = "return"
    RunEditorAction(lib, "test:search", dt, 1, 0)
    RunEditorAction(lib, "test:count",  dt, 3, 0)

    dt.sFilterFunc = " return true "
    RunEditorAction(lib, "test:search", dt, 0, 0)
    RunEditorAction(lib, "test:count",  dt, 0, 0)

    dt.sFilterFunc = "return n == 2"
    RunEditorAction(lib, "test:search", dt, 1, 0)
    RunEditorAction(lib, "test:count",  dt, 2, 0)

    dt.sFilterFunc = "return not rex.find(s, '[13]')"
    RunEditorAction(lib, "test:search", dt, 1, 0)
    RunEditorAction(lib, "test:count",  dt, 2, 0)

    dt.sInitFunc = "Var1,Var2 = 'line2','line3'"
    dt.sFilterFunc = "return not(s==Var1 or s==Var2)"
    dt.sFinalFunc = "assert(Var1=='line2')"
    RunEditorAction(lib, "test:search", dt, 1, 0)
    RunEditorAction(lib, "test:count",  dt, 2, 0)

    dt.sInitFunc = nil
    dt.sFinalFunc = "assert(Var1==nil)"
    RunEditorAction(lib, "test:search", dt, 0, 0)
    RunEditorAction(lib, "test:count",  dt, 0, 0)
  end

  local function test_Replace(lib)
    for k=0,1 do
    -- test "user choice function"
      SetEditorText("line1\rline2\rline3\r")
      local dt = { sSearchPat=".", sReplacePat="$0", bRegExpr=true }
      dt.bSearchBack = (k==1)
      dt.sOrigin = "scope"
      for _,ch in ipairs {"yes","all","no","cancel"} do
        local cnt = 0
        dt.fUserChoiceFunc = function() cnt=cnt+1; return ch end
        RunEditorAction(lib, "test:replace", dt,
          ch=="cancel" and 1 or 15, (ch=="yes" or ch=="all") and 15 or 0)
        ProtectedAssert(
          (ch=="yes" or ch=="no") and cnt==15 or
          (ch=="all" or ch=="cancel") and cnt==1)
      end

      -- test empty replace
      dt = { sSearchPat="l", sReplacePat="", fUserChoiceFunc=fReturnAll }
      dt.bSearchBack = (k==1)
      dt.sOrigin = "scope"
      SetEditorText("line1\rline2\rline3\r")
      RunEditorAction(lib, "test:replace", dt, 3, 3)
      AssertEditorText("ine1\rine2\rine3\r")

      -- test non-empty replace
      dt = { sSearchPat="l", sReplacePat="LL", fUserChoiceFunc=fReturnAll }
      dt.bSearchBack = (k==1)
      dt.sOrigin = "scope"
      SetEditorText("line1\rline2\rline3\r")
      RunEditorAction(lib, "test:replace", dt, 3, 3)
      AssertEditorText("LLine1\rLLine2\rLLine3\r")

      -- test replace from cursor
      dt = { sSearchPat="l", sReplacePat="LL", CurPos=2, fUserChoiceFunc=fReturnAll }
      dt.bSearchBack = (k==1)
      SetEditorText("line1\rline2\rline3\r")
      if dt.bSearchBack then
        RunEditorAction(lib, "test:replace", dt, 1, 1)
        AssertEditorText("LLine1\rline2\rline3\r")
      else
        RunEditorAction(lib, "test:replace", dt, 2, 2)
        AssertEditorText("line1\rLLine2\rLLine3\r")
      end

      -- test submatches (captures)
      dt = { sSearchPat="(.)(.)(.)(.)(.)(.)(.)(.)(.)(.)(.)(.)(.)(.)(.)",
             sReplacePat="-$F-$E-$D-$C-$B-$A-$9-$8-$7-$6-$5-$4-$3-$2-$1-$0-",
             bRegExpr=true, fUserChoiceFunc=fReturnYes }
      dt.bSearchBack = (k==1)
      dt.sOrigin = "scope"
      local subj = "abcdefghijklmno1234"
      SetEditorText(subj)
      RunEditorAction(lib, "test:replace", dt, 1, 1)
      if dt.bSearchBack then
        AssertEditorText(dt.bSearchBack and
          "abcd-4-3-2-1-o-n-m-l-k-j-i-h-g-f-e-efghijklmno1234-" or
          "-o-n-m-l-k-j-i-h-g-f-e-d-c-b-a-abcdefghijklmno-1234")
      end

      -- test escaped dollar and backslash
      dt = { sSearchPat="abc", sReplacePat=[[$0\$0\t\\t]], bRegExpr=true,
             fUserChoiceFunc=fReturnYes }
      dt.bSearchBack = (k==1)
      dt.sOrigin = "scope"
      SetEditorText("abc")
      RunEditorAction(lib, "test:replace", dt, 1, 1)
      AssertEditorText("abc$0\t\\t")
    end

    -- test escape sequences in replace pattern
    local dt = { sSearchPat="b", sReplacePat=[[\a\e\f\n\r\t]], bRegExpr=true }
    for i=0,127 do dt.sReplacePat = dt.sReplacePat .. ("\\x%x"):format(i) end
    dt.fUserChoiceFunc = fReturnYes
    SetEditorText("abc")
    RunEditorAction(lib, "test:replace", dt, 1, 1)
    local result = "a\7\27\12\13\13\9"
    for i=0,127 do result = result .. string.char(i) end
    result = result:gsub("\10", "\13", 1) .. "c"
    AssertEditorText(result)

    -- test text case modifiers
    dt = { sSearchPat="abAB",
      sReplacePat=[[\l$0 \u$0 \L$0\E $0 \U$0\E $0 \L\u$0\E \U\l$0\E \L\U$0\E$0\E]],
      bRegExpr=true, fUserChoiceFunc=fReturnYes }
    SetEditorText("abAB")
    RunEditorAction(lib, "test:replace", dt, 1, 1)
    AssertEditorText("abAB AbAB abab abAB ABAB abAB Abab aBAB ABABabab")

    -- test counter
    dt = { sSearchPat=".+", sReplacePat=[[\R$0]], bRegExpr=true,
           fUserChoiceFunc=fReturnAll }
    SetEditorText("a\rb\rc\rd\re\rf\rg\rh\ri\rj\r")
    RunEditorAction(lib, "test:replace", dt, 10, 10)
    AssertEditorText("1a\r2b\r3c\r4d\r5e\r6f\r7g\r8h\r9i\r10j\r")
    --------
    dt.sReplacePat=[[\R{-5}$0]]
    SetEditorText("a\rb\rc\rd\re\rf\rg\rh\ri\rj\r")
    RunEditorAction(lib, "test:replace", dt, 10, 10)
    AssertEditorText("-5a\r-4b\r-3c\r-2d\r-1e\r0f\r1g\r2h\r3i\r4j\r")
    --------
    dt.sReplacePat=[[\R{5,3}$0]]
    SetEditorText("a\rb\rc\rd\re\rf\rg\rh\ri\rj\r")
    RunEditorAction(lib, "test:replace", dt, 10, 10)
    AssertEditorText("005a\r006b\r007c\r008d\r009e\r010f\r011g\r012h\r013i\r014j\r")

    -- test replace in selection
    dt = { sSearchPat="in", sReplacePat="###", sScope="block" }
    dt.fUserChoiceFunc = fReturnAll
    SetEditorText("line1\rline2\rline3\rline4\r")
    editor.Select("BTYPE_STREAM",2,1,-1,2)
    RunEditorAction(lib, "test:replace", dt, 2, 2)
    AssertEditorText("line1\rl###e2\rl###e3\rline4\r")
    --------
    dt = { sSearchPat=".+", sReplacePat="###", sScope="block", bRegExpr=true }
    dt.fUserChoiceFunc = fReturnAll
    SetEditorText("line1\rline2\rline3\rline4\r")
    editor.Select("BTYPE_COLUMN",2,2,2,2)
    RunEditorAction(lib, "test:replace", dt, 2, 2)
    AssertEditorText("line1\rl###e2\rl###e3\rline4\r")

    -- test "function mode"
    dt = { sSearchPat="(.)(.)(.)(.)(.)(.)(.)(.)(.)", bRepIsFunc=true,
           bRegExpr=true, fUserChoiceFunc=fReturnAll, sReplacePat=
           "V=(V or 1)*3;return V..T[9]..T[8]..T[7]..T[6]..T[5]..T[4]..T[3]..T[2]..T[1]"
    }
    SetEditorText("abcdefghiabcdefghiabcdefghi")
    RunEditorAction(lib, "test:replace", dt, 3, 3)
    AssertEditorText("3ihgfedcba9ihgfedcba27ihgfedcba")
    --------
    dt.sSearchPat = ".+"
    dt.sReplacePat = lib=="lua" and
      [[return T[0] .. '--' .. rex.match(T[0], '%d%d')]] or
      [[return T[0] .. '--' .. rex.match(T[0], '\\d\\d')]]
    RunEditorAction(lib, "test:replace", dt, 1, 1)
    AssertEditorText("3ihgfedcba9ihgfedcba27ihgfedcba--27")
    --------
    dt.sSearchPat = ".+"
    dt.sReplacePat = nil
    RunEditorAction(lib, "test:replace", dt, 1, 0)
    --------
    dt.sReplacePat = ""
    RunEditorAction(lib, "test:replace", dt, 1, 0)
    --------
    dt.sReplacePat = "return false"
    RunEditorAction(lib, "test:replace", dt, 1, 0)
    -------- test 1-st return == true
    dt = { bRepIsFunc=true, bRegExpr=true, fUserChoiceFunc=fReturnAll,
           sReplacePat=[[return R==2 or "string"]], }
    dt.sSearchPat = (lib=="lua") and "%D+" or "\\D+"
    SetEditorText("line1\rline2\rline3\r")
    RunEditorAction(lib, "test:replace", dt, 3, 3)
    AssertEditorText("string1\rstring3\r")

    -- test replace patterns containing \n or \r
    dt = { sSearchPat=".", sReplacePat="a\rb", bRegExpr=true }
    dt.fUserChoiceFunc=fReturnAll
    dt.sOrigin = "scope"
    for k=0,1 do
      dt.bSearchBack = (k==1)
      SetEditorText("L1\rL2\r")
      RunEditorAction(lib, "test:replace", dt, 4, 4)
      AssertEditorText("a\rba\rb\ra\rba\rb\r")
    end

    -- test "Delete empty line"
    dt = { sSearchPat=".*a.*", sReplacePat="", bRegExpr=true }
    dt.fUserChoiceFunc=fReturnAll
    dt.sOrigin = "scope"
    dt.bDelEmptyLine = true
    for k=0,1 do
      dt.bSearchBack = (k==1)
      SetEditorText("foo1\rbar1\rfoo2\rbar2\rfoo3\rbar3\r")
      RunEditorAction(lib, "test:replace", dt, 3, 3)
      AssertEditorText("foo1\rfoo2\rfoo3\r")
    end
    dt.sScope = "block"
    for k=0,1 do
      dt.bSearchBack = (k==1)
      SetEditorText("foo1\rbar1\rfoo2\rbar2\rfoo3\rbar3\rfoo4\rbar4\r")
      editor.Select("BTYPE_STREAM",3,1,-1,4)
      RunEditorAction(lib, "test:replace", dt, 2, 2)
      AssertEditorText("foo1\rbar1\rfoo2\rfoo3\rfoo4\rbar4\r")
    end

    -- test named groups
    if lib=="oniguruma" or lib=="pcre" then
      dt = { sSearchPat="(?<foo>\\w+)(?<space>\\s+)(?<bar>\\w+)",
             sReplacePat="${bar}${space}${foo}",
             bRegExpr=true,
             sOrigin="scope",
             fUserChoiceFunc=fReturnAll, }
      for k=0,1 do
        dt.bSearchBack = (k==1)
        SetEditorText("@@@ word1  \t\t  WORD2 @@@")
        RunEditorAction(lib, "test:replace", dt, 1, 1)
        AssertEditorText("@@@ WORD2  \t\t  word1 @@@")

        dt.bRepIsFunc = true
        dt.sReplacePat = "return T.bar .. T.space .. T.foo"
        SetEditorText("@@@ word1  \t\t  WORD2 @@@")
        RunEditorAction(lib, "test:replace", dt, 1, 1)
        AssertEditorText("@@@ WORD2  \t\t  word1 @@@")
      end
    end
  end

  local function test_Encodings(lib)
    local dt = { bRegExpr=true, fUserChoiceFunc=fReturnAll }
    dt.sSearchPat = (lib == "lua") and "%w+" or "\\w+"
    --------
    SetEditorText(russian_alphabet_utf8)
    dt.sReplacePat = ""
    RunEditorAction(lib, "test:replace", dt, 1, 1)
    AssertEditorText("")
    --------
    SetEditorText(russian_alphabet_utf8)
    dt.sReplacePat = "\\L$0"
    RunEditorAction(lib, "test:replace", dt, 1, 1)
    local s = GetEditorText()
    ProtectedAssert(s:sub(1,33)==s:sub(34))
    --------
    SetEditorText(russian_alphabet_utf8)
    dt.sReplacePat = "\\U$0"
    RunEditorAction(lib, "test:replace", dt, 1, 1)
    s = GetEditorText()
    ProtectedAssert(s:sub(1,33)==s:sub(34))
    --------
  end

  local function test_bug_20090208(lib)
    local dt = { bRegExpr=true, sReplacePat="\n$0",
                 sScope="block", fUserChoiceFunc=fReturnAll }
    dt.sSearchPat = (lib == "lua") and "%w+" or "\\w+"
    SetEditorText(("my table\r"):rep(5))
    editor.Select("BTYPE_STREAM",2,1,-1,2)
    RunEditorAction(lib, "test:replace", dt, 4, 4)
    AssertEditorText("my table\r\rmy \rtable\r\rmy \rtable\rmy table\rmy table\r")
  end

  local function test_EmptyMatch(lib)
    local dt = { bRegExpr=true, sSearchPat=".*?", sReplacePat="-",
                 fUserChoiceFunc = fReturnAll }
    dt.sSearchPat = (lib == "lua") and ".-" or ".*?"
    SetEditorText(("line1\rline2\r"))
    RunEditorAction(lib, "test:replace", dt, 13, 13)
    AssertEditorText("-l-i-n-e-1-\r-l-i-n-e-2-\r-")

    dt.sSearchPat, dt.sReplacePat = ".*", "1. $0"
    SetEditorText(("line1\rline2\r"))
    RunEditorAction(lib, "test:replace", dt, 3, 3)
    AssertEditorText("1. line1\r1. line2\r1. ")
  end

  local function test_Anchors(lib)
    local dt = { bRegExpr=true, sOrigin="scope" }
    SetEditorText("line\rline\r")
    for k1 = 0, 1 do dt.sSearchPat = (k1 == 0) and "^." or ".$"
    for k2 = 0, 1 do dt.bSearchBack = (k2 == 1)
      RunEditorAction(lib, "test:count", dt, 2, 0)
    end end
  end

  if type(aLibs) ~= "table" then aLibs = { "far" } end
  OpenHelperEditor()
  for _,lib in ipairs(aLibs) do
    test_Switches     (lib)
    test_LineFilter   (lib)
    test_Replace      (lib)
    test_Encodings    (lib)
    test_Anchors      (lib)
    test_EmptyMatch   (lib)
    test_bug_20090208 (lib)
  end
  CloseHelperEditor()
  lfsearch.EditorAction("test:search", {})  -- reset history

end -- ### MARKER

local function TestMReplaceEditorAction(aLibs)

  local function RunEditorAction(lib, op, data, refFound, refReps)
    data.sRegexLib = lib
    if not data.KeepCurPos then
      editor.SetPosition(data.CurLine or 1, data.CurPos or 1)
    end
    local nFound, nReps = lfsearch.MReplaceEditorAction(op, data)
    if nFound ~= refFound or nReps ~= refReps then
      ProtectedError(
        "nFound="        .. tostring(nFound)..
        "; refFound="    .. tostring(refFound)..
        "; nReps="       .. tostring(nReps)..
        "; refReps="     .. tostring(refReps)..
        "; sRegexLib="   .. tostring(data.sRegexLib)..
        "; bCaseSens="   .. tostring(data.bCaseSens)..
        "; bRegExpr="    .. tostring(data.bRegExpr)..
        "; bWholeWords=" .. tostring(data.bWholeWords)..
        "; bExtended="   .. tostring(data.bExtended)..
        "; bFileAsLine=" .. tostring(data.bFileAsLine)..
        "; bMultiLine="  .. tostring(data.bMultiLine)
      )
    end
  end

  local function test_Switches (lib)
    SetEditorText("line1\nline2\nline3\nline4\n")
    local dt = {}

    for k1=0,1    do dt.bCaseSens   = (k1==1)
    for k2=0,1    do dt.bRegExpr    = (k2==1)
    for k3=0,1    do dt.bWholeWords = (k3==1)
    for k4=0,1    do dt.bExtended   = (k4==1)
    for k5=0,1    do dt.bFileAsLine = (k5==1)
    for k6=0,1    do dt.bMultiLine  = (k6==1)
      local bEnable
      ---------------------------------
      dt.sSearchPat = "a"
      RunEditorAction(lib, "count",  dt, 0, 0)
      ---------------------------------
      dt.sSearchPat = "line"
      bEnable = dt.bRegExpr or not dt.bWholeWords
      RunEditorAction(lib, "count",  dt, bEnable and 4 or 0, 0)
      ---------------------------------
      dt.sSearchPat = "LiNe"
      bEnable = (dt.bRegExpr or not dt.bWholeWords) and not dt.bCaseSens
      RunEditorAction(lib, "count",  dt, bEnable and 4 or 0, 0)
      ---------------------------------
      dt.sSearchPat = "."
      bEnable = dt.bRegExpr
      RunEditorAction(lib, "count", dt, bEnable and (dt.bFileAsLine and 24 or 20) or 0, 0)
      ---------------------------------
      dt.sSearchPat = " . "
      bEnable = dt.bRegExpr and dt.bExtended
      RunEditorAction(lib, "count", dt, bEnable and (dt.bFileAsLine and 24 or 20) or 0, 0)
      ---------------------------------
      dt.sSearchPat = "^\\w+"
      bEnable = dt.bRegExpr
      RunEditorAction(lib, "count", dt, bEnable and (dt.bMultiLine and 4 or 1) or 0, 0)
      ---------------------------------
      dt.sSearchPat = "\\w+$"
      bEnable = dt.bRegExpr
      local nRef1 = lib=="far" and 0 or 1 -- see flag PCRE_DOLLAR_ENDONLY
      RunEditorAction(lib, "count", dt, bEnable and (dt.bMultiLine and 4 or nRef1) or 0, 0)
      ---------------------------------
    end end end end end end
  end

  local function test_Replace (lib)
    -- test empty replace
    local dt = { sSearchPat="l", sReplacePat="" }
    SetEditorText("line1\nline2\nline3\n")
    RunEditorAction(lib, "replace", dt, 3, 3)
    AssertEditorText("ine1\rine2\rine3\r")

    -- test non-empty replace
    dt = { sSearchPat="l", sReplacePat="LL" }
    SetEditorText("line1\nline2\nline3\n")
    RunEditorAction(lib, "replace", dt, 3, 3)
    AssertEditorText("LLine1\rLLine2\rLLine3\r")

    -- test submatches (captures)
    dt = { sSearchPat=("(.)"):rep(35),
           sReplacePat=("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"):reverse():gsub(".","$%0"),
           bRegExpr=true }
    local subj = "123456789abcdefghijklmnopqrstuvwxyz###"
    SetEditorText(subj)
    RunEditorAction(lib, "replace", dt, 1, 1)
    AssertEditorText(subj:sub(1,35):reverse() .. subj)

    -- test escaped dollar and backslash
    dt = { sSearchPat="abc", sReplacePat=[[$0\$0\t\\t]], bRegExpr=true }
    SetEditorText("abc")
    RunEditorAction(lib, "replace", dt, 1, 1)
    AssertEditorText("abc$0\t\\t")

    -- test escape sequences in replace pattern
    dt = { sSearchPat="b", sReplacePat=[[\a\e\f\n\r\t]], bRegExpr=true }
    for i=0,127 do dt.sReplacePat = dt.sReplacePat .. ("\\x%x"):format(i) end
    SetEditorText("abc")
    RunEditorAction(lib, "replace", dt, 1, 1)
    local result = "a\7\27\12\10\13\9"
    for i=0,127 do result = result .. string.char(i) end
    result = result:gsub("\n", "\r") .. "c"
    AssertEditorText(result)

    -- test replace in selection
    dt = { sSearchPat="in", sReplacePat="###", sScope="block" }
    SetEditorText("line1\rline2\rline3\rline4\r")
    editor.Select("BTYPE_STREAM",2,1,-1,2)
    RunEditorAction(lib, "replace", dt, 2, 2)
    AssertEditorText("line1\rl###e2\rl###e3\rline4\r")

    -- test replace patterns containing \n or \r
    dt = { sSearchPat=".", sReplacePat="a\nb", bRegExpr=true }
    dt.sOrigin = "scope"
    SetEditorText("L1\rL2\r")
    RunEditorAction(lib, "replace", dt, 4, 4)
    AssertEditorText("a\rba\rb\ra\rba\rb\r")

    -- test date/time insertion
    dt = { sSearchPat=".+", sReplacePat=[[\D{$ \n date is %Y-%m-%d : }$0]], bRegExpr=true }
    SetEditorText("line1\rline2\r")
    RunEditorAction(lib, "replace", dt, 2, 2)
    local ref = ("$ \\n date is %d%d%d%d%-%d%d%-%d%d : line%d\r"):rep(2)
    ProtectedAssert(GetEditorText():match(ref))

    -- test "function mode"
    dt = { sSearchPat=".+", bRepIsFunc=true, bRegExpr=true,
           sReplacePat=[[return M~=2 and ("%d.%d. %s"):format(M, R, T[0])]]
         }
    SetEditorText("line1\rline2\rline3\r")
    RunEditorAction(lib, "replace", dt, 3, 2)
    AssertEditorText("1.1. line1\rline2\r3.2. line3\r")
    --------
    dt = { sSearchPat="(.)(.)(.)(.)(.)(.)(.)(.)(.)", bRepIsFunc=true,
           bRegExpr=true,
           sReplacePat = "V=(V or 1)*3; return V..T[9]..T[8]..T[7]..T[6]..T[5]..T[4]..T[3]..T[2]..T[1]"
    }
    SetEditorText("abcdefghiabcdefghiabcdefghi")
    RunEditorAction(lib, "replace", dt, 3, 3)
    AssertEditorText("3ihgfedcba9ihgfedcba27ihgfedcba")
    --------
    dt.sSearchPat = ".+"
    dt.sReplacePat = [[return T[0] .. '--' .. rex.match(T[0], '\\d\\d')]]
    RunEditorAction(lib, "replace", dt, 1, 1)
    AssertEditorText("3ihgfedcba9ihgfedcba27ihgfedcba--27")
    --------
    dt.sReplacePat = ""
    RunEditorAction(lib, "replace", dt, 1, 0)
    --------
    dt.sReplacePat = "return false"
    RunEditorAction(lib, "replace", dt, 1, 0)

    -- test 2-nd return == true
    dt = { sSearchPat="[^\\d\\s]+", bRepIsFunc=true, bRegExpr=true,
           sReplacePat=[[return "string", R==2]]
         }
    SetEditorText("line1\rline2\rline3\r")
    RunEditorAction(lib, "replace", dt, 2, 2)
    AssertEditorText("string1\rstring2\rline3\r")
    ------------------------------------------------------------------------------
  end

  local function test_Encodings (lib)
    local dt = { bRegExpr=true }
    dt.sSearchPat = "\\w+"
    --------
    SetEditorText(russian_alphabet_utf8)
    dt.sReplacePat = ""
    RunEditorAction(lib, "replace", dt, 1, 1)
    AssertEditorText("")
    --------
    SetEditorText(russian_alphabet_utf8)
    dt.sReplacePat = "\\L$0"
    RunEditorAction(lib, "replace", dt, 1, 1)
    local s = GetEditorText()
    ProtectedAssert(s:sub(1,33)==s:sub(34))
    --------
    SetEditorText(russian_alphabet_utf8)
    dt.sReplacePat = "\\U$0"
    RunEditorAction(lib, "replace", dt, 1, 1)
    s = GetEditorText()
    ProtectedAssert(s:sub(1,33)==s:sub(34))
    --------
  end

  local function test_bug_20090208 (lib)
    local dt = { bRegExpr=true, sReplacePat="\n$0" }
    dt.sSearchPat = "\\w+"
    SetEditorText(("my table\r"):rep(5))
    editor.Select("BTYPE_STREAM",2,1,-1,2)
    RunEditorAction(lib, "replace", dt, 4, 4)
    AssertEditorText("my table\r\rmy \rtable\r\rmy \rtable\rmy table\rmy table\r")
  end

  local function test_bug_20100802 (lib)
    local dt = { bRegExpr=true, sReplacePat="", bMultiLine=true }
    SetEditorText("line1\rline2\r")
    dt.sSearchPat = "^."
    RunEditorAction(lib, "replace", dt, 2, 2)
    AssertEditorText("ine1\rine2\r")

    SetEditorText("line1\rline2\r")
    dt.sSearchPat = ".$"
    RunEditorAction(lib, "replace", dt, 2, 2)
    AssertEditorText("line\rline\r")
  end

  local function test_EmptyMatch (lib)
    local dt = { bRegExpr=true, sSearchPat=".*?", sReplacePat="-" }
    dt.sSearchPat = ".*?"
    SetEditorText(("line1\rline2\r"))
    RunEditorAction(lib, "replace", dt, 13, 13)
    AssertEditorText("-l-i-n-e-1-\r-l-i-n-e-2-\r-")

    dt.sSearchPat, dt.sReplacePat = ".*", "1. $0"
    SetEditorText(("line1\rline2\r"))
    RunEditorAction(lib, "replace", dt, 3, 3)
    AssertEditorText("1. line1\r1. line2\r1. ")
  end

  if type(aLibs) ~= "table" then aLibs = { "far" } end
  OpenHelperEditor()
  for _,lib in ipairs(aLibs) do
    if lib ~= "lua" then
      test_Switches     (lib)
      test_Replace      (lib)
      test_Encodings    (lib)
      test_bug_20090208 (lib)
      test_bug_20100802 (lib)
      test_EmptyMatch   (lib)
    end
  end
  CloseHelperEditor()
  lfsearch.EditorAction("test:search", {})  -- reset history

end

TestEditorAction(...)
TestMReplaceEditorAction(...)

far.Message("All tests OK", "LuaFAR Search")
