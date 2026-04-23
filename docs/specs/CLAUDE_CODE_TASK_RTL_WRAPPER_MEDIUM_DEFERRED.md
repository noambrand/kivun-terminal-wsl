> # DEFERRED — do not build from this spec
>
> **Status:** Deferred 2026-04-23.
>
> MEDIUM's §1 integration gate (empirical Konsole BiDi validation on a machine with working GUI Konsole) couldn't be cheaply closed in this environment: no VM, no Kubuntu live USB, no native Linux box with functioning Konsole, and WSLg Konsole was unresponsive on the dev machine. MEDIUM's economic case — "cheaper code if we can cheaply verify Assumption A" — collapsed because verification stopped being cheap.
>
> HEAVY (`CLAUDE_CODE_TASK_RTL_WRAPPER_HEAVY.md`) was chosen instead. HEAVY's Assumption B (terminal honors RLE/PDF per UAX #9) is near-universal for BiDi-capable terminals, carries no profile-drift failure modes, and requires no release gate.
>
> **Revisit this document if** Kivun ever adds a non-Kivun Konsole target that can be cheaply gate-tested natively *and* the ~200-line code delta between HEAVY and MEDIUM becomes relevant to ship cost. Neither is true today.
>
> The decision trail matters — this file is preserved in full below.
>
> ---

# Claude Code Task: MEDIUM_SPEC — Production RTL wrapper for Claude Code in Konsole

> **Verdict basis:** The two prior prototypes (`CLAUDE_CODE_TASK_PROTOTYPE_STREAM.md` → NO-GO, `CLAUDE_CODE_TASK_PROTOTYPE_PTY.md` → HEAVY-or-MEDIUM) eliminated stdout-intercept and naive-per-Hebrew-run RLM injection. The third micro-prototype (line-start RLM under node-pty) functions correctly end-to-end (probe.js mode `line-rlm`, confirmed via fake-claude smoke), but its visual effect in real Konsole **was not observed** — the test environment's Konsole (WSLg) was non-functional. This spec proceeds on the **theoretical case** (Konsole source + KivunTerminal.profile settings), with a required integration gate before release.
>
> **Owner:** Kivun Terminal. Wraps Claude Code on Linux (Konsole) so Hebrew responses render RTL.

---

## 1. Explicit assumption we could not close empirically

> **Assumption A (MUST be validated before release):**
> In Konsole 23.08+ running on a Linux system with the `KivunTerminal` profile active (where `BidiLineLTR=false`, `BidiRenderingEnabled=true`, `BidiTableDirOverride=true`), when `‏` (RLM) is the first strong character on a line, ICU's Unicode BiDi Algorithm returns paragraph direction RTL, and subsequent Hebrew runs render right-to-left while Latin runs on the same line remain correctly positioned.

If Assumption A fails, MEDIUM_SPEC does **not** solve the problem and you must abandon this wrapper and pivot to HEAVY (explicit RLE/PDF bracket injection at composed-row level).

### The integration test gate

Before tagging v1 of the wrapper for release, run in a **native-Linux Konsole** (not WSLg), on a workstation/VM/CI-runner where Konsole GUI actually functions, with the KivunTerminal profile active:

```bash
printf '‏שלום עולם\n'       # With RLM prefix — must render right-to-left
printf 'שלום עולם\n'              # Without RLM — likely renders reversed
printf '‏❯ שלום world bar\n'  # Mixed-script; RLM must flip paragraph to RTL
```

**Pass criterion:** line 1 and line 3 render with Hebrew readable right-to-left and English readable left-to-right in correct positions. Line 2 is the control.
**Fail criterion:** any of the above produces reversed, garbled, or unchanged output → STOP release, escalate to HEAVY.

Treat this gate as a required pre-release check; do not skip.

---

## 2. What we're shipping

A single small wrapper that sits between Konsole and the `claude` binary. When the user runs `claude` inside a Kivun Terminal session, they actually run the wrapper; the wrapper spawns the real `claude` under node-pty and rewrites the pty→stdout stream to inject `‏` at each logical line start.

