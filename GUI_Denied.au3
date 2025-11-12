; GUI_Denied.au3

#include-once
#include <GUIConstantsEx.au3>
#include <ListViewConstants.au3>
#include <GuiListView.au3>
#include <Clipboard.au3>

Global $g_DeniedListView = 0
Global $g_DeniedListView_Handle = 0
Global $g_DeniedControls[14] ; now indexed from [1]
Global $g_DeniedDeleteConfirmVisible = False
Global $g_DeniedDeleteSelectedIndex = -1
Global $g_DeniedContextMenu = 0
Global $g_DeniedContextMenu_Delete = 0
Global $g_DeniedContextMenu_Refresh = 0
Global $g_DeniedContextMenu_CopyPath = 0

; =================================================================
; DENIED TAB CREATION
; =================================================================
Func GUIDeniedCreate($parentGUI, $x, $y, $width, $height, $deniedDict)
    Local $controls[14]

    ; ListView
    $controls[1] = GUICtrlCreateListView("#|Name|Type|Location/Path|Hash", $x + 10, $y + 10, $width - 20, $height - 60, _
        BitOR($LVS_REPORT, $LVS_SHOWSELALWAYS), BitOR($LVS_EX_FULLROWSELECT, $LVS_EX_GRIDLINES))
    $g_DeniedListView = $controls[1]
    $g_DeniedListView_Handle = GUICtrlGetHandle($g_DeniedListView)

    _GUICtrlListView_SetColumnWidth($g_DeniedListView_Handle, 0, 40)
    _GUICtrlListView_SetColumnWidth($g_DeniedListView_Handle, 1, 150)
    _GUICtrlListView_SetColumnWidth($g_DeniedListView_Handle, 2, 55)
    _GUICtrlListView_SetColumnWidth($g_DeniedListView_Handle, 3, $width - 360)
    _GUICtrlListView_SetColumnWidth($g_DeniedListView_Handle, 4, 70)

    ; --- Confirmation UI ---
    ; Confirmation Label
    $controls[2] = GUICtrlCreateLabel("", $x + 10, $y + $height - 40, $width - 80, 50)
    GUICtrlSetFont($controls[2], 10, 700)
    GUICtrlSetBkColor($controls[2], 0xF2DADA)
    GUICtrlSetColor($controls[2], 0x7A0000)
    GUICtrlSetState($controls[2], $GUI_HIDE)
    ; Details Label
    $controls[3] = GUICtrlCreateLabel("", $x + 13, $y + $height - 23, $width - 83, 30, $SS_LEFT)
    GUICtrlSetFont($controls[3], 9, 400)
    GUICtrlSetColor($controls[3], 0x7A0000)
    GUICtrlSetState($controls[3], $GUI_HIDE)
	
    $controls[4] = GUICtrlCreateButton("OK", $x + $width - 60, $y + $height - 40, 50, 20)
    GUICtrlSetState($controls[4], $GUI_HIDE)
    $controls[5] = GUICtrlCreateButton("Cancel", $x + $width - 60, $y + $height - 10, 50, 20)
    GUICtrlSetState($controls[5], $GUI_HIDE)

    $g_DeniedContextMenu = GUICtrlCreateContextMenu($controls[1])
    $g_DeniedContextMenu_Delete = GUICtrlCreateMenuItem("Remove", $g_DeniedContextMenu)
    $g_DeniedContextMenu_Refresh = GUICtrlCreateMenuItem("Refresh", $g_DeniedContextMenu)
    $g_DeniedContextMenu_CopyPath = GUICtrlCreateMenuItem("Copy Path", $g_DeniedContextMenu)

    _DeniedPopulateList($deniedDict)

    ; Fill remaining indices for compatibility
    For $i = 6 To 13
        $controls[$i] = -1
    Next

    For $i = 1 To 13
        $g_DeniedControls[$i] = $controls[$i]
    Next

    Return $controls
EndFunc

; =================================================================
; DENIED TAB MESSAGE HANDLING
; =================================================================
Func GUIDeniedHandleMessage($msg, $controls, ByRef $deniedDict)
    If Not IsArray($controls) Then Return

    ; Inline confirmation UI logic
    If $g_DeniedDeleteConfirmVisible Then
        If $msg = $controls[4] Then ; OK
            _DeniedDeleteItemConfirmed($deniedDict, $controls)
            _DeniedHideDeleteConfirm($controls)
            GUICtrlSetState($g_DeniedListView, $GUI_ENABLE)
        ElseIf $msg = $controls[5] Then ; Cancel
            _DeniedHideDeleteConfirm($controls)
            GUICtrlSetState($g_DeniedListView, $GUI_ENABLE)
        Else
            Return
        EndIf
    EndIf

    If $msg = $g_DeniedListView Then
        Local $info = GUIGetCursorInfo()
        If IsArray($info) And $info[4] = $g_DeniedListView Then
            ListView_NaturalSortIndex($g_DeniedListView, 0)
        EndIf
    EndIf

    Switch $msg
        Case $g_DeniedContextMenu_Delete
            _DeniedShowDeleteConfirm($controls)
            If _GUICtrlListView_GetSelectedIndices($g_DeniedListView_Handle) <> "" Then
                GUICtrlSetState($g_DeniedListView, $GUI_DISABLE)
            EndIf
        Case $g_DeniedContextMenu_Refresh
            _DeniedPopulateList($deniedDict)
        Case $g_DeniedContextMenu_CopyPath
            Local $selected = _GUICtrlListView_GetSelectedIndices($g_DeniedListView_Handle)
            If $selected <> "" Then
                Local $selectedIndex = Int($selected)
                Local $path = _GUICtrlListView_GetItemText($g_DeniedListView_Handle, $selectedIndex, 3)
                ClipPut($path)
                GUICtrlSetData($controls[2], " Path copied to clipboard. ")
                GUICtrlSetState($controls[2], $GUI_SHOW)
                AdlibRegister("_DeniedHideNoSelectionMessage", 1500)
            EndIf
    EndSwitch
