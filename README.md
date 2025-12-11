# My AHK v2 scripts
A few miscellaneous scripts I use in my day-to-day work or personal life.

## NeatClipboard

A clipboard helper and cheatsheet manager. Press `Win + Alt + V` to open.

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
  - clip: "text to copy"
    description: "what this clip is for"
    group: "Optional Group Name"
```

## Disclaimer
I am putting it out there just so it may be of help to someone, some day. I am not responsible if you choose to use any of my stuff at your own risk!

## Add to Windows Startup
Create script file shortcut in File Explorer; Run (Win+R) "shell:startup" to open Startup folder; Move shortcut in there.