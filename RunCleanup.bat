@echo off
setlocal
title School Laptop Cleanup
cls
echo ============================================
echo School Laptop Cleanup - GitHub Version
echo ============================================

:: Check for Administrator privileges upfront
net session >nul 2>&1
if %errorlevel% NEQ 0 (
    echo.
    echo ERROR: This script must be run as Administrator.
    echo Please right-click the file and select "Run as administrator".
    pause
    endlocal
    exit /b 1
)

echo Downloading latest cleanup script from GitHub...
:: Use a temporary variable for the download path
set "ScriptPath=%TEMP%\SchoolLaptopCleanup.ps1"

powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
 "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13; ^
  try {
      Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/PinkyCodeMaster/SchoolLaptopCleanup/refs/heads/main/SchoolLaptopCleanup.ps1' ^
        -OutFile '%ScriptPath%' -ErrorAction Stop; ^
      Write-Host 'Download successful.'; ^
      exit 0; ^
  } catch {
      Write-Host 'Download failed, checking for local script...'; ^
      exit 1; ^
  }"

:: Check the ERRORLEVEL set by the PowerShell command (0 for success, 1 for failure)
if %ERRORLEVEL% EQU 0 (
    echo Running downloaded script from %TEMP%...
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ScriptPath%"
) else (
    echo Attempting to run local script...
    if exist "%~dp0SchoolLaptopCleanup.ps1" (
        echo Running local script from same folder...
        powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0SchoolLaptopCleanup.ps1"
    ) else (
        echo.
        echo ERROR: No cleanup script found locally or via download.
        pause
        endlocal
        exit /b 1
    )
)

echo ============================================
echo Cleanup finished.
timeout /t 3 >nul
pause
endlocal
