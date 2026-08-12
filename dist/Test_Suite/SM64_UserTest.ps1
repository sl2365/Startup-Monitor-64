$ErrorActionPreference = "Stop"

$SuiteDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ResultsPath = Join-Path $SuiteDir "Results.log"

$Workspace = Join-Path $env:TEMP "StartupMonitor64_UserTest"
$ManifestPath = Join-Path $env:TEMP "StartupMonitor64_UserTest_manifest.json"

$Prefix = "SM64_USER_TEST_9D7A3C21"

$StartupFolder = [Environment]::GetFolderPath(
    [Environment+SpecialFolder]::Startup
)

if ([string]::IsNullOrWhiteSpace($StartupFolder)) {
    $StartupFolder = Join-Path $env:APPDATA (
        "Microsoft\Windows\Start Menu\Programs\Startup"
    )
}

$RunKeyPs = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$RunKeySm64 = "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"

$Names = [ordered]@{
    BaseFile       = "${Prefix}_BASE_FILE.txt"
    BaseRegistry   = "${Prefix}_BASE_REGISTRY"
    BaseTaskA      = "${Prefix}_BASE_TASK_A"
    BaseTaskB      = "${Prefix}_BASE_TASK_B"
    PauseFile      = "${Prefix}_PAUSE_RESUME.txt"
    AllowFile      = "${Prefix}_ALLOW.txt"
    DenyFile       = "${Prefix}_DENY.txt"
    RegistryDeny   = "${Prefix}_REGISTRY_DENY"
    TaskDeny       = "${Prefix}_TASK_DENY"
}

$Paths = [ordered]@{
    BaseFile  = Join-Path $StartupFolder $Names.BaseFile
    PauseFile = Join-Path $StartupFolder $Names.PauseFile
    AllowFile = Join-Path $StartupFolder $Names.AllowFile
    DenyFile  = Join-Path $StartupFolder $Names.DenyFile
}

$TaskNames = @(
    $Names.BaseTaskA,
    $Names.BaseTaskB,
    $Names.TaskDeny
)

$RegistryNames = @(
    $Names.BaseRegistry,
    $Names.RegistryDeny
)

$FilePaths = @(
    $Paths.BaseFile,
    $Paths.PauseFile,
    $Paths.AllowFile,
    $Paths.DenyFile
)

$script:PassCount = 0
$script:FailCount = 0
$script:IncompleteCount = 0
$script:InfoCount = 0
$script:TestProcess = $null
$script:TestExe = $null
$script:TestApp = Join-Path $Workspace "App"

function Write-Line {
    param([string]$Text = "")
    Write-Host $Text
    Add-Content -LiteralPath $ResultsPath -Value $Text -Encoding UTF8
}

function Write-Section {
    param([string]$Title)
    Write-Line ""
    Write-Line ("=" * 68)
    Write-Line $Title
    Write-Line ("=" * 68)
}

function Add-Pass {
    param(
        [string]$Name,
        [string]$Evidence = ""
    )
    $script:PassCount++
    Write-Line "- PASS: $Name"
    if ($Evidence) {
        Write-Line "    Evidence: $Evidence"
    }
}

function Add-Fail {
    param(
        [string]$Name,
        [string]$Stage,
        [string]$Evidence = ""
    )
    $script:FailCount++
    Write-Line "- FAIL: $Name"
    Write-Line "    Failure stage: $Stage"
    if ($Evidence) {
        Write-Line "    Evidence: $Evidence"
    }
}

function Add-Incomplete {
    param(
        [string]$Name,
        [string]$Evidence = ""
    )
    $script:IncompleteCount++
    Write-Line "- INCOMPLETE: $Name"
    if ($Evidence) {
        Write-Line "    Evidence: $Evidence"
    }
}

function Add-Info {
    param([string]$Text)
    $script:InfoCount++
    Write-Line "- INFO: $Text"
}

function Wait-Enter {
    param([string]$Prompt = "Press ENTER to continue")
    [void](Read-Host $Prompt)
}

function Get-DecisionState {
    param([string]$Key)

    $allowedPath = Join-Path $script:TestApp "Allowed.ini"
    $deniedPath = Join-Path $script:TestApp "Denied.ini"

    $inAllowed = Ini-HasKey $allowedPath $Key
    $inDenied = Ini-HasKey $deniedPath $Key

    if ($inAllowed -and $inDenied) {
        return "Both"
    }

    if ($inAllowed) {
        return "Allowed"
    }

    if ($inDenied) {
        return "Denied"
    }

    return "None"
}

