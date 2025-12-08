# SchoolLaptopCleanup.ps1
# Run as Administrator

Write-Output "=== Starting School Laptop Cleanup ==="

# 1. Delete all user profiles except Administrator, Default, and Public
Get-CimInstance Win32_UserProfile | Where-Object {
    $_.LocalPath -notlike "*Administrator" -and
    $_.LocalPath -notlike "*Default*" -and
    $_.LocalPath -notlike "*Public*"
} | ForEach-Object {
    Write-Output "Deleting profile: $($_.LocalPath)"
    Remove-CimInstance $_
}

# 2. Trigger Windows Update using built-in commands
Write-Output "Starting Windows Update..."
# This uses the Windows Update client directly
Start-Process "wuauclt.exe" -ArgumentList "/detectnow" -Wait
Start-Process "wuauclt.exe" -ArgumentList "/updatenow" -Wait

# 3. Run Disk Cleanup (requires sageset configured once manually)
Write-Output "Running Disk Cleanup..."
cleanmgr /sagerun:1

# 4. Run Defragmentation (skip if SSD)
Write-Output "Running Defrag..."
defrag C: /U /V

Write-Output "=== Cleanup Complete ==="
Pause