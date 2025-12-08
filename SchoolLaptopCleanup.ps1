# SchoolLaptopCleanup.ps1
# Run as Administrator

# TODO: Verify error handling logs both locally and to server summary file
# TODO: Confirm hostname is correctly recorded in logs and central CSV
# TODO: Manually log into \\YourServer\CleanupLogs to ensure write permissions
# TODO: Update README if features change (Dry Run, server logging, hostname tracking)
# TODO: Add .gitignore entries for CleanupLog.txt and DriverReport.txt
# TODO: Confirm RunCleanup.bat points to correct GitHub raw URL
# TODO: Run cleanmgr /sageset:1 once manually to configure cleanup options
# TODO: Consider adding per‑step success/failure logging to server CSV
# TODO: Decide if you want to automate via Task Scheduler (later)

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
Add-Content $logFile "`n=== Cleanup started on $hostname at $(Get-Date) ==="

# Prepare server summary file
$serverPath = "\\YourServer\CleanupLogs"
$summaryFile = "$serverPath\Summary.csv"

# Check server connectivity
if (-not (Test-Connection -ComputerName "YourServer" -Count 1 -Quiet)) {
    Write-Output "WARNING: Server not reachable. Logs will only be saved locally."
}

function Log-Step($step, $status, $error="") {
    $line = "$hostname,$step,$status,$(Get-Date),$error"
    Add-Content $logFile $line
    try {
        Add-Content $summaryFile $line
    } catch {
        Write-Output "Could not write $step result to server summary file."
    }
}

try {
    # 1. Delete user profiles
    Write-Output "Checking user profiles..."
    try {
        Get-CimInstance Win32_UserProfile | Where-Object {
            $_.LocalPath -notlike "*Administrator" -and
            $_.LocalPath -notlike "*Default*" -and
            $_.LocalPath -notlike "*Public*"
        } | ForEach-Object {
            if ($DryRun) {
                Write-Output "[DRY RUN] Would delete profile: $($_.LocalPath)"
                Add-Content $logFile "[DRY RUN] Would delete profile: $($_.LocalPath)"
            } else {
                Write-Output "Deleting profile: $($_.LocalPath)"
                Remove-CimInstance $_
                Add-Content $logFile "Deleted profile: $($_.LocalPath)"
            }
        }
        Log-Step "Profiles" "Success"
    } catch {
        Log-Step "Profiles" "Error" $_.Exception.Message
    }

    # 2. Group Policy update
    Write-Output "Running Group Policy Update..."
    try {
        gpupdate /force | Out-Null
        Log-Step "GroupPolicy" "Success"
    } catch {
        Log-Step "GroupPolicy" "Error" $_.Exception.Message
    }

    # 3. Windows Update
    Write-Output "Starting Windows Update..."
    try {
        Start-Process "wuauclt.exe" -ArgumentList "/detectnow" -Wait
        Start-Process "wuauclt.exe" -ArgumentList "/updatenow" -Wait
        Log-Step "WindowsUpdate" "Success"
    } catch {
        Log-Step "WindowsUpdate" "Error" $_.Exception.Message
    }

    # 4. Disk Cleanup
    Write-Output "Running Disk Cleanup..."
    try {
        cleanmgr /sagerun:1
        Log-Step "DiskCleanup" "Success"
    } catch {
        Log-Step "DiskCleanup" "Error" $_.Exception.Message
    }

    # 5. Defrag
    Write-Output "Running Defrag..."
    try {
        defrag C: /U /V
        Log-Step "Defrag" "Success"
    } catch {
        Log-Step "Defrag" "Error" $_.Exception.Message
    }

    # 6. Driver check
    Write-Output "Checking installed drivers..."
    try {
        driverquery /V /FO Table > "$logPath\DriverReport.txt"
        Write-Output "Driver report saved to $logPath\DriverReport.txt"
        Log-Step "DriverReport" "Success"
    } catch {
        Log-Step "DriverReport" "Error" $_.Exception.Message
    }

    # --- Restore screen timeout settings ---
    Write-Output "Restoring screen timeout settings..."
    powercfg /change monitor-timeout-ac $acTimeout
    powercfg /change monitor-timeout-dc $dcTimeout
    Log-Step "ScreenTimeoutRestore" "Success"

    Write-Output "=== Cleanup Complete ==="
    Add-Content $logFile "=== Cleanup completed successfully on $hostname at $(Get-Date) ==="
}
catch {
    $errorMsg = $_.Exception.Message
    Write-Output "ERROR: $errorMsg"
    Add-Content $logFile "ERROR on $hostname: $errorMsg"
    Log-Step "Overall" "Error" $errorMsg
}