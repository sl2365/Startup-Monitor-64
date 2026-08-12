@echo off
setlocal EnableExtensions EnableDelayedExpansion

title Startup Monitor 64 - Move to Denied Test

set "SCRIPT_DIR=%~dp0"
set "RESULTS=%SCRIPT_DIR%Results.log"

set "SOURCE_EXE=%SCRIPT_DIR%dist\StartupMonitor64.exe"
if not exist "%SOURCE_EXE%" (
    set "SOURCE_EXE=%SCRIPT_DIR%..\dist\StartupMonitor64.exe"
)

set "TEST_DIR=%TEMP%\StartupMonitor64_MoveToDenied_Test"
set "TEST_EXE=%TEST_DIR%\StartupMonitor64.exe"
set "APP_DIR=%TEST_DIR%\App"

> "%RESULTS%" echo Startup Monitor 64 - Move to Denied Test
>>"%RESULTS%" echo ==========================================
>>"%RESULTS%" echo.

echo.
echo ============================================================
echo Startup Monitor 64 - Move to Denied Test
echo ============================================================
echo.

if not exist "%SOURCE_EXE%" (
    echo ERROR: StartupMonitor64.exe was not found.
    echo.
    echo Put RUN_TEST.bat either:
    echo   - beside build_SM64.bat
    echo   - or in a subfolder directly below the project folder
    echo.
    echo Expected EXE:
    echo   dist\StartupMonitor64.exe
    echo.
    >>"%RESULTS%" echo - FAIL: StartupMonitor64.exe was not found.
    pause
    exit /b 1
)

tasklist /FI "IMAGENAME eq StartupMonitor64.exe" 2>nul | find /I "StartupMonitor64.exe" >nul
if not errorlevel 1 (
    echo ERROR: Startup Monitor 64 is currently running.
    echo.
    echo Exit the normal Startup Monitor 64 from its tray icon,
    echo then double-click RUN_TEST.bat again.
    echo.
    >>"%RESULTS%" echo - FAIL: Startup Monitor 64 was already running.
    pause
    exit /b 1
)

echo Preparing isolated test folder...
if exist "%TEST_DIR%" rmdir /s /q "%TEST_DIR%"

if exist "%TEST_DIR%" (
    echo ERROR: The previous test folder could not be removed.
    echo.
    echo Test folder:
    echo   %TEST_DIR%
    echo.
    >>"%RESULTS%" echo - FAIL: Previous test folder could not be removed.
    pause
    exit /b 1
)

mkdir "%APP_DIR%" >nul 2>&1
if errorlevel 1 (
    echo ERROR: The test folder could not be created.
    >>"%RESULTS%" echo - FAIL: Test folder could not be created.
    pause
    exit /b 1
)

copy /y "%SOURCE_EXE%" "%TEST_EXE%" >nul
if errorlevel 1 (
    echo ERROR: StartupMonitor64.exe could not be copied to the test folder.
    >>"%RESULTS%" echo - FAIL: Test EXE could not be copied.
    pause
    exit /b 1
)

> "%APP_DIR%\Settings.ini" (
    echo [Options]
    echo DefaultCheckReviewItems=1
    echo ClearLogOnStart=1
    echo MonitorTime=60000
    echo MonitorTimeTasks=3600000
    echo PersistentBaseline=0
    echo MonitorTasks=0
    echo Registry=0
    echo ShowReview=1
    echo NotifyDeniedAgain=1
    echo.
    echo [GUI]
    echo ReviewWindowWidth=700
    echo ReviewWindowHeight=450
    echo Theme=System
)

> "%APP_DIR%\Locations.ini" (
    echo [Folders]
    echo.
    echo [Registry]
)

> "%APP_DIR%\Allowed.ini" (
    echo [Allowed]
)

> "%APP_DIR%\Denied.ini" (
    echo [Denied]
)

> "%APP_DIR%\BaseStartup.ini" (
    echo [Folders]
    echo C:\SM64_MoveToDenied_Test\Startup_File_Test.lnk=1111111111111111
    echo.
    echo [Registry]
    echo HKCU\Software\SM64_MoveToDenied_Test^|StartupRegistryTest=2222222222222222
)

> "%APP_DIR%\BaseTasks.ini" (
    echo [BaseTasks]
    echo \SM64 MoveToDenied Test\Task A=3333333333333333
    echo \SM64 MoveToDenied Test\Task B=4444444444444444
)

echo.
echo Test data is ready.
echo.
echo When the TEST copy of Startup Monitor opens:
echo.
echo   1. Open Settings - Base Startup.
echo.
echo   2. Right-click Startup_File_Test.lnk.
echo      Choose "Move to Denied".
echo      Click NO first.
echo      Confirm the item stays in Base Startup.
echo.
echo   3. Right-click Startup_File_Test.lnk again.
echo      Choose "Move to Denied".
echo      Click YES.
echo      Confirm it disappears from Base Startup.
echo.
echo   4. Right-click StartupRegistryTest.
echo      Choose "Move to Denied".
echo      Click YES.
echo.
echo   5. Open Base Tasks.
echo      Ctrl+click BOTH test tasks so both rows are selected:
echo        - Task A
echo        - Task B
echo      Right-click either selected row.
echo      Choose "Move to Denied".
echo      Click YES.
echo.
echo   6. Open Denied.
echo      Confirm all FOUR test entries are present.
echo.
echo   7. Close Settings, then EXIT the TEST copy from its tray icon.
echo.
echo The batch will verify the INI files automatically after it exits.
echo.
pause

