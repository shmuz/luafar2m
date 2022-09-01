-- Started 2010-06-15 by Shmuel Zeigerman.
-- Proof of concept.

local extmap = { -- put extensions in lower case!
  txt=1, lua=1, c=1, h=1, cpp=1,
}

-- display text at the file beginning
--------------------------------------
function export.GetCustomData (FilePath)
  local ext = FilePath:match ( "%.([^/.]+)$" )
  if ext and extmap[ext:lower()] then
    local fp = io.open(FilePath)
    if fp then
      local s = fp:read(512)
      fp:close()
      return s and s:gsub("%s+", " "):match("[%w_].*")
    end
  end
end
