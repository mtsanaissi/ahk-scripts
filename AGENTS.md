# AI Agent Notes (AutoHotkey v2 workspace)

This repo contains personal AutoHotkey **v2** scripts. Changes should be small, readable, and safe: these scripts can simulate input, read clipboard text, and manipulate windows.

## Ground rules

- **Target runtime:** AutoHotkey **v2.x** only (`#Requires AutoHotkey v2.0`). Do not introduce v1 syntax.
- **OS/runtime:** Scripts are meant to run on **Windows** (even if the repo is edited from WSL).
- **Public repo:** Never add personal data, secrets, or private clip content to tracked files.

## Privacy & security (high priority)

- **Do not commit user content**: `clips/` is intentionally gitignored; keep it that way. Use `example-clips/` for sanitized samples only.
- **Avoid data exfiltration patterns:** don’t add HTTP calls, telemetry, logging of clipboard/window titles, or “send to pastebin” style helpers.
- **Minimize clipboard exposure:** only read selected text/clipboard when required, avoid persisting it, and don’t print it to tooltips/logs.
- **Be explicit with automation:** AHK can act like malware if careless. Avoid keylogging-like hooks, broad `#InstallKeybdHook`, or capturing all input unless the script’s purpose requires it and README documents it.
- **No arbitrary code execution from data files:** don’t evaluate/execute YAML or clipboard text as code; treat it as data.

## AHK v2 syntax reminders (common pitfalls)

- **Expressions everywhere:** `if (x)`, `while (x)`, etc. Parentheses required for most function calls.
- **Variables are expressions:** no legacy `%var%` deref in most places; use concatenation (`"a" var`) or format functions.
- **Commands became functions:** e.g. `MsgBox(...)`, `WinMove(...)`, `WinGetPos(&x,&y,&w,&h, ...)`, `ControlGetFocus(...)`.
- **Hotkeys:**
  - `#` Win, `!` Alt, `^` Ctrl, `+` Shift, `~` passthrough, `*` wildcard.
  - Use `#HotIf` / `HotIfWinActive(...)` to scope hotkeys carefully (avoid global collisions).
- **Objects:** prefer `Map()` / `Array` / `{}` and keep global state explicit (`global`, `static`).
- **Send/clipboard:** prefer `SendText` when you want literal text (no `{}` parsing). Be careful with `{}` escaping and timing (`ClipWait`, `SetTimer`).

## Workspace layout (what matters)

- `NeatClipboard.ahk`: GUI clipboard/cheatsheet manager. Loads YAML from `clips/*.yaml` via `Lib\\YamlParser.ahk`.
- `Global Hotkeys.ahk`: global hotkeys/remaps (media, window pinning, text transforms). Treat as “always on”.
- `Hotstrings.ahk`: editor/terminal-only expansions (scoped via `#HotIf WinActive(...)`).
- `Window Manager.ahk`: `Win+N` toggles moving/restoring windows across monitors.
- `fix_MButton.ahk`: debounces middle-click.
- `BlockPBIPublish.ahk`: shows a warning overlay when Power BI Desktop is active; window identity strings may be machine-specific.

## Editing conventions (keep it consistent)

- Keep scripts self-contained and readable; avoid over-abstraction.
- Prefer descriptive names over one-letter variables; keep `global` declarations near the top.
- Don’t reformat the whole file unless requested; match existing style in each script.
- Document new/changed shortcuts in `README.md` (and keep descriptions short).

## Testing / verification (manual)

- Run with AutoHotkey v2 on Windows (double-click or `AutoHotkey64.exe /restart <script.ahk>`).
- Validate hotkeys don’t conflict globally; use `#HotIf` scoping where possible.
- For window targeting, prefer `ahk_exe` + stable identifiers; when using `ahk_class`, note it may vary by version.
- Use AutoHotkey “Window Spy” to confirm `ahk_exe` / `ahk_class` / control names when troubleshooting.
