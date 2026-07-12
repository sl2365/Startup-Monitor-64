@echo off
setlocal EnableExtensions

:: ============================================================
:: Startup Monitor 64 - Portable Python Build Script
::
:: Expected layout:
::
::   _Projects\
::   +-- _Tools\
::   |   +-- python\
::   |       +-- python.exe
::   +-- StartupMonitor64\
::       +-- build_SM64.bat
::       +-- source\
::           +-- StartupMonitor64.py
::           +-- requirements.txt
::           +-- StartupMonitor.ico
::
:: All paths are relative to this batch file.
:: ============================================================

set "PROJECT_DIR=%~dp0"
set "TOOLS_DIR=%PROJECT_DIR%..\_Tools"
set "PYTHON_DIR=%TOOLS_DIR%\python"
set "PYTHON_EXE=%PYTHON_DIR%\python.exe"
set "SOURCE_DIR=%PROJECT_DIR%source"
set "ENTRY_SCRIPT=%SOURCE_DIR%\StartupMonitor64.py"
set "REQUIREMENTS=%SOURCE_DIR%\requirements.txt"
set "ICON_FILE=%SOURCE_DIR%\StartupMonitor.ico"
set "VERSION_SCRIPT=%SOURCE_DIR%\make_version_info.py"
set "VERSION_FILE=%SOURCE_DIR%\version_info.txt"
set "BUILD_DIR=%PROJECT_DIR%build"
set "DIST_DIR=%PROJECT_DIR%dist"
set "APP_NAME=StartupMonitor64_TEST"
set "OUTPUT_EXE=%DIST_DIR%\%APP_NAME%.exe"

cd /d "%PROJECT_DIR%"

echo.
echo ============================================================
echo Startup Monitor 64 - Portable Python Build
echo ============================================================
echo.

if not exist "%PYTHON_EXE%" (
    echo ERROR: Portable Python was not found.
    echo Expected:
    echo "%PYTHON_EXE%"
    echo.
    pause
    exit /b 1
)

if not exist "%ENTRY_SCRIPT%" (
    echo ERROR: Main Python file was not found.
    echo Expected:
    echo "%ENTRY_SCRIPT%"
    echo.
    pause
    exit /b 1
)

if not exist "%REQUIREMENTS%" (
    echo ERROR: requirements.txt was not found.
    echo Expected:
    echo "%REQUIREMENTS%"
    echo.
    pause
    exit /b 1
)

echo Python:
"%PYTHON_EXE%" --version
if errorlevel 1 (
    echo ERROR: Python could not be started.
    pause
    exit /b 1
)

echo.
echo Checking pip...
"%PYTHON_EXE%" -m pip --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: pip is not available in the portable Python folder.
    echo Run get-pip.py with this Python installation first.
    pause
    exit /b 1
)

echo.
echo Installing or updating required build packages...
"%PYTHON_EXE%" -m pip install --disable-pip-version-check -r "%REQUIREMENTS%"
if errorlevel 1 (
    echo.
    echo ERROR: A required Python package could not be installed.
    pause
    exit /b 1
)

echo.
echo Closing any running copy of %APP_NAME%.exe...
taskkill /IM "%APP_NAME%.exe" /F >nul 2>&1
timeout /t 2 /nobreak >nul

tasklist /FI "IMAGENAME eq %APP_NAME%.exe" 2>nul | find /I "%APP_NAME%.exe" >nul
if not errorlevel 1 (
    echo.
    echo ERROR: %APP_NAME%.exe is still running.
    echo.
    echo Close Startup Monitor from its tray icon, or use Task Manager
    echo to end %APP_NAME%.exe, then run this build again.
    echo.
    pause
    exit /b 1
)

echo Cleaning previous build files...
if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"

if exist "%OUTPUT_EXE%" del /f /q "%OUTPUT_EXE%"

if exist "%BUILD_DIR%" (
    echo ERROR: Could not remove "%BUILD_DIR%".
    pause
    exit /b 1
)

if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"
if errorlevel 1 (
    echo ERROR: Could not create "%BUILD_DIR%".
    pause
    exit /b 1
)

if not exist "%DIST_DIR%" mkdir "%DIST_DIR%"
if errorlevel 1 (
    echo ERROR: Could not create "%DIST_DIR%".
    pause
    exit /b 1
)

echo.
echo Generating build information...
"%PYTHON_EXE%" -c "from datetime import date; from pathlib import Path; Path(r'%SOURCE_DIR%\build_info.py').write_text('BUILD_DATE = ' + repr(date.today().isoformat()) + '\n', encoding='utf-8')"
if errorlevel 1 (
    echo ERROR: Build information could not be generated.
    pause
    exit /b 1
)

echo.
echo Generating Windows version resource...
"%PYTHON_EXE%" "%VERSION_SCRIPT%" "%VERSION_FILE%" "%APP_NAME%.exe"
if errorlevel 1 (
    echo ERROR: Windows version resource could not be generated.
    pause
    exit /b 1
)

echo.
echo Building %APP_NAME%.exe...

set "ICON_OPTIONS="
set "DATA_OPTIONS="
if exist "%ICON_FILE%" (
    set "ICON_OPTIONS=--icon "%ICON_FILE%""
    set "DATA_OPTIONS=--add-data "%ICON_FILE%;.""
)

"%PYTHON_EXE%" -m PyInstaller ^
    --noconfirm ^
    --clean ^
    --onefile ^
    --windowed ^
    --uac-admin ^
    --name "%APP_NAME%" ^
    --version-file "%VERSION_FILE%" ^
    %ICON_OPTIONS% ^
    %DATA_OPTIONS% ^
    --distpath "%DIST_DIR%" ^
    --workpath "%BUILD_DIR%\work" ^
    --specpath "%BUILD_DIR%" ^
    --paths "%SOURCE_DIR%" ^
    --hidden-import pystray._win32 ^
    "%ENTRY_SCRIPT%"

if errorlevel 1 (
    echo.
    echo ============================================================
    echo BUILD FAILED
    echo ============================================================
    echo.
    pause
    exit /b 1
)

if not exist "%OUTPUT_EXE%" (
    echo ERROR: Build completed but the EXE was not found.
    echo Expected:
    echo "%OUTPUT_EXE%"
    pause
    exit /b 1
)

echo.
echo ============================================================
echo BUILD SUCCESSFUL
echo ============================================================
echo Output:
echo "%OUTPUT_EXE%"
echo.

timeout /t 2 /nobreak >nul
start "" "%OUTPUT_EXE%"
exit /b 0
