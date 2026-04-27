'use strict';

// FLATTEN_COLORS_RTL was added in v1.1.10 and defaults on. The "preserves
// leading ANSI color codes around the stripped bullet" test below was
// written against legacy SGR-passthrough behavior, so we explicitly opt
// out of FLATTEN here. The new FLATTEN-on behavior is exercised in
// test/flatten-colors-rtl.test.js.
process.env.KIVUN_BIDI_FLATTEN_COLORS_RTL = 'off';

// Regression tests for KIVUN_BIDI_STRIP_BULLET (added in v1.1.8).
//
// Background: a real-user report (Ubuntu 24.04 + Konsole 23.08.5) showed
// that Hebrew bullet lines from Claude Code render with the bullet on
// the LEFT side of the screen, even though:
//   - the wrapper injects RLM at line-start,
//   - Konsole 23.x honors RLM at line-start in static printf tests,
//   - the bracket+RLM combination renders right-aligned in isolation.
//
// Empirical finding: Konsole 23.x classifies the leading `●` (U+25CF
// BLACK CIRCLE) as a direction-anchoring neutral char, which keeps the
// line LTR even with RLM at start. Removing the bullet means the first
// visible char is Hebrew and Konsole's BiDi flips the line RTL
// automatically — no special markers needed.
//
// These tests pin the strip behavior so a future "let's clean up the
// old workaround" PR can't silently undo it.

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

// The injector reads KIVUN_BIDI_STRIP_BULLET at module load. To test
// both env values without subprocesses, invalidate the require cache and
// flip the env around each load.
function loadInjector(envValue) {
  delete require.cache[require.resolve('../lib/injector')];
  const prev = process.env.KIVUN_BIDI_STRIP_BULLET;
  if (envValue === undefined) delete process.env.KIVUN_BIDI_STRIP_BULLET;
  else process.env.KIVUN_BIDI_STRIP_BULLET = envValue;
  try {
    return require('../lib/injector');
  } finally {
    if (prev === undefined) delete process.env.KIVUN_BIDI_STRIP_BULLET;
    else process.env.KIVUN_BIDI_STRIP_BULLET = prev;
  }
}

function runOnce(mod, input) {
  const inj = new mod.Injector();
  return inj.write(Buffer.from(input, 'utf8')) + inj.end();
}

describe('KIVUN_BIDI_STRIP_BULLET=on (Konsole 23.x bullet-LTR workaround)', () => {
  const mod = loadInjector('on');
  const { RLE, PDF, RLM } = mod;

  it('strips leading ● + space on a Hebrew line so BiDi sees Hebrew first', () => {
    // Without strip: RLM + '● ' + RLE + 'שלום' + PDF + '\n'
    // With strip: RLM + RLE + 'שלום' + PDF + '\n' — bullet and space gone
    const out = runOnce(mod, '● שלום\n');
    assert.equal(out, RLM + RLE + 'שלום' + PDF + '\n');
  });

  it('does NOT strip ● on a Latin-first line (no RLM injection, no strip applied)', () => {
    // Strip only fires when injectRlm=true (i.e., the line is Hebrew).
    // English bullet lines must keep their bullet so users still see
    // list structure for English content.
    const out = runOnce(mod, '● hello world\n');
    assert.equal(out, '● hello world\n');
  });

  it('strips multiple ● if Claude emits more than one before Hebrew', () => {
    // Defensive: not a real Claude pattern, but the regex is global so
    // pin the behavior. Multiple bullets + their adjacent whitespace
    // all collapse to nothing.
    const out = runOnce(mod, '● ● שלום\n');
    assert.equal(out, RLM + RLE + 'שלום' + PDF + '\n');
  });

  it('preserves leading ANSI color codes around the stripped bullet', () => {
    // Claude wraps bullet markers in color codes like \x1b[38;5;174m●\x1b[39m.
    // The strip regex removes ONLY the bullet glyph itself; SGR
    // sequences and any whitespace AFTER the SGR remain untouched.
    // (The regex matches ●\s* greedily, but only when ● is immediately
    // followed by whitespace; if a SGR reset comes between them, the
    // trailing space survives.)
    const RED = '\x1b[31m';
    const RST = '\x1b[0m';
    const out = runOnce(mod, RED + '●' + RST + ' שלום\n');
    assert.equal(out, RLM + RED + RST + ' ' + RLE + 'שלום' + PDF + '\n');
  });

  it('leaves non-Hebrew bullet variants (✻, *, -) untouched', () => {
    // The strip regex deliberately matches only `●` (U+25CF). Other
    // bullet-like glyphs Claude emits — ✻ for "responding now", * for
    // some markdown — are NOT stripped because the user empirically
    // confirmed (v1.1.8) those don't trigger Konsole's LTR-anchoring
    // bug. Adding them to the regex would lose more visual structure
    // than necessary.
    const out = runOnce(mod, '✻ שלום\n');
    // ✻ is neutral, doesn't get stripped, BUT the line still gets RLM
    // because the first strong char is Hebrew. With ✻ at line start it
    // still renders RTL on Konsole (verified by user).
    assert.equal(out, RLM + '✻ ' + RLE + 'שלום' + PDF + '\n');
  });
});

describe('KIVUN_BIDI_STRIP_BULLET=off (legacy v1.1.0–v1.1.7 behavior)', () => {
  const mod = loadInjector('off');
  const { RLE, PDF, RLM } = mod;

  it('preserves the ● on Hebrew lines (the broken-but-historical default)', () => {
    // Pin the off-behavior so an accidental "always strip" refactor
    // would fail this test loudly.
    const out = runOnce(mod, '● שלום\n');
    assert.equal(out, RLM + '● ' + RLE + 'שלום' + PDF + '\n');
  });
});

describe('KIVUN_BIDI_STRIP_BULLET unset (default = off, matches v1.1.7)', () => {
  const mod = loadInjector(undefined);
  const { RLE, PDF, RLM } = mod;

  it('matches the off behavior — no strip when env is not set', () => {
    // The unit-test default is "env not set" which must equal "off".
    // The end-user default is "on" — set by kivun-launch.sh based on
    // config.txt — but the wrapper itself must default off so existing
    // unit fixtures and direct-invocation users see no surprise.
    const out = runOnce(mod, '● שלום\n');
    assert.equal(out, RLM + '● ' + RLE + 'שלום' + PDF + '\n');
  });
});
