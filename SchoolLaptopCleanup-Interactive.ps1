#Requires -RunAsAdministrator
<#
.SYNOPSIS
    School Laptop Cleanup Script - Interactive Edition
.DESCRIPTION
    Prompts the user step-by-step for each cleanup task (Y/N).
    Allows custom defrag passes (1–6).
.NOTES
    Author: PinkyCodeMaster
    License: MIT
#>

Write-Output "=== Starting School Laptop Cleanup (Interactive Edition) ==="

# --- Prevent screen from going dark ---
Write-Output "Disabling screen timeout temporarily..."
# Simplify: set to 10 minutes as safe default, restore later
$acTimeout = 10
$dcTimeout = 10
powercfg /change monitor-timeout-ac 0
powercfg /change monitor-timeout-dc 0

# --- Prepare logging ---
$hostname = $env:COMPUTERNAME
$logPath = "C:\Temp"
if (!(Test-Path $logPath)) { New-Item -ItemType Directory -Path $logPath | Out-Null }
$logFile = "$logPath\CleanupLog.txt"

# Log rotation: archive if >5MB
if (Test-Path $logFile -and (Get-Item $logFile).Length -gt 5MB) {
    $archiveName = "$logPath\CleanupLog_$(Get-Date -Format yyyyMMddHHmmss).txt"
    Rename-Item $logFile $archiveName
}

Add-Content $logFile "`n=== Interactive Cleanup started on $hostname at $(Get-Date) ==="

function Log-Step($step, $status, $error="") {
    $line = '"' + $hostname + '","' + $step + '","' + $status + '","' + (Get-Date) + '","' + $error + '"'
    Add-Content $logFile $line
    Write-Output $line
}

try {
    # 1. Delete user profiles
    $choice = Read-Host "Delete non-system user profiles? (Y/N)"
    if ($choice -eq "Y") {
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
                Write-Output "Deleting profile: $($_.LocalPath)"
                Remove-CimInstance $_
                Add-Content $logFile '"Deleted profile","' + $_.LocalPath + '"'
            }
            Log-Step "Profiles" "Success"
        } catch {
            Log-Step "Profiles" "Error" $_.Exception.Message
        }
    } else {
        Log-Step "Profiles" "Skipped (User Choice)"
    }

    # 2. Group Policy update
    $choice = Read-Host "Run Group Policy Update (gpupdate /force)? (Y/N)"
    if ($choice -eq "Y") {
        try {
            gpupdate /force | Out-Null
            Log-Step "GroupPolicy" "Success"
        } catch {
            Log-Step "GroupPolicy" "Error" $_.Exception.Message
        }
    } else {
        Log-Step "GroupPolicy" "Skipped (User Choice)"
    }

    # 3. Windows Update
    $choice = Read-Host "Trigger Windows Update scan/install? (Y/N)"
    if ($choice -eq "Y") {
        try {
            try {
                Start-Process "UsoClient.exe" -ArgumentList "StartScan" -Wait
                Start-Process "UsoClient.exe" -ArgumentList "StartDownload" -Wait
                Start-Process "UsoClient.exe" -ArgumentList "StartInstall" -Wait
                Write-Warning "Windows Update triggered; installation may require reboot or further cycles."
                Log-Step "WindowsUpdate" "Success"
            } catch {
                Write-Warning "UsoClient not available, falling back to wuauclt."
                Start-Process "wuauclt.exe" -ArgumentList "/detectnow" -Wait
                Start-Process "wuauclt.exe" -ArgumentList "/updatenow" -Wait
                Log-Step "WindowsUpdate" "Success (Legacy)"
            }
        } catch {
            Log-Step "WindowsUpdate" "Error" $_.Exception.Message
        }
    } else {
        Log-Step "WindowsUpdate" "Skipped (User Choice)"
    }

    # 4. Disk Cleanup
    $choice = Read-Host "Run Disk Cleanup (cleanmgr /sagerun:1)? (Y/N)"
    if ($choice -eq "Y") {
        try {
            if (-not (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches")) {
                Write-Warning "Disk Cleanup options not configured. Run 'cleanmgr /sageset:1' manually first."
                Add-Content $logFile "WARNING: Disk Cleanup options not configured."
            }
            cleanmgr /sagerun:1
            Log-Step "DiskCleanup" "Success"
        } catch {
            Log-Step "DiskCleanup" "Error" $_.Exception.Message
        }
    } else {
        Log-Step "DiskCleanup" "Skipped (User Choice)"
    }

    # 5. Defrag
    $choice = Read-Host "Run Defrag? (Y/N)"
    if ($choice -eq "Y") {
        $passes = Read-Host "How many defrag passes (1–6)?"
        try {
            if ($passes -match '^[1-6]$') {
                $driveType = (Get-PhysicalDisk | Where-Object DeviceID -eq 0).MediaType
                if ($driveType -eq "SSD") {
                    Write-Output "SSD detected — skipping defrag."
                    Log-Step "Defrag" "Skipped (SSD)"
                } else {
                    defrag C: /U /V /Passes:$passes
                    Log-Step "Defrag" "Success"
                }
            } else {
                Write-Warning "Invalid input, skipping defrag."
                Log-Step "Defrag" "Skipped (Invalid Input)"
            }
        } catch {
            Log-Step "Defrag" "Error" $_.Exception.Message
        }
    } else {
        Log-Step "Defrag" "Skipped (User Choice)"
    }

    # 6. Driver check
    $choice = Read-Host "Generate driver report? (Y/N)"
    if ($choice -eq "Y") {
        try {
            driverquery /V /FO CSV > "$logPath\DriverReport.csv"
            Write-Output "Driver report saved to $logPath\DriverReport.csv"
            Log-Step "DriverReport" "Success"
        } catch {
            Log-Step "DriverReport" "Error" $_.Exception.Message
        }
    } else {
        Log-Step "DriverReport" "Skipped (User Choice)"
    }

    # --- Restore screen timeout settings ---
    Write-Output "Restoring screen timeout settings..."
    powercfg /change monitor-timeout-ac $acTimeout
    powercfg /change monitor-timeout-dc $dcTimeout
    Log-Step "ScreenTimeoutRestore" "Success"

    Write-Output "=== Interactive Cleanup Complete ==="
    Add-Content $logFile "=== Interactive Cleanup completed successfully on ${hostname} at $(Get-Date) ==="
}
catch {
    $errorMsg = $_.Exception.Message
    Write-Output "ERROR: $errorMsg"
    Add-Content $logFile "ERROR on ${hostname}: $errorMsg"
    Log-Step "Overall" "Error" $errorMsg
}