#Requires AutoHotkey v2.0

#SingleInstance Force

; ShortcutsHelper - Shortcut reference overlay
; - YAML-driven (copy `example-shortcuts/` -> `shortcuts/`)
; - Shows active app shortcuts first, then globals, then the rest (A-Z)
; - Borderless, resizable, and does not steal focus on show

#Include "Lib\ShortcutsSchemaParser.ahk"

; ============================================================
; Configuration
; ============================================================
global SH_CONFIG := {
    shortcutsFolder: A_ScriptDir "\shortcuts",
    exampleFolder: A_ScriptDir "\example-shortcuts",
    iniPath: A_ScriptDir "\ShortcutsHelper.ini",
    hotkey: "#^;", ; Win + Ctrl + ;
    watchIntervalMs: 250,
    ; Ignore transient system UI windows (prevents Alt+Tab / Task View from triggering refreshes).
    ignoreWindowClasses: ["MultitaskingViewFrame", "TaskSwitcherWnd", "XamlExplorerHostIslandWindow"],

    ; UI
    windowWidth: 770,
    windowHeight: 520,
    minWidth: 420,
    minHeight: 320,
    headerHeight: 44,
    footerHeight: 26,
    padding: 12,
    resizeGrip: 8,

    ; Colors
    bg: "0b1220",
    panel: "0f172a",
    panel2: "111c33",
    text: "e5e7eb",
    muted: "93a4b8",
    accent: "22c55e",
    globalAccent: "60a5fa",
    appAccent: "fda4af",
    sectionBgActive: "0f2a1c",
    sectionBgGlobal: "0f223d",
    groupBgActive: "0d2318",
    groupBgGlobal: "0d1d33",
    border: "22304a"
}

; ============================================================
; Global State
; ============================================================
global ShGui := ""
global ShLv := ""
global ShSearch := ""
global ShTitle := ""
global ShContext := ""
global ShCount := ""
global ShCloseBtn := ""
global ShCopyExeBtn := ""
global ShHeaderBg := ""
global ShFooterBg := ""
global ShBorderTop := ""
global ShBorderLeft := ""
global ShBorderRight := ""
global ShBorderBottom := ""
global ShLastActiveWindow := 0
global ShLastNonGuiWindow := 0
global ShLastGuiW := 0
global ShLastGuiH := 0
global ShInSizeHandler := false
global ShActiveExe := ""
global ShLastActiveDefIdx := 0
global ShAllDefs := [] ; Array of {title,type,displayOrder,match,entries}
global ShRenderedRows := [] ; Array of {kind,style,keys,desc,section,group}
global ShLoadStats := { files: 0, loaded: 0, errors: 0, entries: 0, details: [] }
global ShColorCache := Map()

; ============================================================
; Startup
; ============================================================
Hotkey(SH_CONFIG.hotkey, (*) => Sh_Toggle())

; ============================================================
; Hotkey Actions
; ============================================================

Sh_Toggle() {
    global ShGui
    if (Sh_GuiIsVisible()) {
        Sh_Hide()
        return
    }
    Sh_Show()
}

Sh_GuiIsVisible() {
    global ShGui
    if (!IsSet(ShGui) || ShGui = "")
        return false
    try return DllCall("IsWindowVisible", "ptr", ShGui.Hwnd, "int") != 0
    return false
}

Sh_Show() {
    global SH_CONFIG, ShGui, ShLastActiveWindow, ShLastNonGuiWindow

    ShLastActiveWindow := WinGetID("A")
    ShLastNonGuiWindow := ShLastActiveWindow
    Sh_EnsureShortcutsFolder()
    Sh_LoadAllYaml()

    if (ShGui = "") {
        Sh_CreateGui()
    } else {
        Sh_RefreshList()
    }

    geo := Sh_ReadWindowGeometry()
    ShGui.Show("NA")
    Sh_ApplySavedWindowGeometry(geo)
    SetTimer(Sh_ApplyLayoutFromCurrentSize, -1)
    SetTimer(Sh_WatchActiveWindow, SH_CONFIG.watchIntervalMs)
}

Sh_Hide() {
    global ShGui, ShLastActiveWindow
    if (ShGui = "")
        return
    wasActive := WinActive("ahk_id " ShGui.Hwnd)
    Sh_SaveWindowGeometry()
    ShGui.Hide()
    SetTimer(Sh_WatchActiveWindow, 0)
    if (wasActive)
        try WinActivate("ahk_id " ShLastActiveWindow)
}

; ============================================================
; YAML Loading & Matching
; ============================================================

