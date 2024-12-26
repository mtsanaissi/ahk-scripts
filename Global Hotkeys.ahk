; #NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
; SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
; SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.

; CTRL + SPACE -> set active window always on top
; ^SPACE:: Winset, Alwaysontop, , A

; Remap Win+V to CTRL+'
#v::^'

; CTRL + MB4 = previous media; CTRL + MB5 = next media.
; Check before if your MB4 and MB5 are tied to something in the mouse software.
^Volume_Down::
{
  Send "{Media_Prev}"
}
^Volume_Up::
{
  Send "{Media_Next}"
}

; CTRL+ALT+S -> gets the selected text and replaces newlines with commas and spaces
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

; CTRL + SHIFT + Q -> replace www with old
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

; Win + N para alternar janela entre monitores
;#n::
;{
;  ;active_id := WinGetID("A")
;  isDefaultPos := true
;  if (isDefaultPos) {
;    ; First click - save position, move to Display 2, and maximize
;    WinGetPos &initialX, &initialY, &initialWidth, &initialHeight, "A"
;    ;initialPos := initialX "|" initialY "|" initialWidth "|" initialHeight
;    
;    ;SysGet MonitorWorkArea, MonitorWorkArea, 2 ; Assuming Display 2 is index 2
;    WinMove 0, 0, ,, "A"
;    WinMaximize "A"
;    isDefaultPos := false
;  } else {
;    ; Subsequent clicks - restore to initial position and size
;    ;Loop Parse, initialPos, "|"
;    ;{
;    ;  if (A_Index = 1) {
;    ;    initialX := A_LoopField
;    ;  } else if (A_Index = 2) {
;    ;    initialY := A_LoopField
;    ;  } else if (A_Index = 3) {
;    ;    initialWidth := A_LoopField
;    ;  } else if (A_Index = 4) {
;    ;    initialHeight := A_LoopField
;    ;  }
;    ;}
;    
;    WinMove initialX, initialY, initialWidth, initialHeight, "A"
;    isDefaultPos := true
;  }
;  Return
;}