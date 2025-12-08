@echo off
echo Downloading latest cleanup script from GitHub...

:: Pull the raw file from GitHub (HTTPS is easier for laptops)
powershell -Command "Invoke-WebRequest -Uri https://raw.githubusercontent.com/PinkyCodeMaster/SchoolLaptopCleanup/main/SchoolLaptopCleanup.ps1 -OutFile %TEMP%\SchoolLaptopCleanup.ps1"

echo Running cleanup script...
powershell.exe -ExecutionPolicy Bypass -File "%TEMP%\SchoolLaptopCleanup.ps1"

echo Done.
pause