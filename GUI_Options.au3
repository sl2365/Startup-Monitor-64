; GUI_Options.au3

#include-once
#include <GUIConstantsEx.au3>
#include <EditConstants.au3>
#include <StaticConstants.au3>
#include <ButtonConstants.au3>

Global $g_OptionsControls[11] ; Increased size for new controls
Global $g_OptionsMsgPanel = 0
Global $g_OptionsMsgLabel = 0
Global $g_OptionsMsgOk = 0
Global $g_OptionsMsgCancel = 0

; =================================================================
; OPTIONS TAB CREATION
; =================================================================
Func GUIOptionsCreate($parentGUI, $x, $y, $width, $height, ByRef $settingsDict)
    Local $controls[11]
    Local $curY = $y

    ; Monitor Time setting
    GUICtrlCreateLabel("Monitor Interval:", $x + 10, $curY + 20, 100, 20)
    $controls[0] = GUICtrlCreateInput("", $x + 140, $curY + 16, 60, 20, $ES_NUMBER)
    GUICtrlCreateLabel("Range: 1000-60000ms (1-60 sec)", $x + 220, $curY + 20, 200, 20)

    ; Clear Log on Start
    $controls[1] = GUICtrlCreateCheckbox("Clear log file start", $x + 10, $curY + 60, 100, 20)
    GUICtrlCreateLabel("(Creates new log file on each start)", $x + 30, $curY + 80, 400, 20)

    ; Persistent Baseline
    $controls[2] = GUICtrlCreateCheckbox("Create persistent baseline (recommended)", $x + 10, $curY + 110, 220, 20)
    GUICtrlCreateLabel("(Creates baseline of existing startup items on first run to reduce false alerts)", $x + 30, $curY + 130, 400, 20)

    ; Monitor Tasks
    $controls[3] = GUICtrlCreateCheckbox("Monitor scheduled tasks", $x + 10, $curY + 160, 130, 20)
    GUICtrlCreateLabel("(Includes Windows scheduled tasks in monitoring)", $x + 30, $curY + 180, 400, 20)

    ; Monitor Registry
    $controls[4] = GUICtrlCreateCheckbox("Monitor registry startup locations", $x + 10, $curY + 210, 170, 20)
    GUICtrlCreateLabel("(Monitors registry keys for startup programs)", $x + 30, $curY + 230, 400, 20)

    ; Review Window Width/Height
    GUICtrlCreateLabel("Review Window Width:", $x + 10, $curY + 260, 120, 20)
    $controls[6] = GUICtrlCreateInput("", $x + 140, $curY + 256, 60, 20, $ES_NUMBER)
    GUICtrlCreateLabel("Review Window Height:", $x + 10, $curY + 290, 160, 20)
    $controls[7] = GUICtrlCreateInput("", $x + 140, $curY + 286, 60, 20, $ES_NUMBER)

    ; Reset to defaults button
    $controls[5] = GUICtrlCreateButton("Reset to Defaults", $x + 10, $curY + 400, 100, 30)
    $controls[8] = GUICtrlCreateButton("Settings Folder", $x + 10, $curY + 440, 100, 30)

    ; Message panel controls (hidden by default)
    $controls[9] = GUICtrlCreateLabel("", $x + 130, $curY + 400, 250, 30, $SS_CENTER)
    GUICtrlSetColor($controls[9], 0xAA0000)
    GUICtrlSetFont($controls[9], 10, 700)
    GUICtrlSetState($controls[9], $GUI_HIDE)
    $controls[10] = GUICtrlCreateButton("OK", $x + 190, $curY + 440, 60, 20, $BS_DEFPUSHBUTTON)
    GUICtrlSetState($controls[10], $GUI_HIDE)
    $g_OptionsMsgPanel = $controls[9]
    $g_OptionsMsgOk = $controls[10]
    $g_OptionsMsgCancel = GUICtrlCreateButton("Cancel", $x + 260, $curY + 440, 60, 20)
    GUICtrlSetState($g_OptionsMsgCancel, $GUI_HIDE)

    ; Load current values into controls
    _OptionsLoadValues($controls, $settingsDict)

    ; Store controls globally (optional, if used elsewhere)
    For $i = 0 To UBound($controls) - 1
        $g_OptionsControls[$i] = $controls[$i]
    Next

    Return $controls