function Wait-ForDecisions {
    param(
        [string[]]$Keys,
        [string]$Description,
        [int]$Seconds = 120
    )

    while ($true) {
        $deadline = (Get-Date).AddSeconds($Seconds)

        Write-Host ""
        Write-Host "Waiting for Startup Monitor..."
        Write-Host "Complete the normal Review window when it appears."
        Write-Host "You do NOT need to return here or press ENTER afterwards."

        while ((Get-Date) -lt $deadline) {
            $allResolved = $true

            foreach ($key in $Keys) {
                if ((Get-DecisionState $key) -eq "None") {
                    $allResolved = $false
                    break
                }
            }

            if ($allResolved) {
                Write-Host "Review result detected. Continuing automatically..."
                Start-Sleep -Seconds 1
                return $true
            }

            Start-Sleep -Milliseconds 500
        }

        Write-Host ""
        Write-Host "The tester has not detected a completed Review yet."
        Write-Host ""
        Write-Host "If the Review window is still open, finish it first."
        Write-Host "Then type W to keep waiting."
        Write-Host ""
        Write-Host "If no Review window appeared, type F."
        Write-Host "The test will stop safely rather than starting another test"
        Write-Host "while this one is unresolved."
        Write-Host ""

        $answer = (Read-Host "[W]ait again or [F]ail and stop").Trim().ToUpperInvariant()

        if ($answer -eq "F") {
            Add-Fail `
                $Description `
                "Detection / Review presentation" `
                "No completed Allowed/Denied decision was detected before the user stopped this test."
            throw "$Description did not complete."
        }
    }
}

function Wait-ForBaseMoveAndPause {
    param([int]$Seconds = 180)

    while ($true) {
        $deadline = (Get-Date).AddSeconds($Seconds)

        Write-Host ""
        Write-Host "Waiting for the Base Startup/Base Tasks actions..."
        Write-Host "You do NOT need to return here or press ENTER afterwards."

        while ((Get-Date) -lt $deadline) {
            $deniedPath = Join-Path $script:TestApp "Denied.ini"

            $startupDone = (
                -not (Ini-HasKey $baseStartupPath $baseFileKey) `
                -and -not (Ini-HasKey $baseStartupPath $baseRegKey) `
                -and (Ini-HasKey $deniedPath $baseFileKey) `
                -and (Ini-HasKey $deniedPath $baseRegKey)
            )

            $tasksDone = (
                -not (Ini-HasKey $baseTasksPath $baseTaskAKey) `
                -and -not (Ini-HasKey $baseTasksPath $baseTaskBKey) `
                -and (Ini-HasKey $deniedPath $baseTaskAKey) `
                -and (Ini-HasKey $deniedPath $baseTaskBKey)
            )

            if (
                $startupDone `
                -and $tasksDone `
                -and (Log-HasText "monitoring_paused")
            ) {
                Write-Host "Required actions detected. Continuing automatically..."
                Start-Sleep -Seconds 1
                return
            }

            Start-Sleep -Milliseconds 500
        }

        Write-Host ""
        Write-Host "The tester is still waiting for the required actions."
        Write-Host ""
        Write-Host "Complete them in Startup Monitor, then type W."
        Write-Host "Type F only if the test cannot be completed."
        Write-Host ""

        $answer = (Read-Host "[W]ait again or [F]ail and stop").Trim().ToUpperInvariant()

        if ($answer -eq "F") {
            Add-Fail `
                "Base Startup/Base Tasks guided actions" `
                "Manual action not completed" `
                "The required Pause Monitoring and Move to Denied results were not all detected."
            throw "Base guided actions did not complete."
        }
    }
}

function Wait-ForResumeDecision {
    param(
        [string]$Key,
        [int]$Seconds = 120
    )

    while ($true) {
        $deadline = (Get-Date).AddSeconds($Seconds)

        Write-Host ""
        Write-Host "Waiting for Resume Monitoring and the Review decision..."
        Write-Host "You do NOT need to return here or press ENTER afterwards."

        while ((Get-Date) -lt $deadline) {
            if (
                (Log-HasText "monitoring_resumed") `
                -and (Get-DecisionState $Key) -ne "None"
            ) {
                Write-Host "Resume/Review result detected. Continuing automatically..."
                Start-Sleep -Seconds 1
                return
            }

            Start-Sleep -Milliseconds 500
        }

        Write-Host ""
        Write-Host "The tester has not detected the Resume/Review result yet."
        Write-Host ""
        Write-Host "If Startup Monitor is still waiting for you, finish that action"
        Write-Host "and type W. If the Review never appeared, type F."
        Write-Host ""

        $answer = (Read-Host "[W]ait again or [F]ail and stop").Trim().ToUpperInvariant()

        if ($answer -eq "F") {
            Add-Fail `
                "Pause/Resume detection" `
                "Resume / detection / Review" `
                "No completed decision was detected after monitoring was resumed."
            throw "Pause/Resume test did not complete."
        }
    }
}

function Wait-ForProcessExit {
    param([int]$Seconds = 180)

    $deadline = (Get-Date).AddSeconds($Seconds)

    Write-Host ""
    Write-Host "Waiting for Startup Monitor to exit..."
    Write-Host "You do NOT need to return here or press ENTER afterwards."

    while ((Get-Date) -lt $deadline) {
        $script:TestProcess.Refresh()

        if ($script:TestProcess.HasExited) {
            return $true
        }

        Start-Sleep -Milliseconds 500
    }

    return $false
}

function Wait-ForPath {
    param(
        [string]$Path,
        [int]$Seconds = 30
    )

    $deadline = (Get-Date).AddSeconds($Seconds)

    while ((Get-Date) -lt $deadline) {
        if (Test-Path -LiteralPath $Path) {
            return $true
        }

        Start-Sleep -Milliseconds 500
    }

    return $false
}

function Ini-HasKey {
    param(
        [string]$File,
        [string]$Key
    )

    if (-not (Test-Path -LiteralPath $File)) {
        return $false
    }

    $pattern = "^" + [regex]::Escape($Key) + "="

    return [bool](
        Select-String `
            -LiteralPath $File `
            -Pattern $pattern `
            -Quiet
    )
}

function Log-HasText {
    param(
        [string]$Text
    )

    $logPath = Join-Path $script:TestApp "Log.ini"

    if (-not (Test-Path -LiteralPath $logPath)) {
        return $false
    }

    $content = Get-Content -LiteralPath $logPath -Raw -ErrorAction SilentlyContinue

    if ($null -eq $content) {
        return $false
    }

    return $content.Contains($Text)
}

function Registry-ValueExists {
    param([string]$Name)

    try {
        [void](
            Get-ItemPropertyValue `
                -LiteralPath $RunKeyPs `
                -Name $Name `
                -ErrorAction Stop
        )
        return $true
    }
    catch {
        return $false
    }
}

