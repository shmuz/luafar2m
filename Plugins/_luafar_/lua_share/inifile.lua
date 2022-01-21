-- started : 2020-12-10
-- author  : Shmuel Zeigerman
-- action  : INI-file parser

local lib, section = {}, {}
local mt_lib     = {__index=lib}
local mt_section = {__index=section}

local function has_trailing(s)
  return s:match("^ ") or s:match(" $")
end

local function get_secname(line)
  local sec = line:match("^%s*%[([%w_./ ]+)%]")
  return sec and not has_trailing(sec) and sec
end

local function get_key_val(line)
  local key,val = line:match("^%s*([%w_%-]+)%s*=%s*(.+)") -- no spaces in the key
  if not key then key,val = line:match("^%s*([%w_%- ]+)=%s*(.+)"); end -- spaces in the key
  if key and not has_trailing(key) then return key,val; end
  return nil
end

-- @param fname     : name of ini-file
-- @param nocomment : if true then values can contain any chars including semicolons
--                    if false then a semicolon means start of a comment
function lib.New(fname, nocomment)
  local fp, msg = io.open(fname)
  if not fp then return nil, msg; end
  local self = { map={}; arr={}; }
  setmetatable(self, mt_lib)
  local cursection
  for line in fp:lines() do
    local secname = get_secname(line)
    if secname then
      local lname = secname:lower()
      cursection = { name=secname; lname=lname; map={}; arr={}; }
      setmetatable(cursection, mt_section)
      self.map[lname] = cursection
    elseif cursection then
      local key,val = get_key_val(line)
      if key then
        local first = val:sub(1,1)
        if first == '"' then
          val = val:match('^"(.-)"') -- in double quotes
        elseif first == "'" then
          val = val:match("^'(.-)'") -- in single quotes
        else
          if not nocomment then
            val = val:match("^[^;]+")  -- semicolon starts the comment
          end
          val = val and val:gsub("%s+$","")
        end
        if val then
          local lkey = key:lower()
          local item = { name=key; lname=lkey; val=val; }
          cursection.map[lkey] = item
        end
      end
    end
  end
  -- fill arrays
  for _,sec in pairs(self.map) do
    table.insert(self.arr, sec)
    for _,item in pairs(sec.map) do
      table.insert(sec.arr, item)
    end
    table.sort(sec.arr, function(a,b) return a.lname < b.lname end)
  end
  table.sort(self.arr, function(a,b) return a.lname < b.lname end)

  fp:close()
  return self
end

function lib:sections()
  local i=0
  return function() i = i+1; return self.arr[i]; end
end

function section:pairs()
  local i=0
  return function() i = i+1; return self.arr[i]; end
end

function lib:GetString(sec, key)
  local sect = self.map[sec:lower()]
  if sect then
    local item = sect.map[key:lower()]
    return item and item.val
  end
end

function lib:GetNumber(sec, key)
  return tonumber(self:GetString(sec,key))
end

function lib:GetBoolean(sec, key)
  local s = (self:GetString(sec,key) or ""):lower()
  if s=="1" or s=="yes" or s=="true" then return true end
  if s=="0" or s=="no" or s=="false" then return false end
  return nil
end

return lib
