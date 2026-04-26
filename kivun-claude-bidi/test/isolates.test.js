'use strict';

// Regression tests for KIVUN_BIDI_USE_ISOLATES (added in v1.1.9 spike).
//
// Background: a real-user report on Ubuntu 24.04 + Konsole 23.08.5
// (after the v1.1.8 bullet-strip fix landed) showed that mixed
// RTL/LTR content like:
//
//   אנחנו עובדים עם React 19 ו-Next.js 15 כדי לבנות את הפלטפורמה
//
// renders with LTR runs ("React 19", "Next.js 15") in unexpected
// visual positions — e.g., "React 19" lands at the right edge of the
// line instead of between the third and fourth Hebrew word. Per
// Unicode UAX #9 in an RTL paragraph, LTR runs should render with
// internal L→R reading but be positioned within the RTL flow. Konsole
// 23.x's BiDi engine doesn't always honor this for embeds (RLE/PDF).
//
// Isolates (RLI/PDI) form a stronger directional boundary than embeds
// and may render mixed content correctly on broken engines. This
// option lets users test that workaround.

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

function loadInjector(envValue) {
  delete require.cache[require.resolve('../lib/injector')];
  const prev = process.env.KIVUN_BIDI_USE_ISOLATES;
  if (envValue === undefined) delete process.env.KIVUN_BIDI_USE_ISOLATES;
  else process.env.KIVUN_BIDI_USE_ISOLATES = envValue;
  try {
    return require('../lib/injector');
  } finally {
    if (prev === undefined) delete process.env.KIVUN_BIDI_USE_ISOLATES;
    else process.env.KIVUN_BIDI_USE_ISOLATES = prev;
  }
}

function runOnce(mod, input) {
  const inj = new mod.Injector();
  return inj.write(Buffer.from(input, 'utf8')) + inj.end();
}

const RLI = '⁧';
const PDI = '⁩';
const RLE_CHAR = '‫';
const PDF_CHAR = '‬';

describe('KIVUN_BIDI_USE_ISOLATES=on (Konsole 23.x mixed-content workaround)', () => {
  const mod = loadInjector('on');

  it('uses RLI (U+2067) instead of RLE for the run opener', () => {
    assert.equal(mod.RLE, RLI);
  });

  it('uses PDI (U+2069) instead of PDF for the run closer', () => {
    assert.equal(mod.PDF, PDI);
  });

  it('wraps Hebrew run with RLI...PDI on a Hebrew-first line', () => {
    const out = runOnce(mod, 'שלום\n');
    assert.equal(out, mod.RLM + RLI + 'שלום' + PDI + '\n');
  });

  it('mixed-content line uses isolates around each Hebrew run', () => {
    // Three Hebrew runs separated by English. Each Hebrew run gets
    // its own RLI/PDI bracket (no leakage of direction context to
    // adjacent LTR runs — that's the whole point of isolates).
    const out = runOnce(mod, 'שלום React עולם Vue\n');
    assert.equal(
      out,
      mod.RLM + RLI + 'שלום' + PDI + ' React ' + RLI + 'עולם' + PDI + ' Vue\n',
    );
  });
});

describe('KIVUN_BIDI_USE_ISOLATES=off (default = embeds)', () => {
  const mod = loadInjector('off');

  it('uses RLE (U+202B) for the run opener — historical default', () => {
    assert.equal(mod.RLE, RLE_CHAR);
  });

  it('uses PDF (U+202C) for the run closer — historical default', () => {
    assert.equal(mod.PDF, PDF_CHAR);
  });

  it('wraps Hebrew run with RLE...PDF on a Hebrew-first line', () => {
    const out = runOnce(mod, 'שלום\n');
    assert.equal(out, mod.RLM + RLE_CHAR + 'שלום' + PDF_CHAR + '\n');
  });
});

describe('KIVUN_BIDI_USE_ISOLATES unset (default = off, matches v1.1.x)', () => {
  const mod = loadInjector(undefined);

  it('falls back to embed behavior — no surprise for default users', () => {
    assert.equal(mod.RLE, RLE_CHAR);
    assert.equal(mod.PDF, PDF_CHAR);
  });
});
