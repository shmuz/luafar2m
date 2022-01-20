--[[
Started:  2007-Feb-23
Action:   Global matching and substitution on a file.

Module functions
----------------
fgsub.gsub:
    Search/count matches/replace in a file. The file is read into memory as
    a whole.

fgsub.IncrementalSearch:
    Search/count matches in a file. The file is read into memory chunk by chunk.
    (In fact, it doesn't have to be a file, as long as readFunc API is honored).

fgsub.count:
    A wrapper around IncrementalSearch, that provides an fgsub.gsub-like API.

--]]


--[[
        IncrementalSearch
        =================
 Goal - find and count matches with the given match function in a file/a stream
 of arbitrary size (thus the method of reading the entire file contents into
 memory isn't suitable).

 @param LEN_MATCH:
    Maximum match length possible. The algorithm must ensure finding of all
    matches, that are not longer than that. Detecting of a longer match is
    considered an error, and then error is raised.

 @param. LEN_PRECONTEXT:
    Minimum length of the text preceding the offset of search start. It must be
    guaranteed by the algorithm in all cases, except in a few initial searches.
    (May be needed for matching with lookbehind assertions).

 @param. LEN_POSTCONTEXT:
    Minimum length of text after the offset of match end. It must be guaranteed
    by the algorithm in all cases, except in a few final searches.
    (May be needed for matching with lookahead assertions).

--]]
local function IncrementalSearch (
  readFunc,         -- read function: chunk = readFunc(numBytes)
  findFunc,         -- find function: from,to = findFunc(s,init)
  LEN_MATCH,        -- match: maximum length
  LEN_PRECONTEXT,   -- precontext: minimum length
  LEN_POSTCONTEXT,  -- postcontext: minimum length
  callbackFunc      -- callback function: stop = callbackFunc(strMatch,from)
)
  assert(type(readFunc) == "function")
  assert(type(findFunc) == "function")
  LEN_MATCH       = LEN_MATCH or 2048;       assert(LEN_MATCH > 0)
  LEN_PRECONTEXT  = LEN_PRECONTEXT or 0;     assert(LEN_PRECONTEXT >= 0)
  LEN_POSTCONTEXT = LEN_POSTCONTEXT or 0;    assert(LEN_POSTCONTEXT >= 0)
  if callbackFunc then assert(type(callbackFunc) == "function") end

  local lenNeeded = LEN_PRECONTEXT + 2*LEN_MATCH + LEN_POSTCONTEXT
  local currStr = ""
  local isEof = false
  local count = 0
  local globalStart, start = 0, 0

  while true do
    -- read -------------------------------------------------------------------
    local chunk = readFunc(lenNeeded)
    if chunk then
      if #chunk < lenNeeded then
        isEof = true
      end
      currStr = currStr .. chunk
    else
      isEof = true
    end

    -- search -----------------------------------------------------------------
    while true do
      local found = false
      local fr, to = findFunc(currStr, start+1)
      if fr then
        found = isEof or (to <= LEN_PRECONTEXT + 2*LEN_MATCH)
        if found then
          assert(to-fr < LEN_MATCH, "found match length exceeded the specified limit")
          count = count+1
          if callbackFunc and callbackFunc(currStr:sub(fr,to), globalStart+fr) then
            return count
          end
          if isEof or (to < LEN_PRECONTEXT + LEN_MATCH) then
            start = (to > start) and to or (start + 1)
          else
            lenNeeded = to - LEN_PRECONTEXT
            break
          end
        end
      elseif isEof then
        return count
      end
      if not found then
        lenNeeded = LEN_MATCH
        break
      end
    end
    currStr = currStr:sub(lenNeeded+1)
    start = LEN_PRECONTEXT
    globalStart = globalStart + lenNeeded
  end
end


local function count (opt, lenMatch, lenPrecontext, lenPostcontext)
  local findFunc
  if opt.pcre then
    local rex = require "rex_pcre"
    local pat = rex.new(opt.pat, opt.flags, opt.locale)
    findFunc = function(s, init) return pat:find(s, init) end
  else
    findFunc = function(s, init) return s:find(opt.pat, init) end
  end

  local callbackFunc
  if opt.n then
    local n = 0
    callbackFunc = function(strMatch, from) n=n+1; return n==opt.n; end
  end

  local hin = assert (io.open(opt[1], opt.text and "r" or "rb"))
  local readFunc = function(len) return hin:read(len) end
  local ok, count = pcall(IncrementalSearch, readFunc, findFunc, lenMatch,
                          lenPrecontext, lenPostcontext, callbackFunc)
  hin:close()
  return ok and count or error(count)
end


local function gsub (opt)
  local hin = assert (io.open(opt[1], opt.text and "r" or "rb"))
  local s, nmatches = hin:read"*a"
  hin:close()

  local rep = opt.rep or ""
  if type(rep) == "function" then
    local env = setmetatable({ cnt=0 }, { __index=_G })
    local oldrep = rep
    rep = function(...) cnt=cnt+1; return oldrep(...) end
    setfenv(oldrep, env)
    setfenv(rep, env)
  end

  if opt.pcre then
    local rex = require "rex_pcre"
    s, nmatches = rex.gsub(s, opt.pat, rep, opt.n, opt.flags, nil, opt.locale)
  else
    s, nmatches = string.gsub (s, opt.pat, rep, opt.n)
  end

  if opt.rep then
    local hout = assert (io.open(opt[2] or opt[1], opt.text and "w" or "wb"))
    hout:write(s)
    hout:close()
  end

  return nmatches
end


return {
  IncrementalSearch=IncrementalSearch,
  count=count,
  gsub=gsub,
}
