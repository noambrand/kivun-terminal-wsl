'use strict';

// Regression tests for KIVUN_BIDI_BRACKET_RTL_RUNS (v1.1.11).
//
// Background: v1.1.10 shipped FLATTEN_COLORS_RTL based on the
// hypothesis that ANSI SGR boundaries were splitting Konsole's BiDi
// runs and causing English/code fragments to land at the visual left
// edge of Hebrew sentences. v1.1.10 fixed PART of the problem (no
// more visible color codes), but real Claude output still showed
// misposition around `-` and `:`.
//
// April 2026 follow-up A/B test (`Kivun-BiDi-Deep-Test.bat`) ran the
// same problem strings three ways:
//   TEST A: plain printf, no wrapper involvement
//   TEST B: RLM at line-start only
//   TEST C: RLM + ONE RLE/PDF pair around the whole line
//
// All three rendered correctly. The thing v1.1.10 was still doing
// that broke rendering: emitting per-run RLE/PDF brackets — multiple
// pairs per line when the line had multiple Hebrew runs separated by
// LTR runs. Each PDF/RLE transition acts as an attribute-region
// boundary to Konsole, which is exactly what v1.1.10 FLATTEN_COLORS
// was supposed to eliminate.
//
// The fix: skip per-run bracketing on RTL lines. Hebrew runs INSIDE
// LTR paragraphs still get bracketed (they're the exception in an
// LTR flow and need the marker).
//
// Mode (KIVUN_BIDI_BRACKET_RTL_RUNS):
//   off — no per-run bracketing on RTL lines (default v1.1.11+)
//   on  — bracket every Hebrew run regardless (legacy v1.1.0 - v1.1.10)

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

function loadInjector(envValue) {
  delete require.cache[require.resolve('../lib/injector')];
  const prev = process.env.KIVUN_BIDI_BRACKET_RTL_RUNS;
  if (envValue === undefined) delete process.env.KIVUN_BIDI_BRACKET_RTL_RUNS;
  else process.env.KIVUN_BIDI_BRACKET_RTL_RUNS = envValue;
  try {
    return require('../lib/injector');
  } finally {
    if (prev === undefined) delete process.env.KIVUN_BIDI_BRACKET_RTL_RUNS;
    else process.env.KIVUN_BIDI_BRACKET_RTL_RUNS = prev;
  }
}

function runOnce(mod, input) {
  const inj = new mod.Injector();
  return inj.write(Buffer.from(input, 'utf8')) + inj.end();
}

describe('KIVUN_BIDI_BRACKET_RTL_RUNS=off (default v1.1.11+) — no per-run brackets on RTL lines', () => {
  const mod = loadInjector('off');
  const { RLE, PDF, RLM } = mod;

  it('Hebrew-only line: just RLM at line-start, no RLE/PDF', () => {
    const out = runOnce(mod, 'שלום\n');
    assert.equal(out, RLM + 'שלום\n');
    assert.ok(!out.includes(RLE), 'no RLE on RTL line');
    assert.ok(!out.includes(PDF), 'no PDF on RTL line');
  });

  it('mixed Hebrew+English on RTL line: no RLE/PDF around any run', () => {
    // The "Claude Code mid-Hebrew" pattern from the bug report.
    const out = runOnce(mod, 'אני משתמש ב-Claude Code-בעברית\n');
    assert.equal(out, RLM + 'אני משתמש ב-Claude Code-בעברית\n');
    assert.ok(!out.includes(RLE), 'no RLE inside RTL line');
    assert.ok(!out.includes(PDF), 'no PDF inside RTL line');
  });

  it('the React 19 pattern: no fragment markers, single RLM at start', () => {
    const out = runOnce(mod, 'אנחנו עובדים עם React 19 ו-Next.js 15\n');
    assert.equal(out, RLM + 'אנחנו עובדים עם React 19 ו-Next.js 15\n');
  });

  it('numbers + colon inside Hebrew: clean passthrough', () => {
    const out = runOnce(mod, 'מספרים: 1234 בעברית\n');
    assert.equal(out, RLM + 'מספרים: 1234 בעברית\n');
  });

  it('Hebrew run INSIDE an LTR line still gets bracketed (LTR is paragraph)', () => {
    // Line starts with Latin -> lineIsRTL = false -> per-run bracketing
    // still applies because the Hebrew is the exception in an LTR flow
    // and needs the direction marker.
    const out = runOnce(mod, 'Hello שלום world\n');
    assert.equal(out, 'Hello ' + RLE + 'שלום' + PDF + ' world\n');
  });

  it('still injects line-start RLM on Hebrew-first lines', () => {
    const out = runOnce(mod, 'שלום עולם\n');
    assert.ok(out.startsWith(RLM), 'RLM at line-start preserved');
  });

  it('does not inject RLM on Latin-first lines', () => {
    const out = runOnce(mod, 'plain English line\n');
    assert.ok(!out.startsWith(RLM), 'no RLM on LTR-first line');
  });

  it('multi-line: RTL line clean, then LTR line passes through, then RTL line clean again', () => {
    const inj = new mod.Injector();
    const out = inj.write(Buffer.from('שלום\nhello\nעולם\n', 'utf8')) + inj.end();
    assert.equal(out, RLM + 'שלום\nhello\n' + RLM + 'עולם\n');
  });

  it('integrates with strip-bullet: bullet stripped, no per-run bracket either', () => {
    const prev = process.env.KIVUN_BIDI_STRIP_BULLET;
    process.env.KIVUN_BIDI_STRIP_BULLET = 'on';
    try {
      const m = loadInjector('off');
      const out = runOnce(m, '● שלום\n');
      // Bullet stripped + no RLE/PDF brackets + RLM at start
      assert.equal(out, m.RLM + 'שלום\n');
    } finally {
      if (prev === undefined) delete process.env.KIVUN_BIDI_STRIP_BULLET;
      else process.env.KIVUN_BIDI_STRIP_BULLET = prev;
    }
  });
});

describe('KIVUN_BIDI_BRACKET_RTL_RUNS=on (legacy v1.1.0 - v1.1.10 behavior)', () => {
  const mod = loadInjector('on');
  const { RLE, PDF, RLM } = mod;

  it('Hebrew-only line: RLE/PDF around the run as in v1.1.0', () => {
    const out = runOnce(mod, 'שלום\n');
    assert.equal(out, RLM + RLE + 'שלום' + PDF + '\n');
  });

  it('mixed Hebrew+English: per-run brackets (the v1.1.10 behavior that broke positioning)', () => {
    const out = runOnce(mod, 'אני ב-Code-בעברית\n');
    // Multiple Hebrew runs separated by Latin -> multiple RLE/PDF pairs
    // emitted under legacy. (This is exactly the pattern v1.1.11 fixes
    // by NOT emitting these.)
    assert.ok(out.includes(RLE), 'legacy emits RLE');
    assert.ok(out.includes(PDF), 'legacy emits PDF');
  });
});

describe('KIVUN_BIDI_BRACKET_RTL_RUNS unset (defaults to off)', () => {
  const mod = loadInjector(undefined);
  const { RLE, PDF, RLM } = mod;

  it('matches off-mode — no per-run brackets on RTL line by default', () => {
    const out = runOnce(mod, 'שלום עולם\n');
    assert.equal(out, RLM + 'שלום עולם\n');
  });
});
