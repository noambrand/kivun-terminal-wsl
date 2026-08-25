# Kivun Terminal — RTL on macOS, Debug Notes

Investigation date: 2026-05-02
Machine: macOS (Darwin 24.6.0), arm64
Project under test: `noambrand/kivun-terminal-wsl` v1.2.1 (macOS .pkg install)

---

## 1. Initial complaint

> "Installed the v1.2.1 fix for Mac, but everything is still left-aligned. RTL is broken."
> Release: https://github.com/noambrand/kivun-terminal-wsl/releases/tag/v1.2.1

---

## 2. What we found (root causes)

### 2.1 The release v1.2.1 does not fix RTL

Per the GitHub release page, the only changes in v1.2.1 are:
- README styling update ("match kivun-terminal LinkedIn badge style in footer")
- "add Claude Code RTL Support to related-projects (EN+HE)" — a documentation cross-link

**No code, config, or installer change was made.** The release title invites the reader to expect an RTL fix; there is none.

### 2.2 Apple Terminal cannot do RTL paragraph alignment

The user's config had `MAC_TERMINAL=terminal`. Apple Terminal lacks BiDi paragraph reordering — RTL alignment cannot be achieved in it regardless of any wrapper or config flag. The project's own `config.txt` notes this in a comment, but the default ships as `terminal`, so users hit the broken state out of the box.

### 2.3 `TEXT_DIRECTION` is a documented config key with no consumer

`config.txt` documents `TEXT_DIRECTION=rtl` as the default. We searched all installed files:

```
grep -rn "TEXT_DIRECTION" /usr/local/share/kivun-terminal/    # no matches
grep -n  "TEXT_DIRECTION" ~/Desktop/Kivun\ Terminal.command   # no matches
```

The launcher's `case "$key" in …` block reads only `RESPONSE_LANGUAGE`, `TERMINAL_COLOR`, `MAC_TERMINAL`, `FOLDER_PICKER`, `CLAUDE_FLAGS`, `KIVUN_BIDI_WRAPPER`. `TEXT_DIRECTION` is silently ignored — it is a no-op.

### 2.4 The bidi wrapper's `bin` script has stale comments

`/usr/local/share/kivun-terminal/kivun-claude-bidi/bin/kivun-claude-bidi`:

- Comments at lines 13–16 describe `KIVUN_BIDI_FORCE` as an "escape hatch for users running Kivun scripts inside non-Konsole profiles". But `lib/detect-terminal.js` already accepts `apple-terminal`, `iterm2`, and `wezterm`; the escape hatch is no longer needed for these.
- Error block at lines 36–48 says "node-pty integration is pending — run with `KIVUN_BIDI_WRAPPER=off` to disable this wrapper until v1.1.0 ships". But `lib/wrapper.js` does in fact `require('node-pty')` and implements `run()`. This is dead error text; on a normal install it is unreachable.

### 2.5 The bidi wrapper conflicts with native BiDi terminals (the **main RTL bug**)

The wrapper's job is to inject Unicode `RLE…PDF` brackets around Hebrew runs so a non-BiDi terminal will display them right-to-left. iTerm2 (3.5+) and WezTerm both do BiDi natively — they reorder the same runs themselves.

When both run together, the runs are reordered twice and Hebrew comes out **mirrored / reversed**. This is what the user observed after switching to iTerm2 with the wrapper still on:

> "now the text is backwards in hebrew in the new claude session"

`detect-terminal.js` actively *welcomes* iTerm2 and WezTerm into its allowlist — but for a wrapper whose entire purpose is to compensate for a missing BiDi engine, those are exactly the terminals it should opt out of.

### 2.6 The WezTerm launch path in the launcher is incomplete

Compare the two emulator branches in `~/Desktop/Kivun Terminal.command`:

```bash
case "$MAC_TERMINAL" in
    iterm2)
        # builds a full command (cd $FOLDER && claude_exec --append-system-prompt …)
        # and uses osascript to write it into a fresh iTerm window. Exits 0.
        ;;
    wezterm)
        open -a WezTerm "$FOLDER" 2>/dev/null
        exit 0
        ;;
esac
```