function Create-TestRegistryValue {
    param([string]$Name)

    if (-not (Test-Path -LiteralPath $RunKeyPs)) {
        New-Item -Path $RunKeyPs -Force | Out-Null
    }

    New-ItemProperty `
        -LiteralPath $RunKeyPs `
        -Name $Name `
        -PropertyType String `
        -Value "cmd.exe /c exit /b 0" `
        -Force | Out-Null
}

function Remove-TestRegistryValue {
    param([string]$Name)

    if (Registry-ValueExists $Name) {
        Remove-ItemProperty `
            -LiteralPath $RunKeyPs `
            -Name $Name `
            -Force `
            -ErrorAction SilentlyContinue
    }
}

function Invoke-SchtasksQuiet {
    param([string[]]$Arguments)

    $previousPreference = $ErrorActionPreference

    try {
        # Windows PowerShell can convert expected stderr from native programs
        # into PowerShell errors when ErrorActionPreference is Stop.
        # Missing test tasks are normal during safety checks, so capture the
        # native output and use schtasks.exe's exit code instead.
        $ErrorActionPreference = "SilentlyContinue"

        $output = & schtasks.exe @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = @($output)
    }
}

function Task-Exists {
    param([string]$Name)

    $result = Invoke-SchtasksQuiet @(
        "/Query",
        "/TN",
        $Name
    )

    return ($result.ExitCode -eq 0)
}

function Create-TestTask {
    param([string]$Name)

    $result = Invoke-SchtasksQuiet @(
        "/Create",
        "/TN",
        $Name,
        "/TR",
        "cmd.exe /c exit /b 0",
        "/SC",
        "ONLOGON",
        "/RL",
        "LIMITED",
        "/F"
    )

    if ($result.ExitCode -ne 0) {
        $detail = (
            $result.Output |
            ForEach-Object { $_.ToString() }
        ) -join " "

        if ([string]::IsNullOrWhiteSpace($detail)) {
            $detail = "schtasks.exe returned exit code $($result.ExitCode)."
        }

        throw "Scheduled Task could not be created: $Name. $detail"
    }
}

function Remove-TestTask {
    param([string]$Name)

    if (Task-Exists $Name) {
        [void](Invoke-SchtasksQuiet @(
            "/Delete",
            "/TN",
            $Name,
            "/F"
        ))
    }
}

function Save-Manifest {
    $manifest = [ordered]@{
        Prefix = $Prefix
        Workspace = $Workspace
        Files = $FilePaths
        RegistryValues = $RegistryNames
        Tasks = $TaskNames
    }

    $manifest |
        ConvertTo-Json -Depth 4 |
        Set-Content -LiteralPath $ManifestPath -Encoding UTF8
}

function Remove-TestObjects {
    param([switch]$FromManifest)

    $files = $FilePaths
    $registry = $RegistryNames
    $tasks = $TaskNames
    $workspaceToRemove = $Workspace

    if ($FromManifest -and (Test-Path -LiteralPath $ManifestPath)) {
        try {
            $old = Get-Content -LiteralPath $ManifestPath -Raw |
                ConvertFrom-Json

            if ($old.Files) {
                $files = @($old.Files)
            }

            if ($old.RegistryValues) {
                $registry = @($old.RegistryValues)
            }

            if ($old.Tasks) {
                $tasks = @($old.Tasks)
            }

            if ($old.Workspace) {
                $workspaceToRemove = [string]$old.Workspace
            }
        }
        catch {
            Write-Host "WARNING: Previous test manifest could not be read."
        }
    }

    foreach ($file in $files) {
        if ($file -and (Test-Path -LiteralPath $file)) {
            Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
        }
    }

    foreach ($name in $registry) {
        if ($name) {
            Remove-TestRegistryValue ([string]$name)
        }
    }

    foreach ($name in $tasks) {
        if ($name) {
            Remove-TestTask ([string]$name)
        }
    }

    if (
        $workspaceToRemove `
        -and (Test-Path -LiteralPath $workspaceToRemove)
    ) {
        Remove-Item `
            -LiteralPath $workspaceToRemove `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }
}

