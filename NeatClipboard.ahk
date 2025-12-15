#Requires AutoHotkey v2.0
#SingleInstance Force

; NeatClipboard - Clipboard Manager & Cheatsheet Visualizer
; Version 2.0
; 
; Features:
; - Load clips and cheatsheets from YAML files in the "clips" folder
; - Tabbed interface with one tab per YAML file
; - Visual grouping within each tab
; - Centralized search with live filtering
; - Result count badges on each tab
; - Click to copy and optionally auto-paste

#Include "Lib\YamlParser.ahk"

; ============================================================
; Configuration
; ============================================================
global CONFIG := {
    clipsFolder: A_ScriptDir "\clips",
    autoPaste: true,  ; Toggle: automatically paste after copying
    hotkey: "#!v",    ; Win + Alt + V
    
    ; UI Colors (Dark theme)
    bgColor: "1e1e2e",
    bgColorLight: "2a2a3e",
    accentColor: "89b4fa",
    textColor: "cdd6f4",
    textMuted: "6c7086",
    borderColor: "45475a",
    groupBg: "313244",
    
    ; UI Dimensions
    windowWidth: 700,
    windowHeight: 550,
    searchBarHeight: 25,
    tabHeight: 30,
    itemHeight: 50,
    padding: 10,
    tabPadding: 70
}

; ============================================================
; Global State
; ============================================================
global MyGui := ""
global TabData := Map()     ; TabName -> {items: [], filteredItems: [], displayOrder: n}
global TabOrder := []       ; Array of tab names in display order
global DisplayOrderItems := Map()  ; TabName -> Array of items in display order
global TabControl := ""
global SearchEdit := ""
global ContentPanels := Map()  ; TabName -> Panel Control
global LvByHwnd := Map()       ; hwnd -> ListView control
global AutoPasteCheckbox := ""
global SearchDescCheckbox := ""  ; Toggle for searching in descriptions
global LastActiveWindow := ""
global _NcHover := {active: false, hwnd: 0, row: 0, col: 0}

; ============================================================
; Hotkey Registration
; ============================================================
#HotIf WinActive("A")
#!v::ShowClipboardManager()

; ============================================================
; Main Functions
; ============================================================

ShowClipboardManager() {
    global MyGui, LastActiveWindow
    
    ; Remember the active window before showing GUI
    LastActiveWindow := WinGetID("A")
    
    ; Destroy existing GUI if any
    if (MyGui != "") {
        try NcDestroyGui()
    }
    
    ; Load all YAML files
    LoadAllClips()
    
    ; Create and show GUI
    CreateMainGUI()
}

LoadAllClips() {
    global TabData, TabOrder, CONFIG
    
    TabData := Map()
    TabOrder := []
    
    ; Find all YAML files in clips folder
    if !DirExist(CONFIG.clipsFolder) {
        DirCreate(CONFIG.clipsFolder)
        return
    }
    
    ; Temporary array for sorting
    tempTabs := []
    
    Loop Files, CONFIG.clipsFolder "\*.yaml" {
        yamlPath := A_LoopFileFullPath
        fileName := StrReplace(A_LoopFileName, ".yaml", "")
        
        parsed := YamlParser.ParseFile(yamlPath)
        
        if (parsed.HasOwnProp("error")) {
            continue
        }
        
        tabName := parsed.title != "" ? parsed.title : fileName
        displayOrder := parsed.HasOwnProp("displayOrder") ? parsed.displayOrder : 999
        normalizedItems := NormalizeYamlItems(parsed.HasOwnProp("items") ? parsed.items : [])
        
        TabData[tabName] := {
            items: normalizedItems,
            filteredItems: normalizedItems.Clone(),
            displayOrder: displayOrder
        }
        
        tempTabs.Push({name: tabName, order: displayOrder})
    }
    
    ; Sort tabs by displayOrder
    n := tempTabs.Length
    Loop n - 1 {
        i := A_Index
        Loop n - i {
            j := A_Index
            if (tempTabs[j].order > tempTabs[j + 1].order) {
                temp := tempTabs[j]
                tempTabs[j] := tempTabs[j + 1]
                tempTabs[j + 1] := temp
            }
        }
    }
    
    ; Build sorted tab order array
    for tab in tempTabs {
        TabOrder.Push(tab.name)
    }
}

