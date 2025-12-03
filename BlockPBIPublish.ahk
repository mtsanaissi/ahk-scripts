#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; CONFIGURATION
; ==============================================================================
RightOffset     := 610
TopOffset       := 80
BoxWidth        := 60
BoxHeight       := 90
BoxColor        := "Red"
BoxTransparency := 150

; --- WINDOW IDENTIFICATION CONFIGURATION ---
; CRITICAL: You MUST replace 'ATL:00994110' with the actual ahk_class 
; of the main Power BI Desktop window (find this with AutoHotkey's Window Spy).
PBI_MAIN_WINDOW_ID := "ahk_exe PBIDesktop.exe ahk_class WindowsForms10.Window.8.app.0.3c14b78_r6_ad1" 
PBI_ANY_WINDOW_ID := "ahk_exe PBIDesktop.exe"
; ==============================================================================

; Create the GUI Object
BlockerGui := Gui("+AlwaysOnTop -Caption +ToolWindow +LastFound")
BlockerGui.BackColor := BoxColor
BlockerGui.SetFont("s9 bold cWhite", "Segoe UI")
BlockerGui.Add("Text", "x0 y35 w" BoxWidth " Center", "NO GIT!")

; Start the monitoring loop (500ms = 2 times per second)
SetTimer CheckPBI, 400

CheckPBI()
{
    global RightOffset, TopOffset, BoxWidth, BoxHeight, BoxTransparency
    global PBI_MAIN_WINDOW_ID, PBI_ANY_WINDOW_ID
    
    ; Static variables remember their values between function calls
    static LastX := 0, LastY := 0, LastW := 0, LastH := 0, IsVisible := false

    ; 1. Check if Power BI Desktop exists (running at all)
    if (!WinExist(PBI_ANY_WINDOW_ID))
    {
        ; If Power BI Desktop is not running, hide the blocker.
        if (IsVisible)
        {
            BlockerGui.Hide()
            IsVisible := false
            LastX := 0, LastY := 0 
        }
        return
    }

    ; 2. Check if the main Power BI window is visible and active
    
    ; The blocker should only be visible when the main PBI window is the active window
    ; and is not minimized.
    if (!WinActive(PBI_MAIN_WINDOW_ID))
    {
        ; If PBI is NOT the active window (minimized or Alt+Tabbed away), hide the blocker.
        if (IsVisible)
        {
            BlockerGui.Hide()
            IsVisible := false
            LastX := 0, LastY := 0 
        }
        return
    }

    ; --- Power BI is running AND is the active window ---
    
    ; 3. Get current position of PBI main window using the specific ID
    try 
    {
        ; This targets the main window and ignores popups/modals
        WinGetPos &PbiX, &PbiY, &PbiW, &PbiH, PBI_MAIN_WINDOW_ID
    }
    catch
    {
        return
    }

    ; 4. Safety check: If the position data is zero (shouldn't happen here if it's active, but good practice)
    if (PbiW = 0 || PbiH = 0)
    {
        if (IsVisible)
        {
            BlockerGui.Hide()
            IsVisible := false
            LastX := 0, LastY := 0 
        }
        return
    }
    
    ; 5. Use the main window position for blocker calculation
    UseX := PbiX
    UseY := PbiY
    UseW := PbiW
    UseH := PbiH

    ; 6. Optimization: Only Redraw if position/size changed, or if it was previously hidden
    if (UseX != LastX || UseY != LastY || UseW != LastW || UseH != LastH || !IsVisible)
    {
        ; Calculate coordinates anchored to the RIGHT side of the main window
        BlockX := UseX + UseW - RightOffset
        BlockY := UseY + TopOffset

        ; Move and Show the GUI
        BlockerGui.Show("x" BlockX " y" BlockY " w" BoxWidth " h" BoxHeight " NoActivate")
        
        ; Ensure transparency is applied
        WinSetTransparent(BoxTransparency, BlockerGui.Hwnd)
        
        ; Update state memory
        LastX := UseX
        LastY := UseY
        LastW := UseW
        LastH := UseH
        IsVisible := true
    }
}