Two artifacts:
1. **`kivun-claude-bidi`** — the wrapper binary (Node script, probably a symlink in `$PATH` named `claude`).
2. **Konsole profile validator** — runs at install time (or first launch), fails loudly if the active profile does not have the required BiDi settings.

### Explicit non-goals

- No support for terminals other than Konsole. If `$KONSOLE_PROFILE_NAME` is empty, the wrapper must print a clear error and exit non-zero (see §5 Fallback).
- No transformation of `stdin→pty`. The user's typed Hebrew passes through unchanged; only output is rewritten.
- No replacement of Claude Code. We wrap the upstream `claude` binary. Upgrades to Claude Code don't require wrapper changes (unless ink's stream behavior regresses).
- No modification of Konsole profiles at runtime. Profiles are managed by the installer.

---

## 3. Source of the wrapper — adapt, don't re-derive

Start from the prototype in `~/claude-bidi-pty-probe/probe.js`, mode `line-rlm`. The algorithm is proven. Production-ization:

- **Remove modes `raw`, `passthrough`, `naive-rlm`.** Only `line-rlm` ships. Simpler surface, smaller test matrix.
- **Remove verbose JSONL logging** from the hot path. Production wrapper logs only: startup meta, errors, clean exit. Debug logging behind `KIVUN_BIDI_DEBUG=1`, writes to `$XDG_STATE_HOME/kivun/bidi.log` (or `~/.local/state/kivun/bidi.log` fallback) with rotation at 5 MB.
- **Replace `process.exit(127)` on missing node-pty** with a user-readable message in Hebrew + English ("Kivun BiDi wrapper is missing its node-pty dependency. Please reinstall."). **Exit code 2**, not 127. Rationale — leave as a code comment next to the `process.exit(2)` call: *"Using 2 instead of shell-convention 127 for consistency with Kivun's internal exit-code taxonomy (§10). 127 is shell-convention for command-not-found at the shell level; this is a missing runtime dependency inside an already-running process, which is categorically different."*
- **Keep** the cross-chunk state (`StringDecoder`, `atLineStart`, `inCsi`, `inOsc`, `afterEsc`). These are correctness-load-bearing — do not simplify.
- **Keep** `SIGWINCH` forwarding and signal pass-through (SIGINT, SIGTERM, SIGHUP).
- **Keep** `stdio.setRawMode(true)` on stdin for bidirectional TTY transparency.

### Injection rules (unchanged from prototype, restated for the record)

On each byte arriving from pty→stdout:
1. Decode through `StringDecoder('utf8')` to preserve UTF-8 boundaries across chunks.
2. Walk codepoints with the ANSI-aware state machine (CSI / OSC / single-char ESC).
3. On `\n` or `\r`, set `atLineStart = true`.
4. On the first non-ANSI, non-newline, non-directional codepoint after `atLineStart` is true, emit `‏` then the codepoint. Clear `atLineStart`.
5. Never inject twice on the same line. Never inject inside an ANSI sequence.
6. Do not emit RLM if the next codepoint is already RLM, LRM, or ALM.

---

## 4. Konsole profile audit — content-validated, fail-loudly

The wrapper's install step (or equivalent first-launch check) MUST validate the Konsole profile it expects its users to run under. **Existence is not enough** — a user who hand-edited `KivunTerminal.profile` and flipped `BidiLineLTR` back to `true` would silently break the wrapper's entire premise, and all Hebrew would render reversed with no diagnostic. That's the worst failure mode.

### What to validate

Read the profile file at `~/.local/share/konsole/KivunTerminal.profile`. Require, in the `[Terminal Features]` section:

| Key | Required value | Rationale |
| --- | --- | --- |
| `BidiRenderingEnabled` | `true` | Default is `true`, so omission is ACCEPTED (Konsole will use default). Presence with value `false` is REJECTED. |
| `BidiLineLTR` | `false` | Default is `true` (paragraph forced LTR). Our wrapper relies on this being `false`. Omission is REJECTED. Value `true` is REJECTED. |

