; Kivun Terminal v1.4.25 - Professional Installer
; WSL + Ubuntu + Konsole launcher for Claude Code with full RTL/BiDi support.
; Encoding: UTF-8

Unicode True

!define PRODUCT_NAME "Kivun Terminal"
!define PRODUCT_VERSION "1.4.25"
!define PRODUCT_PUBLISHER "Noam Brand"
!define PRODUCT_WEB_SITE "https://github.com/noambrand/kivun-terminal-wsl"
!define PRODUCT_DESCRIPTION "WSL+Konsole launcher for Claude Code with RTL/BiDi support"
!define INSTALL_DIR "$LOCALAPPDATA\Kivun-WSL"

!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "FileFunc.nsh"
!include "WinMessages.nsh"

; SECURITY (#10): this is a PER-USER install to $LOCALAPPDATA\Kivun-WSL
; — nothing is written to Program Files, HKLM, or other system locations.
; Running as `admin` under over-the-shoulder UAC would land HKCU writes
; and $LOCALAPPDATA paths in the elevating admin's hive, not the
; invoking user's. Run as `user` and reject the install if `wsl --install`
; (which needs admin) is required, with a clear message telling the user
; to run that step from an admin PowerShell first.
RequestExecutionLevel user

Name "${PRODUCT_NAME}"
OutFile "Kivun_Terminal_Setup.exe"
InstallDir "${INSTALL_DIR}"
ShowInstDetails show
ShowUnInstDetails show

VIProductVersion "1.4.25.0"
VIAddVersionKey "ProductName" "${PRODUCT_NAME}"
VIAddVersionKey "ProductVersion" "${PRODUCT_VERSION}"
VIAddVersionKey "CompanyName" "${PRODUCT_PUBLISHER}"
VIAddVersionKey "FileDescription" "${PRODUCT_DESCRIPTION}"
VIAddVersionKey "FileVersion" "1.4.25.0"
VIAddVersionKey "LegalCopyright" "(C) 2026 ${PRODUCT_PUBLISHER}"

!define MUI_ABORTWARNING
!define MUI_ICON "kivun_icon.ico"
!define MUI_UNICON "kivun_icon.ico"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP_NOSTRETCH
!define MUI_WELCOMEFINISHPAGE_BITMAP_NOSTRETCH

!define MUI_WELCOMEPAGE_TITLE "Welcome to ${PRODUCT_NAME} v${PRODUCT_VERSION}"
!define MUI_WELCOMEPAGE_TEXT "This installer will set up ${PRODUCT_NAME} on your computer.$\r$\n$\r$\n${PRODUCT_DESCRIPTION}$\r$\n$\r$\nWhat will be installed:$\r$\n  - WSL2 + Ubuntu (if missing)$\r$\n  - Konsole terminal emulator (inside Ubuntu)$\r$\n  - wmctrl + xdotool (window management)$\r$\n  - Claude Code CLI (inside Ubuntu)$\r$\n  - VcXsrv X Server (optional, enables Alt+Shift keyboard switching)$\r$\n$\r$\nFeatures:$\r$\n  - Real RTL/BiDi text rendering (Hebrew, Arabic, Persian, Urdu, etc.)$\r$\n  - Light blue terminal color scheme$\r$\n  - Desktop shortcut + right-click folder integration$\r$\n  - 11 supported RTL languages$\r$\n$\r$\nNote: If WSL is not yet installed, Windows may require a reboot.$\r$\n$\r$\nClick Next to continue."
!insertmacro MUI_PAGE_WELCOME

!insertmacro MUI_PAGE_LICENSE "..\LICENSE"
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES

!define MUI_FINISHPAGE_TITLE "${PRODUCT_NAME} Installation Complete!"
!define MUI_FINISHPAGE_TEXT "${PRODUCT_NAME} v${PRODUCT_VERSION} has been installed successfully.$\r$\n$\r$\nLaunch it from the desktop shortcut or right-click any folder and choose $\"Open with Kivun Terminal$\".$\r$\n$\r$\nYou will need a Claude Pro/Max subscription or an Anthropic API key.$\r$\nGet one at: https://console.anthropic.com/$\r$\n$\r$\nTo test it works: launch Kivun Terminal and send Claude a message. If anything fails, open $\"Kivun Diagnostics$\" from the Start Menu and email the report to noambbb@gmail.com."
!define MUI_FINISHPAGE_RUN "$INSTDIR\KivunTerminal.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Launch Kivun Terminal now"
!define MUI_FINISHPAGE_RUN_NOTCHECKED
!define MUI_FINISHPAGE_SHOWREADME "$INSTDIR\README.md"
!define MUI_FINISHPAGE_SHOWREADME_TEXT "View Quick Start Guide"
!define MUI_FINISHPAGE_SHOWREADME_NOTCHECKED
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

; =================================================================
; INSTALL LOGGING (v1.4.15)
; Previously the installer wrote NO log to the Windows filesystem, so a
; failure in the WSL section (e.g. "WSL not installed") left the user with
; only a transient MessageBox and nothing to send to support. The apt steps
; log inside WSL (/tmp/kivun-*.log) but those don't exist until WSL works.
; Mirror the launcher's logging (payload/kivun-terminal.bat writes
; %LOCALAPPDATA%\Kivun-WSL\LAUNCH_LOG.txt) on the installer side.
; =================================================================
Var LOGFILE

!macro KLOG TEXT
  Push $R8
  FileOpen $R8 "$LOGFILE" a
  FileSeek $R8 0 END
  FileWrite $R8 "${TEXT}$\r$\n"
  FileClose $R8
  Pop $R8
!macroend

