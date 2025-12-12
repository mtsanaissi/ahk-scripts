; Simple YAML Parser for AHK v2
; Designed for parsing clip/cheatsheet configuration files
; Supports:
; - title, displayOrder
; - items:
;   - clip items: {clip, description, group?}
;   - group items: {group, items: [ {clip, description, group?}, ... ]}

class YamlParser {
    
    /**
     * Parse a YAML file and return a structured object
     * @param filePath - Path to the YAML file
     * @returns Object with title and items array
     */
    static ParseFile(filePath) {
        try {
            content := FileRead(filePath, "UTF-8")
            return this.Parse(content)
        } catch Error as err {
            return {title: "", items: [], error: err.Message}
        }
    }
    
    /**
     * Parse YAML text content
     * @param content - YAML text content
     * @returns Object with title and items array
     */
    static Parse(content) {
        result := {title: "", displayOrder: 999, items: []}
        lines := StrSplit(content, "`n", "`r")
        
        currentItem := ""            ; current top-level item
        currentItemType := ""        ; "unknown" | "clip" | "group"
        currentGroupItem := ""       ; current nested clip item inside a group
        inGroupItems := false
        inItems := false
        
        for lineNum, line in lines {
            ; Skip empty lines and comments
            trimmedLine := Trim(line)
            if (trimmedLine = "" || SubStr(trimmedLine, 1, 1) = "#")
                continue
            
            ; Calculate indentation level (2 spaces = 1 level)
            indent := this.GetIndentLevel(line)
            
            ; Parse title at root level
            if (indent = 0 && RegExMatch(trimmedLine, "i)^title:\s*(.*)$", &match)) {
                result.title := this.CleanValue(match[1])
                continue
            }
            
            ; Parse displayOrder at root level
            if (indent = 0 && RegExMatch(trimmedLine, "i)^displayOrder:\s*(.*)$", &match)) {
                result.displayOrder := Integer(this.CleanValue(match[1]))
                continue
            }
            
            ; Check for items array start
            if (indent = 0 && RegExMatch(trimmedLine, "i)^items:\s*$")) {
                inItems := true
                continue
            }
            
            ; Parse items
            if (inItems) {
                ; New item starts with "- "
                if (RegExMatch(trimmedLine, "^-\s*(.*)$", &match)) {
                    remaining := Trim(match[1])
                    
                    ; Top-level list item (under items:)
                    if (indent >= 1 && indent < 3) {
                        ; Finalize previous top-level item
                        if (currentItem != "") {
                            if (currentItemType = "group" && currentGroupItem != "") {
                                currentItem.items.Push(currentGroupItem)
                                currentGroupItem := ""
                            }
                            result.items.Push(currentItem)
                        }
                        
                        ; Start a new top-level item; decide its type from the first key.
                        currentItem := {clip: "", description: "", group: "", items: []}
                        currentItemType := "unknown"
                        inGroupItems := false
                        currentGroupItem := ""
                        
                        if (remaining != "") {
                            if (RegExMatch(remaining, "i)^group:\s*"))
                                currentItemType := "group"
                            else if (RegExMatch(remaining, "i)^clip:\s*"))
                                currentItemType := "clip"
                            this.ParseKeyValue(remaining, currentItem)
                        }
                        continue
                    }
                    
                    ; Nested list item inside a group items:
                    if (indent >= 3 && currentItemType = "group" && inGroupItems) {
                        if (currentGroupItem != "") {
                            currentItem.items.Push(currentGroupItem)
                        }
                        currentGroupItem := {clip: "", description: "", group: ""}
                        if (remaining != "")
                            this.ParseKeyValue(remaining, currentGroupItem)
                        continue
                    }
                }
                
                ; Group item: detect "items:" block, then parse nested clip properties.
                if (currentItemType = "group") {
                    if (indent = 2 && RegExMatch(trimmedLine, "i)^items:\s*$")) {
                        inGroupItems := true
                        continue
                    }
                    
                    if (inGroupItems) {
                        if (currentGroupItem != "" && indent >= 4) {
                            this.ParseKeyValue(trimmedLine, currentGroupItem)
                        }
                    } else {
                        ; Group header properties (e.g., group:)
                        if (currentItem != "" && indent >= 2) {
                            this.ParseKeyValue(trimmedLine, currentItem)
                        }
                    }
                } else {
                    ; Resolve unknown top-level item type based on first key line.
                    if (currentItemType = "unknown" && indent >= 2) {
                        if (RegExMatch(trimmedLine, "i)^group:\s*"))
                            currentItemType := "group"
                        else if (RegExMatch(trimmedLine, "i)^clip:\s*"))
                            currentItemType := "clip"
                    }
                    
                    if (currentItemType = "group") {
                        if (indent = 2 && RegExMatch(trimmedLine, "i)^items:\s*$")) {
                            inGroupItems := true
                            continue
                        }
                        if (inGroupItems) {
                            if (currentGroupItem != "" && indent >= 4) {
                                this.ParseKeyValue(trimmedLine, currentGroupItem)
                            }
                        } else if (currentItem != "" && indent >= 2) {
                            this.ParseKeyValue(trimmedLine, currentItem)
                        }
                        continue
                    }
                    
                    ; Clip item properties (indented under the dash)
                    if (currentItem != "" && indent >= 2) {
                        this.ParseKeyValue(trimmedLine, currentItem)
                    }
                }
            }
        }
        
        ; Don't forget the last item
        if (currentItem != "") {
            if (currentItemType = "group" && currentGroupItem != "") {
                currentItem.items.Push(currentGroupItem)
                currentGroupItem := ""
            }
            result.items.Push(currentItem)
        }
        
        return result
    }
    
    /**
     * Parse a key: value pair and add to object
     */
    static ParseKeyValue(line, obj) {
        if (RegExMatch(line, "i)^(clip|description|group):\s*(.*)$", &match)) {
            key := StrLower(match[1])
            value := this.CleanValue(match[2])
            obj.%key% := value
        }
    }
    
    /**
     * Get indentation level of a line
     */
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
    
    /**
     * Clean a value - remove quotes, trim whitespace
     */
    static CleanValue(value) {
        value := Trim(value)
        ; Remove surrounding quotes
        if ((SubStr(value, 1, 1) = '"' && SubStr(value, -1) = '"') ||
            (SubStr(value, 1, 1) = "'" && SubStr(value, -1) = "'")) {
            value := SubStr(value, 2, StrLen(value) - 2)
        }
        ; Handle escape sequences
        value := StrReplace(value, '\n', '`n')
        value := StrReplace(value, '\t', '`t')
        value := StrReplace(value, '\"', '"')
        value := StrReplace(value, "\'", "'")
        return value
    }
}
