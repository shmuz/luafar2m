local syntax_cmake =
{
  bgcolor = "darkblue";
  bracketmatch = true;
  --bracketcolor = 0xE3;
  {
    name = "Comment"; fgcolor = "gray7";
    pattern = [[ \# .* ]];
  },
--  {
--    name = "Literal"; fgcolor = "white";
--    pattern = [[
--      \b (?: 0[xX][\da-fA-F]+ | (?:\d+\.\d*|\.?\d+)(?:[eE][+-]?\d+)? | false | nil | true) \b ]];
--  },
--  {
--    name = "Compare"; fgcolor = "yellow";
--    pattern = [[ == | <= | >= | ~= | < | > ]];
--  },
  {
    name = "String1"; fgcolor = "green"; color_unfinished= "darkblue on purple";
    pat_open     = [[ " ]];
    pat_skip     = [[ (?: \\. | [^\\"] )* ]];
    pat_close    = [[ " ]];
    pat_continue = [[ \\$ ]];
  },
  {
    name = "Command"; fgcolor = "yellow";
    --color = { ForegroundColor=0x00FF00; BackgroundColor=0x000080; Flags={FCF_FG_BOLD=1} };
    pattern = [[ (?i) (?<![^\s(){}]) (?:
      if|else|elseif|endif|while|endwhile|foreach|endforeach|break|continue|
      function|endfunction|macro|endmacro|
      set|unset|string|defined|
      exists|include|return|file|math
      ) (?![^\s(){}]) ]];
  },
  {
    name = "Argument"; fgcolor = "yellow";
    --color = { ForegroundColor=0x00FF00; BackgroundColor=0x000080; Flags={FCF_FG_BOLD=1} };
    pattern = [[ (?<![^\s(){}]) (?:
      OR|AND|NOT|
      DEFINED|MATCHES|EQUAL|STREQUAL|
      VERSION_LESS|VERSION_GREATER|VERSION_EQUAL|VERSION_GREATER_EQUAL|VERSION_LESS_EQUAL
      ) (?![^\s(){}]) ]];
  },
--  {
--    name = "Function"; fgcolor = "purple";
--    pattern = [[ \b(?:
--      _G|_VERSION|assert|collectgarbage|dofile|error|getfenv|getmetatable|ipairs|load|loadfile|loadstring|module|next|
--      )\b ]];
--  },
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
  name = "CMake";
  filemask = "*.cmake;CMakeLists.txt;CMakeLists";
  syntax = syntax_cmake;
  firstline = "cmake";
}
