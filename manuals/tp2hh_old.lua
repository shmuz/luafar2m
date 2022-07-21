-- TP2HH  :  Convert "TreePad" file to "HTML Help" project files
-- Author :  S.Zeigerman
-- Started:  29 Dec 2000
-- Ported to Lua: 02-03 Dec 2008

local discount = require "old-discount"
local rex      = require "rex_pcre"
local tsi      = require "tsi"

local function fprintf(fp_out, fmt, ...)
  fp_out:write(fmt:format(...))
end

-- Convert chars & < > " to HTML representation
local function HTML_convert(s)
  local tb = {["&"]="&amp;", ["<"]="&lt;", [">"]="&gt;", ['"']="&quot;"}
  s = s:gsub('[&<>"]', tb)
  return s
end

local function HTML_puts(s, fp_out)
  fp_out:write(HTML_convert(s))
end

local function fputs_indent(s, fp_out, indent)
  for _=1,indent do fp_out:write '\t' end
  fp_out:write(s)
end

local function writeProjectHeader (fp_out, ProjectName, Title, DefaultTopic)
  local WindowName = "MyDefaultWindow"
  fprintf(fp_out, "[OPTIONS]\n")
  fprintf(fp_out, "Compatibility=1.1 or later\n")
  fprintf(fp_out, "Compiled file=%s.chm\n", ProjectName)
  fprintf(fp_out, "Contents file=%s.hhc\n", ProjectName)
  fprintf(fp_out, "Default Window=%s\n",    WindowName)
  fprintf(fp_out, "Default topic=%s\n", DefaultTopic)
  fprintf(fp_out, "Display compile progress=No\n")
  fprintf(fp_out, "Error log file=Logfile.txt\n")
  fprintf(fp_out, "Full-text search=Yes\n")
  fprintf(fp_out, "Index file=%s.hhk\n", ProjectName)
  fprintf(fp_out, "Language=0x809 English (British)\n")
  fprintf(fp_out, "Title=%s\n", Title)
  fprintf(fp_out, "\n[WINDOWS]\n")
  fprintf(fp_out, "%s=,\"%s.hhc\",\"%s.hhk\",,\"%s\",,,,,0x23520,,0x301e,,,,,,,,0\n",
          WindowName, ProjectName, ProjectName, DefaultTopic)
  fprintf(fp_out, "\n[FILES]\n")
end

local function writeTocHeader(fp_out)
  fp_out:write("<!DOCTYPE HTML PUBLIC \"-//IETF//DTD HTML//EN\">\n",
    "<HTML>\n",
    "<HEAD>\n",
    "<meta name=\"GENERATOR\" content=\"Microsoft&reg; HTML Help Workshop 4.1\">\n",
    "<!-- Sitemap 1.0 -->\n",
    "</HEAD><BODY>\n",
    "<OBJECT type=\"text/site properties\">\n",
    "\t<param name=\"Auto Generated\" value=\"No\">\n",
    "</OBJECT>\n")
end

local function writeTopicHeader(fp_out, Title, fp_template)
  if not fp_template then
      fp_out:write("<HTML>\n<HEAD>\n<TITLE>\n")
      HTML_puts(Title, fp_out)
      fp_out:write("\n</TITLE>\n</HEAD>\n<BODY>\n")
      -- put the topic title at the article beginning
      fp_out:write("<H2>")
      HTML_puts(Title,  fp_out)
      fp_out:write("</H2>\n<HR>\n")
      return
  end

  -- Using the "template file" as formatting template:
  --   a)  There are two "keywords": <!--Body--> and <!--Title-->
  --       (both are case sensitive !!!)
  --   b)  This keywords serve as placeholders for the document's
  --       body and title respectively.
  --   c)  There must be exactly one <!--Body--> in the template file.
  --   d)  <!--Body--> must begin from the leftmost column. All
  --       following characters in that line will be ignored.
  --   e)  <!--Title--> must not encounter more than once in a line.
  --   f)  No <!--Title--> may be placed after the <!--Body-->
  --
  fp_template:seek("set", 0)
  for line in fp_template:lines() do
      if "<!--Body-->" == line:sub(1,11) then return end
      local cp1, cp2 = line:find("<!--Title-->", 1, true)
      if not cp1 then
          fp_out:write(line, "\n")
      else
          fp_out:write(line:sub(1, cp1 - 1))
          HTML_puts(Title, fp_out)
          fp_out:write(line:sub(cp2 + 1), "\n")
      end
  end
