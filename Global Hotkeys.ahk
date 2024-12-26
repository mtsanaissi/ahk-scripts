#Requires AutoHotkey v2.0

; Remap Win+V to CTRL+'
; I use this in conjunction with Ditto (clipboard manager)
#v::^'

; CTRL + MB4 = previous media; CTRL + MB5 = next media.
; Check before if your MB4 and MB5 are tied to something in your mouse software.
; In my case, MB4 and MB5 are for Volume_Down and Volume_Up.
^Volume_Down::
{
  Send "{Media_Prev}"
}
^Volume_Up::
{
  Send "{Media_Next}"
}

; CTRL+ALT+S -> gets the selected text and replaces newlines with commas and spaces.
; Very useful for working with SQL and converting a list of values into a comma-separated string
^!s::
{
  A_Clipboard := ""
  ; Copy selected text to clipboard
  Send "^c"
  ClipWait
  ; Replace newline character with comma and blank space
  A_Clipboard := StrReplace(A_Clipboard, "`r`n", ", ")
  Send "^v"
}


; CTRL + F11 -> remove minimize and maximize buttons, set the window to be always on top, start a timer to test if it's minimized and then restore it
; CTRL + F12 -> undo the above
global winid := 0

^F11::
{
  ;WinSetStyle("-0x30000", "A")    ; remove minimize and maximize buttons
  ;WinSetStyle("-0xC00000", "A")
  ;WinSetStyle("+0x80000000", "A")
  WinSetAlwaysOnTop(1, "A")    ; set it on top of all other windows
  global winid := WinGetID("A")          ; keep the ID of the active window
  ;MsgBox "Win ID = " winid
  SetTimer RestoreWindow, 500  ; run RestoreWindow subroutine every half a second
  ;SetTimer WinRestore("ahk_id " winid), 500
}

^F12::
{
  ;WinSetStyle("+0x30000", "A")    ; add minimize and maximize buttons
  ;WinSetStyle("+0xC00000", "A")
  ;WinSetStyle("-0x80000000", "A")
  SetTimer RestoreWindow, 0  ; stop RestoreWindow from looping
  global winid := 0
  WinSetAlwaysOnTop(0, "A")   ; undo on top
}
  
RestoreWindow()
{
  ;WinGet, WinState, MinMax, ahk_id winid
  ;MsgBox "Win ID = " winid
  If IsSet(winid)
  {
    MinMax := WinGetMinMax(winid)
    If MinMax = -1                ; if window is minimized
      WinRestore(winid)
  }
}

  
;; Make windows fabulous?
;^F10::
;    WinGetTitle, currentWindow, A
;    IfWinExist %currentWindow%
;    WinSet, Style, -0xC40000,
;    ; WinMove, , , 0, 0, A_ScreenWidth, A_ScreenHeight
;    DllCall("SetMenu", "Ptr", WinExist(), "Ptr", 0)
;    return

; CTRL + SHIFT + Q -> replace www with old (don't ask!)
^+Q::
{
  Send "{F4}"
  Send "{Home}"
  Send "{Home}"
  Send "^{Right}"
  Send "{Delete 3}"
  Send "old"
  Send "{Enter}"
  Send "{Enter}"
  return
}

; CTRL + SPACE -> set active window always on top
; ^SPACE:: Winset, Alwaysontop, , A