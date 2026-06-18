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

REM v1.4.36: pin the WSL distro for BOTH path conversion AND execution.
REM A BARE "wsl wslpath" resolves against the user's DEFAULT distro, but every
REM real operation runs against Ubuntu. When the default distro isn't Ubuntu
REM (Docker Desktop's "docker-desktop" makes itself default and mounts C: at
REM /mnt/host/c, not /mnt/c), the converted path points somewhere that does
REM not exist inside Ubuntu -> "No such file or directory" / exit 127, and the
REM auto-install + launch both fail silently. Routing every wslpath AND every
REM -d call through one DISTRO knob keeps conversion and execution consistent
REM no matter what the user's default distro is.
set "DISTRO=Ubuntu"

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
REM v1.1.2: every wsl probe before set /p YN is fed `< nul` so it can't
REM swallow user input intended for the Claude install prompt. Without
REM this, the wsl pipe handshake consumed the "Y" the user typed and
REM the launcher silently behaved as if the user had declined.
echo WSL VERSION: >> "%LOG_FILE%"
wsl --version < nul >> "%LOG_FILE%" 2>&1
echo ---------------------------------------- >> "%LOG_FILE%"
echo WSL STATUS: >> "%LOG_FILE%"
wsl --status < nul >> "%LOG_FILE%" 2>&1
echo ---------------------------------------- >> "%LOG_FILE%"
echo WSL DISTRIBUTIONS: >> "%LOG_FILE%"
wsl -l -v < nul >> "%LOG_FILE%" 2>&1
echo ======================================== >> "%LOG_FILE%"
echo. >> "%LOG_FILE%"

echo ========================================
echo   KIVUN TERMINAL v%PRODUCT_VERSION% - STARTING...
echo   LOG FILE: %LOG_FILE%
echo ========================================
echo.

call :LOG "START - Launching Kivun Terminal v%PRODUCT_VERSION% (WSL Launcher)"

REM KIVUN_HIDDEN=1 is set by KivunTerminal.exe (the native no-console-flash
REM launcher). The console exists but has no window, so anything interactive
REM (pause, set /p) would block forever with nobody able to see or answer it.
REM Every interactive site below is guarded on this variable. Failures stay
REM visible: the exe waits for our exit code and shows a MessageBox with the
REM LAUNCH_LOG tail when it is non-zero.
if defined KIVUN_HIDDEN call :LOG "INFO - KIVUN_HIDDEN=1 (native hidden launcher); console prompts disabled"

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
REM Legacy constant: VcXsrv support was removed (Konsole always uses WSLg).
REM Kept only so kivun-launch.sh's 4th positional arg stays "false".
set USE_VCXSRV=false
set TEXT_DIRECTION=rtl
set FOLDER_PICKER=false
set "CLAUDE_FLAGS="
REM v1.1.3: AUTO_INSTALL_CLAUDE controls the Claude-missing flow.
REM   yes (default) - install automatically, no prompt
REM   ask           - prompt [Y/N] like v1.1.1/v1.1.2
REM   no            - skip install, exit with manual instructions
set AUTO_INSTALL_CLAUDE=yes
if exist "%~dp0config.txt" (
    REM SECURITY: quote the SET target. Unquoted `set X=%%b` lets CMD
    REM parse the value — a config line `RESPONSE_LANGUAGE=english& calc.exe`
    REM would execute `calc.exe` during config load. The quoted form
    REM `set "X=%%b"` treats the contents as literal (& | ^ < > are
    REM all safe inside the quotes).
    REM
    REM v1.3.1: read the file directly via for /f "eol=#" instead of
    REM piping through `type ... | findstr /v "^#"`. The pipe-form
    REM treated LF-only configs (which `cp` from Linux/WSL produces)
    REM as a single line — findstr saw it start with # and filtered
    REM the entire file out, leaving every config key at its compiled-
    REM in default. Reading the file directly via for /f handles both
    REM LF and CRLF; eol=# skips comments without findstr.
    for /f "usebackq eol=# tokens=1,2 delims==" %%a in ("%~dp0config.txt") do (
        if "%%a"=="RESPONSE_LANGUAGE"     set "RESPONSE_LANGUAGE=%%b"
        if "%%a"=="PRIMARY_LANGUAGE"      set "PRIMARY_LANGUAGE=%%b"
        if "%%a"=="TEXT_DIRECTION"        set "TEXT_DIRECTION=%%b"
        if "%%a"=="FOLDER_PICKER"         set "FOLDER_PICKER=%%b"
        if "%%a"=="AUTO_INSTALL_CLAUDE"   set "AUTO_INSTALL_CLAUDE=%%b"
        if "%%a"=="CLAUDE_FLAGS"          set "CLAUDE_FLAGS=%%b"
    )
    call :LOG "SUCCESS - Config loaded: language=%RESPONSE_LANGUAGE%, keyboard=%PRIMARY_LANGUAGE%, textdir=%TEXT_DIRECTION%, folderpicker=%FOLDER_PICKER%, flags=%CLAUDE_FLAGS%"
) else (
    call :LOG "WARNING - config.txt not found, using defaults"
)
echo Language: %RESPONSE_LANGUAGE%
echo Keyboard: %PRIMARY_LANGUAGE%

