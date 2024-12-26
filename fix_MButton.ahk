#Requires AutoHotkey v2.0

; prevent accidental double mouse middle button activation
MButton::
{
    If (A_TimeSincePriorHotkey and A_TimeSincePriorHotkey < 300)
        Return
    Click "Middle"
}