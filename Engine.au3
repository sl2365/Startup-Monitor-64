; Engine.au3

#include-once
#include <Date.au3>
#include "Scanners.au3"

Global Const $ENGINE_LOG_FILE = @ScriptDir & "\App\Log.ini"

; =================================================================
; LOGGING FUNCTIONS
; =================================================================
Func EngineInitializeLogging($settingsDict)
    Local $clearOnStart = ($settingsDict.Exists("ClearLogOnStart") And $settingsDict.Item("ClearLogOnStart") = "1")
    
    If $clearOnStart Then
        FileDelete($ENGINE_LOG_FILE)
        FileWrite($ENGINE_LOG_FILE, "")
    Else
        _EnginePruneOldLogEntries()
    EndIf
EndFunc

Func _EnginePruneOldLogEntries()
    If Not FileExists($ENGINE_LOG_FILE) Then Return
    
    Local $content = FileRead($ENGINE_LOG_FILE)
    If $content = "" Then Return
    
    Local $lines = StringSplit($content, @CRLF, 1)
    Local $newContent = ""
    Local $cutoffDate = _DateAdd("D", -30, _NowCalcDate()) ; 30 days ago
    
    For $i = 1 To $lines[0]
        Local $line = $lines[$i]
        If StringLen($line) < 19 Then ContinueLoop ; Skip malformed lines
        
        Local $dateStr = StringLeft($line, 10) ; YYYY-MM-DD
        If $dateStr >= $cutoffDate Then
            $newContent &= $line & @CRLF
        EndIf
    Next
    
    FileDelete($ENGINE_LOG_FILE)
    FileWrite($ENGINE_LOG_FILE, $newContent)
EndFunc

Func EngineLogWrite($event, $type, $key, $detail, $status)
    Local $timestamp = @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC
    Local $logEntry = $timestamp & " | " & $event & " | " & $type & " | " & $key & " | " & $detail & " | " & $status & @CRLF
    FileWrite($ENGINE_LOG_FILE, $logEntry)
EndFunc

; =================================================================
; MAIN MONITORING ENGINE
; =================================================================
Func EngineMonitorTick($settingsDict, $foldersDict, $regTokensDict, $allowedDict, $deniedDict, _
    $baseFoldersDict, $baseRegDict, $baseTasksDict, $cancelledItems, $cachedTasks = 0)
    
    Local $reviewItems[0][7] ; [key, displayName, type, detail, status, hash, checked]
    Local $monitorTasks = ($settingsDict.Exists("MonitorTasks") And $settingsDict.Item("MonitorTasks") = "1")
    Local $monitorRegistry = ($settingsDict.Exists("Registry") And $settingsDict.Item("Registry") = "1")
    
    ; --- Profile folder scan ---
    Local $t = TimerInit()
    Local $currentFiles = ScannersGetFolders($foldersDict)
    If IsArray($currentFiles) And UBound($currentFiles) > 0 Then
        $t = TimerInit()
        For $i = 0 To UBound($currentFiles) - 1
            Local $path = $currentFiles[$i][0]
            Local $hash = $currentFiles[$i][1]
            Local $fileName = _EngineGetFileName($path)
            
            _EngineProcessItem($path, $fileName, "file", $path, $hash, $allowedDict, $deniedDict, _
                $baseFoldersDict, $cancelledItems, $reviewItems)
        Next
    EndIf
    
    ; --- Profile registry scan ---
    If $monitorRegistry Then
        $t = TimerInit()
        Local $currentRegistry = ScannersGetRegistry($regTokensDict)
        If IsArray($currentRegistry) And UBound($currentRegistry) > 0 Then
            $t = TimerInit()
            For $i = 0 To UBound($currentRegistry) - 1
                Local $regKey = $currentRegistry[$i][0]
                Local $hash = $currentRegistry[$i][1]
                Local $valueName = _EngineGetRegistryValueName($regKey)
                
                _EngineProcessItem($regKey, $valueName, "reg", $regKey, $hash, $allowedDict, $deniedDict, _
                    $baseRegDict, $cancelledItems, $reviewItems)
            Next
        EndIf
    EndIf
    
    ; --- Profile tasks scan ---
    If $monitorTasks And IsObj($cachedTasks) And $cachedTasks.Count > 0 Then
        $t = TimerInit()
        For $taskName In $cachedTasks.Keys
            Local $command = $cachedTasks.Item($taskName)
            Local $hash = _EngineHashString($taskName & "|" & $command)
            
            _EngineProcessItem($taskName, $taskName, "task", $command, $hash, $allowedDict, $deniedDict, _
                $baseTasksDict, $cancelledItems, $reviewItems)
        Next
    EndIf
    
    Return $reviewItems
EndFunc

