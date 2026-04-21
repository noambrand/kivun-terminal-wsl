@echo off
REM ========================================
REM   Kivun Terminal v1.0.6 - WSL Launcher
REM   WSL + Ubuntu + Konsole with full RTL/BiDi
REM ========================================

REM Read product version (single source of truth)
set "PRODUCT_VERSION=1.0.6"
if exist "%~dp0VERSION" (
    for /f "usebackq delims=" %%V in ("%~dp0VERSION") do set "PRODUCT_VERSION=%%V"
)

title Kivun Terminal v%PRODUCT_VERSION% - Launch Log: %LOCALAPPDATA%\Kivun-WSL\LAUNCH_LOG.txt

REM Initialize log file
set "LOG_FILE=%LOCALAPPDATA%\Kivun-WSL\LAUNCH_LOG.txt"
if not exist "%LOCALAPPDATA%\Kivun-WSL" mkdir "%LOCALAPPDATA%\Kivun-WSL"

REM Start new log entry
echo ======================================== >> "%LOG_FILE%"
echo KIVUN TERMINAL v%PRODUCT_VERSION% LAUNCH LOG >> "%LOG_FILE%"
echo ======================================== >> "%LOG_FILE%"
echo Date: %DATE% %TIME% >> "%LOG_FILE%"
echo User: %USERNAME% >> "%LOG_FILE%"
echo Computer: %COMPUTERNAME% >> "%LOG_FILE%"
echo Working Directory: %CD% >> "%LOG_FILE%"
echo Script Location: %~dp0 >> "%LOG_FILE%"
echo ======================================== >> "%LOG_FILE%"
echo WSL VERSION: >> "%LOG_FILE%"
wsl --version >> "%LOG_FILE%" 2>&1
echo ---------------------------------------- >> "%LOG_FILE%"
echo WSL STATUS: >> "%LOG_FILE%"
wsl --status >> "%LOG_FILE%" 2>&1
echo ---------------------------------------- >> "%LOG_FILE%"
echo WSL DISTRIBUTIONS: >> "%LOG_FILE%"
wsl -l -v >> "%LOG_FILE%" 2>&1
echo ======================================== >> "%LOG_FILE%"
echo. >> "%LOG_FILE%"

echo ========================================
echo   KIVUN TERMINAL v%PRODUCT_VERSION% - STARTING...
echo   LOG FILE: %LOG_FILE%
echo ========================================
echo.

call :LOG "START - Launching Kivun Terminal v%PRODUCT_VERSION% (WSL Launcher)"

REM Get working directory
if "%~1"=="" (
    set "WORK_DIR=%USERPROFILE%"
    call :LOG "INFO - Using default work directory: %USERPROFILE%"
) else (
    set "WORK_DIR=%~1"
    call :LOG "INFO - Using specified work directory: %~1"
)
echo Work directory: %WORK_DIR%

REM Read language preference
call :LOG "INFO - Reading config.txt"
set RESPONSE_LANGUAGE=english
set PRIMARY_LANGUAGE=hebrew
set USE_VCXSRV=false
set TEXT_DIRECTION=rtl
set FOLDER_PICKER=false
if exist "%~dp0config.txt" (
    REM SECURITY: quote the SET target. Unquoted `set X=%%b` lets CMD
    REM parse the value — a config line `RESPONSE_LANGUAGE=english& calc.exe`
    REM would execute `calc.exe` during config load. The quoted form
    REM `set "X=%%b"` treats the contents as literal (& | ^ < > are
    REM all safe inside the quotes).
    for /f "tokens=1,2 delims==" %%a in ('type "%~dp0config.txt" 2^>nul ^| findstr /v "^#"') do (
        if "%%a"=="RESPONSE_LANGUAGE" set "RESPONSE_LANGUAGE=%%b"
        if "%%a"=="PRIMARY_LANGUAGE" set "PRIMARY_LANGUAGE=%%b"
        if "%%a"=="USE_VCXSRV"       set "USE_VCXSRV=%%b"
        if "%%a"=="TEXT_DIRECTION"   set "TEXT_DIRECTION=%%b"
        if "%%a"=="FOLDER_PICKER"    set "FOLDER_PICKER=%%b"
    )
    call :LOG "SUCCESS - Config loaded: language=%RESPONSE_LANGUAGE%, keyboard=%PRIMARY_LANGUAGE%, vcxsrv=%USE_VCXSRV%, textdir=%TEXT_DIRECTION%, folderpicker=%FOLDER_PICKER%"
) else (
    call :LOG "WARNING - config.txt not found, using defaults"
)
echo Language: %RESPONSE_LANGUAGE%
echo Keyboard: %PRIMARY_LANGUAGE%
echo VcXsrv: %USE_VCXSRV%