end

local function writeTopicFooter(fp_out, fp_template)
  if fp_template then
    fp_out:write(fp_template:read("*all"))
  else
    fp_out:write("</BODY>\n</HTML>\n")
  end
end

local function postprocess_article (part1, part2, preformat)
  if part2 then
    local script = part2:match("<lua>(.-)</lua>")
    if script then
      local env = {}
      local f = assert(loadstring(script))
      setfenv(f, env)()
      if env.Links then
        for str, trg in pairs(env.Links) do
          local patt = "\\b"..str.."\\b" -- prevent matching parts of words
          part1 = rex.gsub(part1, patt, '<a href="'..trg..'">%1</a>')
        end
      end
      if env.no_preformat then preformat = false end
    end
  end
  return preformat and "\n<pre>"..part1.."</pre>\n" or part1
end

-- By default, this program assumes that each article of the input Treepad
-- file is in plain text format.
-- But if a user wants to keep some articles already in HTML format, he/she
-- must insert a line "<!--HTML-->\n" (case sensitive, without quotes), at the
-- very beginning of each such article, to let this program know that these
-- articles should go to the output "as they are" (with no added header, no
-- added footer and no conversion).
local function process_article (text)
  local line, start = text:match "^([^\n]*)\n()"
  if line == "<!--HTML-->" then
    return { kind="html"; text=text; }
  elseif line == "<markdown>" then
    text = text:sub(start)
    local part1, part2 = text:match("(.-)@@@(.*)")
    part1 = discount(part1 or text)
    return { kind="markdown"; text=postprocess_article(part1, part2, false); }
  else
    local part1, part2 = text:match("(.-)@@@(.*)")
    part1 = HTML_convert(part1 or text)
    -- For convenience: the words marked with @ at the beginning should be indexed, e.g. @DM_KEY
    -- It should be done *after* HTML_convert()
    part1 = rex.gsub(part1, [[(?<!\S)@(\w+)]], [[<a name="%1">%1</a>]])

    part1 = part1:gsub("%*%*(.-)%*%*", "<strong>%1</strong>") -- make bold
    part1 = part1:gsub(  "%*(.-)%*",   "<em>%1</em>")         -- make italic
    part1 = part1:gsub(  "%`(.-)%`",   "<code>%1</code>")     -- make code
    return { kind="simple"; text=postprocess_article(part1, part2, true); }
  end
end

local function path_join(path1, path2)
  if path1:find("[/\\]$") then return path1..path2; end
  return path1.."\\"..path2
end

local CHM_INDEX = {
  Head = [[
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">
<HTML>
<HEAD>
<meta http-equiv="Content-Type" Content="text/html; charset=Windows-1251">
<meta name="GENERATOR" content="Microsoft&reg; HTML Help Workshop 4.1">
<!-- Sitemap 1.0 -->
</HEAD><BODY>
<UL>
]];
  Item = [[
  <LI> <OBJECT type="text/sitemap">
    <param name="Name" value="%s">
    <param name="Local" value="%s">
    </OBJECT>
]];
  Foot = "</UL>\n</BODY></HTML>\n";
}

