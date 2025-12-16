#Requires AutoHotkey v2.0

#SingleInstance Force

; ShortcutsHelper - Shortcut reference overlay
; - YAML-driven (copy `example-shortcuts/` -> `shortcuts/`)
; - Shows global shortcuts, then active app, then the rest (A-Z)
; - Borderless, resizable, and does not steal focus on show

#Include "Lib\ShortcutsYamlParser.ahk"

; ============================================================
; Configuration
; ============================================================
global SH_CONFIG := {
    shortcutsFolder: A_ScriptDir "\shortcuts",
    exampleFolder: A_ScriptDir "\example-shortcuts",
    iniPath: A_ScriptDir "\ShortcutsHelper.ini",
    hotkey: "#^;", ; Win + Ctrl + ;

    ; UI
    windowWidth: 760,
    windowHeight: 520,
    minWidth: 520,
    minHeight: 320,
    headerHeight: 44,
    footerHeight: 26,
    padding: 12,
    resizeGrip: 8,

    ; Colors (different look from NeatClipboard)
    bg: "0b1220",
    panel: "0f172a",
    panel2: "111c33",
    text: "e5e7eb",
    muted: "93a4b8",
    accent: "22c55e",
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
global ShHeaderBg := ""
global ShFooterBg := ""
global ShBorderTop := ""
global ShBorderLeft := ""
global ShBorderRight := ""
global ShBorderBottom := ""
global ShLastActiveWindow := 0
global ShAllDefs := [] ; Array of {title,type,displayOrder,match,entries}
global ShRenderedRows := [] ; Array of {keys,desc,section,group}
global ShLoadStats := { files: 0, loaded: 0, errors: 0 }

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
    if (ShGui = "")
        return false
    try return DllCall("IsWindowVisible", "ptr", ShGui.Hwnd, "int") != 0
    return false
}

Sh_Show() {
    global SH_CONFIG, ShGui, ShLastActiveWindow

    ShLastActiveWindow := WinGetID("A")
    Sh_EnsureShortcutsFolder()
    Sh_LoadAllYaml()

    if (ShGui = "") {
        Sh_CreateGui()
    } else {
        Sh_RefreshList()
    }

    geo := Sh_ReadWindowGeometry()
    opts := "NA"
    if (geo.Has("w") && geo.Has("h")) {
        opts .= " w" geo["w"] " h" geo["h"]
    } else {
        opts .= " w" SH_CONFIG.windowWidth " h" SH_CONFIG.windowHeight
    }
    if (geo.Has("x") && geo.Has("y")) {
        opts .= " x" geo["x"] " y" geo["y"]
    }

    ShGui.Show(opts)
}

