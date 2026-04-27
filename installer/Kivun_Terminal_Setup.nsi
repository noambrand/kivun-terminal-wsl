; Kivun Terminal v1.1.24 - Professional Installer
; WSL + Ubuntu + Konsole launcher for Claude Code with full RTL/BiDi support.
; Encoding: UTF-8

Unicode True

!define PRODUCT_NAME "Kivun Terminal"
!define PRODUCT_VERSION "1.1.24"
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

VIProductVersion "1.1.1.0"
VIAddVersionKey "ProductName" "${PRODUCT_NAME}"
VIAddVersionKey "ProductVersion" "${PRODUCT_VERSION}"
VIAddVersionKey "CompanyName" "${PRODUCT_PUBLISHER}"
VIAddVersionKey "FileDescription" "${PRODUCT_DESCRIPTION}"
VIAddVersionKey "FileVersion" "1.1.1.0"
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
!define MUI_FINISHPAGE_TEXT "${PRODUCT_NAME} v${PRODUCT_VERSION} has been installed successfully.$\r$\n$\r$\nLaunch it from the desktop shortcut or right-click any folder and choose $\"Open with Kivun Terminal$\".$\r$\n$\r$\nYou will need a Claude Pro/Max subscription or an Anthropic API key.$\r$\nGet one at: https://console.anthropic.com/"
!define MUI_FINISHPAGE_RUN "$INSTDIR\kivun-terminal.bat"
!define MUI_FINISHPAGE_RUN_TEXT "Launch Kivun Terminal now"
!define MUI_FINISHPAGE_SHOWREADME "$INSTDIR\README.md"
!define MUI_FINISHPAGE_SHOWREADME_TEXT "View Quick Start Guide"
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

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
  File "..\payload\kivun-launch.sh"
  File "..\payload\kivun-direct.sh"
  File "..\payload\kivun-install-claude.sh"
  File "..\payload\kivun.xlaunch"
  File "..\payload\statusline.mjs"
  File "..\payload\configure-statusline.js"
  File "..\payload\folder-picker.wsf"
  ; Window-icon override for VcXsrv (which ignores Konsole's empty icon
  ; and shows its own X). kivun-set-icon.py reads kivun-icon.png and
  ; writes _NET_WM_ICON via python-xlib. See payload/kivun-set-icon.py.
  File "..\payload\kivun-set-icon.py"
  File "..\payload\kivun-icon.png"
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

