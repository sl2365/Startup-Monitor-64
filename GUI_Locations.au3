; GUI_Locations.au3

#include-once
#include <GUIConstantsEx.au3>
#include <ListViewConstants.au3>
#include <GuiListView.au3>
#include <FileConstants.au3>
#include <WindowsConstants.au3>

Global $g_LocationsListView = 0
Global $g_LocationsControls[15] ; controls now indexed from [1]
Global $g_LocationsCheckTimer = 0
Global $g_LocationsDict_Folders = 0
Global $g_LocationsDict_Registry = 0
Global $g_LocationsDeleteConfirmVisible = False
Global $g_LocationsEditIndex = -1
Global $g_LocationsInputMode = ""

Global $g_LocationsContextMenu = 0
Global $g_LocationsContextMenu_Remove = 0
Global $g_LocationsContextMenu_Refresh = 0
Global $g_LocationsContextMenu_Edit = 0
Global $g_LocationsContextMenu_AddRegistry = 0
Global $g_LocationsContextMenu_AddFolder = 0
Global $g_LocationsContextMenu_OpenRegEdit = 0

Func GUILocationsCreate($parentGUI, $x, $y, $width, $height, $foldersDict, $regTokensDict)
    Local $controls[15]

    $g_LocationsDict_Folders = $foldersDict
    $g_LocationsDict_Registry = $regTokensDict

    ; ListView
    $controls[1] = GUICtrlCreateListView("Enabled|Location Path|Type", $x + 10, $y + 10, $width - 20, $height - 60, _
        BitOR($LVS_REPORT, $LVS_SHOWSELALWAYS, $LVS_SINGLESEL), _
        BitOR($LVS_EX_CHECKBOXES, $LVS_EX_FULLROWSELECT, $LVS_EX_GRIDLINES))
    $g_LocationsListView = $controls[1]

    _GUICtrlListView_SetColumnWidth($g_LocationsListView, 0, 70)
    _GUICtrlListView_SetColumnWidth($g_LocationsListView, 1, $width - 200)
    _GUICtrlListView_SetColumnWidth($g_LocationsListView, 2, 70)

    ; Add Path Button (hidden by default)
    $controls[2] = GUICtrlCreateButton("Add Path", $x + 10, $y + $height - 40, 80, 25)
    GUICtrlSetState($controls[2], $GUI_HIDE)
    ; Edit Button (hidden by default)
    $controls[3] = GUICtrlCreateButton("Edit", $x + 10, $y + $height - 40, 80, 25)
    GUICtrlSetState($controls[3], $GUI_HIDE)
    ; Shared Input Field (hidden by default)
    $controls[4] = GUICtrlCreateInput("", $x + 100, $y + $height - 40, 250, 23)
    GUICtrlSetState($controls[4], $GUI_HIDE)

    ; --- Inline Remove Confirmation UI (hidden by default) ---
    ; Confirmation Label
    $controls[5] = GUICtrlCreateLabel("", $x + 10, $y + $height - 40, $width - 80, 50)
    GUICtrlSetFont($controls[5], 10, 700)
    GUICtrlSetBkColor($controls[5], 0xF2DADA)
    GUICtrlSetColor($controls[5], 0x7A0000)
    GUICtrlSetState($controls[5], $GUI_HIDE)
    ; Details Label
    $controls[6] = GUICtrlCreateLabel("", $x + 13, $y + $height - 22, $width - 80, 50)
    GUICtrlSetFont($controls[6], 9, 400)
    GUICtrlSetColor($controls[6], 0x7A0000)
    GUICtrlSetState($controls[6], $GUI_HIDE)
    ; OK/Cancel Buttons
    $controls[7] = GUICtrlCreateButton("OK", $x + $width - 60, $y + $height - 40, 50, 20)
    GUICtrlSetState($controls[7], $GUI_HIDE)
    $controls[8] = GUICtrlCreateButton("Cancel", $x + $width - 60, $y + $height - 10, 50, 20)
    GUICtrlSetState($controls[8], $GUI_HIDE)

    $g_LocationsContextMenu = GUICtrlCreateContextMenu($controls[1])
    $g_LocationsContextMenu_Edit = GUICtrlCreateMenuItem("Edit", $g_LocationsContextMenu)
    $g_LocationsContextMenu_Remove = GUICtrlCreateMenuItem("Remove", $g_LocationsContextMenu)
    $g_LocationsContextMenu_Refresh = GUICtrlCreateMenuItem("Refresh", $g_LocationsContextMenu)
    $g_LocationsContextMenu_AddFolder = GUICtrlCreateMenuItem("Add Folder", $g_LocationsContextMenu)
    $g_LocationsContextMenu_AddRegistry = GUICtrlCreateMenuItem("Add Registry Path", $g_LocationsContextMenu)
    $g_LocationsContextMenu_OpenRegEdit = GUICtrlCreateMenuItem("Open RegEdit", $g_LocationsContextMenu)

    _LocationsPopulateList($foldersDict, $regTokensDict)
    $g_LocationsCheckTimer = TimerInit()
    AdlibRegister("_LocationsMonitorCheckboxes", 250)

    For $i = 9 To 14
        $controls[$i] = -1
    Next

    For $i = 1 To 14
        $g_LocationsControls[$i] = $controls[$i]
    Next

    Return $controls