Sh_EnsureShortcutsFolder() {
    global SH_CONFIG
    if !DirExist(SH_CONFIG.shortcutsFolder) {
        DirCreate(SH_CONFIG.shortcutsFolder)
        if (DirExist(SH_CONFIG.exampleFolder)) {
            MsgBox(
                "Created: " SH_CONFIG.shortcutsFolder "`n`n" .
                "Copy YAML files from:`n" SH_CONFIG.exampleFolder "`n" .
                "into:`n" SH_CONFIG.shortcutsFolder "`n`n" .
                "The `shortcuts/` folder is gitignored for privacy.",
                "ShortcutsHelper",
                "Iconi"
            )
        }
    }
}

Sh_LoadAllYaml() {
    global SH_CONFIG, ShAllDefs, ShLoadStats
    ShAllDefs := []
    ShLoadStats := { files: 0, loaded: 0, errors: 0, entries: 0, details: [] }

    if !DirExist(SH_CONFIG.shortcutsFolder)
        return

    Loop Files, SH_CONFIG.shortcutsFolder "\*.yaml" {
        ShLoadStats.files += 1
        parsed := ShortcutsSchemaParser.ParseFile(A_LoopFileFullPath)
        if (parsed.HasOwnProp("error")) {
            ShLoadStats.errors += 1
            ShLoadStats.details.Push(A_LoopFileName ": ERROR: " parsed.error)
            continue
        }

        title := parsed.HasOwnProp("title") && parsed.title != "" ? parsed.title : StrReplace(A_LoopFileName, ".yaml", "")
        type := parsed.HasOwnProp("type") ? parsed.type : "app"
        displayOrder := parsed.HasOwnProp("displayOrder") ? Sh_AsOrder(parsed.displayOrder) : 999
        match := parsed.HasOwnProp("match") ? parsed.match : {}

        entries := Sh_NormalizeYamlEntries(parsed)
        ShLoadStats.entries += entries.Length
        ShLoadStats.details.Push(
            A_LoopFileName
                ": parser=" (parsed.HasOwnProp("__parser") ? parsed.__parser : "?")
                " rootKeys=" (parsed.HasOwnProp("__rootKeys") ? parsed.__rootKeys.Length : 0)
                " groups=" Sh_KeySummary(parsed, "groups")
                " items=" Sh_KeySummary(parsed, "items")
                " -> entries=" entries.Length
                (parsed.HasOwnProp("__rootKeys") ? (" keys=[" Sh_JoinArray(parsed.__rootKeys, ",") "]") : "")
        )
        ShAllDefs.Push({ title: title, type: type, displayOrder: displayOrder, match: match, entries: entries })
        ShLoadStats.loaded += 1
    }
}

Sh_KeySummary(obj, key) {
    if (!IsObject(obj) || !obj.HasOwnProp(key))
        return "none"
    v := obj.%key%
    t := Type(v)
    if (t = "Array")
        return "Array(" v.Length ")"
    if (t = "Object")
        return "Object"
    return t
}

Sh_NormalizeYamlEntries(parsed) {
    entries := []

    ; Supports:
    ; - groups: [{name, items:[{keys,desc}]}]
    ; - items:  [{group, items:[...] }] OR [{keys,desc,group?}]

    if (parsed.HasOwnProp("groups")) {
        for groupObj in parsed.groups {
            groupName := groupObj.HasOwnProp("name") ? groupObj.name : ""
            if (!groupObj.HasOwnProp("items"))
                continue
            for item in groupObj.items {
                keys := item.HasOwnProp("keys") ? item.keys : ""
                desc := item.HasOwnProp("desc") ? item.desc : (item.HasOwnProp("description") ? item.description : "")
                if (keys = "" && desc = "")
                    continue
                entries.Push({ group: groupName, keys: keys, desc: desc })
            }
        }
    }

    if (parsed.HasOwnProp("items")) {
        for obj in parsed.items {
            if (obj.HasOwnProp("group") && obj.HasOwnProp("items")) {
                groupName := obj.group
                for item in obj.items {
                    keys := item.HasOwnProp("keys") ? item.keys : ""
                    desc := item.HasOwnProp("desc") ? item.desc : (item.HasOwnProp("description") ? item.description : "")
                    if (keys = "" && desc = "")
                        continue
                    entries.Push({ group: groupName, keys: keys, desc: desc })
                }
            } else {
                keys := obj.HasOwnProp("keys") ? obj.keys : ""
                desc := obj.HasOwnProp("desc") ? obj.desc : (obj.HasOwnProp("description") ? obj.description : "")
                groupName := obj.HasOwnProp("group") ? obj.group : ""
                if (keys = "" && desc = "")
                    continue
                entries.Push({ group: groupName, keys: keys, desc: desc })
            }
        }
    }

    return entries
}

Sh_GetActiveAppTitle() {
    global ShAllDefs

    exe := ""
    class := ""
    title := ""
    try exe := WinGetProcessName("A")
    try class := WinGetClass("A")
    try title := WinGetTitle("A")

    return Sh_GetActiveDefIndex(exe, class, title)
}

