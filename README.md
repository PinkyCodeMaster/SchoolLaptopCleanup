# 🖥️ School Laptop Cleanup Script

This repository contains a PowerShell script and batch wrapper designed to help maintain shared school laptops. It automates common cleanup and maintenance tasks so devices stay fast, reliable, and ready for students.

---

## ✨ Features

- 🔒 **Profile Cleanup**: Deletes all user profiles except Administrator, Default, Public, and system/service accounts (`systemprofile`, `LocalService`, `NetworkService`, `WDAGUtilityAccount`).  
- 🧪 **Dry Run Mode**: Preview all actions before running live.  
- 📜 **Group Policy Update**: Forces a `gpupdate /force` to ensure policies are applied.  
- 🔄 **Windows Update Trigger**: Uses built‑in `wuauclt` commands to detect and install updates.  
- 🧹 **Disk Cleanup**: Runs `cleanmgr /sagerun:1` (requires one‑time setup of cleanup options).  
- 💽 **Defragmentation**: Runs `defrag` on the system drive (safe for HDDs, Windows auto‑optimizes SSDs).  
- 🖱️ **Driver Report**: Generates a detailed driver list (`DriverReport.csv`) in `C:\Temp`.  
- 🌙 **Screen Awake**: Temporarily disables screen timeout during execution, then restores settings.  
- 📝 **Logging**: Records actions in `C:\Temp\CleanupLog.txt` with automatic log rotation (archives if >5MB).  

---

## 📂 Files

- `SchoolLaptopCleanup.ps1` → Main PowerShell script with all cleanup tasks.  
- `RunCleanup.bat` → Batch wrapper that downloads the latest script from GitHub and runs it.  

---

## 🚀 Usage

### Option 1: Run Directly
1. Download or clone this repo.  
2. Open **PowerShell as Administrator**.  
3. Run:
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force
   .\SchoolLaptopCleanup.ps1
   ```

### Option 2: Run via Batch Wrapper

1.  Download or clone this repo.
2.  Double‑click `RunCleanup.bat`.

-   It will attempt to download the latest script from GitHub.
-   If download fails, it falls back to the local copy.

## ⚙️ Dry Run Mode

To preview actions without making changes, run:
```
.\SchoolLaptopCleanup.ps1 -DryRun
```
This will log what _would_ happen without deleting profiles or running cleanup tasks.

## 🧹 Disk Cleanup Setup

Before using the script, configure Disk Cleanup options once manually:
```
cleanmgr /sageset:1
```
Select the cleanup options you want. After this, the script can run them automatically with `cleanmgr /sagerun:1`.

## 📒 Logging

-   Logs are stored in `C:\Temp\CleanupLog.txt`.
-   If the log grows beyond 5MB, it is automatically archived with a timestamp.
-   Driver reports are saved as `DriverReport.csv` in the same folder.

## ⏰ Optional Automation

You can schedule the script to run weekly using Task Scheduler:
```
schtasks /create /tn "SchoolLaptopCleanup" /tr "powershell.exe -ExecutionPolicy Bypass -File C:\Temp\SchoolLaptopCleanup.ps1" /sc weekly /d SUN /ru SYSTEM
```

This registers the cleanup to run every Sunday as SYSTEM.

## 🛡️ Notes

-   Always run as **Administrator**.
-   Safe exclusions prevent deletion of system/service profiles.
-   Works on Windows 10/11 laptops.
-   SSDs are automatically optimized by Windows; defrag step is harmless but mostly useful for HDDs.

## 📜 License

This project is provided under the MIT License. Use at your own risk.