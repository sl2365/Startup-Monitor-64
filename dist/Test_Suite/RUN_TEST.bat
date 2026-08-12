@echo off
setlocal EnableExtensions

title Startup Monitor 64 - Guided User Test

powershell.exe -NoProfile -Command ^
    "exit -not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)"

if errorlevel 1 (
    echo Requesting Administrator permission for the test...
    powershell.exe -NoProfile -Command ^
        "Start-Process -FilePath 'cmd.exe' -ArgumentList '/c','\"%~f0\"' -Verb RunAs"
    exit /b
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0SM64_UserTest.ps1"

echo.
echo Test finished. Opening Results.log...
echo.

if exist "%~dp0Results.log" (
    start "" notepad.exe "%~dp0Results.log"
)

exit /b