Sh_GetActiveDefIndex(exe, class, title) {
    global ShAllDefs

    bestIdx := 0
    bestScore := 2147483647

    for idx, def in ShAllDefs {
        if (StrLower(def.type) = "global")
            continue
        score := Sh_ScoreMatch(def.match, exe, class, title)
        if (score < bestScore) {
            bestScore := score
            bestIdx := idx
        }
    }

    return bestIdx
}

Sh_GetActiveWindowInfo() {
    global ShGui, ShLastNonGuiWindow
    info := { exe: "", class: "", title: "" }
    winSpec := "A"
    try {
        activeId := WinGetID("A")
        if (IsSet(ShGui) && ShGui != "" && activeId = ShGui.Hwnd && ShLastNonGuiWindow)
            winSpec := "ahk_id " ShLastNonGuiWindow
    }
    try info.exe := WinGetProcessName(winSpec)
    try info.class := WinGetClass(winSpec)
    try info.title := WinGetTitle(winSpec)
    return info
}

Sh_IsIgnoredWindow(hwnd) {
    global SH_CONFIG
    if (!IsSet(SH_CONFIG) || !SH_CONFIG.HasOwnProp("ignoreWindowClasses"))
        return false
    cls := ""
    try cls := WinGetClass("ahk_id " hwnd)
    catch
        return false
    for c in SH_CONFIG.ignoreWindowClasses {
        if (cls = c)
            return true
    }
    ; Heuristic: while Alt is held, ignore transient Explorer-hosted UI (Alt+Tab / Task View),
    ; but do NOT ignore real File Explorer windows (CabinetWClass).
    if (GetKeyState("Alt", "P")) {
        exe := ""
        try exe := WinGetProcessName("ahk_id " hwnd)
        if (StrLower(exe) = "explorer.exe" && cls != "CabinetWClass")
            return true
    }
    return false
}

Sh_ScoreMatch(matchObj, exe, class, title) {
    if (!IsObject(matchObj))
        return 2147483647

    priority := matchObj.HasOwnProp("priority") ? matchObj.priority : 100

    if (matchObj.HasOwnProp("exe")) {
        if (Sh_ValueMatches(matchObj.exe, exe))
            return priority * 1000 + 0
    }
    if (matchObj.HasOwnProp("class")) {
        if (Sh_ValueMatches(matchObj.class, class))
            return priority * 1000 + 10
    }
    if (matchObj.HasOwnProp("titleRegex")) {
        if (Sh_RegexMatches(matchObj.titleRegex, title))
            return priority * 1000 + 20
    }
    if (matchObj.HasOwnProp("titleContains")) {
        if (Sh_TitleContains(matchObj.titleContains, title))
            return priority * 1000 + 30
    }

    return 2147483647
}

Sh_ValueMatches(patternOrList, value) {
    if (value = "")
        return false
    if (IsObject(patternOrList)) {
        for v in patternOrList {
            if (StrLower(v) = StrLower(value))
                return true
        }
        return false
    }
    return StrLower(patternOrList) = StrLower(value)
}

Sh_RegexMatches(regexOrList, haystack) {
    if (haystack = "")
        return false
    if (IsObject(regexOrList)) {
        for re in regexOrList {
            if (RegExMatch(haystack, re))
                return true
        }
        return false
    }
    return RegExMatch(haystack, regexOrList)
}

Sh_TitleContains(needleOrList, haystack) {
    if (haystack = "")
        return false
    if (IsObject(needleOrList)) {
        for n in needleOrList {
            if (InStr(haystack, n))
                return true
        }
        return false
    }
    return InStr(haystack, needleOrList)
}

; ============================================================
; GUI
; ============================================================

