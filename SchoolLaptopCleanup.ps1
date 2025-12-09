# SchoolLaptopCleanup.ps1
# Run as Administrator

param([switch]$DryRun)

Write-Output "=== Starting School Laptop Cleanup ==="

# --- Check for Administrator rights ---
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Output "ERROR: Please run this script as Administrator."
    exit 1
}

# --- Prevent screen from going dark ---
Write-Output "Disabling screen timeout temporarily..."
$acTimeout = (powercfg /query SCHEME_CURRENT SUB_VIDEO VIDEOIDLE).Split()[3]
$dcTimeout = (powercfg /query SCHEME_CURRENT SUB_VIDEO VIDEOIDLE).Split()[4]
powercfg /change monitor-timeout-ac 0
powercfg /change monitor-timeout-dc 0

# Prepare local log file
$hostname = $env:COMPUTERNAME
$logPath = "C:\Temp"
if (!(Test-Path $logPath)) { New-Item -ItemType Directory -Path $logPath | Out-Null }
$logFile = "$logPath\CleanupLog.txt"

# Log rotation: archive if >5MB
if (Test-Path $logFile -and (Get-Item $logFile).Length -gt 5MB) {
    $archiveName = "$logPath\CleanupLog_$(Get-Date -Format yyyyMMddHHmmss).txt"
    Rename-Item $logFile $archiveName
}

Add-Content $logFile "`n=== Cleanup started on $hostname at $(Get-Date) ==="

function Log-Step($step, $status, $error="") {
    $line = "$hostname,$step,$status,$(Get-Date),$error"
    Add-Content $logFile $line
    Write-Output $line
}

try {
    # 1. Delete user profiles
    Write-Output "Checking user profiles..."
    try {
        Get-CimInstance Win32_UserProfile | Where-Object {
            $_.LocalPath -notlike "*Administrator" -and
            $_.LocalPath -notlike "*Default*" -and
            $_.LocalPath -notlike "*Public*" -and
            $_.LocalPath -notlike "*systemprofile*" -and
            $_.LocalPath -notlike "*LocalService*" -and
            $_.LocalPath -notlike "*NetworkService*" -and
            $_.LocalPath -notlike "*WDAGUtilityAccount*"
        } | ForEach-Object {
            try {
                if ($DryRun) {
                    Write-Output "[DRY RUN] Would delete profile: $($_.LocalPath)"
                    Add-Content $logFile "[DRY RUN] Would delete profile: $($_.LocalPath)"
                } else {
                    Write-Output "Deleting profile: $($_.LocalPath)"
                    Remove-CimInstance $_
                    Add-Content $logFile "Deleted profile: $($_.LocalPath)"
                }
            } catch {
                Log-Step "ProfileDelete" "Error" $_.Exception.Message
            }
        }
        Log-Step "Profiles" "Success"
    } catch {
        Log-Step "Profiles" "Error" $_.Exception.Message
    }

    # 2. Group Policy update
    Write-Output "Running Group Policy Update..."
    try {
        if ($DryRun) {
            Write-Output "[DRY RUN] Would run gpupdate /force"
        } else {
            gpupdate /force | Out-Null
        }
        Log-Step "GroupPolicy" "Success"
    } catch {
        Log-Step "GroupPolicy" "Error" $_.Exception.Message
    }

    # 3. Windows Update
    Write-Output "Starting Windows Update..."
    try {
        if ($DryRun) {
            Write-Output "[DRY RUN] Would run Windows Update"
        } else {
            Start-Process "wuauclt.exe" -ArgumentList "/detectnow" -Wait
            Start-Process "wuauclt.exe" -ArgumentList "/updatenow" -Wait
        }
        Log-Step "WindowsUpdate" "Success"
    } catch {
        Log-Step "WindowsUpdate" "Error" $_.Exception.Message
    }

    # 4. Disk Cleanup
    Write-Output "Running Disk Cleanup..."
    try {
        if ($DryRun) {
            Write-Output "[DRY RUN] Would run cleanmgr /sagerun:1"
        } else {
            $sagesetConfigured = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
            if (-not $sagesetConfigured) {
                Write-Output "WARNING: Disk Cleanup options not configured. Run 'cleanmgr /sageset:1' manually first."
                Add-Content $logFile "WARNING: Disk Cleanup options not configured."
            }
            cleanmgr /sagerun:1
        }
        Log-Step "DiskCleanup" "Success"
    } catch {
        Log-Step "DiskCleanup" "Error" $_.Exception.Message
    }

    # 5. Defrag
    Write-Output "Running Defrag..."
    try {
        if ($DryRun) {
            Write-Output "[DRY RUN] Would run defrag C:"
        } else {
            defrag C: /U /V
        }
        Log-Step "Defrag" "Success"
    } catch {
        Log-Step "Defrag" "Error" $_.Exception.Message
    }

    # 6. Driver check
    Write-Output "Checking installed drivers..."
    try {
        if ($DryRun) {
            Write-Output "[DRY RUN] Would run driverquery"
        } else {
            driverquery /V /FO CSV > "$logPath\DriverReport.csv"
            Write-Output "Driver report saved to $logPath\DriverReport.csv"
        }
        Log-Step "DriverReport" "Success"
    } catch {
        Log-Step "DriverReport" "Error" $_.Exception.Message
    }

    # --- Restore screen timeout settings ---
    Write-Output "Restoring screen timeout settings..."
    if ($DryRun) {
        Write-Output "[DRY RUN] Would restore screen timeout settings"
    } else {
        powercfg /change monitor-timeout-ac $acTimeout
        powercfg /change monitor-timeout-dc $dcTimeout
    }
    Log-Step "ScreenTimeoutRestore" "Success"

    Write-Output "=== Cleanup Complete ==="
    Add-Content $logFile "=== Cleanup completed successfully on ${hostname} at $(Get-Date) ==="
}
catch {
    $errorMsg = $_.Exception.Message
    Write-Output "ERROR: $errorMsg"
    Add-Content $logFile "ERROR on ${hostname}: $errorMsg"
    Log-Step "Overall" "Error" $errorMsg
}