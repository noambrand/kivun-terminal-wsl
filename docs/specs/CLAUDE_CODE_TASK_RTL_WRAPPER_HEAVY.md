# Claude Code Task: HEAVY_SPEC - Production RTL wrapper using RLE/PDF bracket injection

> **Status:** Contingency spec. Pre-authored in parallel with MEDIUM_SPEC so that if MEDIUM's Assumption A fails at its §1 integration gate, Kivun is not cold-starting on architecture. Also the correct ship if portability outside the KivunTerminal profile is required (e.g., users running Kivun scripts inside their own Konsole profile, or future non-Konsole terminal support).
>
> **Relationship to MEDIUM:** HEAVY reuses MEDIUM's `§3` pty-wrapper scaffolding (node-pty, StringDecoder, ANSI state machine, signal passthrough, logging) and replaces only the injector algorithm (`lib/injector.js`) and the audit (`lib/audit.js` - largely dropped). Everything else is shared. If you adopt HEAVY after MEDIUM was built, ~70% of the code carries over.

---

## 0. Why RLE/PDF, not RLM at line start, not xterm.js state machine

Three injection strategies exist for BiDi in terminal output:

1. **MEDIUM: RLM (U+200F) at line start.** Cheap. Works only if the terminal's paragraph direction picks up the first strong character (requires `BidiLineLTR=false` in Konsole, or equivalent in other terminals). Silent failure if the profile's wrong.
2. **HEAVY (this doc): RLE (U+202B) + PDF (U+202C) around each Hebrew run.** Unconditionally forces RTL paragraph direction *within the wrapped run* regardless of terminal settings. No Konsole profile dependency. No silent failure mode from profile drift.
3. **HEAVIEST (rejected): full xterm.js-headless state machine, reconstruct screen grid, inject at composed-row level.** ~800 lines, handles every ink cursor-positioning quirk. Correct in every case but 3× code + ongoing maintenance burden tracking xterm.js releases. **Rejected** as over-engineered for the actual problem: ink's output does have well-defined logical line boundaries, it's just that paragraph direction needs to be set unconditionally, which (2) achieves with ~50 lines of injector code.

Target for HEAVY: **~500 total wrapper lines**, not 800. The main size difference vs MEDIUM (~300 lines) is bracket-pairing state and the edge cases in §3.

### Why RLE/PDF and not RLI/PDI (isolates)?

Unicode 6.3 (2013) introduced **isolates** (RLI U+2067, LRI U+2066, FSI U+2068, PDI U+2069), which are the *modern* preferred controls - they don't influence surrounding text, only the isolated run. RLE/PDF (embeddings) can leak direction into adjacent characters if the terminal's BiDi implementation is slightly off-spec.

**We use RLE/PDF anyway because:**
- Kivun targets Konsole, which uses ICU 52+. Both embedding and isolate characters are supported.
- Per the Konsole research finding (`TerminalDisplay.cpp` uses `ubidi_setPara` with per-paragraph level), isolates don't offer a meaningful advantage over embeddings in this specific context - Konsole re-runs BiDi per line anyway.
- RLE/PDF has broader terminal support if we ever generalize beyond Konsole (older terminals with pre-2013 ICU handle embeddings).

**Noted alternative:** v2 may switch to RLI/PDI if we ever observe direction-leak artifacts in practice. The switch is a one-line constant change; algorithm unchanged.

---

## 1. The Assumption A we inherit - and the one we don't

MEDIUM's Assumption A was the profile-dependent one. HEAVY has a **weaker, broader-applicable assumption**:

> **Assumption B:** Konsole's BiDi renderer honors explicit Unicode directional formatting characters (RLE U+202B, PDF U+202C) per the Unicode Bidirectional Algorithm (UAX #9). Specifically: characters between a matched RLE and PDF are rendered with RTL paragraph direction regardless of `BidiLineLTR` setting or first-strong-char analysis.

This is the near-universal contract for BiDi-capable terminals. Failure implies the terminal is not BiDi-capable at all (in which case no wrapper can help - a pre-wrapping question).

