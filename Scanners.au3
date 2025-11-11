; Scanners.au3

#include-once
#include <File.au3>

; =================================================================
; FOLDER SCANNING
; =================================================================
Func ScannersGetFolders($foldersDict)
    Local $results[0][2] ; [path, hash]
    
    If Not IsObj($foldersDict) Then Return $results
    
    For $pathTemplate In $foldersDict.Keys
        Local $enabled = $foldersDict.Item($pathTemplate)
        If $enabled <> "1" Then ContinueLoop
        
        Local $expandedPath = _ScannersExpandEnvironmentVars($pathTemplate)
        If Not FileExists($expandedPath) Then ContinueLoop
        
        Local $files = _FileListToArray($expandedPath, "*", 1) ; Files only
        If @error Or Not IsArray($files) Then ContinueLoop
        
        For $i = 1 To $files[0]
            Local $fullPath = $expandedPath & "\" & $files[$i]
            Local $hash = _ScannersHashString($fullPath)
            
            ; Add to results
            Local $currentSize = UBound($results, 1)
            ReDim $results[$currentSize + 1][2]
            $results[$currentSize][0] = $fullPath
            $results[$currentSize][1] = $hash
        Next
    Next
    
    Return $results
EndFunc

; =================================================================
; REGISTRY SCANNING
; =================================================================
; Corrected ScannersGetRegistry function (replace the existing one in Scanners.au3)
Func ScannersGetRegistry($regTokensDict)
    Local $results[0][2] ; [key, hash]
    Local $tokenMap = _ScannersGetRegistryTokenMap()
    
    If Not IsObj($regTokensDict) Then Return $results
    
    For $token In $regTokensDict.Keys
        Local $enabled = $regTokensDict.Item($token)
        ; Accept explicit "1" or the mapping string (if tokenMap was passed directly)
        If $enabled <> "1" And ( $tokenMap.Exists($token) And $enabled <> $tokenMap.Item($token) ) Then ContinueLoop
        If Not $tokenMap.Exists($token) Then ContinueLoop
        
        Local $mapping = $tokenMap.Item($token)
        ; Correct use of StringSplit: parts count is in parts[0], substrings start at index 1
        Local $parts = StringSplit($mapping, "|")
        If $parts[0] < 2 Then ContinueLoop ; need at least HIVE and SUBKEY
        
        Local $hive = $parts[1]
        Local $subkey = $parts[2]
        Local $specificValue = ""
        If $parts[0] >= 3 Then $specificValue = $parts[3]
        Local $fullKey = $hive & "\" & $subkey
        
        If $specificValue <> "" Then
            ; Monitor specific value only
            Local $data = RegRead($fullKey, $specificValue)
            If @error = 0 Then
                Local $regKey = $fullKey & "|" & $specificValue
                Local $combinedData = $regKey & "|" & $data
                Local $hash = _ScannersHashString($combinedData)
                
                Local $currentSize = UBound($results, 1)
                ReDim $results[$currentSize + 1][2]
                $results[$currentSize][0] = $regKey
                $results[$currentSize][1] = $hash
            EndIf
        Else
            ; Enumerate all values in the key
            Local $valueIndex = 1
            While 1
                Local $valueName = RegEnumVal($fullKey, $valueIndex)
                If @error Then ExitLoop
                
                Local $data = RegRead($fullKey, $valueName)
                If @error = 0 Then
                    ; Use the actual value name (empty string means default value)
                    Local $regKey = $fullKey & "|" & $valueName
                    Local $combinedData = $regKey & "|" & $data
                    Local $hash = _ScannersHashString($combinedData)
                    
                    Local $currentSize = UBound($results, 1)
                    ReDim $results[$currentSize + 1][2]
                    $results[$currentSize][0] = $regKey
                    $results[$currentSize][1] = $hash
                EndIf
                
                $valueIndex += 1
            WEnd
        EndIf
    Next
    
    Return $results
EndFunc

