local syntax_tcl =
{
  bgcolor = "darkblue";
  bracketmatch = true;
  {
    name = "Comment"; fgcolor = "gray7";
    pattern = [[ \#.* ]];
  },
  {
    name = "Literal"; fgcolor = "white";
    pattern = [[ (?i) \b
      (?: 0x[\dA-F]+ |
          \d+        |
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
    name = "Depoint"; fgcolor = "purple";
    pattern = [[\$\w+]];
  },
  {
    name = "Keyword"; fgcolor = "yellow";
    pattern = [[ \b(?:
        after|aio|alarm|alias|append|apply|array|binary|break|case|catch|cd|class|clock|close|collect|
        concat|continue|curry|dict|elseif|else|env|eof|error|eval|eventloop|exec|exists|exit|expr|fconfigure|
        file|finalize|flush|for|foreach|format|getref|gets|glob|global|history|if|incr|info|interp|join|kill|
        lambda|lappend|lassign|lindex|linsert|list|llength|lmap|load|local|loop|lrange|lrepeat|lreplace|
        lreverse|lsearch|lset|lsort|namespace|oo|open|os.fork|os.gethostname|os.getids|os.uptime|os.wait|
        pack|package|pid|posix|proc|puts|pwd|rand|range|read|ref|regexp|regsub|rename|return|scan|seek|
        set|setref|signal|sleep|socket|source|split|stackdump|stacktrace|string|subst|super|switch|syslog|
        tailcall|tcl::prefix|tell|then|throw|time|tree|try|unknown|unpack|unset|upcall|update|uplevel|upvar|
        vwait|while|zlib
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
  name = "TCL";
  filemask = "*.tcl";
  syntax = syntax_tcl;
}
