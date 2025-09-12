; GUI_Settings.au3

#include-once
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <TabConstants.au3>
#include "Config.au3"
#include "GUI_Locations.au3"
#include "GUI_Allowed.au3"
#include "GUI_Denied.au3"
#include "GUI_BaseStartup.au3"
#include "GUI_BaseTasks.au3"
#include "GUI_Options.au3"
#include "GUI_Log.au3"
#include "GUI_About.au3"

Global $g_SettingsGUI = 0
Global $g_SettingsTab = 0
Global $g_TabHandles[8]
Global $g_SettingsApplyBtn = 0
Global $g_SettingsCloseBtn = 0
Global $g_LastBaseStartupSelected = -1
Global $g_MaxLineLen = 90 ; <-- define line length once

; =================================================================
; MAIN SETTINGS GUI FUNCTION
; =================================================================
Func GUIShowSettings(ByRef $settingsDict, ByRef $foldersDict, ByRef $regTokensDict, _
    ByRef $allowedDict, ByRef $deniedDict, ByRef $baseFoldersDict, ByRef $baseRegDict, ByRef $baseTasksDict)

    Local $width = 800
    Local $height = 600
	
    $g_SettingsGUI = GUICreate("Startup Monitor - Settings", $width, $height, -1, -1, _
        BitOR($WS_CAPTION, $WS_SYSMENU, $WS_MINIMIZEBOX), $WS_EX_TOPMOST)
    $g_SettingsTab = GUICtrlCreateTab(10, 10, $width - 20, $height - 60)

    GUICtrlCreateTabItem("Options")
    $g_TabHandles[0] = GUIOptionsCreate($g_SettingsGUI, 20, 40, $width - 40, $height - 110, $settingsDict)
    GUICtrlCreateTabItem("Locations")
    $g_TabHandles[1] = GUILocationsCreate($g_SettingsGUI, 20, 40, $width - 40, $height - 110, $foldersDict, $regTokensDict)
    GUICtrlCreateTabItem("Allowed")
    $g_TabHandles[2] = GUIAllowedCreate($g_SettingsGUI, 20, 40, $width - 40, $height - 110, $allowedDict)
    GUICtrlCreateTabItem("Denied")
    $g_TabHandles[3] = GUIDeniedCreate($g_SettingsGUI, 20, 40, $width - 40, $height - 110, $deniedDict)
    GUICtrlCreateTabItem("Base Startup")
    $g_TabHandles[4] = GUIBaseStartupCreate($g_SettingsGUI, 20, 40, $width - 40, $height - 110, $baseFoldersDict, $baseRegDict)
    GUICtrlCreateTabItem("Base Tasks")
    $g_TabHandles[5] = GUIBaseTasksCreate($g_SettingsGUI, 20, 40, $width - 40, $height - 110, $baseTasksDict)
    GUICtrlCreateTabItem("Log File")
    $g_TabHandles[6] = GUILogCreate($g_SettingsGUI, 20, 40, $width - 40, $height - 110)
    GUICtrlCreateTabItem("About")
    $g_TabHandles[7] = GUIAboutCreate($g_SettingsGUI, 20, 40, $width - 40, $height - 110)
    GUICtrlCreateTabItem("") ; End tab creation

    $g_SettingsApplyBtn = GUICtrlCreateButton("Apply", $width - 180, $height - 40, 70, 30)
    $g_SettingsCloseBtn = GUICtrlCreateButton("Close", $width - 100, $height - 40, 70, 30)

    GUISetState(@SW_SHOW, $g_SettingsGUI)
    WinSetOnTop("Startup Monitor - Settings", "", 1)
    WinActivate("Startup Monitor - Settings")
    Sleep(200)
    WinSetOnTop($g_SettingsGUI, "", 0)

    Local $lastSelectedIndex = -1
    Local $lastPath = ""
    Local $result = "CANCEL"
    Local $tabCount = 8 
    Local $logTabInitialized = False

    While 1
        Local $msg = GUIGetMsg()
        Local $currentTab = GUICtrlRead($g_SettingsTab)
		
        Switch $msg
            Case $GUI_EVENT_CLOSE, $g_SettingsCloseBtn
                $result = "CLOSE"
                ExitLoop

            Case $g_SettingsApplyBtn
                _SettingsApplyAllChanges($settingsDict, $foldersDict, $regTokensDict, $allowedDict, $deniedDict)
                $result = "APPLY"
                ExitLoop

            Case Else
                Switch $currentTab
                    Case 0 ; Options
                        GUIOptionsHandleMessage($msg, $g_TabHandles[0], $settingsDict)
                    Case 1 ; Locations
                        GUILocationsHandleMessage($msg, $g_TabHandles[1], $foldersDict, $regTokensDict)
                        Local $locationsControls = $g_TabHandles[1]
                        Local $selected = _GUICtrlListView_GetSelectedIndices($g_LocationsListView)
                        If $selected <> "" Then
                            Local $index = Int($selected)
                            Local $path = _GUICtrlListView_GetItemText($g_LocationsListView, $index, 1)
                            Local $editCurrent = GUICtrlRead($locationsControls[2])
                            If $index <> $lastSelectedIndex And ($editCurrent = "" Or $editCurrent = $lastPath) Then
                                GUICtrlSetData($locationsControls[2], $path)
                                $lastSelectedIndex = $index
                                $lastPath = $path
                            EndIf
                        Else
                            $lastSelectedIndex = -1
                            $lastPath = ""
                        EndIf
                    Case 2 ; Allowed
                        GUIAllowedHandleMessage($msg, $g_TabHandles[2], $allowedDict)
                    Case 3 ; Denied
                        GUIDeniedHandleMessage($msg, $g_TabHandles[3], $deniedDict)
                    Case 4 ; Base Startup
                        GUIBaseStartupHandleMessage($msg, $g_TabHandles[4])
                        If $msg = $g_BaseStartupListView Then
                            Local $selected = _GUICtrlListView_GetSelectedIndices($g_BaseStartupListView)
                            If $selected <> "" Then
                                Local $index = Int($selected)
                                Local $location = _GUICtrlListView_GetItemText($g_BaseStartupListView, $index, 3)
                                If $location <> "" Then
                                    GUICtrlSetData($g_BaseStartupMsgLabel, "Location/Path: " & $location)
                                    GUICtrlSetState($g_BaseStartupMsgLabel, $GUI_SHOW)
                                Else
                                    GUICtrlSetState($g_BaseStartupMsgLabel, $GUI_HIDE)
                                EndIf
                            Else
                                GUICtrlSetState($g_BaseStartupMsgLabel, $GUI_HIDE)
                            EndIf
                        EndIf
                    Case 5 ; Base Tasks
                        GUIBaseTasksHandleMessage($msg, $g_TabHandles[5])
                    Case 6 ; Log File
                        If Not $logTabInitialized Then
                            _HandleLogTabInit()
                            $logTabInitialized = True
                        EndIf
                        _HandleLogTabMessages($msg)
                    Case 7 ; About
                        GUIAboutHandleMessage($msg, $g_TabHandles[7])
                EndSwitch
        EndSwitch
        Sleep(10)
    WEnd

    WinSetOnTop("Startup Monitor - Settings", "", 0)
    GUIDelete($g_SettingsGUI)
    $g_SettingsGUI = 0

    Return $result
