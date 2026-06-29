@echo off
REM ============================================================
REM  Kivun Terminal - Diagnostics & Problem Report
REM  Run from the Start Menu ("Kivun Diagnostics") or by double-
REM  clicking. NO admin needed. NOTHING is sent anywhere - it only
REM  creates a text file YOU choose to email. No PowerShell.
REM
REM  v1.5.9 rewrite. Two real bugs this fixes (confirmed on a live
REM  failing PC):
REM   1) The old report died at the "wmic" virtualization section
REM      (wmic was REMOVED from Windows 11 build 26200+), so it never
REM      reached the save/Desktop/Notepad step - the user "ran
REM      diagnostics and got no file". We no longer use wmic at all.
REM   2) The window-problem evidence lives in LAUNCH_LOG.txt and
REM      BASH_LAUNCH_LOG.txt, which the old report never included.
REM  Strategy: write the LOCAL, instant sections (versions + the three
REM  logs) FIRST, then DELIVER the report (copy to the real Desktop +
REM  open in Notepad) BEFORE any WSL probe, so the user always gets it.
REM ============================================================
setlocal enableextensions
set "KDIR=%LOCALAPPDATA%\Kivun-WSL"
if not exist "%KDIR%" mkdir "%KDIR%" 2>nul
set "RPT=%KDIR%\Kivun-Report.txt"
set "WSL=%WINDIR%\System32\wsl.exe"
REM Reuse the same distro the launcher picks (handles "Ubuntu-24.04" etc.).
set "DISTRO=Ubuntu"
if exist "%~dp0kivun-detect-distro.cmd" for /f "delims=" %%i in ('call "%~dp0kivun-detect-distro.cmd" 2^>nul') do set "DISTRO=%%i"
set "CONTACT=noambbb@gmail.com"
set "ISSUES=https://github.com/noambrand/kivun-terminal-wsl/issues"

echo Collecting a Kivun diagnostic report, please wait...

REM ---- LOCAL, INSTANT sections (no WSL, no wmic) ----
> "%RPT%" echo ===== KIVUN TERMINAL - PROBLEM REPORT =====
>>"%RPT%" echo Generated: %DATE% %TIME%
>>"%RPT%" echo Send this file to: %CONTACT%
>>"%RPT%" echo (or attach it at: %ISSUES%)
>>"%RPT%" echo.

set "KVER=unknown"
if exist "%KDIR%\VERSION" set /p KVER=<"%KDIR%\VERSION"
>>"%RPT%" echo ===== [1] Versions =====
>>"%RPT%" echo Kivun Terminal version: %KVER%
ver >>"%RPT%" 2>&1
>>"%RPT%" echo Detected WSL distro: %DISTRO%
>>"%RPT%" echo.

>>"%RPT%" echo ===== [2] Launch log (LAUNCH_LOG.txt) =====
if exist "%KDIR%\LAUNCH_LOG.txt" (
    type "%KDIR%\LAUNCH_LOG.txt" >>"%RPT%" 2>&1
) else (
    >>"%RPT%" echo (no LAUNCH_LOG.txt yet - launch Kivun once, then run this again)
)
>>"%RPT%" echo.

>>"%RPT%" echo ===== [3] Konsole/window log (BASH_LAUNCH_LOG.txt) =====
if exist "%KDIR%\BASH_LAUNCH_LOG.txt" (
    type "%KDIR%\BASH_LAUNCH_LOG.txt" >>"%RPT%" 2>&1
) else (
    >>"%RPT%" echo (no BASH_LAUNCH_LOG.txt yet)
)
>>"%RPT%" echo.

>>"%RPT%" echo ===== [4] Install log (install-log.txt) =====
if exist "%KDIR%\install-log.txt" (
    type "%KDIR%\install-log.txt" >>"%RPT%" 2>&1
) else (
    >>"%RPT%" echo (no install-log.txt found)
)
>>"%RPT%" echo.

REM ---- DELIVER NOW: copy to the real Desktop, open it on screen, AND pop open
REM ---- the folder with the file highlighted — all BEFORE any WSL probe can be
REM ---- slow. So the user always gets a readable report (with the window logs
REM ---- above) and can just DRAG the file into an email or a GitHub issue.
call :COPYDESK
start "" notepad "%RPT%"
REM Open Explorer with the report file selected so it's effortless to grab/send.
if exist "%DESKTOP%\Kivun-Report.txt" (
    start "" explorer.exe /select,"%DESKTOP%\Kivun-Report.txt"
) else (
    start "" explorer.exe /select,"%RPT%"
)

REM ---- BEST-EFFORT extras (may be slow on a broken WSL; the report is already
REM ---- delivered, so a hang here can no longer hide the report from the user) ----
>>"%RPT%" echo ===== [5] WSL status =====
"%WSL%" --status >>"%RPT%" 2>&1
"%WSL%" --version >>"%RPT%" 2>&1
"%WSL%" -l -v >>"%RPT%" 2>&1
>>"%RPT%" echo.
>>"%RPT%" echo ===== [6] Inside WSL (%DISTRO%): claude + node =====
"%WSL%" -d %DISTRO% -- bash -lc "echo ubuntu_reachable; command -v claude || echo claude_missing; command -v node || echo node_missing" >>"%RPT%" 2>&1
>>"%RPT%" echo.
>>"%RPT%" echo ===== end of report =====

REM Refresh the Desktop copy so it has the complete report too.
call :COPYDESK

cls
echo ============================================================
echo   YOUR REPORT IS READY:  Kivun-Report.txt
echo ============================================================
echo.
echo   A folder just opened with the file  Kivun-Report.txt
echo   highlighted (it is on your Desktop). Sending it really
echo   helps us fix the problem - it is the fastest way.
echo.
echo   To send it, just DRAG that highlighted file into:
echo     - an email to:   %CONTACT%
echo     - or a new post at:
echo       %ISSUES%
echo.
echo   Nothing was sent automatically - you are in control.
echo ============================================================
echo.
pause
endlocal
exit /b

:COPYDESK
REM Resolve the REAL Desktop (handles OneDrive Known-Folder redirection, where
REM the Desktop is %USERPROFILE%\OneDrive\Desktop, not %USERPROFILE%\Desktop).
set "DESKTOP="
for /f "tokens=2,*" %%A in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" /v Desktop 2^>nul ^| findstr /i "REG_"') do set "DESKTOP=%%B"
call set "DESKTOP=%DESKTOP%"
if not defined DESKTOP set "DESKTOP=%USERPROFILE%\Desktop"
if not exist "%DESKTOP%" set "DESKTOP=%USERPROFILE%\Desktop"
if not exist "%DESKTOP%" md "%DESKTOP%" 2>nul
copy /y "%RPT%" "%DESKTOP%\Kivun-Report.txt" >nul 2>&1
if /i not "%DESKTOP%"=="%USERPROFILE%\Desktop" copy /y "%RPT%" "%USERPROFILE%\Desktop\Kivun-Report.txt" >nul 2>&1
exit /b