EndFunc

Func _LocationsMonitorCheckboxes()
    If $g_LocationsListView = 0 Or Not IsObj($g_LocationsDict_Folders) Or Not IsObj($g_LocationsDict_Registry) Then Return

    Local $itemCount = _GUICtrlListView_GetItemCount($g_LocationsListView)
    Local $hasChanges = False

    For $i = 0 To $itemCount - 1
        Local $path = _GUICtrlListView_GetItemText($g_LocationsListView, $i, 1)
        Local $type = _GUICtrlListView_GetItemText($g_LocationsListView, $i, 2)
        Local $checked = _GUICtrlListView_GetItemChecked($g_LocationsListView, $i)
        Local $newValue = $checked ? "1" : "0"

        If $type = "Folder" And $g_LocationsDict_Folders.Exists($path) Then
            Local $currentValue = $g_LocationsDict_Folders.Item($path)
            If $currentValue <> $newValue Then
                $g_LocationsDict_Folders.Item($path) = $newValue
                $hasChanges = True
                EngineLogWrite("SETTINGS", "locations", "folder_checkbox", $path & "=" & $newValue, "CHANGED")
            EndIf
        EndIf

        If $type = "Registry" And $g_LocationsDict_Registry.Exists($path) Then
            Local $currentValue = $g_LocationsDict_Registry.Item($path)
            If $currentValue <> $newValue Then
                $g_LocationsDict_Registry.Item($path) = $newValue
                $hasChanges = True
                EngineLogWrite("SETTINGS", "locations", "registry_checkbox", $path & "=" & $newValue, "CHANGED")
            EndIf
        EndIf
    Next

    If $hasChanges Then
        ConfigSaveLocations($g_LocationsDict_Folders, $g_LocationsDict_Registry)
        EngineLogWrite("SETTINGS", "locations", "save_to_ini", "checkbox_changes", "SAVED")
    EndIf
EndFunc