EndFunc

; =================================================================
; OPTIONS TAB MESSAGE HANDLING
; =================================================================
Func GUIOptionsHandleMessage($msg, $controls, ByRef $settingsDict)
    If Not IsArray($controls) Or UBound($controls) < 11 Then Return

    Switch $msg
        Case $controls[0] ; Monitor Time changed
            Local $value = GUICtrlRead($controls[0])
            If $value <> "" And IsNumber($value) Then
                If $value >= 1000 And $value <= 60000 Then
                    $settingsDict.Item("MonitorTime") = String($value)
                    ConfigSaveSettings($settingsDict)
                Else
                    MsgBox(48, "Invalid Value", "Monitor interval must be between 1000 and 60000 milliseconds.")
                    Local $currentValue = $settingsDict.Exists("MonitorTime") ? $settingsDict.Item("MonitorTime") : "3000"
                    GUICtrlSetData($controls[0], $currentValue)
                EndIf
            EndIf

        Case $controls[1] ; Clear Log on Start
            Local $checked = (GUICtrlRead($controls[1]) = 1)
            $settingsDict.Item("ClearLogOnStart") = $checked ? "1" : "0"
            ConfigSaveSettings($settingsDict)

        Case $controls[2] ; Persistent Baseline
            Local $checked = (GUICtrlRead($controls[2]) = 1)
            $settingsDict.Item("PersistentBaseline") = $checked ? "1" : "0"
            ConfigSaveSettings($settingsDict)

        Case $controls[3] ; Monitor Tasks
            Local $checked = (GUICtrlRead($controls[3]) = 1)
            $settingsDict.Item("MonitorTasks") = $checked ? "1" : "0"
            ConfigSaveSettings($settingsDict)

        Case $controls[4] ; Monitor Registry
            Local $checked = (GUICtrlRead($controls[4]) = 1)
            $settingsDict.Item("Registry") = $checked ? "1" : "0"
            ConfigSaveSettings($settingsDict)

        Case $controls[5] ; Reset to Defaults Button
            _OptionsShowResetConfirmPanel($controls)

        Case $controls[6] ; ReviewWindowWidth changed
            Local $widthVal = GUICtrlRead($controls[6])
            If $widthVal <> "" And IsNumber($widthVal) Then
                If $widthVal >= 400 And $widthVal <= 1600 Then
                    $settingsDict.Item("ReviewWindowWidth") = String($widthVal)
                    ConfigSaveSettings($settingsDict)
                Else
                    MsgBox(48, "Invalid Value", "Review window width must be between 400 and 1600 pixels.")
                    Local $currentValue = $settingsDict.Exists("ReviewWindowWidth") ? $settingsDict.Item("ReviewWindowWidth") : "800"
                    GUICtrlSetData($controls[6], $currentValue)
                EndIf
            EndIf

        Case $controls[7] ; ReviewWindowHeight changed
            Local $heightVal = GUICtrlRead($controls[7])
            If $heightVal <> "" And IsNumber($heightVal) Then
                If $heightVal >= 200 And $heightVal <= 900 Then
                    $settingsDict.Item("ReviewWindowHeight") = String($heightVal)
                    ConfigSaveSettings($settingsDict)
                Else
                    MsgBox(48, "Invalid Value", "Review window height must be between 200 and 900 pixels.")
                    Local $currentValue = $settingsDict.Exists("ReviewWindowHeight") ? $settingsDict.Item("ReviewWindowHeight") : "400"
                    GUICtrlSetData($controls[7], $currentValue)
                EndIf
            EndIf

        Case $controls[8] ; Open Settings Folder
            _OpenSettingsFolder()

        Case $controls[10] ; OK clicked in message panel
            _OptionsHideResetConfirmPanel($controls)
            _OptionsResetToDefaults($controls, $settingsDict)

        Case $g_OptionsMsgCancel ; Cancel clicked in message panel
            _OptionsHideResetConfirmPanel($controls)
    EndSwitch
EndFunc