NormalizeYamlItems(items) {
    normalized := []
    if !(items is Array)
        return normalized
    
    for _, item in items {
        if !(item is Object)
            continue
        
        ; Classic/flat clip item always wins if present.
        clipText := item.HasOwnProp("clip") ? item.clip : ""
        if (Trim(clipText) != "") {
            normalized.Push({
                clip: clipText,
                description: item.HasOwnProp("description") ? item.description : "",
                group: item.HasOwnProp("group") ? item.group : ""
            })
            continue
        }
        
        ; Group container format: {group: "...", items: [ {clip, description, group?}, ... ]}
        if (item.HasOwnProp("items") && (item.items is Array)) {
            outerGroup := item.HasOwnProp("group") ? item.group : ""
            for _, subItem in item.items {
                if !(subItem is Object)
                    continue
                clipText := subItem.HasOwnProp("clip") ? subItem.clip : ""
                if (Trim(clipText) = "")
                    continue
                
                clipGroup := subItem.HasOwnProp("group") && subItem.group != "" ? subItem.group : outerGroup
                normalized.Push({
                    clip: clipText,
                    description: subItem.HasOwnProp("description") ? subItem.description : "",
                    group: clipGroup
                })
            }
            continue
        }
    }
    
    return normalized
}

CreateMainGUI() {
    global MyGui, TabControl, SearchEdit, ContentPanels, BadgeTexts, AutoPasteCheckbox, SearchDescCheckbox, CONFIG, LvByHwnd
    
    ContentPanels := Map()
    BadgeTexts := Map()
    LvByHwnd := Map()
    
    ; Create main window
    MyGui := Gui("+Resize", "NeatClipboard")
    MyGui.BackColor := CONFIG.bgColor
    MyGui.SetFont("s10 c" CONFIG.textColor, "Segoe UI")
    MyGui.OnEvent("Close", (*) => NcDestroyGui())
    MyGui.OnEvent("Escape", (*) => NcDestroyGui())
    MyGui.OnEvent("Size", OnGuiResize)
    
    ; ========== Top Bar ==========
    ; Search icon and edit
    MyGui.SetFont("s12 c" CONFIG.textMuted)
    MyGui.Add("Text", "x" CONFIG.padding " y" (CONFIG.padding + 5) " w20 h25", "🔍")
    
    MyGui.SetFont("s10 c" CONFIG.textColor, "Segoe UI")
    SearchEdit := MyGui.Add("Edit", 
        "x35 y" CONFIG.padding " w" (CONFIG.windowWidth - 350) " h" CONFIG.searchBarHeight " Background" CONFIG.bgColorLight,
        "")
    SearchEdit.OnEvent("Change", OnSearchChange)
    
    ; Search in descriptions toggle
    SearchDescCheckbox := MyGui.Add("Checkbox", 
        "x" (CONFIG.windowWidth - 290) " y" (CONFIG.padding + 5) " w130 c" CONFIG.textMuted " Checked",
        "+ descriptions")
    SearchDescCheckbox.OnEvent("Click", OnSearchDescToggle)
    
    ; Auto-paste toggle
    AutoPasteCheckbox := MyGui.Add("Checkbox", 
        "x" (CONFIG.windowWidth - 130) " y" (CONFIG.padding + 5) " w120 c" CONFIG.textMuted " Checked" CONFIG.autoPaste,
        "Auto-paste")
    AutoPasteCheckbox.OnEvent("Click", OnAutoPasteToggle)
    
    ; ========== Tab Control ==========
    tabY := CONFIG.padding + CONFIG.searchBarHeight + 10
    
    if (TabOrder.Length = 0) {
        MyGui.SetFont("s11 c" CONFIG.textMuted)
        MyGui.Add("Text", "x" CONFIG.padding " y100 w" (CONFIG.windowWidth - 2*CONFIG.padding) " Center", 
            "No clips found.`n`nAdd YAML files to the 'clips' folder.")
        MyGui.Show("w" CONFIG.windowWidth " h200")
        return
    }
    
    ; Build tab list with initial counts - using sorted TabOrder
    tabList := ""
    for tabName in TabOrder {
        count := TabData[tabName].items.Length
        tabList .= tabName " (" count ")|"
    }
    tabList := RTrim(tabList, "|")
    
    TabControl := MyGui.Add("Tab3", 
        "x" CONFIG.padding " y" tabY " w" (CONFIG.windowWidth - 2*CONFIG.padding) " h" (CONFIG.windowHeight - tabY - CONFIG.padding) " Background" CONFIG.bgColorLight " vTabCtrl",
        StrSplit(tabList, "|"))
    TabControl.OnEvent("Change", OnTabChange)
    
    ; Create content for each tab
    ; Tab3 content area: need to position ListView INSIDE each tab's display area
    ; The tab headers take about 25px, so content starts below that
    tabContentX := CONFIG.padding + 5
    tabContentY := tabY + 28  ; Below tab headers
    lvWidth := CONFIG.windowWidth - 2*CONFIG.padding - 15
    lvHeight := CONFIG.windowHeight - tabContentY - CONFIG.padding - 10
    
    tabIndex := 0
    for tabName in TabOrder {
        tabIndex++
        count := TabData[tabName].items.Length
        TabControl.UseTab(tabIndex)  ; Use index instead of name since names now have counts
        CreateTabContent(tabName, tabContentX, tabContentY, lvWidth, lvHeight)
    }
    
    TabControl.UseTab()  ; Reset to no specific tab
    
    ; Update badges for initial state
    UpdateAllBadges()
    
    ; Register keyboard shortcuts for this GUI
    RegisterGuiHotkeys()

    ; ListView does not support word-wrapping with per-row variable height in Report view.
    ; Provide hover tooltips so full Clip/Description text can be read without truncation.
    RegisterListViewHoverTooltips()
    
    ; Show
    MyGui.Show("w" CONFIG.windowWidth " h" CONFIG.windowHeight)
    FocusActiveTabListView()
}

