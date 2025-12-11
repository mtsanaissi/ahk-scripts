; Simple YAML Parser for AHK v2
; Designed for parsing clip/cheatsheet configuration files
; Supports: title, items array with clip, description, group properties

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
        
        currentItem := ""
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
                if (RegExMatch(trimmedLine, "^-\s+(.*)$", &match)) {
                    ; Save previous item if exists
                    if (currentItem != "") {
                        result.items.Push(currentItem)
                    }
                    currentItem := {clip: "", description: "", group: ""}
                    
                    ; Check if there's inline content after the dash
                    remaining := Trim(match[1])
                    if (remaining != "") {
                        this.ParseKeyValue(remaining, currentItem)
                    }
                    continue
                }
                
                ; Item properties (indented under the dash)
                if (currentItem != "" && indent >= 2) {
                    this.ParseKeyValue(trimmedLine, currentItem)
                }
            }
        }
        
        ; Don't forget the last item
        if (currentItem != "") {
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
