# 🖥️ School Laptop Cleanup Script

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)
![Windows](https://img.shields.io/badge/Windows-10%2F11-green)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow)

This repository contains PowerShell scripts and a batch wrapper designed to help maintain shared school laptops. It automates common cleanup and maintenance tasks so devices stay fast, reliable, and ready for students. The main script now supports both **automatic** and **interactive** flows from a single entry point.

---

## ✨ Features

- 🔒 **Profile Cleanup**: Deletes all user profiles except Administrator, Default, Public, and system/service accounts (`systemprofile`, `LocalService`, `NetworkService`, `WDAGUtilityAccount`).  
- 🧪 **Dry Run Mode**: Preview all actions before running live (automated edition).  
- 📜 **Group Policy Update**: Forces a `gpupdate /force` to ensure policies are applied.  
- 🔄 **Windows Update Trigger**: Uses `UsoClient` with fallback to legacy `wuauclt` commands.  
- 🧹 **Disk Cleanup**: Runs `cleanmgr /sagerun:1` (requires one‑time setup of cleanup options).  
- 💽 **Defragmentation**: Runs `defrag` on the system drive with configurable passes; skips SSD automatically.  
- 🖱️ **Driver Report**: Generates a detailed driver list (`DriverReport.csv`) in `C:\Temp`.  
- 🌙 **Screen Awake**: Temporarily disables screen timeout during execution, then restores settings.  
- 📝 **Logging**: Records actions in `C:\Temp\CleanupLog.txt` with automatic log rotation (archives if >5MB).  
- 🔁 **Self‑Launcher**: `.ps1` scripts relaunch themselves in PowerShell if double‑clicked, so they never open in cmd by mistake.  

---

## 📂 Files

- `SchoolLaptopCleanup.ps1` → **Unified edition** (automatic by default; use `-Mode Manual` for interactive prompts). Supports centralized logging via `-ServerPath` and validated defrag passes with `-DefragPasses`.
- `RunCleanup.bat` → Batch wrapper that downloads the latest script from GitHub and runs it safely in PowerShell.

---

## 🚀 Usage

### Option 1: Run Automated Edition
1. Download or clone this repo.
2. Open **PowerShell as Administrator**.
3. Run:
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force
   .\SchoolLaptopCleanup.ps1
   ```

### Option 2: Run Interactive Edition
1. Download or clone this repo.
2. Open **PowerShell as Administrator**.
3. Run:
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force
   .\SchoolLaptopCleanup.ps1 -Mode Manual
   ```

   You will be prompted step‑by‑step (Y/N) for each task, and asked how many defrag passes to run (1–6).

### Option 3: Run via Batch Wrapper
1. Download or clone this repo.
2. Double‑click `RunCleanup.bat`.
   - It will attempt to download the latest script from GitHub.
   - If an older download is found, the wrapper strips the legacy `[CmdletBinding()]` line before execution to prevent parser errors.
   - If download fails, it falls back to the local copy.

---

## 💽 Defrag Passes (Automated Edition)

By default, the automated script runs **3 passes** of defrag. You can override this with the `-DefragPasses` parameter (validated 1–6):

- Run with 3 passes (default):
.\SchoolLaptopCleanup.ps1

- Run with 5 passes:  
.\SchoolLaptopCleanup.ps1 -DefragPasses 5  

The interactive edition will ask you how many passes you want (1–6). Invalid input is skipped safely.

---

## 📒 Logging

- Logs are stored in `C:\Temp\CleanupLog.txt` by default.
- Specify a central UNC path (e.g., `-ServerPath \\pat-fs1\c$`) to log to a network share (logs go in `LaptopLogs\<HOSTNAME>`).
- If the log grows beyond 5MB, it is automatically archived with a timestamp.
- Driver reports are saved as `DriverReport.csv` alongside the selected log path.

---

## 🧹 Disk Cleanup Setup

Before using the script, configure Disk Cleanup options once manually:  
cleanmgr /sageset:1  

Select the cleanup options you want. After this, the script can run them automatically with `cleanmgr /sagerun:1`.

---

## ⏰ Optional Automation

You can schedule the **automated edition** to run weekly using Task Scheduler:  
schtasks /create /tn "SchoolLaptopCleanup" /tr "powershell.exe -ExecutionPolicy Bypass -File C:\Temp\SchoolLaptopCleanup.ps1" /sc weekly /d SUN /ru SYSTEM  

This registers the cleanup to run every Sunday as SYSTEM.

---

## 🛠️ Troubleshooting

- **“Please run this script as Administrator”**  
  → Right‑click PowerShell and choose *Run as Administrator*.  

- **Disk Cleanup doesn’t run**  
  → Make sure you’ve configured cleanup options first with:  
    cleanmgr /sageset:1  

- **Defrag runs too many passes (e.g. 11)**  
  → Use `-DefragPasses N` (automated edition) or enter a number (interactive edition) to control passes.  

- **Batch wrapper fails to download script**  
  → Check internet connection. If offline, the wrapper will fall back to the local copy.  

- **Log file errors**  
  → Ensure `C:\Temp` exists and is writable. The script will auto‑create the folder if missing.  

- **Windows Update step doesn’t seem to install updates**  
  → The script triggers detection and update, but installation may require a reboot or further Windows Update cycles.  

---

## 🛡️ Notes

- Always run as **Administrator**.  
- Safe exclusions prevent deletion of system/service profiles.  
- Works on Windows 10/11 laptops.  
- SSDs are automatically optimized by Windows; defrag step is skipped for SSDs.  
- Choose **Automated edition** for consistency, or **Interactive edition** for flexibility.  
- Double‑clicking `.ps1` files is safe — they relaunch themselves in PowerShell automatically.  

---

## 📜 License

This project is provided under the MIT License. Use at your own risk.