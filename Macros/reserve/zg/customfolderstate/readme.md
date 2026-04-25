This MoonScript macro implements “custom folder state” persistence for FAR Manager panels: when you enter specific folders (including plugin panels), it automatically applies a predefined sort mode and sort order, and can run an optional callback action. It tracks state separately for the active and passive panels, updates state on folder changes, and restores special states on exit.

Key points:

- **Loads user configuration**: `pcall(require, "customfolderstate_user")`. If absent, uses an empty config. The user module can provide:
  - a list of folder rules (strings or tables),
  - default `Sort` / `Order`,
  - an `Action` function callback (`init.Action`).

- **Platform handling (Windows vs non-Windows)**:
  - Detects path separator (`package.config:sub(1,1)`).
  - Normalizes case to lowercase on Windows for reliable comparisons.
  - Uses `win.Uuid()` and a 16-byte `\0` UUID as a “zero” plugin id on Windows; uses `0` on non-Windows.

- **Folder/panel identity model (`class Panel`)**:
  - Captures `Name`, `Param`, `PluginId`, `File`, plus `Sort`, `Order`, and `Action`.
  - Custom equality (`__eq`) treats a configured folder ending with `/*` (implemented via matching a trailing `\*`) as a **prefix match** (i.e., “all subfolders”), and also requires `Param`, `PluginId`, and `File` to match.

- **Configuration preprocessing**:
  - Each rule is converted into a `Panel` object and stored in `folders`.
  - Expands environment variables in folder names:
    - Windows: `%VAR%`
    - non-Windows: `$(VAR)`
  - Normalizes `PluginId`, fills defaults (`Param`/`File` empty), and applies per-rule or global default `Sort`/`Order`.

- **Core behavior on folder change**:
  - `main()` reads current directories of **active** and **passive** panels via `panel.GetPanelDirectory`.
  - If a panel changed since last time, `process(idx, current)` runs:
    - Looks for a matching rule in `folders`.
    - Remembers the panel’s previous sort/order (unless it was already in a “Special” overridden state).
    - If a rule matched and has `Sort`, applies that rule’s sort/order and marks the panel state as `Special`.
    - Applies the sort mode:
      - If `sort` is a custom sort (`>= F.SM_USER`), uses `_G.Panel.SetCustomSortMode(...)`.
      - Otherwise uses `panel.SetSortMode` / `panel.SetSortOrder`.
    - Preserves visual position by re-reading panel info and calling `panel.RedrawPanel` with `CurrentItem` and original `TopPanelItem`.
    - Runs an **action callback** if present:
      - rule-specific `found.Action`, otherwise `folders.Action` (global),
      - called as `func(idx, {Name, Param, PluginId, File})`.

- **Events registered**:
  - `FolderChanged` → calls `main()` to apply rules dynamically.
  - `ExitFAR` → for any panel still in a `Special` state, re-applies the remembered sort/order (effectively restoring the “special” sorting choice/state right before exit).

Overall: it’s a per-folder (and per-plugin-panel) sort-mode manager for FAR2m/FAR3 panels, driven by a user config module, with wildcard folder support, environment-variable expansion, and optional hooks.