RegisterGuiHotkeys() {
    global MyGui
    
    ; Ctrl+F = Focus search and select all
    HotIfWinActive("ahk_id " MyGui.Hwnd)
    Hotkey("^f", (*) => FocusSearch(), "On")
    
    ; Ctrl+1-9 = Switch to tab 1-9
    ; Use Bind() to capture the value, not reference
    Loop 9 {
        Hotkey("^" A_Index, SwitchToTab.Bind(A_Index), "On")
    }
    
    ; Alt+1-9 = Activate entry 1-9
    Loop 9 {
        Hotkey("!" A_Index, ActivateEntry.Bind(A_Index), "On")
    }

    ; 1-9 = Activate entry 1-9 (only when the search box is NOT focused)
    HotIf(NcHotIfNoSearchFocus)
    Loop 9 {
        Hotkey(A_Index, ActivateEntry.Bind(A_Index), "On")
    }
    HotIfWinActive("ahk_id " MyGui.Hwnd)
    
    HotIf()  ; Reset context
}

NcHotIfNoSearchFocus(*) {
    global MyGui
    return (MyGui != "") && WinActive("ahk_id " MyGui.Hwnd) && !NcIsSearchFocused()
}

NcIsSearchFocused() {
    global MyGui, SearchEdit
    if (MyGui = "" || SearchEdit = "")
        return false

    try {
        focusedClassNN := ControlGetFocus("ahk_id " MyGui.Hwnd)
        if (focusedClassNN = "")
            return false
        focusedHwnd := ControlGetHwnd(focusedClassNN, "ahk_id " MyGui.Hwnd)
        return (focusedHwnd = SearchEdit.Hwnd)
    } catch {
        return false
    }
}