EndFunc

; =================================================================
; LOG TAB HELPER FUNCTIONS
; =================================================================
Func _HandleLogTabInit()
    If IsArray($g_TabHandles[6]) Then
        GUILogShowFile($g_TabHandles[6])
    ElseIf $g_TabHandles[6] <> 0 Then
        Local $logFile = @ScriptDir & "\App\Log.ini"
        Local $logContent = ""
        If FileExists($logFile) Then
            $logContent = FileRead($logFile)
        Else
            $logContent = "(Log.ini does not exist)"
        EndIf
        GUICtrlSetData($g_TabHandles[6], $logContent)
    EndIf
EndFunc

Func _HandleLogTabMessages($msg)
    ; Add log tab message handling if needed
    If $msg <> 0 Then
        ; Handle any log-related messages here
    EndIf
EndFunc

; =================================================================
; HELPER FUNCTIONS
; =================================================================
Func _SettingsApplyAllChanges(ByRef $settingsDict, ByRef $foldersDict, ByRef $regTokensDict, ByRef $allowedDict, ByRef $deniedDict)
    SaveOptionsTabSettings($settingsDict, $g_TabHandles[0])
;~     GUILocationsApply($g_TabHandles[1], $foldersDict, $regTokensDict)
    ConfigSaveLocations($foldersDict, $regTokensDict)
    ConfigSaveAllowedDenied($allowedDict, $deniedDict)
    EngineLogWrite("SETTINGS", "gui", "apply_all", "settings_applied", "SUCCESS")
