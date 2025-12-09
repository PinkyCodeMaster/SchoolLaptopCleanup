# Simpler header for maximum compatibility on older PowerShell hosts
param(
    [string]$Mode = 'Automatic',
    [int]$DefragPasses = 3,
    [string]$ServerPath
)

# Relaunch in PowerShell with Admin rights if opened incorrectly
if (-not $PSVersionTable -or -not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -ArgumentList "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" @PSBoundParameters" -Verb RunAs
    exit
}

$ErrorActionPreference = 'Continue'
$hostname = $env:COMPUTERNAME
$script:LogFile = $null
$script:LogRoot = $null

function Write-Log {
    param(
        [Parameter(Mandatory)] [string]$Step,
        [Parameter(Mandatory)] [string]$Status,
        [string]$Message = ''
    )

    $line = '"' + $hostname + '","' + $Step + '","' + $Status + '","' + (Get-Date) + '","' + $Message.Replace('"', "''") + '"'
    if ($script:LogFile) { Add-Content -Path $script:LogFile -Value $line }
    Write-Output $line
}

function Initialize-Logging {
    param([string]$ServerPath)

    $header = "`n=== Cleanup started on $hostname at $(Get-Date) ==="

    if (-not [string]::IsNullOrWhiteSpace($ServerPath)) {
        try {
            $script:LogRoot = Join-Path -Path $ServerPath -ChildPath "LaptopLogs\\$hostname"
            if (-not (Test-Path $script:LogRoot)) {
                Write-Output "Creating log directory on server: $script:LogRoot"
                New-Item -ItemType Directory -Path $script:LogRoot -Force -ErrorAction Stop | Out-Null
            }

            $script:LogFile = Join-Path -Path $script:LogRoot -ChildPath 'CleanupLog.txt'
            if (-not (Test-Path $script:LogFile)) {
                New-Item -ItemType File -Path $script:LogFile -Force -ErrorAction Stop | Out-Null
            }

            if ((Get-Item -Path $script:LogFile -ErrorAction Stop).Length -gt 5MB) {
                $archive = Join-Path -Path $script:LogRoot -ChildPath "CleanupLog_$(Get-Date -Format yyyyMMddHHmmss).txt"
                Move-Item -Path $script:LogFile -Destination $archive -Force -ErrorAction Stop
                New-Item -ItemType File -Path $script:LogFile -Force -ErrorAction Stop | Out-Null
            }

            Add-Content -Path $script:LogFile -Value $header
            Write-Output "Logging to central share: $script:LogFile"
            return
        }
        catch {
            Write-Warning "Failed to use server path '$ServerPath'. Falling back to local logging. Error: $($_.Exception.Message)"
            $script:LogRoot = $null
            $script:LogFile = $null
        }
    }

    try {
        $script:LogRoot = 'C:\\Temp'
        if (-not (Test-Path $script:LogRoot)) {
            New-Item -ItemType Directory -Path $script:LogRoot -Force -ErrorAction Stop | Out-Null
        }

        $script:LogFile = Join-Path -Path $script:LogRoot -ChildPath 'CleanupLog.txt'
        if (-not (Test-Path $script:LogFile)) {
            New-Item -ItemType File -Path $script:LogFile -Force -ErrorAction Stop | Out-Null
        }

        if ((Get-Item -Path $script:LogFile -ErrorAction Stop).Length -gt 5MB) {
            $archive = Join-Path -Path $script:LogRoot -ChildPath "CleanupLog_$(Get-Date -Format yyyyMMddHHmmss).txt"
            Move-Item -Path $script:LogFile -Destination $archive -Force -ErrorAction Stop
            New-Item -ItemType File -Path $script:LogFile -Force -ErrorAction Stop | Out-Null
        }

        Add-Content -Path $script:LogFile -Value $header
        Write-Output "Logging locally: $script:LogFile"
    }
    catch {
        Write-Error "Failed to set up logging. Continuing without file logging. Error: $($_.Exception.Message)"
        $script:LogFile = $null
        $script:LogRoot = $null
    }
}

function Set-ScreenAwake {
    Write-Output 'Disabling screen timeout temporarily...'
    try {
        powercfg /change monitor-timeout-ac 0 | Out-Null
        powercfg /change monitor-timeout-dc 0 | Out-Null
        Write-Log -Step 'ScreenTimeout' -Status 'Adjusted'
        return $true
    }
    catch {
        Write-Warning "Could not change screen timeout settings: $($_.Exception.Message)"
        Write-Log -Step 'ScreenTimeout' -Status 'Skipped' -Message $_.Exception.Message
        return $false
    }
}