REM If FOLDER_PICKER=true AND no folder was passed as arg (i.e. launched
REM from the desktop shortcut, not from a right-click context menu), pop
REM a native Windows folder-browse dialog.
REM
REM Flow is goto-based on purpose: cmd parses the bodies of nested `(...)`
REM blocks once, up-front, expanding `%PICKED%` to whatever it was BEFORE
REM `set /p PICKED=<file` ran. The earlier nested-paren version always
REM produced WORK_DIR="" (parse-time expansion of an empty PICKED), the
REM launcher's empty-WORK_DIR guard then substituted %USERPROFILE%, and
REM the user's chosen folder was silently discarded. Top-level statements
REM between labels evaluate %VAR% at runtime, so the picker result
REM actually reaches WORK_DIR.
REM PICKER_INVOKED tracks whether the HTA dialog actually ran. When the
REM picker DID run but produced no kivun-workdir.txt, that means the user
REM clicked Cancel (or hit Esc / closed the X) — and the user-stated
REM contract is "Cancel terminates", so the launcher exits without
REM starting Konsole. The pre-Cancel-fix behavior was to silently fall
REM back to %USERPROFILE%, which from the user's POV looked exactly like
REM "Launch fired itself".
set "PICKER_INVOKED=0"
if /i not "%FOLDER_PICKER:~0,4%"=="true" goto :picker_done
if not "%~1"=="" goto :picker_done
call :LOG "INFO - FOLDER_PICKER enabled, launching HTA dialog"
if not exist "%~dp0folder-picker.hta" (
    call :LOG "WARNING - folder-picker.hta not found in install dir, falling back to .wsf"
    if not exist "%~dp0folder-picker.wsf" (
        call :LOG "WARNING - folder-picker.wsf also not found; skipping picker"
        goto :picker_done
    )
    set "PICKER_INVOKED=1"
    cscript //Nologo "%~dp0folder-picker.wsf" >nul 2>&1
    goto :picker_read
)
REM v1.3.0: HTA picker replaces the .wsf BrowseForFolder. The HTA
REM offers a path edit field, a Browse button (which still calls the
REM native BrowseForFolder for the tree), AND an "Edit Default Flags"
REM button that opens config.txt in Notepad — all in one dialog.
REM Why HTA: native BrowseForFolder doesn't allow custom buttons.
REM
REM v1.3.3: invoke mshta.exe DIRECTLY (no `start /wait`). cmd waits
REM for mshta to exit by default, and `start /wait mshta.exe ...`
REM was unreliably synchronous in some configurations — Konsole
REM could begin launching before the user finished with the picker
REM dialog. Direct invocation guarantees the .bat blocks until the
REM dialog window closes.
set "PICKER_INVOKED=1"
mshta.exe "%~dp0folder-picker.hta"
:picker_read
if not exist "%LOCALAPPDATA%\Kivun-WSL\kivun-workdir.txt" (
    call :LOG "INFO - User cancelled folder picker — terminating launcher"
    echo.
    echo Cancelled.
    exit /b 0
)
set "PICKED="
set /p PICKED=<"%LOCALAPPDATA%\Kivun-WSL\kivun-workdir.txt"
del "%LOCALAPPDATA%\Kivun-WSL\kivun-workdir.txt" >nul 2>&1
if not defined PICKED (
    call :LOG "INFO - Picker file empty (treated as cancel) — terminating launcher"
    echo.
    echo Cancelled.
    exit /b 0
)
set "WORK_DIR=%PICKED%"
call :LOG "SUCCESS - User picked folder: %PICKED%"
echo Work directory updated: %PICKED%
:picker_done

REM Re-read CLAUDE_FLAGS from config.txt — the HTA picker may have just
REM rewritten the line based on the user's flag-picker selections, and
REM the version we loaded at startup is now stale. Only this single key
REM needs refreshing; language/theme/bidi keys aren't editable from the
REM picker, so the rest of the config-loaded variables are still good.
if exist "%~dp0config.txt" (
    for /f "usebackq eol=# tokens=1,2 delims==" %%a in ("%~dp0config.txt") do (
        if "%%a"=="CLAUDE_FLAGS" set "CLAUDE_FLAGS=%%b"
    )
    call :LOG "INFO - CLAUDE_FLAGS after picker: %CLAUDE_FLAGS%"
)

REM One-shot resume flag (--continue / --resume) chosen in the HTA picker.
REM The picker writes it to a sidecar (NOT config.txt) so it applies to THIS
REM launch only. Apply it solely on the picker path (PICKER_INVOKED=1); on any
REM other path just delete a stale file so it can never leak into a right-click
REM launch and crash on a folder with no prior conversation.
set "CONV_ONCE=%LOCALAPPDATA%\Kivun-WSL\kivun-conv-once.txt"
if not exist "%CONV_ONCE%" goto :conv_done
if "%PICKER_INVOKED%"=="1" goto :conv_apply
del "%CONV_ONCE%" >nul 2>&1
goto :conv_done
:conv_apply
set "CONV_FLAG="
set /p CONV_FLAG=<"%CONV_ONCE%"
del "%CONV_ONCE%" >nul 2>&1
if not defined CONV_FLAG goto :conv_done
set "CLAUDE_FLAGS=%CLAUDE_FLAGS% %CONV_FLAG%"
call :LOG "INFO - Applied one-shot resume flag from picker: %CONV_FLAG%"
:conv_done

