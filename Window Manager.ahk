#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; Window Manager - Move windows between monitors
; ==============================================================================
; Hotkey: Win+N
;
; Features:
; - Toggles window between monitors 1 and 2
; - Automatically restores original position on second press
; - Handles minimized and maximized windows correctly
; - Validates target windows before moving
; ==============================================================================

global windowStates := Map()

; Constants for better maintainability
WINDOW_MOVE_DELAY_MS := 50
TOOLTIP_DURATION_MS := 1000

#n:: {
    try {
        ; Validate active window exists
        if !WinExist("A") {
            ShowTooltip("No active window")
            return
        }

        ; Get window information safely
        try {
            activeTitle := WinGetTitle("A")
            activeClass := WinGetClass("A")
            activeHwnd := WinGetID("A")
        } catch Error as err {
            ShowTooltip("Failed to get window info")
            return
        }

        ; Prevent moving desktop or system windows
        if (activeClass = "WorkerW" || activeClass = "Progman" || activeTitle = "") {
            ShowTooltip("Cannot move system windows")
            return
        }

        ; Validate window handle
        if (!activeHwnd) {
            ShowTooltip("Invalid window handle")
            return
        }

        ; Toggle between saved state and moving to other monitor
        if (windowStates.Has(activeHwnd)) {
            RestoreWindow(activeHwnd, windowStates[activeHwnd])
            windowStates.Delete(activeHwnd)
        } else {
            SaveAndMoveWindow(activeHwnd, activeTitle)
        }
    } catch Error as err {
        ; Graceful fallback for any unexpected errors
        ShowTooltip("Window manager error occurred")
    }
}

SaveAndMoveWindow(hwnd, title) {
    try {
        ; Validate window still exists
        if !WinExist("ahk_id " hwnd) {
            return
        }

        ; Save current state before moving
        state := GetWindowState(hwnd)
        windowStates[hwnd] := state
        
        ; Get current window position and determine monitor
        try {
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        } catch Error as err {
            ShowTooltip("Failed to get window position")
            return
        }
        
        currentMonitor := GetMonitorFromPoint(x + (w//2), y + (h//2))

        ; Verify we have at least 2 monitors
        monitorCount := 0
        try {
            monitorCount := MonitorGetCount()
        } catch Error as err {
            ShowTooltip("Failed to detect monitors")
            return
        }
        
        if (monitorCount < 2) {
            ShowTooltip("Multiple monitors not detected")
            return
        }

        ; Calculate target display index
        targetMonitor := (currentMonitor = 1) ? 2 : 1

        ; Get monitor info and move window
        try {
            MonitorGet(targetMonitor, &left, &top, &right, &bottom)
        } catch Error as err {
            ShowTooltip("Failed to get monitor info")
            return
        }
        
        ; Move and maximize the window
        try {
            WinRestore("ahk_id " hwnd)
            WinMove(left, top, w, h, "ahk_id " hwnd)
            WinMaximize("ahk_id " hwnd)
        } catch Error as err {
            ShowTooltip("Failed to move window")
            return
        }
        
        ShowTooltip("Moved " title " to display " targetMonitor)
    } catch Error as err {
        ShowTooltip("Window move failed")
    }
}

; ==============================================================================
; Helper Functions
; ==============================================================================

/**
 * Show a tooltip with consistent styling and automatic cleanup
 * @param message - Text to display
 * @param durationMs - How long to show (optional, defaults to TOOLTIP_DURATION_MS)
 */
ShowTooltip(message, durationMs := TOOLTIP_DURATION_MS) {
    try {
        ToolTip(message)
        SetTimer(() => ToolTip(), -durationMs)
    } catch {
        ; Silent fallback if ToolTip fails
    }
}

/**
 * Restore window to its saved position and state
 * @param hwnd - Window handle
 * @param state - Saved window state (position, size, maximized flag)
 */
RestoreWindow(hwnd, state) {
    try {
        ; Validate window still exists
        if !WinExist("ahk_id " hwnd) {
            return
        }

        ; Restore window position and size
        try {
            WinRestore("ahk_id " hwnd)
            WinMove(state.x, state.y, state.w, state.h, "ahk_id " hwnd)
        } catch Error as err {
            ShowTooltip("Failed to restore window position")
            return
        }

        ; Restore maximization state if it was maximized
        try {
            if (state.maximized) {
                WinMaximize("ahk_id " hwnd)
            }
        } catch Error as err {
            ; Continue even if maximization fails
        }
        
        ; Show success message
        try {
            activeTitle := WinGetTitle("ahk_id " hwnd)
            ShowTooltip("Restored " activeTitle)
        } catch {
            ShowTooltip("Window restored")
        }
    } catch Error as err {
        ShowTooltip("Restore failed")
    }
}

/**
 * Get the current state of a window for later restoration
 * @param hwnd - Window handle
 * @returns Map containing position, size, and maximized state
 */
GetWindowState(hwnd) {
    try {
        state := Map()
        
        ; Get window position and size
        try {
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
            state.x := x
            state.y := y
            state.w := w
            state.h := h
        } catch Error as err {
            ; Use default values if position retrieval fails
            state.x := 100
            state.y := 100
            state.w := 800
            state.h := 600
        }
        
        ; Check if window is maximized
        try {
            minMaxState := WinGetMinMax("ahk_id " hwnd)
            state.maximized := (minMaxState = 1)  ; 1 means maximized
        } catch {
            state.maximized := false  ; Default to not maximized
        }
        
        return state
    } catch Error as err {
        ; Return safe default state if everything fails
        return Map("x", 100, "y", 100, "w", 800, "h", 600, "maximized", false)
    }
}

/**
 * Determine which monitor contains a specific screen coordinate
 * @param x - X coordinate
 * @param y - Y coordinate
 * @returns Monitor number (1-based)
 */
GetMonitorFromPoint(x, y) {
    try {
        monitorCount := MonitorGetCount()
        Loop monitorCount {
            try {
                MonitorGet(A_Index, &left, &top, &right, &bottom)
                if (x >= left && x <= right && y >= top && y <= bottom) {
                    return A_Index
                }
            } catch {
                ; Continue to next monitor if this one fails
                continue
            }
        }
        
        ; If no monitor matches, return monitor 1 as fallback
        return 1
    } catch Error as err {
        ; Return 1 as default if monitor detection fails
        return 1
    }
}
