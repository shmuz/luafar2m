local F = far.Flags

local function OpenHelperEditor(filename)
  local ret = editor.Editor (filename, nil, nil,nil,nil,nil,
              {EF_NONMODAL=1, EF_IMMEDIATERETURN=1})
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

local function ClearBuffer()
  local editInfo = editor.GetInfo()
  editor.Select("BTYPE_STREAM", 1, 1, nil, editInfo.TotalLines)
  editor.DeleteBlock()
end


local function PrepareFile (filename)
  OpenHelperEditor(filename)
  local editInfo = editor.GetInfo()
  if bit64.band (editInfo.CurState, F.ECSTATE_SAVED) == 0 then
    local result = far.Message("\nSave current file?\n",
      "A new file will be created", "Yes;No;Cancel")
    if result < 0 or result == 3 then return false end
    if result == 1 and not editor.SaveFile(editInfo.FileName) then
      far.Message"Could not save file. Canceling the operation."
      return false
    end
  end
  os.remove(filename)
  ClearBuffer()
  if not editor.SaveFile(filename) then
    far.Message"Could not save file. Canceling the operation."
    return false
  end
  return true
end


local function TestCase (data, selection, refer, expr, colpat, onlysel)
  local sl = require "sortlines"
  -----------------------------------------------------------------------------
  local y1,y2 = selection:match"^(%d+)%-(%d+)"
  ProtectedAssert(y1)
  local x1,x2 = selection:match"^%d+%-%d+%-(%d+)%-(%d+)$"
  y1,y2 = tonumber(y1),tonumber(y2)
  if x1 then
    x1,x2 = tonumber(x1),tonumber(x2)
    selection = { "BTYPE_COLUMN", y1, x1, x2-x1+1, y2-y1+1 }
  else
    selection = { "BTYPE_STREAM", y1, 1, -1, y2-y1+1 }
  end
  -----------------------------------------------------------------------------
  local control = {}
  local e1 = expr:match "^[^;]+"
  local e2 = expr:match "^[^;]*;([^;]+)"
  local e3 = expr:match "^[^;]*;[^;]*;([^;]+)"
  if e1 and e1 ~= "" then
    control.cbxUse1 = true
    local rev, case = e1:match"^(%-?)(%+?)"
    if rev == "-" then control.cbxRev1=true end
    if case == "+" then control.cbxCase1=true end
    control.edtExpr1 = e1:sub(1+#rev+#case)
  end
  if e2 and e2 ~= "" then
    control.cbxUse2 = true
    local rev, case = e2:match"^(%-?)(%+?)"
    if rev == "-" then control.cbxRev2=true end
    if case == "+" then control.cbxCase2=true end
    control.edtExpr2 = e2:sub(1+#rev+#case)
  end
  if e3 and e3 ~= "" then
    control.cbxUse3 = true
    local rev, case = e3:match"^(%-?)(%+?)"
    if rev == "-" then control.cbxRev3=true end
    if case == "+" then control.cbxCase3=true end
    control.edtExpr3 = e3:sub(1+#rev+#case)
  end
  control.edtColPat = colpat or "\\S+"
  control.cbxOnlySel = onlysel
  -----------------------------------------------------------------------------
  ClearBuffer()
  for _=1,#data do editor.InsertString() end
  for i,line in ipairs(data) do
    editor.SetPosition(i, 1)
    editor.SetString(i, line, "")
  end
  editor.Select(unpack(selection))
  -----------------------------------------------------------------------------
  sl.SortWithRawData(control)
  for i = 1, #data do
    editor.SetPosition(i, 1)
    local s = editor.GetString(i)
    if type(refer) == "string" then
      ProtectedAssert(s.StringText .. s.StringEOL == data[tonumber(refer:sub(i,i))])
    elseif type(refer) == "table" then
      ProtectedAssert(s.StringText .. s.StringEOL == refer[i])
    end
  end
end


local data1 = {
  "ac  10  2   1\r\n",  -- 1
  "ac  10  10  2\n",    -- 2
  "ac  2   e   3\r\n",  -- 3
  "bc  2   e   4\n",    -- 4
  "AD  BD  e   5\r\n",  -- 5
  "BD  AD  e   6\n",    -- 6
  "2   bc  e   7\r\n",  -- 7
  "10  ac  e   8",      -- 8
}

local data2, result2a, result2b = {
  "a 3 f\r\n",
  "b 2 d\n",
  "c 1 e\n",
}, { -- 3-rd column sorted: only selection
  "a 3 d\r\n",
  "b 2 e\n",
  "c 1 f\n",
}, { -- 2-nd and 3-rd columns sorted: only selection
  "a 1 e\r\n",
  "b 2 d\n",
  "c 3 f\n",
}

local data3, result3 = {
  "abc\n",
  "1234567\n"
}, { -- indexes [5,6] sorted: only selection
  "abc 56\n",
  "1234  7\n"
}

local function DoTest()
package.loaded["sortlines"]=nil
  local filename = "/tmp/test_sortlines.tmp"
  if not PrepareFile(filename) then return end
  -----------------------------------------------------------------------------
  -- "a"
  TestCase (data1, "1-8", "87562134", "+a")
  TestCase (data1, "1-8", "43126578", "-+a")
  -- "C(n)"
  TestCase (data1, "3-8", "12875634", "+C(1)")
  TestCase (data1, "3-8", "12436578", "-+C(1)")
  TestCase (data1, "4-8", "12346587", "+C(2)")
  TestCase (data1, "4-8", "12378564", "-+C(2)")
  TestCase (data1, "1-3", "21345678", "+C(3)")
  TestCase (data1, "1-3", "31245678", "-+C(3)")
  -- "L(s)"
  TestCase (data1, "1-8", "87213546", "L(a)")
  TestCase (data1, "1-8", "64531278", "-L(a)")
  -- "N(s)"
  TestCase (data1, "7-8", "12345678", "N(a:match'^%d+')")
  TestCase (data1, "7-8", "12345687", "-N(a:match'^%d+')")
  -- "LC(n)"
  TestCase (data1, "3-8", "12873546", "LC(1)")
  TestCase (data1, "3-8", "12645378", "-LC(1)")
  TestCase (data1, "4-8", "12348675", "LC(2)")
  TestCase (data1, "4-8", "12357684", "-LC(2)")
  -- "NC(n)"
  TestCase (data1, "7-8", "12345678", "NC(1)")
  TestCase (data1, "7-8", "12345687", "-NC(1)")
  TestCase (data1, "2-3", "13245678", "NC(2)")
  TestCase (data1, "2-3", "12345678", "-NC(2)")
  -- "a" (vertical selection)
  TestCase (data1, "1-8-1-10", "87562134", "+a")
  TestCase (data1, "1-8-1-10", "43126578", "-+a")
  -- "a" (vertical selections)
  TestCase (data1, "3-8-1-2", "12875634", "+a")
  TestCase (data1, "3-8-1-2", "12436578", "-+a")
  TestCase (data1, "4-8-5-6", "12346587", "+a")
  TestCase (data1, "4-8-5-6", "12378564", "-+a")
  TestCase (data1, "1-3-9-10", "21345678", "+a")
  TestCase (data1, "1-3-9-10", "31245678", "-+a")
  -- "a" (2-nd and 3-rd expressions)
  TestCase (data1, "1-8", "87562134", ";+a")
  TestCase (data1, "1-8", "43126578", ";-+a")
  TestCase (data1, "1-8", "87562134", ";;+a")
  TestCase (data1, "1-8", "43126578", ";;-+a")
  -- multi-criterion sorting
  TestCase (data1, "1-8", "87562134", "+C(1);+C(2);+C(3)")
  TestCase (data1, "1-8", "87563214", "+C(1);-+C(2);+C(3)")
  TestCase (data1, "1-8", "43126578", "-+C(1);-+C(2);-+C(3)")
  -- vertical selection: sort only selection
  TestCase (data2, "1-3-5-5", result2a, "+a", nil, true)
  TestCase (data2, "1-3-3-5", result2b, "+a", nil, true)
  -- vertical selection: insert spaces; sort only selection
  TestCase (data3, "1-2-5-6", result3, "-+a", nil, true)
  -- sorting stability
  TestCase (data1, "1-8", "12345678",  "5;5;5")
  TestCase (data1, "1-8", "12345678", '"5";"5";"5"')
  TestCase (data2, "1-3", "123",       "5;5;5")
  TestCase (data2, "1-3", "123",      '"5";"5";"5"')
  TestCase (data3, "1-2", "12",        "5;5;5")
  TestCase (data3, "1-2", "12",       '"5";"5";"5"')
  -- reorder lines
  TestCase (data1, "1-8", "12345678", "i")
  TestCase (data1, "1-8", "87654321", "-i")
  TestCase (data1, "1-8", "21436587", "i%2==0 and i-1 or i+1")
  TestCase (data1, "1-8", "13572468", "i%2==1 and i-I or i")
  -----------------------------------------------------------------------------
  editor.SaveFile(filename)
  far.Message"Success!"
end

AddToMenu ("e", "Test: Sort Lines", nil, DoTest)
