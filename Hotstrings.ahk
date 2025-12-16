#Requires AutoHotkey v2.0

; If in VS Code or terminal window, expand npm commands
#HotIf WinActive("ahk_exe Code.exe") || WinActive("ahk_exe WindowsTerminal.exe") || WinActive("ahk_exe ConEmu64.exe") || WinActive("ahk_exe Antigravity.exe")
    ; Git
    :*:gmo`t::git merge origin/
    :*:gac`t::git add . && git commit -m "chore: docs" && git push
#HotIf
