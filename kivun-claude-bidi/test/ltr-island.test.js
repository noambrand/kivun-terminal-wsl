'use strict';

// HEAVY §1a — Mixed-line LTR-island fixtures.
//
// Hebrew-dominant lines containing embedded English tokens. These are the
// real-world cases from CLAUDE_CODE_TASK_HEAVY_BUILD_AND_README.md §1a:
// the user wants to verify RLE/PDF alone is sufficient, or upgrade to
// LRI/PDI (⁦/⁩) if Latin tokens render in wrong RTL-relative
// position or with mirrored punctuation.
//
// Algorithm chosen: RLE/PDF only. The current injector closes the Hebrew
// run at the boundary into Latin (commitPendingOutside emits PDF), then
// re-opens it when Hebrew resumes. The Latin/punctuation/numeric run
// between two PDF/RLE bracket pairs sits at base level (paragraph
// direction RTL via the line-start RLM), so UAX #9 reordering places it
// correctly relative to the surrounding Hebrew runs and preserves its
// internal LTR order. See docs/specs/BIDI_ALGORITHM.md for the full
// rationale and the LRI/PDI alternative considered.

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { Injector, RLE, PDF, RLM } = require('../lib/injector');

function runOnce(input) {
  const inj = new Injector();
  return inj.write(Buffer.from(input, 'utf8')) + inj.end();
}

describe('HEAVY §1a — Mixed-line LTR-island fixtures', () => {
  it('Hebrew + arrow + English + arrow + Hebrew (קלט → Process → תוצאה)', () => {
    // Two Hebrew runs flank a Latin token; arrows are bidi-neutral and
    // get directional class from surroundings per UAX #9 N1/N2.
    assert.equal(
      runOnce('קלט → Process → תוצאה\n'),
      RLM + RLE + 'קלט' + PDF + ' → Process → ' + RLE + 'תוצאה' + PDF + '\n',
    );
  });

  it('Hebrew prose with embedded npm command (הפעלה של npm install אמורה לעבוד)', () => {
    // Tests that `npm install` (with internal space) gets one combined
    // PDF/RLE bracket, not split per-token. The space between `npm` and
    // `install` is NOT pending-buffered because we're outside the Hebrew
    // run when we see it.
    assert.equal(
      runOnce('הפעלה של npm install אמורה לעבוד\n'),
      RLM + RLE + 'הפעלה של' + PDF + ' npm install ' + RLE + 'אמורה לעבוד' + PDF + '\n',
    );
  });

  it('Hebrew + filename + Hebrew + path (קובץ config.txt נמצא ב-~/.local/share/)', () => {
    // The hyphen `-` immediately after Hebrew `ב` triggers run close
    // (hyphen isn't EXTENDABLE_PUNCT). Path tokens with `~`, `/`, `.`
    // pass through unchanged. Period inside `config.txt` is buffered as
    // EXTENDABLE_PUNCT but doesn't trigger run-close because we're not
    // inside a Hebrew run when we see it.
    assert.equal(
      runOnce('קובץ config.txt נמצא ב-~/.local/share/\n'),
      RLM + RLE + 'קובץ' + PDF + ' config.txt ' + RLE + 'נמצא ב' + PDF + '-~/.local/share/\n',
    );
  });

  it('Hebrew + filename.ext (שגיאה ב-line 42 של injector.js)', () => {
    // Numeric "42" sits in its own LTR-classified neutral region; per
    // UAX #9 numerics are weak and resolve to the base direction context.
    // injector.js with the period is one Latin token after the second
    // Hebrew run closes.
    assert.equal(
      runOnce('שגיאה ב-line 42 של injector.js\n'),
      RLM + RLE + 'שגיאה ב' + PDF + '-line 42 ' + RLE + 'של' + PDF + ' injector.js\n',
    );
  });

  it('non-substitution: arrows pass through unchanged (HEAVY §8 non-goal)', () => {
    // No ↔ swap, no glyph mirroring at the wrapper layer. Arrows are
    // direction-neutral; rendering relies on the terminal's BiDi engine
    // to position them correctly within the resolved run order.
    const input = 'a → b ← c ↑ d ↓ e\n';
    // No Hebrew at all → no RLM, no RLE/PDF, output identical to input.
    assert.equal(runOnce(input), input);
  });

  it('non-substitution: box-drawing chars pass through unchanged (HEAVY §8)', () => {
    // Tree renderers (e.g. plan-mode output) use ├ └ │ ─ ┌ ┐ ┘ ┤. These
    // are direction-neutral and must NOT be substituted with mirrored
    // variants when surrounded by Hebrew. Note: with line-start RLM
    // injection, the paragraph direction becomes RTL when the first
    // strong char on the line is Hebrew — this reorders the tree chars'
    // visual position. That is a documented tradeoff in
    // BIDI_ALGORITHM.md (Hebrew rendering correctness wins over tree
    // visuals). The non-goal here is character SUBSTITUTION; visual
    // reordering by the BiDi engine is expected.
    const input = '├─ שלום\n│  └─ עולם\n';
    assert.equal(
      runOnce(input),
      RLM + '├─ ' + RLE + 'שלום' + PDF + '\n' + RLM + '│  └─ ' + RLE + 'עולם' + PDF + '\n',
    );
    // Verify no character substitution occurred — the box chars are
    // byte-for-byte identical in input and output (modulo the RLM/RLE/PDF
    // controls, which are zero-width).
    const out = runOnce(input);
    for (const ch of '├─│└') {
      assert.ok(out.includes(ch), `box-drawing char ${ch} must pass through unchanged`);
    }
  });
});
