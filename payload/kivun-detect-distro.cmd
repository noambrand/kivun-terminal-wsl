@echo off
REM ============================================================
REM  Kivun Terminal - WSL distro picker (v1.5.8)
REM
REM  Prints the name of the Ubuntu distro Kivun should use, with
REM  NO trailing newline, so callers can capture it with:
REM     for /f "delims=" %%i in ('call kivun-detect-distro.cmd') do set "DISTRO=%%i"
REM
REM  Why this exists: the launcher and installer used to assume the
REM  distro was literally named "Ubuntu". But the Microsoft Store often
REM  registers it as "Ubuntu-24.04" (or -22.04). Assuming "Ubuntu" then
REM  (a) made every `wsl -d Ubuntu` call fail against that PC's real
REM  distro, and (b) let the installer register a SECOND, empty "Ubuntu"
REM  - a duplicate. This picker prevents both: it reuses whatever Ubuntu
REM  is already there.
REM
REM  Rule: prefer a distro named exactly "Ubuntu"; otherwise the first
REM  registered distro whose name starts with "Ubuntu"; otherwise fall
REM  back to "Ubuntu" (the name the installer will register when none
REM  exists yet). WSL_UTF8=1 makes `wsl -l -q` emit parseable UTF-8 - its
REM  default on Windows is UTF-16, which cmd's for /f turns into garbage.
REM ============================================================
setlocal enabledelayedexpansion
set "WSL_UTF8=1"
set "EXACT="
set "FIRST="
for /f "usebackq delims=" %%D in (`wsl -l -q 2^>nul`) do (
    set "N=%%D"
    REM Trim surrounding whitespace the list may carry.
    for /f "tokens=* delims= " %%T in ("!N!") do set "N=%%T"
    if /i "!N!"=="Ubuntu" set "EXACT=Ubuntu"
    if not defined FIRST echo(!N!| findstr /i /b /c:"Ubuntu" >nul && set "FIRST=!N!"
)
if defined EXACT (
    set "PICK=Ubuntu"
) else if defined FIRST (
    set "PICK=!FIRST!"
) else (
    set "PICK=Ubuntu"
)
<nul set /p "=!PICK!"
endlocal
