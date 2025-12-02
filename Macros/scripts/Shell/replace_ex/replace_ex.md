# Replace EX — Replace in files (SUPER Replace)

Script: replace_ex.lua
Macro: Ctrl+Alt+E
Dialog title: "Replace in files"

Overview
--------
Replace EX is a Far Manager macro/utility that performs search-and-replace operations across files. It supports plain-text replacement, regular expressions with common flags, and a powerful "function mode" where the replacement is a Lua expression or function that can inspect/modify each match and track state across files. The macro is intended for UTF-8 text files and skips binary files and files with invalid UTF-8.

Important highlights:
- Works from the current panel directory and walks files matching a mask (optionally recursively).
- By default the utility will prompt (Ask) before modifying each file; behavior differs in function mode (see below).
- Replacements are done in-memory: file contents are loaded, transformed, and written back if changed.
- The macro will not process files containing NULs or invalid UTF-8 sequences.
- No automatic backups are made — make sure to back up important files first.

Dialog fields and controls
--------------------------
Main controls:
- File mask — file glob pattern(s) used for selecting files (history: "Masks").
- Search for — text or regular-expression pattern to search for (history: "SearchText").
- Replace with — replacement text, or Lua code when Function mode is enabled (history: "ReplaceText").
- Recursively — search subdirectories.
- Run / Clear / Reload / Save / Cancel buttons:
  - Run — start the operation.
  - Clear — clear dialog fields (does not close dialog).
  - Reload — restore the saved dialog state/settings.
  - Save — persist current dialog state/settings (stored under key Replace_EX).
  - Cancel — close dialog.

Options:
- Regular expressions — if checked, treats "Search for" as a regular-expression pattern.
- Case sensitive — when unchecked, matching is case-insensitive.
- Whole words — search pattern is wrapped with word boundaries (\bpattern\b).
- Extended (regex) — ignore whitespace/comments in the regex (flag x).
- Multi-line (regex) — multi-line mode (flag m).
- File as a line (regex) — let '.' match newlines (flag s). Treat file as a single line.
- Function mode — treat the Replace field as Lua code rather than plain replacement text.
- Initial code / Final code — Lua code executed before starting and after finishing (only used in Function mode).

Histories and settings:
- The dialog saves settings (file mask, regex flags, etc.) with Save and Reload. The code uses a settings key "Replace_EX" in the persistent settings (via the script's settings facility).
- Edit boxes have edit ext="lua" for function/initial/final fields in function mode.

Operation modes explained
-------------------------

1) Plain text mode (Regular expressions unchecked)
- The "Search for" string is treated as a literal string.
- Special pattern characters are automatically escaped (so you don't need to escape punctuation).
- Matching respects the Case sensitive and Whole words options.
- The search is converted to a regex-escaped pattern under the hood, then applied.

2) Regular expression mode
- Uses the regex library used by the script (via regex.gsub).
- Flags built:
  - case-insensitive when Case sensitive is unchecked -> adds "i"
  - extended -> adds "x" (ignore whitespace/comments)
  - multiline -> adds "m"
  - file-as-line -> adds "s"
- Replace field processing:
  - Recognizes standard backslash escapes: \n, \r, \t, \f, \a, etc.
  - Dollar placeholders like $0, $1, $2 are converted to the form expected by regex.gsub (the script converts $n to %n).
  - Escaped characters like \. are unescaped appropriately.
- Whole words wraps the pattern with \b on both ends.

3) Function mode (power user)
- Replace field becomes a Lua chunk that is evaluated and used to compute replacements.
- The Replace field is loaded as a Lua chunk with the following automatic prefix:
    T = { [0]=select(1,...); select(2, ...) }
  then your code follows. This creates a table T visible to your code:
  - T[0] is the entire match (the whole substring matched by the search).
  - T[1], T[2], ... are the captured groups from the regex pattern.
- In addition, the environment for the chunk includes several helper variables (per-file, updated before processing each file):
  - FN — filename being processed (string)
  - M — number of matches found so far in the current file
  - R — number of replacements performed so far in the current file
  - item — file metadata (size and attributes as passed by far.RecursiveSearch)
  - n1, n2 — counters you may use from your own code (initialized to 0 each file)
  - a1, a2 — tables you can use for accumulating state (initialized empty each file)
- Initial code (InitFunc) and Final code (FinalFunc) are Lua chunks also executed in the same environment before/after processing (this environment persists across files but per-file fields such as FN/M/R are updated).
- What your Replace function should return:
  - return nil or false -> no replacement for that match (no change).
  - return string or number -> used as replacement text.
  - return any other non-string, non-number true/boolean/object -> interpreted as stop further replacements for this file (file_no), i.e. subsequent matches in that file will not be replaced.
