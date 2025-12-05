# Replace EX — User Manual

Version: based on replace_ex.lua (commit ac8b3e0)
Last updated: 2025-12-05

Overview
--------
Replace EX is a Find-and-Replace utility implemented as a Far Manager macro (area: Shell). It lets you search and replace text across files with optional regular expression support and an advanced "function mode" that runs Lua code for replacements. The tool is interactive: it can prompt per match, per file, or apply changes automatically.

Key features
- Search and replace across files in the current panel directory (optionally recursive).
- File mask support (wildcards).
- Regular expression mode with flags (case-insensitive, extended, multiline, treat file as a single line).
- "File as a line" mode to treat entire file contents as one string (useful for multi-line patterns).
- Function mode: supply Lua code for custom replacements, with per-file initialization and finalization code and a shared environment.
- Ask/confirm replacement dialogs with "yes", "yes for this file", "yes for all files", "skip", and "cancel" options.
- Skips binary files (contains NUL or invalid UTF-8) and very large files (over 256 MiB by default).
- Macro keybinding: Ctrl+Alt+E (id: 11986160-83AE-474D-9E85-D615A77AF658).

How to run
----------
- Place the macro in your Far Manager macros directory (it's already implemented as a Macro block in replace_ex.lua).
- Open the Shell (Files) panel and navigate to the directory where you want the replacements to start.
- Press Ctrl+Alt+E (or run the macro by name "SUPER Replace") to open the Replace EX dialog.

Dialog fields and options
-------------------------
Items you will see in the dialog:

- Recursively
  - If checked, subdirectories are searched recursively.

- File mask
  - Standard wildcard masks (e.g. `*.txt`, `**/*.lua` depending on Far's mask rules). Mask is validated by Far.

- Search for
  - The text or regular expression to search for.
  - If empty, the dialog will warn and not run.

- Replace with
  - Replacement string (or Lua code when Function mode is enabled).

- Regular expressions
  - Toggle regular expression mode.
  - When enabled, extra regex-related options become available.

- Case sensitive
  - When checked, searches are case-sensitive; otherwise, case-insensitive.

- Whole words
  - Enclose the search pattern with word boundaries (`\b... \b`).

- Ignore spaces (Extended)
  - When regex mode is on, the "x" flag is added, allowing whitespace in the pattern and `#` comments as per extended regex behavior.

- Multi-line
  - Adds the "m" regex flag, affecting `^` and `$` behavior.

- File as a line
  - Adds the "s" regex flag making `.` match newlines, effectively allowing the file to be treated as a single text string for regex matching.

- Function mode
  - When checked, the "Replace with" field becomes Lua code. You can also provide:
    - Initial code (run once before processing files)
    - Final code (run once after processing files)
  - The replacement code runs in a custom environment (see Function Mode section below).

Buttons
- Run — execute the search-and-replace operation.
- Clear — clears controls.
- Reload — reload saved settings into controls.
- Save — save current settings.
- Cancel — close the dialog without changes.

Replacement syntax (normal mode)
-------------------------------
- Escape sequences:
  - Use backslash escapes in the replacement text: `\n`, `\t`, `\r`, `\f`, `\a`, `\e`.
    - Example: Replace `\n` in replace box will insert a newline character.

- Capture references:
  - Use `$0`, `$1`, `$2`, ... `$9`, `$A` ... `$Z` to insert captures from the search regular expression.
  - $0 corresponds to the entire match; $1 to the first user capture, $2 to the second, etc.
  - Letters (A..Z) extend capturing beyond single-digit indexes (base-35 notation is used internally).
  - Example: Search: `(foo)(bar)` (in regex mode) and Replace: `$1-$2` → yields `foo-bar`.

Notes about indexing: The tool wraps the provided search pattern into an extra capturing group internally, so `$0` refers to the full match (the wrapper group). `$1` refers to the first capture from the user's original pattern, `$2` to the second, and so on. The dialog validates capture indices (it will refuse replacements referencing non-existent captures).

Interactive confirmation behavior
---------------------------------
When replacements are performed, you can be prompted to confirm each replacement. The per‑match dialog offers options:
- Yes — replace this occurrence.
- Yes for this file — replace remaining occurrences in this file without further prompts.
- Yes for all files — replace all remaining occurrences in all files without further prompts.
- Skip — skip this occurrence.
- Skip for this file — skip the remaining occurrences in this file.
- Cancel — abort the entire operation.

Function mode (Lua replacement)
-------------------------------
Function mode gives you full Lua control over replacements:

- How it works
  - The Replace-with field becomes Lua code (a function body). Internally the macro builds a replacement function from the code. The replacement function is called for each match with captures as arguments.
  - You may supply optional Initial code and Final code. All three (initial, replacement, final) share the same environment.

- Environment variables available in your replacement function:
  - T — table of captures:
    - T[0] — whole match
    - T[1..] — capture groups
    - The replacement builder sets up T as the simplest way to access captures from the function.
  - FN — current file name.
  - M — number of matches in the current file (incremented as matches are seen).
  - R — number of replacements made in the current file (incremented whenever you return a non-nil string to replace).
  - item — file item table (fields such as FileSize, FileAttributes, etc. as provided by Far's recursive search).
  - n1, n2 — numeric counters you can use freely per-file (initialized to 0).
  - a1, a2 — tables you can use freely per-file (initialized to {}).
  - The environment starts with N1, N2, A1, A2 and then per-file lowercase counterparts are set; both forms are present to reduce surprises.
  - The initial code runs once before processing files; final code runs after everything is processed.

- Replacement function behavior
  - Your function should return a string (or number convertible to string) to perform a replacement.
  - To skip replacing a match, return nil or false.
  - Returning a non-string non-number signals the tool to stop making replacements for the remainder of the current file.

- Example
  - Initial code:
    local sum = 0
  - Replace code:
    sum = sum + tonumber(T[1] or 0)
    return tostring(sum)
  - Final code:
    print("Done. Last sum:", sum)

Safety and constraints
----------------------
- Large files:
  - Files larger than 256 MiB (2^28 bytes) are by default not processed. The tool asks whether to skip, process anyway, or terminate when large files are encountered.

- Binary / encoding:
  - Files containing NUL bytes (`\0`) or invalid UTF-8 are skipped (the utility is designed to operate on text files only).

- Atomicity and backups:
  - Changes are written back to the original file (opened with "wb" and overwritten). No automatic backups are created. Make sure you have backups or version control if you need to revert changes.

- Error handling:
  - If a file cannot be opened for read or write, the tool presents a dialog to continue, skip, or terminate.
  - Invalid regex or invalid replacement function code will be reported before any file processing starts.

Limitations and behavior details
--------------------------------
- The search pattern and flags:
  - If "Regular expressions" is unchecked, the search text is escaped so it is treated literally.
  - "Whole words" wraps the search with `\b` boundaries.
  - The dialog builds the regex with a wrapper group so `T[0]` and `$0` refer to the full match.

- Replacement token parsing:
  - Replacement parsing recognizes `$` followed by characters in [0-9A-Z] (case-insensitive). This allows references beyond 9 (e.g. `$A` for capture index 10). The mapping is based on a base-35 conversion (digits and letters).

- Matching engine:
  - The script uses Far's regex API (`regex.new`, `:tfind` and related functions) and adapts flags to the pattern. Behavior matches the regex engine provided in your Far+Lua environment.

Examples
--------
1) Simple literal replace (non-regex)
- File mask: `*.txt`
- Search for: `foo`
- Replace with: `bar`
- Regular expressions: unchecked
- Result: all literal `"foo"` occurrences replaced with `"bar"` (interactive confirmation available).

2) Regex replace with captures
- File mask: `*.txt`
- Search for: `(\d+)-(\d+)`
- Replace with: `$2/$1`
- Regular expressions: checked
- Example: `2025-12` -> `12/2025`.

3) Function mode example (increment numbers in a file)
- Regular expressions: checked
- Search for: `(\d+)`
- Function mode: checked
- Initial code:
  count = 0
- Replace function:
  count = count + 1
  return tostring(tonumber(T[1]) + 1)
- Final code:
  print("Processed matches in last file:", count)

Tips
----
- Use Save/Reload to store common search/replace sets.
- Test on a copy of a directory first, especially when using function mode or regexes that might match more widely than expected.
- Use interactive confirmations the first time you run a complex replacement to verify expected changes.
