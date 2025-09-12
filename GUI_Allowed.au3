; GUI_Allowed.au3

#include-once
#include <GUIConstantsEx.au3>
#include <ListViewConstants.au3>
#include <GuiListView.au3>
#include <Clipboard.au3>

Global $g_AllowedListView = 0
Global $g_AllowedListView_Handle = 0
Global $g_AllowedControls[14]
Global $g_AllowedDeleteConfirmVisible = False
Global $g_AllowedDeleteSelectedIndex = -1
Global $g_AllowedContextMenu = 0
Global $g_AllowedContextMenu_Delete = 0
Global $g_AllowedContextMenu_Refresh = 0
Global $g_AllowedContextMenu_CopyPath = 0

; =================================================================
; ALLOWED TAB CREATION
; =================================================================
Func GUIAllowedCreate($parentGUI, $x, $y, $width, $height, $allowedDict)
    Local $controls[14]

    ; ListView
    $controls[1] = GUICtrlCreateListView("#|Name|Type|Location/Path|Hash", $x + 10, $y + 10, $width - 20, $height - 60, _
        BitOR($LVS_REPORT, $LVS_SHOWSELALWAYS), BitOR($LVS_EX_FULLROWSELECT, $LVS_EX_GRIDLINES))
    $g_AllowedListView = $controls[1]
    $g_AllowedListView_Handle = GUICtrlGetHandle($g_AllowedListView)

    _GUICtrlListView_SetColumnWidth($g_AllowedListView_Handle, 0, 40)
    _GUICtrlListView_SetColumnWidth($g_AllowedListView_Handle, 1, 150)
    _GUICtrlListView_SetColumnWidth($g_AllowedListView_Handle, 2, 55)
    _GUICtrlListView_SetColumnWidth($g_AllowedListView_Handle, 3, $width - 360)
    _GUICtrlListView_SetColumnWidth($g_AllowedListView_Handle, 4, 70)

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

    $g_AllowedContextMenu = GUICtrlCreateContextMenu($controls[1])
    $g_AllowedContextMenu_Delete = GUICtrlCreateMenuItem("Remove", $g_AllowedContextMenu)
    $g_AllowedContextMenu_Refresh = GUICtrlCreateMenuItem("Refresh", $g_AllowedContextMenu)
    $g_AllowedContextMenu_CopyPath = GUICtrlCreateMenuItem("Copy Path", $g_AllowedContextMenu)

    _AllowedPopulateList($allowedDict)

    ; Fill remaining indices for compatibility
    For $i = 6 To 13
        $controls[$i] = -1
    Next

    For $i = 1 To 13
        $g_AllowedControls[$i] = $controls[$i]
    Next

    Return $controls
EndFunc

; =================================================================
; ALLOWED TAB MESSAGE HANDLING
; =================================================================
Func GUIAllowedHandleMessage($msg, $controls, ByRef $allowedDict)
    If Not IsArray($controls) Then Return

    ; Inline confirmation UI logic
    If $g_AllowedDeleteConfirmVisible Then
        If $msg = $controls[4] Then ; OK
            _AllowedDeleteItemConfirmed($allowedDict, $controls)
            _AllowedHideDeleteConfirm($controls)
            GUICtrlSetState($g_AllowedListView, $GUI_ENABLE)
        ElseIf $msg = $controls[5] Then ; Cancel
            _AllowedHideDeleteConfirm($controls)
            GUICtrlSetState($g_AllowedListView, $GUI_ENABLE)
        Else
            Return
        EndIf
    EndIf

    If $msg = $g_AllowedListView Then
        Local $info = GUIGetCursorInfo()
        If IsArray($info) And $info[4] = $g_AllowedListView Then
            ListView_NaturalSortIndex($g_AllowedListView, 0)
        EndIf
    EndIf

    Switch $msg
        Case $g_AllowedContextMenu_Delete
            _AllowedShowDeleteConfirm($controls)
            If _GUICtrlListView_GetSelectedIndices($g_AllowedListView_Handle) <> "" Then
                GUICtrlSetState($g_AllowedListView, $GUI_DISABLE)
            EndIf
        Case $g_AllowedContextMenu_Refresh
            _AllowedPopulateList($allowedDict)
        Case $g_AllowedContextMenu_CopyPath
            Local $selected = _GUICtrlListView_GetSelectedIndices($g_AllowedListView_Handle)
            If $selected <> "" Then
                Local $selectedIndex = Int($selected)
                Local $path = _GUICtrlListView_GetItemText($g_AllowedListView_Handle, $selectedIndex, 3)
                ClipPut($path)
                GUICtrlSetData($controls[2], " Path copied to clipboard. ")
                GUICtrlSetState($controls[2], $GUI_SHOW)
                AdlibRegister("_AllowedHideNoSelectionMessage", 1500)
            EndIf
    EndSwitch
EndFunc

