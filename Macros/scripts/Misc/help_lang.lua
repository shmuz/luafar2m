-- started: 2024-12-12

local MacroKey = "CtrlL"
local dirsep = string.sub(package.config, 1, 1)
local Pattern = regex.new([[^\s*\.Language\s*=\s*(\w+)(?:\s*,\s*(.+))?]], "i")

Macro {
  id="8AF20887-F869-40DC-AF2D-5A649FABBCE5";
  description="Select Help language from Help window";
  area="Help"; key=MacroKey;
  action=function()
    local Topic = Help.Topic
    local mItems = {}
    local dir = Help.FileName:match(".+"..dirsep)
    far.RecursiveSearch(dir, "*.hlf", function(item,path)
        if item.FileAttributes:find("d") then return end
        local fp = io.open(path)
        if not fp then return end
        for i=1,3 do -- try up to 3 lines
          local line = fp:read("*l")
          if line then
            if i==1 and line:find("^\239\187\191") then
              line = string.sub(line, 4) -- remove UTF-8 BOM
            end
            local p1,p2 = Pattern:match(line)
            if p1 then
              table.insert(mItems, {text=p2 or p1, path=path})
              break
            end
          end
        end
        fp:close()
      end)
    if mItems[1] then
      table.sort(mItems, function(a,b) return utf8.ncasecmp(a.text,b.text) < 0 end)
      local item = far.Menu({Title="Select help language"},mItems)
      if item then
        Keys("Esc")
        far.ShowHelp(item.path, Topic, "FHELP_CUSTOMFILE")
      end
    end
  end;
}