Sh_CreateGui() {
    global SH_CONFIG, ShGui, ShLv, ShSearch, ShTitle, ShContext, ShCount, ShCloseBtn, ShCopyExeBtn
    global ShHeaderBg, ShFooterBg, ShBorderTop, ShBorderLeft, ShBorderRight, ShBorderBottom

    ShGui := Gui("+AlwaysOnTop +ToolWindow +Resize -Caption")
    ShGui.BackColor := SH_CONFIG.bg
    ShGui.MarginX := 0
    ShGui.MarginY := 0
    ; AHK v2 GUI option format is `+MinSize<width>x<height>`
    ShGui.Opt("+MinSize" SH_CONFIG.minWidth "x" SH_CONFIG.minHeight)

    ; Header panel
    ShHeaderBg := ShGui.Add("Text", "x0 y0 w" SH_CONFIG.windowWidth " h" SH_CONFIG.headerHeight " Background" SH_CONFIG.panel)

    ShTitle := ShGui.Add("Text", "x" SH_CONFIG.padding " y10 w220 h20 BackgroundTrans c" SH_CONFIG.text, "Shortcuts")
    ShTitle.SetFont("s11 w600", "Segoe UI")

    ShContext := ShGui.Add("Text", "x0 y0 w220 h16 BackgroundTrans c" SH_CONFIG.muted, "")
    ShContext.SetFont("s9", "Segoe UI")

    ShSearch := ShGui.Add("Edit", "x0 y0 w100 h22 -E0x200", "")
    ShSearch.SetFont("s9", "Segoe UI")
    ShSearch.OnEvent("Change", (*) => Sh_RefreshList())

    ShCopyExeBtn := ShGui.Add("Button", "x0 y0 w36 h24", "exe")
    ShCopyExeBtn.SetFont("s8 w600", "Segoe UI")
    ShCopyExeBtn.OnEvent("Click", (*) => Sh_CopyActiveExe())

    ShCloseBtn := ShGui.Add("Button", "x0 y0 w28 h24", "×")
    ShCloseBtn.SetFont("s11 w600", "Segoe UI")
    ShCloseBtn.OnEvent("Click", (*) => Sh_Hide())

    ; Footer (status)
    ShFooterBg := ShGui.Add("Text", "x0 y0 w" SH_CONFIG.windowWidth " h" SH_CONFIG.footerHeight " Background" SH_CONFIG.panel2)
    ShCount := ShGui.Add("Text", "x" SH_CONFIG.padding " y0 w400 h18 BackgroundTrans c" SH_CONFIG.muted, "")
    ShCount.SetFont("s8", "Segoe UI")

    ; List
    pad := SH_CONFIG.padding
    lvY := SH_CONFIG.headerHeight + SH_CONFIG.footerHeight
    lvW := SH_CONFIG.windowWidth - (2 * pad)
    lvH := SH_CONFIG.windowHeight - lvY
    if (lvW < 50)
        lvW := 50
    if (lvH < 50)
        lvH := 50
    ShLv := ShGui.Add(
        "ListView",
        "x" pad " y" (lvY + 4) " w" lvW " h" (lvH - 8)
            " Background" SH_CONFIG.bg " c" SH_CONFIG.text
            " -Multi -Hdr +Report +LV0x10000",
        ["Shortcut", "Description"]
    )
    ShLv.SetFont("s9", "Segoe UI")
    ShLv.ModifyCol(1, 270)
    ShLv.ModifyCol(2, 420)

    ShGui.OnEvent("Close", (*) => Sh_Hide())
    ShGui.OnEvent("Escape", (*) => Sh_Hide())

    OnMessage(0x4E, Sh_WmNotify) ; WM_NOTIFY (ListView selection + custom draw)
    OnMessage(0x0005, Sh_WmSize) ; WM_SIZE (more reliable than Gui.OnEvent("Size") for -Caption)

    ; Border (1px) - add last so it stays on top
    ShBorderTop := ShGui.Add("Text", "x0 y0 w" SH_CONFIG.windowWidth " h1 Background" SH_CONFIG.border)
    ShBorderLeft := ShGui.Add("Text", "x0 y0 w1 h" SH_CONFIG.windowHeight " Background" SH_CONFIG.border)
    ShBorderRight := ShGui.Add("Text", "x0 y0 w1 h" SH_CONFIG.windowHeight " Background" SH_CONFIG.border)
    ShBorderBottom := ShGui.Add("Text", "x0 y0 w" SH_CONFIG.windowWidth " h1 Background" SH_CONFIG.border)

    OnMessage(0x84, Sh_WmNcHitTest) ; WM_NCHITTEST

    Sh_OnSize(ShGui, 0, SH_CONFIG.windowWidth, SH_CONFIG.windowHeight)
    Sh_RefreshList()
}

Sh_ApplyLayoutFromCurrentSize() {
    global ShGui
    if (!IsSet(ShGui) || ShGui = "")
        return
    w := 0
    h := 0
    if (!Sh_GetClientSize(ShGui.Hwnd, &w, &h))
        return
    Sh_OnSize(ShGui, 0, w, h)
}

Sh_ApplySavedWindowGeometry(geo) {
    global SH_CONFIG, ShGui
    if (!IsSet(ShGui) || ShGui = "")
        return

    x := ""
    y := ""
    w := SH_CONFIG.windowWidth
    h := SH_CONFIG.windowHeight

    if (IsObject(geo)) {
        if (geo.Has("w"))
            w := geo["w"]
        if (geo.Has("h"))
            h := geo["h"]
        if (geo.Has("x"))
            x := geo["x"]
        if (geo.Has("y"))
            y := geo["y"]
    }

    try WinMove(x, y, w, h, "ahk_id " ShGui.Hwnd)
}

