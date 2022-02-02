-- EE_SAVE: delete trailing spaces

local filemask =
  ([[ bat  c  cmd  cpp  da_  h  hex  hpp  htm  html  lua  luacheckrc  mak  pas  py  txt ]])
  : gsub("%s*(%S+)%s*", "*.%1,") .. "changelog,makefile,readme"

local F = far.Flags
local pn_flags = bit.bor(F.PN_CMPNAMELIST, F.PN_SKIPPATH)

local function RemoveTrailingSpaces(Event, Param)
  if Event==F.EE_SAVE then
    local info = editor.GetInfo()
    if info and far.ProcessName(filemask, info.FileName, pn_flags) then
      for k=1,info.TotalLines do
        local ln = editor.GetString(k,1)
        local from = ln.StringText:find("%s+$")
        if from then
          local str = ln.StringText:sub(1,from-1)
          editor.SetString(k,str,ln.StringEOL)
        end
      end
      editor.SetPosition(info)
    end
  end
end

AddEvent("EditorEvent", RemoveTrailingSpaces)
