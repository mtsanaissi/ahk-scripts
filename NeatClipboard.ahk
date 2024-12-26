#Requires AutoHotkey v2.0

; This script expects a CSV file named NeatClipboardConfig.csv in the same folder.
; The file should contain data for displaying buttons in the UI.
; Each row should be in the format
; "Button Text",RowNumber,ColumnNumber
; where "Button Text" will also be the text to be copied to clipboard,
; and RowNumber and ColumnNumber are positional arguments for the UI to
; arrange the buttons in a grid.

; Define a custom class for button configurations
class ButtonConfig {
    __New(text, row, column) {
        this.text := text
        this.row := row
        this.column := column
    }
}

#HotIf WinActive("A")  ; Only trigger the hotkey when a window is active

; Win + Alt + V hotkey
#!v::CreateGUI()

global maxRow := 0

CreateGUI() {
    global MyGui := Gui()
    MyGui.Title := "Neat Clipboard"
    MyGui.BackColor := "F0F0F0"

    global buttonWidth := 200
    global buttonHeight := 20
    global columnWidth := buttonWidth + 60  ; Increased to accommodate edit and delete buttons
    global rowHeight := buttonHeight + 5

    ; Read button configurations from CSV file
    global buttonConfigs := ReadButtonConfigsFromCSV("NeatClipboardConfig.csv")
    

    ; Check for duplicate row/column combinations
    if (HasDuplicateRowColumn(buttonConfigs)) {
        MsgBox("Error: CSV contains duplicate row/column combinations.")
        return
    }

    ; Create buttons based on CSV configuration
    for config in buttonConfigs {
        CreateButtonGroup(config.text, (config.column - 1) * columnWidth + 10, (config.row - 1) * rowHeight + 10)
    }

    ; Add button for new text
    ;maxIndex := buttonConfigs.Length() - 1
    addBtn := MyGui.Add("Button", "x10 y" . (maxRow * rowHeight + 20) . " w100 h20", "➕ Add Text")
    addBtn.OnEvent("Click", (*) => AddButtonClick())

    MyGui.Show()
}

HasDuplicateRowColumn(buttonConfigs) {
    for i, config1 in buttonConfigs {
        for j, config2 in buttonConfigs {
            if (i != j && config1.row == config2.row && config1.column == config2.column) {
                return true
            }
        }
    }
    return false
}

CreateButtonGroup(text, x, y) {
    btn := MyGui.Add("Button", Format("x{} y{} w{} h{}", x, y, buttonWidth, buttonHeight), text)
    btn.OnEvent("Click", ButtonClick)

    editBtn := MyGui.Add("Button", Format("x{} y{} w20 h{}", x + buttonWidth + 3, y, buttonHeight), "✏️")
    editBtn.OnEvent("Click", (*) => EditButtonClick(text))

    editBtn.GetPos(&editBtnX, &editBtnY, &editBtnW, &editBtnH)
    deleteBtn := MyGui.Add("Button", Format("x{} y{} w20 h{}", editBtnX + editBtnW + 3, y, buttonHeight), "🗑️")
    deleteBtn.OnEvent("Click", (*) => DeleteButtonClick(text))
}

ButtonClick(sender, info)
{
    btnText := sender.Text
    A_Clipboard := btnText
    sender.Gui.Hide()
    Send "^v"
}

EditButtonClick(text)
{
    editGui := Gui()
    editGui.Title := "Edit Text"
    editGui.Add("Text", "x10 y10", "Edit the text:")
    editBox := editGui.Add("Edit", "x10 y30 w300 h100 vEditedText", text)
    saveBtn := editGui.Add("Button", "x10 y140 w100", "Save")
    saveBtn.OnEvent("Click", (*) => SaveEditedText(editGui, text))
    editGui.Show()
}

SaveEditedText(editGui, oldText)
{
    newText := editGui.Submit().EditedText
    UpdateCSVEntry(oldText, newText)
    editGui.Destroy()
    RefreshGUI()
}

DeleteButtonClick(text)
{
    result := MsgBox("Are you sure you want to delete this entry?", "Confirm Deletion", 4)
    if (result == "Yes") {
        DeleteCSVEntry(text)
        RefreshGUI()
    }
}