Sh_Hide() {
    global ShGui, ShLastActiveWindow
    if (ShGui = "")
        return
    wasActive := WinActive("ahk_id " ShGui.Hwnd)
    Sh_SaveWindowGeometry()
    ShGui.Hide()
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
    ShLoadStats := { files: 0, loaded: 0, errors: 0 }

    if !DirExist(SH_CONFIG.shortcutsFolder)
        return

    Loop Files, SH_CONFIG.shortcutsFolder "\*.yaml" {
        ShLoadStats.files += 1
        parsed := ShortcutsYamlParser.ParseFile(A_LoopFileFullPath)
        if (parsed.HasOwnProp("error")) {
            ShLoadStats.errors += 1
            continue
        }

        title := parsed.HasOwnProp("title") && parsed.title != "" ? parsed.title : StrReplace(A_LoopFileName, ".yaml", "")
        type := parsed.HasOwnProp("type") ? parsed.type : "app"
        displayOrder := parsed.HasOwnProp("displayOrder") ? Sh_AsOrder(parsed.displayOrder) : 999
        match := parsed.HasOwnProp("match") ? parsed.match : {}

        entries := Sh_NormalizeYamlEntries(parsed)
        ShAllDefs.Push({ title: title, type: type, displayOrder: displayOrder, match: match, entries: entries })
        ShLoadStats.loaded += 1
    }
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
    global SH_CONFIG, ShGui, ShLv, ShSearch, ShTitle, ShContext, ShCount, ShCloseBtn
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

    ShContext := ShGui.Add("Text", "x" (SH_CONFIG.padding + 220) " y12 w220 h18 BackgroundTrans c" SH_CONFIG.muted, "")
    ShContext.SetFont("s9", "Segoe UI")

    ShSearch := ShGui.Add("Edit", "x0 y0 w100 h22 -E0x200", "")
    ShSearch.SetFont("s9", "Segoe UI")
    ShSearch.OnEvent("Change", (*) => Sh_RefreshList())

    ShCloseBtn := ShGui.Add("Button", "x0 y0 w28 h24", "×")
    ShCloseBtn.SetFont("s11 w600", "Segoe UI")
    ShCloseBtn.OnEvent("Click", (*) => Sh_Hide())

    ; Footer (status)
    ShFooterBg := ShGui.Add("Text", "x0 y0 w" SH_CONFIG.windowWidth " h" SH_CONFIG.footerHeight " Background" SH_CONFIG.panel2)
    ShCount := ShGui.Add("Text", "x" SH_CONFIG.padding " y0 w400 h18 BackgroundTrans c" SH_CONFIG.muted, "")
    ShCount.SetFont("s8", "Segoe UI")

    ; List
    ShLv := ShGui.Add("ListView", "x0 y0 w" SH_CONFIG.windowWidth " h" SH_CONFIG.windowHeight " -Multi -Hdr", ["Shortcut", "Description"])
    ShLv.SetFont("s9", "Segoe UI")
    ShLv.ModifyCol(1, 220)
    ShLv.ModifyCol(2, 520)

    ShGui.OnEvent("Close", (*) => Sh_Hide())
    ShGui.OnEvent("Escape", (*) => Sh_Hide())
    ShGui.OnEvent("Size", Sh_OnSize)

    ; Border (1px) - add last so it stays on top
    ShBorderTop := ShGui.Add("Text", "x0 y0 w" SH_CONFIG.windowWidth " h1 Background" SH_CONFIG.border)
    ShBorderLeft := ShGui.Add("Text", "x0 y0 w1 h" SH_CONFIG.windowHeight " Background" SH_CONFIG.border)
    ShBorderRight := ShGui.Add("Text", "x0 y0 w1 h" SH_CONFIG.windowHeight " Background" SH_CONFIG.border)
    ShBorderBottom := ShGui.Add("Text", "x0 y0 w" SH_CONFIG.windowWidth " h1 Background" SH_CONFIG.border)

    OnMessage(0x84, Sh_WmNcHitTest) ; WM_NCHITTEST

    Sh_OnSize(ShGui, 0, SH_CONFIG.windowWidth, SH_CONFIG.windowHeight)
    Sh_RefreshList()
}

Sh_OnSize(guiObj, minMax, width, height) {
    global SH_CONFIG, ShLv, ShSearch, ShCloseBtn, ShCount, ShContext
    global ShHeaderBg, ShFooterBg, ShBorderTop, ShBorderLeft, ShBorderRight, ShBorderBottom
    if (minMax = -1)
        return

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

    searchW := 260
    closeW := 34
    topY := 10

    ShCloseBtn.Move(width - pad - closeW, topY - 2, closeW, 26)
    ShSearch.Move(width - pad - closeW - 10 - searchW, topY, searchW, 22)
    ShContext.Move(pad + 220, topY + 2, width - (pad + 220) - (pad + closeW + 10 + searchW) - 10, 18)

    ShCount.Move(pad, headerH + 5, width - (2 * pad), 18)

    lvY := headerH + footerH
    lvH := height - lvY
    if (lvH < 50)
        lvH := 50

    ShLv.Move(pad, lvY + 4, width - (2 * pad), lvH - 8)
    ShLv.ModifyCol(1, 220)
    ShLv.ModifyCol(2, width - (2 * pad) - 240)
}