REM If FOLDER_PICKER=true AND no folder was passed as arg (i.e. launched
REM from the desktop shortcut, not from a right-click context menu), pop
REM a native Windows folder-browse dialog.
if /i "%FOLDER_PICKER:~0,4%"=="true" if "%~1"=="" (
    call :LOG "INFO - FOLDER_PICKER enabled, launching native dialog"
    if exist "%~dp0folder-picker.wsf" (
        cscript //Nologo "%~dp0folder-picker.wsf" >nul 2>&1
        if exist "%LOCALAPPDATA%\Kivun-WSL\kivun-workdir.txt" (
            set /p PICKED=<"%LOCALAPPDATA%\Kivun-WSL\kivun-workdir.txt"
            del "%LOCALAPPDATA%\Kivun-WSL\kivun-workdir.txt" >nul 2>&1
            if defined PICKED (
                set "WORK_DIR=%PICKED%"
                call :LOG "SUCCESS - User picked folder: %PICKED%"
                echo Work directory updated: %PICKED%
            ) else (
                call :LOG "INFO - User cancelled folder picker, using default: %WORK_DIR%"
            )
        ) else (
            call :LOG "INFO - User cancelled folder picker, using default: %WORK_DIR%"
        )
    ) else (
        call :LOG "WARNING - folder-picker.wsf not found in install dir, skipping picker"
    )
)

REM Set language-specific prompt. 23-entry lookup table. Default English.
REM We strip a trailing CR (from CRLF config files) by slicing the variable
REM to a fixed length per language key before comparing.
call :LOG "INFO - Setting language-specific prompt for %RESPONSE_LANGUAGE%"
set "CLAUDE_PROMPT=Always respond in English, even if the user writes in another language."
call :SET_LANG_PROMPT "%RESPONSE_LANGUAGE%"
call :LOG "SUCCESS - Prompt configured"

REM Check WSL
echo.
echo Checking WSL...
call :LOG "INFO - Checking WSL installation"
wsl --version 2>&1 >> "%LOG_FILE%"
if %ERRORLEVEL% NEQ 0 (
    call :LOG "ERROR - WSL not found or not working (error %ERRORLEVEL%)"
    echo ERROR: WSL not found or not working.
    echo Run the Kivun Terminal installer to fix this.
    echo.
    echo Log file: %LOG_FILE%
    pause
    exit /b 1
)
call :LOG "SUCCESS - WSL is installed and working"
echo   WSL: OK

call :LOG "INFO - Checking Ubuntu distribution"
wsl -d Ubuntu echo OK 2>&1 >> "%LOG_FILE%"
if %ERRORLEVEL% NEQ 0 (
    call :LOG "WARNING - Ubuntu not responding, attempting WSL restart"
    echo Ubuntu not responding, restarting WSL...
    wsl --shutdown
    call :LOG "INFO - WSL shutdown command issued, waiting 3 seconds"
    timeout /t 3 /nobreak >nul
    wsl -d Ubuntu echo OK 2>&1 >> "%LOG_FILE%"
    if %ERRORLEVEL% NEQ 0 (
        call :LOG "ERROR - Ubuntu not available after restart (error %ERRORLEVEL%)"
        echo ERROR: Ubuntu not available.
        echo Run the Kivun Terminal installer to fix this.
        echo.
        echo Log file: %LOG_FILE%
        pause
        exit /b 1
    )
    call :LOG "SUCCESS - Ubuntu is now responding after restart"
) else (
    call :LOG "SUCCESS - Ubuntu is running"
)
echo   Ubuntu: OK