echo.
echo Starting isolated test copy...
echo A UAC prompt is expected because Startup Monitor runs as Administrator.
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "try { Start-Process -FilePath '%TEST_EXE%' -Verb RunAs -Wait -ErrorAction Stop; exit 0 } catch { exit 1 }"

if errorlevel 1 (
    echo.
    echo ERROR: The test copy could not be started or the UAC prompt was cancelled.
    >>"%RESULTS%" echo - FAIL: Test copy did not run to completion.
    pause
    exit /b 1
)

echo.
echo Verifying results...
echo.

set /a PASS_COUNT=0
set /a FAIL_COUNT=0

findstr /L /X /C:"C:\SM64_MoveToDenied_Test\Startup_File_Test.lnk=1111111111111111" "%APP_DIR%\BaseStartup.ini" >nul 2>&1
if errorlevel 1 (
    call :PASS "Base Startup file entry removed from BaseStartup.ini"
) else (
    call :FAIL "Base Startup file entry is still in BaseStartup.ini"
)

findstr /L /X /C:"HKCU\Software\SM64_MoveToDenied_Test|StartupRegistryTest=2222222222222222" "%APP_DIR%\BaseStartup.ini" >nul 2>&1
if errorlevel 1 (
    call :PASS "Base Startup registry entry removed from BaseStartup.ini"
) else (
    call :FAIL "Base Startup registry entry is still in BaseStartup.ini"
)

findstr /L /X /C:"\SM64 MoveToDenied Test\Task A=3333333333333333" "%APP_DIR%\BaseTasks.ini" >nul 2>&1
if errorlevel 1 (
    call :PASS "Task A removed from BaseTasks.ini"
) else (
    call :FAIL "Task A is still in BaseTasks.ini"
)

findstr /L /X /C:"\SM64 MoveToDenied Test\Task B=4444444444444444" "%APP_DIR%\BaseTasks.ini" >nul 2>&1
if errorlevel 1 (
    call :PASS "Task B removed from BaseTasks.ini"
) else (
    call :FAIL "Task B is still in BaseTasks.ini"
)

findstr /L /X /C:"C:\SM64_MoveToDenied_Test\Startup_File_Test.lnk=1111111111111111" "%APP_DIR%\Denied.ini" >nul 2>&1
if not errorlevel 1 (
    call :PASS "Base Startup file entry added to Denied.ini"
) else (
    call :FAIL "Base Startup file entry missing from Denied.ini"
)

findstr /L /X /C:"HKCU\Software\SM64_MoveToDenied_Test|StartupRegistryTest=2222222222222222" "%APP_DIR%\Denied.ini" >nul 2>&1
if not errorlevel 1 (
    call :PASS "Base Startup registry entry added to Denied.ini"
) else (
    call :FAIL "Base Startup registry entry missing from Denied.ini"
)

findstr /L /X /C:"\SM64 MoveToDenied Test\Task A=3333333333333333" "%APP_DIR%\Denied.ini" >nul 2>&1
if not errorlevel 1 (
    call :PASS "Task A added to Denied.ini"
) else (
    call :FAIL "Task A missing from Denied.ini"
)

findstr /L /X /C:"\SM64 MoveToDenied Test\Task B=4444444444444444" "%APP_DIR%\Denied.ini" >nul 2>&1
if not errorlevel 1 (
    call :PASS "Task B added to Denied.ini"
) else (
    call :FAIL "Task B missing from Denied.ini"
)

findstr /L /X /C:"C:\SM64_MoveToDenied_Test\Startup_File_Test.lnk=1111111111111111" "%APP_DIR%\Allowed.ini" >nul 2>&1
if errorlevel 1 (
    call :PASS "Moved file entry is not present in Allowed.ini"
) else (
    call :FAIL "Moved file entry unexpectedly exists in Allowed.ini"
)

findstr /L /X /C:"HKCU\Software\SM64_MoveToDenied_Test|StartupRegistryTest=2222222222222222" "%APP_DIR%\Allowed.ini" >nul 2>&1
if errorlevel 1 (
    call :PASS "Moved registry entry is not present in Allowed.ini"
) else (
    call :FAIL "Moved registry entry unexpectedly exists in Allowed.ini"
)

echo.
echo ============================================================
echo TEST SUMMARY
echo ============================================================
echo.
echo - PASS checks: !PASS_COUNT!
echo - FAIL checks: !FAIL_COUNT!
echo - Test folder: %TEST_DIR%
echo - Results log: %RESULTS%
echo.

>>"%RESULTS%" echo.
>>"%RESULTS%" echo ==========================================
>>"%RESULTS%" echo TEST SUMMARY
>>"%RESULTS%" echo ==========================================
>>"%RESULTS%" echo - PASS checks: !PASS_COUNT!
>>"%RESULTS%" echo - FAIL checks: !FAIL_COUNT!
>>"%RESULTS%" echo - Test folder: %TEST_DIR%

if !FAIL_COUNT! EQU 0 (
    echo - OVERALL: PASS
    >>"%RESULTS%" echo - OVERALL: PASS
) else (
    echo - OVERALL: FAIL
    >>"%RESULTS%" echo - OVERALL: FAIL
)

echo.
echo The isolated test folder has been left in place for inspection.
echo It will be replaced automatically the next time this test is run.
echo.
pause
exit /b !FAIL_COUNT!

:PASS
set /a PASS_COUNT+=1
echo - PASS: %~1
>>"%RESULTS%" echo - PASS: %~1
exit /b 0

:FAIL
set /a FAIL_COUNT+=1
echo - FAIL: %~1
>>"%RESULTS%" echo - FAIL: %~1
exit /b 0
