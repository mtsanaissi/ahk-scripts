#Requires AutoHotkey v2.0

; ==============================================================================
; Smart Hotstrings - Editor/Terminal Text Expansions
; ==============================================================================
; Provides intelligent text expansions for development workflows.
; Only activates in specific editors and terminals to avoid conflicts.
;
; Supported environments:
; - Visual Studio Code
; - Windows Terminal
; - ConEmu
; - Custom editor (Antigravity)
; ==============================================================================

#HotIf CheckEditorTerminalActive()

; ==============================================================================
; Git Workflow Shortcuts
; ==============================================================================
; Quick git commands for common development tasks

; git merge origin/[branch] - Quick merge from remote
:*:gmo`t::
{
    try {
        SendText("git merge origin/")
    } catch {
        Send("git merge origin/")
    }
}

; git add . && git commit -m "chore: docs" && git push - One-liner for documentation updates
:*:gac`t::
{
    try {
        SendText('git add . && git commit -m "chore: docs" && git push')
    } catch {
        Send('git add . && git commit -m "chore: docs" && git push')
    }
}

#HotIf  ; Reset to global context

; ==============================================================================
; Helper Functions
; ==============================================================================

/**
 * Check if the current active window is a supported editor or terminal
 * @returns true if in a supported environment, false otherwise
 */
CheckEditorTerminalActive() {
    try {
        ; Get active window process name safely
        activeExe := ""
        try {
            activeExe := WinGetProcessName("A")
        } catch {
            return false
        }
        
        ; List of supported editor/terminal executables
        supportedApps := [
            "Code.exe",           ; Visual Studio Code
            "WindowsTerminal.exe", ; Windows Terminal
            "ConEmu64.exe",       ; ConEmu
            "Antigravity.exe"     ; Custom editor
        ]
        
        ; Check if current exe is in supported list
        for app in supportedApps {
            if (StrLower(activeExe) = StrLower(app)) {
                return true
            }
        }
        
        return false
    } catch {
        ; Safe fallback: if we can't determine the app, don't expand
        return false
    }
}

; ==============================================================================
; Debug Functions (commented out by default)
; ==============================================================================

/**
 * Log the active window title for debugging purposes
 * Uncomment the function call below to enable debugging
 */
/*
LogActiveWindow() {
    try {
        activeTitle := WinGetTitle("A")
        ToolTip("Active window: " activeTitle)
        SetTimer(() => ToolTip(), -2000)
    } catch {
        ; Silent fallback if window info can't be retrieved
    }
}

; To enable debugging, uncomment this line:
; SetTimer(LogActiveWindow, 5000)  ; Log every 5 seconds
*/
