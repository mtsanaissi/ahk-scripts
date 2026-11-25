#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; CONFIGURATION
; ==============================================================================
FoxitExe     := "C:\Program Files\Foxit Software\Foxit PDF Reader\FoxitPDFReader.exe"

; Position is relative to the Foxit window.
;   AnchorRight := true  -> OffsetX = distance from Foxit's RIGHT edge to overlay's left edge
;   AnchorRight := false -> OffsetX = distance from Foxit's LEFT edge  to overlay's left edge
; OffsetY = distance from Foxit's top edge to overlay's top edge.
AnchorRight  := true
OffsetX      := 610
OffsetY      := 80
BoxW         := 60
BoxH         := 90

BoxColor     := "555555"
BoxTransp    := 255            ; 0-255
BoxText      := "AD BLOCKER"
TextColor    := "White"

; Drag the overlay with the left mouse button to move it; drag its edges to resize.
; New position/size is remembered (relative to Foxit) until the script is reloaded.
; ==============================================================================

AppMatch := "ahk_exe " FoxitExe
FoxitHwnd := 0
Dragging := false

; -DPIScale = all coordinates are raw pixels (same unit as WinGetPos)
; E0x08000000 = WS_EX_NOACTIVATE, so clicking the overlay never steals focus from Foxit
Ovl := Gui("+AlwaysOnTop -Caption +ToolWindow +Resize -DPIScale +E0x08000000 +MinSize20x20")
Ovl.BackColor := BoxColor
Ovl.SetFont("s9 bold c" TextColor, "Segoe UI")
Txt := Ovl.Add("Text", "x0 y0 w" BoxW " h" BoxH " Center +0x200 BackgroundTrans", BoxText)
Ovl.OnEvent("Size", OnOvlSize)

OnMessage(0x201, OnLButtonDown)   ; WM_LBUTTONDOWN   -> start window drag
OnMessage(0x231, OnEnterSizeMove) ; WM_ENTERSIZEMOVE
OnMessage(0x232, OnExitSizeMove)  ; WM_EXITSIZEMOVE  -> store new offsets

SetTimer(CheckFoxit, 100)

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
    global Ovl, FoxitHwnd, Dragging, OffsetX, OffsetY, BoxW, BoxH, AnchorRight
    Dragging := false
    if (!FoxitHwnd || !WinExist(FoxitHwnd))
        return
    WinGetPos(&fx, &fy, &fw, &fh, FoxitHwnd)
    WinGetPos(&ox, &oy, &BoxW, &BoxH, Ovl.Hwnd)
    OffsetX := AnchorRight ? (fx + fw - ox) : (ox - fx)
    OffsetY := oy - fy
}

CheckFoxit() {
    global Ovl, AppMatch, FoxitHwnd, Dragging
    global AnchorRight, OffsetX, OffsetY, BoxW, BoxH, BoxTransp
    static LastKey := "", IsVisible := false

    if (Dragging)
        return

    hFox := WinActive(AppMatch)

    ; Hide unless a Foxit window is the active window
    ; (also hide for owned child windows such as dialogs: Open, Save, Print...)
    if (!hFox || DllCall("GetWindow", "Ptr", hFox, "UInt", 4, "Ptr")
        || WinGetMinMax(hFox) = -1) {
        if (IsVisible) {
            Ovl.Hide()
            IsVisible := false
            LastKey := ""
        }
        return
    }

    FoxitHwnd := hFox
    try WinGetPos(&fx, &fy, &fw, &fh, hFox)
    catch
        return
    if (fw = 0 || fh = 0)
        return

    key := fx "," fy "," fw "," fh "," hFox "," OffsetX "," OffsetY "," BoxW "," BoxH
    if (key = LastKey && IsVisible)
        return

    ox := (AnchorRight ? fx + fw - OffsetX : fx + OffsetX)
    oy := fy + OffsetY

    if (!IsVisible) {
        Ovl.Show("NoActivate x" ox " y" oy)
        WinSetTransparent(BoxTransp, Ovl.Hwnd)
        IsVisible := true
    }
    Ovl.Move(ox, oy, BoxW, BoxH)
    LastKey := key
}
