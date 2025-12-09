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
:: Define the local script path relative to the batch file location
set "LocalScriptPath=%~dp0SchoolLaptopCleanup.ps1"

:: Always clear any existing download so stale copies cannot run
if exist "%ScriptPath%" del "%ScriptPath%" >nul 2>&1

:: Attempt to download the script using the canonical raw URL
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13; try { Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/PinkyCodeMaster/SchoolLaptopCleanup/main/SchoolLaptopCleanup.ps1' -OutFile '%ScriptPath%' -ErrorAction Stop; Write-Host 'Download successful.'; exit 0; } catch { Write-Host 'Download failed, checking for local script...'; exit 1; } "

:: Check the ERRORLEVEL set by the PowerShell command (0 for success, 1 for failure)
if %ERRORlevel% EQU 0 (
    echo Running downloaded script from %TEMP%...
    :: Strip legacy CmdletBinding attribute that caused parser errors in older downloads (handles BOM/whitespace variants)
    powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "try { $raw = Get-Content -Path '%ScriptPath%' -Raw; $sanitized = $raw -replace '(?im)^[\uFEFF\s]*\[CmdletBinding(?:\(\))?\]\s*\r?\n', ''; if ($sanitized -ne $raw) { Set-Content -Path '%ScriptPath%' -Value $sanitized -Encoding UTF8; Write-Host 'Removed legacy CmdletBinding attribute from downloaded script.' } } catch { Write-Host 'Warning: Could not sanitize downloaded script - ' + $_.Exception.Message }"
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ScriptPath%"
) else (
    echo Attempting to run local script...
    if exist "%LocalScriptPath%" (
        echo Running local script from same folder: %LocalScriptPath%
        :: Sanitize local copy as well in case it still has the legacy header
        powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "try { $raw = Get-Content -Path '%LocalScriptPath%' -Raw; $sanitized = $raw -replace '(?im)^[\uFEFF\s]*\[CmdletBinding(?:\(\))?\]\s*\r?\n', ''; if ($sanitized -ne $raw) { Set-Content -Path '%LocalScriptPath%' -Value $sanitized -Encoding UTF8; Write-Host 'Removed legacy CmdletBinding attribute from local script.' } } catch { Write-Host 'Warning: Could not sanitize local script - ' + $_.Exception.Message }"
        powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%LocalScriptPath%"
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
:: Set a final exit code for automation tools to read (0 for general success)
endlocal
exit /b 0