Function .onInit
  ; Default context is the invoking user; set explicitly so $LOCALAPPDATA
  ; resolves to the real user's profile even under over-the-shoulder UAC.
  SetShellVarContext current
  StrCpy $LOGFILE "$LOCALAPPDATA\Kivun-WSL\install-log.txt"
  ; Create the log dir BEFORE any section can Abort. The WSL section can
  ; abort at its first probe, and Core's CreateDirectory ran too late to
  ; capture that failure.
  CreateDirectory "$LOCALAPPDATA\Kivun-WSL"
  !insertmacro KLOG "=== Kivun Terminal v${PRODUCT_VERSION} install started ==="
FunctionEnd

; =================================================================
; VIRTUALIZATION PRE-FLIGHT (v1.4.19)
; WSL2 runs Linux inside a lightweight Hyper-V utility VM, which cannot start
; unless hardware virtualization (Intel VT-x / AMD-V) is ENABLED in the PC's
; firmware (BIOS/UEFI). On a real user PC (Win10 Home, a 2018 Lenovo) this was
; OFF: `wsl --install` succeeded and asked for a reboot, but after the reboot
; every distro boot failed because the utility VM could not start — so the
; installer kept asking to reboot and re-run, forever. No software can flip
; this firmware switch; only the user can, in BIOS/UEFI setup. So detect it up
; front and tell the user, in plain language, exactly what to do.
;
; Detection is locale-independent: every decision comes from findstr EXIT CODES
; on wmic's non-localized TRUE/FALSE output. We deliberately do NOT parse
; localized text, nor wsl.exe's UTF-16 output (which findstr can't read).
;   Win32_Processor.VirtualizationFirmwareEnabled = FALSE -> firmware VT is off
;   Win32_ComputerSystem.HypervisorPresent        = TRUE  -> a hypervisor is
;     already running, so VT is really ON even if the line above reads FALSE
; Treat VT as OFF only when firmware VT is explicitly FALSE AND no hypervisor
; is present. If wmic is absent (some Win11 24H2+) neither check matches and we
; simply proceed — the install continues rather than false-blocking.
; =================================================================
Function CheckVirtualization
  ; Output: $R5 = "OFF" when firmware virtualization is disabled, else "OK".
  Push $0
  Push $1
  StrCpy $R5 "OK"
  nsExec::Exec 'cmd /c wmic path Win32_Processor get VirtualizationFirmwareEnabled /value 2>nul | findstr /i /c:=FALSE >nul'
  Pop $0
  nsExec::Exec 'cmd /c wmic path Win32_ComputerSystem get HypervisorPresent /value 2>nul | findstr /i /c:=TRUE >nul'
  Pop $1
  ${If} $0 == 0
  ${AndIf} $1 != 0
    StrCpy $R5 "OFF"
  ${EndIf}
  Pop $1
  Pop $0
FunctionEnd

Function ShowVirtualizationHelp
  MessageBox MB_ICONEXCLAMATION|MB_OK "Kivun Terminal (WSL) can't finish because your PC's hardware $\"virtualization$\" setting is turned OFF.$\r$\n$\r$\nWSL runs Linux inside a small virtual machine, and Windows cannot start that virtual machine until virtualization is enabled in your PC's firmware (BIOS/UEFI). No app — including this installer — can change that setting; only you can. It takes about 2 minutes and is a one-time change.$\r$\n$\r$\nHOW TO TURN IT ON:$\r$\n1. Save your work and restart the PC.$\r$\n2. As it powers on, press the BIOS/Setup key repeatedly:$\r$\n        Dell / ASUS / Acer  →  F2$\r$\n        Lenovo  →  F1, F2, or the Novo button$\r$\n        HP  →  Esc, then F10$\r$\n        Other / desktops  →  Del (or F2)$\r$\n3. Find a setting named $\"Virtualization$\", $\"Intel Virtual Technology$\" / $\"VT-x$\", or $\"SVM Mode$\" (AMD), and set it to Enabled.$\r$\n4. Save and exit (usually F10) and let Windows start.$\r$\n5. Run this Kivun Terminal installer again — it continues automatically.$\r$\n$\r$\nNeed help? Open $\"Kivun Diagnostics$\" from the Start Menu and email the report (Kivun-Report.txt, saved to your Desktop) to noambbb@gmail.com.$\r$\n$\r$\nA diagnostic log was also saved to:$\r$\n$LOGFILE"
FunctionEnd

; =================================================================
; SECTIONS
; =================================================================