Sh_WmNcHitTest(wParam, lParam, msg, hwnd) {
    global SH_CONFIG, ShGui, ShSearch, ShCloseBtn
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
        if (ctrlHwnd = ShSearch.Hwnd || ctrlHwnd = ShCloseBtn.Hwnd)
            return 0x1 ; HTCLIENT
        return 0x2 ; HTCAPTION
    }

    return 0x1 ; HTCLIENT
}

; ============================================================
; Rendering
; ============================================================

Sh_RefreshList() {
    global ShGui, ShLv, ShSearch, ShContext, ShCount, ShAllDefs, ShRenderedRows, ShLoadStats
    if (ShGui = "" || ShLv = "")
        return

    ShLv.Delete()
    ShRenderedRows := []

    activeIdx := Sh_GetActiveAppTitle()

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

    activeLabel := ""
    if (activeIdx) {
        activeLabel := ShAllDefs[activeIdx].title
    }
    ShContext.Text := activeLabel != "" ? ("Active: " activeLabel) : "Active: (no match)"

    search := ShSearch.Text

    totalItems := 0
    shownItems := 0

    ; Globals first
    for obj in globalDefs {
        totalItems += obj.def.entries.Length
        shownItems += Sh_AddSection(obj.def.title, obj.def.entries, search)
    }

    ; Active app next (if any)
    if (activeIdx) {
        def := ShAllDefs[activeIdx]
        totalItems += def.entries.Length
        shownItems += Sh_AddSection(def.title, def.entries, search)
    }

    ; Remaining apps A-Z (excluding active)
    for obj in appDefs {
        if (obj.idx = activeIdx)
            continue
        totalItems += obj.def.entries.Length
        shownItems += Sh_AddSection(obj.def.title, obj.def.entries, search)
    }

    if (totalItems = 0) {
        ShLv.Add("", "No shortcuts loaded", "")
        ShLv.Add("", "Copy ``example-shortcuts/`` to ``shortcuts/`` and keep the ``.yaml`` extension.", "")
        if (ShLoadStats.files > 0 && ShLoadStats.loaded = 0)
            ShLv.Add("", "YAML files found, but none could be parsed (check indentation / format).", "")
        ShCount.Text := (ShLoadStats.files " files  •  " ShLoadStats.loaded " loaded  •  " ShLoadStats.errors " errors")
        return
    }

    ShCount.Text := search != "" ? (shownItems " matches  •  " totalItems " total") : (totalItems " shortcuts")
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

Sh_AddSection(title, entries, searchText) {
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
    ShRenderedRows.Push({ keys: "", desc: "", section: title, group: "" })

    lastGroup := "__none__"
    shown := 0
    for entry in filtered {
        groupName := entry.group != "" ? entry.group : ""
        if (groupName != "" && groupName != lastGroup) {
            ShLv.Add("", "  " groupName, "")
            ShRenderedRows.Push({ keys: "", desc: "", section: title, group: groupName })
            lastGroup := groupName
        }
        ShLv.Add("", entry.keys, entry.desc)
        ShRenderedRows.Push({ keys: entry.keys, desc: entry.desc, section: title, group: groupName })
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
    WinGetPos(&x, &y, &w, &h, "ahk_id " ShGui.Hwnd)
    IniWrite(x, SH_CONFIG.iniPath, "Window", "x")
    IniWrite(y, SH_CONFIG.iniPath, "Window", "y")
    IniWrite(w, SH_CONFIG.iniPath, "Window", "w")
    IniWrite(h, SH_CONFIG.iniPath, "Window", "h")
}

Sh_ReadWindowGeometry() {
    global SH_CONFIG
    geo := Map()
    try geo["x"] := IniRead(SH_CONFIG.iniPath, "Window", "x")
    try geo["y"] := IniRead(SH_CONFIG.iniPath, "Window", "y")
    try geo["w"] := IniRead(SH_CONFIG.iniPath, "Window", "w")
    try geo["h"] := IniRead(SH_CONFIG.iniPath, "Window", "h")
    return geo
}
