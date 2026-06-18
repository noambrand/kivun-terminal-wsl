@echo off
REM Build KivunTerminal.exe - the native no-console-flash launcher.
REM Used both locally and by CI (.github/workflows/build-windows.yml).
REM Locates Visual Studio via vswhere so Community/Professional/Enterprise/
REM Build Tools all work (PR #83's build script hardcoded Professional).
setlocal
pushd "%~dp0"

set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" (
    echo ERROR: vswhere.exe not found - install Visual Studio 2019+ or Build Tools with the C++ workload.
    popd
    exit /b 1
)
set "VSDIR="
for /f "usebackq delims=" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSDIR=%%i"
if not defined VSDIR (
    echo ERROR: no Visual Studio installation with the C++ build tools found.
    popd
    exit /b 1
)
call "%VSDIR%\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 (
    echo ERROR: vcvars64.bat failed.
    popd
    exit /b 1
)

REM Version comes from the repo-root VERSION file (single source of truth).
set "VMAJ="
set "VMIN="
set "VPAT="
for /f "usebackq tokens=1-3 delims=." %%a in ("..\VERSION") do (
    set "VMAJ=%%a"
    set "VMIN=%%b"
    set "VPAT=%%c"
)
if not defined VPAT (
    echo ERROR: could not parse ..\VERSION ^(expected MAJOR.MINOR.PATCH^).
    popd
    exit /b 1
)

if not exist out mkdir out
rc.exe /nologo /d KIVUN_V_MAJOR=%VMAJ% /d KIVUN_V_MINOR=%VMIN% /d KIVUN_V_PATCH=%VPAT% /fo out\kivun-launcher.res kivun-launcher.rc
if errorlevel 1 (
    echo ERROR: rc.exe failed.
    popd
    exit /b 1
)
REM /MT statically links the CRT: the exe must run on a clean machine with
REM no VC++ Redistributable installed (same rule the .bat lives by).
REM /link /MANIFEST:NO: the linker embeds a default manifest unless told not to.
REM We supply our own (kivun-launcher.manifest, via the .res) declaring
REM asInvoker, so suppress the auto one to avoid a duplicate RT_MANIFEST.
cl.exe /nologo /W4 /WX /O1 /MT /GS /DUNICODE /D_UNICODE /Foout\ /Feout\KivunTerminal.exe kivun-launcher.cpp out\kivun-launcher.res /link /SUBSYSTEM:WINDOWS /MANIFEST:NO user32.lib
if errorlevel 1 (
    echo ERROR: cl.exe failed.
    popd
    exit /b 1
)
if not exist out\KivunTerminal.exe (
    echo ERROR: link produced no exe.
    popd
    exit /b 1
)
echo Built %~dp0out\KivunTerminal.exe (v%VMAJ%.%VMIN%.%VPAT%)
popd
exit /b 0
