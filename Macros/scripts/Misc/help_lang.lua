-- started: 2024-12-12

Macro {
  id="8AF20887-F869-40DC-AF2D-5A649FABBCE5";
  description="Select Help language from Help window";
  area="Help"; key="CtrlL";
  action=function()
    local Topic = Help.Topic
    local mItems = {}
    local dir = Help.FileName:match(".+/")
    far.RecursiveSearch(dir, "*.hlf", function(item,path)
        if item.FileAttributes:find("d") then return end
        local fp = io.open(path)
        if not fp then return end
        local ln = fp:read("l")
        if ln then
          local lang = ln:match("%.Language=%w+,(.+)")
          if lang then
            table.insert(mItems, {text=lang,path=path})
          end
        end
        fp:close()
      end)
    table.sort(mItems, function(a,b) return utf8.ncasecmp(a.text,b.text) < 0 end)
    local item = far.Menu({Title="Select help language"},mItems)
    if item then
      Keys("Esc")
      far.ShowHelp(item.path, Topic, "FHELP_CUSTOMFILE")
    end
  end;
}
