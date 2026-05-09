@echo off
call "C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat" >nul
cd /d "%~dp0"
cl /nologo /EHsc /O2 /W3 kivun-launcher.cpp /Fe:KivunTerminal.exe /link /SUBSYSTEM:WINDOWS user32.lib