REM Check if Konsole is installed
call :LOG "INFO - Checking if Konsole is installed"
wsl -d Ubuntu -- bash -c "command -v konsole" 2>&1 >> "%LOG_FILE%"
if %ERRORLEVEL% NEQ 0 (
    call :LOG "WARNING - Konsole not found, attempting installation"
    echo   Konsole: NOT FOUND - installing...
    wsl -d Ubuntu -- sudo apt-get install -y konsole 2>&1 >> "%LOG_FILE%"
    wsl -d Ubuntu -- bash -c "command -v konsole" 2>&1 >> "%LOG_FILE%"
    if %ERRORLEVEL% NEQ 0 (
        call :LOG "ERROR - Konsole installation failed"
        echo   Konsole install failed - will run Claude directly.
        goto :run_direct
    )
    call :LOG "SUCCESS - Konsole installed successfully"
) else (
    call :LOG "SUCCESS - Konsole is installed"
)
echo   Konsole: OK

REM Check if Claude Code is installed
call :LOG "INFO - Checking if Claude Code is installed"
wsl -d Ubuntu -- bash -c "command -v claude" 2>&1 >> "%LOG_FILE%"
if %ERRORLEVEL% NEQ 0 (
    call :LOG "ERROR - Claude Code not found in Ubuntu"
    echo   Claude Code: NOT FOUND
    echo   Please install Claude Code: sudo npm install -g @anthropic-ai/claude-code
    goto :run_direct
)
call :LOG "SUCCESS - Claude Code is installed"
echo   Claude: OK

REM Convert paths
call :LOG "INFO - Converting Windows paths to WSL paths"
for /f "delims=" %%i in ('wsl wslpath "%WORK_DIR%" 2^>nul') do set "WSL_PATH=%%i"
if "%WSL_PATH%"=="" (
    set "WSL_PATH=~"
    call :LOG "WARNING - Path conversion failed, using home directory"
) else (
    call :LOG "SUCCESS - WSL work path: %WSL_PATH%"
)
call :LOG "INFO - Converting installation directory: %~dp0"
REM %~dp0 ends with a backslash which confuses wslpath. Strip it.
set "INST_DIR=%~dp0"
if "%INST_DIR:~-1%"=="\" set "INST_DIR=%INST_DIR:~0,-1%"
for /f "delims=" %%i in ('wsl wslpath -a "%INST_DIR%" 2^>nul') do set "INST_WSL=%%i"
if "%INST_WSL%"=="" (
    call :LOG "WARNING - wslpath failed, using manual conversion for: %INST_DIR%"
    call :WIN_TO_WSL_PATH "%INST_DIR%" INST_WSL
    call :LOG "INFO - Manual conversion result: %INST_WSL%"
)
REM Ensure trailing slash for concatenation with script name
if not "%INST_WSL:~-1%"=="/" set "INST_WSL=%INST_WSL%/"
call :LOG "SUCCESS - Installation WSL path: %INST_WSL%"
echo.
echo Path: %WSL_PATH%

REM Fix line endings in launch script (Windows creates CRLF, bash needs LF)
call :LOG "INFO - Fixing line endings in kivun-launch.sh"
wsl -d Ubuntu -- sed -i "s/\r$//" "%INST_WSL%kivun-launch.sh" 2>&1 >> "%LOG_FILE%"
if %ERRORLEVEL% EQU 0 (
    call :LOG "SUCCESS - Line endings fixed"
) else (
    call :LOG "WARNING - Failed to fix line endings (error %ERRORLEVEL%)"
)

REM Start VcXsrv if enabled and not running
if /i "%USE_VCXSRV%"=="true" (
    echo.
    echo VcXsrv mode enabled - checking X server...
    call :LOG "INFO - VcXsrv mode enabled, checking if running"
    tasklist /FI "IMAGENAME eq vcxsrv.exe" 2>nul | find /I "vcxsrv.exe" >nul
    if %ERRORLEVEL% NEQ 0 (
        call :LOG "INFO - VcXsrv not running, attempting to start"
        if exist "C:\Program Files\VcXsrv\xlaunch.exe" (
            echo   Starting VcXsrv X server...
            start "" "C:\Program Files\VcXsrv\xlaunch.exe" -run "%~dp0kivun.xlaunch"
            timeout /t 2 /nobreak >nul
            call :LOG "SUCCESS - VcXsrv started"
        ) else (
            call :LOG "WARNING - VcXsrv not installed at expected path, falling back to WSLg"
            echo   WARNING: VcXsrv not installed at expected path.
            echo   Falling back to WSLg mode.
            set USE_VCXSRV=false
        )
    ) else (
        call :LOG "SUCCESS - VcXsrv already running"
        echo   VcXsrv: already running
    )
)