FocusActiveTabListView() {
    global MyGui, TabControl, TabOrder, ContentPanels
    if (MyGui = "" || TabControl = "" || TabOrder.Length = 0)
        return

    tabIdx := TabControl.Value
    if (tabIdx < 1 || tabIdx > TabOrder.Length)
        tabIdx := 1

    tabName := TabOrder[tabIdx]
    if ContentPanels.Has(tabName) {
        try ContentPanels[tabName].Focus()
    }
}

NcClearHoverTooltip() {
    global _NcHover
    ToolTip()
    _NcHover.active := false
    _NcHover.hwnd := 0
    _NcHover.row := 0
    _NcHover.col := 0
}

NcDestroyGui() {
    global MyGui, TabControl, SearchEdit, ContentPanels, LvByHwnd
    static destroying := false
    if (destroying)
        return
    destroying := true

    try {
        NcClearHoverTooltip()
        if (MyGui != "")
            try MyGui.Destroy()
    } finally {
        MyGui := ""
        TabControl := ""
        SearchEdit := ""
        ContentPanels := Map()
        LvByHwnd := Map()
        destroying := false
    }
}

FocusSearch() {
    global SearchEdit
    SearchEdit.Focus()
    SendInput("^a")  ; Select all text
}

SwitchToTab(tabNum, *) {
    global TabControl, TabOrder
    
    if (tabNum <= TabOrder.Length) {
        TabControl.Choose(tabNum)
    }
}

ActivateEntry(entryNum, *) {
    global TabOrder, TabControl, DisplayOrderItems
    
    ; Get current tab
    tabIdx := TabControl.Value
    if (tabIdx < 1 || tabIdx > TabOrder.Length)
        return
    
    currentTab := TabOrder[tabIdx]
    
    ; Use DisplayOrderItems which matches the actual display order
    if !DisplayOrderItems.Has(currentTab)
        return
    
    items := DisplayOrderItems[currentTab]
    
    ; Direct access by index
    if (entryNum >= 1 && entryNum <= items.Length) {
        CopyAndPasteItem(items[entryNum])
    }
}

; ============================================================
; Dynamic Clip Functions
; ============================================================

/**
 * Process dynamic function calls in clip text
 * Supports patterns like: {FunctionName(args)}
 * @param clipText - The raw clip text that may contain function calls
 * @returns Processed text with function calls replaced by their results
 */
ProcessDynamicClip(clipText) {
    result := clipText
    
    ; Match pattern: {FunctionName(args)} or {FunctionName()}
    pos := 1
    while (pos := RegExMatch(result, "\{(\w+)\(([^)]*)\)\}", &match, pos)) {
        funcName := match[1]
        funcArgs := match[2]
        
        ; Execute the appropriate function
        replacement := ""
        switch funcName {
            case "GetCurrentDate":
                replacement := GetCurrentDate(funcArgs)
            case "GetCurrentTime":
                replacement := GetCurrentTime(funcArgs)
            case "GetCurrentDateTime":
                replacement := GetCurrentDateTime(funcArgs)
            case "GetClipboard":
                replacement := A_Clipboard
            case "GetUsername":
                replacement := A_UserName
            case "GetComputerName":
                replacement := A_ComputerName
            default:
                ; Unknown function, leave as-is
                pos += StrLen(match[0])
                continue
        }
        
        ; Replace the match with the result
        result := SubStr(result, 1, pos - 1) . replacement . SubStr(result, pos + StrLen(match[0]))
        pos += StrLen(replacement)
    }
    
    return result
}

/**
 * Get the current date formatted according to the specified format
 * @param format - Date format string (e.g., "yyyy-MM-dd", "dd/MM/yyyy")
 * @returns Formatted date string
 */
GetCurrentDate(format := "yyyy-MM-dd") {
    if (format = "")
        format := "yyyy-MM-dd"
    return FormatTime(A_Now, format)
}

/**
 * Get the current time formatted according to the specified format
 * @param format - Time format string (e.g., "HH:mm:ss", "hh:mm tt")
 * @returns Formatted time string
 */
GetCurrentTime(format := "HH:mm:ss") {
    if (format = "")
        format := "HH:mm:ss"
    return FormatTime(A_Now, format)
}