Sh_GetClientSize(hwnd, &w, &h) {
    rc := Buffer(16, 0) ; RECT: left, top, right, bottom
    if (!DllCall("GetClientRect", "ptr", hwnd, "ptr", rc, "int"))
        return false
    w := NumGet(rc, 8, "int") - NumGet(rc, 0, "int")
    h := NumGet(rc, 12, "int") - NumGet(rc, 4, "int")
    return (w > 0 && h > 0)
}

Sh_OnSize(guiObj, minMax, width, height) {
    global SH_CONFIG, ShLv, ShSearch, ShCloseBtn, ShCopyExeBtn, ShCount, ShContext, ShLastGuiW, ShLastGuiH
    global ShHeaderBg, ShFooterBg, ShBorderTop, ShBorderLeft, ShBorderRight, ShBorderBottom
    if (minMax = -1)
        return
    ShLastGuiW := width
    ShLastGuiH := height

    headerH := SH_CONFIG.headerHeight
    footerH := SH_CONFIG.footerHeight
    pad := SH_CONFIG.padding
    border := 1

    ; Border + background panels
    ShBorderTop.Move(0, 0, width, border)
    ShBorderLeft.Move(0, 0, border, height)
    ShBorderRight.Move(width - border, 0, border, height)
    ShBorderBottom.Move(0, height - border, width, border)

    ShHeaderBg.Move(0, 0, width, headerH)
    ShFooterBg.Move(0, headerH, width, footerH)

    maxSearchW := 260
    minSearchW := 140
    closeW := 34
    copyExeW := 42
    topY := 6

    rightBlockW := closeW + 6 + copyExeW
    searchRightX := width - pad - rightBlockW - 10
    searchLeftMin := pad + 220 + 10
    searchW := searchRightX - searchLeftMin
    if (searchW > maxSearchW)
        searchW := maxSearchW
    if (searchW < minSearchW)
        searchW := minSearchW
    if (searchRightX - searchW < searchLeftMin) {
        searchW := searchRightX - searchLeftMin
        if (searchW < 0)
            searchW := 0
    }
    searchX := searchRightX - searchW

    ShCloseBtn.Move(width - pad - closeW, topY - 2, closeW, 26)
    ShCopyExeBtn.Move(width - pad - closeW - 6 - copyExeW, topY - 1, copyExeW, 24)
    ShSearch.Move(searchX, topY, searchW, 22)

    contextY := topY + 22
    contextH := headerH - contextY
    if (contextH < 10)
        contextH := 10
    contextX := searchX
    contextW := (width - pad) - contextX
    if (contextW < 0)
        contextW := 0
    ShContext.Move(contextX, contextY, contextW, contextH)

    ShCount.Move(pad, headerH + 5, width - (2 * pad), 18)

    lvY := headerH + footerH
    lvH := height - lvY
    if (lvH < 50)
        lvH := 50

    ShLv.Move(pad, lvY + 4, width - (2 * pad), lvH - 8)
    ShLv.ModifyCol(1, 220)
    ShLv.ModifyCol(2, width - (2 * pad) - 240)
}

Sh_WmSize(wParam, lParam, msg, hwnd) {
    global ShGui, ShInSizeHandler
    if (!IsSet(ShGui) || ShGui = "" || hwnd != ShGui.Hwnd)
        return
    if (ShInSizeHandler)
        return
    ShInSizeHandler := true
    try {
        width := lParam & 0xFFFF
        height := (lParam >> 16) & 0xFFFF
        Sh_OnSize(ShGui, wParam, width, height)
    } finally {
        ShInSizeHandler := false
    }
}

Sh_CopyActiveExe() {
    global ShActiveExe
    if (ShActiveExe = "") {
        ToolTip("No active exe", , , 20)
        SetTimer(() => ToolTip(, , , 20), -900)
        return
    }
    A_Clipboard := ""
    A_Clipboard := ShActiveExe
    ToolTip("Copied: " ShActiveExe, , , 20)
    SetTimer(() => ToolTip(, , , 20), -900)
}

Sh_JoinArray(arr, sep := ",") {
    if (!IsObject(arr) || arr.Length = 0)
        return ""
    out := ""
    for _, v in arr {
        out .= (out = "" ? "" : sep) v
    }
    return out
}