Section "Core Files" SEC_CORE
  SectionIn RO
  SetOutPath "$INSTDIR"

  ; Ensure HKCU and shell folders (Desktop, Start Menu) refer to the
  ; real user, not the elevated admin - matters when UAC elevates to a
  ; different account.
  SetShellVarContext current

  File "..\payload\kivun-terminal.bat"
  ; Native no-console-flash launcher (thin hidden shell over the .bat).
  ; Built by launcher\build.bat - CI (build-windows.yml) runs it before
  ; makensis; for a local installer build run it manually first.
  File "..\launcher\out\KivunTerminal.exe"
  File "..\payload\kivun-launch.sh"
  File "..\payload\kivun-direct.sh"
  File "..\payload\kivun-install-claude.sh"
  File "..\payload\kivun.xlaunch"
  File "..\payload\statusline.mjs"
  File "..\payload\configure-statusline.js"
  File "..\payload\folder-picker.wsf"
  File "..\payload\folder-picker.hta"
  ; Window-icon override for VcXsrv (which ignores Konsole's empty icon
  ; and shows its own X). kivun-set-icon.py reads kivun-icon.png and
  ; writes _NET_WM_ICON via python-xlib. See payload/kivun-set-icon.py.
  File "..\payload\kivun-set-icon.py"
  File "..\payload\kivun-icon.png"
  ; Kivun Diagnostics: a user-runnable report collector (Start Menu shortcut
  ; created below). Installed here in Core so it is present even if a later
  ; section aborts (e.g. virtualization off) — the user can still produce and
  ; send a good report. See payload/kivun-diagnostics.cmd.
  File "..\payload\kivun-diagnostics.cmd"
  ; Offline / antivirus-safe WSL+Ubuntu installer, used when the normal online
  ; `wsl --install` is blocked (e.g. corporate McAfee Web Protection). Installed
  ; in Core so SEC_WSL's failure messages can point the user to it on disk. See
  ; offline/README.md.
  File "..\offline\offline-install.cmd"
  ; Ensures a non-root Ubuntu user exists (Claude won't run as root). Run by
  ; SEC_WSL at install time and by the launcher as a self-heal. See .sh header.
  File "..\payload\kivun-ensure-user.sh"
  File "kivun_icon.ico"
  File "..\VERSION"
  File "..\docs\README.md"
  File "..\docs\README_INSTALLATION.md"
  File "..\docs\SECURITY.txt"
  File "..\docs\CREDENTIALS.txt"
  File "..\docs\TROUBLESHOOTING.md"

  ; config.txt: only install if it doesn't already exist, so users don't
  ; lose their edits on reinstall/upgrade.
  ${IfNot} ${FileExists} "$INSTDIR\config.txt"
    File "..\payload\config.txt"
  ${Else}
    DetailPrint "Preserving existing config.txt (user edits kept)"
  ${EndIf}

  ; BiDi wrapper bundle — source files only (no node_modules). npm install
  ; --production runs on first enable inside WSL; see payload/kivun-launch.sh
  ; deploy_bidi_wrapper(). Wrapper is off by default via config.txt in
  ; v1.1.0 — ships installed but dormant until the user flips
  ; KIVUN_BIDI_WRAPPER=on.
  SetOutPath "$INSTDIR"
  File /r /x node_modules /x .git "..\kivun-claude-bidi"
  DetailPrint "Installed BiDi wrapper source (enable via KIVUN_BIDI_WRAPPER=on in config.txt)"

  ; Log directory
  CreateDirectory "$LOCALAPPDATA\Kivun-WSL"

  ; Uninstaller
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  ; Registry: Add/Remove Programs entry
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\KivunTerminal" "DisplayName" "${PRODUCT_NAME} v${PRODUCT_VERSION}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\KivunTerminal" "DisplayVersion" "${PRODUCT_VERSION}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\KivunTerminal" "Publisher" "${PRODUCT_PUBLISHER}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\KivunTerminal" "UninstallString" "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\KivunTerminal" "DisplayIcon" "$INSTDIR\kivun_icon.ico"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\KivunTerminal" "URLInfoAbout" "${PRODUCT_WEB_SITE}"
SectionEnd

; Shortcuts + right-click are created HERE — immediately after Core and
; BEFORE the WSL/Konsole/Claude sections. Those later sections can Abort
; (apt failure, ~300MB Konsole download, user Cancel), and NSIS stops the
; whole install on Abort. When these sections lived at the end (pre-v1.2.5
; ordering), an abort meant the desktop shortcut and right-click menu were
; never created — the user's exact symptom. They only touch local files
; ($INSTDIR\kivun-terminal.bat + icon, both written by Core above) and
; HKCU, so they can't fail and are safe to run early.
Section "Desktop Shortcut" SEC_SHORTCUT
  ; SetShellVarContext current was set in Core and persists across sections,
  ; so $DESKTOP / $SMPROGRAMS resolve to the invoking user's folders.
  ; Shortcuts target the native launcher (no console flash). SW_SHOWNORMAL:
  ; there is no window to minimize anymore - MINIMIZED was only ever a
  ; mitigation for the cmd flash the exe now eliminates.
  CreateShortcut "$DESKTOP\Kivun Terminal.lnk" "$INSTDIR\KivunTerminal.exe" "" "$INSTDIR\kivun_icon.ico" 0 SW_SHOWNORMAL "" "Launch Kivun Terminal"
  CreateShortcut "$SMPROGRAMS\Kivun Terminal.lnk" "$INSTDIR\KivunTerminal.exe" "" "$INSTDIR\kivun_icon.ico" 0 SW_SHOWNORMAL "" "Launch Kivun Terminal"
  ; Visible-console fallback: same .bat, real window. Diagnostic aid, and
  ; the escape hatch if an antivirus ever quarantines the unsigned exe.
  CreateShortcut "$SMPROGRAMS\Kivun Terminal (console).lnk" "$INSTDIR\kivun-terminal.bat" "" "$INSTDIR\kivun_icon.ico" 0 SW_SHOWNORMAL "" "Launch with a visible console (diagnostics)"
  ; Diagnostics/report shortcut — visible console (SW_SHOWNORMAL) so the user
  ; sees the "report saved — email it" message and can send us good data.
  CreateShortcut "$SMPROGRAMS\Kivun Diagnostics.lnk" "$INSTDIR\kivun-diagnostics.cmd" "" "$INSTDIR\kivun_icon.ico" 0 SW_SHOWNORMAL "" "Collect a Kivun problem report to send for help"
SectionEnd

; Default-ON (no /o). The welcome page advertises "right-click folder
; integration" as a headline feature; shipping it unchecked meant most
; users never got the "Open with Kivun Terminal" menu they were promised.
Section "Right-Click Menu Integration" SEC_RCLICK
  ; Add "Open with Kivun Terminal" to folder context menu
  WriteRegStr HKCU "Software\Classes\Directory\shell\KivunTerminal" "" "Open with Kivun Terminal"
  WriteRegStr HKCU "Software\Classes\Directory\shell\KivunTerminal" "Icon" "$INSTDIR\kivun_icon.ico"
  WriteRegStr HKCU "Software\Classes\Directory\shell\KivunTerminal\command" "" '"$INSTDIR\KivunTerminal.exe" "%1"'

  ; Add to background of folder (right-click inside a folder)
  WriteRegStr HKCU "Software\Classes\Directory\Background\shell\KivunTerminal" "" "Open with Kivun Terminal"
  WriteRegStr HKCU "Software\Classes\Directory\Background\shell\KivunTerminal" "Icon" "$INSTDIR\kivun_icon.ico"
  WriteRegStr HKCU "Software\Classes\Directory\Background\shell\KivunTerminal\command" "" '"$INSTDIR\KivunTerminal.exe" "%V"'
SectionEnd

Section "WSL2 + Ubuntu" SEC_WSL
  SectionIn RO

  ; Virtualization (firmware) pre-flight — see CheckVirtualization above. If
  ; VT is off, WSL2 can never boot, so explain the one-time BIOS fix now rather
  ; than letting the user fall into an endless install/reboot loop.
  DetailPrint "Checking hardware virtualization (BIOS/UEFI)..."
  Call CheckVirtualization
  ${If} $R5 == "OFF"
    !insertmacro KLOG "Firmware virtualization is DISABLED -> telling user how to enable VT in BIOS"
    Call ShowVirtualizationHelp
    Abort "Virtualization disabled in firmware — enable it in BIOS, then re-run."
  ${EndIf}
  !insertmacro KLOG "Virtualization check result: $R5"

  DetailPrint "Checking WSL..."
  ; Availability probe. The bare `wsl` form returns exit=error from this 32-bit
  ; installer — wsl.exe is NOT reliably excluded from WOW64 redirection (an old
  ; comment here wrongly claimed it was). A real-PC log showed `wsl --version
  ; exit=error` on EVERY run, INCLUDING after a successful install + reboot, so
  ; the installer never saw the WSL it had just installed and re-installed it on
  ; each launch — an endless reinstall/reboot loop. Resolve wsl.exe via the
  ; Sysnative alias (the real 64-bit System32 seen from a 32-bit process), the
  ; same path the elevated install step uses.
  StrCpy $R7 "$WINDIR\System32\wsl.exe"
  ${If} ${FileExists} "$WINDIR\Sysnative\wsl.exe"
    StrCpy $R7 "$WINDIR\Sysnative\wsl.exe"
  ${EndIf}
  ; WSL counts as present if EITHER `--status` or `--version` runs cleanly
  ; (exit 0). Different WSL builds expose different info subcommands, and a
  ; freshly `wsl --install`ed system must never read as "missing" (that was the
  ; loop). Both are non-interactive subcommands, so the pre-install stub returns
  ; promptly instead of hanging on the bare-`wsl` "press any key" prompt.
  nsExec::ExecToStack '"$R7" --status'
  Pop $0
  Pop $1
  !insertmacro KLOG "wsl --status (via $R7) exit=$0"
  !insertmacro KLOG "$1"
  ${If} $0 != 0
    nsExec::ExecToStack '"$R7" --version'
    Pop $0
    Pop $1
    !insertmacro KLOG "wsl --version (via $R7) exit=$0"
    !insertmacro KLOG "$1"
  ${EndIf}
  ${If} $0 != 0
    ; WSL is missing. Installing it requires admin + a reboot — a Windows
    ; requirement, there is no per-user API for it. We keep THIS installer
    ; per-user (so $LOCALAPPDATA / HKCU writes stay correct, per SECURITY #10)
    ; and elevate ONLY Microsoft's signed wsl.exe for the one admin step, via
    ; a single UAC prompt. No PowerShell, no cmd wrapper. WSL needs a reboot
    ; before Ubuntu/Konsole/Claude can install, so afterwards we ask the user
    ; to reboot and re-run.
    !insertmacro KLOG "WSL not available -> offering elevated wsl --install"
    MessageBox MB_ICONINFORMATION|MB_OKCANCEL "Kivun Terminal needs Windows Subsystem for Linux (WSL), which isn't installed yet.$\r$\n$\r$\nWindows will now ask for administrator permission so it can install WSL for you (Microsoft's built-in 'wsl --install'). After it finishes you'll need to REBOOT and run this installer again.$\r$\n$\r$\nClick OK to install WSL now, or Cancel to do it yourself later." IDOK do_wsl_install
      ; Cancel -> the user prefers to do it themselves later.
      !insertmacro KLOG "User cancelled automatic WSL install"
      MessageBox MB_ICONINFORMATION|MB_OK "No problem. To install WSL yourself later:$\r$\n$\r$\nEasiest: RIGHT-CLICK this installer and choose 'Run as administrator', then run it again, it can install WSL for you.$\r$\n$\r$\nOr do it manually:$\r$\n1. Open Terminal as Administrator (right-click Start > Terminal (Admin))$\r$\n2. Run:   wsl --install$\r$\n3. Reboot, then run this installer again$\r$\n$\r$\nA diagnostic log was saved to:$\r$\n$LOGFILE"
      Abort "WSL not installed — user opted to do it manually."
    do_wsl_install:
      ; Elevate ONLY Microsoft's signed wsl.exe (no PowerShell / cmd wrapper).
      ; WOW64: this installer is 32-bit, and contrary to a long-standing comment
      ; here, wsl.exe is NOT reliably excluded from WOW64 file redirection. So
      ; "$WINDIR\System32\wsl.exe" gets redirected to SysWOW64 — where the WSL
      ; stub does NOT exist — and ShellExecuteEx fails to start it. Real-PC log:
      ; `Elevated wsl --install did not start`, even when the user ran as admin
      ; (it was never a permissions problem). Reach the genuine 64-bit System32
      ; via the Sysnative alias, which exists only for 32-bit processes on 64-bit
      ; Windows; fall back to System32 on 32-bit Windows where it doesn't exist.
      StrCpy $R9 "$WINDIR\System32\wsl.exe"
      ${If} ${FileExists} "$WINDIR\Sysnative\wsl.exe"
        StrCpy $R9 "$WINDIR\Sysnative\wsl.exe"
      ${EndIf}
      !insertmacro KLOG "Launching elevated: $R9 --install"
      ClearErrors
      ExecShellWait "runas" "$R9" "--install"
      ${If} ${Errors}
        ; ShellExecuteEx failed to start — UAC declined, or elevation blocked
        ; by org policy. Fall back to manual instructions; never pretend.
        !insertmacro KLOG "Elevated wsl --install did not start (UAC declined or blocked by policy)"
        MessageBox MB_ICONINFORMATION|MB_OK "WSL installation didn't start. The administrator step was blocked, or no prompt appeared.$\r$\n$\r$\nEasiest fix: close this window, then RIGHT-CLICK this installer and choose 'Run as administrator', and run it again. That usually completes the WSL install in one go. Afterwards, reboot and run it once more to finish.$\r$\n$\r$\nIf 'Run as administrator' asks for a password you don't have, this is a locked-down work computer: ask your IT department to run  wsl --install  once, then reboot.$\r$\n$\r$\nIf antivirus blocks the WSL download, install OFFLINE (no downloads): run$\r$\n  $INSTDIR\offline-install.cmd$\r$\nas administrator, with the two official files beside it. Guide:$\r$\nhttps://github.com/noambrand/kivun-terminal-wsl/tree/main/offline$\r$\n$\r$\nA diagnostic log was saved to:$\r$\n$LOGFILE"
        Abort "WSL install not started."
      ${EndIf}
      !insertmacro KLOG "Elevated wsl --install finished; reboot required"
      MessageBox MB_ICONINFORMATION|MB_OK "WSL has been installed.$\r$\n$\r$\nPlease REBOOT your computer, then run this Kivun Terminal installer again to finish setting up Ubuntu, Konsole, and Claude Code.$\r$\n$\r$\nYou can close this installer now."
      Abort "WSL installed — reboot and re-run this installer."
  ${EndIf}
  !insertmacro KLOG "WSL available — continuing install"

  ; Best-effort set default version 2 — on modern Windows 11 this works
  ; as user; on older systems it may require admin, in which case we log
  ; and continue (user can run it themselves from admin shell if needed).
  DetailPrint "Setting WSL default version to 2 (best-effort)..."
  nsExec::Exec 'wsl --set-default-version 2'
  Pop $0
  ${If} $0 != 0
    DetailPrint "  Could not set WSL2 default (may need admin PowerShell: wsl --set-default-version 2). Continuing..."
  ${EndIf}

  DetailPrint "Checking Ubuntu distribution..."
  nsExec::Exec 'wsl -d Ubuntu -- echo OK'
  Pop $0
  ${If} $0 != 0
    DetailPrint "Installing Ubuntu distribution (no admin needed once WSL2 is up)..."
    nsExec::ExecToLog 'wsl --install -d Ubuntu --no-launch'
    Pop $0
    ${If} $0 != 0
      !insertmacro KLOG "Ubuntu install (wsl --install -d Ubuntu) failed exit=$0"
      MessageBox MB_ICONEXCLAMATION|MB_OK "Ubuntu installation failed.$\r$\n$\r$\nPlease try:$\r$\n1. Open Microsoft Store$\r$\n2. Search for 'Ubuntu'$\r$\n3. Install 'Ubuntu' (the latest LTS version)$\r$\n4. Run this installer again$\r$\n$\r$\nBlocked by antivirus? Install WSL + Ubuntu OFFLINE (no downloads): run$\r$\n  $INSTDIR\offline-install.cmd$\r$\nas administrator, after placing the two official files beside it. Step-by-step:$\r$\nhttps://github.com/noambrand/kivun-terminal-wsl/tree/main/offline$\r$\n$\r$\nA diagnostic log was saved to:$\r$\n$LOGFILE"
      Abort "Ubuntu installation failed."
    ${EndIf}
    DetailPrint "Waiting for Ubuntu to initialize..."
    Sleep 5000
  ${Else}
    DetailPrint "Ubuntu already installed."
    ; Attempt to ensure Ubuntu is on WSL2. Use nsExec::Exec (no log output)
    ; to suppress confusing wsl.exe messages when Ubuntu is already WSL2.
    DetailPrint "Ensuring Ubuntu uses WSL2..."
    nsExec::Exec 'wsl --set-version Ubuntu 2'
    Pop $0
    ${If} $0 == 0
      DetailPrint "Ubuntu converted to WSL2 successfully."
      Sleep 3000
    ${Else}
      ; Non-zero typically means "already on requested version" - this is fine.
      DetailPrint "Ubuntu is already on WSL2."
    ${EndIf}
  ${EndIf}

  ; Ensure a non-root user exists and is the WSL default (v1.4.22). Ubuntu from
  ; `wsl --install --no-launch` has ONLY root, and Claude Code refuses to run as
  ; root — which used to dead-end the launcher on a "create a user by hand"
  ; dialog. Pipe the helper in via stdin (type | bash -s) to dodge all
  ; NSIS/cmd/bash quoting of the sudoers parens; the .sh is LF via .gitattributes.
  ; Restart the distro so WSLg is owned by the new user and so Claude installs
  ; into the user's home (not /root) in the next section.
  DetailPrint "Ensuring a non-root Ubuntu user (Claude won't run as root)..."
  nsExec::ExecToLog 'cmd /c type "$INSTDIR\kivun-ensure-user.sh" | wsl -d Ubuntu --user root -- bash -s'
  Pop $0
  !insertmacro KLOG "ensure non-root user exit=$0"
  nsExec::Exec 'wsl --terminate Ubuntu'
SectionEnd

Section "Konsole + window tools" SEC_KONSOLE
  SectionIn RO

  ; ------------------------------------------------------------
  ; IMPORTANT: Run as root (-u root) to avoid sudo TTY password hang.
  ; Redirect output to a log file so nsExec doesn't deadlock on buffer.
  ; Split into small steps so Cancel button is responsive between them.
  ; ------------------------------------------------------------

  DetailPrint "[1/7] Updating package lists (~30-60 seconds)..."
  nsExec::Exec 'wsl -d Ubuntu -u root -- bash -c "apt-get update -qq -y > /tmp/kivun-apt.log 2>&1"'
  Pop $0
  ${If} $0 != 0
    MessageBox MB_ICONEXCLAMATION|MB_OKCANCEL "apt-get update failed (code $0).$\r$\n$\r$\nMost common cause: Ubuntu has no internet access.$\r$\n$\r$\nLog: wsl -d Ubuntu -- cat /tmp/kivun-apt.log$\r$\n$\r$\nClick OK to continue anyway, or Cancel to abort." IDOK konsole_ok_1
      Abort "Cancelled by user."
    konsole_ok_1:
  ${EndIf}

  DetailPrint "[2/7] Installing wmctrl (~20-40 seconds)..."
  nsExec::Exec 'wsl -d Ubuntu -u root -- bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq wmctrl >> /tmp/kivun-apt.log 2>&1"'
  Pop $0
  ${If} $0 != 0
    MessageBox MB_ICONEXCLAMATION|MB_OKCANCEL "Failed to install wmctrl (code $0).$\r$\n$\r$\nClick OK to continue or Cancel to abort." IDOK konsole_ok_2
      Abort "Cancelled by user."
    konsole_ok_2:
  ${EndIf}

  DetailPrint "[3/7] Installing xdotool (~20-40 seconds)..."
  nsExec::Exec 'wsl -d Ubuntu -u root -- bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq xdotool >> /tmp/kivun-apt.log 2>&1"'
  Pop $0
  ${If} $0 != 0
    MessageBox MB_ICONEXCLAMATION|MB_OKCANCEL "Failed to install xdotool (code $0).$\r$\n$\r$\nClick OK to continue or Cancel to abort." IDOK konsole_ok_3
      Abort "Cancelled by user."
    konsole_ok_3:
  ${EndIf}

  DetailPrint "[4/7] Installing x11-utils + x11-xserver-utils + color-emoji font (~40-60 seconds)..."
  nsExec::Exec 'wsl -d Ubuntu -u root -- bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq x11-utils x11-xserver-utils fonts-noto-color-emoji >> /tmp/kivun-apt.log 2>&1"'
  Pop $0
  ${If} $0 != 0
    MessageBox MB_ICONEXCLAMATION|MB_OKCANCEL "Failed to install x11-utils (code $0).$\r$\n$\r$\nClick OK to continue or Cancel to abort." IDOK konsole_ok_4
      Abort "Cancelled by user."
    konsole_ok_4:
  ${EndIf}

  DetailPrint "[5/7] Ensuring Node.js is available..."
  ; Node may already be installed by Claude's installer or an external
  ; package manager (e.g. nvm). apt-get install nodejs can fail with exit
  ; code 100 ("held broken packages") in that case. So: check first, only
  ; install via apt if truly missing.
  nsExec::Exec 'wsl -d Ubuntu -u root -- bash -c "command -v node >/dev/null 2>&1"'
  Pop $0
  ${If} $0 == 0
    DetailPrint "      Node already present, skipping apt install."
  ${Else}
    DetailPrint "      Node missing, installing nodejs + npm via apt..."
    nsExec::Exec 'wsl -d Ubuntu -u root -- bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq nodejs npm >> /tmp/kivun-apt.log 2>&1"'
    Pop $0
    ${If} $0 != 0
      MessageBox MB_ICONEXCLAMATION|MB_OKCANCEL "Failed to install Node.js + npm (code $0).$\r$\n$\r$\nThe statusline at the bottom of Claude Code TUI won't work without Node.$\r$\n$\r$\nLog: wsl -d Ubuntu -- cat /tmp/kivun-apt.log$\r$\n$\r$\nClick OK to continue (you can install manually later), or Cancel to abort." IDOK konsole_ok_node
        Abort "Cancelled by user."
      konsole_ok_node:
    ${EndIf}
  ${EndIf}

  DetailPrint "[6/7] Downloading Konsole + KDE dependencies..."
  DetailPrint "      (3-8 minutes. Downloads ~300MB of packages.)"
  DetailPrint "      The installer is working - please be patient."
  nsExec::Exec 'wsl -d Ubuntu -u root -- bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --download-only konsole >> /tmp/kivun-apt.log 2>&1"'
  Pop $0
  ${If} $0 != 0
    MessageBox MB_ICONEXCLAMATION|MB_OKCANCEL "Failed to download Konsole packages (code $0).$\r$\n$\r$\nLog: wsl -d Ubuntu -- cat /tmp/kivun-apt.log$\r$\n$\r$\nClick OK to continue or Cancel to abort." IDOK konsole_ok_5
      Abort "Cancelled by user."
    konsole_ok_5:
  ${EndIf}

  DetailPrint "[7/7] Unpacking and configuring Konsole (~2-4 minutes)..."
  nsExec::Exec 'wsl -d Ubuntu -u root -- bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq konsole >> /tmp/kivun-apt.log 2>&1"'
  Pop $0
  ${If} $0 != 0
    MessageBox MB_ICONEXCLAMATION|MB_OKCANCEL "Failed to install Konsole (code $0).$\r$\n$\r$\nLog: wsl -d Ubuntu -- cat /tmp/kivun-apt.log$\r$\n$\r$\nYou can retry later via:$\r$\n  wsl -d Ubuntu -u root -- apt-get install -y konsole$\r$\n$\r$\nClick OK to continue or Cancel to abort." IDOK konsole_ok_6
      Abort "Cancelled by user."
    konsole_ok_6:
  ${Else}
    DetailPrint "Konsole and window tools installed successfully."
  ${EndIf}
SectionEnd

Section "Claude Code CLI" SEC_CLAUDE
  SectionIn RO
  DetailPrint "Checking for Claude Code in Ubuntu..."
  ; Detect a NATIVE Linux claude only. WSL appends the Windows PATH, so a
  ; plain `command -v claude` matches a Windows npm install at
  ; /mnt/c/.../npm/claude — which made the installer skip the native
  ; install for any user who also has Claude on Windows, leaving the
  ; launcher to drive the Windows binary (TUI opens then dies). Rejecting
  ; /mnt/* paths mirrors resolve-claude-bin.js, which prefers native slots.
  nsExec::Exec 'wsl -d Ubuntu -- bash -lc "command -v claude | grep -q -v ^/mnt/"'
  Pop $0
  ${If} $0 != 0
    DetailPrint "Installing Claude Code CLI via official installer (~1-2 minutes)..."
    ; SECURITY (#7): download the installer to a file FIRST, then run it.
    ; `curl | bash` starts executing bytes as they arrive; a mid-download
    ; network drop leaves bash parsing a truncated script that can land
    ; the system in a half-configured state. Download-then-run also means
    ; if curl fails we can tell (via `[ -s file ]`), instead of tee
    ; returning success while curl silently died.
    ; Run as the DEFAULT WSL user (NOT root). The official installer drops
    ; claude in $HOME/.local/bin of whoever runs it — as root that's
    ; /root/.local/bin, which the normal launcher user cannot execute, so
    ; the native install was effectively invisible. install.sh needs no
    ; root (it writes only to the user's home), and this matches the
    ; launcher's own runtime install step in kivun-terminal.bat. Log all
    ; output to file so nsExec doesn't deadlock on pipe buffers.
    ; curl gets retries so a transient network blip (the common cause of the
    ; "install failed, run this by hand" dialog) auto-recovers instead of
    ; surfacing a manual-command MessageBox to the user. --retry-all-errors
    ; covers HTTP errors too, not just connection failures.
    nsExec::Exec 'wsl -d Ubuntu -- bash -lc "set -o pipefail; T=$(mktemp /tmp/claude-install-XXXXXX.sh) && curl -fsSL --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 30 -o \"$T\" https://claude.ai/install.sh > /tmp/kivun-claude.log 2>&1 && [ -s \"$T\" ] && bash \"$T\" >> /tmp/kivun-claude.log 2>&1; rm -f \"$T\""'
    Pop $0
    ${If} $0 != 0
      DetailPrint "Installer script failed, trying npm fallback (~2-3 minutes)..."
      nsExec::Exec 'wsl -d Ubuntu -u root -- bash -lc "apt-get install -y -qq nodejs npm && npm install -g @anthropic-ai/claude-code >> /tmp/kivun-claude.log 2>&1"'
      Pop $0
      ${If} $0 != 0
        MessageBox MB_ICONEXCLAMATION|MB_OKCANCEL "Claude Code CLI installation failed.$\r$\n$\r$\nLog: wsl -d Ubuntu -- cat /tmp/kivun-claude.log$\r$\n$\r$\nThis is usually a temporary network issue - clicking OK and re-running the installer often succeeds.$\r$\n$\r$\nIf it keeps failing, you can install it manually (in WSL):$\r$\n  T=$(mktemp) && curl -fsSL --retry 5 -o $T https://claude.ai/install.sh && [ -s $T ] && bash $T && rm -f $T$\r$\n$\r$\nStill stuck? Open $\"Kivun Diagnostics$\" from the Start Menu and email the report to noambbb@gmail.com.$\r$\n$\r$\nClick OK to continue, or Cancel to abort." IDOK claude_continue
          Abort "Installation cancelled by user."
        claude_continue:
      ${EndIf}
    ${Else}
      DetailPrint "Claude Code installed successfully."
    ${EndIf}
  ${Else}
    DetailPrint "Claude Code already installed, skipping."
  ${EndIf}
SectionEnd

Section /o "Open VcXsrv download page (optional, manual install)" SEC_VCXSRV
  ; Skip install if VcXsrv is already present in common locations.
  ; NOTE: NSIS is 32-bit so $PROGRAMFILES gets WOW64-redirected to
  ; "Program Files (x86)". Use $PROGRAMFILES64 for the real 64-bit path.
  ${If} ${FileExists} "$PROGRAMFILES64\VcXsrv\vcxsrv.exe"
    DetailPrint "VcXsrv already installed at $PROGRAMFILES64\VcXsrv - skipping."
    Goto vcxsrv_done
  ${EndIf}
  ${If} ${FileExists} "$PROGRAMFILES32\VcXsrv\vcxsrv.exe"
    DetailPrint "VcXsrv already installed at $PROGRAMFILES32\VcXsrv - skipping."
    Goto vcxsrv_done
  ${EndIf}
  ; Fallback: check registry for VcXsrv uninstall entry
  ReadRegStr $0 HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\VcXsrv is X server" "DisplayName"
  ${If} $0 != ""
    DetailPrint "VcXsrv detected via registry ($0) - skipping download."
    Goto vcxsrv_done
  ${EndIf}
  SetRegView 64
  ReadRegStr $0 HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\VcXsrv is X server" "DisplayName"
  SetRegView 32
  ${If} $0 != ""
    DetailPrint "VcXsrv detected via 64-bit registry ($0) - skipping download."
    Goto vcxsrv_done
  ${EndIf}

  ; SECURITY (#6): we intentionally do NOT download + silently-exec the
  ; VcXsrv installer from this NSIS script. The combination of (a) a
  ; curl-to-TEMP, (b) silent-exec of the downloaded binary, (c) under
  ; elevation — previously — (d) from an unsigned parent, is the exact
  ; cluster of heuristics that Microsoft Defender / SmartScreen flag as
  ; a dropper. It also means we'd be executing a binary whose SHA we
  ; can't pin (SourceForge "latest" URL changes per release). Instead:
  ; open the official VcXsrv page in the user's browser, let them
  ; download and install it themselves with full visibility.
  DetailPrint "Opening the VcXsrv download page in your browser..."
  ExecShell "open" "https://sourceforge.net/projects/vcxsrv/"
  MessageBox MB_ICONINFORMATION "VcXsrv was not found on this system.$\r$\n$\r$\nTo enable Alt+Shift keyboard-layout switching inside Konsole, install VcXsrv from the page that just opened, then set USE_VCXSRV=true in $INSTDIR\config.txt.$\r$\n$\r$\nThis step is optional — if you skip it, Kivun Terminal falls back to WSLg (Alt+Shift will not work but everything else does)."
  vcxsrv_done:
SectionEnd

; Section descriptions for components page
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_CORE}     "Launcher scripts, config, docs (required)."
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_WSL}      "Install WSL2 and Ubuntu if missing (required)."
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_KONSOLE}  "Install Konsole terminal and window tools inside Ubuntu (required)."
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_CLAUDE}   "Install Claude Code CLI inside Ubuntu (required)."
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_VCXSRV}   "Opens the VcXsrv download page in your browser. Install it manually to enable Alt+Shift keyboard switching. Skip if you don't need it."
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_SHORTCUT} "Desktop and Start Menu shortcuts."
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_RCLICK}   "Right-click any folder -> Open with Kivun Terminal."
!insertmacro MUI_FUNCTION_DESCRIPTION_END

; =================================================================
; UNINSTALLER
; =================================================================

Section "Uninstall"
  ; Match the install-time shell context so $DESKTOP / $SMPROGRAMS
  ; point at the same folders we wrote to.
  SetShellVarContext current

  ; Remove shortcuts. The "Edit Kivun Terminal Config.lnk" was created
  ; by v1.2.9 only and removed in v1.3.0 — uninstalling here cleans up
  ; for users who installed v1.2.9 and then upgraded.
  Delete "$DESKTOP\Kivun Terminal.lnk"
  Delete "$SMPROGRAMS\Kivun Terminal.lnk"
  Delete "$SMPROGRAMS\Kivun Terminal (console).lnk"
  Delete "$SMPROGRAMS\Kivun Diagnostics.lnk"
  Delete "$SMPROGRAMS\Edit Kivun Terminal Config.lnk"

  ; Remove registry entries
  DeleteRegKey HKCU "Software\Classes\Directory\shell\KivunTerminal"
  DeleteRegKey HKCU "Software\Classes\Directory\Background\shell\KivunTerminal"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\KivunTerminal"

  ; Remove installed files
  Delete "$INSTDIR\folder-picker.hta"
  Delete "$INSTDIR\kivun-diagnostics.cmd"
  Delete "$INSTDIR\kivun-ensure-user.sh"
  Delete "$INSTDIR\kivun-terminal.bat"
  Delete "$INSTDIR\KivunTerminal.exe"
  Delete "$INSTDIR\kivun-launch.sh"
  Delete "$INSTDIR\kivun-direct.sh"
  Delete "$INSTDIR\kivun-install-claude.sh"
  Delete "$INSTDIR\kivun-set-icon.py"
  Delete "$INSTDIR\kivun-icon.png"
  Delete "$INSTDIR\config.txt"
  Delete "$INSTDIR\kivun.xlaunch"
  Delete "$INSTDIR\VERSION"
  Delete "$INSTDIR\README.md"
  Delete "$INSTDIR\README_INSTALLATION.md"
  Delete "$INSTDIR\SECURITY.txt"
  Delete "$INSTDIR\CREDENTIALS.txt"
  Delete "$INSTDIR\TROUBLESHOOTING.md"
  Delete "$INSTDIR\kivun_icon.ico"
  Delete "$INSTDIR\Uninstall.exe"

  ; Remove BiDi wrapper bundle
  RMDir /r "$INSTDIR\kivun-claude-bidi"

  RMDir "$INSTDIR"

  ; NOTE: Deliberately do NOT uninstall WSL, Ubuntu, Konsole, or Claude Code.
  ; These are shared with other tools and removing them may break the user's system.
  ; Log directory is left intact for post-uninstall troubleshooting.

  MessageBox MB_ICONINFORMATION "Kivun Terminal has been uninstalled.$\r$\n$\r$\nWSL, Ubuntu, Konsole, and Claude Code were left intact.$\r$\nRemove them manually via 'wsl --unregister Ubuntu' if desired.$\r$\n$\r$\nLogs preserved at: $LOCALAPPDATA\Kivun-WSL"
SectionEnd