Func GUILocationsHandleMessage($msg, $controls, ByRef $foldersDict, ByRef $regTokensDict)
    If Not IsArray($controls) Then Return

    $g_LocationsDict_Folders = $foldersDict
    $g_LocationsDict_Registry = $regTokensDict

    ; If confirmation is showing, only handle OK/Cancel
    If $g_LocationsDeleteConfirmVisible Then
        If $msg = $controls[7] Then ; OK
            _LocationsDeleteItemConfirmed($foldersDict, $regTokensDict, $controls)
            _LocationsHideDeleteConfirm($controls)
            GUICtrlSetState($g_LocationsListView, $GUI_ENABLE)
            GUICtrlSetData($controls[4], "")
            GUICtrlSetState($controls[4], $GUI_HIDE)
            GUICtrlSetState($controls[3], $GUI_HIDE)
            GUICtrlSetState($controls[2], $GUI_HIDE)
        ElseIf $msg = $controls[8] Then ; Cancel
            _LocationsHideDeleteConfirm($controls)
            GUICtrlSetState($g_LocationsListView, $GUI_ENABLE)
        Else
            Return
        EndIf
    EndIf

    Switch $msg
        Case $g_LocationsContextMenu_AddRegistry
            $g_LocationsInputMode = "add_registry"
            GUICtrlSetData($controls[4], "")
            GUICtrlSetState($controls[4], $GUI_SHOW)
            GUICtrlSetState($controls[2], $GUI_SHOW)
            GUICtrlSetState($controls[4], $GUI_FOCUS)
            GUICtrlSetState($controls[3], $GUI_HIDE)

        Case $g_LocationsContextMenu_AddFolder
            _LocationsBrowseFolder($foldersDict, $regTokensDict)

        Case $g_LocationsContextMenu_OpenRegEdit
            Run("regedit.exe")

        Case $g_LocationsContextMenu_Edit
            Local $selected = _GUICtrlListView_GetSelectedIndices($g_LocationsListView)
            If $selected = "" Then
                MsgBox(48, " No Selection", "Please select an item to edit. ")
                Return
            EndIf
            Local $index = Int($selected)
            $g_LocationsEditIndex = $index
            $g_LocationsInputMode = "edit"
            Local $oldPath = _GUICtrlListView_GetItemText($g_LocationsListView, $index, 1)
            GUICtrlSetData($controls[4], $oldPath)
            GUICtrlSetState($controls[4], $GUI_SHOW)
            GUICtrlSetState($controls[3], $GUI_SHOW)
            GUICtrlSetState($controls[4], $GUI_FOCUS)
            GUICtrlSetState($controls[2], $GUI_HIDE)

        Case $controls[3] ; Confirm edit button
            If $g_LocationsEditIndex < 0 Then Return
            Local $oldPath = _GUICtrlListView_GetItemText($g_LocationsListView, $g_LocationsEditIndex, 1)
            Local $type = _GUICtrlListView_GetItemText($g_LocationsListView, $g_LocationsEditIndex, 2)
            Local $newPath = GUICtrlRead($controls[4])
            GUICtrlSetState($controls[4], $GUI_HIDE)
            GUICtrlSetState($controls[3], $GUI_HIDE)
            GUICtrlSetState($controls[2], $GUI_HIDE)
            $g_LocationsEditIndex = -1
            $g_LocationsInputMode = ""
            If StringStripWS($newPath, 3) = "" Or $newPath = $oldPath Then Return
            If Not _LocationsValidatePath($newPath) Then Return
            If $type = "Folder" And IsObj($foldersDict) And $foldersDict.Exists($oldPath) Then
                Local $enabled = $foldersDict.Item($oldPath)
                $foldersDict.Remove($oldPath)
                $foldersDict.Item($newPath) = $enabled
            ElseIf $type = "Registry" And IsObj($regTokensDict) And $regTokensDict.Exists($oldPath) Then
                Local $enabled = $regTokensDict.Item($oldPath)
                $regTokensDict.Remove($oldPath)
                $regTokensDict.Item($newPath) = $enabled
            EndIf
            ConfigSaveLocations($foldersDict, $regTokensDict)
            _LocationsPopulateList($foldersDict, $regTokensDict)
            EngineLogWrite("SETTINGS", "locations", "edit_" & StringLower($type), $oldPath & " -> " & $newPath, "UPDATED")

        Case $controls[2] ; Add Registry button
            Local $token = GUICtrlRead($controls[4])
            GUICtrlSetState($controls[4], $GUI_HIDE)
            GUICtrlSetState($controls[2], $GUI_HIDE)
            GUICtrlSetState($controls[3], $GUI_HIDE)
            $g_LocationsInputMode = ""
            If StringStripWS($token, 3) = "" Then Return
            If Not _LocationsValidatePath($token) Then Return
            If $regTokensDict.Exists($token) Then
                MsgBox(48, "Duplicate", "This registry token is already in the list.")
                Return
            EndIf
            $regTokensDict.Item($token) = "1"
            ConfigSaveLocations($foldersDict, $regTokensDict)
            _LocationsPopulateList($foldersDict, $regTokensDict)
            EngineLogWrite("SETTINGS", "locations", "add_registry", $token, "ADDED")

        Case $g_LocationsContextMenu_Remove
            _LocationsShowDeleteConfirm($controls)
            Local $selected = _GUICtrlListView_GetSelectedIndices($g_LocationsListView)
            If $selected <> "" Then
                GUICtrlSetState($g_LocationsListView, $GUI_DISABLE)
            EndIf

        Case $g_LocationsContextMenu_Refresh
            _LocationsPopulateList($foldersDict, $regTokensDict)

        Case $g_LocationsListView
            ; Do nothing here for edit field
    EndSwitch