- Per-match interactive prompting:
  - When in function mode, the script does not ask to modify each file before processing (Ask = false). However, inside the replacement function the script will prompt per match (AskForReplace) unless you set file_yes to true or return a value triggering auto-accept.
  - The AskForReplace dialog offers options: Yes, Yes for this file, Yes for all files, Skip, Skip for this file, Cancel.

Examples
--------

Basic plain-text replace (non-regex)
- Purpose: replace "TODO" with "DONE" in *.txt files in current directory:
  - File mask: *.txt
  - Search for: TODO
  - Replace with: DONE
  - Regular expressions: unchecked
  - Run

Regex with capture groups
- Purpose: swap two words separated by a colon "key:value" to "value:key":
  - File mask: *.cfg
  - Regular expressions: checked
  - Search for: (\w+):(\w+)
  - Replace with: $2:$1
  (The script converts $1/$2 to the proper replacement syntax for the underlying regex engine.)

Function mode example: conditional replacement and counting
- Suppose you want to increment a number captured in a pattern:
  - Regular expressions: checked
  - Function mode: checked
  - Search for: (\bcount:\s*)(\d+)
  - Replace with (Lua chunk):
      -- increment captured number and update per-file counter
      local prefix = T[1]      -- "count: "
      local num = tonumber(T[2]) or 0
      return prefix .. tostring(num + 1)

Notes about the T table in Function mode:
- T[0] = whole match
- T[1..N] = captures (if your regex uses captures)
- Example: pattern "(hello) (world)" -> T[0] = "hello world", T[1] = "hello", T[2] = "world"

Prompts and interactions
------------------------
- Before processing each file (when not in function mode), the script will prompt:
  - Modify (process this file)
  - All (process this and all following files without asking)
  - Skip (don't process this file)
  - Cancel (terminate operation)
- During replacements (function mode), the replace function can trigger per-match prompts:
  - The prompt offers: Yes, Yes for this file, Yes for all files, Skip, Skip for this file, Cancel.
  - Use the return values of your replacement code and env variables to control interactive behavior.

Implementation details & limitations
-----------------------------------
- The macro uses far.RecursiveSearch starting from the current panel directory (panel.GetPanelDirectory(nil,1).Name) and the provided file mask.
- Files with attributes matching [dejk] (directory, reparse point, device block, socket) are skipped.
- Binary/unsafe files:
  - Files containing \0 (NUL) or invalid UTF-8 are skipped.
- Empty files: due to a Lua 5.1/LuaJIT behavior the code handles empty file reads explicitly (an empty-file workaround).
- Files are fully loaded into memory; for very large files this may be memory-intensive.
- When writing changed content back, the file is overwritten. There is no automatic backup/undo provided by the script — consider using version control or manual backups before running large-scale replacements.
- If a file cannot be opened for reading or writing, the script offers a "Break/Continue" choice.

Tips and best practices
-----------------------
- Test first on a small sample or a copy of your directory to confirm expected behavior.
- If using complex regexes, test them in a regex tester or on a sample file first.
- Use the Save button to store commonly used patterns and options; Reload to restore them.
- Use Function mode only if you need per-match logic or complex transformations. Function mode is powerful but requires Lua knowledge and care.
- Consider using the "Yes for all files" options (either via prompts or via your function logic) to speed up large runs when interactive prompts are not needed.
- If you intend to run against many or large files, ensure you have a current backup or commit to version control first.

Troubleshooting
---------------
- "Invalid search string" message — occurs if the Search for field is empty or, when regex is checked, the regex cannot be compiled. Verify the pattern.
- "Replace field error" / "Initial code error" / "Final code error" — occurs when the provided Lua chunk has a syntax/error at load time. Fix Lua code; use simple prints during development.
- No changes seen — verify file mask, recursion option, search expression, and that files are not skipped as binary or unreadable.
- If the script prompts for replacing content but you expected an automatic change, double-check function mode logic and file_yes/yes_to_all behavior in your function code.

Safety checklist before a big run
---------------------------------
1. Back up the directory or ensure you have changes committed in version control.
2. Test the search and replacement on a handful of files (small file mask).
3. If in doubt, keep Regular expressions unchecked and use plain-text replace, or test regex in a separate tester.
4. Use Save to persist working parameters, so you can reuse or revert.

Technical references
--------------------
- Settings key used by the macro: set_key="temp", set_name="Replace_EX" (saved via the script's settings facility).
- Macro binding details: Macro { area="Shell"; key="CtrlAltE"; description="SUPER Replace"; flags="NoPluginPanels" }
- The script uses the regex library via regex.gsub and passes flags string (e.g. "ixms").

License and attribution
-----------------------
- This documentation pertains to the replace_ex.lua script in this repository.
- Follow the repository license for redistribution and modification.