function Get-SourceExe {
    $candidates = @(
        (Join-Path (Split-Path -Parent $SuiteDir) "StartupMonitor64.exe"),
        (Join-Path $SuiteDir "StartupMonitor64.exe"),
        (Join-Path (Split-Path -Parent $SuiteDir) "dist\StartupMonitor64.exe")
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    return $null
}

function Test-NoCollision {
    $collisions = @()

    foreach ($file in $FilePaths) {
        if (Test-Path -LiteralPath $file) {
            $collisions += "File: $file"
        }
    }

    foreach ($name in $RegistryNames) {
        if (Registry-ValueExists $name) {
            $collisions += "Registry value: $name"
        }
    }

    foreach ($name in $TaskNames) {
        if (Task-Exists $name) {
            $collisions += "Scheduled Task: $name"
        }
    }

    if ($collisions.Count -gt 0) {
        Write-Line ""
        Write-Line "The test found objects using its reserved test names."
        Write-Line "They were NOT deleted because no valid previous-test manifest exists."
        Write-Line ""
        foreach ($collision in $collisions) {
            Write-Line "  $collision"
        }
        return $false
    }

    return $true
}

function Stop-TestProcess {
    if ($null -eq $script:TestProcess) {
        return
    }

    try {
        if (-not $script:TestProcess.HasExited) {
            $previousPreference = $ErrorActionPreference

            try {
                $ErrorActionPreference = "SilentlyContinue"

                & taskkill.exe `
                    /PID $script:TestProcess.Id `
                    /T `
                    /F *> $null
            }
            finally {
                $ErrorActionPreference = $previousPreference
            }
        }
    }
    catch {
    }
}

function Append-DiagnosticEvidence {
    Write-Section "DIAGNOSTIC EVIDENCE"

    $allowed = Join-Path $script:TestApp "Allowed.ini"
    $denied = Join-Path $script:TestApp "Denied.ini"
    $baseStartup = Join-Path $script:TestApp "BaseStartup.ini"
    $baseTasks = Join-Path $script:TestApp "BaseTasks.ini"
    $log = Join-Path $script:TestApp "Log.ini"

    foreach ($pair in @(
        @("Allowed.ini", $allowed),
        @("Denied.ini", $denied),
        @("BaseStartup.ini", $baseStartup),
        @("BaseTasks.ini", $baseTasks)
    )) {
        Write-Line ""
        Write-Line "[$($pair[0]) - test entries]"

        if (Test-Path -LiteralPath $pair[1]) {
            $matches = Get-Content -LiteralPath $pair[1] |
                Where-Object { $_ -like "*$Prefix*" }

            if ($matches) {
                foreach ($line in $matches) {
                    Write-Line "  $line"
                }
            }
            else {
                Write-Line "  (none)"
            }
        }
        else {
            Write-Line "  (file missing)"
        }
    }

    Write-Line ""
    Write-Line "[Relevant Log.ini entries]"

    if (Test-Path -LiteralPath $log) {
        $matches = Get-Content -LiteralPath $log |
            Where-Object {
                $_ -like "*$Prefix*" `
                -or $_ -like "*monitoring_paused*" `
                -or $_ -like "*monitoring_resumed*" `
                -or $_ -like "*worker_thread*"
            }

        if ($matches) {
            foreach ($line in $matches) {
                Write-Line "  $line"
            }
        }
        else {
            Write-Line "  (none)"
        }
    }
    else {
        Write-Line "  (Log.ini missing)"
    }
}

function Verify-Decision {
    param(
        [string]$FriendlyName,
        [string]$Key,
        [ValidateSet("Allowed", "Denied")]
        [string]$Expected,
        [string]$SystemObjectDescription,
        [bool]$SystemObjectExists
    )

    $allowedPath = Join-Path $script:TestApp "Allowed.ini"
    $deniedPath = Join-Path $script:TestApp "Denied.ini"

    $inAllowed = Ini-HasKey $allowedPath $Key
    $inDenied = Ini-HasKey $deniedPath $Key

    if ($Expected -eq "Allowed") {
        if ($inAllowed -and -not $inDenied -and $SystemObjectExists) {
            Add-Pass `
                "$FriendlyName - Allow decision" `
                "Allowed.ini contains the item and $SystemObjectDescription remains present."
            return
        }

        if ($inDenied) {
            Add-Incomplete `
                "$FriendlyName - Allow decision" `
                "The test item was Denied instead of Allowed. The requested Allow branch was not exercised."
            return
        }

        if (Log-HasText $Key) {
            Add-Fail `
                "$FriendlyName - Allow decision" `
                "Review / persistence" `
                "SM64 logged the item, but the expected Allowed.ini state was not produced."
        }
        else {
            Add-Fail `
                "$FriendlyName - Allow decision" `
                "Detection" `
                "No Allowed/Denied entry or relevant SM64 log entry was found for the test item."
        }

        return
    }

    if ($inDenied -and -not $inAllowed -and -not $SystemObjectExists) {
        Add-Pass `
            "$FriendlyName - Deny decision and removal" `
            "Denied.ini contains the item and $SystemObjectDescription was removed."
        return
    }

    if ($inAllowed) {
        Add-Incomplete `
            "$FriendlyName - Deny decision" `
            "The test item was Allowed instead of Denied. The requested Deny branch was not exercised."
        return
    }

    if ($inDenied -and $SystemObjectExists) {
        Add-Fail `
            "$FriendlyName - Deny removal" `
            "Removal" `
            "Denied.ini contains the test item, but $SystemObjectDescription still exists."
        return
    }

    if (Log-HasText $Key) {
        Add-Fail `
            "$FriendlyName - Deny decision" `
            "Review / persistence" `
            "SM64 logged the item, but the expected Denied.ini state was not produced."
    }
    else {
        Add-Fail `
            "$FriendlyName - Deny decision" `
            "Detection" `
            "No Allowed/Denied entry or relevant SM64 log entry was found for the test item."
    }
}

function Show-TestInstructions {
    param([string[]]$Lines)

    Write-Host ""
    Write-Host ("-" * 68)
    foreach ($line in $Lines) {
        Write-Host $line
    }
    Write-Host ("-" * 68)
    Write-Host ""
}

# ----------------------------------------------------------------------
# Start report
# ----------------------------------------------------------------------

Set-Content `
    -LiteralPath $ResultsPath `
    -Value "Startup Monitor 64 - Guided User Test" `
    -Encoding UTF8

Write-Line "Test-suite revision: 5"
Write-Line ("Started: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
Write-Line ("Computer: " + $env:COMPUTERNAME)
Write-Line ("User: " + $env:USERNAME)
Write-Line ("Windows culture: " + [Globalization.CultureInfo]::CurrentCulture.Name)
Write-Line ("Windows UI culture: " + [Globalization.CultureInfo]::CurrentUICulture.Name)

try {
    $os = Get-CimInstance Win32_OperatingSystem
    Write-Line ("Windows: " + $os.Caption + " " + $os.Version + " " + $os.OSArchitecture)
}
catch {
    Write-Line "Windows: (could not query OS details)"
}

Write-Section "SAFETY CHECKS"

$sourceExe = Get-SourceExe

if (-not $sourceExe) {
    Add-Fail `
        "Locate StartupMonitor64.exe" `
        "Test setup" `
        "Put Test_Suite beside StartupMonitor64.exe, then run RUN_TEST.bat again."
    throw "StartupMonitor64.exe was not found."
}

Write-Line "Release EXE: $sourceExe"

try {
    $vi = (Get-Item -LiteralPath $sourceExe).VersionInfo
    Write-Line ("File version: " + $vi.FileVersion)
    Write-Line ("Product version: " + $vi.ProductVersion)
}
catch {
    Write-Line "Version information: unavailable"
}

$running = Get-Process -Name "StartupMonitor64" -ErrorAction SilentlyContinue

if ($running) {
    Add-Fail `
        "Normal Startup Monitor is closed before testing" `
        "Test setup" `
        "Exit Startup Monitor 64 from its tray icon, then run this test again."
    throw "StartupMonitor64.exe is already running."
}

Add-Pass "Normal Startup Monitor is not running"

if (Test-Path -LiteralPath $ManifestPath) {
    Add-Info "An interrupted previous user test was found. Cleaning its recorded test objects first."
    Remove-TestObjects -FromManifest

    if (Test-Path -LiteralPath $ManifestPath) {
        Remove-Item -LiteralPath $ManifestPath -Force -ErrorAction SilentlyContinue
    }
}

if (-not (Test-NoCollision)) {
    Add-Fail `
        "Reserved test object names are available" `
        "Safety check" `
        "One or more reserved test names already exist and were left untouched."
    throw "Reserved test object collision."
}

Add-Pass "Reserved test object names are clear"

if (Test-Path -LiteralPath $Workspace) {
    Remove-Item -LiteralPath $Workspace -Recurse -Force
}

New-Item -ItemType Directory -Path $Workspace -Force | Out-Null
New-Item -ItemType Directory -Path $script:TestApp -Force | Out-Null

$script:TestExe = Join-Path $Workspace "StartupMonitor64.exe"
Copy-Item -LiteralPath $sourceExe -Destination $script:TestExe -Force

Add-Pass `
    "Release EXE copied to isolated test installation" `
    $Workspace

# Use normal SM64 options, but shorten scan intervals for a practical user test.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$settingsIni = @"
[Options]
DefaultCheckReviewItems=1
ClearLogOnStart=1
MonitorTime=1500
MonitorTimeTasks=10000
PersistentBaseline=1
MonitorTasks=1
Registry=1
ShowReview=1
NotifyDeniedAgain=1

[GUI]
ReviewWindowWidth=700
ReviewWindowHeight=450
Theme=System
"@

[IO.File]::WriteAllText(
    (Join-Path $script:TestApp "Settings.ini"),
    $settingsIni,
    $utf8NoBom
)

# Keep the public test narrowly scoped to the current user's real Startup folder
# and HKCU Run. This avoids exposing unrelated system startup items to test actions.
$locationsIni = @"
[Folders]
%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup=1

[Registry]
HKCU_Run=1
"@

[IO.File]::WriteAllText(
    (Join-Path $script:TestApp "Locations.ini"),
    $locationsIni,
    $utf8NoBom
)

Save-Manifest

try {
    # ------------------------------------------------------------------
    # Baseline fixtures
    # ------------------------------------------------------------------

    Write-Section "TEST 1 - FIRST-RUN BASELINE"

    Set-Content `
        -LiteralPath $Paths.BaseFile `
        -Value "Harmless Startup Monitor 64 user-test marker." `
        -Encoding UTF8

    Create-TestRegistryValue $Names.BaseRegistry
    Create-TestTask $Names.BaseTaskA
    Create-TestTask $Names.BaseTaskB

    Add-Pass "Baseline test objects were created safely"

    $script:TestProcess = Start-Process `
        -FilePath $script:TestExe `
        -WorkingDirectory $Workspace `
        -PassThru

    $baseStartupPath = Join-Path $script:TestApp "BaseStartup.ini"
    $baseTasksPath = Join-Path $script:TestApp "BaseTasks.ini"

    $baselineReady = (
        (Wait-ForPath $baseStartupPath 40) `
        -and (Wait-ForPath $baseTasksPath 40)
    )

    if (-not $baselineReady) {
        Add-Fail `
            "First-run baseline files were created" `
            "Application startup / baseline creation" `
            "BaseStartup.ini or BaseTasks.ini did not appear within 40 seconds."
        throw "Baseline creation did not complete."
    }

    Start-Sleep -Seconds 3

    $baseFileKey = [IO.Path]::GetFullPath($Paths.BaseFile)
    $baseRegKey = "$RunKeySm64|$($Names.BaseRegistry)"
    $baseTaskAKey = "\$($Names.BaseTaskA)"
    $baseTaskBKey = "\$($Names.BaseTaskB)"

    $baseFileFound = Ini-HasKey $baseStartupPath $baseFileKey
    $baseRegFound = Ini-HasKey $baseStartupPath $baseRegKey
    $baseTaskAFound = Ini-HasKey $baseTasksPath $baseTaskAKey
    $baseTaskBFound = Ini-HasKey $baseTasksPath $baseTaskBKey

    if ($baseFileFound) {
        Add-Pass "Startup-folder item was captured in Base Startup"
    }
    else {
        Add-Fail `
            "Startup-folder item was captured in Base Startup" `
            "Folder baseline scan" `
            $baseFileKey
    }

    if ($baseRegFound) {
        Add-Pass "HKCU Run item was captured in Base Startup"
    }
    else {
        Add-Fail `
            "HKCU Run item was captured in Base Startup" `
            "Registry baseline scan" `
            $baseRegKey
    }

    if ($baseTaskAFound -and $baseTaskBFound) {
        Add-Pass "Scheduled Tasks were captured in Base Tasks"
    }
    else {
        Add-Fail `
            "Scheduled Tasks were captured in Base Tasks" `
            "Scheduled Task baseline scan" `
            "Expected $baseTaskAKey and $baseTaskBKey"
    }

    # ------------------------------------------------------------------
    # Base Move to Denied + Pause
    # ------------------------------------------------------------------

    Write-Section "TEST 2 - BASE ITEMS, MULTI-SELECT, AND PAUSE"

    if (
        $baseFileFound `
        -and $baseRegFound `
        -and $baseTaskAFound `
        -and $baseTaskBFound
    ) {
        Show-TestInstructions @(
            "Use the TEST copy of Startup Monitor now.",
            "",
            "1. Left-click its tray icon to open Settings.",
            "2. Click 'Pause Monitoring'. KEEP IT PAUSED for this test.",
            "",
            "3. Open Base Startup.",
            "   Tick BOTH test entries:",
            "     $($Names.BaseFile)",
            "     $($Names.BaseRegistry)",
            "   Right-click either checked test entry.",
            "   Choose 'Move to Denied' and click Yes.",
            "",
            "4. Open Base Tasks.",
            "   Tick BOTH test tasks:",
            "     $($Names.BaseTaskA)",
            "     $($Names.BaseTaskB)",
            "   Right-click either checked test task.",
            "   Choose 'Move to Denied' and click Yes.",
            "",
            "Do not resume monitoring yet.",
            "The tester will detect these completed actions automatically."
        )

        Wait-ForBaseMoveAndPause

        $deniedPath = Join-Path $script:TestApp "Denied.ini"

        $startupMoveOkay = (
            -not (Ini-HasKey $baseStartupPath $baseFileKey) `
            -and -not (Ini-HasKey $baseStartupPath $baseRegKey) `
            -and (Ini-HasKey $deniedPath $baseFileKey) `
            -and (Ini-HasKey $deniedPath $baseRegKey)
        )

        if ($startupMoveOkay) {
            Add-Pass `
                "Base Startup multi-item Move to Denied" `
                "Both the file and Registry baseline entries moved to Denied.ini."
        }
        else {
            Add-Fail `
                "Base Startup multi-item Move to Denied" `
                "Base Startup context action / persistence" `
                "Expected both checked test entries to leave BaseStartup.ini and appear in Denied.ini."
        }

        $taskMoveOkay = (
            -not (Ini-HasKey $baseTasksPath $baseTaskAKey) `
            -and -not (Ini-HasKey $baseTasksPath $baseTaskBKey) `
            -and (Ini-HasKey $deniedPath $baseTaskAKey) `
            -and (Ini-HasKey $deniedPath $baseTaskBKey)
        )

        if ($taskMoveOkay) {
            Add-Pass `
                "Base Tasks multi-item Move to Denied" `
                "Both checked test tasks moved to Denied.ini."
        }
        else {
            Add-Fail `
                "Base Tasks multi-item Move to Denied" `
                "Base Tasks context action / persistence" `
                "Expected both checked test tasks to leave BaseTasks.ini and appear in Denied.ini."
        }

        if (Log-HasText "monitoring_paused") {
            Add-Pass "Pause Monitoring action was recorded"
        }
        else {
            Add-Incomplete `
                "Pause Monitoring action" `
                "No monitoring_paused event was found in the isolated Log.ini."
        }

        # Remove the baseline fixtures while monitoring is paused.
        Remove-Item -LiteralPath $Paths.BaseFile -Force -ErrorAction SilentlyContinue
        Remove-TestRegistryValue $Names.BaseRegistry
        Remove-TestTask $Names.BaseTaskA
        Remove-TestTask $Names.BaseTaskB

        # Prove that a new item is ignored while paused.
        Set-Content `
            -LiteralPath $Paths.PauseFile `
            -Value "Harmless pause/resume test marker." `
            -Encoding UTF8

        Write-Host ""
        Write-Host "A new harmless Startup-folder item has now been created WHILE PAUSED."
        Write-Host "The test will wait 6 seconds. It should NOT be detected yet."
        Start-Sleep -Seconds 6

        $pauseKey = [IO.Path]::GetFullPath($Paths.PauseFile)
        $allowedPath = Join-Path $script:TestApp "Allowed.ini"

        $detectedWhilePaused = (
            (Ini-HasKey $allowedPath $pauseKey) `
            -or (Ini-HasKey $deniedPath $pauseKey) `
            -or (Log-HasText $pauseKey)
        )

        if (-not $detectedWhilePaused) {
            Add-Pass "Monitoring stayed inactive while paused"
        }
        else {
            Add-Fail `
                "Monitoring stayed inactive while paused" `
                "Pause state" `
                "The pause/resume test item was processed while monitoring was meant to be paused."
        }

        Show-TestInstructions @(
            "Return to the TEST copy.",
            "",
            "1. Click 'Resume Monitoring'.",
            "2. The Review window should now appear for:",
            "     $($Names.PauseFile)",
            "3. Leave that test item CHECKED (Allow).",
            "4. Click Apply.",
            "",
            "The tester will detect the completed Review automatically.",
            "There is no need to press anything in the test window afterwards."
        )

        Wait-ForResumeDecision $pauseKey

        Verify-Decision `
            "Pause/Resume detection" `
            $pauseKey `
            "Allowed" `
            "the Startup-folder test file" `
            (Test-Path -LiteralPath $Paths.PauseFile)

        if (Log-HasText "monitoring_resumed") {
            Add-Pass "Resume Monitoring action was recorded"
        }
        else {
            Add-Incomplete `
                "Resume Monitoring action" `
                "No monitoring_resumed event was found in the isolated Log.ini."
        }

        Remove-Item -LiteralPath $Paths.PauseFile -Force -ErrorAction SilentlyContinue
    }
    else {
        Add-Incomplete `
            "Base Move to Denied and Pause test" `
            "The required first-run baseline fixtures were not all detected, so this guided step was skipped."
    }

    # ------------------------------------------------------------------
    # Startup folder Allow and Deny
    # ------------------------------------------------------------------

    Write-Section "TEST 3 - STARTUP FOLDER REVIEW: ALLOW AND DENY"

    Show-TestInstructions @(
        "This test creates TWO harmless .txt files in your real per-user Startup folder.",
        "They cannot execute at logon.",
        "",
        "When Startup Monitor's Review window appears:",
        "",
        "  $($Names.AllowFile)",
        "      LEAVE CHECKED  = Allow",
        "",
        "  $($Names.DenyFile)",
        "      UNTICK         = Deny",
        "",
        "Click Apply.",
        "",
        "If unrelated items appear, LEAVE THEM CHECKED.",
        "Do not deny anything that does not begin with $Prefix.",
        "",
        "Press ENTER below to create the two test files."
    )

    Wait-Enter "Press ENTER to create the Startup-folder test items"

    Set-Content `
        -LiteralPath $Paths.AllowFile `
        -Value "Harmless Startup Monitor Allow test." `
        -Encoding UTF8

    Set-Content `
        -LiteralPath $Paths.DenyFile `
        -Value "Harmless Startup Monitor Deny test." `
        -Encoding UTF8

    $allowKey = [IO.Path]::GetFullPath($Paths.AllowFile)
    $denyKey = [IO.Path]::GetFullPath($Paths.DenyFile)

    Wait-ForDecisions `
        @($allowKey, $denyKey) `
        "Startup Folder Review"

    Verify-Decision `
        "Startup folder" `
        $allowKey `
        "Allowed" `
        "the Allow test file" `
        (Test-Path -LiteralPath $Paths.AllowFile)

    Verify-Decision `
        "Startup folder" `
        $denyKey `
        "Denied" `
        "the Deny test file" `
        (Test-Path -LiteralPath $Paths.DenyFile)

    Remove-Item -LiteralPath $Paths.AllowFile -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $Paths.DenyFile -Force -ErrorAction SilentlyContinue

    # ------------------------------------------------------------------
    # Registry Deny
    # ------------------------------------------------------------------

    Write-Section "TEST 4 - HKCU RUN REGISTRY DETECTION AND DENY"

    Show-TestInstructions @(
        "This test creates ONE temporary value in:",
        "HKCU\Software\Microsoft\Windows\CurrentVersion\Run",
        "",
        "The value runs only 'cmd.exe /c exit /b 0' and is harmless.",
        "",
        "When the Review window appears for:",
        "  $($Names.RegistryDeny)",
        "",
        "UNTICK it (Deny), then click Apply.",
        "",
        "Press ENTER below to create the Registry test value."
    )

    Wait-Enter "Press ENTER to create the Registry test value"

    Create-TestRegistryValue $Names.RegistryDeny

    $registryKey = "$RunKeySm64|$($Names.RegistryDeny)"

    Wait-ForDecisions `
        @($registryKey) `
        "HKCU Run Registry Review"

    Verify-Decision `
        "HKCU Run Registry" `
        $registryKey `
        "Denied" `
        "the HKCU Run test value" `
        (Registry-ValueExists $Names.RegistryDeny)

    Remove-TestRegistryValue $Names.RegistryDeny

    # ------------------------------------------------------------------
    # Scheduled Task Deny
    # ------------------------------------------------------------------

    Write-Section "TEST 5 - SCHEDULED TASK DETECTION AND DENY"

    Show-TestInstructions @(
        "This test creates ONE harmless Scheduled Task:",
        "  $($Names.TaskDeny)",
        "",
        "Its action is only 'cmd.exe /c exit /b 0'.",
        "The task is not run by this test.",
        "",
        "Scheduled Tasks are scanned every 10 seconds in this isolated test.",
        "",
        "When the Review window appears:",
        "UNTICK the test task (Deny), then click Apply.",
        "",
        "Press ENTER below to create the Scheduled Task."
    )

    Wait-Enter "Press ENTER to create the Scheduled Task"

    Create-TestTask $Names.TaskDeny

    $taskKey = "\$($Names.TaskDeny)"

    Wait-ForDecisions `
        @($taskKey) `
        "Scheduled Task Review" `
        180

    Verify-Decision `
        "Scheduled Task" `
        $taskKey `
        "Denied" `
        "the Scheduled Task" `
        (Task-Exists $Names.TaskDeny)

    Remove-TestTask $Names.TaskDeny

    # ------------------------------------------------------------------
    # Log coverage
    # ------------------------------------------------------------------

    Write-Section "TEST 6 - LOGGING"

    $expectedLogMarkers = @(
        $Names.AllowFile,
        $Names.DenyFile,
        $Names.RegistryDeny,
        $Names.TaskDeny
    )

    foreach ($marker in $expectedLogMarkers) {
        if (Log-HasText $marker) {
            Add-Pass "Log contains evidence for $marker"
        }
        else {
            Add-Fail `
                "Log contains evidence for $marker" `
                "Logging" `
                "The isolated Log.ini has no entry containing this test marker."
        }
    }

    # ------------------------------------------------------------------
    # Graceful shutdown
    # ------------------------------------------------------------------

    Write-Section "TEST 7 - NORMAL EXIT"

    Show-TestInstructions @(
        "Final step:",
        "",
        "Right-click the TEST copy's tray icon and choose Exit.",
        "",
        "The tester will detect when Startup Monitor closes automatically."
    )

    if (Wait-ForProcessExit 180) {
        Add-Pass "Startup Monitor exited normally from the tray"
    }
    else {
        Add-Fail `
            "Startup Monitor exited normally from the tray" `
            "Shutdown" `
            "The isolated StartupMonitor64.exe was still running after 180 seconds."
        Stop-TestProcess
    }

    Start-Sleep -Seconds 1

    if (
        (Log-HasText "worker_thread") `
        -and (Log-HasText "Monitoring worker stopped cleanly")
    ) {
        Add-Pass "Monitoring worker logged a clean shutdown"
    }
    else {
        Add-Fail `
            "Monitoring worker logged a clean shutdown" `
            "Shutdown logging" `
            "Expected clean worker shutdown evidence was not found in Log.ini."
    }

    Append-DiagnosticEvidence
}
catch {
    Write-Section "TEST ABORTED"
    Add-Fail `
        "Guided test completed" `
        "Test harness" `
        $_.Exception.Message

    if (Test-Path -LiteralPath $script:TestApp) {
        Append-DiagnosticEvidence
    }
}
finally {
    Write-Section "CLEANUP"

    Stop-TestProcess

    Remove-TestObjects

    $cleanupProblems = @()

    foreach ($file in $FilePaths) {
        if (Test-Path -LiteralPath $file) {
            $cleanupProblems += "File remains: $file"
        }
    }

    foreach ($name in $RegistryNames) {
        if (Registry-ValueExists $name) {
            $cleanupProblems += "Registry value remains: $name"
        }
    }

    foreach ($name in $TaskNames) {
        if (Task-Exists $name) {
            $cleanupProblems += "Scheduled Task remains: $name"
        }
    }

    if ($cleanupProblems.Count -eq 0) {
        Add-Pass "All temporary Windows test objects were removed"
    }
    else {
        Add-Fail `
            "All temporary Windows test objects were removed" `
            "Cleanup" `
            ($cleanupProblems -join "; ")
    }

    if (Test-Path -LiteralPath $Workspace) {
        Add-Fail `
            "Temporary isolated Startup Monitor installation was removed" `
            "Cleanup" `
            $Workspace
    }
    else {
        Add-Pass "Temporary isolated Startup Monitor installation was removed"
    }

    if ($script:FailCount -eq 0) {
        Remove-Item -LiteralPath $ManifestPath -Force -ErrorAction SilentlyContinue
    }
    else {
        # Keep no stale manifest when Windows objects are already gone.
        if ($cleanupProblems.Count -eq 0) {
            Remove-Item -LiteralPath $ManifestPath -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Section "TEST SUMMARY"

    Write-Line "- PASS checks: $script:PassCount"
    Write-Line "- FAIL checks: $script:FailCount"
    Write-Line "- INCOMPLETE checks: $script:IncompleteCount"
    Write-Line "- Results log: $ResultsPath"

    if ($script:FailCount -gt 0) {
        Write-Line "- OVERALL: FAIL"
    }
    elseif ($script:IncompleteCount -gt 0) {
        Write-Line "- OVERALL: INCOMPLETE"
    }
    else {
        Write-Line "- OVERALL: PASS"
    }

    Write-Line ""
    Write-Line "Only objects whose names begin with the reserved test prefix were used:"
    Write-Line "  $Prefix"
    Write-Line ""
    Write-Line "The user's normal Startup Monitor App folder was not opened or modified."
}