Other keys in the profile are not inspected.

### How to fail

On violation:
- Write a message to stderr:
  ```
  Kivun BiDi wrapper: Konsole profile audit failed.
  Required setting in ~/.local/share/konsole/KivunTerminal.profile:
    [Terminal Features]
    BidiLineLTR=false
    BidiRenderingEnabled=true   # or omitted (default is true)
  Found: <describe what's wrong>
  Cannot safely run — Hebrew rendering would be incorrect.
  Fix the profile and retry.
  ```
- **Exit code 3.** Reserved for "profile audit failed."
- **Do not proceed to spawn `claude`.** This is the whole point of "fail loudly" — no silent degradation.

### When to run the audit

- At install time (post-install hook in the installer): reject the install outcome if the profile's wrong. The installer should write the profile itself as part of the install so this almost never fails unless the user hand-modified later.
- At every invocation of the wrapper: as the first check before spawning node-pty. Cheap (one file read, two regex checks). If the user has edited their profile after install, we catch it the next time they run `claude`.
- **NOT only at install time.** Re-check every run. Profile drift is real.

### Konsole version check — warn on untested majors

In addition to content validation, the audit reads Konsole's version: `konsole --version 2>/dev/null | head -n 1` → extract the major version (e.g., `konsole 23.08.5` → major `23`). Compare against the release's tested range.

**Initial tested range: 22–25 inclusive** (bump per wrapper release).

- Inside range → silent pass.
- Outside range → stderr warning, **not fatal**:
  ```
  kivun-claude-bidi: Konsole <X.Y.Z> is outside the tested major-version range (22-25).
  BiDi profile keys may have been renamed or repurposed in this version.
  If Hebrew renders incorrectly, file a bug with this version info.
  ```
  Continue running.

Rationale: catches upstream regressions (e.g., Konsole renaming `BidiLineLTR` to `BidiParagraphDirection` in a future major) **before users hit silently-broken rendering in production**. Cheap, doesn't block legitimate-but-untested upgrades.

### What if `$KONSOLE_PROFILE_NAME` is set but isn't `"Kivun Terminal"`?

The user is in a different Konsole profile (maybe a personal one without `BidiLineLTR=false`). Print a clear message telling them to switch profile (`konsole -p KivunTerminal`) and exit code 4. Do not attempt to audit a non-Kivun profile.

### What if `$KONSOLE_PROFILE_NAME` is empty?

Not in Konsole. Exit code 5 with a message pointing them at supported terminals.

---

## 5. Fallback / supported-terminal behavior

Detection (in order):
1. If `$KONSOLE_PROFILE_NAME` is non-empty → in Konsole. If it equals "Kivun Terminal", proceed to profile audit. If not, exit code 4.
2. If `$KONSOLE_DBUS_SERVICE` is non-empty but `$KONSOLE_PROFILE_NAME` is empty → unusual Konsole launch; treat as unsupported, exit code 5 with a hint to set the profile.
3. If neither → exit code 5 (not in Konsole).

No attempt to support other terminals in v1. If that becomes a requirement later, it's a v2 feature — likely driven by HEAVY_SPEC architecture, because non-Konsole terminals may not support ICU-style BiDi with `BidiLineLTR=false` semantics.

### Do we offer a `--force` flag?

No. A user who needs to override the audit can set `KIVUN_BIDI_SKIP_AUDIT=1` in their environment, which bypasses §4 but prints a stderr warning every run. This is for dev/debugging only; not documented in user-facing docs. The warning must say "Rendering may be incorrect; audit skipped."

---

## 6. File layout & install targets

### Repository structure