REM Convert bash log path to WSL format
for /f "delims=" %%i in ('wsl wslpath "%LOCALAPPDATA%\Kivun-WSL\BASH_LAUNCH_LOG.txt" 2^>nul') do set "BASH_LOG_WSL=%%i"
call :LOG "INFO - Bash log WSL path: %BASH_LOG_WSL%"

REM Detect which user owns WSLg's runtime dir. Qt's QStandardPaths
REM refuses to use XDG_RUNTIME_DIR unless it's owned by the current user,
REM which breaks Konsole's display when the default WSL user differs
REM from the one WSLg was initialized with. We run as that user instead.
set "WSLG_USER="
for /f "delims=" %%U in ('wsl -d Ubuntu --user root -- stat -c "%%U" /mnt/wslg/runtime-dir 2^>nul') do set "WSLG_USER=%%U"
if defined WSLG_USER (
    call :LOG "INFO - WSLg runtime dir owner: %WSLG_USER% - will run as this user"
    set "WSL_USER_FLAG=--user %WSLG_USER%"
) else (
    call :LOG "WARNING - Could not detect WSLg owner, using default user"
    set "WSL_USER_FLAG="
)

REM Get primary monitor size via wmic (PowerShell is blocked by GPO on some
REM machines). Windows always places the primary monitor at origin (0,0),
REM so we only need width+height; the launcher uses (0,0) for position.
REM Format passed to launcher: "X Y W H".
set "PRIMARY_MON="
set "MON_W="
set "MON_H="
for /f "tokens=1,2 delims==" %%a in ('wmic DESKTOPMONITOR GET screenwidth^,screenheight /FORMAT:list 2^>nul') do (
    if /i "%%a"=="ScreenWidth"  set "MON_W=%%b"
    if /i "%%a"=="ScreenHeight" set "MON_H=%%b"
)
if defined MON_W if defined MON_H set "PRIMARY_MON=0 0 %MON_W% %MON_H%"
call :LOG "INFO - Primary monitor bounds (wmic): %PRIMARY_MON%"

REM Launch via kivun-launch.sh (handles profile, colors, title, maximize).
REM start /MIN opens the WSL bash subprocess console minimized so it doesn't
REM clutter the desktop; all its output still goes to BASH_LAUNCH_LOG.txt.
echo.
echo Launching Konsole...
call :LOG "INFO - Launching Konsole via kivun-launch.sh"
call :LOG "INFO - Command: wsl -d Ubuntu %WSL_USER_FLAG% bash %INST_WSL%kivun-launch.sh %WSL_PATH% [prompt] %PRIMARY_LANGUAGE% %USE_VCXSRV% %BASH_LOG_WSL% %TEXT_DIRECTION% %PRIMARY_MON%"
title Kivun Terminal v%PRODUCT_VERSION% - Loading
start "Kivun Bash" /MIN wsl -d Ubuntu %WSL_USER_FLAG% bash "%INST_WSL%kivun-launch.sh" "%WSL_PATH%" "%CLAUDE_PROMPT%" "%PRIMARY_LANGUAGE%" "%USE_VCXSRV%" "%BASH_LOG_WSL%" "%TEXT_DIRECTION%" "%PRIMARY_MON%"
if %ERRORLEVEL% EQU 0 (
    call :LOG "SUCCESS - Launch command executed"
) else (
    call :LOG "ERROR - Launch command failed (error %ERRORLEVEL%)"
)

REM Wait for Konsole to start (profile deploy + launch takes a few seconds)
call :LOG "INFO - Waiting 8 seconds for Konsole to start"
timeout /t 8 /nobreak >nul

REM Check if a konsole process is running inside WSL
call :LOG "INFO - Checking if Konsole process is running"
wsl -d Ubuntu -- bash -c "pgrep -x konsole" 2>&1 >> "%LOG_FILE%"
if %ERRORLEVEL% EQU 0 (
    call :LOG "SUCCESS - Konsole is running"
    exit
)

