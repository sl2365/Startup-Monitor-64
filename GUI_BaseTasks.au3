; GUI_BaseTasks.au3

#include-once
#include <GUIConstantsEx.au3>
#include <ListViewConstants.au3>
#include <GuiListView.au3>
#include <Clipboard.au3>
#include "GUI_Settings.au3"

Global $g_BaseTasksListView = 0
Global $g_BaseTasksMsgLabel = 0
Global $g_LastBaseTasksSelected = -1

; =================================================================
; BASE TASKS TAB CREATION
; =================================================================
Func GUIBaseTasksCreate($parentGUI, $x, $y, $width, $height, $baseTasksDict)
    $g_BaseTasksListView = GUICtrlCreateListView("#|Task Name|Type|Command|Hash", $x + 10, $y + 10, $width - 20, $height - 60, _
        BitOR($LVS_REPORT, $LVS_SHOWSELALWAYS), BitOR($LVS_EX_FULLROWSELECT, $LVS_EX_GRIDLINES))
    
    _GUICtrlListView_SetColumnWidth($g_BaseTasksListView, 0, 40)
    _GUICtrlListView_SetColumnWidth($g_BaseTasksListView, 1, 150)
    _GUICtrlListView_SetColumnWidth($g_BaseTasksListView, 2, 55)
    _GUICtrlListView_SetColumnWidth($g_BaseTasksListView, 3, $width - 365)
    _GUICtrlListView_SetColumnWidth($g_BaseTasksListView, 4, 70)
    
    GUICtrlCreateLabel("Baseline tasks (read-only) - Detected on first run", $x + 10, $y + $height - 40, $width - 20, 20)
    
    $g_BaseTasksMsgLabel = GUICtrlCreateLabel("", $x + 10, $y + $height - 40, $width - 80, 50)
    GUICtrlSetFont($g_BaseTasksMsgLabel, 10, 700)
    GUICtrlSetBkColor($g_BaseTasksMsgLabel, 0xDAF2DA)
    GUICtrlSetColor($g_BaseTasksMsgLabel, 0x005A00)
    GUICtrlSetState($g_BaseTasksMsgLabel, $GUI_HIDE)

    _BaseTasksPopulateList($baseTasksDict)
    
    Return 0
EndFunc

; =================================================================
; BASE TASKS TAB MESSAGE HANDLING
; =================================================================
Func GUIBaseTasksHandleMessage($msg, $controls)
    Local $selected = _GUICtrlListView_GetSelectedIndices($g_BaseTasksListView)
    If $selected <> "" Then
        Local $index = Int($selected)
        If $index <> $g_LastBaseTasksSelected Then
            $g_LastBaseTasksSelected = $index
            Local $command = _GUICtrlListView_GetItemText($g_BaseTasksListView, $index, 3)
            If $command <> "" Then
                GUICtrlSetData($g_BaseTasksMsgLabel, "Command: " & _SmartWordWrap($command))
                GUICtrlSetState($g_BaseTasksMsgLabel, $GUI_SHOW)
                _ClipBoard_Open(0)
                _ClipBoard_SetData($command)
                _ClipBoard_Close()
                ToolTip("Command copied!", MouseGetPos(0), MouseGetPos(1))
                Sleep(600)
                ToolTip("")
            Else
                GUICtrlSetState($g_BaseTasksMsgLabel, $GUI_HIDE)
            EndIf
        EndIf
    Else
        If $g_LastBaseTasksSelected <> -1 Then
            $g_LastBaseTasksSelected = -1
            GUICtrlSetState($g_BaseTasksMsgLabel, $GUI_HIDE)
        EndIf
    EndIf
EndFunc

; =================================================================
; BASE TASKS TAB HELPER FUNCTIONS
; =================================================================
Func _BaseTasksPopulateList($baseTasksDict)
    _GUICtrlListView_DeleteAllItems($g_BaseTasksListView)
    
    If Not IsObj($baseTasksDict) Then Return
    
    Local $index = 0
    For $taskName In $baseTasksDict.Keys
        Local $hash = $baseTasksDict.Item($taskName)
        Local $itemIndex = _GUICtrlListView_AddItem($g_BaseTasksListView, $index + 1)
        _GUICtrlListView_AddSubItem($g_BaseTasksListView, $itemIndex, $taskName, 1)
        _GUICtrlListView_AddSubItem($g_BaseTasksListView, $itemIndex, "Task", 2)
        _GUICtrlListView_AddSubItem($g_BaseTasksListView, $itemIndex, $taskName, 3)
        _GUICtrlListView_AddSubItem($g_BaseTasksListView, $itemIndex, $hash, 4)
        $index += 1
    Next
EndFunc