; =================================================================
; ITEM PROCESSING
; =================================================================
Func _EngineProcessItem($key, $displayName, $type, $detail, $hash, $allowedDict, $deniedDict, _
    $baselineDict, $cancelledItems, ByRef $reviewItems)
    
    ; Skip if cancelled within last 60 minutes
    If IsObj($cancelledItems) And $cancelledItems.Exists($key) Then Return
    
    Local $isAllowed = (IsObj($allowedDict) And $allowedDict.Exists($key))
    Local $isDenied = (IsObj($deniedDict) And $deniedDict.Exists($key))
    Local $isInBaseline = (IsObj($baselineDict) And $baselineDict.Exists($key))
    
    Local $shouldInclude = False
    Local $status = 0 ; 0=new, 1=allowed, 2=denied
    Local $checked = False
    
    ; PRIORITY 1: Check if item is in ALLOWED list (skip if allowed and hash matches)
    If $isAllowed Then
        Local $allowedHash = $allowedDict.Item($key)
        If $allowedHash = $hash Then
            ; Item is allowed with same hash - skip completely
            Return
        Else
            ; Item is allowed but hash changed - treat as modified
            $status = 0
            $checked = True
            $shouldInclude = True
            EngineLogWrite("DETECT_MODIFIED", $type, $key, $detail, "ALLOWED_ITEM_MODIFIED")
        EndIf
    
    ; PRIORITY 2: Check if item is in BASELINE (skip if in baseline and hash matches)
    ElseIf $isInBaseline Then
        Local $baselineHash = $baselineDict.Item($key)
        If $baselineHash = $hash Then
            ; Item exists in baseline with same hash - ignore completely
            Return
        Else
            ; Item modified from baseline - alert for review
            $status = 0
            $checked = True
            $shouldInclude = True
            EngineLogWrite("DETECT_MODIFIED", $type, $key, $detail, "BASELINE_ITEM_MODIFIED")
        EndIf
    
    ; PRIORITY 3: Everything else is NEW and should be alerted
    Else
        ; This is a new item that wasn't in allowed list or baseline
        ; Check if it was previously denied (for logging purposes and default selection)
        If $isDenied Then
            ; Item was previously denied but is back - alert and default to denied
            $status = 0
            $checked = False ; Default to denied since it was previously denied
            $shouldInclude = True
            EngineLogWrite("DETECT_RECREATED", $type, $key, $detail, "RECREATED_AFTER_DENIAL")
        Else
            ; Item is completely new
            $status = 0
            $checked = True ; Default to allowed for truly new items
            $shouldInclude = True
            EngineLogWrite("DETECT_NEW", $type, $key, $detail, "NEW_ITEM")
        EndIf
    EndIf
    
    If $shouldInclude Then
        Local $currentSize = UBound($reviewItems, 1)
        ReDim $reviewItems[$currentSize + 1][7]
        $reviewItems[$currentSize][0] = $key
        $reviewItems[$currentSize][1] = $displayName
        $reviewItems[$currentSize][2] = $type
        $reviewItems[$currentSize][3] = $detail
        $reviewItems[$currentSize][4] = $status
        $reviewItems[$currentSize][5] = $hash
        $reviewItems[$currentSize][6] = $checked
    EndIf
EndFunc

; =================================================================
; ITEM REMOVAL FUNCTIONS
; =================================================================
Func EngineRemoveStartupItem($key, $type)
    Local $success = False
    
    Switch $type
        Case "file"
            ; Remove file
            If FileExists($key) Then
                FileDelete($key)
                $success = (Not FileExists($key))
                EngineLogWrite("REMOVE_FILE", $type, $key, $key, $success ? "SUCCESS" : "FAILED")
            EndIf
            
        Case "reg"
            ; Parse registry key: HIVE\SubKey|ValueName
            Local $pos = StringInStr($key, "|", 0, -1)
            If $pos > 0 Then
                Local $regPath = StringLeft($key, $pos - 1)
                Local $valueName = StringTrimLeft($key, $pos)
                RegDelete($regPath, $valueName)
                ; Check if deletion was successful
                Local $testRead = RegRead($regPath, $valueName)
                $success = (@error <> 0) ; Success if RegRead fails (value doesn't exist)
                EngineLogWrite("REMOVE_REGISTRY", $type, $key, $regPath & "\" & $valueName, $success ? "SUCCESS" : "FAILED")
            EndIf
            
        Case "task"
            ; Remove scheduled task
            Local $cmd = @ComSpec & ' /c schtasks /delete /tn "' & $key & '" /f'
            Local $result = RunWait($cmd, "", @SW_HIDE)
            $success = ($result = 0)
            EngineLogWrite("REMOVE_TASK", $type, $key, $key, $success ? "SUCCESS" : "FAILED")
    EndSwitch
    
    Return $success
EndFunc

; =================================================================
; UTILITY FUNCTIONS
; =================================================================
Func _EngineGetFileName($fullPath)
    Local $pos = StringInStr($fullPath, "\", 0, -1)
    If $pos = 0 Then Return $fullPath
    Return StringTrimLeft($fullPath, $pos)
EndFunc

Func _EngineGetRegistryValueName($regKey)
    Local $pos = StringInStr($regKey, "|", 0, -1)
    If $pos = 0 Then Return $regKey
    Return StringTrimLeft($regKey, $pos)
EndFunc

Func _EngineHashString($input)
    ; Simple hash function
    Local $hash = 0
    For $i = 1 To StringLen($input)
        $hash = Mod($hash * 31 + Asc(StringMid($input, $i, 1)), 2147483647)
    Next
    Return Hex($hash, 8)
EndFunc
