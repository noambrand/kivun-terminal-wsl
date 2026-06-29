# Working notes for AI agents on this repo

## Decision-making

**When the bulletproof option is obvious, do it. Do not ask.**

If you have validated half of a feature (e.g. the decline path of an installer prompt) and the other half is obviously the path users actually care about (e.g. the auto-install path itself), add the validation - don't offer the user a choice between the obviously-right and obviously-wrong option. Framing an obvious call as a question shifts engineering judgment onto the user and risks them picking the worse option for the wrong reason (saving CI minutes, looking decisive, etc.).

Reserve questions for genuine trade-offs - cost vs. benefit, scope, taste. Completeness and self-doubt are not the same as helpfulness when the answer is obvious.

## Bulletproofing this product specifically

This repo ships a launcher that runs on someone else's Windows machine. The user-visible failure mode that ate v1.1.0 was: launcher said "Claude not found", then claimed to fall back, then crashed running the missing binary. Treat every launcher path as a path that must work end-to-end on a clean machine - not just "exit cleanly when broken." The CI in `.github/workflows/validate-launcher-windows.yml` exists to enforce this; if you add a new launcher branch, add a CI job that exercises it against real WSL.

**Field bugs you can't reproduce here: get ground truth, don't ship blind.** When a symptom is on the user's *other* Windows PC, that machine is theirs — ask them to run a Claude Code session ON it to pull the real logs (`%LOCALAPPDATA%\Kivun-WSL\LAUNCH_LOG.txt` + `BASH_LAUNCH_LOG.txt`) and run live probes (e.g. `xeyes` to test whether WSLg paints *anything*). v1.5.6–v1.5.8 wasted three releases on speculative fixes; the actual causes only fell out once the failing machine's logs/experiments came back. The rewritten `kivun-diagnostics.cmd` exists to make this one click; trust its report over guesses.

## WSLg + Windows gotchas (learned debugging the v1.5.x "no window" saga)

- **`wmic` is REMOVED on Windows 11 24H2+ (build 26200).** Never call it in `payload/`/`offline/` scripts — it silently broke Diagnostics (truncated mid-run) and monitor detection. CI guard blocks real `wmic` invocations. Get monitor size from the WSL side (xrandr/Xinerama), not Windows.
- **Konsole on WSLg is Qt6 *Wayland* → xdotool/wmctrl (X11) can't see or manage it** ("Could not find Konsole window"). Force `QT_QPA_PLATFORM=xcb` (Xwayland) and then `--name`, geometry, raise, icon all work. Escape hatch: `KIVUN_FORCE_XCB=auto|on|off` in config.txt.
- **Konsole *forks* by default** → the launched pid hands the window to a daemon instance and the window you sized/raised is replaced by an unmanaged, minimized one. Launch `--nofork --separate` (probed) and find the window by `--pid` (KPID), with a ~15s retry (first paint is slow: BiDi wrapper + Claude spin up).
- **WSLg can "wedge" and paint NO window at all** (even `xeyes` is invisible). Only cure is `wsl --shutdown`. Don't make users type it: the installer runs `wsl --update` + `wsl --shutdown` at finalize, and ships a one-click Start-menu **"Repair Kivun Display"** for recurrence. Never auto-run `wsl --shutdown` mid-session (kills other WSL work).
- **The distro is NOT always named "Ubuntu"** (the Store installs `Ubuntu-24.04`). `kivun-detect-distro.cmd` picks it (exact `Ubuntu`, else first `Ubuntu-*`); used by the launcher (`%DISTRO%`) and installer (`$DISTRO`) so an existing distro is reused, never duplicated. `WSL_UTF8=1` makes `wsl -l -q` parseable from cmd.
- **Diagnostics must deliver before any WSL probe** (Desktop copy + Notepad + `explorer /select` to highlight the file), include `LAUNCH_LOG`/`BASH_LAUNCH_LOG`, and resolve the *real* Desktop via `User Shell Folders` (OneDrive redirection). Every hard launcher error calls `:DIAG_HINT`, which auto-opens it.
- **`--continue`/`--resume` on a folder with no prior chat makes Claude exit immediately** → the terminal/tab dies. Launchers retry a fresh session (time-guarded) so the window never just vanishes.
- **CI invariants:** the `static-lint` job grep-asserts each fix; add a guard per fix, and run the grep against the real file before pushing — the word in a comment/log-string will false-positive (match commands only, e.g. `nsExec::Exec` lines, line-start, or a real verb).

## Workflows

### Automatic Publishing

When publishing a release on this repo:

1. **Versioning** — bump `VERSION` at the repo root (the source of truth — there is no `package.json`). Add a corresponding entry in `docs/CHANGELOG.md`. Optionally add `docs/RELEASE_NOTES_<version>.md` for a user-friendly GitHub release page; CI prefers it over the CHANGELOG section.
2. **Binary Integrity** — never upload manually built artifacts. The release pipeline is tag-push driven: pushing `vX.Y.Z` triggers `.github/workflows/build-windows.yml` (Windows installer) and `.github/workflows/build-linux.yml` (Linux tarball), each rebuilds clean and attaches via `softprops/action-gh-release@v2`.
3. **Atomic Release** — push the version-bump commit to the branch FIRST, then push the tag: `git push origin vX.Y.Z`. The GitHub release is created by the tag push, not by the branch merge.
4. **Asset Persistence (badge re-sync)** — if a release exists but the Shields.io downloads badge shows "invalid" or "no data", run `gh release upload v<version> <asset> --clobber` against an existing asset to force GitHub to refresh the asset metadata; this tickles the API's `download_count` field which the badge cache reads. Use this whenever a user reports the badge stuck on "invalid". (Verbatim phrase to expect from the user: "Refresh the release assets for the latest version.")
