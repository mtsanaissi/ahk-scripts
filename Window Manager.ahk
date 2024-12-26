#Requires AutoHotkey v2.0

global windowStates := Map()

#n:: {
    ; Check if there's an active window
    if !WinExist("A") {
        ToolTip("No active window")
        SetTimer () => ToolTip(), -1000
        return
    }

    ; Check if the active window is the desktop
    activeTitle := WinGetTitle("A")
    activeClass := WinGetClass("A")
    if (activeClass = "WorkerW" || activeClass = "Progman" || activeTitle = "") {
        ToolTip("Cannot move desktop")
        SetTimer () => ToolTip(), -1000
        return
    }

    activeHwnd := WinGetID("A")
    if (!activeHwnd) {
        ToolTip("Invalid window")
        SetTimer () => ToolTip(), -1000
        return
    }

    if (windowStates.Has(activeHwnd)) {
        RestoreWindow(activeHwnd, windowStates[activeHwnd])
        windowStates.Delete(activeHwnd)
    } else {
        SaveAndMoveWindow(activeHwnd, activeTitle)
    }
}

SaveAndMoveWindow(hwnd, title) {
    if !WinExist("ahk_id " hwnd)
        return

    state := GetWindowState(hwnd)
    windowStates[hwnd] := state
    
    ; Determine the current display
    WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
    currentMonitor := GetMonitorFromPoint(x + (w//2), y + (h//2))

    ; Verify we have at least 2 monitors
    monitorCount := MonitorGetCount()
    if (monitorCount < 2) {
        ToolTip("Multiple monitors not detected")
        SetTimer () => ToolTip(), -1000
        return
    }

    ; Calculate target display index
    targetMonitor := (currentMonitor = 1) ? 2 : 1

    ; Get monitor info and move window
    MonitorGet(targetMonitor, &left, &top, &right, &bottom)
    
    WinRestore("ahk_id " hwnd)
    WinMove(left, top, w, h, "ahk_id " hwnd)
    WinMaximize("ahk_id " hwnd)
    
    ToolTip("Moved " title " to display " targetMonitor)
    SetTimer () => ToolTip(), -1000
}

RestoreWindow(hwnd, state) {
    if !WinExist("ahk_id " hwnd)
        return

    WinRestore("ahk_id " hwnd)
    WinMove(state.x, state.y, state.w, state.h, "ahk_id " hwnd)

    if (state.maximized)
        WinMaximize("ahk_id " hwnd)
    ;else
    ;    WinMove(state.x, state.y, state.w, state.h, "ahk_id " hwnd)
    
    activeTitle := WinGetTitle("ahk_id " hwnd)
    ToolTip("Restored " activeTitle)
    SetTimer () => ToolTip(), -1000
}

GetWindowState(hwnd) {
    state := Map()
    WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
    state.x := x
    state.y := y
    state.w := w
    state.h := h
    state.maximized := WinGetMinMax("ahk_id " hwnd) = 1  ; 1 means maximized
    return state
}

GetMonitorFromPoint(x, y) {
    monitorCount := MonitorGetCount()
    Loop monitorCount {
        MonitorGet(A_Index, &left, &top, &right, &bottom)
        if (x >= left && x <= right && y >= top && y <= bottom)
            return A_Index
    }
    return 1
}
