--[=[
  Library functions:
    *  hobj = history.newfile (filename)
       *  description:   create a new history object from file
       *  @param filename: file name
       *  @return:       history object

  Methods of history object:
    *  value = hobj:field (name)
       *  description:   get or create a field
       *  @param name:   name (sequence of fields delimitered with dots)
       *  @return:       either value of existing field or a new table
       *  example:       hist:field("mydialog.namelist").width = 120

    *  value = hobj:getfield (name)
       *  description:   get a field
       *  @param name:   name (sequence of fields delimitered with dots)
       *  @return:       value of a field
       *  example:       local namelist = hist:field("mydialog.namelist")

    *  value = hobj:setfield (name, value)
       *  description:   set a field
       *  @param name:   name (sequence of fields delimitered with dots)
       *  @param value:  value to set the field
       *  @return:       value
       *  example:       hist:setfield("mydialog.namelist.width", 120)

    *  hobj:save()
       *  description:   save history object

    *  str = hobj:serialize()
       *  description:   serialize history object
       *  @return:       serialized history object
--]=]

local serial  = require "serial"

local history = {}
local meta = { __index = history }

function history:serialize()
  return serial.SaveToString("Data", self.Data)
end

function history:field (fieldname)
  local tb = self.Data
  for v in fieldname:gmatch("[^.]+") do
    tb[v] = tb[v] or {}
    tb = tb[v]
  end
  return tb
end

function history:getfield (fieldname)
  local tb = self.Data
  for v in fieldname:gmatch("[^.]+") do
    if type(tb) ~= "table" then
      return nil
    end
    tb = tb[v]
  end
  return tb
end

function history:setfield (name, val)
  local tb = self.Data
  local part1, part2 = name:match("^(.-)([^.]*)$")
  for v in part1:gmatch("[^.]+") do
    tb[v] = tb[v] or {}
    tb = tb[v]
  end
  tb[part2] = val
  return val
end

local function new (chunk)
  local self
  if chunk then
    self = {}
    setfenv(chunk, self)()
    if type(self.Data) ~= "table" then self = nil end
  end
  self = self or { Data={} }
  return setmetatable(self, meta)
end

local function newfile (FileName)
  assert(type(FileName) == "string")
  local self = new(loadfile(FileName))
  self.FileName = FileName
  return self
end

function history:save()
  if self.FileName then
    serial.SaveToFile (self.FileName, "Data", self.Data)
  end
end

return {
  newfile = newfile,
}