Sh_WmNotify(wParam, lParam, msg, hwnd) {
    global ShGui, ShLv, ShRenderedRows, SH_CONFIG
    if (!IsSet(ShGui) || !IsSet(ShLv) || ShGui = "" || ShLv = "")
        return
    if (hwnd != ShGui.Hwnd)
        return

    hwndFrom := NumGet(lParam, 0, "ptr")
    if (hwndFrom != ShLv.Hwnd)
        return

    code := NumGet(lParam, A_PtrSize * 2, "int")

    nmhdrSize := (A_PtrSize = 8) ? 24 : 12
    nmcdSize := (A_PtrSize = 8) ? 80 : 48
    offItemSpec := nmhdrSize + 4 + (A_PtrSize = 8 ? 4 : 0) + A_PtrSize + 16

    ; Prevent selecting section/group rows.
    if (code = -100) { ; LVN_ITEMCHANGING
        iItem := NumGet(lParam, nmhdrSize, "int") + 1
        if (iItem >= 1 && iItem <= ShRenderedRows.Length) {
            try {
                if (ShRenderedRows[iItem].kind != "item")
                    return 1
            }
        }
        return 0
    }

    ; Per-row colors for section/group headers.
    if (code = -12) { ; NM_CUSTOMDRAW
        drawStage := NumGet(lParam, nmhdrSize, "uint")
        if (drawStage = 0x1) { ; CDDS_PREPAINT
            return 0x20 ; CDRF_NOTIFYITEMDRAW
        }
        if (drawStage = 0x10001) { ; CDDS_ITEMPREPAINT
            ; In report view, colors are applied per-subitem. Ask for subitem draw callbacks.
            return 0x20 ; CDRF_NOTIFYSUBITEMDRAW
        }
        if (drawStage = 0x30001) { ; CDDS_ITEMPREPAINT | CDDS_SUBITEM
            row := NumGet(lParam, offItemSpec, "UPtr") + 1
            if (row >= 1 && row <= ShRenderedRows.Length) {
                kind := ""
                try kind := ShRenderedRows[row].kind
                if (kind = "section") {
                    style := "app"
                    try style := ShRenderedRows[row].style
                    if (style = "active") {
                        NumPut("uint", Sh_ColorRef(SH_CONFIG.accent), lParam, nmcdSize)                 ; clrText
                        NumPut("uint", Sh_ColorRef(SH_CONFIG.sectionBgActive), lParam, nmcdSize + 4)   ; clrTextBk
                    } else if (style = "global") {
                        NumPut("uint", Sh_ColorRef(SH_CONFIG.globalAccent), lParam, nmcdSize)
                        NumPut("uint", Sh_ColorRef(SH_CONFIG.sectionBgGlobal), lParam, nmcdSize + 4)
                    } else {
                        NumPut("uint", Sh_ColorRef(SH_CONFIG.appAccent), lParam, nmcdSize)
                        NumPut("uint", Sh_ColorRef(SH_CONFIG.panel2), lParam, nmcdSize + 4)
                    }
                    return 0x2 ; CDRF_NEWFONT
                }
                if (kind = "group") {
                    style := "app"
                    try style := ShRenderedRows[row].style
                    NumPut("uint", Sh_ColorRef(SH_CONFIG.muted), lParam, nmcdSize) ; clrText
                    if (style = "active")
                        NumPut("uint", Sh_ColorRef(SH_CONFIG.groupBgActive), lParam, nmcdSize + 4)
                    else if (style = "global")
                        NumPut("uint", Sh_ColorRef(SH_CONFIG.groupBgGlobal), lParam, nmcdSize + 4)
                    else
                        NumPut("uint", Sh_ColorRef(SH_CONFIG.panel), lParam, nmcdSize + 4)
                    return 0x2
                }
            }
            return 0
        }
        return 0
    }
}

Sh_ColorRef(hexRgb) {
    global ShColorCache
    key := StrLower(hexRgb)
    if (ShColorCache.Has(key))
        return ShColorCache[key]

    hex := RegExReplace(key, "i)^0x", "")
    val := 0
    try val := Integer("0x" hex)
    r := (val >> 16) & 0xFF
    g := (val >> 8) & 0xFF
    b := val & 0xFF
    colorRef := (b << 16) | (g << 8) | r
    ShColorCache[key] := colorRef
    return colorRef
}

Sh_WmNcHitTest(wParam, lParam, msg, hwnd) {
    global SH_CONFIG, ShGui, ShSearch, ShCloseBtn, ShCopyExeBtn
    if (ShGui = "" || hwnd != ShGui.Hwnd)
        return

    x := (lParam & 0xFFFF)
    y := (lParam >> 16) & 0xFFFF
    if (x & 0x8000)
        x := -(0x10000 - x)
    if (y & 0x8000)
        y := -(0x10000 - y)

    WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)
    cx := x - wx
    cy := y - wy

    grip := SH_CONFIG.resizeGrip
    onLeft := (cx < grip)
    onRight := (cx >= ww - grip)
    onTop := (cy < grip)
    onBottom := (cy >= wh - grip)

    ; Resizing zones
    if (onTop && onLeft)
        return 0xD ; HTTOPLEFT
    if (onTop && onRight)
        return 0xE ; HTTOPRIGHT
    if (onBottom && onLeft)
        return 0x10 ; HTBOTTOMLEFT
    if (onBottom && onRight)
        return 0x11 ; HTBOTTOMRIGHT
    if (onLeft)
        return 0xA ; HTLEFT
    if (onRight)
        return 0xB ; HTRIGHT
    if (onTop)
        return 0xC ; HTTOP
    if (onBottom)
        return 0xF ; HTBOTTOM

    ; Drag zone: header area, excluding interactive controls.
    if (cy <= SH_CONFIG.headerHeight) {
        MouseGetPos(, , , &ctrlHwnd, 2)
        if (ctrlHwnd = ShSearch.Hwnd || ctrlHwnd = ShCloseBtn.Hwnd || ctrlHwnd = ShCopyExeBtn.Hwnd)
            return 0x1 ; HTCLIENT
        return 0x2 ; HTCAPTION
    }

    return 0x1 ; HTCLIENT
}