; =================================================================
; OPTIONS TAB HELPER FUNCTIONS
; =================================================================
Func _OptionsLoadValues($controls, $settingsDict)
    If Not IsObj($settingsDict) Or Not IsArray($controls) Then Return

    ; Monitor Time
    Local $monitorTime = $settingsDict.Exists("MonitorTime") ? $settingsDict.Item("MonitorTime") : "3000"
    GUICtrlSetData($controls[0], $monitorTime)
    ; Clear Log on Start
    Local $clearLog = $settingsDict.Exists("ClearLogOnStart") ? $settingsDict.Item("ClearLogOnStart") : "0"
    GUICtrlSetState($controls[1], ($clearLog = "1") ? $GUI_CHECKED : $GUI_UNCHECKED)
    ; Persistent Baseline
    Local $persistentBaseline = $settingsDict.Exists("PersistentBaseline") ? $settingsDict.Item("PersistentBaseline") : "1"
    GUICtrlSetState($controls[2], ($persistentBaseline = "1") ? $GUI_CHECKED : $GUI_UNCHECKED)
    ; Monitor Tasks
    Local $monitorTasks = $settingsDict.Exists("MonitorTasks") ? $settingsDict.Item("MonitorTasks") : "1"
    GUICtrlSetState($controls[3], ($monitorTasks = "1") ? $GUI_CHECKED : $GUI_UNCHECKED)
    ; Monitor Registry
    Local $monitorRegistry = $settingsDict.Exists("Registry") ? $settingsDict.Item("Registry") : "1"
    GUICtrlSetState($controls[4], ($monitorRegistry = "1") ? $GUI_CHECKED : $GUI_UNCHECKED)
    ; Review Window Width
    Local $reviewWidth = $settingsDict.Exists("ReviewWindowWidth") ? $settingsDict.Item("ReviewWindowWidth") : "800"
    GUICtrlSetData($controls[6], $reviewWidth)
    ; Review Window Height
    Local $reviewHeight = $settingsDict.Exists("ReviewWindowHeight") ? $settingsDict.Item("ReviewWindowHeight") : "400"
    GUICtrlSetData($controls[7], $reviewHeight)
EndFunc

Func _OptionsResetToDefaults($controls, ByRef $settingsDict)
    ; Reset all values to defaults
    GUICtrlSetData($controls[0], "3000")
    GUICtrlSetState($controls[1], $GUI_UNCHECKED)
    GUICtrlSetState($controls[2], $GUI_CHECKED)
    GUICtrlSetState($controls[3], $GUI_CHECKED)
    GUICtrlSetState($controls[4], $GUI_CHECKED)
    GUICtrlSetData($controls[6], "800")
    GUICtrlSetData($controls[7], "400")
    ; Update settings dictionary
    $settingsDict.Item("MonitorTime") = "3000"
    $settingsDict.Item("ClearLogOnStart") = "0"
    $settingsDict.Item("PersistentBaseline") = "1"
    $settingsDict.Item("MonitorTasks") = "1"
    $settingsDict.Item("Registry") = "1"
    $settingsDict.Item("ReviewWindowWidth") = "800"
    $settingsDict.Item("ReviewWindowHeight") = "400"
    ; Save to file
    ConfigSaveSettings($settingsDict)
    EngineLogWrite("SETTINGS", "options", "reset_defaults", "all_settings", "RESET_TO_DEFAULTS")
EndFunc

Func _OpenSettingsFolder()
    ShellExecute(@ScriptDir & "\App")
EndFunc

; =================================================================
; OPTIONS TAB CONFIRMATION PANEL HANDLING
; =================================================================
Func _OptionsShowResetConfirmPanel($controls)
    GUICtrlSetData($controls[9], "Are you sure you want to reset all settings to default values?")
    GUICtrlSetState($controls[9], $GUI_SHOW)
    GUICtrlSetState($controls[10], $GUI_SHOW)
    GUICtrlSetState($g_OptionsMsgCancel, $GUI_SHOW)
EndFunc

Func _OptionsHideResetConfirmPanel($controls)
    GUICtrlSetState($controls[9], $GUI_HIDE)
    GUICtrlSetState($controls[10], $GUI_HIDE)
    GUICtrlSetState($g_OptionsMsgCancel, $GUI_HIDE)
EndFunc
