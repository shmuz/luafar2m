local syntax_text =
{
  bgcolor = "darkblue";
  bracketmatch = true;
  {
    name = "Emphasize1"; fgcolor = "green";
    pattern = [[ ^\s*__.* | \b_.*?_\b ]];
  },
  {
    name = "Emphasize2"; color = "yellow on gold";
    pattern = [[ \*\*.*?\*{2,} ]];
  },
  {
    name = "Important"; fgcolor = "red";
    pattern = [[ ^\s*\\\\.* ]];
  },
  {
    name = "RusLetter"; fgcolor = "yellow";
    pattern = [[ [а-яёА-ЯЁ]+ ]];
  },
  {
    name = "Comment"; fgcolor = "gray7";
    pattern = [[ ^\s*\/\/.* ]];
  },
  {
    name = "Digit"; fgcolor = "white";
    pattern = [[ [\d\W]+? ]];
  },
}

Class {
  name = "My editor";
  filemask = "*.txt;readme";
  syntax = syntax_text;
  fastlines = 0;
  firstline = "text";
}
