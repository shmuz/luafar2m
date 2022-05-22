-- EE_SAVE: delete trailing spaces

local F = far.Flags

local function RemoveTrailingSpaces(Id, Event, Param)
  if Event==F.EE_SAVE then
    local info = editor.GetInfo()
    if info then
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

Event { -- for text files
  description="EE_SAVE: delete trailing spaces";
  group="EditorEvent";
  filemask = ([[ bat c cmd cpp da_ h hex hlf hpp htm html lua luacheckrc mak moon pas py txt ]])
    : gsub("%s*(%S+)%s*", "*.%1,") .. "changelog,makefile,readme";
  action=RemoveTrailingSpaces;
}
