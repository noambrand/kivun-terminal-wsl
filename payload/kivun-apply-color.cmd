@echo off
REM UTF-8, same reason as kivun-terminal.bat: this script wslpath-converts its
REM own install directory, which breaks if that path has non-ASCII characters
REM and the console is on the OEM codepage.
chcp 65001 >nul 2>&1
setlocal EnableExtensions
REM kivun-apply-color.cmd <color-value>   (v1.6.2)
REM
REM Windows half of the folder picker's "Apply now" for terminal color. Runs the
REM WSL-side regen (kivun-apply-color.sh) as the SAME distro + WSLg user the
REM launcher uses, so the regenerated Konsole files land in the home whose
REM Konsole the user actually sees. A NEW Konsole tab then shows the color
REM without a full Kivun relaunch (the running window keeps its color).
REM
REM Best-effort by design: any failure is non-fatal because the picker has
REM already written TERMINAL_COLOR to config.txt, so the next launch applies the
REM color regardless. A one-line breadcrumb is left in APPLY_COLOR_LOG.txt.

set "COLORVAL=%~1"
set "HERE=%~dp0"
if not exist "%LOCALAPPDATA%\Kivun-WSL" mkdir "%LOCALAPPDATA%\Kivun-WSL" 2>nul
set "APPLYLOG=%LOCALAPPDATA%\Kivun-WSL\APPLY_COLOR_LOG.txt"
> "%APPLYLOG%" echo [kivun-apply-color] value=%COLORVAL%

REM --- real distro (the Microsoft Store often registers "Ubuntu-24.04", not the
REM     bare "Ubuntu"); reuse the launcher's detector, never a hardcoded name ---
set "DISTRO=Ubuntu"
if exist "%HERE%kivun-detect-distro.cmd" (
    for /f "usebackq delims=" %%i in (`call "%HERE%kivun-detect-distro.cmd" 2^>nul`) do set "DISTRO=%%i"
)
if not defined DISTRO set "DISTRO=Ubuntu"
>> "%APPLYLOG%" echo distro=%DISTRO%

REM --- WSLg user = owner of /mnt/wslg/runtime-dir = the user Konsole runs as.
REM     Mirrors kivun-terminal.bat so the ~/.local/share/konsole files match. ---
set "WSLG_USER="
for /f "delims=" %%U in ('wsl -d %DISTRO% --user root -- stat -c "%%U" /mnt/wslg/runtime-dir 2^>nul') do set "WSLG_USER=%%U"
if not defined WSLG_USER for /f "delims=" %%U in ('wsl -d %DISTRO% --user root -- id -un 1000 2^>nul') do set "WSLG_USER=%%U"
set "USERFLAG="
if defined WSLG_USER set "USERFLAG=--user %WSLG_USER%"
>> "%APPLYLOG%" echo user=%WSLG_USER%

REM --- WSL path of the .sh sibling ---
set "SH_WSL="
for /f "delims=" %%i in ('wsl -d %DISTRO% wslpath "%HERE%kivun-apply-color.sh" 2^>nul') do set "SH_WSL=%%i"
if not defined SH_WSL (
    >> "%APPLYLOG%" echo ERROR: could not resolve WSL path of kivun-apply-color.sh
    exit /b 1
)

REM --- CR-strip: a picker-triggered run is NOT covered by the launch-time strip
REM     in kivun-terminal.bat, so normalize line endings before bash reads it ---
wsl -d %DISTRO% -- sed -i "s/\r$//" "%SH_WSL%" 2>nul

REM --- run the regen as the WSLg user ---
wsl -d %DISTRO% %USERFLAG% -- bash "%SH_WSL%" "%COLORVAL%" >> "%APPLYLOG%" 2>&1
set "RC=%errorlevel%"
>> "%APPLYLOG%" echo exit=%RC%
exit /b %RC%
