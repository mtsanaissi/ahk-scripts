#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; CONFIGURATION
; ==============================================================================
; Regex matched against the active window's process name.
; Covers PBIDesktop.exe (MSI/.exe installer) and PBIDesktopStore.exe (Microsoft Store).
ExePattern := "i)^PBIDesktop\w*\.exe$"

; Position is relative to the Power BI window.
;   AnchorRight := true  -> OffsetX = distance from PBI's RIGHT edge to overlay's left edge
;   AnchorRight := false -> OffsetX = distance from PBI's LEFT edge  to overlay's left edge
AnchorRight  := true
OffsetX      := 610
OffsetY      := 80
BoxW         := 60
BoxH         := 90

BoxColor     := "Red"
BoxTransp    := 150            ; 0-255
BoxText      := "NO GIT!"
TextColor    := "White"

MinMainWidth := 400            ; ignore splash screens / tiny helper windows

; Ctrl+Alt+D shows exe / class / title / owner of the active window (for debugging).
; Drag the overlay to move it; drag its edges to resize it. Changes last until reload.
; ==============================================================================

PbiHwnd := 0
Dragging := false

; -DPIScale = raw pixel coordinates (same unit as WinGetPos) -> no offset on scaled displays
; E0x08000000 = WS_EX_NOACTIVATE -> clicking the overlay never steals focus
Ovl := Gui("+AlwaysOnTop -Caption +ToolWindow +Resize -DPIScale +E0x08000000 +MinSize20x20")
Ovl.BackColor := BoxColor
Ovl.SetFont("s9 bold c" TextColor, "Segoe UI")
Txt := Ovl.Add("Text", "x0 y0 w" BoxW " h" BoxH " Center +0x200 BackgroundTrans", BoxText)
Ovl.OnEvent("Size", OnOvlSize)

OnMessage(0x201, OnLButtonDown)
OnMessage(0x231, OnEnterSizeMove)
OnMessage(0x232, OnExitSizeMove)

SetTimer(CheckPBI, 150)

OnOvlSize(gui, minMax, w, h) {
    global Txt
    Txt.Move(0, 0, w, h)
    Txt.Redraw()
}

OnLButtonDown(wParam, lParam, msg, hwnd) {
    global Ovl
    if (hwnd = Ovl.Hwnd)
        PostMessage(0xA1, 2, 0, , "ahk_id " Ovl.Hwnd)  ; WM_NCLBUTTONDOWN, HTCAPTION
}

OnEnterSizeMove(*) {
    global Dragging
    Dragging := true
}

OnExitSizeMove(*) {
    global Ovl, PbiHwnd, Dragging, OffsetX, OffsetY, BoxW, BoxH, AnchorRight
    Dragging := false
    if (!PbiHwnd || !WinExist(PbiHwnd))
        return
    WinGetPos(&px, &py, &pw, &ph, PbiHwnd)
    WinGetPos(&ox, &oy, &BoxW, &BoxH, Ovl.Hwnd)
    OffsetX := AnchorRight ? (px + pw - ox) : (ox - px)
    OffsetY := oy - py
}

CheckPBI() {
    global Ovl, ExePattern, PbiHwnd, Dragging, MinMainWidth
    global AnchorRight, OffsetX, OffsetY, BoxW, BoxH, BoxTransp
    static LastKey := "", IsVisible := false

    if (Dragging)
        return

    hAct := WinExist("A")
    if (hAct = Ovl.Hwnd)
        return

    ok := false
    try {
        if (hAct
            && RegExMatch(WinGetProcessName(hAct), ExePattern)       ; Power BI process
            && !DllCall("GetWindow", "Ptr", hAct, "UInt", 4, "Ptr") ; not an owned dialog
            && WinGetMinMax(hAct) != -1) {                           ; not minimized
            WinGetPos(&px, &py, &pw, &ph, hAct)
            ok := (pw >= MinMainWidth && ph > 0)
        }
    }

    if (!ok) {
        if (IsVisible) {
            Ovl.Hide()
            IsVisible := false
            LastKey := ""
        }
        return
    }

    PbiHwnd := hAct
    key := px "," py "," pw "," ph "," hAct "," OffsetX "," OffsetY "," BoxW "," BoxH
    if (key = LastKey && IsVisible)
        return

    ox := AnchorRight ? px + pw - OffsetX : px + OffsetX
    oy := py + OffsetY

    if (!IsVisible) {
        Ovl.Show("NoActivate x" ox " y" oy)
        WinSetTransparent(BoxTransp, Ovl.Hwnd)
        IsVisible := true
    }
    Ovl.Move(ox, oy, BoxW, BoxH)
    LastKey := key
}