REM v1.4.0: pick up startup slash commands the HTA picker may have
REM written (one command per line). kivun-launch.sh reads the file
REM content itself and types each line into Konsole after Claude is up.
REM Convert the Windows path to a WSL path so bash can read it directly.
set "STARTUP_CMDS_WSL="
if exist "%LOCALAPPDATA%\Kivun-WSL\kivun-startup-cmds.txt" (
    for /f "delims=" %%i in ('wsl -d %DISTRO% wslpath "%LOCALAPPDATA%\Kivun-WSL\kivun-startup-cmds.txt" 2^>nul') do set "STARTUP_CMDS_WSL=%%i"
    call :LOG "INFO - Startup commands file: %STARTUP_CMDS_WSL%"
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
wsl --version < nul 2>&1 >> "%LOG_FILE%"
if %ERRORLEVEL% NEQ 0 (
    call :LOG "ERROR - WSL not found or not working (error %ERRORLEVEL%)"
    echo ERROR: WSL not found or not working.
    echo Run the Kivun Terminal installer to fix this.
    echo.
    echo Log file: %LOG_FILE%
    if not defined KIVUN_HIDDEN pause
    exit /b 1
)
call :LOG "SUCCESS - WSL is installed and working"
echo   WSL: OK

call :LOG "INFO - Checking Ubuntu distribution"
wsl -d %DISTRO% echo OK < nul 2>&1 >> "%LOG_FILE%"
if %ERRORLEVEL% NEQ 0 (
    call :LOG "WARNING - Ubuntu not responding, attempting WSL restart"
    echo Ubuntu not responding, restarting WSL...
    wsl --shutdown
    call :LOG "INFO - WSL shutdown command issued, waiting 3 seconds"
    timeout /t 3 /nobreak >nul
    wsl -d %DISTRO% echo OK < nul 2>&1 >> "%LOG_FILE%"
    if %ERRORLEVEL% NEQ 0 (
        call :LOG "ERROR - Ubuntu not available after restart (error %ERRORLEVEL%)"
        echo ERROR: Ubuntu not available.
        echo Run the Kivun Terminal installer to fix this.
        echo.
        echo Log file: %LOG_FILE%
        if not defined KIVUN_HIDDEN pause
        exit /b 1
    )
    call :LOG "SUCCESS - Ubuntu is now responding after restart"
) else (
    call :LOG "SUCCESS - Ubuntu is running"
)
echo   Ubuntu: OK

REM Check if Claude Code is installed (v1.1.2: must run BEFORE the
REM Konsole check. If Konsole apt-install fails, the launcher used to
REM jump straight to :run_direct and trip the no-claude guard, so the
REM Claude install offer was silently skipped on flaky-apt machines.
REM Now Claude is checked first: even if Konsole later fails, the user
REM still gets offered the auto-install.)
call :LOG "INFO - Checking if Claude Code is installed"
set "CLAUDE_IN_WSL=0"
REM v1.1.5: presence check must match the post-install verify step's
REM logic (see :_do_install). `command -v claude` runs in non-login,
REM non-interactive bash whose default PATH does NOT include
REM ~/.local/bin -- the directory where Anthropic's curl installer
REM drops the binary. So an existing claude install was invisible to
REM this check, and the launcher reinstalled Claude on every launch
REM (user report: "it keeps installing the terminal, that's a bit dumb").
REM
REM v1.1.6: try the standard absolute slots first (fast, deterministic),
REM then fall back to a LOGIN shell PATH lookup that asks bash where
REM claude actually is. This catches nvm / pnpm / yarn-global / snap /
REM corp installs whose paths are added to PATH only by .bashrc /
REM .profile, without requiring the user to set a config var. The
REM resolver in kivun-claude-bidi/lib/resolve-claude-bin.js does the
REM same thing on the wrapper side -- both paths agree about what
REM "installed" means.
wsl -d %DISTRO% -- bash -c "test -x $HOME/.local/bin/claude || test -x /usr/local/bin/claude || test -x /usr/bin/claude" < nul 2>&1 >> "%LOG_FILE%"
if %ERRORLEVEL% EQU 0 goto :claude_present
REM Standard slots empty -- ask a login shell to actively discover.
REM bash -lc sources .profile/.bashrc so nvm/pnpm/yarn paths are
REM visible. `grep -q -v ^/mnt/` rejects a Windows npm claude reached
REM through the appended Windows PATH (/mnt/c/.../npm/claude) -- not a
REM runnable native Linux binary; accepting it made the launcher skip
REM the native install and then drive the Windows binary (TUI dies).
wsl -d %DISTRO% -- bash -lc "command -v claude | grep -q -v ^/mnt/" < nul 2>&1 >> "%LOG_FILE%"
if %ERRORLEVEL% EQU 0 (
    call :LOG "INFO - Claude found via login-shell PATH (non-standard install location)"
    goto :claude_present
)
call :LOG "ERROR - Claude Code not found in Ubuntu"
echo   Claude Code: NOT FOUND in WSL
call :INSTALL_CLAUDE_WSL
if "%CLAUDE_IN_WSL%"=="1" goto :claude_present
goto :no_claude_exit
:claude_present
set "CLAUDE_IN_WSL=1"
call :LOG "SUCCESS - Claude Code is installed"
echo   Claude: OK

REM v1.1.18: do path conversion + WSLg-user detection BEFORE the
REM Konsole check. The Konsole apt-install can fail (no GUI on a CI
REM runner, flaky apt mirror, network outage) and the launcher then
REM falls through to :run_direct via `goto`. Until v1.1.18 the goto
REM jumped OVER both the path conversion (sets WSL_PATH + INST_WSL)
REM and the WSLg-user detection (sets WSL_USER_FLAG), so the direct
REM fallback ran with all three variables empty — bash got
REM `wsl -d %DISTRO% bash kivun-direct.sh` with no INST_WSL prefix,
REM couldn't find the script, the launch silently failed, and the
REM launcher logged "Claude session ended" anyway because the exit
REM code wasn't checked. Reordering puts all three variables in the
REM environment before we try Konsole, so both the Konsole-launch
REM path and the direct-fallback path use the same resolved
REM WSL_PATH / INST_WSL / WSL_USER_FLAG.

REM Convert paths
call :LOG "INFO - Converting Windows paths to WSL paths"
REM v1.1.17: pre-validate WORK_DIR before wslpath. The launcher used to
REM let `wslpath "."` return literal "." then fall back to ~ (WSL home).
REM But ~ resolves to /home/<user> — NOT what users expect when the
REM Desktop shortcut promised %USERPROFILE% (their Windows home).
REM Now: if WORK_DIR is empty OR ".", substitute %USERPROFILE% upfront
REM so wslpath converts a real Windows path → /mnt/c/Users/<user>.
if "%WORK_DIR%"=="" (
    set "WORK_DIR=%USERPROFILE%"
    call :LOG "INFO - WORK_DIR was empty, substituting USERPROFILE=%USERPROFILE%"
)
if "%WORK_DIR%"=="." (
    set "WORK_DIR=%USERPROFILE%"
    call :LOG "INFO - WORK_DIR was '.', substituting USERPROFILE=%USERPROFILE%"
)
for /f "delims=" %%i in ('wsl -d %DISTRO% wslpath "%WORK_DIR%" 2^>nul') do set "WSL_PATH=%%i"
REM Belt-and-suspenders: if wslpath still returned "" or ".", fall back
REM to USERPROFILE via a second wslpath call (NOT to ~). v1.1.16 used ~
REM which lands users in the WSL home; v1.1.17 keeps the Windows-home
REM contract that the Desktop shortcut implies.
if "%WSL_PATH%"=="" (
    for /f "delims=" %%i in ('wsl -d %DISTRO% wslpath "%USERPROFILE%" 2^>nul') do set "WSL_PATH=%%i"
    call :LOG "WARNING - wslpath returned empty for '%WORK_DIR%', falling back to USERPROFILE"
) else if "%WSL_PATH%"=="." (
    for /f "delims=" %%i in ('wsl -d %DISTRO% wslpath "%USERPROFILE%" 2^>nul') do set "WSL_PATH=%%i"
    call :LOG "WARNING - wslpath returned '.' for '%WORK_DIR%', falling back to USERPROFILE"
) else (
    call :LOG "SUCCESS - WSL work path: %WSL_PATH%"
)
call :LOG "INFO - Converting installation directory: %~dp0"
REM %~dp0 ends with a backslash which confuses wslpath. Strip it.
set "INST_DIR=%~dp0"
if "%INST_DIR:~-1%"=="\" set "INST_DIR=%INST_DIR:~0,-1%"
for /f "delims=" %%i in ('wsl -d %DISTRO% wslpath -a "%INST_DIR%" 2^>nul') do set "INST_WSL=%%i"
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
call :LOG "INFO - Fixing line endings in kivun-launch.sh + kivun-direct.sh + kivun-set-icon.py + kivun-install-claude.sh"
wsl -d %DISTRO% -- sed -i "s/\r$//" "%INST_WSL%kivun-launch.sh" 2>&1 >> "%LOG_FILE%"
wsl -d %DISTRO% -- sed -i "s/\r$//" "%INST_WSL%kivun-direct.sh" 2>&1 >> "%LOG_FILE%"
wsl -d %DISTRO% -- sed -i "s/\r$//" "%INST_WSL%kivun-set-icon.py" 2>&1 >> "%LOG_FILE%"
REM v1.4.36: kivun-install-claude.sh runs from :INSTALL_CLAUDE_WSL (before this
REM block on a first install) but is also re-stripped here so a CRLF-shipped
REM copy never trips bash with the same exit-127 "No such file" class of error.
wsl -d %DISTRO% -- sed -i "s/\r$//" "%INST_WSL%kivun-install-claude.sh" 2>&1 >> "%LOG_FILE%"
if %ERRORLEVEL% EQU 0 (
    call :LOG "SUCCESS - Line endings fixed"
) else (
    call :LOG "WARNING - Failed to fix line endings (error %ERRORLEVEL%)"
)

REM Convert bash log path to WSL format
for /f "delims=" %%i in ('wsl -d %DISTRO% wslpath "%LOCALAPPDATA%\Kivun-WSL\BASH_LAUNCH_LOG.txt" 2^>nul') do set "BASH_LOG_WSL=%%i"
call :LOG "INFO - Bash log WSL path: %BASH_LOG_WSL%"

REM Detect which user owns WSLg's runtime dir. Qt's QStandardPaths
REM refuses to use XDG_RUNTIME_DIR unless it's owned by the current user,
REM which breaks Konsole's display when the default WSL user differs
REM from the one WSLg was initialized with. We run as that user instead.
set "WSLG_USER="
for /f "delims=" %%U in ('wsl -d %DISTRO% --user root -- stat -c "%%U" /mnt/wslg/runtime-dir 2^>nul') do set "WSLG_USER=%%U"
REM v1.1.4: stat -c "%U" returns the literal string "UNKNOWN" when the
REM directory's UID has no /etc/passwd entry (e.g. fresh WSL distros
REM created via cloud images). Passing that to `wsl --user UNKNOWN`
REM makes wsl reject the launch with error 1 and Konsole never starts.
REM Treat UNKNOWN exactly like "not detected".
if /i "%WSLG_USER%"=="UNKNOWN" set "WSLG_USER="

