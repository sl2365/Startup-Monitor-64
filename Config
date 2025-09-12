; Config.au3

#include-once

Global Const $CONFIG_APP_DIR = @ScriptDir & "\App"
Global Const $CONFIG_FILE_SETTINGS = $CONFIG_APP_DIR & "\Settings.ini"
Global Const $CONFIG_FILE_LOCATIONS = $CONFIG_APP_DIR & "\Locations.ini"
Global Const $CONFIG_FILE_ALLOWED = $CONFIG_APP_DIR & "\Allowed.ini"
Global Const $CONFIG_FILE_DENIED = $CONFIG_APP_DIR & "\Denied.ini"
Global Const $CONFIG_FILE_LOG = $CONFIG_APP_DIR & "\Log.ini"
Global Const $CONFIG_FILE_BASE_STARTUP = $CONFIG_APP_DIR & "\BaseStartup.ini"
Global Const $CONFIG_FILE_BASE_TASKS = $CONFIG_APP_DIR & "\BaseTasks.ini"

; =================================================================
; APP STRUCTURE MANAGEMENT
; =================================================================
Func ConfigEnsureAppStructure()
    If Not FileExists($CONFIG_APP_DIR) Then DirCreate($CONFIG_APP_DIR)
    
    ; Create default files if they don't exist
    If Not FileExists($CONFIG_FILE_SETTINGS) Then _CreateDefaultSettings()
    If Not FileExists($CONFIG_FILE_LOCATIONS) Then _CreateDefaultLocations()
    If Not FileExists($CONFIG_FILE_ALLOWED) Then FileWrite($CONFIG_FILE_ALLOWED, "[Allowed]" & @CRLF)
    If Not FileExists($CONFIG_FILE_DENIED) Then FileWrite($CONFIG_FILE_DENIED, "[Denied]" & @CRLF)
    If Not FileExists($CONFIG_FILE_LOG) Then FileWrite($CONFIG_FILE_LOG, "")
EndFunc

Func ConfigGetAppDirectory()
    Return $CONFIG_APP_DIR
EndFunc

; =================================================================
; SETTINGS MANAGEMENT
; =================================================================
Func _CreateDefaultSettings()
    Local $content = _
        "[Options]" & @CRLF & _
        "ClearLogOnStart=0" & @CRLF & _
        "MonitorTime=3000" & @CRLF & _
        "PersistentBaseline=1" & @CRLF & _
        "MonitorTasks=1" & @CRLF & _
        "Registry=1" & @CRLF & _
        @CRLF & _
        "[GUI]" & @CRLF & _
        "ReviewWindowWidth=500" & @CRLF & _
        "ReviewWindowHeight=400" & @CRLF & _
        @CRLF
    FileWrite($CONFIG_FILE_SETTINGS, $content)
EndFunc

Func ConfigLoadSettings(ByRef $settingsDict)
    $settingsDict = ObjCreate("Scripting.Dictionary")
    
    ; Load Options section
    Local $options = IniReadSection($CONFIG_FILE_SETTINGS, "Options")
    If Not @error Then
        For $i = 1 To $options[0][0]
            $settingsDict.Item($options[$i][0]) = $options[$i][1]
        Next
    EndIf
    
    ; Load GUI section
    Local $gui = IniReadSection($CONFIG_FILE_SETTINGS, "GUI")
    If Not @error Then
        For $i = 1 To $gui[0][0]
            $settingsDict.Item($gui[$i][0]) = $gui[$i][1]
        Next
    EndIf
    
    ; Ensure all default settings exist - ONLY ADD IF MISSING
    Local $needsSave = False
    
    If Not $settingsDict.Exists("MonitorTime") Then 
        $settingsDict.Item("MonitorTime") = "3000"
        $needsSave = True
    EndIf
    If Not $settingsDict.Exists("ClearLogOnStart") Then 
        $settingsDict.Item("ClearLogOnStart") = "0"
        $needsSave = True
    EndIf
    If Not $settingsDict.Exists("PersistentBaseline") Then 
        $settingsDict.Item("PersistentBaseline") = "1"
        $needsSave = True
    EndIf
    If Not $settingsDict.Exists("MonitorTasks") Then 
        $settingsDict.Item("MonitorTasks") = "1"
        $needsSave = True
    EndIf
    If Not $settingsDict.Exists("Registry") Then 
        $settingsDict.Item("Registry") = "1"
        $needsSave = True
    EndIf
    If Not $settingsDict.Exists("ReviewWindowWidth") Then 
        $settingsDict.Item("ReviewWindowWidth") = "500"
        $needsSave = True
    EndIf
    If Not $settingsDict.Exists("ReviewWindowHeight") Then 
        $settingsDict.Item("ReviewWindowHeight") = "400"
        $needsSave = True
    EndIf
    
    ; ONLY save if we actually added missing defaults
    If $needsSave Then
        ConfigSaveSettings($settingsDict)
    EndIf
