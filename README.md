# 🖥️ School Laptop Cleanup Script

This repository contains a PowerShell script and batch wrapper designed to help maintain shared school laptops. It automates common cleanup and maintenance tasks so devices stay fast, reliable, and ready for students.

---

## ✨ Features

- 🔒 **Profile Cleanup**: Deletes all user profiles except Administrator, Default, and Public.  
- 🧪 **Dry Run Mode**: Preview which profiles would be deleted before running live.  
- 📜 **Group Policy Update**: Forces a `gpupdate /force` to ensure policies are applied.  
- 🔄 **Windows Update Trigger**: Uses built‑in `wuauclt` commands to detect and install updates.  
- 🧹 **Disk Cleanup**: Runs `cleanmgr /sagerun:1` (requires one‑time setup of cleanup options).  
- 💽 **Defragmentation**: Runs `defrag` on the system drive (safe for HDDs, Windows auto‑optimizes SSDs).  
- 🖱️ **Driver Report**: Generates a detailed driver list (`DriverReport.txt`) in `C:\Temp`.  
- 🌙 **Screen Awake**: Temporarily disables screen timeout during execution, then restores settings.  
- 📝 **Logging**: Records actions in `C:\Temp\CleanupLog.txt`.  

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