The WezTerm branch opens WezTerm in the folder but **does not launch claude**. A user picking `MAC_TERMINAL=wezterm` will land in an empty WezTerm shell.

### 2.7 The `.command` file's default opener is Apple Terminal

`.command` files are always opened by Terminal.app on double-click — even when the user picked iTerm2 in config. The launcher works around this with an `osascript`-based relaunch, which works but causes a brief Apple Terminal flash before iTerm2 takes over.

---

## 3. Fixes applied to this machine

| # | Action | File / target |
|---|---|---|
| 1 | Installed iTerm2 3.6.10 | `brew install --cask iterm2` → `/Applications/iTerm.app` |
| 2 | Switched terminal emulator | `MAC_TERMINAL=iterm2` in `~/Library/Application Support/Kivun-Terminal/config.txt` |
| 3 | Disabled the bidi wrapper to stop double-application | `KIVUN_BIDI_WRAPPER=off` in same config file |
| 4 | Force-enabled iTerm2's per-profile BiDi via direct plist write (the GUI checkbox at Profiles → Text was missing in 3.6.10) | `BiDi = 1` on every profile in `~/Library/Preferences/com.googlecode.iterm2.plist`. Backup at `*.bak.20260502-214338`. **Result: ineffective.** User reported Hebrew rendered *backwards* (mirrored) on relaunch despite `KIVUN_BIDI_WRAPPER=off` and `BiDi = 1`. This resolves §5.1 case 3: iTerm2 3.6.10's BiDi engine cannot correctly render Hebrew for this workflow. Migration to WezTerm follows in §7. |

Final state of the config after step 3:

```
RESPONSE_LANGUAGE=english
MAC_TERMINAL=iterm2
TERMINAL_COLOR=kivun
TEXT_DIRECTION=rtl     # no-op (see §2.3) — kept as-is for now
FOLDER_PICKER=true
CLAUDE_FLAGS=
KIVUN_BIDI_WRAPPER=off
```

`TEXT_DIRECTION` left in place pending an upstream decision (implement vs. remove — see §4.4).

---

## 4. What needs to change upstream

Listed in roughly the order a maintainer would tackle them.

### 4.1 v1.2.1 release notes are misleading

Tag docs-only releases distinctly (`v1.2.1-docs`, or `docs:` prefix in the title), **or** ship the actual RTL fix and call that release the RTL one. A release titled in a way that implies functional RTL improvements should contain functional RTL improvements.

### 4.2 The installer must gate on a BiDi-capable terminal

The macOS `.pkg` postinstall should:

- Detect installed emulators (`/Applications/iTerm.app`, `/Applications/WezTerm.app`).
- If only Terminal.app is present, surface a hard warning that Apple Terminal cannot do RTL paragraph alignment, and offer to `brew install --cask iterm2` (or wezterm).
- Auto-set `MAC_TERMINAL` based on what's actually installed instead of defaulting to `terminal`. The current default silently produces a broken RTL experience — exactly the bug that triggered this investigation.
- **Per §7 findings: prefer WezTerm over iTerm2.** iTerm2 3.6.10's BiDi cannot render Hebrew correctly even with the wrapper disabled and `BiDi=1` set on the profile, so installer recommendation order should be wezterm → iterm2 → terminal (with terminal flagged as broken).

### 4.3 The bidi wrapper must opt **out** of BiDi-capable terminals

This is the proximate cause of the "Hebrew backwards" symptom in earlier iterations. Two options, in order of cleanliness:

1. **Wrapper-side fix (preferred):** edit `lib/detect-terminal.js`. Today it returns `ok:true` for `apple-terminal`, `iterm2`, `wezterm`. For a wrapper whose entire purpose is to compensate for missing BiDi, iTerm2 and WezTerm should be `ok:false` — i.e. the wrapper should *refuse* to run on terminals that already do BiDi. Apple Terminal stays `ok:true` because it lacks native BiDi and benefits from the wrapper.

2. **Launcher-side fallback:** in `Kivun Terminal.command`, before deciding `CLAUDE_EXEC`, force `KIVUN_BIDI_WRAPPER=off` when `MAC_TERMINAL` ∈ {iterm2, wezterm}.