/**
 * Get the current date and time formatted according to the specified format
 * @param format - DateTime format string (e.g., "yyyy-MM-dd HH:mm:ss")
 * @returns Formatted datetime string
 */
GetCurrentDateTime(format := "yyyy-MM-dd HH:mm:ss") {
    if (format = "")
        format := "yyyy-MM-dd HH:mm:ss"
    return FormatTime(A_Now, format)
}

; ============================================================
; Copy & Paste Functions
; ============================================================

CopyAndPasteItem(item) {
    global MyGui, LastActiveWindow, AutoPasteCheckbox
    
    ; Save values before destroying GUI
    shouldAutoPaste := AutoPasteCheckbox.Value
    targetWindow := LastActiveWindow
    
    ; Process dynamic functions in clip text
    A_Clipboard := ProcessDynamicClip(item.clip)
    NcDestroyGui()
    
    ; Auto-paste if enabled
    if (shouldAutoPaste && targetWindow) {
        try {
            WinActivate(targetWindow)
            Sleep(50)
            Send("^v")
        }
    }
}

CreateTabContent(tabName, x, y, lvWidth, lvHeight) {
    global MyGui, ContentPanels, TabData, CONFIG, LvByHwnd
    
    ; Create a ListView for this tab's content with absolute positioning
    lv := MyGui.Add("ListView", 
        "x" x " y" y " w" lvWidth " h" lvHeight " Background" CONFIG.bgColor " c" CONFIG.textColor " -Hdr +Report +LV0x10000",
        ["Clip", "Description"])
    
    lv.OnEvent("DoubleClick", OnItemDoubleClick)
    lv.OnEvent("Click", OnItemClick)
    
    ; Set column widths proportionally
    lv.ModifyCol(1, Integer(lvWidth * 0.48))
    lv.ModifyCol(2, Integer(lvWidth * 0.50))
    
    ContentPanels[tabName] := lv
    try LvByHwnd[lv.Hwnd] := lv
    
    ; Populate with items
    RefreshTabContent(tabName)
}

RegisterListViewHoverTooltips() {
    static registered := false
    if (registered)
        return
    registered := true
    CoordMode("Mouse", "Screen")
    OnMessage(0x200, OnNcMouseMove)  ; WM_MOUSEMOVE
}

OnNcMouseMove(wParam, lParam, msg, hwnd) {
    global MyGui, LvByHwnd, _NcHover
    if (MyGui = "")
        return

    guiHwnd := 0
    try guiHwnd := MyGui.Hwnd
    catch {
        NcClearHoverTooltip()
        MyGui := ""
        return
    }
    if (!guiHwnd || !WinExist("ahk_id " guiHwnd)) {
        NcClearHoverTooltip()
        MyGui := ""
        return
    }

    if !WinActive("ahk_id " guiHwnd) {
        if (_NcHover.active) {
            ToolTip()
            _NcHover.active := false
        }
        return
    }

    ; WM_MOUSEMOVE is received by the control currently under the cursor.
    ; Using lParam (client coords) keeps hit-testing in sync even when the ListView is scrolled/DPI scaled.
    if !LvByHwnd.Has(hwnd) {
        if (_NcHover.active) {
            ToolTip()
            _NcHover.active := false
        }
        return
    }

    lv := LvByHwnd[hwnd]
    x := NcSignedLoWord(lParam)
    y := NcSignedHiWord(lParam)
    hit := NcListViewHitTestClient(lv, x, y)
    row := hit.row
    col := hit.col
    if (row < 1 || col < 1) {
        if (_NcHover.active) {
            ToolTip()
            _NcHover.active := false
        }
        return
    }
    
    text := ""
    try text := lv.GetText(row, col)
    text := Trim(text)
    
    ; Skip group headers and empty cells.
    if (text = "" || SubStr(text, 1, 2) = "▸ ") {
        if (_NcHover.active) {
            ToolTip()
            _NcHover.active := false
        }
        return
    }
    
    ; Only update tooltip when hovering a different cell.
    if (_NcHover.active && _NcHover.hwnd = hwnd && _NcHover.row = row && _NcHover.col = col)
        return

    MouseGetPos(&mx, &my)
    ToolTip(text, mx + 18, my + 18)
    _NcHover.active := true
    _NcHover.hwnd := hwnd
    _NcHover.row := row
    _NcHover.col := col
}

