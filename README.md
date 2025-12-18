# My AHK v2 scripts
A few miscellaneous scripts I use in my day-to-day work or personal life.

## NeatClipboard

A clipboard helper and cheatsheet manager. Press `Win + Alt + V` to open.

### Shortcuts
- `Win + Alt + V` — Open the NeatClipboard window
- `Ctrl + F` — Focus search box (and select all)
- `Ctrl + 1..9` — Switch to tab 1..9
- `Alt + 1..9` — Copy/activate entry 1..9
- `1..9` — Copy/activate entry 1..9 (when search box is not focused)

### Features
- **Tabbed interface** with clips organized by category
- **Live search** across all clips (optionally includes descriptions)
- **Groups** for visual organization within each tab
- **Click-to-copy** with optional auto-paste
- **Keyboard shortcuts**: `Ctrl+F` (search), `Ctrl+1-9` (tabs), `Alt+1-9` (entries)

### Setup
1. Copy files from `example-clips/` to `clips/`
2. Customize the YAML files with your own clips
3. The `clips/` folder is gitignored for privacy

### YAML Format
```yaml
title: Tab Name
displayOrder: 1  # Lower = appears first
items:
  # Option A: group container (avoids repeating group on each clip)
  - group: "Optional Group Name"
    items:
      - clip: "text to copy"
        description: "what this clip is for"

  # Option B: classic per-clip group (still supported)
  - clip: "text to copy"
    description: "what this clip is for"
    group: "Optional Group Name"
```

## Global Hotkeys

Small global remaps and helpers (media controls, text transforms, and window pinning).

### Shortcuts
- `Win + V` — Remapped to `Ctrl + '` (intended for Ditto clipboard manager)
- `Win + S` — Send `Ctrl + Alt + NumLock`
- `Ctrl + Volume_Down` — Previous media track (often mapped to mouse MB4)
- `Ctrl + Volume_Up` — Next media track (often mapped to mouse MB5)
- `Ctrl + Alt + S` — Replace selected text newlines with `, ` and paste back (restores clipboard; hold `Shift` to keep transformed text)
- `Ctrl + F11` — Pin active window on top and auto-restore it if minimized
- `Ctrl + F12` — Undo the above (stop auto-restore + unpin)
- `Hold LButton` + `Volume_Up` — Lock mouse movement (until LButton is released)
- `Ctrl + Shift + Q` — Address-bar macro to swap `www` → `old` (very specific workflow)

## Hotstrings

Typing expansions for VS Code and terminal apps (Windows Terminal/ConEmu/Antigravity).

### Shortcuts
- Type `nf` then `Tab` — `npm run format`
- Type `nt` then `Tab` — `npm test`
- Type `nb` then `Tab` — `npm run build`
- Type `nd` then `Tab` — `npm run dev`
- Type `gmo` then `Tab` — `git merge origin/`
- Type `gac` then `Tab` — `git add . && git commit -m "chore: docs" && git push`

## Window Manager

One-key window mover for dual-monitor setups: toggles an app between displays and restores it back.

### Shortcuts
- `Win + N` — Move active window to the other monitor (maximized); press again to restore original position/size

## fix_MButton

Debounces the middle mouse button to prevent accidental double-activation.

### Shortcuts
- `MButton` — Normal middle-click, but ignores rapid re-triggers within ~300ms

## BlockPBIPublish

Shows a small always-on-top “NO GIT!” warning box when Power BI Desktop is the active window.

### Shortcuts
- (none) — Runs in the background via a timer; visibility depends on the configured Power BI window identity

## Disclaimer
I am putting it out there just so it may be of help to someone, some day. I am not responsible if you choose to use any of my stuff at your own risk!

## Add to Windows Startup
Create script file shortcut in File Explorer; Run (Win+R) "shell:startup" to open Startup folder; Move shortcut in there.

## ShortcutsHelper

A shortcut reference overlay that shows global shortcuts first, then shortcuts for the currently focused app, then the rest (alphabetical).

### Shortcuts
- `Win + Ctrl + ;` — Toggle the ShortcutsHelper window

### Setup
1. Copy files from `example-shortcuts/` to `shortcuts/`
2. Customize the YAML files with your own shortcuts
3. The `shortcuts/` folder is gitignored for privacy

### YAML format
```yaml
title: App Name
type: app         # or "global"
displayOrder: 10  # optional; lower shows first
match:            # optional for apps; used for auto-detection
  exe: Code.exe   # string or list of strings
groups:
  - name: Group Name
    items:
      - keys: Ctrl+P
        desc: Quick Open
```
