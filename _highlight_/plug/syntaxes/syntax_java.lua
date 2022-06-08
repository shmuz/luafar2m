local syntax_java =
{
  bgcolor = "darkblue";
  bracketmatch = true;
  {
    name = "LongComment"; fgcolor = "gray7";
    pat_open = [[ \/\* ]];
    pat_close = [[ \*\/ ]];
  },
  {
    name = "Comment"; fgcolor = "gray7";
    pattern = [[ \/\/.* ]];
  },
  {
    name = "Literal"; fgcolor = "white";
    pattern = [[ (?i) \b
      (?: 0x[\dA-F]+ L? |
          \d+ L?        |
          (?:\d+\.\d*|\.?\d+) (?:E[+-]?\d+)?
      )
    \b ]];
  },
  {
    name = "String"; fgcolor = "purple"; color_unfinished= "darkblue on purple";
    pat_open     = [[ " ]];
    pat_skip     = [[ (?: \\. | [^\\"] )* ]];
    pat_close    = [[ " ]];
    pat_continue = [[ \\$ ]];
  },
  {
    name = "Char"; fgcolor = "purple"; color_unfinished= "darkblue on purple";
    pattern = [[ ' (?: \\. | [^\\'] ) ' ]];
  },
  {
    name = "Keyword"; fgcolor = "yellow";
    pattern = [[ \b(?:
      abstract|continue|for|new|switch|
      assert|default|if|package|synchronized|
      boolean|do|goto|private|this|
      break|double|implements|protected|throw|
      byte|else|import|public|throws|
      case|enum|instanceof|return|transient|
      catch|extends|int|short|try|
      char|final|interface|static|void|
      class|finally|long|strictfp|volatile|
      const|float|native|super|while|true|false|null
      )\b ]];
  },
  {
    name = "Word"; fgcolor = "aqua";
    pattern = [[ \b\w+\b ]];
  },
  {
    name = "MathOp"; fgcolor = "white";
    pattern = [[ [^\w\s] ]];
  },
}

Class {
  name = "Java";
  filemask = "*.java";
  syntax = syntax_java;
}
