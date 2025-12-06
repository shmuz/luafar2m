local function set_f_gsub1 (lib, flg)
  local subj, pat = "abcdef", "[abef]+"
  return {
    Name = "Function gsub, set1",
    Func = lib.gsub,
    { {subj,   pat,  "",  0},   {subj,    0, 0} }, -- test "n" + empty_replace
    { {subj,   pat,  "", -1},   {subj,    0, 0} }, -- test "n" + empty_replace
    { {subj,   pat,  "",  1},   {"cdef",  1, 1} },
    { {subj,   pat,  "",  2},   {"cd",    2, 2} },
    { {subj,   pat,  "",  3},   {"cd",    2, 2} },
    { {subj,   pat,  ""    },   {"cd",    2, 2} },
    { {subj,   pat,  "#", 0},   {subj,    0, 0} }, -- test "n" + non-empty_replace
    { {subj,   pat,  "#", 1},   {"#cdef", 1, 1} },
    { {subj,   pat,  "#", 2},   {"#cd#",  2, 2} },
    { {subj,   pat,  "#", 3},   {"#cd#",  2, 2} },
    { {subj,   pat,  "#"   },   {"#cd#",  2, 2} },
    { {"abc",  "^.", "#"   },   {"#bc",   1, 1} }, -- anchored pattern
  }
end

local function set_f_gsub2 (lib, flg)
  local subj, pat = "abc", "([ac])"
  return {
    Name = "Function gsub, set2",
    Func = lib.gsub,
    { {subj, pat, "<$1>" },   {"<a>b<c>", 2, 2} }, -- test non-escaped chars in f
    { {subj, pat, "$<$1$>" }, {"<a>b<c>", 2, 2} }, -- test escaped chars in f
    { {subj, pat, "" },       {"b",       2, 2} }, -- test empty replace
    { {subj, pat, "1" },      {"1b1",     2, 2} }, -- test odd and even $'s in f
    { {subj, pat, "$1" },     {"abc",     2, 2} },
    { {subj, pat, "$$1" },    {"$1b$1",   2, 2} },
    { {subj, pat, "$$$1" },   {"$ab$c",   2, 2} },
    { {subj, pat, "$$$$1" },  {"$$1b$$1", 2, 2} },
    { {subj, pat, "$$$$$1" }, {"$$ab$$c", 2, 2} },
  }
end

local function set_f_gsub3 (lib, flg)
  return {
    Name = "Function gsub, set3",
    Func = lib.gsub,
    { {"abc",   "a",      "$0"   },   {"abc", 1, 1} }, -- test (in)valid capture index
    { {"abc",   "a",      "$1"   },   {"abc", 1, 1} },
    { {"abc",   "[ac]",   "$1"   },   {"abc", 2, 2} },
    { {"abc",   "(a)",    "$1"   },   {"abc", 1, 1} },
    { {"ab",    "(.)(.)", "$2$1" },   {"ba",  1, 1} },
    { {"abc",   "(a)",    "$2"   },   "invalid capture index" },
  }
end

local function set_f_gsub4 (lib, flg)
  return {
    Name = "Function gsub, set4",
    Func = lib.gsub,
    { {"a2c3",     ".",            "#"     },  {"####",      4, 4} }, -- test .
    { {"a2c3",     ".+",           "#"     },  {"#",         1, 1} }, -- test .+
    { {"a2c3",     ".*",           "#"     },  {"#",         1, 1} }, -- test .*
    { {"/* */ */", "\\/\\*(.*)\\*\\/", "#" },  {"#",         1, 1} },
    { {"a2c3",     "[0-9]",        "#"     },  {"a#c#",      2, 2} }, -- test $d
    { {"a2c3",     "[^0-9]",       "#"     },  {"#2#3",      2, 2} }, -- test $D
    { {"a \t\nb",  "[ \t\n]",      "#"     },  {"a###b",     3, 3} }, -- test $s
    { {"a \t\nb",  "[^ \t\n]",     "#"     },  {"# \t\n#",   2, 2} }, -- test $S
  }
end

local function set_f_gsub5 (lib, flg)
  --local subj, pat = "abcdef", "[abef]+"
  return {
    Name = "Function gsub, set5",
    Func = lib.gsub,
    { {"a\0c", ".",  "#"   },   {"###",   3, 3} }, -- subj contains nuls
  }
end

local function set_f_gsub6 (lib, flg)
  local set = {
    Name = "Function gsub, set6",
    Func = lib.gsub,
    { {"/* */ */", [[\/\*(.*)\*\/]],  "#"  },  {"#",         1, 1} },
    { {"a2c3",     ".*?",             "#"  },  {"#a#2#c#3#", 5, 5} },
    { {"/**/",     [[\/\*(.*?)\*\/]], "#"  },  {"#",         1, 1} },
    { {"/* */ */", [[\/\*(.*?)\*\/]], "#"  },  {"# */",      1, 1} },
    { {"a2c3",     "\\d",             "#"  },  {"a#c#",      2, 2} }, -- test %d
    { {"a2c3",     "\\D",             "#"  },  {"#2#3",      2, 2} }, -- test %D
    { {"a \t\nb",  "\\s",             "#"  },  {"a###b",     3, 3} }, -- test %s
    { {"a \t\nb",  "\\S",             "#"  },  {"# \t\n#",   2, 2} }, -- test %S
    { {"abcd",     "\\b",             "$1" },  {"abcd",      2, 2} },
  }
  return set
end

local function get_sets(lib)
  return {
    set_f_gsub1 (lib),
    set_f_gsub2 (lib),
    set_f_gsub3 (lib),
    set_f_gsub4 (lib),
    set_f_gsub5 (lib),
    set_f_gsub6 (lib),
  }
end

local script = far.InMyConfig("Macros/scripts/Shell/replace_ex/replace_ex.lua")
local lib = loadfile(script)("test")

lib.gsub = function(subj, patt, repl, n)
  patt = assert(regex.new(patt))
  repl = lib.transform_repl(repl)
  return lib.gsub_ex(subj, patt, repl, n)
end

local debug1 = false
local debug2 = false

for _,set in ipairs(get_sets(lib)) do
  if debug1 or debug2 then
    far.Message(set.Name)
  end

  for k,test in ipairs(set) do
    if type(test[2]) == "string" then
      if debug1 then
        assert(not pcall(lib.gsub, unpack(test[1])))
      end
    else
      local ref1, ref2, ref3 = unpack(test[2])
      local res1, res2, res3 = lib.gsub(unpack(test[1]))
      if debug2 then
        if res1~=ref1 or res2~=ref2 or res3~=ref3 then
          far.Show(("%s, test%d"):format(set.Name, k), ref1,ref2,ref3, "OUTPUT BELOW", res1,res2,res3)
          return
        end
      else
        assert(res1 == ref1)
        assert(res2 == ref2)
        assert(res3 == ref3)
      end
    end
  end
end
