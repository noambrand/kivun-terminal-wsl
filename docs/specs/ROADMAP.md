# Kivun Terminal — Roadmap

Tracks upcoming versions and the criteria gating each release. Owner: Kivun Terminal. Source of truth for "when do we ship X".

---

## v1.1.0 — BiDi wrapper, opt-in (ship target: after HEAVY core fixtures pass + integration gate + 1-day production canary)

### Scope

Ships the `kivun-claude-bidi` wrapper (HEAVY architecture — explicit RLE/PDF bracket injection, see `CLAUDE_CODE_TASK_RTL_WRAPPER_HEAVY.md`) installed but **disabled by default**. Users opt in by flipping one config key.

### Deliverables (checklist)

- [ ] `kivun-claude-bidi/` package built per HEAVY §6 layout.
- [ ] 10 ship-blocking core fixtures pass in `test/core.test.js` (see HEAVY §7 partition below).
- [ ] 8 nice-to-have fixtures exist in `test/extended.test.js`; failures documented as known limitations in release notes.
- [ ] HEAVY §1 integration gate run on real Konsole; result logged in `docs/research/integration-gate-<date>.md`.
- [ ] Stress test: 10 MB mixed Hebrew/Latin through wrapper at ≥1 MB/s.
- [ ] 1-day production canary on lead-dev Claude Code use.
- [ ] `payload/config.txt` adds `KIVUN_BIDI_WRAPPER=off` as shipped default.
- [ ] `payload/kivun-launch.sh` and `linux/kivun-launch.sh` read `KIVUN_BIDI_WRAPPER`; invoke wrapper only when `=on`.
- [ ] `docs/CHANGELOG.md` — v1.1.0 entry describing wrapper, how to enable it, note that default-on lands in v1.2.0 after feedback cycle.
- [ ] `docs/TROUBLESHOOTING.md` — wrapper-specific diagnostics section.
- [ ] `VERSION` bumped `1.0.6` → `1.1.0`.
- [ ] Installer **unchanged** in v1.1.0. No new checkbox; opt-in is via config key only.

### HEAVY §7 fixture partition (Noam-approved 2026-04-23)

**Ship-blocking core (10):** #1, #2, #3, #4, #5, #9, #10, #11, #13, #16. All must pass before tag.

**Nice-to-have (8):** #6, #7, #8, #12, #14, #15, #17, #18. Failures ship with known-limitation notes.

---

## v1.2.0 — BiDi wrapper, default-on

### Scope

Flip `KIVUN_BIDI_WRAPPER=off` → `KIVUN_BIDI_WRAPPER=on` in shipped `config.txt`. Nothing else needs to change — the wrapper is identical; the switch is one line in one config file.

### Gate criteria (ALL must be true before the flip)

1. **Minimum feedback window.** At least 4 weeks have elapsed since v1.1.0 tag. Shorter isn't long enough to surface visual regressions in diverse Claude Code workloads.
2. **Zero reported output corruption attributable to the wrapper.** "Attributable to the wrapper" = issue reproduces only with `KIVUN_BIDI_WRAPPER=on` and resolves with `=off`. Reports of pre-existing Claude Code / Konsole bugs don't count.
3. **Positive adoption signal.** At least 3 independent users confirm (issue comment, DM, or email) that Hebrew renders correctly with the wrapper on. This can be Kivun maintainers + close collaborators if the wider user base doesn't self-report — the bar is "people who'd tell us if it looked wrong actually use it and don't tell us it looks wrong."
4. **Integration gate still passes.** §1 of HEAVY re-run on the version of Konsole shipped with Ubuntu at v1.2.0-release time. If Konsole shipped a BiDi regression, block the flip until upstream fixes.
5. **CI coverage unchanged or expanded.** No fixture removed or made optional between v1.1.0 and v1.2.0. If anything, extended-fixture failures from v1.1.0 should be promoted to core by v1.2.0 if they've been investigated and fixed.

### Rollback trigger (at any point after v1.2.0 ships)

If a user reports output corruption traceable to the wrapper:

1. **Same-day response:** acknowledge publicly, guide affected users to set `KIVUN_BIDI_WRAPPER=off` as a workaround.
2. **v1.2.1 hotfix** flips default back to `off` if root-cause fix isn't ready within 48 hours.
3. **Root-cause post-mortem** before re-flipping default-on in a subsequent patch release. No "just try again next version" — document what was missed in v1.1.0 feedback-window process and what changed.

### What is NOT in v1.2.0 scope

- No architecture change to wrapper (no RLI/PDI migration, no Arabic support, no xterm.js state machine).
- No new installer component.
- No terminal-support widening (still Konsole-only).
- No API-level changes to `config.txt` schema beyond the one-character default flip.

If any of the above become necessary, they go to v1.3.0+.

---

## Beyond v1.2.0 (tracked, not scheduled)

- **Arabic support** via `KIVUN_BIDI_WRAP_ARABIC=1` env flag. Wraps U+0600–U+06FF in addition to Hebrew block. Trigger: explicit user request or Arabic adoption of Kivun.
- **Non-Konsole terminals.** Widen `detect-terminal.js` allowlist to gnome-terminal+VTE, alacritty with BiDi, Windows Terminal when/if it adopts BiDi. Each addition requires its own integration gate test.
- **RLI/PDI isolates migration.** One-line constant change from RLE/PDF. Triggered only if direction-leak artifacts are observed in practice.
- **Statusline for Kivun Terminal.** Listed in `docs/README.md` as "planned v1.1" — not a wrapper-track item, tracked separately.

---

_Last updated: 2026-04-23. Next review: on v1.1.0 tag._
