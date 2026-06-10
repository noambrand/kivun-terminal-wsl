@echo off
REM ============================================================
REM  Kivun WSL - Offline / antivirus-safe installer
REM  Installs WSL2 + Ubuntu using ONLY native, Microsoft-signed
REM  tooling - dism, msiexec, and `wsl --install --from-file`.
REM  No PowerShell, no Microsoft Store, no download tricks, so
REM  antivirus (incl. McAfee Web Protection) does not flag or
REM  block it - the one method proven to work on a locked-down PC.
REM
REM  Put these two OFFICIAL files in the SAME folder as this script:
REM    * wsl.<version>.x64.msi              (Microsoft WSL runtime)
REM        https://github.com/microsoft/WSL/releases
REM    * ubuntu-24.04.<n>-wsl-amd64.wsl     (Canonical Ubuntu image)
REM        https://releases.ubuntu.com/noble/
REM  Download them on any working PC, copy this whole folder over
REM  (USB is fine), then RIGHT-CLICK this file > Run as administrator.
REM ============================================================
setlocal enableextensions
set "HERE=%~dp0"
cd /d "%HERE%" 2>nul
set "WSL=%WINDIR%\System32\wsl.exe"
set "KDIR=%LOCALAPPDATA%\Kivun-WSL"
if not exist "%KDIR%" mkdir "%KDIR%" 2>nul
set "LOG=%KDIR%\offline-install-log.txt"
echo ===== Kivun WSL offline install  %DATE% %TIME% =====> "%LOG%"

REM --- locate the two official files by pattern (version-agnostic) ---
set "MSI="
set "DISTRO="
for %%F in ("%HERE%wsl.*.x64.msi") do if exist "%%~fF" set "MSI=%%~fF"
for %%F in ("%HERE%ubuntu-*-wsl-amd64.wsl") do if exist "%%~fF" set "DISTRO=%%~fF"

REM --- must be Administrator (dism + msiexec need it) ---
net session >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Please right-click this file and choose "Run as administrator".
  echo not admin>> "%LOG%"
  pause & exit /b 1
)

REM --- the two files must be present (this script never downloads) ---
if not defined MSI (
  echo [ERROR] WSL runtime MSI not found next to this script.
  echo         Download wsl.^<version^>.x64.msi from:
  echo            https://github.com/microsoft/WSL/releases
  echo         put it in this folder, and run again.
  echo missing MSI>> "%LOG%"
  pause & exit /b 1
)
if not defined DISTRO (
  echo [ERROR] Ubuntu image not found next to this script.
  echo         Download ubuntu-24.04.^<n^>-wsl-amd64.wsl from:
  echo            https://releases.ubuntu.com/noble/
  echo         put it in this folder, and run again.
  echo missing distro>> "%LOG%"
  pause & exit /b 1
)
echo Using MSI:    "%MSI%">> "%LOG%"
echo Using distro: "%DISTRO%">> "%LOG%"

REM --- [0/4] virtualization must be ON in firmware (WSL2 can't boot without it) ---
echo [0/4] Checking hardware virtualization (BIOS/UEFI)...
set "VFW=unknown" & set "HYP=unknown"
wmic path Win32_Processor get VirtualizationFirmwareEnabled /value 2>nul | findstr /i /c:=TRUE >nul && set "VFW=ENABLED"
wmic path Win32_Processor get VirtualizationFirmwareEnabled /value 2>nul | findstr /i /c:=FALSE >nul && set "VFW=DISABLED"
wmic path Win32_ComputerSystem get HypervisorPresent /value 2>nul | findstr /i /c:=TRUE >nul && set "HYP=YES"
echo virtualization VFW=%VFW% HYP=%HYP%>> "%LOG%"
if /i "%VFW%"=="DISABLED" if /i not "%HYP%"=="YES" goto vt_off
echo       virtualization OK (or a hypervisor is already running).
goto vt_ok
:vt_off
echo.
echo [ACTION NEEDED] Hardware virtualization is OFF in this PC's BIOS/UEFI.
echo WSL2 runs Linux in a virtual machine that cannot start until you enable it.
echo No software can change this - only you, in BIOS setup (one-time, ~2 min):
echo   1. Restart the PC and press the setup key as it powers on:
echo        Dell / ASUS / Acer:  F2       Lenovo:  F1, F2, or the Novo button
echo        HP:  Esc then F10             Other / desktops:  Del (or F2)
echo   2. Enable "Intel Virtual Technology" / "VT-x" / "SVM Mode".
echo   3. Save and exit (usually F10), let Windows start, then run this again.
echo aborted: virtualization off>> "%LOG%"
pause & exit /b 1
:vt_ok

REM --- [1/4] enable the WSL features locally (no download). Idempotent. ---
echo [1/4] Enabling WSL features (DISM, local - no download)...
dism /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart >> "%LOG%" 2>&1
dism /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart >> "%LOG%" 2>&1

REM --- [2/4] install the WSL runtime from the Microsoft-signed MSI ---
echo [2/4] Installing the WSL runtime (Microsoft-signed MSI)...
msiexec /i "%MSI%" /qn /norestart /l*v "%KDIR%\wsl-msi.log"
set "RC=%errorlevel%"
echo msiexec rc=%RC%>> "%LOG%"
if not "%RC%"=="0" if not "%RC%"=="3010" (
  echo [ERROR] WSL runtime install failed (code %RC%). See "%KDIR%\wsl-msi.log"
  pause & exit /b 1
)

REM --- [3/4] is WSL active? if not, a reboot is needed before importing Ubuntu ---
echo [3/4] Checking WSL is active...
"%WSL%" --status >> "%LOG%" 2>&1
if errorlevel 1 (
  echo.
  echo [ACTION] WSL needs a REBOOT to finish activating.
  echo          Restart the PC, then run this script again (Run as administrator).
  echo          It resumes where it left off and imports Ubuntu.
  echo reboot required before import>> "%LOG%"
  pause & exit /b 0
)

REM --- already have an Ubuntu distro? skip the import ---
"%WSL%" -l -q 2>nul | findstr /i "Ubuntu" >nul && ( echo [SKIP] Ubuntu is already installed. & goto verify )

REM --- [4/4] import Ubuntu from the official .wsl image (offline) ---
echo [4/4] Installing Ubuntu from the official image (offline)...
"%WSL%" --set-default-version 2 >> "%LOG%" 2>&1
"%WSL%" --install --from-file "%DISTRO%" >> "%LOG%" 2>&1
set "RC=%errorlevel%"
echo from-file rc=%RC%>> "%LOG%"
if not "%RC%"=="0" (
  echo [ERROR] Ubuntu install failed (code %RC%). See "%LOG%"
  pause & exit /b 1
)

:verify
echo.
echo ===== VERIFY =====
"%WSL%" -l -v
echo.
echo [DONE] WSL + Ubuntu are installed with no downloads and no Store.
echo Next: run Kivun_Terminal_Setup.exe to finish setting up Claude.
echo Log: "%LOG%"
pause
endlocal
