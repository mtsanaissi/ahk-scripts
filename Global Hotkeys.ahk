#Requires AutoHotkey v2.0

; ==============================================================================
; Global Hotkeys - System-wide Keyboard and Mouse Remaps
; ==============================================================================
; Provides system-wide hotkeys for common tasks like clipboard management,
; media control, text processing, and window management.
; ==============================================================================

; ==============================================================================
; Clipboard Management
; ==============================================================================

; Remap Win+V to CTRL+'
; Useful for Ditto (clipboard manager) compatibility
#v::^'

; ==============================================================================
; Media Control (Mouse Buttons)
; ==============================================================================
; CTRL + Mouse Button 4 = previous track
; CTRL + Mouse Button 5 = next track
; Note: Ensure your mouse software doesn't conflict with these buttons

^Volume_Down::
{
    try {
        Send("{Media_Prev}")
    } catch {
        ; Silent fallback: Media keys not supported on this system
    }
}

^Volume_Up::
{
    try {
        Send("{Media_Next}")
    } catch {
        ; Silent fallback: Media keys not supported on this system
    }
}

; ==============================================================================
; Text Processing
; ==============================================================================
; CTRL+ALT+S -> Convert selected text to comma-separated format
; Useful for SQL queries and converting lists to CSV format

^!s::
{
    try {
        ; Clear clipboard and copy selected text
        A_Clipboard := ""
        Send("^c")
        
        ; Wait for clipboard content with timeout
        if (!ClipWait(2)) {
            ; No text was selected or clipboard operation timed out
            return
        }
        
        ; Replace newlines with comma and space for CSV format
        processedText := StrReplace(A_Clipboard, "`r`n", ", ")
        processedText := StrReplace(processedText, "`n", ", ")
        
        ; Put processed text back to clipboard
        A_Clipboard := processedText
        
        ; Paste the processed text
        Send("^v")
    } catch Error as err {
        ; Graceful fallback: try to restore original clipboard
        ; Silent fallback: Clipboard operations failed
    }
}

; ==============================================================================
; Window Management
; ==============================================================================
; CTRL + F11 -> Make active window always on top with auto-restore
; CTRL + F12 -> Remove always-on-top and stop monitoring

; Constants for better maintainability
global WINID_NONE := 0
global RESTORE_CHECK_INTERVAL_MS := 500

; CTRL + F11: Make window always on top and monitor for minimization
^F11::
{
    try {
        ; Validate active window exists
        if !WinExist("A") {
            ShowHotkeyTooltip("No active window")
            return
        }
        
        ; Set window always on top
        try {
            WinSetAlwaysOnTop(1, "A")
        } catch {
            ShowHotkeyTooltip("Failed to set always on top")
            return
        }
        
        ; Store window ID for restoration monitoring
        try {
            global winid := WinGetID("A")
        } catch {
            ShowHotkeyTooltip("Failed to get window ID")
            return
        }
        
        ; Start monitoring timer to restore minimized windows
        SetTimer(RestoreWindow, RESTORE_CHECK_INTERVAL_MS)
        
        ShowHotkeyTooltip("Window set to always on top")
    } catch Error as err {
        ShowHotkeyTooltip("Window pinning failed")
    }
}

; CTRL + F12: Remove always-on-top and stop monitoring
^F12::
{
    try {
        ; Stop monitoring timer
        SetTimer(RestoreWindow, 0)
        
        ; Clear stored window ID
        global winid := WINID_NONE
        
        ; Remove always-on-top from active window
        try {
            WinSetAlwaysOnTop(0, "A")
        } catch {
            ; Continue even if this fails
        }
        
        ShowHotkeyTooltip("Window pinning removed")
    } catch Error as err {
        ShowHotkeyTooltip("Failed to remove window pinning")
    }
}

/**
 * Monitor and restore minimized windows that are set to always on top
 * Called by timer to automatically restore windows when they're minimized
 */
RestoreWindow() {
    try {
        ; Check if we have a valid window ID to monitor
        if (!IsSet(winid) || winid = WINID_NONE) {
            return
        }
        
        ; Check if the window still exists
        if (!WinExist("ahk_id " winid)) {
            ; Window no longer exists, stop monitoring
            SetTimer(RestoreWindow, 0)
            global winid := WINID_NONE
            return
        }
        
        ; Check if window is minimized
        try {
            minMaxState := WinGetMinMax(winid)
            if (minMaxState = -1) {  ; -1 means minimized
                WinRestore(winid)
            }
        } catch {
            ; Continue monitoring even if we can't get window state
        }
    } catch Error as err {
        ; Silently continue monitoring on any errors
    }
}


; ==============================================================================
; Mouse Lock Feature
; ==============================================================================
; Prevents accidental mouse movement when holding left mouse button
; and pressing Volume_Up button (useful for precise clicking)

global mouseLocked := false

#HotIf GetKeyState("LButton", "P")
Volume_Up:: {
    global mouseLocked
    try {
        if (!mouseLocked) {
            mouseLocked := true
            try {
                BlockInput "MouseMove"
            } catch {
                ; Continue even if BlockInput fails
            }
        }
    } catch {
        ; Silent fallback for any errors
    }
}
#HotIf

; Release lock when left mouse button is released
~LButton up:: {
    global mouseLocked
    try {
        if (mouseLocked) {
            mouseLocked := false
            try {
                BlockInput "MouseMoveOff"
            } catch {
                ; Continue even if BlockInput fails
            }
        }
    } catch {
        ; Silent fallback for any errors
    }
}

; ==============================================================================
; Text Transformation
; ==============================================================================
; CTRL + SHIFT + Q -> Replace "www" with "old" (browser URL conversion)

^+Q::
{
    try {
        Send("{F4}")
        Sleep(50)  ; Small delay for F4 to take effect
        Send("{Home}")
        Send("{Home}")
        Send("^{Right}")
        Send("{Delete 3}")
        Send("old")
        Send("{Enter}")
        Send("{Enter}")
    } catch {
        ; Silent fallback if text transformation fails
    }
}

; ==============================================================================
; Helper Functions
; ==============================================================================

/**
 * Show tooltip with consistent styling and automatic cleanup
 * @param message - Text to display
 * @param durationMs - Display duration in milliseconds (optional)
 */
ShowHotkeyTooltip(message, durationMs := 1000) {
    try {
        ToolTip(message)
        SetTimer(() => ToolTip(), -durationMs)
    } catch {
        ; Silent fallback if ToolTip fails
    }
}

; ==============================================================================
; Experimental Features (commented out)
; ==============================================================================

/**
 * Make windows borderless and fullscreen (experimental)
 * Uncomment to enable window decoration removal
 */
/*
^F10::
{
    try {
        WinGetTitle(&currentWindow, "A")
        if (currentWindow != "" && WinExist("A")) {
            ; Remove window border (use with caution)
            ; WinSetStyle("-0xC40000", "A")
            ; DllCall("SetMenu", "Ptr", WinExist(), "Ptr", 0)
        }
    } catch {
        ; Silent fallback
    }
}
*/

/**
 * CTRL + SPACE -> set active window always on top (alternative implementation)
 * Uncomment to enable this feature
 */
/*
^SPACE::
{
    try {
        WinSetAlwaysOnTop(1, "A")
        ShowHotkeyTooltip("Window set to always on top")
    } catch {
        ShowHotkeyTooltip("Failed to set window on top")
    }
}
*/