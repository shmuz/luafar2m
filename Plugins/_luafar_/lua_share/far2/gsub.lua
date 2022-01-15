local utf8 = unicode.utf8
local utf8_sub  = utf8.sub
local utf8_gsub = utf8.gsub
local table_insert = table.insert
local table_concat = table.concat

-- @func gsub: string.gsub for LuaFAR
--   @param s: string to search
--   @param p: pattern to find
--   @param f: replacement function or string or table
--   @param [n]: maximum number of replacements [all]
-- @returns
--   @param out: string with replacements
--   @param matches: number of matches found
--   @param reps: number of replacements made
return function (s, p, f, n)
  local ftype = type (f)
  if ftype ~= "string" and ftype ~= "table" and ftype ~= "function" then
    error("arg #3: invalid type ("..ftype..")")
  end
  local reg = regex.new (p)                                              -- 10%
  local st, len = 1, utf8.len(s)
  local out, matches, reps = {}, 0, 0
  local collect
  local repfun = function (ch)                                           -- 01%
    local d = tonumber(ch)
    if not d then return ch end
    if d == 0 then d = 1 end
    d = collect[2+d]
    assert (d ~= nil, "invalid capture index")
    return d or "" -- capture can be false
  end
  while (not n) or reps < n do
    collect = { reg:find (s, st) }                                       -- 40%
    if not collect[1] then break end
    matches = matches + 1
    local from, to = collect[1], collect[2]
    table_insert (out, utf8_sub (s, st, from - 1))                       -- 07%
    if collect[3] == nil then                                            -- 01%
      collect[3] = utf8_sub (s, from, to)
    end
    local rep
    if ftype == "string" then     rep = utf8_gsub (f, "%%(.?)", repfun)  -- 04%
    elseif ftype == "table" then  rep = f [collect[3]]
    else                          rep = f (unpack (collect, 3))
    end
    if rep then                                                          -- 06%
      local reptype = type (rep)
      if reptype == "string" or reptype == "number" then
        table_insert (out, rep)
        reps = reps + 1
      else
        error ("invalid replacement value (a " .. reptype .. ")")
      end
    else
      table_insert (out, utf8_sub (s, from, to))
    end
    if st <= to then st = to + 1
    elseif st < len then st = st + 1
    else break
    end
  end
  table_insert (out, utf8_sub (s, st))
  return table_concat (out), matches, reps                                -- 2%
end