EndFunc

Func ConfigSaveSettings($settingsDict)
    If Not IsObj($settingsDict) Then Return
    
    ; Save Options and GUI settings to their respective sections
    For $key In $settingsDict.Keys
        Local $value = $settingsDict.Item($key)
;~         ConsoleWrite("[" & ($key = "ReviewWindowWidth" Or $key = "ReviewWindowHeight" ? "GUI" : "Options") & "] " & $key & "=" & $value & @CRLF)
        ; Determine which section this key belongs to
        Switch $key
            Case "ClearLogOnStart", "MonitorTime", "PersistentBaseline", "MonitorTasks", "Registry"
                IniWrite($CONFIG_FILE_SETTINGS, "Options", $key, $value)
            Case "ReviewWindowWidth", "ReviewWindowHeight"
                IniWrite($CONFIG_FILE_SETTINGS, "GUI", $key, $value)
        EndSwitch
    Next
EndFunc

; =================================================================
; ADDITIONAL SAVE FUNCTIONS FOR GUI
; =================================================================
Func ConfigSaveLocations($foldersDict, $regTokensDict)
    ; Clear existing content
    FileDelete($CONFIG_FILE_LOCATIONS)
    FileWrite($CONFIG_FILE_LOCATIONS, "[Folders]" & @CRLF)
    
    ; Save folders
    If IsObj($foldersDict) Then
        For $path In $foldersDict.Keys
            IniWrite($CONFIG_FILE_LOCATIONS, "Folders", $path, $foldersDict.Item($path))
        Next
    EndIf
    
    ; Save registry tokens
    Local $file = FileOpen($CONFIG_FILE_LOCATIONS, 1) ; Open for append
    FileWrite($file, @CRLF & "[Registry]" & @CRLF)
    FileClose($file)
    
    If IsObj($regTokensDict) Then
        For $token In $regTokensDict.Keys
            IniWrite($CONFIG_FILE_LOCATIONS, "Registry", $token, $regTokensDict.Item($token))
        Next
    EndIf
EndFunc

Func ConfigSaveAllowedDenied($allowedDict, $deniedDict)
    ; Save Allowed
    FileDelete($CONFIG_FILE_ALLOWED)
    FileWrite($CONFIG_FILE_ALLOWED, "[Allowed]" & @CRLF)
    If IsObj($allowedDict) Then
        For $key In $allowedDict.Keys
            IniWrite($CONFIG_FILE_ALLOWED, "Allowed", $key, $allowedDict.Item($key))
        Next
    EndIf
    
    ; Save Denied
    FileDelete($CONFIG_FILE_DENIED)
    FileWrite($CONFIG_FILE_DENIED, "[Denied]" & @CRLF)
    If IsObj($deniedDict) Then
        For $key In $deniedDict.Keys
            IniWrite($CONFIG_FILE_DENIED, "Denied", $key, $deniedDict.Item($key))
        Next
    EndIf
EndFunc

; =================================================================
; LOCATIONS MANAGEMENT
; =================================================================
Func _CreateDefaultLocations()
    Local $content = _
        "[Folders]" & @CRLF & _
        "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup=1" & @CRLF & _
        "%PROGRAMDATA%\Microsoft\Windows\Start Menu\Programs\Startup=1" & @CRLF & _
        @CRLF & _
        "[Registry]" & @CRLF & _
        "HKCU_Run=1" & @CRLF & _
        "HKLM_Run=1" & @CRLF & _
        "HKCU_RunOnce=1" & @CRLF & _
        "HKLM_RunOnce=1" & @CRLF & _
        "HKCU_Explorer_ShellFolders=1" & @CRLF & _
        "HKLM_Explorer_ShellFolders=1" & @CRLF & _
        "HKCU_Explorer_UserShellFolders=1" & @CRLF & _
        "HKLM_Explorer_UserShellFolders=1" & @CRLF & _
        "HKCU_RunServicesOnce=1" & @CRLF & _
        "HKLM_RunServicesOnce=1" & @CRLF & _
        "HKCU_RunServices=1" & @CRLF & _
        "HKLM_RunServices=1" & @CRLF & _
        "HKCU_Policies_Explorer_Run=1" & @CRLF & _
        "HKLM_Policies_Explorer_Run=1" & @CRLF & _
        "HKCU_Windows=1" & @CRLF & _
        "HKLM_Winlogon_Userinit=1" & @CRLF & _
        "HKLM_Winlogon_Shell=1" & @CRLF & _
        "HKLM_SessionManager=1" & @CRLF
    FileWrite($CONFIG_FILE_LOCATIONS, $content)