Func _ScannersGetRegistryTokenMap()
    Local $map = ObjCreate("Scripting.Dictionary")
    
    ; Format: HIVE|SUBKEY|SPECIFIC_VALUE (empty = enumerate all values)
    $map.Item("HKCU_Run") = "HKCU|Software\Microsoft\Windows\CurrentVersion\Run|"
    $map.Item("HKLM_Run") = "HKLM|Software\Microsoft\Windows\CurrentVersion\Run|"
    $map.Item("HKCU_RunOnce") = "HKCU|Software\Microsoft\Windows\CurrentVersion\RunOnce|"
    $map.Item("HKLM_RunOnce") = "HKLM|Software\Microsoft\Windows\CurrentVersion\RunOnce|"
    $map.Item("HKCU_Explorer_UserShellFolders") = "HKCU|Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders|"
    $map.Item("HKCU_Explorer_ShellFolders") = "HKCU|Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders|"
    $map.Item("HKLM_Explorer_ShellFolders") = "HKLM|Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders|"
    $map.Item("HKLM_Explorer_UserShellFolders") = "HKLM|Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders|"
    $map.Item("HKLM_RunServicesOnce") = "HKLM|Software\Microsoft\Windows\CurrentVersion\RunServicesOnce|"
    $map.Item("HKCU_RunServicesOnce") = "HKCU|Software\Microsoft\Windows\CurrentVersion\RunServicesOnce|"
    $map.Item("HKLM_RunServices") = "HKLM|Software\Microsoft\Windows\CurrentVersion\RunServices|"
    $map.Item("HKCU_RunServices") = "HKCU|Software\Microsoft\Windows\CurrentVersion\RunServices|"
    $map.Item("HKLM_Policies_Explorer_Run") = "HKLM|Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run|"
    $map.Item("HKCU_Policies_Explorer_Run") = "HKCU|Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run|"
    $map.Item("HKLM_Winlogon_Userinit") = "HKLM|SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon|Userinit"
    $map.Item("HKLM_Winlogon_Shell") = "HKLM|SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon|Shell"
    $map.Item("HKCU_Windows") = "HKCU|Software\Microsoft\Windows\CurrentVersion\Windows|"
    $map.Item("HKLM_SessionManager") = "HKLM|System\CurrentControlSet\Control\Session Manager|"
    
    Return $map
EndFunc

; =================================================================
; TASK SCANNING
; =================================================================
Func ScannersGetTasks()
    Local $tasksDict = ObjCreate("Scripting.Dictionary")
    
    ; Run schtasks command to get task list
    Local $output = _ScannersRunSchTasksCommand()
    If $output = "" Then Return $tasksDict
    
    ; Parse the output
    Local $lines = StringSplit($output, @CRLF, 1)
    Local $currentTaskName = ""
    Local $currentCommand = ""
    
    For $i = 1 To $lines[0]
        Local $line = StringStripWS($lines[$i], 3)
        
        If StringLeft($line, 9) = "TaskName:" Then
            ; Save previous task if we have both name and command
            If $currentTaskName <> "" And $currentCommand <> "" Then
                $tasksDict.Item($currentTaskName) = $currentCommand
            EndIf
            
            ; Start new task
            $currentTaskName = StringStripWS(StringTrimLeft($line, 9), 3)
            $currentCommand = ""
            
        ElseIf StringLeft($line, 12) = "Task To Run:" Then
            $currentCommand = StringStripWS(StringTrimLeft($line, 12), 3)
        EndIf
    Next
    
    ; Don't forget the last task
    If $currentTaskName <> "" And $currentCommand <> "" Then
        $tasksDict.Item($currentTaskName) = $currentCommand
    EndIf
    
    Return $tasksDict
EndFunc

Func _ScannersRunSchTasksCommand()
    Local $command = @ComSpec & " /c schtasks /query /fo LIST /v"
    Local $pid = Run($command, "", @SW_HIDE, 2 + 4) ; STDOUT + STDERR
    
    If $pid = 0 Then Return ""
    
    Local $output = ""
    While 1
        Local $line = StdoutRead($pid)
        If @error Then ExitLoop
        $output &= $line
        If Not ProcessExists($pid) Then ExitLoop
    WEnd
    
    ProcessClose($pid)
    Return $output
EndFunc

; =================================================================
; UTILITY FUNCTIONS
; =================================================================
Func _ScannersExpandEnvironmentVars($path)
    Local $result = $path
    
    ; Find environment variables in format %VAR%
    Local $regex = StringRegExp($path, "%([^%]+)%", 3)
    If IsArray($regex) Then
        For $i = 0 To UBound($regex) - 1
            Local $envVar = $regex[$i]
            Local $envValue = EnvGet($envVar)
            If $envValue <> "" Then
                $result = StringReplace($result, "%" & $envVar & "%", $envValue)
            EndIf
        Next
    EndIf
    
    Return $result
EndFunc

Func _ScannersHashString($input)
    ; FNV-1a like hash implementation
    Local $hash = 2166136261
    Local $prime = 16777619
    
    For $i = 1 To StringLen($input)
        $hash = BitXOR($hash, Asc(StringMid($input, $i, 1)))
        $hash = Mod($hash * $prime, 4294967296)
    Next
    
    Return Hex($hash, 8)
EndFunc