REM v1.1.15: never let the launcher run as root. Claude Code refuses
REM --dangerously-skip-permissions when EUID==0. v1.1.14 only handled
REM the case where WSLG_USER explicitly equaled "root"; it missed the
REM case where WSLG_USER detection returns EMPTY and the wsl default
REM user happens to be root (mipmip's actual scenario). v1.1.15 simpler
REM and exhaustive: discard any root-or-empty result and fall back to
REM UID 1000 (the conventional first non-root user). If even that
REM fails, abort with copy-paste-able instructions for creating a
REM non-root user. Logic is intentionally flat (no nested if blocks)
REM so cmd's parse-time vs runtime variable expansion can't introduce
REM subtle bugs.
if /i "%WSLG_USER%"=="root" set "WSLG_USER="
if not defined WSLG_USER (
    call :LOG "INFO - WSLg owner unusable; querying UID 1000 as non-root fallback"
    for /f "delims=" %%U in ('wsl -d %DISTRO% --user root -- id -un 1000 2^>nul') do set "WSLG_USER=%%U"
)
if not defined WSLG_USER (
    call :LOG "INFO - No non-root user in Ubuntu; auto-creating one (Claude cannot run as root)"
    echo   Setting up your Linux user ^(one-time, a few seconds^)...
    type "%~dp0kivun-ensure-user.sh" | wsl -d %DISTRO% --user root -- bash -s >> "%LOG_FILE%" 2>&1
    call :LOG "INFO - Restarting Ubuntu so the new default user owns WSLg"
    wsl --terminate Ubuntu >> "%LOG_FILE%" 2>&1
    for /f "delims=" %%U in ('wsl -d %DISTRO% --user root -- id -un 1000 2^>nul') do set "WSLG_USER=%%U"
)
if not defined WSLG_USER (
    call :LOG "ERROR - Could not auto-create a non-root user in Ubuntu"
    echo.
    echo  Could not set up a Linux user automatically. Please open
    echo  "Kivun Diagnostics" from the Start Menu and email the
    echo  report to noambbb@gmail.com so we can help.
    if not defined KIVUN_HIDDEN pause
    exit /b 1
)
call :LOG "INFO - Will run as: %WSLG_USER%"
set "WSL_USER_FLAG=--user %WSLG_USER%"

REM Check if Konsole is installed
call :LOG "INFO - Checking if Konsole is installed"
wsl -d %DISTRO% -- bash -c "command -v konsole" 2>&1 >> "%LOG_FILE%"
if %ERRORLEVEL% NEQ 0 (
    call :LOG "WARNING - Konsole not found, attempting installation"
    echo   Konsole: NOT FOUND - installing...
    wsl -d %DISTRO% -- sudo apt-get install -y konsole 2>&1 >> "%LOG_FILE%"
    wsl -d %DISTRO% -- bash -c "command -v konsole" 2>&1 >> "%LOG_FILE%"
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

REM Ensure python3-xlib + python3-pil are present so kivun-launch.sh
REM can override the Konsole window icon (see kivun-set-icon.py). This
REM is optional -- the launcher logs and skips if missing -- but the
REM cost of pre-installing is low and gives every user the branded
REM icon out of the box. Use --user root to avoid sudo password prompts.
call :LOG "INFO - Checking python3-xlib + python3-pil for icon override"
wsl -d %DISTRO% -- bash -c "python3 -c 'import Xlib, PIL' 2>/dev/null" >> "%LOG_FILE%" 2>&1
if %ERRORLEVEL% NEQ 0 (
    call :LOG "INFO - Installing python3-xlib + python3-pil"
    wsl -d %DISTRO% --user root -- apt-get install -y python3-xlib python3-pil >> "%LOG_FILE%" 2>&1
    if %ERRORLEVEL% NEQ 0 (
        call :LOG "WARNING - python deps install failed; window will keep default X icon"
    ) else (
        call :LOG "SUCCESS - python deps installed"
    )
) else (
    call :LOG "SUCCESS - python deps already present"
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

REM v1.4.0: load per-profile env vars from kivun-env.txt (written by the
REM picker HTA on Launch). Each KEY=VAL becomes an env var in this cmd
REM scope AND gets appended to WSLENV so it crosses the WSL boundary —
REM without WSLENV, Windows-side env vars don't reach the bash process.
REM
REM File schema: KEY=VAL one per line, # comments allowed, KEY validated
REM by the picker as ^[A-Za-z_][A-Za-z0-9_]*$. tokens=1,* preserves any
REM '=' that appears in VAL after the first one. eol=# skips comments.
set "ENV_FILE=%LOCALAPPDATA%\Kivun-WSL\kivun-env.txt"
if exist "%ENV_FILE%" (
    call :LOG "INFO - Loading env vars from %ENV_FILE%"
    for /f "usebackq eol=# tokens=1,* delims==" %%a in ("%ENV_FILE%") do (
        if not "%%a"=="" call :ADDENV "%%a" "%%b"
    )
) else (
    call :LOG "INFO - No %ENV_FILE% (no per-profile env vars to load)"
)
REM Log final WSLENV outside the (...) block. cmd parse-time-expands the
REM body of an `if (...)` block ONCE when it reads the block, so a
REM `%WSLENV%` reference inside would show the pre-loop value, not the
REM value set by :ADDENV during the for loop. At top level, the line is
REM re-expanded right before it runs and reflects the loop's side effect.
if defined WSLENV call :LOG "INFO - WSLENV after env load: %WSLENV%"

REM Launch via kivun-launch.sh (handles profile, colors, title, maximize).
REM start /MIN opens the WSL bash subprocess console minimized so it doesn't
REM clutter the desktop; all its output still goes to BASH_LAUNCH_LOG.txt.
echo.
echo Launching Konsole...
call :LOG "INFO - Launching Konsole via kivun-launch.sh"
call :LOG "INFO - Command: wsl -d %DISTRO% %WSL_USER_FLAG% bash %INST_WSL%kivun-launch.sh %WSL_PATH% [prompt] %PRIMARY_LANGUAGE% %USE_VCXSRV% %BASH_LOG_WSL% %TEXT_DIRECTION% %PRIMARY_MON% [flags]"
title Kivun Terminal v%PRODUCT_VERSION% - Loading
REM Hidden mode: /MIN would create a NEW minimized console for wsl.exe - a
REM visible taskbar item, the exact thing the native launcher exists to kill.
REM /B keeps wsl.exe attached to THIS console, which has no window
REM (CREATE_NO_WINDOW), so nothing appears anywhere. Konsole itself detaches
REM via setsid inside kivun-launch.sh, so its lifetime never depended on
REM wsl.exe in the first place. Goto-flat: %CLAUDE_PROMPT% may contain
REM parens (e.g. "(Farsi)"), which break inside an if (...) block.
if defined KIVUN_HIDDEN goto :launch_hidden
start "Kivun Bash" /MIN wsl -d %DISTRO% %WSL_USER_FLAG% bash "%INST_WSL%kivun-launch.sh" "%WSL_PATH%" "%CLAUDE_PROMPT%" "%PRIMARY_LANGUAGE%" "%USE_VCXSRV%" "%BASH_LOG_WSL%" "%TEXT_DIRECTION%" "%PRIMARY_MON%" "%CLAUDE_FLAGS%" "%STARTUP_CMDS_WSL%"
goto :launch_spawned
:launch_hidden
call :LOG "INFO - KIVUN_HIDDEN: start /B keeps the WSL bridge in this hidden console (no taskbar item)"
start "Kivun Bash" /B wsl -d %DISTRO% %WSL_USER_FLAG% bash "%INST_WSL%kivun-launch.sh" "%WSL_PATH%" "%CLAUDE_PROMPT%" "%PRIMARY_LANGUAGE%" "%USE_VCXSRV%" "%BASH_LOG_WSL%" "%TEXT_DIRECTION%" "%PRIMARY_MON%" "%CLAUDE_FLAGS%" "%STARTUP_CMDS_WSL%"
:launch_spawned
if %ERRORLEVEL% EQU 0 (
    call :LOG "SUCCESS - Launch command executed"
) else (
    call :LOG "ERROR - Launch command failed (error %ERRORLEVEL%)"
)

REM kivun-launch.sh has been spawned async. We deliberately do NOT poll
REM for it to confirm Konsole is up:
REM   - pgrep had a 13-second timeout and races on slow systems. When
REM     pgrep returned empty (Konsole still starting), the launcher
REM     fell through to :run_direct and spawned a SECOND claude in this
REM     cmd window. User-reported result: two Claude instances visible.
REM   - kivun-launch.sh writes its own progress to BASH_LAUNCH_LOG.txt;
REM     if Konsole fails to launch the user can inspect that log.
REM   - The :run_direct label below is still kept for HARD failures
REM     reached via explicit `goto :run_direct` earlier in this script
REM     (e.g. Konsole apt-install failure during this very launch).
REM
REM Trust the bash launcher. Exit cleanly so the cmd window closes and
REM Konsole becomes the only visible Claude window.
call :LOG "INFO - kivun-launch.sh spawned; trusting it to handle Konsole"
exit /b 0

:run_direct
call :LOG "INFO - Falling back to direct Claude execution in WSL terminal"
REM v1.1.1: guard against invoking claude when the presence check
REM already reported it missing. Previously the launcher would say
REM "Falling back to direct Claude execution" after ERROR - Claude
REM Code not found, then run the exact same WSL invocation that just
REM failed. That "fallback" always crashed with bash: claude: command
REM not found. Now we refuse to fake it: no Claude in WSL -> clean exit.
if not "%CLAUDE_IN_WSL%"=="1" (
    call :LOG "ERROR - Cannot run direct: claude missing in WSL"
    goto :no_claude_exit
)
REM Hidden mode: an INTERACTIVE Claude session cannot run in a console with
REM no window. Open a fresh visible console for it and exit this hidden one.
if not defined KIVUN_HIDDEN goto :run_direct_console
call :LOG "INFO - KIVUN_HIDDEN: opening a visible console for the direct Claude session"
start "Kivun Terminal" wsl -d %DISTRO% %WSL_USER_FLAG% bash "%INST_WSL%kivun-direct.sh" "%WSL_PATH%" "%CLAUDE_PROMPT%" "%CLAUDE_FLAGS%"
exit /b 0
:run_direct_console
echo ========================================
echo   Running Claude directly in terminal
echo ========================================
echo.
call :LOG "INFO - Executing: claude --append-system-prompt [prompt]"
REM v1.1.4: previously this line embedded the entire bash command in a
REM cmd-quoted string with `\"$KIVUN_DIR\"` style escaping. cmd does
REM NOT process backslash escapes, so the inner `"` toggled cmd's
REM quote state and broke parsing - same class of bug we hit five
REM times in INSTALL_CLAUDE_WSL. Plus the bare `claude` here relied
REM on PATH lookup, but ~/.local/bin (where the curl installer puts
REM claude) is not on the default PATH for non-interactive bash -l -c,
REM so the fallback failed even when claude WAS installed.
REM The kivun-direct.sh script does the cd and the absolute-path
REM lookup in pure bash where quoting actually works.
REM v1.1.15: pass WSL_USER_FLAG to the direct fallback too. v1.1.14 fixed
REM the Konsole-launch path but missed this one — when Konsole failed and
REM we fell back to direct execution, we'd still spawn Claude as the wsl
REM default user (which on root-default-user distros is root, and Claude
REM refuses). Now both paths use the same resolved non-root user.
wsl -d %DISTRO% %WSL_USER_FLAG% bash "%INST_WSL%kivun-direct.sh" "%WSL_PATH%" "%CLAUDE_PROMPT%" "%CLAUDE_FLAGS%"
call :LOG "COMPLETE - Claude session ended"
echo.
echo ========================================
echo LAUNCH LOG SAVED TO:
echo %LOG_FILE%
echo ========================================
if not defined KIVUN_HIDDEN pause
exit /b

:LOG
echo [%TIME%] %~1 >> "%LOG_FILE%"
echo [%TIME%] %~1
exit /b

REM ADDENV %1=KEY %2=VAL: set the env var in this cmd scope AND append KEY
REM to WSLENV (colon-separated) so it propagates into the WSL bash that
REM start-launches kivun-launch.sh. Quoted set form prevents cmd from
REM interpreting & | ^ < > inside VAL — the picker validates KEY as
REM [A-Za-z_][A-Za-z0-9_]* before writing kivun-env.txt, so KEY itself
REM is always safe to use as a variable name. Subroutine pattern (vs.
REM inline assignment in the for /f loop) avoids needing
REM `setlocal enabledelayedexpansion` — vars set here persist to caller.
:ADDENV
if "%~1"=="" exit /b
set "%~1=%~2"
if defined WSLENV (
    set "WSLENV=%WSLENV%:%~1"
) else (
    set "WSLENV=%~1"
)
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
if /i "%LANG:~0,6%"=="hebrew"      set "CLAUDE_PROMPT=Always respond in Hebrew. When mixing Hebrew with English words, code identifiers, paths, or numbers, always insert a space between the Hebrew text and the foreign token (write 'הקובץ src/index.ts' not 'הקובץsrc/index.ts'). Place demonstratives like הזה / הזאת / האלה AFTER the foreign noun with a space (write 'ה-endpoint הזה' not 'הזה-endpoint'). The 'ה-' prefix attaches to a single foreign noun directly via hyphen with no space (e.g. 'ה-API', 'ה-backend'); other Hebrew words must be space-separated from foreign tokens.%RLM_SUFFIX%" & exit /b
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

:INSTALL_CLAUDE_WSL
REM v1.1.3 - install Claude Code inside WSL Ubuntu.
REM Sets CLAUDE_IN_WSL=1 on success, leaves it 0 otherwise.
REM Strategy matches installer/Kivun_Terminal_Setup.nsi: curl installer
REM primary, nodejs+npm fallback.
REM
REM AUTO_INSTALL_CLAUDE controls whether we prompt:
REM   yes (default) - install without asking (the launcher's whole job
REM                   is to run Claude Code, so the consent is implicit
REM                   in launching the launcher)
REM   ask           - keep the v1.1.2 [Y/N] prompt
REM   no            - skip and exit with manual instructions
set "CLAUDE_IN_WSL=0"
echo.
echo Claude Code is required to run Kivun Terminal.
echo Windows-side Claude Code does NOT work here - Konsole runs in WSL.
echo.
REM Hidden mode has no console to show the [Y/N] prompt; the set /p would
REM block invisibly forever. Coerce ask -> yes (the documented default).
if not defined KIVUN_HIDDEN goto :_install_dispatch
if /i not "%AUTO_INSTALL_CLAUDE%"=="ask" goto :_install_dispatch
call :LOG "INFO - KIVUN_HIDDEN: AUTO_INSTALL_CLAUDE=ask coerced to yes (no console to prompt)"
set "AUTO_INSTALL_CLAUDE=yes"
:_install_dispatch
if /i "%AUTO_INSTALL_CLAUDE%"=="no"  goto :_decline_install
if /i "%AUTO_INSTALL_CLAUDE%"=="ask" goto :_prompt_install
call :LOG "INFO - Auto-installing Claude (AUTO_INSTALL_CLAUDE=yes)"
goto :_do_install

:_prompt_install
set /p YN="Install Claude Code in Ubuntu now? [Y/N] "
if /i not "%YN%"=="Y" goto :_decline_install
call :LOG "INFO - User accepted Claude auto-install"

:_do_install
echo Installing Claude Code via official installer (~1-2 min)...
REM v1.1.2: this helper used to use `if %ERRORLEVEL% NEQ 0 (...)` parens
REM blocks. cmd's parser inside parens treats redirection operators
REM (>>, 2>&1) and && more aggressively than at top level - even when
REM they are inside a "..."-quoted argument to wsl/bash - producing
REM "... was unexpected at this time." and an empty install. All control
REM flow here is now goto-based, with each wsl invocation at top level
REM where its quoted argument passes through to bash verbatim.
REM Fixed temp filename (was $(mktemp ...)) for the same reason: the
REM inner ( and ) inside a cmd-quoted bash command were being matched
REM against the surrounding cmd parens block and breaking parsing.
REM Install runs as the WSL DEFAULT USER, NOT -u root. The Anthropic
REM curl installer drops claude into ~/.local/bin. With -u root that
REM resolves to /root/.local/bin which the regular user (= every other
REM wsl invocation in this launcher) can't see. CI proved this: the
REM install logged "Claude Code successfully installed" but the verify
REM step couldn't find it.
REM
REM v1.1.19 added `timeout 600` + `| tee /tmp/kivun-claude.log` — install
REM COMPLETED on disk but tee held the pipe open, wsl.exe never returned.
REM v1.1.20 dropped the pipe (`> /tmp/kivun-claude.log 2>&1 < /dev/null`)
REM but wsl.exe STILL hung. CI run 25014868847 proved it: install
REM completed (binary at /root/.local/bin/claude → versions/2.1.119),
REM LAUNCH_LOG ended at "Auto-installing Claude" with no INSTALL_RC line,
REM wsl.exe was still alive 2 min later. Something in claude.ai/install.sh's
REM "native build" path retains a wsl-side fd or process-group reference
REM that keeps wsl.exe waiting even after the install's main process exits.
REM
REM v1.1.21: stop waiting for wsl.exe. Detach the install entirely:
REM `( ... ) </dev/null >/dev/null 2>&1 & disown` runs the install in a
REM backgrounded subshell whose stdin/stdout/stderr are all closed before
REM `& disown` removes it from the outer bash's job table. The outer
REM `bash -c` has nothing left to wait for, exits, wsl.exe returns to cmd
REM in <1s. The subshell continues running detached; when the install
REM finishes (timeout or natural), it writes its exit code to
REM /tmp/kivun-install-rc. cmd polls every 5s for that marker file —
REM there's no synchronous wsl.exe wait anywhere in this path so it
REM cannot hang regardless of what install.sh forks.
echo Installing Claude Code in Ubuntu (max 10 min)...
REM v1.1.23: ship the install runner as a static script + setsid -f to
REM fully detach. v1.1.21/v1.1.22's inline `( ... ) & disown` returned
REM 0 from wsl but the detached subshell never ran — WSL's interop relay
REM kills its cgroup descendants when wsl.exe exits, and `& disown` only
REM tells the bash job table not to send SIGHUP, it doesn't escape the
REM cgroup. `setsid -f` forks AND creates a NEW session — the install
REM becomes a session leader, fully orphaned from wsl.exe's session.
REM CI run 25015901486 confirmed v1.1.22 with `& disown` left
REM /root/.local/bin/claude absent (install never executed).
REM
REM v1.1.22 also revealed a wsl.exe 2.6.x quirk: `< nul > nul 2>&1`
REM is rejected with "ERROR: Input redirection is not supported"
REM (only `< nul >> file 2>&1` works, not `< nul > nul 2>&1`).
REM v1.1.23 dodges by NOT using `< nul` at all on the new wsl calls —
REM bash inherits launcher's stdin (launcher_input.txt or cmd console),
REM but the inner commands (setsid + script, test -f) don't read stdin
REM so it doesn't matter.

REM Compute install dir's WSL path locally (the global INST_WSL is set
REM later, after :claude_present). Strip trailing backslash from %~dp0
REM before wslpath — wslpath returns "." for paths ending in `\`.
set "_INST_DIR=%~dp0"
if "%_INST_DIR:~-1%"=="\" set "_INST_DIR=%_INST_DIR:~0,-1%"
for /f "delims=" %%i in ('wsl -d %DISTRO% wslpath -a "%_INST_DIR%" 2^>nul') do set "_INST_WSL=%%i"
if "%_INST_WSL%"=="" call :WIN_TO_WSL_PATH "%_INST_DIR%" _INST_WSL
if not "%_INST_WSL:~-1%"=="/" set "_INST_WSL=%_INST_WSL%/"
call :LOG "INFO - Install dir WSL path: %_INST_WSL%"

REM v1.4.36: strip CRLF from the install script BEFORE running it. This is
REM the FIRST-install path (Claude missing) and runs before the main launch
REM block's line-ending fix, so a CRLF-shipped kivun-install-claude.sh would
REM otherwise fail with bash's "No such file or directory" (exit 127).
wsl -d %DISTRO% -- sed -i "s/\r$//" "%_INST_WSL%kivun-install-claude.sh" >> "%LOG_FILE%" 2>&1

REM v1.1.31: SYNCHRONOUS install via `setsid -w`. v1.1.21–v1.1.30 tried
REM backgrounded install + cmd-side polling — every cmd-side sleep
REM mechanism hung in the `start /B`-detached context (timeout, ping,
REM wsl-sleep, waitfor, even pure-cmd `for /L`).
REM
REM v1.1.32: `-w` flag is critical. v1.1.31 used `setsid bash <script>`
REM (no flags), which by default does NOT wait for the child program —
REM setsid just creates a new session and exec's, returning immediately.
REM CI run 25020006926 confirmed: install.sh "returned" exit 0 in
REM 230ms, but /root/.local/bin/claude was absent (install hadn't
REM actually run). `-w` (`--wait`) makes setsid wait for the child and
REM propagate its exit code.
REM
REM `setsid -w` runs the install in a new session AND waits for it.
REM install.sh's forked daemons inherit the new session, so they don't
REM keep wsl.exe alive after install completes. wsl.exe sees setsid
REM exit, returns. ERRORLEVEL captures install.sh exit code.
wsl -d %DISTRO% -- setsid -w bash "%_INST_WSL%kivun-install-claude.sh" >> "%LOG_FILE%" 2>&1
set "INSTALL_RC=%ERRORLEVEL%"

:_install_after
call :LOG "INFO - install.sh returned exit code %INSTALL_RC%"
if "%INSTALL_RC%"=="124" call :LOG "WARNING - install.sh hit 600s timeout"
if not "%INSTALL_RC%"=="0" call :_NPM_FALLBACK
REM Verify by checking the three known install locations directly.
REM Earlier attempts used `PATH=$HOME/.local/bin:$PATH command -v claude`
REM which seemed cleaner, but on Windows-WSL the inherited $PATH contains
REM Windows paths like `/mnt/c/Program Files (x86)/sbt/bin` with literal
REM `(` and `)`. Bash word-splits the unquoted assignment value, hits
REM the `(` as a subshell-open token, and dies with a syntax error.
REM Listing absolute paths sidesteps PATH entirely.
wsl -d %DISTRO% -- bash -c "test -x $HOME/.local/bin/claude || test -x /usr/local/bin/claude || test -x /usr/bin/claude" < nul >> "%LOG_FILE%" 2>&1
if %ERRORLEVEL% NEQ 0 goto :_install_failed
REM Log the installed version so future bug reports include it.
REM Same constraint: do not lean on $PATH expansion. Try the user-local
REM install first; on failure fall back to whatever PATH lookup yields.
wsl -d %DISTRO% -- bash -lc "$HOME/.local/bin/claude --version 2>/dev/null || claude --version 2>/dev/null" < nul > "%TEMP%\kivun-claude-version.txt" 2>&1
for /f "delims=" %%v in ('type "%TEMP%\kivun-claude-version.txt" 2^>nul') do call :LOG "INFO - Claude version: %%v"
del "%TEMP%\kivun-claude-version.txt" 2>nul
call :LOG "SUCCESS - Claude Code installed in WSL"
echo   Claude: OK
set "CLAUDE_IN_WSL=1"
exit /b

:_decline_install
call :LOG "INFO - User declined Claude auto-install"
exit /b

:_NPM_FALLBACK
call :LOG "WARNING - Official installer failed, trying npm fallback"
echo Official installer failed, trying npm fallback (~2-3 min)...
wsl -d %DISTRO% -u root -- bash -c "apt-get install -y -qq nodejs npm && npm install -g @anthropic-ai/claude-code >> /tmp/kivun-claude.log 2>&1"
exit /b

:_install_failed
call :LOG "ERROR - Claude auto-install failed"
echo Claude install failed. See: wsl -d %DISTRO% -- cat /tmp/kivun-claude.log
exit /b

:no_claude_exit
REM v1.1.1 - clean exit when Claude is missing and either the install
REM was declined or it failed. Surface the real manual install command
REM (curl, matching installer NSI and Anthropic's current install docs),
REM not the deprecated `npm install -g` that the old error message used.
echo.
echo ========================================
echo   Claude Code is required but not installed in Ubuntu.
echo   Install manually:
echo     wsl -d %DISTRO% -- bash -lc "curl -fsSL https://claude.ai/install.sh ^| bash"
echo   Then re-run Kivun Terminal.
echo   NOTE: Windows-side Claude Code does NOT work here.
echo ========================================
call :LOG "EXIT - No Claude in WSL, user must install manually"
if not defined KIVUN_HIDDEN pause
exit /b 2

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