Either fix would have prevented the earlier "backwards Hebrew" symptom without manual intervention. (Note: §7 shows the wrapper alone is *not* the only cause of mirrored Hebrew — iTerm2 itself reproduces the symptom even with the wrapper off, so this fix is necessary but not sufficient.)

### 4.4 `TEXT_DIRECTION` is a documented no-op — implement or remove

Either:

- Implement it: extend `lib/injector.js` to emit `RLE … PDF` per line when `TEXT_DIRECTION=rtl`, giving RTL paragraph alignment at the Unicode layer regardless of the terminal's native BiDi support. **Caveat:** this only makes sense in terminals that *don't* already do paragraph BiDi (i.e. Apple Terminal). On iTerm2/WezTerm it would be the same double-application problem as §2.5. So the implementation must also gate on `detect-terminal`.
- Or remove the key from the documented schema in `config.txt` and stop describing it.

Today it sits in a worst-of-both state: documented, defaulted to `rtl`, and read by no one.

### 4.5 Update the README / TROUBLESHOOTING

The fact that Apple Terminal cannot right-align RTL is currently buried in a `config.txt` comment block. Hoist it to the top of the macOS install section as an upfront prerequisite:

> **macOS prerequisite:** Apple Terminal cannot right-align RTL paragraphs, and iTerm2 3.6.x renders Hebrew incorrectly. Install **WezTerm** before installing Kivun Terminal: `brew install --cask wezterm`.

### 4.6 Stale comments in `bin/kivun-claude-bidi`

- Lines 13–16: rewrite the comment about `KIVUN_BIDI_FORCE` to reflect that macOS terminals are now in the allowlist (and after fix §4.3, that two of them are intentionally rejected).
- Lines 36–48: remove the unreachable "node-pty integration is pending" / "wrapper.run not yet implemented" branches, or downgrade them to a generic catch-all error message. As written they suggest the wrapper is a stub when it isn't.

### 4.7 Default `.command` opener

Double-clicking `.command` always opens Apple Terminal first, even when the user picked iTerm2/WezTerm. The relaunch via `osascript` works but produces a visible flash. Cleaner options:

- Ship a small `.app` bundle (Platypus / Automator) whose `LSHandlers` opens directly in iTerm2 / WezTerm.
- Or have postinstall set the per-file LaunchServices binding: `duti -s com.github.wez.wezterm .command shell` (only when the user opts into WezTerm).

### 4.8 Complete the WezTerm launch path

`Kivun Terminal.command`'s WezTerm branch only opens WezTerm in the folder; it doesn't run claude. Replace with:

```bash
wezterm)
    wezterm start --cwd "$FOLDER" -- "$CLAUDE_EXEC" \
        ${LANG_PROMPT:+--append-system-prompt "$LANG_PROMPT"} \
        $CLAUDE_FLAGS &
    exit 0
    ;;
```

Match the iTerm2 branch's level of orchestration (cwd + flags + language prompt). **This patch was applied locally on this machine in §7.**

### 4.9 Schema validator for cross-platform config drift

`config.txt` is shared between Linux/WSL and macOS builds. It already has comments like `Not used on macOS: USE_VCXSRV (Windows/WSL only)`. A small validator that warns on:

- Keys present in `config.txt` but never read by any installed `*.sh`/`*.command`/`*.js` file (would have caught `TEXT_DIRECTION`).
- Keys read by code but missing from `config.txt`.

…would prevent future ghost-key bugs.

---

## 5. Open questions

1. **Does iTerm2 3.6.10 do BiDi paragraph alignment by default?** **RESOLVED in §3 step 4 / §7.** Empirically: no. With `BiDi = 1` set on the profile and `KIVUN_BIDI_WRAPPER=off`, Hebrew still renders backwards (mirrored). iTerm2 3.6.10's BiDi does not produce correct output for this workflow. Migrating to WezTerm per §7.

2. **Did the v1.2.1 author intend an RTL fix that was dropped from the release?** Worth checking the PR/commit history — this is the kind of release-note mismatch that can happen if a feature commit was reverted but the changelog wasn't.