-- generate: files, project, TOC and FileIndex
local function generateFPT (NodeIterator, ProjectName, fp_template, out_dir)
  local path_project_name = path_join(out_dir, ProjectName)
  -- create a FileIndex, a project file and a TOC file
  local fIndex = assert( io.open(path_project_name..".htm", "wt") )
  fIndex:write("<HTML><HEAD><TITLE>\nFile Locator\n</TITLE></HEAD>\n<BODY>\n")

  local fProj = assert( io.open(path_project_name..".hhp", "wt") )
  local fToc  = assert( io.open(path_project_name..".hhc", "wt") )
  local fChmIndex  = assert( io.open(path_project_name..".hhk", "wt") )
  writeTocHeader(fToc)
  fChmIndex:write(CHM_INDEX.Head)

  local ProjectHeaderReady
  local nodeLevel = -1
  for node, _ in NodeIterator do
    if node.datatype ~= "text" then
      error(node.name .. ": article must be pure text type")
    end
    local filename = ("%d.html"):format(node.id)
    local fCurrent = assert( io.open(path_join(out_dir,filename), "wt") )
    local article = process_article(node.article)
    if article.kind == "html" then
      fCurrent:write(article.text)
    else
      writeTopicHeader(fCurrent, node.name, fp_template)
      fCurrent:write(article.text)
      writeTopicFooter(fCurrent, fp_template)
    end
    fCurrent:close()

    if not ProjectHeaderReady then
      writeProjectHeader(fProj, ProjectName, node.name, filename)
      ProjectHeaderReady = true
    end

    -- include file name into the project file
    fProj:write(filename, "\n")

    -- get node level
    -- put node info into the TOC and the FileIndex
    local newLevel = tonumber(node.level)
    for i = nodeLevel, newLevel+1, -1 do -- end of subtree ?
      fputs_indent("</UL>\n", fToc, i)
      fputs_indent("</UL>\n", fIndex, i)
    end
    if newLevel > nodeLevel then  -- the first child
      fputs_indent("<UL>\n", fToc, newLevel)
      fputs_indent("<UL>\n", fIndex, newLevel)
    end

    fputs_indent("<LI><A HREF=\"", fIndex, newLevel)
    fIndex:write(filename)
    fIndex:write("\">")
    HTML_puts(node.name, fIndex)
    fIndex:write("</A>\n")

    fputs_indent("<LI> <OBJECT type=\"text/sitemap\">\n", fToc, newLevel)
    fputs_indent("<param name=\"Name\" value=\"", fToc, newLevel+1)
    local p = node.name:gsub('"', '&quot;')
    fToc:write(p)
    fToc:write("\">\n")
    fputs_indent("<param name=\"Local\" value=\"", fToc, newLevel+1)
    fToc:write(filename)
    fToc:write("\">\n")
    fputs_indent("</OBJECT>\n", fToc, newLevel+1)

    -- index nodes with non-empty articles
    if node.article:find("%S") then
      fChmIndex:write(CHM_INDEX.Item:format(node.name, filename))
    end
    -- index keywords in "simple" articles
    if article.kind == "simple" then
      for nm in article.text:gmatch([[<a name="(.-)">]]) do
        fChmIndex:write(CHM_INDEX.Item:format(nm, filename.."#"..nm))
      end
    end

    nodeLevel = newLevel
  end

  fProj:close()

  for i = nodeLevel, 0, -1 do
    fputs_indent("</UL>\n", fToc, i)
    fputs_indent("</UL>\n", fIndex, i)
  end

  fToc:write("</BODY></HTML>\n")
  fIndex:write("</BODY></HTML>\n")
  fChmIndex:write(CHM_INDEX.Foot)

  fToc:close()
  fIndex:close()
  fChmIndex:close()
end

do
  local datafile, tem, outdir = ...
  assert(datafile and tem and outdir, "some parameter is missing")
  local fp_template = (tem~="-") and assert(io.open(tem))
  local project_name = datafile:match("[^/\\]+$"):gsub("%.[^.]+$", "")
  generateFPT(tsi.Nodes(datafile), project_name, fp_template, outdir or ".")
  if fp_template then fp_template:close() end
end