```
kivun-claude-bidi/
├── package.json
├── bin/
│   └── kivun-claude-bidi          # shebang'd entrypoint, wraps lib/
├── lib/
│   ├── wrapper.js                  # main event loop (from probe.js line-rlm)
│   ├── audit.js                    # §4 profile validator
│   ├── injector.js                  # the line-start RLM state machine (pure fn, unit-testable)
│   └── detect-terminal.js           # §5 terminal detection
├── test/
│   ├── injector.test.js             # unit tests — pure function, no I/O
│   ├── audit.test.js                # fixture profiles (pass + 5 fail modes)
│   └── smoke.sh                     # end-to-end against fake-claude (reuse prototype's approach)
└── README.md
```

### Install targets — userspace only, **no `/usr/local`, no `sudo`**

Kivun's install footprint is entirely per-user. The wrapper follows suit:

- `~/.local/share/kivun-terminal/claude-bidi/` — wrapper source + `node_modules/` (compiled node-pty lives here).
- `~/.local/bin/claude-bidi` — executable shim (Node shebang, points at the source above). This is the name users' commands must hit.
- `~/.local/share/konsole/KivunTerminal.profile` — the installer writes this with the correct BiDi settings. The audit (§4) validates it.
- `~/.local/share/konsole/ColorSchemeNoam.colorscheme` — unchanged from current distribution.

### How `claude` calls get routed through the wrapper — launcher exec, NOT an alias

**Do NOT use a shell alias** for `claude`. Aliases only apply in interactive shells — they silently break for:
- `claude` invoked from scripts (most dangerous; appears to work in terminal but fails elsewhere)
- Subprocess invocations (Claude Code itself spawns some tool children)
- Non-interactive shells started by IDEs, cron, systemd units

The correct route: **Kivun's existing `kivun-launch.sh` does the work at session start**:

1. Launcher prepends `~/.local/bin` to `PATH` before anything else runs.
2. Launcher's final line uses `exec claude-bidi "$@"` (not `exec claude "$@"`). This hard-wires every Kivun-launched session to go through the wrapper.
3. Inside the wrapper, when we `pty.spawn(CLAUDE_BIN, ...)`, `CLAUDE_BIN` is resolved from `command -v claude` **while explicitly excluding** `~/.local/bin` from the search path, to avoid the wrapper re-invoking itself. (One line: `PATH="${PATH/$HOME\/.local\/bin:/}" command -v claude`, or equivalent.)

### Defensive PATH check (first-run self-diagnostic)

On startup, the wrapper reads its own install directory (`path.dirname(process.argv[1])`, resolved via `realpath`). If that directory is **not** a prefix match in `$PATH`, the wrapper writes a stderr diagnostic:

```
kivun-claude-bidi: installed at <path>, but that directory is not on $PATH.
Your Kivun launcher may not be loading correctly. Typical fix:
  export PATH="$HOME/.local/bin:$PATH"
(Or fix kivun-launch.sh to prepend this before invoking the session.)
```

This is a **warning, not fatal** — proceed with the run. Catches installer bugs where the launcher didn't run, or the user stripped the PATH prepend. Cheap defense; one `realpath` + one substring check per session.

### Installer requirements (Kivun installer team, out of this repo's scope but noted)

- `node >= 18` installed (for node-pty compat).
- `build-essential`, `make`, `g++`, `python3` at install time for node-pty's native build. The install that hit us today had none of these — surface this explicitly in install-time dependency checks.
- Post-install hook runs the profile audit once; if it fails, abort install.

---

## 7. Testing plan

### Unit (fast, CI-friendly)

1. `injector.test.js`: feed the line-start injector a list of representative fixtures and assert output byte-for-byte:
   - Plain ASCII line — no injection
   - Line starting with Hebrew — RLM prepended
   - Line starting with ANSI (SGR) then Hebrew — RLM between SGR and Hebrew
   - Chunk boundary splits a UTF-8 codepoint in half — output correct when concatenated with next chunk's output
   - Chunk boundary splits a CSI sequence in half — state machine resumes correctly
   - Line already starting with RLM — no double injection
   - `\r\n` vs `\n` vs bare `\r` — all treated as line start
   - Alt-screen-buffer toggle (`\x1b[?1049h` / `\x1b[?1049l`) in a chunk — does not break state
