#Requires AutoHotkey v2.0

; Hotstrings
:*:gmo`t::git merge origin/
:*:gac`t::git add . && git commit -m "chore: docs" && git push

; If in VS Code or terminal window, expand npm commands
#HotIf WinActive("ahk_exe Code.exe") || WinActive("ahk_exe WindowsTerminal.exe") || WinActive("ahk_exe ConEmu64.exe")
:*:nf`t::npm run format
:*:nt`t::npm test
:*:nb`t::npm run build
#HotIf
