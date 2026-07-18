'use strict';

// F1 (v1.7.1) — LTR-island fixtures against the SHIPPING DEFAULT env combo.
// See core-defaults.test.js for rationale. ltr-island.test.js pins the legacy
// combo (per-run RLE/PDF around every Hebrew run). Under the shipping defaults
// (FLATTEN_COLORS_RTL='on', BRACKET_RTL_RUNS='off'), an RTL line (first strong
// char Hebrew) receives ONLY a leading RLM: no per-run RLE/PDF at all. The
// Latin islands sit at base level and UAX #9 reorders them relative to the
// Hebrew — that is the whole point of the no-bracket default (fewer injected
// marks in copy/scrollback, one continuous BiDi region for Konsole).
//
// The non-substitution guarantee (HEAVY §8) is unchanged: arrows and
// box-drawing chars still pass through byte-for-byte.
process.env.KIVUN_BIDI_FLATTEN_COLORS_RTL = 'on';
process.env.KIVUN_BIDI_BRACKET_RTL_RUNS = 'off';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { RLM } = require('../lib/injector');
const { Injector } = require('../lib/injector');

function runOnce(input) {
  const inj = new Injector();
  return inj.write(Buffer.from(input, 'utf8')) + inj.end();
}

describe('HEAVY §1a — LTR-island fixtures — SHIPPING DEFAULTS (FLATTEN=on, BRACKET=off)', () => {
  it('Hebrew + arrow + English + arrow + Hebrew — RLM prefix only, no brackets', () => {
    assert.equal(
      runOnce('קלט → Process → תוצאה\n'),
      RLM + 'קלט → Process → תוצאה\n',
    );
  });

  it('Hebrew prose with embedded npm command — RLM prefix only', () => {
    assert.equal(
      runOnce('הפעלה של npm install אמורה לעבוד\n'),
      RLM + 'הפעלה של npm install אמורה לעבוד\n',
    );
  });

  it('Hebrew + filename + Hebrew + path — RLM prefix only', () => {
    assert.equal(
      runOnce('קובץ config.txt נמצא ב-~/.local/share/\n'),
      RLM + 'קובץ config.txt נמצא ב-~/.local/share/\n',
    );
  });

  it('Hebrew + filename.ext + line number — RLM prefix only', () => {
    assert.equal(
      runOnce('שגיאה ב-line 42 של injector.js\n'),
      RLM + 'שגיאה ב-line 42 של injector.js\n',
    );
  });

  it('non-substitution: arrows pass through unchanged (no Hebrew → no RLM)', () => {
    const input = 'a → b ← c ↑ d ↓ e\n';
    assert.equal(runOnce(input), input);
  });

  it('non-substitution: box-drawing chars pass through unchanged, RLM prefix only', () => {
    const input = '├─ שלום\n│  └─ עולם\n';
    assert.equal(
      runOnce(input),
      RLM + '├─ שלום\n' + RLM + '│  └─ עולם\n',
    );
    // Box-drawing chars must survive byte-for-byte (no mirroring/substitution).
    const out = runOnce(input);
    for (const ch of '├─│└') {
      assert.ok(out.includes(ch), `box-drawing char ${ch} must pass through unchanged`);
    }
  });
});
