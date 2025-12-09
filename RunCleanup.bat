@echo off
echo ============================================
echo School Laptop Cleanup - GitHub Version
echo ============================================

:: Force TLS 1.2 and download latest script from GitHub
echo Downloading latest cleanup script from GitHub...
powershell -NoLogo -NoProfile -Command ^
  "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; ^
   try { Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/PinkyCodeMaster/SchoolLaptopCleanup/refs/heads/main/SchoolLaptopCleanup.ps1' -OutFile $env:TEMP\SchoolLaptopCleanup.ps1 -ErrorAction Stop; exit 0 } ^
   catch { Write-Output 'Download failed, using local script if available...'; exit 1 }"

:: Check if download succeeded
if exist "%TEMP%\SchoolLaptopCleanup.ps1" (
    echo Running downloaded script...
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\SchoolLaptopCleanup.ps1"
) else if exist "%~dp0SchoolLaptopCleanup.ps1" (
    echo Running local script from same folder...
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0SchoolLaptopCleanup.ps1"
) else (
    echo ERROR: No cleanup script found.
    pause
    exit /b 1
)

echo ============================================
echo Cleanup finished.
timeout /t 2 >nul
pause