EndFunc

Func _LocationsShowDeleteConfirm($controls)
    Local $selected = _GUICtrlListView_GetSelectedIndices($g_LocationsListView)
    If $selected = "" Then
        GUICtrlSetData($controls[5], " No selection. Please select an item to Remove. ")
        GUICtrlSetState($controls[5], $GUI_SHOW)
        GUICtrlSetState($controls[7], $GUI_HIDE)
        GUICtrlSetState($controls[8], $GUI_HIDE)
        GUICtrlSetData($controls[6], "")
        GUICtrlSetData($controls[4], "")
        GUICtrlSetState($controls[4], $GUI_HIDE)
        GUICtrlSetState($controls[3], $GUI_HIDE)
        GUICtrlSetState($controls[2], $GUI_HIDE)
        AdlibRegister("_LocationsHideNoSelectionMessage", 2000)
        Return
    EndIf

    Local $index = Int($selected)
    Local $path = _GUICtrlListView_GetItemText($g_LocationsListView, $index, 1)
    Local $type = _GUICtrlListView_GetItemText($g_LocationsListView, $index, 2)
    GUICtrlSetData($controls[5], " Are you sure you want to remove this " & StringLower($type) & " location? ")
    GUICtrlSetState($controls[5], $GUI_SHOW)
    GUICtrlSetState($controls[7], $GUI_SHOW)
    GUICtrlSetState($controls[8], $GUI_SHOW)
    GUICtrlSetData($controls[6], $path)
    GUICtrlSetState($controls[6], $GUI_SHOW)
    GUICtrlSetState($controls[4], $GUI_HIDE)
    GUICtrlSetState($controls[3], $GUI_HIDE)
    GUICtrlSetState($controls[2], $GUI_HIDE)
    $g_LocationsDeleteConfirmVisible = True
EndFunc

Func _LocationsHideNoSelectionMessage()
    GUICtrlSetState($g_LocationsControls[5], $GUI_HIDE)
    AdlibUnRegister("_LocationsHideNoSelectionMessage")
    $g_LocationsDeleteConfirmVisible = False
EndFunc

Func _LocationsHideDeleteConfirm($controls)
    GUICtrlSetState($controls[5], $GUI_HIDE)
    GUICtrlSetState($controls[7], $GUI_HIDE)
    GUICtrlSetState($controls[8], $GUI_HIDE)
    GUICtrlSetState($controls[6], $GUI_HIDE)
    GUICtrlSetState($controls[4], $GUI_HIDE)
    GUICtrlSetState($controls[3], $GUI_HIDE)
    GUICtrlSetState($controls[2], $GUI_HIDE)
    $g_LocationsDeleteConfirmVisible = False
