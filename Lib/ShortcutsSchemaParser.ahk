#Requires AutoHotkey v2.0

; Parser for the specific YAML subset used by ShortcutsHelper.
; This is intentionally schema-driven (not a general YAML parser).
;
; Supported (root):
; - title: string
; - type: "global" | "app"
; - displayOrder: number
; - match: { exe|class|titleRegex|titleContains : scalar | list }
; - groups: [ { name, items:[{keys,desc}] } ]   (for apps)
; - items:  [ { group, items:[{keys,desc}] } ]  (for globals)
; - items:  [ { keys, desc, group? } ]          (for apps or simple files)

class ShortcutsSchemaParser {
    static ParseFile(filePath) {
        try {
            return this.Parse(FileRead(filePath, "UTF-8"))
        } catch Error as err {
            return { error: err.Message }
        }
    }

    static Parse(content) {
        obj := {}
        obj.__parser := "schema"
        seenRootKeys := []
        obj.title := ""
        obj.type := "app"
        obj.displayOrder := 999

        match := {}
        matchHasAny := false
        groups := []
        items := []

        ; State
        inMatch := false
        matchIndent := 0
        matchListKey := ""
        matchListIndent := 0

        inGroups := false
        groupsIndent := 0
        currentGroup := 0

        inItems := false
        itemsIndent := 0
        currentContainer := 0
        inItemsDirect := false

        currentShortcut := 0
        currentShortcutIndent := 0

        lines := StrSplit(content, "`n", "`r")
        for _, rawLine in lines {
            line := rawLine
            trimmed := Trim(line)

            if (trimmed = "" || SubStr(trimmed, 1, 1) = "#")
                continue

            indent := this.GetIndentLevel(line)

            ; Leaving blocks when indentation decreases.
            if (inMatch && indent <= matchIndent) {
                inMatch := false
                matchListKey := ""
            }
            if (inGroups && indent <= groupsIndent) {
                inGroups := false
                currentGroup := 0
                currentShortcut := 0
            }
            if (inItems && indent <= itemsIndent) {
                inItems := false
                currentContainer := 0
                currentShortcut := 0
                inItemsDirect := false
            }

            ; Root keys
            if (indent = 0 && RegExMatch(trimmed, "^([^:]+):\s*(.*)$", &mRoot)) {
                key := StrLower(Trim(mRoot[1]))
                valRaw := Trim(mRoot[2])
                seenRootKeys.Push(key)

                if (key = "match") {
                    inMatch := true
                    matchIndent := indent
                    matchListKey := ""
                    continue
                }
                if (key = "groups") {
                    inGroups := true
                    groupsIndent := indent
                    currentGroup := 0
                    continue
                }
                if (key = "items") {
                    inItems := true
                    itemsIndent := indent
                    currentContainer := 0
                    continue
                }

                if (key = "title") {
                    obj.title := this.ParseScalar(valRaw)
                    continue
                }
                if (key = "type") {
                    obj.type := StrLower(this.ParseScalar(valRaw))
                    continue
                }
                if (key = "displayorder") {
                    obj.displayOrder := this.ParseNumberOrDefault(valRaw, 999)
                    continue
                }

                continue
            }

            ; match:
            if (inMatch) {
                if (indent = matchIndent + 1 && RegExMatch(trimmed, "^([^:]+):\s*(.*)$", &mMatch)) {
                    mKey := Trim(mMatch[1])
                    mVal := Trim(mMatch[2])
                    mKeyLower := StrLower(mKey)

                    if (mVal = "") {
                        match.%mKeyLower% := []
                        matchListKey := mKeyLower
                        matchListIndent := indent
                        matchHasAny := true
                    } else {
                        match.%mKeyLower% := this.ParseScalar(mVal)
                        matchListKey := ""
                        matchHasAny := true
                    }
                    continue
                }

                if (matchListKey != "" && indent = matchListIndent + 1 && RegExMatch(trimmed, "^-\s*(.*)$", &mList)) {
                    match.%matchListKey%.Push(this.ParseScalar(Trim(mList[1])))
                    continue
                }
            }

            ; groups: (apps)
            if (inGroups) {
                if (indent = groupsIndent + 1 && RegExMatch(trimmed, "^-\s*(.*)$", &mDash)) {
                    currentGroup := { name: "", items: [] }
                    groups.Push(currentGroup)

                    rest := Trim(mDash[1])
                    if (RegExMatch(rest, "^name:\s*(.*)$", &mName)) {
                        currentGroup.name := this.ParseScalar(Trim(mName[1]))
                    }
                    currentShortcut := 0
                    continue
                }

                if (currentGroup && indent = groupsIndent + 2 && RegExMatch(trimmed, "^name:\s*(.*)$", &mName2)) {
                    currentGroup.name := this.ParseScalar(Trim(mName2[1]))
                    continue
                }

                if (currentGroup && indent = groupsIndent + 2 && RegExMatch(trimmed, "^items:\s*$")) {
                    ; enter group items list; actual items are parsed below
                    continue
                }

                ; Shortcut list items inside group
                if (currentGroup && indent = groupsIndent + 3 && RegExMatch(trimmed, "^-\s*(.*)$", &mItemDash)) {
                    currentShortcut := { keys: "", desc: "" }
                    currentShortcutIndent := indent
                    currentGroup.items.Push(currentShortcut)

                    rest := Trim(mItemDash[1])
                    if (RegExMatch(rest, "^keys:\s*(.*)$", &mKeys)) {
                        currentShortcut.keys := this.ParseScalar(Trim(mKeys[1]))
                    }
                    if (RegExMatch(rest, "^desc:\s*(.*)$", &mDesc)) {
                        currentShortcut.desc := this.ParseScalar(Trim(mDesc[1]))
                    }
                    continue
                }

                if (currentShortcut && indent >= currentShortcutIndent + 1 && RegExMatch(trimmed, "^([^:]+):\s*(.*)$", &mItemKv)) {
                    k := StrLower(Trim(mItemKv[1]))
                    v := this.ParseScalar(Trim(mItemKv[2]))
                    if (k = "keys")
                        currentShortcut.keys := v
                    else if (k = "desc" || k = "description")
                        currentShortcut.desc := v
                    continue
                }
            }

            ; items: (globals)
            if (inItems) {
                if (indent = itemsIndent + 1 && RegExMatch(trimmed, "^-\s*(.*)$", &mDash2)) {
                    rest := Trim(mDash2[1])
                    ; Support two shapes:
                    ; 1) container: - group: X \n   items: \n     - keys: ... \n       desc: ...
                    ; 2) direct:    - keys: ... \n   desc: ... \n   group: ...?
                    if (RegExMatch(rest, "^(keys|desc|description):\s*(.*)$", &mDirectFirst)) {
                        currentContainer := 0
                        inItemsDirect := true
                        currentShortcut := { keys: "", desc: "", group: "" }
                        currentShortcutIndent := indent
                        items.Push(currentShortcut)

                        firstKey := StrLower(Trim(mDirectFirst[1]))
                        firstVal := this.ParseScalar(Trim(mDirectFirst[2]))
                        if (firstKey = "keys")
                            currentShortcut.keys := firstVal
                        else
                            currentShortcut.desc := firstVal
                        continue
                    }

                    inItemsDirect := false
                    currentContainer := { group: "", items: [] }
                    items.Push(currentContainer)

                    if (RegExMatch(rest, "^group:\s*(.*)$", &mGroup)) {
                        currentContainer.group := this.ParseScalar(Trim(mGroup[1]))
                    }
                    currentShortcut := 0
                    continue
                }

                if (inItemsDirect && currentShortcut && indent >= currentShortcutIndent + 1 && RegExMatch(trimmed, "^([^:]+):\s*(.*)$", &mDirectKv)) {
                    k := StrLower(Trim(mDirectKv[1]))
                    v := this.ParseScalar(Trim(mDirectKv[2]))
                    if (k = "keys")
                        currentShortcut.keys := v
                    else if (k = "desc" || k = "description")
                        currentShortcut.desc := v
                    else if (k = "group")
                        currentShortcut.group := v
                    continue
                }

                if (currentContainer && indent = itemsIndent + 2 && RegExMatch(trimmed, "^group:\s*(.*)$", &mGroup2)) {
                    currentContainer.group := this.ParseScalar(Trim(mGroup2[1]))
                    continue
                }

                if (currentContainer && indent = itemsIndent + 2 && RegExMatch(trimmed, "^items:\s*$")) {
                    continue
                }

                if (currentContainer && indent = itemsIndent + 3 && RegExMatch(trimmed, "^-\s*(.*)$", &mItemDash2)) {
                    currentShortcut := { keys: "", desc: "" }
                    currentShortcutIndent := indent
                    currentContainer.items.Push(currentShortcut)

                    rest := Trim(mItemDash2[1])
                    if (RegExMatch(rest, "^keys:\s*(.*)$", &mKeys2)) {
                        currentShortcut.keys := this.ParseScalar(Trim(mKeys2[1]))
                    }
                    if (RegExMatch(rest, "^desc:\s*(.*)$", &mDesc2)) {
                        currentShortcut.desc := this.ParseScalar(Trim(mDesc2[1]))
                    }
                    continue
                }

                if (currentShortcut && indent >= currentShortcutIndent + 1 && RegExMatch(trimmed, "^([^:]+):\s*(.*)$", &mItemKv2)) {
                    k := StrLower(Trim(mItemKv2[1]))
                    v := this.ParseScalar(Trim(mItemKv2[2]))
                    if (k = "keys")
                        currentShortcut.keys := v
                    else if (k = "desc" || k = "description")
                        currentShortcut.desc := v
                    continue
                }
            }
        }

        obj.__rootKeys := seenRootKeys
        obj.match := match
        obj.groups := groups
        obj.items := items

        return obj
    }

    static ParseNumberOrDefault(raw, defaultValue := 0) {
        v := this.StripTrailingComment(Trim(raw))
        if (RegExMatch(v, "^-?\d+$"))
            return Integer(v)
        return defaultValue
    }

    static ParseScalar(raw) {
        v := this.StripTrailingComment(Trim(raw))
        if ((SubStr(v, 1, 1) = '"' && SubStr(v, -1) = '"') || (SubStr(v, 1, 1) = "'" && SubStr(v, -1) = "'")) {
            v := SubStr(v, 2, StrLen(v) - 2)
        }
        return v
    }

    static StripTrailingComment(v) {
        if (v = "")
            return ""
        if (SubStr(v, 1, 1) = '"' || SubStr(v, 1, 1) = "'")
            return v
        hashPos := InStr(v, "#")
        if (hashPos > 1) {
            before := SubStr(v, 1, hashPos - 1)
            if (RegExMatch(before, "\s+$"))
                return Trim(before)
        }
        return v
    }

    static GetIndentLevel(line) {
        spaces := 0
        Loop Parse, line {
            if (A_LoopField = " ")
                spaces++
            else if (A_LoopField = "`t")
                spaces += 2
            else
                break
        }
        return spaces // 2
    }
}