2. `audit.test.js`: fixture profiles for every failure mode:
   - Profile missing — fails with code 3
   - `BidiLineLTR=true` — fails
   - `BidiLineLTR` key absent — fails
   - `BidiRenderingEnabled=false` — fails
   - Correct profile — passes
   - Profile has the `BidiEnabled=true` legacy key (like KivunTerminal.profile currently has) — treated as informational warning; passes if other keys are right.

### Smoke (medium, pre-release)

Reuse the fake-claude smoke from the prototype. `test/smoke.sh` exits 0 on expected byte output.

### Integration gate (slow, pre-release — §1)

The three `printf` lines in native Linux Konsole. Manual-visual, once per release.

### Load / stress (nice-to-have)

Pipe a 10 MB stream of mixed Hebrew/English through the wrapper and measure throughput. Target: ≥ 1 MB/s on a laptop. Ink doesn't produce more than a few KB/s even at full typing speed; this is headroom.

---

## 8. Out-of-scope for v1

- **stdin→pty injection.** If the user's typed Hebrew also needs directional marking to display correctly at the prompt, that's a v2 problem. Likely already handled by Konsole's own input BiDi.
- **Non-Konsole terminals.** §5.
- **Automatic profile installation.** Profile is a Kivun installer concern.
- **Full xterm.js-style state machine.** If Assumption A fails, that's HEAVY_SPEC and a different document.
- **Telemetry.** No phone-home.

---

## 9. Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Assumption A fails in real Konsole | Low (theory + research supports it) | High (spec is moot) | §1 integration gate is mandatory; planned HEAVY pivot documented elsewhere |
| node-pty fails to build on user system | Medium (build-essential can be missing) | High (wrapper can't run) | Installer declares hard dep; wrapper prints clear error pointing at the install doc |
| User hand-edits profile and flips BidiLineLTR | Low-medium (power users) | High (silent reversal of all Hebrew) | §4 mandatory audit catches it every run |
| User switches Konsole profile mid-session via menu | Low (5% edge case; most users don't profile-hop) | High (silent Hebrew reversal until session end) | **None in v1.** `$KONSOLE_PROFILE_NAME` in the running shell is window-launch-time only; Konsole does not update it on profile switch. Audit would pass against the stale cached value while the actual profile has `BidiLineLTR=true`. **Documented limitation.** v2 fix: query active profile via D-Bus at each wrapper invocation instead of trusting the env var. |
| ink changes its stream pattern in a future Claude Code release | Low per release, cumulative over time | Medium (line detection may drift) | Smoke test runs against each Claude Code release; CI alarm |
| Konsole drops or renames BidiLineLTR key in a future version | Low | High if it happens | Audit's Konsole-version check (§4) warns on untested major versions; combined with mandatory content validation catches renamed keys |

---

## 10. Deliverable checklist

- [ ] `lib/injector.js` with unit tests (at least the 8 fixtures from §7).
- [ ] `lib/audit.js` with unit tests (the 6 scenarios from §7).
- [ ] `lib/detect-terminal.js` small; tests or manual verification.
- [ ] `lib/wrapper.js` — main event loop.
- [ ] `bin/kivun-claude-bidi` entrypoint.
- [ ] `test/smoke.sh` reusing the prototype's fake-claude approach.
- [ ] README covering: install, dependencies, usage, `KIVUN_BIDI_DEBUG` flag, `KIVUN_BIDI_SKIP_AUDIT` escape hatch, Konsole profile requirement.
- [ ] Exit-code documentation (0 clean, 2 missing dep, 3 profile audit fail, 4 wrong profile, 5 wrong terminal).
- [ ] §1 integration gate result (a brief text note in repo, by hand, listing machine/Konsole version and observed rendering).

Only line 1 of the final release notes should mention "Right-to-left rendering for Hebrew in Claude Code." The engineering is invisible to users. That's the win condition.