REM Retry check - konsole may still be starting
call :LOG "INFO - Konsole not detected yet, waiting 5 more seconds"
timeout /t 5 /nobreak >nul
wsl -d Ubuntu -- bash -c "pgrep -x konsole" 2>&1 >> "%LOG_FILE%"
if %ERRORLEVEL% EQU 0 (
    call :LOG "SUCCESS - Konsole is running (detected on second check)"
    exit
)
call :LOG "WARNING - Konsole process not detected, may not have started (WSLg issue?)"

echo.
echo Konsole did not start (WSLg may not be available on this PC).
echo.

:run_direct
call :LOG "INFO - Falling back to direct Claude execution in terminal"
echo ========================================
echo   Running Claude directly in terminal
echo ========================================
echo.
call :LOG "INFO - Executing: claude --append-system-prompt [prompt]"
REM SECURITY: pass WSL_PATH and CLAUDE_PROMPT through the environment,
REM not inlined into the shell command string. A folder named
REM `a';rm -rf ~;'` would break out of the single-quoted `cd '%WSL_PATH%'`
REM form and execute rm. `env VAR=... bash -c 'cd "$VAR"'` keeps the
REM value as a single variable read at runtime, no re-parsing by shell.
wsl -d Ubuntu env KIVUN_DIR="%WSL_PATH%" KIVUN_PROMPT="%CLAUDE_PROMPT%" bash -l -c "cd \"$KIVUN_DIR\" 2>/dev/null || cd ~; claude --append-system-prompt \"$KIVUN_PROMPT\""
call :LOG "COMPLETE - Claude session ended"
echo.
echo ========================================
echo LAUNCH LOG SAVED TO:
echo %LOG_FILE%
echo ========================================
pause
exit /b

:LOG
echo [%TIME%] %~1 >> "%LOG_FILE%"
echo [%TIME%] %~1
exit /b