; ============================================================
; Rendering
; ============================================================

Sh_WatchActiveWindow() {
    global SH_CONFIG, ShGui, ShLastNonGuiWindow, ShLastActiveDefIdx
    if (!IsSet(ShGui) || ShGui = "" || !Sh_GuiIsVisible()) {
        SetTimer(Sh_WatchActiveWindow, 0)
        return
    }

    try activeId := WinGetID("A")
    catch
        return

    ; If the overlay itself is active (e.g., typing in search), keep the last non-GUI window context.
    if (activeId = ShGui.Hwnd)
        return

    if (activeId != ShLastNonGuiWindow) {
        if (Sh_IsIgnoredWindow(activeId))
            return
        ShLastNonGuiWindow := activeId
        info := Sh_GetActiveWindowInfo()
        activeIdx := Sh_GetActiveDefIndex(info.exe, info.class, info.title)

        ; Only redraw when we transition into/out of a matched app, or between two different matched apps.
        needsRedraw := (activeIdx != ShLastActiveDefIdx) && (activeIdx != 0 || ShLastActiveDefIdx != 0)
        ShLastActiveDefIdx := activeIdx

        Sh_UpdateContext(info, activeIdx)
        if (needsRedraw)
            Sh_RefreshList()
    }
}

Sh_RefreshList() {
    global ShGui, ShLv, ShSearch, ShContext, ShCount, ShAllDefs, ShRenderedRows, ShLoadStats, ShActiveExe, ShLastActiveDefIdx
    if (!IsSet(ShGui) || !IsSet(ShLv) || ShGui = "" || ShLv = "")
        return

    ShLv.Delete()
    ShRenderedRows := []

    info := Sh_GetActiveWindowInfo()
    ShActiveExe := info.exe
    activeIdx := Sh_GetActiveDefIndex(info.exe, info.class, info.title)
    ShLastActiveDefIdx := activeIdx

    globalDefs := []
    appDefs := []
    for idx, def in ShAllDefs {
        if (StrLower(def.type) = "global")
            globalDefs.Push({idx: idx, def: def})
        else
            appDefs.Push({idx: idx, def: def})
    }

    Sh_SortDefs(globalDefs)
    Sh_SortDefs(appDefs)

    Sh_UpdateContext(info, activeIdx)

    search := ShSearch.Text

    totalItems := 0
    shownItems := 0

    ; Active app first (if any)
    if (activeIdx) {
        def := ShAllDefs[activeIdx]
        totalItems += def.entries.Length
        shownItems += Sh_AddSection(def.title, def.entries, search, "active")
    }

    ; Globals next
    for obj in globalDefs {
        totalItems += obj.def.entries.Length
        shownItems += Sh_AddSection(obj.def.title, obj.def.entries, search, "global")
    }

    ; Remaining apps A-Z (excluding active)
    for obj in appDefs {
        if (obj.idx = activeIdx)
            continue
        totalItems += obj.def.entries.Length
        shownItems += Sh_AddSection(obj.def.title, obj.def.entries, search, "app")
    }

    if (totalItems = 0) {
        ShLv.Add("", "No shortcuts loaded", "")
        ShLv.Add("", "Copy ``example-shortcuts/`` to ``shortcuts/`` and keep the ``.yaml`` extension.", "")
        if (ShLoadStats.files > 0 && ShLoadStats.loaded = 0)
            ShLv.Add("", "YAML files found, but none could be parsed (check indentation / format).", "")
        if (ShLoadStats.details.Length) {
            ShLv.Add("", "", "")
            ShLv.Add("", "Diagnostics:", "")
            for line in ShLoadStats.details {
                ShLv.Add("", "  " line, "")
            }
        }
        ShCount.Text := (ShLoadStats.files " files  •  " ShLoadStats.loaded " loaded  •  " ShLoadStats.errors " errors  •  " ShLoadStats.entries " entries")
        return
    }

    ShCount.Text := search != "" ? (shownItems " matches  •  " totalItems " total") : (totalItems " shortcuts")
}