**The integration gate** (run once on a real Linux Konsole, same as MEDIUM's):

```bash
printf 'plain: שלום עולם\n'
printf 'bracketed: ‫שלום עולם‬\n'
printf 'mixed: Hello ‫שלום‬ world\n'
```

**Pass:** bracketed lines render Hebrew right-to-left while Latin text remains left-to-right in expected positions. Plain line (line 1) may render reversed - that's the baseline bug. Lines 2 and 3 must be correct.
**Fail:** lines 2-3 render reversed → terminal doesn't support embeddings → no wrapper architecture can fix Kivun in this terminal. Escalate to architectural discussion (switch terminal? Patch ink? Give up?).

Unlike MEDIUM, HEAVY's gate is near-guaranteed to pass on any modern BiDi terminal. The main uncertainty is whether a few edge cases (§3) produce rendering artifacts.

---

## 2. Architecture - state machine per stream

Same scaffolding as MEDIUM §3 (node-pty, StringDecoder, ANSI-aware walk, signal handling). Replace only the injector.

### Injector state

```
state: {
  inCsi        : bool,   // inside ESC [ ... final byte
  inOsc        : bool,   // inside ESC ] ... BEL
  afterEsc     : bool,   // just saw ESC, next byte classifies
  insideRun    : bool,   // currently inside an open RLE...PDF bracket
  lastEmittedCp: int|null, // for cross-chunk Hebrew-run continuation
}
```

### Injection rules

For each codepoint extracted from the ANSI state walk (i.e., not a byte of an escape sequence):

| Situation | Action |
| --- | --- |
| Hebrew cp (U+0590–U+05FF) + not inside run | Emit `‫` (RLE), emit cp. Set `insideRun = true`. |
| Hebrew cp + already inside run | Emit cp. No bracket change. |
| Non-Hebrew, non-newline cp + inside run | Emit `‬` (PDF), emit cp. Clear `insideRun`. |
| `\n` or `\r` + inside run | Emit `‬`, emit newline. Clear `insideRun`. **Do not let brackets cross lines.** |
| Chunk boundary + inside run | Emit `‬`. On next chunk, if first non-ANSI cp is Hebrew, emit `‫` and reopen. `lastEmittedCp` tracks this. |
| Stream end + inside run | Emit `‬`. All brackets balanced at termination. |

### Invariants

1. Every RLE we emit is matched by a PDF, always, before stream end, line end, or chunk end.
2. RLE/PDF are emitted **outside** any ANSI escape sequence - never mid-CSI.
3. Brackets never span a `\n` or `\r`. If a Hebrew run appears to continue on the next line (rare in claude's output; never happens in practice), it gets re-bracketed as a new run.
4. Nested RLE are not emitted. Single-level bracketing only.

### Hebrew run detection details

Hebrew block: U+0590–U+05FF (Hebrew block itself; includes letters U+05D0–U+05EA, points U+0591–U+05C7, punctuation like maqaf U+05BE, paseq U+05C0).
Hebrew presentation forms (U+FB1D–U+FB4F) treated identically - same detection predicate, same bracketing.
Arabic block (U+0600–U+06FF) is NOT included by default. Kivun is Hebrew-first. v2 decision: also wrap Arabic if required; the detection predicate becomes `isStrongRtl(cp)` and includes both ranges.

### Punctuation and whitespace inside Hebrew runs

A Hebrew run ends at the first codepoint that's **not Hebrew and not Hebrew-adjacent punctuation**. Hebrew-adjacent punctuation, for our purposes, is:
- Space (U+0020) - **included as part of the run if it's between Hebrew words**. A phrase like `שלום עולם` bracket-wraps as `‫שלום עולם‬` (one bracket pair), not as `‫שלום‬ ‫עולם‬`. Fewer brackets → cleaner output + fewer opportunities for terminal BiDi weirdness.
- Comma, period, semicolon, colon, question mark (U+002C, U+002E, U+003B, U+003A, U+003F) and their Hebrew equivalents (U+05F3 geresh, U+05F4 gershayim) - included **if preceded by Hebrew and followed by Hebrew or whitespace-then-Hebrew-or-line-end**. This keeps "שלום, עולם" as one run.
- Parentheses, brackets - **not included.** Bracketing here is risky due to BiDi's paired-bracket rules. Close the Hebrew run at `(`, start a fresh one if Hebrew resumes inside.

Implementation: two-character lookahead on the first non-Hebrew codepoint. If it's in the allowed set and the char-after-that is Hebrew or whitespace, keep the run open; emit the punctuation without PDF. Otherwise close the run.

**Tradeoff acknowledged:** this heuristic is imperfect. If it proves wrong in practice (e.g., Hebrew followed by a period followed by end-of-sentence English looks odd), the fallback is stricter: close the run at any non-Hebrew, non-space codepoint. Simpler, more brackets, equally correct.

---

## 3. Edge cases and how HEAVY handles each

### 3.1 Nested RTL spans

Doesn't happen in practice from Claude Code's output. But if it did: our single-level bracketing would emit one RLE...PDF pair for the outermost run. Nested Hebrew inside already-bracketed Hebrew just flows - no special handling needed.

### 3.2 Hebrew inside code blocks (``` fences)

Code blocks from Claude Code contain Hebrew as comments (`# תגובה בעברית`) and occasionally as string literals. The wrapper does not know it's inside a code block - it just sees characters. The bracket gets applied to the Hebrew regardless.

Visual consequence: Hebrew comments render RTL (correct for reading), Latin keywords (`def`, `return`) render LTR (correct). **No special code-block handling required.** This is a key win of the run-level approach over line-level MEDIUM.

### 3.3 Hebrew in tables / tree drawings (├─ └─ │)

Tree-drawing chars (U+2500–U+257F) are BiDi class ON (Other Neutral). Our injector doesn't touch them. They render as written. Hebrew between them gets bracketed. Visual: tree lines stay in place, Hebrew inside the tree cells reads right-to-left.

Potential issue: alignment. If a Hebrew word takes different visual width than terminal-estimated width after BiDi, tree columns may shift. Only observable at the last column. Low priority - ink's own width math is already imprecise for RTL content.

### 3.4 Cursor-positioning ANSI mid-Hebrew-run

Unlikely but possible: `\x1b[38;5;16m...שלו\x1b[1Cם...` - ink might reposition cursor mid-word during a partial redraw.

Handling: our ANSI state machine treats the cursor-move sequence as a transparent pass-through. The Hebrew text on either side is still bracketed by our algorithm. The bracket stays open across the ANSI escape (because `insideRun` persists through ANSI passes). If ink did split a Hebrew word with a cursor move, the visual result depends on Konsole's redraw: probably fine because Konsole's cell grid treats the Hebrew cells individually and applies BiDi per the cell's paragraph.

### 3.5 Paste operations (bracketed paste mode)

Claude Code enables bracketed paste (`\x1b[?2004h`). Pasted text arrives wrapped in `\x1b[200~...\x1b[201~`. Our injector treats these as ANSI escapes - passes them through - and brackets Hebrew inside as usual. No special handling needed.

### 3.6 Alt-screen buffer transitions (`\x1b[?1049h`, `\x1b[?1049l`)

Switches between main and alt screen. ANSI state machine passes them through. No bracket changes. On screen restore, the saved screen may contain unbracketed Hebrew from before the switch - but that rendered fine before (our wrapper was active then too). No action required.

### 3.7 Right-aligned English inside an otherwise-Hebrew line

Example: `‏הקוד הוא def foo():` - Hebrew run closes at the space before "def", Latin run unbracketed, rest of line LTR-classified.

Our algorithm produces: `‫הקוד הוא‬ def foo():`. Paragraph direction: line starts with RLE (strong R) and Hebrew (strong R), so until the PDF the line is RTL. After PDF, remaining Latin is rendered by its own classification. Terminal should display: Hebrew words right-side-up on the right side of the line, Latin `def foo():` in natural LTR on the left (or integrated visually as expected for mixed Hebrew-Latin lines).

If this doesn't look right, fallback: also emit RLE/PDF around contiguous-Hebrew-then-whitespace sequences *plus* wrap the whole line in a paragraph-level direction hint. More complex; try without first.

### 3.8 Very long Hebrew runs that span multiple chunks

Handled by the `insideRun` cross-chunk state. Chunk boundaries emit PDF; next chunk opens with RLE if Hebrew continues. One extra bracket pair per chunk boundary; visually invisible.

### 3.9 Bracket-pair pairing under error conditions

If the wrapper crashes mid-run, the running terminal may have an unclosed RLE. Konsole handles unclosed embeddings at end-of-paragraph by implicitly popping levels. Not worse than current (broken) behavior. On wrapper restart, state resets clean.

---

## 4. No Konsole profile dependency

HEAVY does not depend on `BidiLineLTR=false` or any other Konsole profile setting. The profile audit from MEDIUM §4 is **dropped**.

Replaced with a single BiDi capability check at startup:

```bash
# If $TERM is plainly incompatible, warn and continue (user may be redirecting output)
case "$TERM" in
  dumb|"")    echo "kivun-claude-bidi: unusual TERM='$TERM'; BiDi may not render." 1>&2 ;;
  *)          # xterm-256color, xterm, screen, tmux-256color, konsole-* - all fine
              ;;
esac
```

That's it. No profile read, no version check, no content validation. The wrapper runs the same regardless of which Konsole profile is active, which Konsole version is installed, or which terminal-emulator is hosting it - as long as the terminal honors RLE/PDF (Assumption B).

### Consequence: lower operational risk

MEDIUM's top-two risks (`User hand-edits profile`, `User switches Konsole profile mid-session`) disappear entirely under HEAVY. The wrapper doesn't care about the profile.

---

## 5. Terminal detection - looser than MEDIUM

MEDIUM rejects non-Konsole terminals (exit code 5). HEAVY can, in principle, work in any BiDi-capable terminal.

V1 policy: still restrict to Konsole for now, because testing exposure is Konsole-only.
V2 policy: open up to known-good terminals (gnome-terminal with VTE, alacritty with BiDi enabled, Windows Terminal with Hebrew font). Each added terminal requires its own small integration test (the three `printf` lines from §1).

Detection code paths: same as MEDIUM §5 for v1. Widen the allowlist in v2.

---

## 6. File layout - near-identical to MEDIUM

```
kivun-claude-bidi/
├── package.json
├── bin/
│   └── kivun-claude-bidi
├── lib/
│   ├── wrapper.js                  # shared with MEDIUM; near-identical main loop
│   ├── injector.js                 # HEAVY version: RLE/PDF bracket state machine
│   ├── capability-check.js         # replaces MEDIUM's audit.js; much smaller
│   └── detect-terminal.js          # shared
├── test/
│   ├── injector.test.js            # HEAVY fixtures (see §7)
│   ├── capability.test.js
│   └── smoke.sh
└── README.md
```

Install targets: identical to MEDIUM's revised §6 (userspace, `~/.local/share/kivun-terminal/claude-bidi/`, `~/.local/bin/claude-bidi`, launcher exec path). No Konsole profile installation step required (but Kivun's installer still ships the profile for other reasons - color scheme, cursor, etc.).

---

## 7. Testing plan

### Unit - injector fixtures

Input/output string pairs. Each asserts byte-exact output:

1. **Plain ASCII line** - no brackets.
2. **Pure Hebrew line** - one RLE at start, one PDF at end (or before `\n`).
3. **Hebrew run inside Latin** - `Hello שלום world` → `Hello ‫שלום‬ world`.
4. **Multiple Hebrew runs separated by Latin** - each Hebrew run gets its own pair.
5. **Hebrew-space-Hebrew** - one pair for the whole `שלום עולם` (space inside run per §2 rule).
6. **Hebrew-comma-Hebrew** - one pair across the comma.
7. **Hebrew-period-English** - Hebrew run closes at period; period passed through unbracketed.
8. **Hebrew inside parens** - `(שלום)` → `(‫שלום‬)`. Paren stays outside brackets.
9. **ANSI SGR mid-Hebrew run** - bracket stays open through the color change.
10. **Chunk boundary mid-Hebrew run** - PDF emitted at chunk end; RLE re-emitted at start of next chunk (if it continues with Hebrew).
11. **Chunk boundary mid-UTF-8 codepoint** - StringDecoder buffers; output correct when chunks concatenated.
12. **Chunk boundary mid-CSI escape** - ANSI state machine resumes correctly; bracket state preserved.
13. **`\n` inside Hebrew run** - PDF before `\n`; new line starts fresh.
14. **Hebrew presentation forms (U+FB1D–FB4F)** - treated same as Hebrew block.
15. **Emoji between Hebrew runs** - emoji (outside Hebrew block) causes bracket to close; bracket reopens at next Hebrew.
16. **Long Hebrew paragraph (~500 chars)** - single bracket pair; no corruption.
17. **Bracketed-paste sequence containing Hebrew** - paste boundaries pass through; Hebrew inside gets bracketed.
18. **Alt-screen toggle with Hebrew on both sides** - toggle passes through; brackets in each screen section correctly balanced.

At least 18 fixtures. MEDIUM had 8. HEAVY's extra complexity demands broader coverage.

### Capability check unit tests

Much smaller than MEDIUM's audit suite:
1. `TERM=dumb` → warning, continue.
2. `TERM=xterm-256color` → pass silently.
3. `TERM=` (unset) → warning, continue.

### Smoke - fake-claude with Hebrew fixtures

Same as MEDIUM's `test/smoke.sh`, plus a Hebrew-heavy fake-claude that emits all 18 fixture types. Visual result reviewed by screenshot comparison.

### Integration gate - §1

The three `printf` lines in real Konsole. Required before tag. Same gate as MEDIUM; near-guaranteed to pass under Assumption B.

### Stress

Pipe a 10 MB Hebrew/Latin mix through the wrapper. Target: ≥1 MB/s. Same as MEDIUM.

### Production-canary

Run with the wrapper against claude for 1 full day of the lead dev's actual use before release. If anything looks off visually, report. Qualitative but catches integration-level bugs.

---

## 8. Risks & mitigations - slimmer than MEDIUM

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Terminal doesn't support RLE/PDF (rare on modern; can happen on obscure terminals) | Very low | High (Hebrew stays reversed or brackets display as visible boxes) | Capability check + integration gate catches this class at install/release time |
| ink changes stream pattern in a future Claude Code release | Low per release | Medium (detection may skip some runs) | Smoke tests per Claude Code version |
| RLE/PDF leak direction into adjacent Latin (unlikely but possible if terminal's BiDi is non-conforming) | Very low | Medium-visual | Fallback in v2: switch to RLI/PDI isolates (one constant change) |
| Hebrew followed by parentheses/brackets/quotes looks odd (BiDi's paired-bracket rules vs our closure heuristic) | Medium | Low-visual | Documented in §2 punctuation rule; integration gate shows if users perceive it |
| Copy/paste from terminal includes visible bracket chars on some terminals | Low (modern terminals hide them) | Low-cosmetic | Documented user-facing note: "Pasted text may contain zero-width direction marks; strip with `tr -d '‫‬'` if needed." |
| User's Claude Code output contains Arabic, not Hebrew | Currently out-of-scope | High (wrapper ignores) | v2 feature flag: `KIVUN_BIDI_WRAP_ARABIC=1` widens the detection predicate |

**Dropped from MEDIUM's list:**
- `User hand-edits profile and flips BidiLineLTR` - profile no longer matters.
- `User switches Konsole profile mid-session` - same.
- `Konsole drops/renames BidiLineLTR` - same.
- `node-pty fails to build` - still applies; dedup'd via shared installer requirements.

HEAVY's risk profile is strictly smaller. This is the operational argument for HEAVY.

### Non-goals (added 2026-04-24)

**Do not substitute directional characters.** Direction comes from BiDi
markers only, never from character substitution. Arrows
(`→ ← ↑ ↓`), box-drawing characters (`├ └ │ ─ ┌ ┐ ┘ ┤`), and other
directionally-asymmetric glyphs must pass through unchanged.

[Lidor Mashiach's Adaptive-RTL-Extension](https://github.com/Lidor-Mashiach/Adaptive-RTL-Extension)
substitutes `→` ↔ `←` in Hebrew paragraphs - that is correct for DOM
content but **wrong for terminal output** because tree renderers and
status indicators in Claude Code rely on the original glyph. Future
contributors must resist adding character substitution.

This non-goal is enforced by absence: `lib/injector.js` has no
character-mapping table and a comment at the top of the file reiterates
the constraint to catch well-intentioned PRs. See
`docs/specs/BIDI_ALGORITHM.md` for the full algorithm rationale and the
documented limitation around tree-visual reordering on Hebrew lines.

---

## 9. MEDIUM vs HEAVY decision matrix

Use this to pick post-gate.

| Dimension | MEDIUM | HEAVY |
| --- | --- | --- |
| Lines of code | ~300 | ~500 |
| Konsole profile dependency | Yes (`BidiLineLTR=false` required) | No |
| Silent-failure modes | Profile drift; mid-session profile switch | None under Assumption B |
| Portability to non-Kivun Konsole profiles | Requires user to set profile | Works in any BiDi terminal |
| Integration-gate risk | Medium (Assumption A is not trivially true) | Low (Assumption B is near-universal) |
| Install-time audit complexity | High (content-validated, fail-loud, every run) | Low (TERM check only) |
| Code in injector | ~60 lines | ~140 lines |
| Edge cases to document | 6 | 9 (§3.1–3.9) |
| Ongoing maintenance cost | Medium (audit must track Konsole releases) | Low |
| Time-to-ship estimate | 2–3 days | 3–4 days |

**Default recommendation after MEDIUM integration-gate result:**

- Gate passes → ship MEDIUM. HEAVY stays in the drawer. MEDIUM is smaller and simpler; the gate proved the assumption.
- Gate fails → ship HEAVY. MEDIUM's core premise is invalid in Kivun's actual terminal environment.
- Gate inconclusive (couldn't run the test) → ship HEAVY anyway. Lower risk, and without the gate, MEDIUM's assumption is unverified.

---

## 10. Deliverable checklist

- [ ] `lib/injector.js` with the 18 fixture tests.
- [ ] `lib/capability-check.js` with 3 fixture tests.
- [ ] `lib/detect-terminal.js` - reuse from MEDIUM if it was built first.
- [ ] `lib/wrapper.js` - adapted from MEDIUM's wrapper (replace `injectRlmAtLineStarts` with the HEAVY injector; drop the audit call).
- [ ] `bin/kivun-claude-bidi` entrypoint - shared.
- [ ] `test/smoke.sh` - HEAVY version with 18-fixture fake-claude.
- [ ] README covering install, usage, the `KIVUN_BIDI_WRAP_ARABIC=1` v2 placeholder, copy/paste bracket-stripping note.
- [ ] Exit code documentation (0 clean, 2 missing node-pty, 5 wrong terminal - no exit codes 3 and 4 from MEDIUM since no audit).
- [ ] §1 integration gate result (text note in repo with machine, Konsole version, observed rendering).
- [ ] Production-canary day result (one-line note: "ran for full day 2026-MM-DD, no visual issues observed").

---

## 11. What NOT to do

- Don't add the MEDIUM audit as an "extra safety." Audits that can't fail add code and test burden with no benefit. HEAVY doesn't need it.
- Don't switch to RLI/PDI isolates in v1 without an empirical reason. The one-line constant change is cheap but churns the test fixtures.
- Don't attempt the full xterm.js state machine. If HEAVY isn't enough, that's a "terminal doesn't support UAX #9" problem, not an "HEAVY is insufficient" problem. Different escalation.
- Don't ship with just the capability check passing on developer machine - the integration gate is still required. Capability check confirms the terminal isn't blatantly broken; integration gate confirms the rendering actually looks right.
- Don't include Arabic in v1 unless specifically requested. Scope creep. `KIVUN_BIDI_WRAP_ARABIC=1` env flag is the v2 on-switch.

---

## 12. Triggering conditions

Build HEAVY if any of:

1. MEDIUM's §1 integration gate fails (Assumption A invalid).
2. MEDIUM ships but users report silent-degradation issues from profile drift or mid-session profile switch.
3. Kivun product expands to support non-KivunTerminal Konsole configurations (e.g., "power users who keep their own profile").
4. Kivun product expands to non-Konsole terminals.

If none of the above, HEAVY stays in the drawer. MEDIUM is lighter and sufficient.

---

**Ship-readiness:** this spec is executable today. Begin builds only after Noam greenlights (per MEDIUM's build-approval rule) and only for the architecture that was selected post-gate.
