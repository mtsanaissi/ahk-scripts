#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; Debounced Middle Click - Prevents accidental double activation
; ==============================================================================
; Prevents accidental double mouse middle button activation by requiring
; at least 300ms between clicks. Perfect for preventing unwanted paste operations.
; ==============================================================================

MButton::
{
    try {
        ; Prevent double-click within 300ms threshold
        if (A_TimeSincePriorHotkey && A_TimeSincePriorHotkey < 300) {
            ; Silent operation - no tooltip to avoid distraction
            return
        }
        
        ; Execute the middle click
        Click "Middle"
    } catch Error as err {
        ; Fallback: ensure mouse click still works even if our logic fails
        try {
            Click "Middle"
        } catch {
            ; If everything fails, silently return to prevent script errors
            return
        }
    }
}