; =================================================================
; ALLOWED TAB HELPER FUNCTIONS
; =================================================================
Func _AllowedPopulateList($allowedDict)
    _GUICtrlListView_DeleteAllItems($g_AllowedListView_Handle)
    If Not IsObj($allowedDict) Then Return
    Local $index = 0
    For $key In $allowedDict.Keys
        Local $hash = $allowedDict.Item($key)
        Local $name = _AllowedGetDisplayName($key)
        Local $type = _AllowedGetItemType($key)
        Local $itemIndex = _GUICtrlListView_AddItem($g_AllowedListView_Handle, String($index + 1))
        If $itemIndex <> -1 Then
            _GUICtrlListView_AddSubItem($g_AllowedListView_Handle, $itemIndex, $name, 1)
            _GUICtrlListView_AddSubItem($g_AllowedListView_Handle, $itemIndex, $type, 2)
            _GUICtrlListView_AddSubItem($g_AllowedListView_Handle, $itemIndex, $key, 3)
            _GUICtrlListView_AddSubItem($g_AllowedListView_Handle, $itemIndex, $hash, 4)
        EndIf
        $index += 1
    Next
EndFunc

; =================================================================
; DELETE CONFIRMATION UI
; =================================================================
Func _AllowedShowDeleteConfirm($controls)
    Local $selected = _GUICtrlListView_GetSelectedIndices($g_AllowedListView_Handle)
    If $selected = "" Then
        GUICtrlSetData($controls[2], " No selection. Please select an item to Remove. ")
        GUICtrlSetState($controls[2], $GUI_SHOW)
        GUICtrlSetState($controls[4], $GUI_HIDE)
        GUICtrlSetState($controls[5], $GUI_HIDE)
        GUICtrlSetData($controls[3], "")
        $g_AllowedDeleteConfirmVisible = False
        AdlibRegister("_AllowedHideNoSelectionMessage", 2000)
        Return
    EndIf

    Local $selectedIndex = Int($selected)
    $g_AllowedDeleteSelectedIndex = $selectedIndex
    Local $name = _GUICtrlListView_GetItemText($g_AllowedListView_Handle, $selectedIndex, 1)
    Local $type = _GUICtrlListView_GetItemText($g_AllowedListView_Handle, $selectedIndex, 2)
    Local $path = _GUICtrlListView_GetItemText($g_AllowedListView_Handle, $selectedIndex, 3)
    GUICtrlSetData($controls[2], " Confirm removal of this " & StringLower($type) & " entry from allowed list? ")
    GUICtrlSetState($controls[2], $GUI_SHOW)
    GUICtrlSetState($controls[4], $GUI_SHOW)
    GUICtrlSetState($controls[5], $GUI_SHOW)
    Local $wrappedPath = _SmartWordWrap($path, $g_MaxLineLen)
    GUICtrlSetData($controls[3], $wrappedPath)
    GUICtrlSetState($controls[3], $GUI_SHOW)
    $g_AllowedDeleteConfirmVisible = True
EndFunc

Func _AllowedHideNoSelectionMessage()
    GUICtrlSetState($g_AllowedControls[2], $GUI_HIDE)
    AdlibUnRegister("_AllowedHideNoSelectionMessage")
    $g_AllowedDeleteConfirmVisible = False
EndFunc

Func _AllowedHideDeleteConfirm($controls)
    GUICtrlSetState($controls[2], $GUI_HIDE)
    GUICtrlSetState($controls[4], $GUI_HIDE)
    GUICtrlSetState($controls[5], $GUI_HIDE)
    GUICtrlSetState($controls[3], $GUI_HIDE)
    $g_AllowedDeleteConfirmVisible = False
    $g_AllowedDeleteSelectedIndex = -1
EndFunc

Func _AllowedDeleteItemConfirmed(ByRef $allowedDict, $controls)
    Local $selectedIndex = $g_AllowedDeleteSelectedIndex
    If $selectedIndex = -1 Then Return

    Local $key = _GUICtrlListView_GetItemText($g_AllowedListView_Handle, $selectedIndex, 3)
    If $key <> "" And $allowedDict.Exists($key) Then
        $allowedDict.Remove($key)
        IniDelete(@ScriptDir & "\App\Allowed.ini", "Allowed", $key)
        _AllowedPopulateList($allowedDict)
        EngineLogWrite("SETTINGS", "allowed", "delete", $key, "DELETED")
    EndIf
EndFunc

Func _AllowedGetDisplayName($key)
    Local $pos = StringInStr($key, "\", 0, -1)
    If $pos > 0 Then Return StringTrimLeft($key, $pos)
    $pos = StringInStr($key, "|", 0, -1)
    If $pos > 0 Then Return StringTrimLeft($key, $pos)
    Return $key
EndFunc

Func _AllowedGetItemType($key)
    If StringInStr($key, "|") Then Return "Registry"
    If StringInStr($key, ".exe") Or StringInStr($key, ".lnk") Then Return "File"
    Return "Task"
EndFunc
