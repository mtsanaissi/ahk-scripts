#Requires AutoHotkey v2.0

; Minimal YAML parser for ShortcutsHelper configuration files.
; Supports a small subset of YAML:
; - Root scalars: title, type, displayOrder
; - Nested maps/lists (2-space indentation)
; - Lists of maps and lists of scalars
; - Inline list items like: - key: value
;
; Notes:
; - Not a general-purpose YAML parser.
; - Designed to avoid executing/evaluating data; everything is treated as data.

class ShortcutsYamlParser {
    static ParseFile(filePath) {
        try {
            content := FileRead(filePath, "UTF-8")
            return this.Parse(content)
        } catch Error as err {
            return { error: err.Message }
        }
    }

    static Parse(content) {
        root := {}
        stack := [{ indent: -1, kind: "map", node: root }]
        lines := StrSplit(content, "`n", "`r")

        i := 1
        while (i <= lines.Length) {
            line := lines[i]
            trimmed := Trim(line)
            i += 1

            if (trimmed = "" || SubStr(trimmed, 1, 1) = "#")
                continue

            indent := this.GetIndentLevel(line)

            ; Unwind stack to parent with indent < current indent.
            while (stack.Length > 1 && indent <= stack[stack.Length].indent) {
                stack.Pop()
            }

            ctx := stack[stack.Length]

            if (RegExMatch(trimmed, "^-\\s*(.*)$", &mDash)) {
                if (ctx.kind != "list") {
                    ; Invalid structure for our subset; ignore line.
                    continue
                }

                rest := Trim(mDash[1])
                if (rest = "") {
                    item := {}
                    ctx.node.Push(item)
                    stack.Push({ indent: indent, kind: "map", node: item })
                    continue
                }

                if (RegExMatch(rest, "^([^:]+):\\s*(.*)$", &mInline)) {
                    item := {}
                    key := this.CleanKey(mInline[1])
                    valRaw := mInline[2]
                    if (valRaw = "") {
                        child := this.CreateContainerForNext(lines, i, indent)
                        item.%key% := child
                        ctx.node.Push(item)
                        stack.Push({ indent: indent, kind: "map", node: item })
                        stack.Push({ indent: indent + 1, kind: (Type(child) = "Array") ? "list" : "map", node: child })
                    } else {
                        item.%key% := this.ParseScalar(valRaw)
                        ctx.node.Push(item)
                        ; Keep the item on the stack so subsequent indented lines
                        ; (e.g. `items:` following `- name: ...`) attach to it.
                        stack.Push({ indent: indent, kind: "map", node: item })
                    }
                    continue
                }

                ; Scalar list item
                ctx.node.Push(this.ParseScalar(rest))
                continue
            }

            if (RegExMatch(trimmed, "^([^:]+):\\s*(.*)$", &mKv)) {
                if (ctx.kind != "map") {
                    ; Invalid structure for our subset; ignore line.
                    continue
                }

                key := this.CleanKey(mKv[1])
                valRaw := mKv[2]
                if (valRaw = "") {
                    child := this.CreateContainerForNext(lines, i, indent)
                    ctx.node.%key% := child
                    stack.Push({ indent: indent, kind: (Type(child) = "Array") ? "list" : "map", node: child })
                } else {
                    ctx.node.%key% := this.ParseScalar(valRaw)
                }
            }
        }

        return root
    }

    static CreateContainerForNext(lines, nextIndex, indent) {
        j := nextIndex
        while (j <= lines.Length) {
            t := Trim(lines[j])
            if (t = "" || SubStr(t, 1, 1) = "#") {
                j += 1
                continue
            }
            nextIndent := this.GetIndentLevel(lines[j])
            if (nextIndent <= indent)
                break
            if (RegExMatch(t, "^-\\s*"))
                return []
            return {}
        }
        return {}
    }

    static ParseScalar(raw) {
        v := Trim(raw)

        if ((SubStr(v, 1, 1) = '"' && SubStr(v, -1) = '"') || (SubStr(v, 1, 1) = "'" && SubStr(v, -1) = "'")) {
            v := SubStr(v, 2, StrLen(v) - 2)
        } else {
            ; Strip trailing comments like: 20  # comment
            hashPos := InStr(v, "#")
            if (hashPos > 1) {
                before := SubStr(v, 1, hashPos - 1)
                if (RegExMatch(before, "\s+$")) {
                    v := Trim(before)
                }
            }
        }

        if (RegExMatch(v, "^-?\\d+$"))
            return Integer(v)

        if (StrLower(v) = "true")
            return true
        if (StrLower(v) = "false")
            return false

        return v
    }

    static CleanKey(key) {
        return Trim(key)
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
