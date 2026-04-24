# BiDi Algorithm — `kivun-claude-bidi` wrapper

This document records the algorithm chosen for the `kivun-claude-bidi`
wrapper that ships in Kivun Terminal v1.1.0. It exists because
`CLAUDE_CODE_TASK_RTL_WRAPPER_HEAVY.md` left the Hebrew/English mixed-line
case open ("verify RLE/PDF suffices, upgrade to LRI/PDI if not"); this doc
records the decision and the test evidence behind it.

## TL;DR

The wrapper uses **RLE (U+202B) / PDF (U+202C) bracketing for Hebrew runs +
RLM (U+200F) injection at line start when the line's first strong char is
RTL**. No LRI/PDI isolates. No character substitution.

## Three algorithms considered

### Option A — RLE/PDF only (chosen)

For each Hebrew run in the output stream, emit `RLE + run + PDF`. For each
line whose first strong character is RTL, emit `RLM` at position 0 to set
paragraph direction.

- **Strengths:** small, deterministic, no Unicode-version requirements
  beyond Unicode 6.3 (which all 2026-vintage terminals satisfy). Plays well
  with bidi-neutral chars (spaces, punctuation, arrows, box-drawing) by
  letting the terminal's UAX #9 engine resolve their direction from
  surrounding strong chars.
- **Weaknesses:** Latin tokens embedded inside a Hebrew-dominant line are
  at "even" embedding level inside an "odd" paragraph — UAX #9 reordering
  places them correctly relative to surrounding Hebrew runs but their
  absolute position depends on the terminal's BiDi engine behaving
  consistently. Empirically confirmed on Konsole 22.04+; may differ on
  other terminals.

### Option B — RLE/PDF + LRI/PDI for embedded Latin tokens

Same as A, plus: when the wrapper detects a Latin run **inside** a
Hebrew-dominant line, wrap that Latin run in `LRI (U+2066) ... PDI
(U+2069)` to give it its own isolation level.

- **Strengths:** more explicit; would unambiguously force Latin tokens to
  their natural position regardless of BiDi engine quirks.
- **Weaknesses:** detecting "Hebrew-dominant line" requires line-level
  buffering beyond what we already do for line-start RLM; the policy "what
  counts as a Latin run that needs isolation" gets fuzzy (a single English
  word? a path? a number?). Unicode 6.3+ requirement is a non-issue but
  worth flagging.

### Option C — full xterm.js-style headless BiDi state machine

Reimplement the UAX #9 reordering ourselves and emit pre-reordered output
to the terminal.

- **Strengths:** terminal-agnostic; works even on emulators with broken
  BiDi engines.
- **Weaknesses:** months of work, large maintenance surface, duplicates
  what every modern terminal already does. **Rejected as over-engineering**
  per HEAVY spec §8.

## Decision: Option A

The §1a fixtures (`test/ltr-island.test.js`) cover the four real-world
mixed-line cases the user prioritized:

1. `קלט → Process → תוצאה` — Hebrew/Latin/Hebrew with arrow neutrals.
2. `הפעלה של npm install אמורה לעבוד` — Hebrew prose with multi-token
   Latin command in the middle.
3. `קובץ config.txt נמצא ב-~/.local/share/` — Hebrew + filename + Hebrew
   + path.
4. `שגיאה ב-line 42 של injector.js` — Hebrew + Latin + numeric + Hebrew +
   filename.

All four pass with Option A: the wrapper emits exactly one RLM at line
start, opens RLE at each Hebrew run boundary, closes with PDF when the
boundary closes, and lets the terminal's BiDi engine handle the
reordering of the Latin/neutral runs between Hebrew runs.

The fifth and sixth fixtures verify HEAVY §8 — arrows (`→ ← ↑ ↓`) and
box-drawing chars (`├ └ │ ─`) pass through byte-for-byte unchanged.

If a future user reports Latin tokens rendering in the wrong position on
a specific terminal, the path forward is to upgrade to Option B for
**that terminal's output path only** — keep Option A as the default since
it's smaller and the empirical evidence shows it works on Konsole.

## Non-goal: character substitution (HEAVY §8)

Direction comes from BiDi markers only, never from character substitution.
Specifically:

- Arrows `→ ← ↑ ↓` pass through unchanged. We do **not** swap `→`↔`←` in
  Hebrew paragraphs even though some browser-extension RTL solutions
  ([Adaptive-RTL-Extension](https://github.com/Lidor-Mashiach/Adaptive-RTL-Extension))
  do this for DOM content.
- Box-drawing chars `├ └ │ ─ ┌ ┐ ┘ ┤` pass through unchanged. Tree
  renderers (plan-mode output, file trees, status indicators) rely on the
  original glyph; substituting mirrored variants would corrupt the visual
  semantics of those glyphs.
- Status indicators like `●` `⏺` `▶` pass through unchanged.

This is enforced by absence: `lib/injector.js` has no character-mapping
table. New contributors must resist adding one. There is a comment at the
top of `lib/injector.js` reiterating this constraint to catch
well-intentioned PRs.

## Documented limitation: tree visuals on Hebrew lines

Lines that begin with bidi-neutral box-drawing chars followed by Hebrew
(e.g. `├─ שלום`) get RLM at position 0 because the line's first **strong**
char is Hebrew. The neutral box chars then get reordered by the
terminal's BiDi engine to their RTL-relative position — visually, the
tree may render with the box chars on the right side of the line instead
of the left.

This is a deliberate tradeoff: Hebrew rendering correctness wins over
tree-visual preservation. Users who prefer tree-visual fidelity over
Hebrew correctness can disable the wrapper via `KIVUN_BIDI_WRAPPER=off`.
A v1.2.0 candidate is "no-RLM mode for lines containing tree chars" but
that's a behavior knob, not the default.