function Restore-ScreenTimeout {
    try {
        powercfg /restoredefaultschemes | Out-Null
        Write-Log -Step 'ScreenTimeoutRestore' -Status 'Success'
    }
    catch {
        Write-Warning "Failed to restore screen timeout settings: $($_.Exception.Message)"
        Write-Log -Step 'ScreenTimeoutRestore' -Status 'Error' -Message $_.Exception.Message
    }
}

function Clear-StaleProfiles {
    Write-Log -Step 'Profiles' -Status 'Starting'
    $excludeSids = @('S-1-5-18', 'S-1-5-19', 'S-1-5-20')
    $excludeNames = @('Administrator', 'Default', 'Public', 'WDAGUtilityAccount')

    try {
        Get-CimInstance Win32_UserProfile | ForEach-Object {
            $profileName = Split-Path $_.LocalPath -Leaf
            if (($_.SID -notin $excludeSids) -and ($profileName -notin $excludeNames) -and (-not $_.Loaded)) {
                Write-Output "Deleting profile: $($_.LocalPath)"
                $_ | Remove-CimInstance -ErrorAction Stop
                Write-Log -Step 'Profiles' -Status 'Deleted' -Message $profileName
            }
            else {
                Write-Output "Skipping safe/active profile: $($_.LocalPath)"
            }
        }
        Write-Log -Step 'Profiles' -Status 'Success'
    }
    catch {
        Write-Log -Step 'Profiles' -Status 'Error' -Message $_.Exception.Message
    }
}

function Invoke-GroupPolicyUpdate {
    try {
        gpupdate /force | Out-Null
        Write-Log -Step 'GroupPolicy' -Status 'Success'
    }
    catch {
        Write-Log -Step 'GroupPolicy' -Status 'Error' -Message $_.Exception.Message
    }
}

function Invoke-WindowsUpdate {
    try {
        Start-Process 'UsoClient.exe' -ArgumentList 'StartScan' -Wait -ErrorAction Stop
        Start-Process 'UsoClient.exe' -ArgumentList 'StartDownload' -Wait -ErrorAction Stop
        Start-Process 'UsoClient.exe' -ArgumentList 'StartInstall' -Wait -ErrorAction Stop
        Write-Warning 'Windows Update triggered (UsoClient); installation may require reboot.'
        Write-Log -Step 'WindowsUpdate' -Status 'Success'
    }
    catch {
        Write-Warning 'UsoClient not available, using legacy wuauclt.'
        try {
            Start-Process 'wuauclt.exe' -ArgumentList '/detectnow' -Wait -ErrorAction Stop
            Start-Process 'wuauclt.exe' -ArgumentList '/updatenow' -Wait -ErrorAction Stop
            Write-Log -Step 'WindowsUpdate' -Status 'Success (Legacy)'
        }
        catch {
            Write-Log -Step 'WindowsUpdate' -Status 'Error' -Message "Both UsoClient and wuauclt failed: $($_.Exception.Message)"
        }
    }
}