Sh_UpdateContext(info, activeIdx) {
    global ShContext, ShAllDefs, ShActiveExe
    if (!IsSet(ShContext) || ShContext = "")
        return

    ShActiveExe := info.exe
    activeLabel := activeIdx ? ShAllDefs[activeIdx].title : ""
    if (info.exe != "") {
        ShContext.Text := activeLabel != ""
            ? ("Active: " activeLabel " • " info.exe)
            : ("Active: (no match) • " info.exe)
    } else {
        ShContext.Text := activeLabel != "" ? ("Active: " activeLabel) : "Active: (no match)"
    }
}

Sh_SortDefs(defArray) {
    ; Keep v2.0 compatibility: Array.Sort(callback) is not available in all v2 builds.
    Sh_SortInPlace(defArray, (a, b) => (Sh_AsOrder(a.def.displayOrder) != Sh_AsOrder(b.def.displayOrder))
        ? (Sh_AsOrder(a.def.displayOrder) < Sh_AsOrder(b.def.displayOrder))
        : (StrCompare(a.def.title, b.def.title, false) < 0))
}

Sh_AsOrder(value, defaultValue := 999) {
    ; Coerce numeric-ish values to integer for safe comparisons.
    t := Type(value)
    if (t = "Integer" || t = "Float")
        return Integer(value)
    if (t = "String" && RegExMatch(value, "^-?\d+$"))
        return Integer(value)
    return defaultValue
}

Sh_SortInPlace(arr, lessFn) {
    ; Simple insertion sort for arrays of objects (small lists; avoids requiring Array.Sort).
    len := arr.Length
    if (len <= 1)
        return
    i := 2
    while (i <= len) {
        item := arr[i]
        j := i - 1
        while (j >= 1 && lessFn(item, arr[j])) {
            arr[j + 1] := arr[j]
            j -= 1
        }
        arr[j + 1] := item
        i += 1
    }
}

Sh_AddSection(title, entries, searchText, sectionStyle := "app") {
    global ShLv, ShRenderedRows

    filtered := []
    for entry in entries {
        if (searchText = "" || Sh_EntryMatches(entry, searchText))
            filtered.Push(entry)
    }
    if (filtered.Length = 0)
        return 0

    ; Section header row
    ShLv.Add("", "— " title " —", "")
    ShRenderedRows.Push({ kind: "section", style: sectionStyle, keys: "", desc: "", section: title, group: "" })

    lastGroup := "__none__"
    shown := 0
    for entry in filtered {
        groupName := entry.group != "" ? entry.group : ""
        if (groupName != "" && groupName != lastGroup) {
            ShLv.Add("", "  " groupName, "")
            ShRenderedRows.Push({ kind: "group", style: sectionStyle, keys: "", desc: "", section: title, group: groupName })
            lastGroup := groupName
        }
        ShLv.Add("", entry.keys, entry.desc)
        ShRenderedRows.Push({ kind: "item", style: sectionStyle, keys: entry.keys, desc: entry.desc, section: title, group: groupName })
        shown += 1
    }
    return shown
}

Sh_EntryMatches(entry, needle) {
    n := StrLower(needle)
    if (InStr(StrLower(entry.keys), n))
        return true
    if (InStr(StrLower(entry.desc), n))
        return true
    if (entry.group != "" && InStr(StrLower(entry.group), n))
        return true
    return false
}

; ============================================================
; Window persistence
; ============================================================

Sh_SaveWindowGeometry() {
    global SH_CONFIG, ShGui
    if (!Sh_GuiIsVisible())
        return
    x := ""
    y := ""
    w := ""
    h := ""
    try WinGetPos(&x, &y, &w, &h, "ahk_id " ShGui.Hwnd)
    catch
        return
    IniWrite(Integer(x), SH_CONFIG.iniPath, "Window", "x")
    IniWrite(Integer(y), SH_CONFIG.iniPath, "Window", "y")
    IniWrite(Integer(w), SH_CONFIG.iniPath, "Window", "w")
    IniWrite(Integer(h), SH_CONFIG.iniPath, "Window", "h")
}

Sh_ReadWindowGeometry() {
    global SH_CONFIG
    geo := Map()
    try {
        x := IniRead(SH_CONFIG.iniPath, "Window", "x", "")
        y := IniRead(SH_CONFIG.iniPath, "Window", "y", "")
        w := IniRead(SH_CONFIG.iniPath, "Window", "w", "")
        h := IniRead(SH_CONFIG.iniPath, "Window", "h", "")
        if (RegExMatch(x, "^-?\\d+$"))
            geo["x"] := Integer(x)
        if (RegExMatch(y, "^-?\\d+$"))
            geo["y"] := Integer(y)
        if (RegExMatch(w, "^\\d+$"))
            geo["w"] := Integer(w)
        if (RegExMatch(h, "^\\d+$"))
            geo["h"] := Integer(h)
    }
    return geo
}