Section "WSL2 + Ubuntu" SEC_WSL
  SectionIn RO
  DetailPrint "Checking WSL..."
  nsExec::Exec 'wsl --status'
  Pop $0
  ${If} $0 != 0
    ; SECURITY (#10): `wsl --install` requires admin. This installer runs
    ; as `user`. Rather than escalate the whole installer (which causes
    ; HKCU/LOCALAPPDATA-under-admin-hive bugs), we ask the user to do
    ; the one admin step themselves, then re-run us as themselves.
    MessageBox MB_ICONEXCLAMATION|MB_OK "WSL is not installed on this system.$\r$\n$\r$\nKivun Terminal installs to your user profile and does not need admin rights — but WSL installation does. Please:$\r$\n$\r$\n1. Close this installer$\r$\n2. Open PowerShell as Administrator (right-click Start > Terminal (Admin))$\r$\n3. Run:   wsl --install$\r$\n4. Reboot your computer$\r$\n5. Run this installer again (normal double-click, no admin needed)$\r$\n$\r$\nIf 'wsl --install' reports it is not recognized, you are on an older Windows build — see https://learn.microsoft.com/en-us/windows/wsl/install"
    Abort "WSL not installed — please install it first via admin PowerShell."
  ${EndIf}

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
      MessageBox MB_ICONEXCLAMATION|MB_OK "Ubuntu installation failed.$\r$\n$\r$\nPlease try:$\r$\n1. Open Microsoft Store$\r$\n2. Search for 'Ubuntu'$\r$\n3. Install 'Ubuntu' (the latest LTS version)$\r$\n4. Run this installer again"
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
  nsExec::Exec 'wsl -d Ubuntu -- bash -lc "command -v claude"'
  Pop $0
  ${If} $0 != 0
    DetailPrint "Installing Claude Code CLI via official installer (~1-2 minutes)..."
    ; SECURITY (#7): download the installer to a file FIRST, then run it.
    ; `curl | bash` starts executing bytes as they arrive; a mid-download
    ; network drop leaves bash parsing a truncated script that can land
    ; the system in a half-configured state. Download-then-run also means
    ; if curl fails we can tell (via `[ -s file ]`), instead of tee
    ; returning success while curl silently died.
    ; Run as root to avoid sudo TTY hang; log all output to file so
    ; nsExec doesn't deadlock on pipe buffers.
    nsExec::Exec 'wsl -d Ubuntu -u root -- bash -lc "set -o pipefail; T=$(mktemp /tmp/claude-install-XXXXXX.sh) && curl -fsSL -o \"$T\" https://claude.ai/install.sh > /tmp/kivun-claude.log 2>&1 && [ -s \"$T\" ] && bash \"$T\" >> /tmp/kivun-claude.log 2>&1; rm -f \"$T\""'
    Pop $0
    ${If} $0 != 0
      DetailPrint "Installer script failed, trying npm fallback (~2-3 minutes)..."
      nsExec::Exec 'wsl -d Ubuntu -u root -- bash -lc "apt-get install -y -qq nodejs npm && npm install -g @anthropic-ai/claude-code >> /tmp/kivun-claude.log 2>&1"'
      Pop $0
      ${If} $0 != 0
        MessageBox MB_ICONEXCLAMATION|MB_OKCANCEL "Claude Code CLI installation failed.$\r$\n$\r$\nLog: wsl -d Ubuntu -- cat /tmp/kivun-claude.log$\r$\n$\r$\nYou can install it manually later by running (in WSL):$\r$\n  T=$(mktemp) && curl -fsSL -o $T https://claude.ai/install.sh && [ -s $T ] && bash $T && rm -f $T$\r$\n$\r$\nClick OK to continue, or Cancel to abort." IDOK claude_continue
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

Section "Desktop Shortcut" SEC_SHORTCUT
  CreateShortcut "$DESKTOP\Kivun Terminal.lnk" "$INSTDIR\kivun-terminal.bat" "" "$INSTDIR\kivun_icon.ico" 0 SW_SHOWMINIMIZED "" "Launch Kivun Terminal"
  CreateShortcut "$SMPROGRAMS\Kivun Terminal.lnk" "$INSTDIR\kivun-terminal.bat" "" "$INSTDIR\kivun_icon.ico" 0 SW_SHOWMINIMIZED "" "Launch Kivun Terminal"
SectionEnd

Section /o "Right-Click Menu Integration" SEC_RCLICK
  ; Add "Open with Kivun Terminal" to folder context menu
  WriteRegStr HKCU "Software\Classes\Directory\shell\KivunTerminal" "" "Open with Kivun Terminal"
  WriteRegStr HKCU "Software\Classes\Directory\shell\KivunTerminal" "Icon" "$INSTDIR\kivun_icon.ico"
  WriteRegStr HKCU "Software\Classes\Directory\shell\KivunTerminal\command" "" '"$INSTDIR\kivun-terminal.bat" "%1"'

  ; Add to background of folder (right-click inside a folder)
  WriteRegStr HKCU "Software\Classes\Directory\Background\shell\KivunTerminal" "" "Open with Kivun Terminal"
  WriteRegStr HKCU "Software\Classes\Directory\Background\shell\KivunTerminal" "Icon" "$INSTDIR\kivun_icon.ico"
  WriteRegStr HKCU "Software\Classes\Directory\Background\shell\KivunTerminal\command" "" '"$INSTDIR\kivun-terminal.bat" "%V"'
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

  ; Remove shortcuts
  Delete "$DESKTOP\Kivun Terminal.lnk"
  Delete "$SMPROGRAMS\Kivun Terminal.lnk"

  ; Remove registry entries
  DeleteRegKey HKCU "Software\Classes\Directory\shell\KivunTerminal"
  DeleteRegKey HKCU "Software\Classes\Directory\Background\shell\KivunTerminal"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\KivunTerminal"

  ; Remove installed files
  Delete "$INSTDIR\kivun-terminal.bat"
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