---

## 6. Recap of changes made on this machine (pre-§7)

```
~/Library/Application Support/Kivun-Terminal/config.txt
  MAC_TERMINAL:        terminal → iterm2
  KIVUN_BIDI_WRAPPER:  on       → off

~/Library/Preferences/com.googlecode.iterm2.plist
  Default profile BiDi: (unset) → 1
  (backup: *.bak.20260502-214338)

/Applications/iTerm.app                  installed (3.6.10, via brew --cask)
~/Desktop/Kivun Terminal.command         not modified (yet — see §7)
/usr/local/share/kivun-terminal/         not modified
```

§7 follows with the WezTerm migration that supersedes this state.

---

## 7. WezTerm migration plan (executing 2026-05-02)

iTerm2 3.6.10 having failed (see §3 step 4), this section captures the migration to WezTerm — the strongest BiDi/Unicode option of the three macOS terminals listed in `config.txt`.

### 7.1 Plan

1. **Install WezTerm** via Homebrew cask: `brew install --cask wezterm`. Lands at `/Applications/WezTerm.app`.
2. **Patch `~/Desktop/Kivun Terminal.command`** to fix §2.6 / §4.8: the existing `wezterm)` branch in the `case "$MAC_TERMINAL" in …` block opens WezTerm in the folder but does not start claude. Replace it with the orchestrated form from §4.8 — `wezterm start --cwd "$FOLDER" -- "$CLAUDE_EXEC" --append-system-prompt "$LANG_PROMPT" $CLAUDE_FLAGS`. Backup the original at `~/Desktop/Kivun Terminal.command.bak.<timestamp>`.
3. **Switch the config**: `MAC_TERMINAL=iterm2` → `MAC_TERMINAL=wezterm` in `~/Library/Application Support/Kivun-Terminal/config.txt`. Leave `KIVUN_BIDI_WRAPPER=off` — WezTerm has its own BiDi engine, so the wrapper would cause the same double-application bug as §2.5.
4. **Quit iTerm2** so the next launch lands in WezTerm cleanly.
5. **User test**: double-click `Kivun Terminal.command`, pick a folder, type Hebrew. Expected: right-aligned, correctly ordered.

### 7.2 Why WezTerm and not "fix iTerm2"

- iTerm2's BiDi GUI checkbox was missing in 3.6.10's Profiles → Text pane on this machine. Setting `BiDi = 1` directly on every profile in the plist did not produce correct rendering — Hebrew still came out backwards.
- This matches §5.1 case 3: with the wrapper off and iTerm2 BiDi nominally on, mirrored Hebrew indicates that iTerm2's BiDi implementation in this build is broken or incompatible with claude's output stream.
- WezTerm's BiDi is on by default (no per-profile toggle needed) and is independently the recommended option in the project's own `config.txt` comments ("WezTerm — strongest Unicode/BiDi support").

### 7.3 What §7 does NOT do

- Does **not** uninstall iTerm2. Leaves it on disk in case the user wants to revert or re-test after a future iTerm2 update.
- Does **not** revert the iTerm2 plist BiDi flip. Backup at `*.bak.20260502-214338` if needed.
- Does **not** touch the bidi wrapper installation under `/usr/local/share/kivun-terminal/`. Wrapper stays installed-but-disabled (`KIVUN_BIDI_WRAPPER=off`).

### 7.4 Final state after §7

```
~/Library/Application Support/Kivun-Terminal/config.txt
  MAC_TERMINAL:        iterm2 → wezterm
  KIVUN_BIDI_WRAPPER:  off    (unchanged)

~/Desktop/Kivun Terminal.command
  case wezterm) branch:  open-folder-only → full claude orchestration (§4.8)
  (backup: Kivun Terminal.command.bak.<timestamp>)

/Applications/WezTerm.app                installed (via brew --cask)
/Applications/iTerm.app                  retained (not removed)
~/Library/Preferences/com.googlecode.iterm2.plist
  Default profile BiDi: 1   (retained; iTerm2 no longer used for daily work)
```
