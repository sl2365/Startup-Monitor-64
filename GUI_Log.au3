; GUI_Log.au3

#include-once
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <EditConstants.au3>
#include <ButtonConstants.au3>
#include <File.au3>

Func GUILogCreate($parentGUI, $x, $y, $width, $height)
    Local $editCtrl = GUICtrlCreateEdit("", $x, $y, $width, $height - 50, $ES_READONLY + $WS_VSCROLL)
    Local $deleteBtn = GUICtrlCreateButton("Delete Log File", $x + $width - 120, $y + $height - 40, 100, 30)
    Local $controls[2] = [$editCtrl, $deleteBtn]
    Return $controls
EndFunc

Func GUILogShowFile($controls)
    If Not IsArray($controls) Or UBound($controls) < 1 Then Return
    
    Local $logFile = @ScriptDir & "\App\Log.ini"
    Local $logContent = ""
    
    If FileExists($logFile) Then
        Local $fileContent = FileRead($logFile)
        If @error Then
            $logContent = "(Error reading Log.ini)"
        Else
            $logContent = $fileContent
        EndIf
    Else
        $logContent = "(Log.ini does not exist)"
    EndIf
    
    GUICtrlSetData($controls[0], $logContent)
EndFunc

Func GUILogDeleteLog($controls)
    If Not IsArray($controls) Or UBound($controls) < 1 Then Return
    
    Local $logFile = @ScriptDir & "\App\Log.ini"
    If FileExists($logFile) Then
        FileDelete($logFile)
        If @error Then
            MsgBox(16, "Error", "Failed to delete Log.ini")
        Else
            MsgBox(64, "Log.ini", "Log.ini deleted.")
        EndIf
    Else
        MsgBox(48, "Log.ini", "Log.ini does not exist.")
    EndIf
    GUILogShowFile($controls)
EndFunc
