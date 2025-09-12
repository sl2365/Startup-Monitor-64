; GUI_Review.au3

#include-once
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <ListViewConstants.au3>
#include <GuiListView.au3>
#include "Engine.au3"

; =================================================================
; MAIN REVIEW GUI FUNCTION
; =================================================================
Func GUIShowReview($itemsArray, $settingsDict)
    If Not IsArray($itemsArray) Then
        Local $emptyResult[2] = ["CANCEL", ""]
        Return $emptyResult
    EndIf
    
    Local $arrayRows = UBound($itemsArray, 1)
    Local $arrayCols = UBound($itemsArray, 2)
    If $arrayRows = 0 Or $arrayCols < 7 Then
        Local $emptyResult[2] = ["CANCEL", $itemsArray]
        Return $emptyResult
    EndIf

    Local $width = 500
    Local $height = 400
    If IsObj($settingsDict) Then
        If $settingsDict.Exists("ReviewWindowWidth") Then $width = Number($settingsDict.Item("ReviewWindowWidth"))
        If $settingsDict.Exists("ReviewWindowHeight") Then $height = Number($settingsDict.Item("ReviewWindowHeight"))
    EndIf

    Local $footerHeight = 95 ; Change footer (button area) size
    Local $gui = GUICreate("Startup Items Review", $width, $height, -1, -1, _
        BitOR($WS_CAPTION, $WS_SYSMENU, $WS_MINIMIZEBOX), $WS_EX_TOPMOST)

    ; ListView now takes almost all vertical space, minus the footer
    Local $listView = GUICtrlCreateListView("Name|Type|Detail|Status", 10, 10, $width - 20, $height - $footerHeight - 10, _
        BitOR($LVS_REPORT, $LVS_SHOWSELALWAYS), $LVS_EX_CHECKBOXES)
    _GUICtrlListView_SetColumnWidth($listView, 0, 150)
    _GUICtrlListView_SetColumnWidth($listView, 1, 55)
    _GUICtrlListView_SetColumnWidth($listView, 2, $width - 320)
    _GUICtrlListView_SetColumnWidth($listView, 3, 70)

    For $i = 0 To $arrayRows - 1
        Local $statusText = ""
        Switch $itemsArray[$i][4]
            Case 0
                $statusText = "NEW"
            Case 1
                $statusText = "ALLOWED"
            Case 2
                $statusText = "DENIED"
            Case Else
                $statusText = "UNKNOWN"
        EndSwitch
        
        Local $itemIndex = _GUICtrlListView_AddItem($listView, $itemsArray[$i][1])
        _GUICtrlListView_AddSubItem($listView, $itemIndex, $itemsArray[$i][2], 1)
        _GUICtrlListView_AddSubItem($listView, $itemIndex, $itemsArray[$i][3], 2)
        _GUICtrlListView_AddSubItem($listView, $itemIndex, $statusText, 3)
        _GUICtrlListView_SetItemChecked($listView, $itemIndex, $itemsArray[$i][6])
    Next

    ; Info labels (these go in footer area, y = $height - $footerHeight + offset)
    Local $footerY = $height - $footerHeight + 10
    Local $infoChecked = GUICtrlCreateLabel("CHECKED:", 10, $footerY, 80, 20)
    GUICtrlSetFont($infoChecked, 9, 700)
    GUICtrlSetColor($infoChecked, 0x009900)
    Local $infoCheckedRest = GUICtrlCreateLabel("Adds item to Allowed list", 75, $footerY, 150, 20)
    GUICtrlSetFont($infoCheckedRest, 9, 400)
    GUICtrlSetColor($infoCheckedRest, 0x000000)
    Local $infoUnchecked = GUICtrlCreateLabel("UNCHECKED:", 230, $footerY, 80, 20)
    GUICtrlSetFont($infoUnchecked, 9, 700)
    GUICtrlSetColor($infoUnchecked, 0xC00000)
    Local $infoUncheckedRest = GUICtrlCreateLabel("Adds item to Denied list", 310, $footerY, 150, 20)
    GUICtrlSetFont($infoUncheckedRest, 9, 400)
    GUICtrlSetColor($infoUncheckedRest, 0x000000)

    ; "Exported!" message label
    Global $g_ReviewExportMsgLabel = GUICtrlCreateLabel("", $width / 2 - 30, $height - $footerHeight + 38, 60, 24)
    GUICtrlSetFont($g_ReviewExportMsgLabel, 10, 700)
    GUICtrlSetColor($g_ReviewExportMsgLabel, 0x009900)
    GUICtrlSetBkColor($g_ReviewExportMsgLabel, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetState($g_ReviewExportMsgLabel, $GUI_HIDE)

    ; Buttons (also in footer area, y = $height - $footerHeight + offset)
    Local $btnSelectAll = GUICtrlCreateButton("Select All", 20, $height - $footerHeight + 30, 70, 25)
    Local $btnDeselectAll = GUICtrlCreateButton("Deselect All", 20, $height - $footerHeight + 60, 70, 25)
    Local $btnExport = GUICtrlCreateButton("Export List", $width / 2 - 35, $height - $footerHeight + 60, 70, 25)
    Local $btnOK = GUICtrlCreateButton("OK", $width - 90, $height - $footerHeight + 30, 70, 25)
    Local $btnCancel = GUICtrlCreateButton("Cancel", $width - 90, $height - $footerHeight + 60, 70, 25)

    GUISetState(@SW_SHOW, $gui)
    WinSetOnTop("Startup Items Review", "", 1)
    WinActivate("Startup Items Review")
    Local $result[2]
    While 1
        Local $msg = GUIGetMsg()
        Switch $msg
            Case $GUI_EVENT_CLOSE, $btnCancel
                $result[0] = "CANCEL"
                $result[1] = $itemsArray
                _GUILogCancelAction($itemsArray)
                ExitLoop
            Case $btnSelectAll
                _GUISelectAllItems($listView, True)
            Case $btnDeselectAll
                _GUISelectAllItems($listView, False)
            Case $btnExport
                _GUIExportList($listView, $itemsArray)
            Case $btnOK
                For $i = 0 To $arrayRows - 1
                    $itemsArray[$i][6] = _GUICtrlListView_GetItemChecked($listView, $i)
                Next
                $result[0] = "OK"
                $result[1] = $itemsArray
                _GUILogOKAction($itemsArray)
                ExitLoop
        EndSwitch
        Sleep(10)
    WEnd

    WinSetOnTop("Startup Items Review", "", 0)
    GUIDelete($gui)
    Return $result
EndFunc

; =================================================================
; GUI HELPER FUNCTIONS
; =================================================================
Func _GUISelectAllItems($listView, $checked)
    Local $itemCount = _GUICtrlListView_GetItemCount($listView)
    For $i = 0 To $itemCount - 1
        _GUICtrlListView_SetItemChecked($listView, $i, $checked)
    Next
EndFunc

Func _GUIExportList($listView, $itemsArray)
    Local $timestamp = @YEAR & @MON & @MDAY & "_" & @HOUR & @MIN & @SEC
    Local $filename = @ScriptDir & "\App\Exported_" & $timestamp & ".txt"
    Local $content = "Startup Monitor Export - " & @YEAR & "/" & @MON & "/" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC & @CRLF
    $content &= "======================================================" & @CRLF & @CRLF
    If IsArray($itemsArray) And UBound($itemsArray, 1) > 0 And UBound($itemsArray, 2) >= 4 Then
        Local $itemCount = _GUICtrlListView_GetItemCount($listView)
        For $i = 0 To $itemCount - 1
            If $i < UBound($itemsArray, 1) Then
                Local $checked = _GUICtrlListView_GetItemChecked($listView, $i)
                Local $checkmark = $checked ? "[X]" : "[ ]"
                $content &= $checkmark & " " & $itemsArray[$i][2] & " | " & $itemsArray[$i][1] & " | " & $itemsArray[$i][3] & @CRLF
            EndIf
        Next
    EndIf
    FileWrite($filename, $content)
    EngineLogWrite("EXPORT", "gui", "export_list", $filename, "EXPORTED")
    GUICtrlSetData($g_ReviewExportMsgLabel, "Exported!")
    GUICtrlSetState($g_ReviewExportMsgLabel, $GUI_SHOW)
    Local $timer = TimerInit()
    While TimerDiff($timer) < 3000
        Sleep(10)
    WEnd
    GUICtrlSetState($g_ReviewExportMsgLabel, $GUI_HIDE)
EndFunc

Func _GUILogOKAction($itemsArray)
    If Not IsArray($itemsArray) Or UBound($itemsArray, 1) = 0 Or UBound($itemsArray, 2) < 7 Then Return
    For $i = 0 To UBound($itemsArray, 1) - 1
        Local $action = $itemsArray[$i][6] ? "USER_ALLOW" : "USER_DENY"
        EngineLogWrite($action, $itemsArray[$i][2], $itemsArray[$i][0], $itemsArray[$i][3], $action)
    Next
EndFunc

Func _GUILogCancelAction($itemsArray)
    If Not IsArray($itemsArray) Or UBound($itemsArray, 1) = 0 Or UBound($itemsArray, 2) < 4 Then Return
    For $i = 0 To UBound($itemsArray, 1) - 1
        EngineLogWrite("USER_CANCEL", $itemsArray[$i][2], $itemsArray[$i][0], $itemsArray[$i][3], "CANCELLED")
    Next
EndFunc