NcSignedLoWord(value) {
    x := value & 0xFFFF
    return (x & 0x8000) ? (x - 0x10000) : x
}

NcSignedHiWord(value) {
    y := (value >> 16) & 0xFFFF
    return (y & 0x8000) ? (y - 0x10000) : y
}

NcListViewHitTestClient(lv, clientX, clientY) {
    static LVM_SUBITEMHITTEST := 0x1039
    ctrlHwnd := lv.Hwnd

    ; LVHITTESTINFO: POINT pt; UINT flags; int iItem; int iSubItem; (+ optional iGroup)
    info := Buffer(32, 0)
    NumPut("Int", clientX, info, 0)
    NumPut("Int", clientY, info, 4)
    
    itemIdx := SendMessage(LVM_SUBITEMHITTEST, 0, info.Ptr, ctrlHwnd)
    if (itemIdx < 0)
        return {row: 0, col: 0}
    
    ; LVHITTESTINFO.iSubItem is at offset 16 (pt=8, flags=4, iItem=4).
    subIdx := NumGet(info, 16, "Int")
    return {row: itemIdx + 1, col: subIdx + 1}
}

RefreshTabContent(tabName) {
    global ContentPanels, TabData, DisplayOrderItems
    
    if !ContentPanels.Has(tabName) || !TabData.Has(tabName)
        return
    
    lv := ContentPanels[tabName]
    lv.Delete()
    
    data := TabData[tabName]
    items := data.filteredItems
    
    ; Build display order (same logic as the display loop)
    displayItems := []
    
    ; Group items by group name
    groups := Map()
    ungrouped := []
    
    for item in items {
        groupName := item.group
        if (groupName = "") {
            ungrouped.Push(item)
        } else {
            if !groups.Has(groupName)
                groups[groupName] := []
            groups[groupName].Push(item)
        }
    }
    
    ; Get sorted group names
    groupNames := []
    for gn, _ in groups {
        groupNames.Push(gn)
    }
    groupNames := SortArray(groupNames)
    
    ; Build display order: grouped items first, then ungrouped
    for groupName in groupNames {
        for item in groups[groupName] {
            displayItems.Push(item)
        }
    }
    for item in ungrouped {
        displayItems.Push(item)
    }
    
    ; Store display order for this tab
    DisplayOrderItems[tabName] := displayItems
    
    ; Now render the ListView with index numbers
    entryNum := 0
    
    ; Add grouped items
    for groupName in groupNames {
        ; Add group header
        lv.Add("", "▸ " groupName, "", "")
        
        for item in groups[groupName] {
            entryNum++
            clipText := StrLen(item.clip) > 40 ? SubStr(item.clip, 1, 40) "..." : item.clip
            clipText := StrReplace(clipText, "`n", " ↵ ")
            
            ; Add index prefix for first 9 entries
            indexPrefix := entryNum <= 9 ? "[" entryNum "] " : "    "
            lv.Add("", indexPrefix clipText, item.description, "")
        }
    }
    
    ; Add ungrouped items
    if (ungrouped.Length > 0) {
        if (groupNames.Length > 0)
            lv.Add("", "▸ General", "", "")
        
        for item in ungrouped {
            entryNum++
            clipText := StrLen(item.clip) > 40 ? SubStr(item.clip, 1, 40) "..." : item.clip
            clipText := StrReplace(clipText, "`n", " ↵ ")
            
            ; Add index prefix for first 9 entries
            indexPrefix := entryNum <= 9 ? "[" entryNum "] " : "    "
            prefix := groupNames.Length > 0 ? "   " : ""
            lv.Add("", indexPrefix prefix clipText, item.description, "")
        }
    }
}

; ============================================================
; Event Handlers
; ============================================================

