-- Started 2010-06-15 by Shmuel Zeigerman.
-- Proof of concept.

local ext_list = {
  "txt", "lua", "c", "h", "cpp" -- lower case!
}
local hash = {}; for _,v in ipairs(ext_list) do hash[v] = true end

-- display text at the file beginning
--------------------------------------
function export.GetCustomData (FilePath)
  local ext = FilePath:match ( "%.([^/.]+)$" )
  if ext and hash[ext:lower()] then
    local fp = io.open(FilePath)
    if fp then
      local s = fp:read(512)
      fp:close()
      return s and s:gsub("%s+", " "):match("[%w_].*")
    end
  end
end