AddButtonClick()
{
    addGui := Gui()
    addGui.Title := "Add New Text"
    addGui.Add("Text", "x10 y10", "Text:")
    textBox := addGui.Add("Edit", "x10 y30 w300 h20 vNewText")
    addGui.Add("Text", "x10 y60", "Row:")
    rowBox := addGui.Add("Edit", "x10 y80 w50 h20 vNewRow")
    addGui.Add("Text", "x10 y110", "Column:")
    columnBox := addGui.Add("Edit", "x10 y130 w50 h20 vNewColumn")
    saveBtn := addGui.Add("Button", "x10 y160 w100", "Save")
    saveBtn.OnEvent("Click", (*) => SaveNewText(addGui))
    addGui.Show()
}

SaveNewText(addGui)
{
    newText := addGui.Submit().NewText
    newRow := addGui.Submit().NewRow
    newColumn := addGui.Submit().NewColumn

    ; Basic validation
    if (newText == "" || newRow == "" || newColumn == "") {
        MsgBox("Please fill in all fields.")
        return
    }

    AppendToCSV(newText, newRow, newColumn)
    addGui.Destroy()
    RefreshGUI()
}

UpdateCSVEntry(oldText, newText)
{
    fileContent := FileRead("NeatClipboardConfig.csv")
    lines := StrSplit(fileContent, "`n", "`r")
    newLines := []

    for line in lines {
        if (line != "") {
            fields := StrSplit(line, ",")
            if (fields.Length >= 3 && Trim(fields[1], '`"') == oldText) {
                newLines.Push("`"" . newText . "`"," . fields[2] . "," . fields[3])
            } else {
                newLines.Push(line)
            }
        }
    }

    FileDelete("NeatClipboardConfig.csv")
    FileAppend(StrJoin(newLines, "`n"), "NeatClipboardConfig.csv", "UTF-8")
}

DeleteCSVEntry(text)
{
    fileContent := FileRead("NeatClipboardConfig.csv")
    lines := StrSplit(fileContent, "`n", "`r")
    newLines := []

    for line in lines {
        if (line != "") {
            fields := StrSplit(line, ",")
            if (fields.Length >= 3 && Trim(fields[1], '`"') != text) {
                newLines.Push(line)
            }
        }
    }

    FileDelete("NeatClipboardConfig.csv")
    FileAppend(StrJoin(newLines, "`n"), "NeatClipboardConfig.csv", "UTF-8")
}

AppendToCSV(text, row, column)
{
    FileAppend("`n`"" . text . "`"," . row . "," . column, "NeatClipboardConfig.csv", "UTF-8")
}

RefreshGUI()
{
    if (IsSet(MyGui)) {
        MyGui.Destroy()
    }
    CreateGUI()
}

ReadButtonConfigsFromCSV(filename)
{
    buttonConfigs := []
    global maxRow

    try {
        fileContent := FileRead(filename)
        lines := StrSplit(fileContent, "`n", "`r")
        
        for line in lines {
            if (line != "") {
                fields := StrSplit(line, ",")
                if (fields.Length >= 3) {
                    text := ProcessText(Trim(fields[1], '`"'))
                    row := Integer(fields[2])
                    column := Integer(fields[3])
                    buttonConfigs.Push(ButtonConfig(text, row, column))

                    if (row > maxRow)
                        maxRow := row
                }
            }
        }
    } catch Error as err {
        MsgBox("Error reading CSV file: " . err.Message)
    }
    
    return buttonConfigs
}

ProcessText(text)
{
    if (RegExMatch(text, "s){GetCurrentDate\((.*?)\)}", &match)) {
        format := match[1]  ; Extract the format from the match
        date := GetCurrentDate(format)
        ; Replace the {GetCurrentDate(format)} with the actual date
        return StrReplace(text, match[0], date)
    }
    return text
}

GetCurrentDate(format) {
    return FormatTime(A_Now, format)
}

StrJoin(array, separator) {
    result := ""
    for index, element in array {
        if (index > 1) {
            result .= separator
        }
        result .= element
    }
    return result
}