OnGuiResize(thisGui, MinMax, Width, Height) {
    global SearchEdit, TabControl, ContentPanels, AutoPasteCheckbox, SearchDescCheckbox, CONFIG
    
    if (MinMax = -1)  ; Window minimized
        return
    
    ; Suspend redrawing to prevent flashing
    for tabName, lv in ContentPanels {
        try SendMessage(0x000B, 0, 0, lv)  ; WM_SETREDRAW = FALSE
    }
    if (TabControl != "") {
        try SendMessage(0x000B, 0, 0, TabControl)  ; WM_SETREDRAW = FALSE
    }
    
    ; Update search bar width
    try SearchEdit.Move(,, Width - 350)
    
    ; Update checkbox positions
    try SearchDescCheckbox.Move(Width - 290)
    try AutoPasteCheckbox.Move(Width - 130)
    
    ; Calculate new positions
    tabY := CONFIG.padding + CONFIG.searchBarHeight + 10
    
    ; Update tab control size
    try TabControl.Move(,, Width - 2*CONFIG.padding, Height - tabY - CONFIG.padding)
    
    ; Update all ListViews
    tabContentY := tabY + 28
    lvWidth := Width - 2*CONFIG.padding - 15
    lvHeight := Height - tabContentY - CONFIG.padding - 10
    
    for tabName, lv in ContentPanels {
        try {
            lv.Move(,, lvWidth, lvHeight)
            lv.ModifyCol(1, Integer(lvWidth * 0.48))
            lv.ModifyCol(2, Integer(lvWidth * 0.50))
        }
    }
    
    ; Resume redrawing
    for tabName, lv in ContentPanels {
        try {
            SendMessage(0x000B, 1, 0, lv)  ; WM_SETREDRAW = TRUE
            WinRedraw(lv)
        }
    }
    if (TabControl != "") {
        try {
            SendMessage(0x000B, 1, 0, TabControl)  ; WM_SETREDRAW = TRUE
            WinRedraw(TabControl)
        }
    }
}

OnSearchChange(ctrl, *) {
    global TabData, SearchEdit, SearchDescCheckbox, ContentPanels, TabControl
    
    searchText := StrLower(Trim(SearchEdit.Value))
    searchInDesc := SearchDescCheckbox.Value
    
    ; Suspend redrawing while we repopulate ListViews & update tab captions.
    ; This prevents visible flashing/glitches when toggling search options.
    try {
        for _, lv in ContentPanels {
            try SendMessage(0x000B, 0, 0, lv)  ; WM_SETREDRAW = FALSE
        }
        if (TabControl != "") {
            try SendMessage(0x000B, 0, 0, TabControl)  ; WM_SETREDRAW = FALSE
        }
        
        for tabName, data in TabData {
            if (searchText = "") {
                data.filteredItems := data.items.Clone()
            } else {
                data.filteredItems := []
                tabNameLower := StrLower(tabName)
                
                for item in data.items {
                    ; Search in clip and group always, description only if checkbox is checked
                    found := InStr(StrLower(item.clip), searchText) ||
                             InStr(StrLower(item.group), searchText) ||
                             InStr(tabNameLower, searchText)
                    
                    ; Optionally search in descriptions
                    if (!found && searchInDesc) {
                        found := InStr(StrLower(item.description), searchText)
                    }
                    
                    if (found) {
                        data.filteredItems.Push(item)
                    }
                }
            }
            RefreshTabContent(tabName)
        }
        
        UpdateAllBadges()
    } finally {
        for _, lv in ContentPanels {
            try SendMessage(0x000B, 1, 0, lv)  ; WM_SETREDRAW = TRUE
            try WinRedraw(lv)
        }
        if (TabControl != "") {
            try SendMessage(0x000B, 1, 0, TabControl)  ; WM_SETREDRAW = TRUE
            try WinRedraw(TabControl)
        }
    }
}

OnSearchDescToggle(ctrl, *) {
    ; Re-run search with new setting
    OnSearchChange(ctrl)
}

OnTabChange(ctrl, *) {
    ; Tab changed - content is already rendered
}