EndFunc

Func SaveOptionsTabSettings($settingsDict, $optionsControls)
    $settingsDict.Item("MonitorTime") = GUICtrlRead($optionsControls[0])
    $settingsDict.Item("ReviewWindowWidth") = GUICtrlRead($optionsControls[6])
    $settingsDict.Item("ReviewWindowHeight") = GUICtrlRead($optionsControls[7])
    ConfigSaveSettings($settingsDict)
EndFunc

; =================================================================
; WORD WRAP FUNCTION FOR LONG PATHS
; =================================================================
Func _SmartWordWrap($text, $g_MaxLineLen = 90)
    If StringLen($text) <= $g_MaxLineLen Then
        Return $text
    EndIf
    Local $out = ""
    Local $start = 1
    Local $len = StringLen($text)
    While $start <= $len
        Local $chunk = StringMid($text, $start, $g_MaxLineLen)
        If StringLen($chunk) == $g_MaxLineLen Then
            Local $breakPos = StringInStr($chunk, "\", 0, -1)
            If $breakPos > 0 Then
                $out &= StringLeft($chunk, $breakPos) & @CRLF
                $start += $breakPos
                ContinueLoop
            EndIf
        EndIf
        $out &= $chunk
        ExitLoop
    WEnd
    Return $out
EndFunc

Func SplitCommandTwoLines($sCommand)
    Local $len = StringLen($sCommand)
    If $len < 1 Then Return ""
    Local $mid = Int($len / 2)
    Local $split = 0
    For $i = $mid To 1 Step -1
        If StringMid($sCommand, $i, 1) = "\" Then
            $split = $i
            ExitLoop
        EndIf
    Next
    If $split = 0 Then
        For $i = $mid + 1 To $len
            If StringMid($sCommand, $i, 1) = "\" Then
                $split = $i
                ExitLoop
            EndIf
        Next
    EndIf
    If $split = 0 Then $split = $mid
    Local $line1 = StringLeft($sCommand, $split)
    Local $line2 = StringTrimLeft($sCommand, $split)
    Return $line1 & @CRLF & $line2
EndFunc

; =================================================================
; NATURAL SORTING FOR INDEX COLUMN
; =================================================================
Func ListView_NaturalSortIndex($hListView, $iIndexCol = 0)
    Local $itemCount = _GUICtrlListView_GetItemCount($hListView)
    If $itemCount < 2 Then Return

    Local $colCount = _GUICtrlListView_GetColumnCount($hListView)
    Local $aRows[$itemCount][$colCount]

    For $i = 0 To $itemCount - 1
        For $j = 0 To $colCount - 1
            $aRows[$i][$j] = _GUICtrlListView_GetItemText($hListView, $i, $j)
        Next
    Next

    For $i = 0 To $itemCount - 2
        For $j = $i + 1 To $itemCount - 1
            If Number($aRows[$i][$iIndexCol]) > Number($aRows[$j][$iIndexCol]) Then
                Local $temp
                $temp = $aRows[$i]
                $aRows[$i] = $aRows[$j]
                $aRows[$j] = $temp
            EndIf
        Next
    Next

    _GUICtrlListView_DeleteAllItems($hListView)
    For $i = 0 To UBound($aRows) - 1
        Local $newIdx = _GUICtrlListView_AddItem($hListView, $aRows[$i][0])
        For $j = 1 To $colCount - 1
            _GUICtrlListView_AddSubItem($hListView, $newIdx, $aRows[$i][$j], $j)
        Next
    Next
EndFunc
