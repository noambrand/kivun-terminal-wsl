@echo off
REM ============================================================
REM  Kivun Terminal - Diagnostics & Problem Report
REM  Run it from the Start Menu ("Kivun Diagnostics") or by
REM  double-clicking. NO admin needed. NOTHING is sent anywhere
REM  automatically - this only creates a text file that YOU
REM  choose to email or attach. No PowerShell, no downloads.
REM ============================================================
setlocal enableextensions
set "KDIR=%LOCALAPPDATA%\Kivun-WSL"
if not exist "%KDIR%" mkdir "%KDIR%" 2>nul
set "RPT=%KDIR%\Kivun-Report.txt"
set "WSL=%WINDIR%\System32\wsl.exe"
REM Probe the SAME distro the launcher actually uses (Ubuntu), never the user's
REM default distro. On machines where Docker Desktop's "docker-desktop" is the
REM default, a bare "wsl -- bash" runs in a distro that has no bash and reports
REM a false "bash: not found", masking a perfectly healthy Ubuntu install.
set "DISTRO=Ubuntu"
set "CONTACT=noambbb@gmail.com"
set "ISSUES=https://github.com/noambrand/kivun-terminal-wsl/issues"

echo Collecting a Kivun diagnostic report, please wait...

> "%RPT%" echo ===== KIVUN TERMINAL - PROBLEM REPORT =====
>>"%RPT%" echo.
>>"%RPT%" echo HOW TO SEND THIS REPORT (so we can help you):
>>"%RPT%" echo   1) Email this file to:  %CONTACT%
>>"%RPT%" echo      (a copy is on your Desktop, named Kivun-Report.txt)
>>"%RPT%" echo   2) Or open an issue and attach it at:
>>"%RPT%" echo      %ISSUES%
>>"%RPT%" echo.
>>"%RPT%" echo Generated: %DATE% %TIME%
>>"%RPT%" echo.

>>"%RPT%" echo ===== [1] Kivun + Windows version =====
set "KVER=unknown"
if exist "%KDIR%\VERSION" set /p KVER=<"%KDIR%\VERSION"
>>"%RPT%" echo Kivun Terminal version: %KVER%
ver >>"%RPT%" 2>&1

>>"%RPT%" echo.
>>"%RPT%" echo ===== [2] Virtualization (must be ON for WSL2) =====
set "VFW=unknown"
set "HYP=unknown"
wmic path Win32_Processor get VirtualizationFirmwareEnabled /value 2>nul | findstr /i /c:=TRUE >nul && set "VFW=ENABLED"
wmic path Win32_Processor get VirtualizationFirmwareEnabled /value 2>nul | findstr /i /c:=FALSE >nul && set "VFW=DISABLED"
wmic path Win32_ComputerSystem get HypervisorPresent /value 2>nul | findstr /i /c:=TRUE >nul && set "HYP=YES"
wmic path Win32_ComputerSystem get HypervisorPresent /value 2>nul | findstr /i /c:=FALSE >nul && set "HYP=NO"
>>"%RPT%" echo VirtualizationFirmwareEnabled=%VFW%   HypervisorPresent=%HYP%
if /i "%VFW%"=="DISABLED" if /i "%HYP%"=="NO" goto vt_off
>>"%RPT%" echo VERDICT: virtualization looks OK (or a hypervisor is already running).
goto vt_done
:vt_off
>>"%RPT%" echo VERDICT: VIRTUALIZATION IS OFF - WSL2 cannot run until you enable it in BIOS/UEFI.
:vt_done

>>"%RPT%" echo.
>>"%RPT%" echo ===== [3] WSL status =====
"%WSL%" --status >>"%RPT%" 2>&1
>>"%RPT%" echo [status exit=%errorlevel%]
"%WSL%" --version >>"%RPT%" 2>&1
"%WSL%" -l -v >>"%RPT%" 2>&1

>>"%RPT%" echo.
>>"%RPT%" echo ===== [4] Antivirus / security software present =====
tasklist 2>nul | findstr /i "mcafee mfe MsMpEng windefend avp avgnt egui avastsvc" >>"%RPT%" 2>&1

>>"%RPT%" echo.
>>"%RPT%" echo ===== [5] Inside WSL/Ubuntu (claude + node) =====
REM -d %DISTRO% targets Ubuntu explicitly; the [3] "wsl -l -v" above shows which
REM distro is the user's DEFAULT (marked with *). If that is NOT Ubuntu (e.g.
REM docker-desktop), the launcher's bare-wslpath path bug applied pre-v1.4.36.
"%WSL%" -d %DISTRO% -- bash -lc "echo ubuntu_reachable; command -v claude || echo claude_missing; command -v node || echo node_missing" >>"%RPT%" 2>&1
>>"%RPT%" echo [ubuntu probe exit=%errorlevel% via -d %DISTRO%]

>>"%RPT%" echo.
>>"%RPT%" echo ===== [6] Kivun install log =====
if exist "%KDIR%\install-log.txt" goto have_log
>>"%RPT%" echo (no install-log.txt found yet)
goto log_done
:have_log
type "%KDIR%\install-log.txt" >>"%RPT%" 2>&1
:log_done

>>"%RPT%" echo.
>>"%RPT%" echo ===== end of report =====

REM Put a copy on the Desktop so it is easy to find and attach.
REM v1.5.8: resolve the REAL Desktop. On most PCs the Desktop is redirected to
REM OneDrive (%USERPROFILE%\OneDrive\Desktop), so copying to the literal
REM %USERPROFILE%\Desktop dropped the file somewhere the user never sees it
REM ("Diagnostics put nothing on my Desktop"). The authoritative location is the
REM "Desktop" value under User Shell Folders; expand it (it may use %USERPROFILE%
REM or %OneDrive%), fall back to the classic path, and copy to BOTH to be safe.
set "DESKTOP="
for /f "tokens=2,*" %%A in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" /v Desktop 2^>nul ^| findstr /i "REG_"') do set "DESKTOP=%%B"
call set "DESKTOP=%DESKTOP%"
if not defined DESKTOP set "DESKTOP=%USERPROFILE%\Desktop"
if not exist "%DESKTOP%" set "DESKTOP=%USERPROFILE%\Desktop"
if not exist "%DESKTOP%" md "%DESKTOP%" 2>nul
copy /y "%RPT%" "%DESKTOP%\Kivun-Report.txt" >nul 2>&1
if /i not "%DESKTOP%"=="%USERPROFILE%\Desktop" copy /y "%RPT%" "%USERPROFILE%\Desktop\Kivun-Report.txt" >nul 2>&1

cls
echo ============================================================
echo   KIVUN DIAGNOSTIC REPORT CREATED
echo ============================================================
echo.
echo   Saved to your Desktop:  Kivun-Report.txt
echo   Full path:  %DESKTOP%\Kivun-Report.txt
echo   (also at: %RPT%)
echo.
echo   PLEASE SEND IT so we can help:
echo     - Email it to:      %CONTACT%
echo     - or attach it at:  %ISSUES%
echo.
echo   It is opening in Notepad now. Nothing was sent
echo   automatically - you choose what to do with the file.
echo ============================================================
echo.
start "" notepad "%RPT%"
pause
endlocal