:SET_LANG_PROMPT
REM 23-language prompt table. %1 is the RESPONSE_LANGUAGE config value.
REM For RTL languages we append an instruction to prefix every line with
REM U+200F (Right-to-Left Mark), because Konsole's BiDi engine decides
REM paragraph direction from the FIRST character of a line. Claude's
REM formatted output often starts lines with bullets/numbers/dashes
REM (neutral/LTR characters) which force the paragraph to LTR. Prefixing
REM each line with an explicit RLM character forces RTL paragraph
REM direction regardless of what comes after.
REM KNOWN LIMITATION — upstream bug in Claude Code's TUI rendering:
REM Claude Code prepends every assistant message with a `●` bullet (see
REM `cli.js`, `B9=YA.platform==="darwin"?"⏺":"●"`). That bullet is a
REM Unicode neutral character that should be skipped per UAX #9 P2 when
REM determining paragraph direction, but every terminal emulator we've
REM tested treats it as the first character and forces LTR. As a result
REM the first line of Claude's reply renders left-aligned even when its
REM content is Hebrew.
REM
REM We have tried teaching Claude via --append-system-prompt to start
REM each response with a non-Hebrew line (dash, `## OK`, blank line,
REM etc.). Claude treats these as soft suggestions and ignores them on
REM ~50% of replies, wasting tokens on every turn.
REM
REM Clean fix must come from Anthropic. See docs/FEATURE_REQUEST_ANTHROPIC.md.
REM For now: keep the prompt minimal, as in the reference project. Line 2+
REM of Claude's Hebrew replies DOES render right-aligned correctly; only
REM the `●`-prefixed line 1 is affected.
set "RLM_SUFFIX="
set "LANG=%~1"
if /i "%LANG:~0,7%"=="english"     set "CLAUDE_PROMPT=Always respond in English." & exit /b
if /i "%LANG:~0,6%"=="hebrew"      set "CLAUDE_PROMPT=Always respond in Hebrew.%RLM_SUFFIX%" & exit /b
if /i "%LANG:~0,6%"=="arabic"      set "CLAUDE_PROMPT=Always respond in Arabic.%RLM_SUFFIX%" & exit /b
if /i "%LANG:~0,7%"=="persian"     set "CLAUDE_PROMPT=Always respond in Persian (Farsi).%RLM_SUFFIX%" & exit /b
if /i "%LANG:~0,4%"=="urdu"        set "CLAUDE_PROMPT=Always respond in Urdu.%RLM_SUFFIX%" & exit /b
if /i "%LANG:~0,7%"=="kurdish"     set "CLAUDE_PROMPT=Always respond in Kurdish.%RLM_SUFFIX%" & exit /b
if /i "%LANG:~0,6%"=="pashto"      set "CLAUDE_PROMPT=Always respond in Pashto.%RLM_SUFFIX%" & exit /b
if /i "%LANG:~0,6%"=="sindhi"      set "CLAUDE_PROMPT=Always respond in Sindhi.%RLM_SUFFIX%" & exit /b
if /i "%LANG:~0,7%"=="yiddish"     set "CLAUDE_PROMPT=Always respond in Yiddish.%RLM_SUFFIX%" & exit /b
if /i "%LANG:~0,6%"=="syriac"      set "CLAUDE_PROMPT=Always respond in Syriac.%RLM_SUFFIX%" & exit /b
if /i "%LANG:~0,7%"=="dhivehi"     set "CLAUDE_PROMPT=Always respond in Dhivehi (Maldivian).%RLM_SUFFIX%" & exit /b
if /i "%LANG:~0,3%"=="nko"         set "CLAUDE_PROMPT=Always respond in N'Ko.%RLM_SUFFIX%" & exit /b
if /i "%LANG:~0,5%"=="adlam"       set "CLAUDE_PROMPT=Always respond in Fulani using the Adlam script.%RLM_SUFFIX%" & exit /b
if /i "%LANG:~0,7%"=="mandaic"     set "CLAUDE_PROMPT=Always respond in Mandaic.%RLM_SUFFIX%" & exit /b
if /i "%LANG:~0,9%"=="samaritan"   set "CLAUDE_PROMPT=Always respond in Samaritan Hebrew.%RLM_SUFFIX%" & exit /b
if /i "%LANG:~0,4%"=="dari"        set "CLAUDE_PROMPT=Always respond in Dari.%RLM_SUFFIX%" & exit /b
if /i "%LANG:~0,6%"=="uyghur"      set "CLAUDE_PROMPT=Always respond in Uyghur.%RLM_SUFFIX%" & exit /b
if /i "%LANG:~0,7%"=="balochi"     set "CLAUDE_PROMPT=Always respond in Balochi.%RLM_SUFFIX%" & exit /b
if /i "%LANG:~0,8%"=="kashmiri"    set "CLAUDE_PROMPT=Always respond in Kashmiri.%RLM_SUFFIX%" & exit /b
if /i "%LANG:~0,9%"=="shahmukhi"   set "CLAUDE_PROMPT=Always respond in Punjabi using the Shahmukhi script.%RLM_SUFFIX%" & exit /b
if /i "%LANG:~0,11%"=="azeri-south" set "CLAUDE_PROMPT=Always respond in Southern Azerbaijani.%RLM_SUFFIX%" & exit /b
if /i "%LANG:~0,4%"=="jawi"        set "CLAUDE_PROMPT=Always respond in Malay using the Jawi script.%RLM_SUFFIX%" & exit /b
if /i "%LANG:~0,6%"=="turoyo"      set "CLAUDE_PROMPT=Always respond in Turoyo (Neo-Aramaic).%RLM_SUFFIX%" & exit /b
REM Unknown language — keep the existing CLAUDE_PROMPT (English default).
exit /b

:WIN_TO_WSL_PATH
REM Manual Windows-to-WSL path conversion.
REM %1 = Windows path (e.g. C:\Users\x\Kivun-WSL)
REM %2 = name of output variable
setlocal EnableDelayedExpansion
set "WPATH=%~1"
set "DRIVE=!WPATH:~0,1!"
REM Lowercase the drive letter
for %%C in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do if /i "!DRIVE!"=="%%C" set "DRIVE=%%C"
set "DRIVE=!DRIVE: =!"
if /i "!DRIVE!"=="A" set "dl=a"
if /i "!DRIVE!"=="B" set "dl=b"
if /i "!DRIVE!"=="C" set "dl=c"
if /i "!DRIVE!"=="D" set "dl=d"
if /i "!DRIVE!"=="E" set "dl=e"
if /i "!DRIVE!"=="F" set "dl=f"
if /i "!DRIVE!"=="G" set "dl=g"
if /i "!DRIVE!"=="H" set "dl=h"
set "REST=!WPATH:~2!"
set "REST=!REST:\=/!"
set "RESULT=/mnt/!dl!!REST!"
endlocal & set "%~2=%RESULT%"
exit /b