EndFunc

; =================================================================
; DENIED TAB HELPER FUNCTIONS
; =================================================================
Func _DeniedPopulateList($deniedDict)
    _GUICtrlListView_DeleteAllItems($g_DeniedListView_Handle)
    If Not IsObj($deniedDict) Then
        ConsoleWrite("Denied dict is not an object." & @CRLF)
        Return
    EndIf
    Local $index = 0
    For $key In $deniedDict.Keys
        Local $hash = $deniedDict.Item($key)
        Local $name = _DeniedGetDisplayName($key)
        Local $type = _DeniedGetItemType($key)
        Local $itemIndex = _GUICtrlListView_AddItem($g_DeniedListView_Handle, String($index + 1))
        If $itemIndex <> -1 Then
            _GUICtrlListView_AddSubItem($g_DeniedListView_Handle, $itemIndex, $name, 1)
            _GUICtrlListView_AddSubItem($g_DeniedListView_Handle, $itemIndex, $type, 2)
            _GUICtrlListView_AddSubItem($g_DeniedListView_Handle, $itemIndex, $key, 3)
            _GUICtrlListView_AddSubItem($g_DeniedListView_Handle, $itemIndex, $hash, 4)
        Else
            ConsoleWrite("Failed to add item at index " & $index & @CRLF)
        EndIf
        $index += 1
    Next
EndFunc

; =================================================================
; DELETE CONFIRMATION UI
; =================================================================
Func _DeniedShowDeleteConfirm($controls)
    Local $selected = _GUICtrlListView_GetSelectedIndices($g_DeniedListView_Handle)
    If $selected = "" Then
        GUICtrlSetData($controls[2], " No selection. Please select an item to Remove. ")
        GUICtrlSetState($controls[2], $GUI_SHOW)
        GUICtrlSetState($controls[4], $GUI_HIDE)
        GUICtrlSetState($controls[5], $GUI_HIDE)
        GUICtrlSetData($controls[3], "")
        $g_DeniedDeleteConfirmVisible = False
        AdlibRegister("_DeniedHideNoSelectionMessage", 2000)
        Return
    EndIf

    Local $selectedIndex = Int($selected)
    $g_DeniedDeleteSelectedIndex = $selectedIndex
    Local $name = _GUICtrlListView_GetItemText($g_DeniedListView_Handle, $selectedIndex, 1)
    Local $type = _GUICtrlListView_GetItemText($g_DeniedListView_Handle, $selectedIndex, 2)
    Local $path = _GUICtrlListView_GetItemText($g_DeniedListView_Handle, $selectedIndex, 3)
    GUICtrlSetData($controls[2], " Confirm removal of this " & StringLower($type) & " from denied list? ")
    GUICtrlSetState($controls[2], $GUI_SHOW)
    GUICtrlSetState($controls[4], $GUI_SHOW)
    GUICtrlSetState($controls[5], $GUI_SHOW)
    Local $wrappedPath = _SmartWordWrap($path, $g_MaxLineLen)
    GUICtrlSetData($controls[3], $wrappedPath)
    GUICtrlSetState($controls[3], $GUI_SHOW)
    $g_DeniedDeleteConfirmVisible = True
EndFunc

Func _DeniedHideNoSelectionMessage()
    GUICtrlSetState($g_DeniedControls[2], $GUI_HIDE)
    AdlibUnRegister("_DeniedHideNoSelectionMessage")
    $g_DeniedDeleteConfirmVisible = False
EndFunc

Func _DeniedHideDeleteConfirm($controls)
    GUICtrlSetState($controls[2], $GUI_HIDE)
    GUICtrlSetState($controls[4], $GUI_HIDE)
    GUICtrlSetState($controls[5], $GUI_HIDE)
    GUICtrlSetState($controls[3], $GUI_HIDE)
    $g_DeniedDeleteConfirmVisible = False
    $g_DeniedDeleteSelectedIndex = -1
EndFunc

Func _DeniedDeleteItemConfirmed(ByRef $deniedDict, $controls)
    Local $selectedIndex = $g_DeniedDeleteSelectedIndex
    If $selectedIndex = -1 Then Return

    Local $key = _GUICtrlListView_GetItemText($g_DeniedListView_Handle, $selectedIndex, 3)
    If $key <> "" And $deniedDict.Exists($key) Then
        $deniedDict.Remove($key)
        IniDelete(@ScriptDir & "\App\Denied.ini", "Denied", $key)
        _DeniedPopulateList($deniedDict)
        EngineLogWrite("SETTINGS", "denied", "delete", $key, "DELETED")
    EndIf
EndFunc

Func _DeniedGetDisplayName($key)
    Local $pos = StringInStr($key, "\", 0, -1)
    If $pos > 0 Then Return StringTrimLeft($key, $pos)
    $pos = StringInStr($key, "|", 0, -1)
    If $pos > 0 Then Return StringTrimLeft($key, $pos)
    Return $key
EndFunc

Func _DeniedGetItemType($key)
    If StringInStr($key, "|") Then Return "Registry"
    If StringInStr($key, ".exe") Or StringInStr($key, ".lnk") Then Return "File"
    Return "Task"
EndFunc