EndFunc

Func ConfigLoadLocations(ByRef $foldersDict, ByRef $regTokensDict)
    $foldersDict = ObjCreate("Scripting.Dictionary")
    $regTokensDict = ObjCreate("Scripting.Dictionary")
    
    ; Load Folders section
    Local $folders = IniReadSection($CONFIG_FILE_LOCATIONS, "Folders")
    If Not @error Then
        For $i = 1 To $folders[0][0]
            $foldersDict.Item($folders[$i][0]) = $folders[$i][1]
        Next
    EndIf
    
    ; Load Registry section
    Local $registry = IniReadSection($CONFIG_FILE_LOCATIONS, "Registry")
    If Not @error Then
        For $i = 1 To $registry[0][0]
            $regTokensDict.Item($registry[$i][0]) = $registry[$i][1]
        Next
    EndIf
EndFunc

; =================================================================
; ALLOWED/DENIED MANAGEMENT
; =================================================================
Func ConfigLoadAllowedDenied(ByRef $allowedDict, ByRef $deniedDict)
    $allowedDict = ObjCreate("Scripting.Dictionary")
    $deniedDict = ObjCreate("Scripting.Dictionary")
    
    ; Load Allowed
    Local $allowed = IniReadSection($CONFIG_FILE_ALLOWED, "Allowed")
    If Not @error Then
        For $i = 1 To $allowed[0][0]
            $allowedDict.Item($allowed[$i][0]) = $allowed[$i][1]
        Next
    EndIf
    
    ; Load Denied
    Local $denied = IniReadSection($CONFIG_FILE_DENIED, "Denied")
    If Not @error Then
        For $i = 1 To $denied[0][0]
            $deniedDict.Item($denied[$i][0]) = $denied[$i][1]
        Next
    EndIf
EndFunc

Func ConfigRefreshAllowedDenied(ByRef $allowedDict, ByRef $deniedDict)
    ; Reload from files (handles external changes)
    ConfigLoadAllowedDenied($allowedDict, $deniedDict)
EndFunc

Func ConfigCommitReviewResults($itemsArray, ByRef $allowedDict, ByRef $deniedDict)
    ; Validate input array
    If Not IsArray($itemsArray) Or UBound($itemsArray, 1) = 0 Or UBound($itemsArray, 2) < 7 Then
        Return ; Nothing to process
    EndIf
    
    For $i = 0 To UBound($itemsArray, 1) - 1
        Local $key = $itemsArray[$i][0]     ; Item key
        Local $type = $itemsArray[$i][2]    ; Item type (file/reg/task)
        Local $hash = $itemsArray[$i][5]    ; Item hash
        Local $checked = $itemsArray[$i][6] ; Checkbox state (1=allowed, 0=denied)
        
        If $checked Then
            ; Add to allowed, remove from denied
            IniWrite($CONFIG_FILE_ALLOWED, "Allowed", $key, $hash)
            IniDelete($CONFIG_FILE_DENIED, "Denied", $key)
            $allowedDict.Item($key) = $hash
            If $deniedDict.Exists($key) Then $deniedDict.Remove($key)
        Else
            ; Add to denied, remove from allowed, AND remove the actual startup item
            IniWrite($CONFIG_FILE_DENIED, "Denied", $key, $hash)
            IniDelete($CONFIG_FILE_ALLOWED, "Allowed", $key)
            $deniedDict.Item($key) = $hash
            If $allowedDict.Exists($key) Then $allowedDict.Remove($key)
            
            ; Remove the actual startup item from the system
            EngineRemoveStartupItem($key, $type)
        EndIf
    Next
EndFunc

; =================================================================
; BASELINE MANAGEMENT
; =================================================================
Func ConfigLoadBaselines(ByRef $baseFoldersDict, ByRef $baseRegDict, ByRef $baseTasksDict, $settingsDict)
    $baseFoldersDict = ObjCreate("Scripting.Dictionary")
    $baseRegDict = ObjCreate("Scripting.Dictionary")
    $baseTasksDict = ObjCreate("Scripting.Dictionary")
    
    Local $persistentBaseline = ($settingsDict.Exists("PersistentBaseline") And $settingsDict.Item("PersistentBaseline") = "1")
    If Not $persistentBaseline Then Return ; Don't load baselines if persistence disabled
    
    ; Load folder baseline
    Local $folders = IniReadSection($CONFIG_FILE_BASE_STARTUP, "Folders")
    If Not @error Then
        For $i = 1 To $folders[0][0]
            $baseFoldersDict.Item($folders[$i][0]) = $folders[$i][1]
        Next
    EndIf
    
    ; Load registry baseline
    Local $registry = IniReadSection($CONFIG_FILE_BASE_STARTUP, "Registry")
    If Not @error Then
        For $i = 1 To $registry[0][0]
            $baseRegDict.Item($registry[$i][0]) = $registry[$i][1]
        Next
    EndIf
    
    ; Load tasks baseline
    Local $tasks = IniReadSection($CONFIG_FILE_BASE_TASKS, "BaseTasks")
    If Not @error Then
        For $i = 1 To $tasks[0][0]
            $baseTasksDict.Item($tasks[$i][0]) = $tasks[$i][1]
        Next
    EndIf
