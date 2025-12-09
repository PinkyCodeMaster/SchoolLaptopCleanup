# Relaunch in PowerShell if opened incorrectly/without Admin rights
if (-not $PSVersionTable -or -not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -ArgumentList "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

#Requires -RunAsAdministrator
<#
.SYNOPSIS
    School Laptop Cleanup Script - Unified Edition
.DESCRIPTION
    Automates common cleanup and maintenance tasks. Prompts the user to choose Automatic or Manual mode and for central logging path.
.NOTES
    Author: PinkyCodeMaster
    License: MIT
#>

Write-Output "=== School Laptop Cleanup ==="

# --- Prevent screen from going dark ---
Write-Output "Disabling screen timeout temporarily..."
try {
    powercfg /change monitor-timeout-ac 0 | Out-Null
    powercfg /change monitor-timeout-dc 0 | Out-Null
} catch {
    Write-Warning "Could not change screen timeout settings. Policy likely prevents this."
}

# --- Prepare logging ---
$hostname = $env:COMPUTERNAME
$logFile = $null # Initialize $logFile as null by default

# Prompt the user for their school file server path
Write-Output "Enter your school's file server UNC path (e.g., \\pat-fs1\c$), or leave blank for local logging only:"
$serverInput = Read-Host "Server Path"

if (-not [string]::IsNullOrEmpty($serverInput)) {
    # User provided input. Try to use it for central logging.
    $centralLogPath = Join-Path -Path $serverInput -ChildPath "LaptopLogs\$hostname"
    
    try {
        # Check if we can create the log directory on the network share
        if (!(Test-Path $centralLogPath)) { 
            New-Item -ItemType Directory -Path $centralLogPath -Force -ErrorAction Stop | Out-Null 
        }
        
        $logFile = "$centralLogPath\CleanupLog.txt"
        
        # Log rotation: archive if >5MB
        if (Test-Path $logFile -and (Get-Item $logFile).Length -gt 5MB) {
            $archiveName = "$centralLogPath\CleanupLog_$(Get-Date -Format yyyyMMddHHmmss).txt"
            Rename-Item $logFile $archiveName
        }

        Add-Content $logFile "`n=== Cleanup started on $hostname at $(Get-Date) ==="
        Write-Output "Logging to central share: $logFile"

    } catch {
        Write-Warning "Failed to access central log path ($serverInput). Falling back to local C:\Temp logging."
        $serverInput = $null # Clear input to force local fallback logic
    }
}

# This 'else' covers: 
# 1. User left the prompt blank initially.
# 2. Network connection failed in the 'try' block above.
if ([string]::IsNullOrEmpty($serverInput)) {
    Write-Output "Using local logging fallback only."
    $logPath = "C:\Temp"
    try {
        if (!(Test-Path $logPath)) { New-Item -ItemType Directory -Path $logPath -ErrorAction Stop | Out-Null }
        $logFile = "$logPath\CleanupLog.txt"
        Add-Content $logFile "`n=== Cleanup started on $hostname (LOCAL FALLBACK) at $(Get-Date) ==="
    } catch {
        Write-Error "Failed to set up local logging in C:\Temp. Script will continue without file logging."
        $logFile = $null # Disable file logging entirely
    }
}


function Log-Step($step, $status, $errorMsg="") {
    $line = '"' + $hostname + '","' + $step + '","' + $status + '","' + (Get-Date) + '","' + $errorMsg + '"'
    if ($logFile) { Add-Content $logFile $line }
    Write-Output $line
}

function Cleanup-Profiles {
    Log-Step "Profiles Cleanup" "Starting"
    # Define excluded system SIDs and common names
    $exclude_sids = @("S-1-5-18", "S-1-5-19", "S-1-5-20")
    $exclude_names = @("Administrator", "Default", "Public", "WDAGUtilityAccount")
    
    try {
        Get-CimInstance Win32_UserProfile | ForEach-Object {
            $profile_name = Split-Path $_.LocalPath -Leaf
            # Check if SID/Name is excluded AND if profile is currently in use
            if (($_.SID -notin $exclude_sids) -and ($profile_name -notin $exclude_names) -and (-not $_.Loaded)) {
                Write-Output "Deleting profile: $($_.LocalPath)"
                # Use -ErrorAction Stop to ensure catch block is hit if deletion fails
                $_ | Remove-CimInstance -ErrorAction Stop
                Log-Step "Profiles" "Deleted: $profile_name"
            }
            else {
                 Write-Output "Skipping safe/active profile: $($_.LocalPath)"
            }
        }
        Log-Step "Profiles" "Success (Overall)"
    }
    catch { Log-Step "Profiles" "Error" $_.Exception.Message }
}

function Cleanup-GroupPolicy {
    try { gpupdate /force | Out-Null; Log-Step "GroupPolicy" "Success" }
    catch { Log-Step "GroupPolicy" "Error" $_.Exception.Message }
}

function Cleanup-WindowsUpdate {
    try {
        # Try modern methods first
        Start-Process "UsoClient.exe" -ArgumentList "StartScan" -Wait
        Start-Process "UsoClient.exe" -ArgumentList "StartDownload" -Wait
        Start-Process "UsoClient.exe" -ArgumentList "StartInstall" -Wait
        Write-Warning "Windows Update triggered (UsoClient); installation may require reboot."
        Log-Step "WindowsUpdate" "Success"
    }
    catch { 
        # Fallback to legacy wuauclt if UsoClient fails
        Write-Warning "UsoClient not available, using legacy wuauclt."
        try {
            Start-Process "wuauclt.exe" -ArgumentList "/detectnow" -Wait
            Start-Process "wuauclt.exe" -ArgumentList "/updatenow" -Wait
            Log-Step "WindowsUpdate" "Success (Legacy)"
        }
        catch {
             Log-Step "WindowsUpdate" "Error" "Both UsoClient and wuauclt failed: $_.Exception.Message"
        }
    }
}

function Cleanup-Disk {
    try {
        # Check if settings are configured via the registry path
        if (-not (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches")) {
            Write-Warning "Disk Cleanup options not configured. Run 'cleanmgr /sageset:1' first on this machine."
            Log-Step "DiskCleanup" "Skipped (Not Configured)"
        }
        else {
            cleanmgr /sagerun:1
            Log-Step "DiskCleanup" "Success"
        }
    }
    catch { Log-Step "DiskCleanup" "Error" $_.Exception.Message }
}

function Cleanup-Defrag($passes=3) {
    try {
        # Validate input for passes (ensure it's an integer between 1 and 6)
        if ($passes -match '^[1-6]$') {
            # Check drive type more robustly: MediaType 3=HDD, 4=SSD
            $drive = Get-PhysicalDisk | Where-Object { $_.BusType -eq 'SATA' -or $_.BusType -eq 'NVMe' } | Select-Object -First 1
            
            if ($drive.MediaType -eq 4 -or $drive.MediaType -eq "SSD") {
                Write-Output "SSD detected ($($drive.MediaType)) — skipping defrag."
                Log-Step "Defrag" "Skipped (SSD)"
            }
            else {
                Write-Output "HDD detected ($($drive.MediaType)) — starting defrag for $passes passes."
                defrag C: /U /V /Passes:$passes
                Log-Step "Defrag" "Success"
            }
        }
        else {
            Write-Warning "Invalid input for passes, skipping defrag."
            Log-Step "Defrag" "Skipped (Invalid Input)"
        }
    }
    catch { Log-Step "Defrag" "Error" $_.Exception.Message }
}

function Cleanup-Drivers {
    try {
        # $logPath is now defined in the main logging block fallback, ensure it is available if logging locally
        if ($logPath) {
             driverquery /V /FO CSV > "$logPath\DriverReport.csv"
             Write-Output "Driver report saved to $logPath\DriverReport.csv"
             Log-Step "DriverReport" "Success"
        } else {
             Write-Warning "C:\Temp path not available. Cannot generate driver report."
             Log-Step "DriverReport" "Skipped (Path Error)"
        }
    }
    catch { Log-Step "DriverReport" "Error" $_.Exception.Message }
}

function Restore-ScreenTimeout {
    # Original timeout values were hardcoded to 10 earlier, changing them back to default system values is safer
    powercfg /restoredefaultschemes | Out-Null 
    Log-Step "ScreenTimeoutRestore" "Success"
}

# --- Main execution logic (Mode selection remains the same but calls the improved functions) ---

# --- Mode selection ---
$mode = Read-Host "Choose mode: Automatic (A) or Manual (M)"

try {
    if ($mode -eq "A") {
        Write-Output "Running AUTOMATIC cleanup..."
        Cleanup-Profiles
        Cleanup-GroupPolicy
        Cleanup-WindowsUpdate
        Cleanup-Disk
        Cleanup-Defrag -passes 3
        Cleanup-Drivers
        Restore-ScreenTimeout
        Write-Output "=== Automatic Cleanup Complete ==="
    }
    else {
        Write-Output "Running MANUAL cleanup..."
        $choice = Read-Host "Delete non-system user profiles? (Y/N)"
        if ($choice -eq "Y") { Cleanup-Profiles } else { Log-Step "Profiles" "Skipped (User Choice)" }

        $choice = Read-Host "Run Group Policy Update (Y/N)"
        if ($choice -eq "Y") { Cleanup-GroupPolicy } else { Log-Step "GroupPolicy" "Skipped (User Choice)" }

        $choice = Read-Host "Trigger Windows Update (Y/N)"
        if ($choice -eq "Y") { Cleanup-WindowsUpdate } else { Log-Step "WindowsUpdate" "Skipped (User Choice)" }

        $choice = Read-Host "Run Disk Cleanup (Y/N)"
        if ($choice -eq "Y") { Cleanup-Disk } else { Log-Step "DiskCleanup" "Skipped (User Choice)" }

        $choice = Read-Host "Run Defrag? (Y/N)"
        if ($choice -eq "Y") {
            $passes = Read-Host "How many defrag passes (1-6)?"
            Cleanup-Defrag -passes $passes
        } else { Log-Step "Defrag" "Skipped (User Choice)" }

        $choice = Read-Host "Generate driver report? (Y/N)"
        if ($choice -eq "Y") { Cleanup-Drivers } else { Log-Step "DriverReport" "Skipped (User Choice)" }

        Restore-ScreenTimeout 
        Write-Output "=== Manual Cleanup Complete ==="
    }
    
    # --- Final Logging ---
    if ($logFile) { Add-Content $logFile "=== Cleanup completed successfully on ${hostname} at $(Get-Date) ===" }

}
catch {
    $errorMsg = $_.Exception.Message
    Write-Output "CRITICAL ERROR (Main Block): $errorMsg"
    if ($logFile) { Add-Content $logFile "CRITICAL ERROR on ${hostname}: $errorMsg" }
    Log-Step "Overall" "Error" $errorMsg
}