function Invoke-DiskCleanup {
    try {
        if (-not (Test-Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\VolumeCaches')) {
            Write-Warning "Disk Cleanup options not configured. Run 'cleanmgr /sageset:1' first."
            Write-Log -Step 'DiskCleanup' -Status 'Skipped' -Message 'Not configured'
        }
        else {
            cleanmgr /sagerun:1
            Write-Log -Step 'DiskCleanup' -Status 'Success'
        }
    }
    catch {
        Write-Log -Step 'DiskCleanup' -Status 'Error' -Message $_.Exception.Message
    }
}

function Invoke-Defrag {
    param([int]$Passes)

    try {
        $passesToRun = if ($Passes -ge 1 -and $Passes -le 6) { $Passes } else { 3 }

        $drive = Get-PhysicalDisk | Where-Object { $_.BusType -eq 'SATA' -or $_.BusType -eq 'NVMe' } | Select-Object -First 1
        if ($null -eq $drive) {
            Write-Warning 'No physical disk information found; skipping defrag.'
            Write-Log -Step 'Defrag' -Status 'Skipped' -Message 'Drive not detected'
            return
        }

        if ($drive.MediaType -eq 4 -or $drive.MediaType -eq 'SSD') {
            Write-Output "SSD detected ($($drive.MediaType)) — skipping defrag."
            Write-Log -Step 'Defrag' -Status 'Skipped' -Message 'SSD detected'
        }
        else {
            Write-Output "HDD detected ($($drive.MediaType)) — starting defrag for $passesToRun passes."
            defrag C: /U /V /Passes:$passesToRun
            Write-Log -Step 'Defrag' -Status 'Success' -Message "$passesToRun passes"
        }
    }
    catch {
        Write-Log -Step 'Defrag' -Status 'Error' -Message $_.Exception.Message
    }
}

function Export-DriverReport {
    try {
        if ($script:LogRoot) {
            $reportPath = Join-Path -Path $script:LogRoot -ChildPath 'DriverReport.csv'
            driverquery /V /FO CSV > $reportPath
            Write-Output "Driver report saved to $reportPath"
            Write-Log -Step 'DriverReport' -Status 'Success'
        }
        else {
            Write-Warning 'No log path available. Cannot generate driver report.'
            Write-Log -Step 'DriverReport' -Status 'Skipped' -Message 'Missing log path'
        }
    }
    catch {
        Write-Log -Step 'DriverReport' -Status 'Error' -Message $_.Exception.Message
    }
}

function Resolve-Mode {
    if ($PSBoundParameters.ContainsKey('Mode')) { return $Mode }

    $selection = Read-Host "Choose mode: Automatic (A) or Manual (M)"
    switch ($selection.ToUpper()) {
        'A' { return 'Automatic' }
        'M' { return 'Manual' }
        default { return 'Automatic' }
    }
}

try {
    Write-Output '=== School Laptop Cleanup ==='
    Initialize-Logging -ServerPath $ServerPath
    $screenManaged = Set-ScreenAwake

    $selectedMode = Resolve-Mode

    if ($selectedMode -eq 'Automatic') {
        Write-Output 'Running AUTOMATIC cleanup...'
        Clear-StaleProfiles
        Invoke-GroupPolicyUpdate
        Invoke-WindowsUpdate
        Invoke-DiskCleanup
        Invoke-Defrag -Passes $DefragPasses
        Export-DriverReport
        Write-Output '=== Automatic Cleanup Complete ==='
    }
    else {
        Write-Output 'Running MANUAL cleanup...'

        if ((Read-Host 'Delete non-system user profiles? (Y/N)').ToUpper() -eq 'Y') { Clear-StaleProfiles } else { Write-Log -Step 'Profiles' -Status 'Skipped' -Message 'User choice' }
        if ((Read-Host 'Run Group Policy Update (Y/N)').ToUpper() -eq 'Y') { Invoke-GroupPolicyUpdate } else { Write-Log -Step 'GroupPolicy' -Status 'Skipped' -Message 'User choice' }
        if ((Read-Host 'Trigger Windows Update (Y/N)').ToUpper() -eq 'Y') { Invoke-WindowsUpdate } else { Write-Log -Step 'WindowsUpdate' -Status 'Skipped' -Message 'User choice' }
        if ((Read-Host 'Run Disk Cleanup (Y/N)').ToUpper() -eq 'Y') { Invoke-DiskCleanup } else { Write-Log -Step 'DiskCleanup' -Status 'Skipped' -Message 'User choice' }

        if ((Read-Host 'Run Defrag? (Y/N)').ToUpper() -eq 'Y') {
            $manualPasses = Read-Host 'How many defrag passes (1-6)?'
            [int]$manualPassesInt = 0
            [void][int]::TryParse($manualPasses, [ref]$manualPassesInt)
            Invoke-Defrag -Passes $manualPassesInt
        }
        else {
            Write-Log -Step 'Defrag' -Status 'Skipped' -Message 'User choice'
        }

        if ((Read-Host 'Generate driver report? (Y/N)').ToUpper() -eq 'Y') { Export-DriverReport } else { Write-Log -Step 'DriverReport' -Status 'Skipped' -Message 'User choice' }

        Write-Output '=== Manual Cleanup Complete ==='
    }

    if ($script:LogFile) { Add-Content -Path $script:LogFile -Value "=== Cleanup completed successfully on ${hostname} at $(Get-Date) ===" }
}
catch {
    $errorMsg = $_.Exception.Message
    Write-Output "CRITICAL ERROR (Main Block): $errorMsg"
    if ($script:LogFile) { Add-Content -Path $script:LogFile -Value "CRITICAL ERROR on ${hostname}: $errorMsg" }
    Write-Log -Step 'Overall' -Status 'Error' -Message $errorMsg
}
finally {
    if ($screenManaged) { Restore-ScreenTimeout }
}