EndFunc

Func ConfigCreateBaselinesIfNeeded($settingsDict, $foldersDict, $regTokensDict)
    Local $persistentBaseline = ($settingsDict.Exists("PersistentBaseline") And $settingsDict.Item("PersistentBaseline") = "1")
    If Not $persistentBaseline Then Return
    
    Local $monitorRegistry = ($settingsDict.Exists("Registry") And $settingsDict.Item("Registry") = "1")
    Local $monitorTasks = ($settingsDict.Exists("MonitorTasks") And $settingsDict.Item("MonitorTasks") = "1")
    
    ; Create startup baseline if doesn't exist
    If Not FileExists($CONFIG_FILE_BASE_STARTUP) Then
        FileWrite($CONFIG_FILE_BASE_STARTUP, "[Folders]" & @CRLF & @CRLF & "[Registry]" & @CRLF)
        
        ; Build folder baseline from current state
        Local $currentFiles = ScannersGetFolders($foldersDict)
        If IsArray($currentFiles) And UBound($currentFiles) > 0 Then
            For $i = 0 To UBound($currentFiles) - 1
                Local $path = $currentFiles[$i][0]
                Local $hash = $currentFiles[$i][1]
                IniWrite($CONFIG_FILE_BASE_STARTUP, "Folders", $path, $hash)
            Next
        EndIf
        
        ; Build registry baseline from current state
        If $monitorRegistry Then
            Local $currentRegistry = ScannersGetRegistry($regTokensDict)
            If IsArray($currentRegistry) And UBound($currentRegistry) > 0 Then
                For $i = 0 To UBound($currentRegistry) - 1
                    Local $key = $currentRegistry[$i][0]
                    Local $hash = $currentRegistry[$i][1]
                    IniWrite($CONFIG_FILE_BASE_STARTUP, "Registry", $key, $hash)
                Next
            EndIf
        EndIf
    EndIf
    
    ; Create tasks baseline if doesn't exist
    If $monitorTasks And Not FileExists($CONFIG_FILE_BASE_TASKS) Then
        FileWrite($CONFIG_FILE_BASE_TASKS, "[BaseTasks]" & @CRLF)
        
        ; Build tasks baseline from current state
        Local $currentTasks = ScannersGetTasks()
        If IsObj($currentTasks) And $currentTasks.Count > 0 Then
            For $taskName In $currentTasks.Keys
                Local $command = $currentTasks.Item($taskName)
                Local $hash = _ConfigHashString($taskName & "|" & $command)
                IniWrite($CONFIG_FILE_BASE_TASKS, "BaseTasks", $taskName, $hash)
            Next
        EndIf
    EndIf
EndFunc

; =================================================================
; MASTER LOAD FUNCTION
; =================================================================
Func ConfigLoadAll(ByRef $settingsDict, ByRef $foldersDict, ByRef $regTokensDict, _
    ByRef $allowedDict, ByRef $deniedDict, ByRef $baseFoldersDict, ByRef $baseRegDict, ByRef $baseTasksDict)
    
    ConfigLoadSettings($settingsDict)
    ConfigLoadLocations($foldersDict, $regTokensDict)
    ConfigLoadAllowedDenied($allowedDict, $deniedDict)
    
    ; Create baselines BEFORE loading them (this ensures first-run captures everything)
    ConfigCreateBaselinesIfNeeded($settingsDict, $foldersDict, $regTokensDict)
    
    ; Now load the baselines
    ConfigLoadBaselines($baseFoldersDict, $baseRegDict, $baseTasksDict, $settingsDict)
EndFunc

; =================================================================
; UTILITY FUNCTIONS
; =================================================================
Func _ConfigHashString($input)
    ; Simple hash function for internal use
    Local $hash = 0
    For $i = 1 To StringLen($input)
        $hash = Mod($hash * 31 + Asc(StringMid($input, $i, 1)), 2147483647)
    Next
    Return Hex($hash, 8)
EndFunc
