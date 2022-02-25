-- Started: 2005-Sep-09
-- This module offers functions for writing and reading TreeSpice files.
-- Currently, it "exports" the following functions:
--    * NewWriter() -- create a new treespice object
--       * self:WriteHeader() -- method: write the header
--       * self:WriteNode()   -- method: write a node
--       * self.write()       -- may be reassigned to the user-defined function
--    * ReadHeader() -- read the file header
--    * Nodes()      -- iterate nodes in a "generic for" loop

local string_gsub, string_sub, string_match =
      string.gsub, string.sub, string.match
local io_open, io_write = io.open, io.write
local table_insert, table_concat = table.insert, table.concat

-- datatypes: user to tsi conversion
local dt_tsi = {
    text="Text", rtf="RTF", html="HTML",
    vtext="V_Text", vrtf="V_RTF", vhtml="V_HTML"
}

-- datatypes: tsi to user conversion
local dt_user = {
    Text="text", RTF="rtf", HTML="html",
    V_Text="vtext", V_RTF="vrtf", V_HTML="vhtml"
}

-- EPOCH
-- note that `hour' should be explicitly set to 0 (otherwise it may default to 12)
-- note that `isdst' in both uses should be set to false (not nil)
local EPOCH = os.time { year=1999; month=12; day=30; hour=0; isdst=false; } -
              (100*365 + 100/4 - 100/100) * 24 * 3600

-- write node start;
-- parameters `datatype' and `id' are optional;
-- parameter `use_cur_time': use current time rather than the times stored in the node;
local function  wr_node_start (self, node, use_cur_time)
    local now = os.date("*t")
    now.isdst = false -- Borland's TDateTime library itself will make the adjustment if needed
    local tdiff = use_cur_time and tostring(os.time(now) - EPOCH) -- Do NOT use os.difftime here
    local ctime = tdiff or node.ctime
    local mtime = tdiff or node.mtime
    local s = "<node>" ..
              (node.id and ("\nid="..node.id) or "") ..
              "\nlv=" .. node.level ..
              "\ndt=" .. dt_tsi[node.datatype or "text"] ..
              "\nnm=" .. string_gsub(node.name, "\n", " ") ..
              (ctime and ("\nctime="..ctime) or "") ..
              (mtime and ("\nmtime="..mtime) or "") ..
              "\n<article>\n"
    self.write(s)
end

-- write node end
local function wr_node_end(self)
    self.write("</article>\n</node>\n")
end

-- prefix lines in article
local function prefix_lines(text)
    text = string_gsub(text, "[^\n]*\n?", function(c) return c~="" and "#_"..c end)
    return text
end

local function WriteHeader(self)
    self.write("<header>\ntag=SMZ1\nver=2.7\n</header>\n")
end

-- Write a node.
--   Field `datatype' must be one of the following strings:
--       "text", "rtf", "html", "vtext", "vrtf", "vhtml".
--   Fields `id', `article', `prefix' and `suffix' are optional.
local function WriteNode(self, node, use_cur_time)
    wr_node_start(self, node, use_cur_time)
    if node.prefix  then self.write(prefix_lines(node.prefix))  end
    if node.article then self.write(prefix_lines(node.article)) end
    if node.suffix  then self.write(prefix_lines(node.suffix))  end
    wr_node_end(self)
end

-- Create a new treespice object.
--   Parameter `write_func' is optional.
local function NewWriter (write_func)
    local t = {}
    t.write        = write_func or io_write
    t.WriteHeader  = WriteHeader
    t.WriteNode    = WriteNode
    return t
end

-- Read the file header
local function ReadHeader(filename)
    local f = io_open(filename)
    local hdr
    if f then
        local chunk = f:read(1024)
        if chunk then
            hdr = string_match(chunk, "^%s*(<header>.-</header>)")
        end
        f:close()
    end
    return hdr
end

--  Iterate nodes in a "generic for" loop.
local function Nodes (filename)
    local h = assert( io_open(filename) )

    local function abort()
        h:close(); h = nil;
        error("File with incorrect format or corrupted.")
    end

    -- Skip the file header
    repeat
        local line = h:read("*l")
        if not line then abort(); end
    until line == "</header>"

    local state = "start" -- either of: start, info, article, end
    local NodeNumber = 0

    return function()
        if not h then return nil end
        local tNode, tArticle

        for line in h:lines() do
            --------------------------------------------------------------------
            if state == "start" then
                if line ~= "<node>" then abort(); end
                state = "info"
                tNode = {}
            --------------------------------------------------------------------
            elseif state == "info" then
                if line == "<article>" then
                    tArticle = {}
                    state = "article"
                else
                    local var,val = string_match(line, "^%s*([^=%s]+)%s*%=(.*)")
                    if     var == "lv"    then tNode.level = val
                    elseif var == "nm"    then tNode.name = val
                    elseif var == "id"    then tNode.id = val
                    elseif var == "dt"    then tNode.datatype = dt_user[val]
                    elseif var == "ctime" then tNode.ctime = val
                    elseif var == "mtime" then tNode.mtime = val
                    else abort()
                    end
                end
            --------------------------------------------------------------------
            elseif state == "article" then
                if line == "</article>" then
                    state = "end"
                    tNode.article = table_concat(tArticle, "\n")
                    if tNode.article ~= "" then
                        tNode.article = tNode.article .. "\n"
                    end
                elseif string_sub(line,1,2) == "#_" then
                    table_insert(tArticle, string_sub(line,3)) -- delete "#_"
                else
                    abort()
                end
            --------------------------------------------------------------------
            elseif state == "end" then
                if line == "</node>" then
                  state = "start"
                  NodeNumber = NodeNumber + 1
                  return tNode, NodeNumber
                else
                    abort()
                end
            end
            --------------------------------------------------------------------
        end
        if state == "start" then h:close(); h = nil;
        else abort()
        end
    end
end

return {
    NewWriter = NewWriter,
    ReadHeader = ReadHeader,
    Nodes = Nodes,
}
