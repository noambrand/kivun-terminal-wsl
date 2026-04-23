# Kivun Terminal — Roadmap

Tracks upcoming versions and the criteria gating each release. Owner: Kivun Terminal. Source of truth for "when do we ship X".

---

## v1.1.0 — BiDi wrapper, default-on

### Scope

Ships the `kivun-claude-bidi` wrapper (HEAVY architecture — explicit RLE/PDF bracket injection, see `CLAUDE_CODE_TASK_RTL_WRAPPER_HEAVY.md`) installed and **enabled by default**. Users who prefer the baseline behavior can flip `KIVUN_BIDI_WRAPPER=off` in `config.txt`.

### Rationale for default-on

Originally scoped as opt-in with a v1.2.0 default-flip after a 4-week feedback cycle. Dropped that gate dance because:

- User-base is small; the 4 weeks don't yield the kind of signal the gate is supposed to capture.
- The whole product-promise is "Hebrew in Claude Code just works." Requiring users to edit a config file to get the fix contradicts that promise — most users won't do it.
- If the wrapper breaks something, the single-line rollback (`KIVUN_BIDI_WRAPPER=off`) is fast and documented in `docs/TROUBLESHOOTING.md`. Equivalent in practice to keeping it off until they ask.

### Deliverables (checklist)

- [ ] `kivun-claude-bidi/` package built per HEAVY §6 layout.
- [ ] 10 ship-blocking core fixtures pass in `test/core.test.js` (see HEAVY §7 partition below).
- [ ] 8 nice-to-have fixtures exist in `test/extended.test.js`; failures documented as known limitations in release notes.
- [ ] HEAVY §1 integration gate run on real Konsole; result logged in `docs/research/integration-gate-<date>.md`.
- [ ] Stress test: 10 MB mixed Hebrew/Latin through wrapper at ≥1 MB/s.
- [ ] 1-day production canary on lead-dev Claude Code use.
- [ ] `payload/config.txt` ships `KIVUN_BIDI_WRAPPER=on` as default.
- [ ] `payload/kivun-launch.sh` and `linux/kivun-launch.sh` read `KIVUN_BIDI_WRAPPER`; invoke wrapper when `=on`, fall back to unwrapped `claude` when `=off` or when the wrapper binary isn't reachable.
- [ ] `docs/CHANGELOG.md` — v1.1.0 entry describing wrapper, how to disable, known limitations.
- [ ] `docs/TROUBLESHOOTING.md` — wrapper-specific diagnostics section.
- [ ] `VERSION` bumped `1.0.6` → `1.1.0`.

### HEAVY §7 fixture partition (Noam-approved 2026-04-23)

**Ship-blocking core (10):** #1, #2, #3, #4, #5, #9, #10, #11, #13, #16. All must pass before tag.

**Nice-to-have (8):** #6, #7, #8, #12, #14, #15, #17, #18. Failures ship with known-limitation notes.

### Rollback path (if something breaks in the wild)

If a user reports output corruption, silent hang, or Claude launch failure attributable to the wrapper:

1. **Same-day acknowledgement:** guide affected users to `KIVUN_BIDI_WRAPPER=off` as an immediate workaround (documented in TROUBLESHOOTING, surfaced in the release notes).
2. **v1.1.1 hotfix:** if the root-cause fix doesn't ship within 48 hours, release v1.1.1 with default flipped back to `off` so fresh installs don't hit the bug.
3. **Post-mortem:** what signal was missing from the v1.1.0 tests. Extend the fixture set before re-flipping default-on in a subsequent release.

---

## Beyond v1.1.0 (tracked, not scheduled)

- **~~Fix Claude Code's `●` bullet first-line LTR alignment~~ — DONE in v1.1.0.** Extended wrapper with line-start RLM (U+200F) injection for lines whose first strong char is RTL. Empirically verified on real Konsole via `docs/research/paragraph-direction-test.sh`: only RLM at position 0 flips paragraph direction; RLE/RLI wraps don't. See commit `79335be` and the line-start buffering loop in `kivun-claude-bidi/lib/injector.js`.
- **Arabic support** via `KIVUN_BIDI_WRAP_ARABIC=1` env flag. Wraps U+0600–U+06FF in addition to Hebrew block. Trigger: explicit user request or Arabic adoption of Kivun.
- **Non-Konsole terminals.** Widen `detect-terminal.js` allowlist to gnome-terminal+VTE, alacritty with BiDi, Windows Terminal when/if it adopts BiDi. Each addition requires its own integration gate test.
- **RLI/PDI isolates migration.** One-line constant change from RLE/PDF. Triggered only if direction-leak artifacts are observed in practice.
- **Statusline for Kivun Terminal.** Listed in `docs/README.md` as "planned v1.1" — not a wrapper-track item, tracked separately.

---

_Last updated: 2026-04-23. Default-on decision recorded this revision._