EndFunc

Func _LocationsDeleteItemConfirmed(ByRef $foldersDict, ByRef $regTokensDict, $controls)
    Local $selected = _GUICtrlListView_GetSelectedIndices($g_LocationsListView)
    If $selected = "" Then Return

    Local $index = Int($selected)
    Local $path = _GUICtrlListView_GetItemText($g_LocationsListView, $index, 1)
    Local $type = _GUICtrlListView_GetItemText($g_LocationsListView, $index, 2)

    If $type = "Folder" And IsObj($foldersDict) And $foldersDict.Exists($path) Then
        $foldersDict.Remove($path)
    ElseIf $type = "Registry" And IsObj($regTokensDict) And $regTokensDict.Exists($path) Then
        $regTokensDict.Remove($path)
    EndIf

    ConfigSaveLocations($foldersDict, $regTokensDict)
    _LocationsPopulateList($foldersDict, $regTokensDict)
    EngineLogWrite("SETTINGS", "locations", "remove_" & StringLower($type), $path, "REMOVED")
EndFunc

Func GUILocationsCleanup()
    AdlibUnRegister("_LocationsMonitorCheckboxes")
    $g_LocationsCheckTimer = 0
    $g_LocationsDict_Folders = 0
    $g_LocationsDict_Registry = 0
EndFunc

;~ Func GUILocationsApply($controls, ByRef $foldersDict, ByRef $regTokensDict)
;~     ConfigSaveLocations($foldersDict, $regTokensDict)
;~ EndFunc

Func _LocationsPopulateList($foldersDict, $regTokensDict)
    _GUICtrlListView_DeleteAllItems($g_LocationsListView)

    If IsObj($foldersDict) Then
        For $path In $foldersDict.Keys
            Local $enabled = $foldersDict.Item($path)
            Local $index = _GUICtrlListView_AddItem($g_LocationsListView, "")
            _GUICtrlListView_AddSubItem($g_LocationsListView, $index, $path, 1)
            _GUICtrlListView_AddSubItem($g_LocationsListView, $index, "Folder", 2)
            _GUICtrlListView_SetItemChecked($g_LocationsListView, $index, ($enabled = "1"))
        Next
    EndIf

    If IsObj($regTokensDict) Then
        For $token In $regTokensDict.Keys
            Local $enabled = $regTokensDict.Item($token)
            Local $index = _GUICtrlListView_AddItem($g_LocationsListView, "")
            _GUICtrlListView_AddSubItem($g_LocationsListView, $index, $token, 1)
            _GUICtrlListView_AddSubItem($g_LocationsListView, $index, "Registry", 2)
            _GUICtrlListView_SetItemChecked($g_LocationsListView, $index, ($enabled = "1"))
        Next
    EndIf
EndFunc

Func _LocationsBrowseFolder(ByRef $foldersDict, ByRef $regTokensDict)
    Local $folder = FileSelectFolder("Select folder to monitor", "")
    If @error Or $folder = "" Then Return

    $foldersDict.Item($folder) = "1"
    ConfigSaveLocations($foldersDict, $regTokensDict)
    _LocationsPopulateList($foldersDict, $regTokensDict)
    EngineLogWrite("SETTINGS", "locations", "browse_add", $folder, "ADDED")
EndFunc

Func _LocationsValidatePath($path)
    If StringLen($path) < 3 Then
        MsgBox(48, "Invalid Path", "Path is too short.")
        Return False
    EndIf

    Local $invalidChars = '<>"|*?'
    For $i = 1 To StringLen($invalidChars)
        If StringInStr($path, StringMid($invalidChars, $i, 1)) Then
            MsgBox(48, "Invalid Path", "Path contains invalid characters: " & $invalidChars)
            Return False
        EndIf
    Next

    Return True
EndFunc
