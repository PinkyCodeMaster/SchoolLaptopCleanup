# SchoolLaptopCleanup.ps1
# Run as Administrator

Write-Output "=== Starting School Laptop Cleanup ==="

# --- Prevent screen from going dark ---
Write-Output "Disabling screen timeout temporarily..."
# Save current settings
$acTimeout = (powercfg /query SCHEME_CURRENT SUB_VIDEO VIDEOIDLE).Split()[3]
$dcTimeout = (powercfg /query SCHEME_CURRENT SUB_VIDEO VIDEOIDLE).Split()[4]

# Set display timeout to 0 (never) for AC and DC power
powercfg /change monitor-timeout-ac 0
powercfg /change monitor-timeout-dc 0

# 1. Delete all user profiles except Administrator, Default, and Public
Get-CimInstance Win32_UserProfile | Where-Object {
    $_.LocalPath -notlike "*Administrator" -and
    $_.LocalPath -notlike "*Default*" -and
    $_.LocalPath -notlike "*Public*"
} | ForEach-Object {
    Write-Output "Deleting profile: $($_.LocalPath)"
    Remove-CimInstance $_
}

# 2. Force Group Policy update
Write-Output "Running Group Policy Update..."
gpupdate /force

# 3. Trigger Windows Update
Write-Output "Starting Windows Update..."
Start-Process "wuauclt.exe" -ArgumentList "/detectnow" -Wait
Start-Process "wuauclt.exe" -ArgumentList "/updatenow" -Wait

# 4. Run Disk Cleanup
Write-Output "Running Disk Cleanup..."
cleanmgr /sagerun:1

# 5. Run Defragmentation
Write-Output "Running Defrag..."
defrag C: /U /V

# 6. Driver check
Write-Output "Checking installed drivers..."
$logPath = "C:\Temp"
if (!(Test-Path $logPath)) { New-Item -ItemType Directory -Path $logPath | Out-Null }
driverquery /V /FO Table > "$logPath\DriverReport.txt"
Write-Output "Driver report saved to $logPath\DriverReport.txt"

# --- Restore screen timeout settings ---
Write-Output "Restoring screen timeout settings..."
powercfg /change monitor-timeout-ac $acTimeout
powercfg /change monitor-timeout-dc $dcTimeout

Write-Output "=== Cleanup Complete ==="