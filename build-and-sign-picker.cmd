@echo off
setlocal enabledelayedexpansion
title Build ^& Sign the Kivun Picker (replaces mshta)

REM ============================================================
REM  Builds the NEW signed folder-picker program (KivunPicker.exe)
REM  that replaces the old mshta.exe + folder-picker.hta combo Windows
REM  Defender kept false-flagging. It:
REM    1. compiles the .NET WebView2 host,
REM    2. rebuilds folder-picker.html from the canonical folder-picker.hta,
REM    3. signs KivunPicker.exe with your Certum cloud certificate,
REM    4. stages the signed exe + its support files into payload\ so the
REM       installer (installer\Kivun_Terminal_Setup.nsi) packs them.
REM
REM  BEFORE double-clicking: open SimplySign Desktop and log in (enter the
REM  6-digit code from your phone) - same as sign-and-release.cmd.
REM ============================================================

cd /d "%~dp0"
set "APP=picker-app"
set "OUT=%APP%\bin\Release"
set "PAYLOAD=payload"

echo(
echo ============================================================
echo   Build ^& sign the Kivun Picker
echo ============================================================
echo(

echo [1/5] Compiling KivunPicker.exe ...
where dotnet >nul 2>nul || (echo ERROR: dotnet SDK not found. Install the .NET SDK. & goto :fail)
dotnet build "%APP%\KivunPicker.csproj" -c Release -v m
if errorlevel 1 (echo BUILD FAILED. & goto :fail)
if not exist "%OUT%\KivunPicker.exe" (echo ERROR: KivunPicker.exe was not produced. & goto :fail)

echo [2/5] Rebuilding folder-picker.html from folder-picker.hta ...
where node >nul 2>nul || (echo ERROR: node not found. & goto :fail)
node "%APP%\build-picker.js" "%PAYLOAD%\folder-picker.hta" "%PAYLOAD%\folder-picker.html"
if errorlevel 1 (echo HTML TRANSFORM FAILED. & goto :fail)

echo [3/5] Locating signtool ...
set "SIGNTOOL="
for /f "delims=" %%s in ('dir /b /s "C:\Program Files (x86)\Windows Kits\10\bin\signtool.exe" 2^>nul ^| findstr /i /c:"\x64\signtool"') do set "SIGNTOOL=%%s"
if not defined SIGNTOOL for /f "delims=" %%s in ('dir /b /s "C:\Program Files (x86)\Windows Kits\10\bin\signtool.exe" 2^>nul') do set "SIGNTOOL=%%s"
if not defined SIGNTOOL (echo ERROR: signtool.exe not found ^(Windows SDK missing^). & goto :fail)
echo       Using: !SIGNTOOL!

echo [4/5] Signing KivunPicker.exe ^(approve on your phone if asked^) ...
"!SIGNTOOL!" sign /n "Noam Brand" /fd sha256 /tr "http://time.certum.pl" /td sha256 /v "%OUT%\KivunPicker.exe"
if errorlevel 1 (
  echo(
  echo SIGNING FAILED. Most common cause: SimplySign Desktop is not logged in.
  echo Open it, enter the 6-digit code from your phone, then run this file again.
  goto :fail
)
"!SIGNTOOL!" verify /pa /v "%OUT%\KivunPicker.exe"
if errorlevel 1 (echo VERIFY FAILED. & goto :fail)

echo [5/5] Staging signed picker + support files into payload\ ...
copy /y "%OUT%\KivunPicker.exe"                          "%PAYLOAD%\KivunPicker.exe" >nul || goto :fail
copy /y "%OUT%\Microsoft.Web.WebView2.Core.dll"          "%PAYLOAD%\Microsoft.Web.WebView2.Core.dll" >nul || goto :fail
copy /y "%OUT%\Microsoft.Web.WebView2.WinForms.dll"      "%PAYLOAD%\Microsoft.Web.WebView2.WinForms.dll" >nul || goto :fail
copy /y "%OUT%\WebView2Loader.dll"                        "%PAYLOAD%\WebView2Loader.dll" >nul || goto :fail
copy /y "%APP%\webview-shim.js"                           "%PAYLOAD%\webview-shim.js" >nul || goto :fail

echo(
echo ============================================================
echo   DONE. Signed picker + support files are staged in payload\.
echo   Next: commit, bump VERSION, and publish per docs\CHANGELOG.
echo ============================================================
echo(
pause
exit /b 0

:fail
echo(
echo *** Stopped. See messages above. Nothing was published. ***
echo(
pause
exit /b 1