OnItemClick(ctrl, rowNum) {
    if (rowNum = 0)
        return
    
    ; Get the clicked row text
    clipText := ctrl.GetText(rowNum, 1)
    
    ; Skip group headers
    if (SubStr(clipText, 1, 2) = "▸ ")
        return
    
    ; Find the actual item
    CopyItemByDisplayText(ctrl, clipText)
}

OnItemDoubleClick(ctrl, rowNum) {
    OnItemClick(ctrl, rowNum)
}

CopyItemByDisplayText(lv, displayText) {
    global TabData, TabOrder, TabControl, MyGui, LastActiveWindow, AutoPasteCheckbox
    
    ; Get current tab index and find the tab name from TabOrder
    tabIdx := TabControl.Value
    
    if (tabIdx < 1 || tabIdx > TabOrder.Length)
        return
    
    currentTab := TabOrder[tabIdx]
    items := TabData[currentTab].filteredItems
    
    ; Clean up display text for comparison
    displayText := Trim(displayText)
    
    ; Remove index prefix like "[1] " or "    " (4 spaces for non-indexed items)
    displayText := RegExReplace(displayText, "^\[\d+\]\s*", "")
    displayText := RegExReplace(displayText, "^\s+", "")  ; Remove leading spaces
    
    ; Find matching item by exact match
    for item in items {
        clipText := StrLen(item.clip) > 40 ? SubStr(item.clip, 1, 40) "..." : item.clip
        clipText := StrReplace(clipText, "`n", " ↵ ")
        
        ; Use exact string comparison instead of loose InStr matching
        if (displayText = clipText) {
            ; Save values before destroying GUI
            shouldAutoPaste := AutoPasteCheckbox.Value
            targetWindow := LastActiveWindow
            
            ; Process dynamic functions in clip text
            A_Clipboard := ProcessDynamicClip(item.clip)
            NcDestroyGui()
            
            ; Auto-paste if enabled
            if (shouldAutoPaste && targetWindow) {
                try {
                    WinActivate(targetWindow)
                    Sleep(50)
                    Send("^v")
                }
            }
            return
        }
    }
}

OnAutoPasteToggle(ctrl, *) {
    global CONFIG
    CONFIG.autoPaste := ctrl.Value
}

UpdateAllBadges() {
    global TabData, TabOrder, TabControl
    
    ; Update each tab's text to show filtered count using Windows API
    ; TCM_SETITEM = 0x1306, TCIF_TEXT = 0x0001
    static TCM_SETITEM := 0x133D  ; TCM_SETITEMW for Unicode
    static TCIF_TEXT := 0x0001
    
    tabIndex := 0
    for tabName in TabOrder {
        count := TabData[tabName].filteredItems.Length
        newTitle := tabName " (" count ")"
        
        ; Create TCITEM structure
        ; struct { UINT mask; DWORD dwState; DWORD dwStateMask; LPWSTR pszText; int cchTextMax; int iImage; LPARAM lParam; }
        tcItemSize := A_PtrSize * 3 + 4 * 4  ; Adjust for 32/64-bit
        tcItem := Buffer(tcItemSize, 0)
        
        ; Set mask to TCIF_TEXT
        NumPut("UInt", TCIF_TEXT, tcItem, 0)
        
        ; Set text pointer (offset depends on architecture)
        textOffset := 8 + A_PtrSize  ; After mask, dwState, dwStateMask
        NumPut("Ptr", StrPtr(newTitle), tcItem, textOffset)
        
        ; Send message to update tab text
        try SendMessage(TCM_SETITEM, tabIndex, tcItem.Ptr, TabControl)
        
        tabIndex++
    }
}

; ============================================================
; Utility Functions
; ============================================================

SortArray(arr) {
    ; Simple bubble sort for string array using StrCompare
    n := arr.Length
    Loop n - 1 {
        i := A_Index
        Loop n - i {
            j := A_Index
            if (StrCompare(arr[j], arr[j + 1]) > 0) {
                temp := arr[j]
                arr[j] := arr[j + 1]
                arr[j + 1] := temp
            }
        }
    }
    return arr
}
