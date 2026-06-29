@echo off
REM ============================================================
REM  Kivun Terminal - Repair Display (one click, NO typing)
REM
REM  Use this if Kivun's blue window doesn't appear (it only shows
REM  in the taskbar, or nothing shows). WSLg - the part of Windows
REM  that draws Linux windows - sometimes gets "stuck" and stops
REM  drawing ANY Linux window. The cure is to restart it once.
REM
REM  The installer already does this for you at the end of setup.
REM  This shortcut is here only for the rare case it happens again
REM  later, so you never have to type a command.
REM ============================================================
title Repair Kivun Display
echo ============================================================
echo   REPAIR KIVUN DISPLAY
echo ============================================================
echo.
echo   This restarts the part of Windows that draws Linux windows,
echo   so Kivun's window will appear again.
echo.
echo   NOTE: this briefly closes ALL running WSL/Linux sessions. If
echo   you have other Linux/WSL work open, save it first.
echo.
REM Resolve the real 64-bit wsl.exe (Sysnative from a 32-bit shell; System32 otherwise).
set "WSL=%WINDIR%\System32\wsl.exe"
if exist "%WINDIR%\Sysnative\wsl.exe" set "WSL=%WINDIR%\Sysnative\wsl.exe"

echo   Working...
"%WSL%" --shutdown
echo.
echo ============================================================
echo   DONE. Now open Kivun Terminal again (its desktop shortcut).
echo   The first launch can take about 10-15 seconds to appear.
echo ============================================================
echo.
pause
