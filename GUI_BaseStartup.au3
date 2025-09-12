; GUI_BaseStartup.au3

#include-once
#include <GUIConstantsEx.au3>
#include <ListViewConstants.au3>
#include <GuiListView.au3>
#include <Clipboard.au3>
#include "GUI_Settings.au3"

Global $g_BaseStartupListView = 0
Global $g_BaseStartupMsgLabel = 0
Global $g_LastBaseStartupSelected = -1

; =================================================================
; BASE STARTUP TAB CREATION
; =================================================================
Func GUIBaseStartupCreate($parentGUI, $x, $y, $width, $height, $baseFoldersDict, $baseRegDict)
    $g_BaseStartupListView = GUICtrlCreateListView("#|Name|Type|Location/Path|Hash", $x + 10, $y + 10, $width - 20, $height - 60, _
        BitOR($LVS_REPORT, $LVS_SHOWSELALWAYS), BitOR($LVS_EX_FULLROWSELECT, $LVS_EX_GRIDLINES))

    _GUICtrlListView_SetColumnWidth($g_BaseStartupListView, 0, 40)
    _GUICtrlListView_SetColumnWidth($g_BaseStartupListView, 1, 150)
    _GUICtrlListView_SetColumnWidth($g_BaseStartupListView, 2, 55)
    _GUICtrlListView_SetColumnWidth($g_BaseStartupListView, 3, $width - 365)
    _GUICtrlListView_SetColumnWidth($g_BaseStartupListView, 4, 70)

    GUICtrlCreateLabel("Baseline Startup entries (read-only) - Detected on first run", $x + 10, $y + $height - 40, $width - 20, 20)

    ; Message label at bottom, hidden by default
    $g_BaseStartupMsgLabel = GUICtrlCreateLabel("", $x + 10, $y + $height - 40, $width - 80, 50)
    GUICtrlSetFont($g_BaseStartupMsgLabel, 10, 600)
    GUICtrlSetBkColor($g_BaseStartupMsgLabel, 0xFFF9E3) ; soft yellow
    GUICtrlSetColor($g_BaseStartupMsgLabel, 0x9C8500)   ; dark goldenrod
    GUICtrlSetState($g_BaseStartupMsgLabel, $GUI_HIDE)

    _BaseStartupPopulateList($baseFoldersDict, $baseRegDict)

    Return 0
EndFunc

; =================================================================
; BASE STARTUP TAB MESSAGE HANDLING
; =================================================================
Func GUIBaseStartupHandleMessage($msg, $controls)
    ; Poll for selection change every loop
    Local $selected = _GUICtrlListView_GetSelectedIndices($g_BaseStartupListView)
    If $selected <> "" Then
        Local $index = Int($selected)
        If $index <> $g_LastBaseStartupSelected Then
            $g_LastBaseStartupSelected = $index
            Local $loc = _GUICtrlListView_GetItemText($g_BaseStartupListView, $index, 3)
            If $loc <> "" Then
                GUICtrlSetData($g_BaseStartupMsgLabel, "Location/Path: " & _SmartWordWrap($loc))
                GUICtrlSetState($g_BaseStartupMsgLabel, $GUI_SHOW)
                ; Copy path/location value to clipboard
                _ClipBoard_Open(0)
                _ClipBoard_SetData($loc)
                _ClipBoard_Close()
                ToolTip("Path copied!", MouseGetPos(0), MouseGetPos(1))
                Sleep(600)
                ToolTip("")
            Else
                GUICtrlSetState($g_BaseStartupMsgLabel, $GUI_HIDE)
            EndIf
        EndIf
    Else
        If $g_LastBaseStartupSelected <> -1 Then
            $g_LastBaseStartupSelected = -1
            GUICtrlSetState($g_BaseStartupMsgLabel, $GUI_HIDE)
        EndIf
    EndIf
EndFunc

; =================================================================
; BASE STARTUP TAB HELPER FUNCTIONS
; =================================================================
Func _BaseStartupPopulateList($baseFoldersDict, $baseRegDict)
    _GUICtrlListView_DeleteAllItems($g_BaseStartupListView)

    Local $index = 0

    If IsObj($baseFoldersDict) Then
        For $key In $baseFoldersDict.Keys
            Local $hash = $baseFoldersDict.Item($key)
            Local $name = _BaseStartupGetDisplayName($key)
            Local $itemIndex = _GUICtrlListView_AddItem($g_BaseStartupListView, $index + 1)
            _GUICtrlListView_AddSubItem($g_BaseStartupListView, $itemIndex, $name, 1)
            _GUICtrlListView_AddSubItem($g_BaseStartupListView, $itemIndex, "File", 2)
            _GUICtrlListView_AddSubItem($g_BaseStartupListView, $itemIndex, $key, 3)
            _GUICtrlListView_AddSubItem($g_BaseStartupListView, $itemIndex, $hash, 4)
            $index += 1
        Next
    EndIf

    If IsObj($baseRegDict) Then
        For $key In $baseRegDict.Keys
            Local $hash = $baseRegDict.Item($key)
            Local $name = _BaseStartupGetDisplayName($key)
            Local $itemIndex = _GUICtrlListView_AddItem($g_BaseStartupListView, $index + 1)
            _GUICtrlListView_AddSubItem($g_BaseStartupListView, $itemIndex, $name, 1)
            _GUICtrlListView_AddSubItem($g_BaseStartupListView, $itemIndex, "Registry", 2)
            _GUICtrlListView_AddSubItem($g_BaseStartupListView, $itemIndex, $key, 3)
            _GUICtrlListView_AddSubItem($g_BaseStartupListView, $itemIndex, $hash, 4)
            $index += 1
        Next
    EndIf
EndFunc

Func _BaseStartupGetDisplayName($key)
    Local $pos = StringInStr($key, "\", 0, -1)
    If $pos > 0 Then Return StringTrimLeft($key, $pos)
    $pos = StringInStr($key, "|", 0, -1)
    If $pos > 0 Then Return StringTrimLeft($key, $pos)
    Return $key
EndFunc
