; GUI_About.au3

#include-once
#include <GUIConstants.au3>
#include <StaticConstants.au3>

; =================================================================
; ABOUT TAB CREATION
; =================================================================
Func GUIAboutCreate($parentGUI, $x, $y, $width, $height)
    ; Application info
    GUICtrlCreateLabel("Startup Monitor 64", $x + 10, $y + 20, 200, 25, $SS_CENTER)
    GUICtrlSetFont(-1, 16, 800)
    
    GUICtrlCreateLabel("Version: 1.0.0", $x + 10, $y + 55, $width - 20, 20)
    GUICtrlCreateLabel("Build Date: " & @YEAR & "-" & @MON & "-" & @MDAY, $x + 10, $y + 80, $width - 20, 20)
    
    ; Description
    GUICtrlCreateLabel("Description:", $x + 10, $y + 120, $width - 20, 20)
    GUICtrlSetFont(-1, 9, 600)
    
    Local $description = "Monitors Windows startup locations for new or modified entries. " & _
        "Provides real-time detection of startup modifications including files, " & _
        "registry entries, and scheduled tasks. Maintains baseline of existing " & _
        "items to reduce false alerts."
    
    GUICtrlCreateLabel($description, $x + 10, $y + 145, $width - 20, 80, $SS_LEFT)
    
    ; Features
    GUICtrlCreateLabel("Features:", $x + 10, $y + 240, $width - 20, 20)
    GUICtrlSetFont(-1, 9, 600)
    
    Local $features = "• Real-time monitoring of startup locations" & @CRLF & _
        "• File, registry, and scheduled task detection" & @CRLF & _
        "• Baseline management to reduce false alerts" & @CRLF & _
        "• Automatic removal of denied items" & @CRLF & _
        "• Configurable monitoring intervals" & @CRLF & _
        "• Comprehensive logging and reporting"
    
    GUICtrlCreateLabel($features, $x + 10, $y + 265, $width - 20, 120, $SS_LEFT)
    
    ; Author info
    GUICtrlCreateLabel("Author: sl23", $x + 10, $y + $height - 60, $width - 20, 20)

    ; --- Clickable GitHub Link ---
    Local $hGitHubLink = GUICtrlCreateLabel("GitHub: https://github.com/sl2365/Startup-Monitor-64", $x + 10, $y + $height - 40, $width - 20, 20)
    GUICtrlSetColor($hGitHubLink, 0x0000FF) ; Blue
    GUICtrlSetFont($hGitHubLink, 10, -1, 4) ; Underline (style 4)
    GUICtrlSetCursor($hGitHubLink, 0) ; Show hand cursor on hover

    GUICtrlCreateLabel("License: MIT", $x + 10, $y + $height - 20, $width - 20, 20)
    
    ; Return the control handle for link so handler can use it
    Return $hGitHubLink
EndFunc

; =================================================================
; ABOUT TAB MESSAGE HANDLING
; =================================================================
Func GUIAboutHandleMessage($msg, $hGitHubLink)
    ; Only handle link click
    If $msg = $hGitHubLink Then
        ShellExecute("https://github.com/sl2365/Startup-Monitor-64")
    EndIf
EndFunc
