'use strict';

// Regression tests for KIVUN_BIDI_FLATTEN_COLORS_RTL (added in v1.1.10).
//
// Background: empirical A/B test on Konsole 23.08.5 (April 2026) with
// the SAME Hebrew/English mixed text rendered with vs without ANSI SGR
// color codes confirmed that Konsole runs BiDi only on continuous
// attribute regions. Color changes split the BiDi run, and Qt's text
// layout positions the resulting fragments incorrectly — typically
// pushing English/code runs to the visual left edge instead of their
// UAX #9 logical position inside the Hebrew sentence. The freedesktop.org
// Terminal Working Group documented this same architectural limit:
//   https://terminal-wg.pages.freedesktop.org/bidi/prior-work/terminals.html
//
// The fix is to strip SGR codes from any line whose first strong char
// is Hebrew so the whole line is one attribute run and Konsole positions
// LTR runs at their logical positions. The trade-off is loss of syntax
// highlighting on Hebrew lines.
//
// Mode (KIVUN_BIDI_FLATTEN_COLORS_RTL):
//   off — passthrough; SGR codes reach Konsole as-is
//   on  — strip SGR (CSI...m) codes from RTL lines (default)
//
// What's stripped: only CSI sequences ending in `m` (the SGR final
// byte). Cursor positioning, screen-clear, scroll-region, OSC, etc. all
// pass through. LTR lines are NEVER affected.

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

function loadInjector(envValue) {
  delete require.cache[require.resolve('../lib/injector')];
  const prev = process.env.KIVUN_BIDI_FLATTEN_COLORS_RTL;
  if (envValue === undefined) delete process.env.KIVUN_BIDI_FLATTEN_COLORS_RTL;
  else process.env.KIVUN_BIDI_FLATTEN_COLORS_RTL = envValue;
  try {
    return require('../lib/injector');
  } finally {
    if (prev === undefined) delete process.env.KIVUN_BIDI_FLATTEN_COLORS_RTL;
    else process.env.KIVUN_BIDI_FLATTEN_COLORS_RTL = prev;
  }
}

function runOnce(mod, input) {
  const inj = new mod.Injector();
  const out = inj.write(Buffer.from(input, 'utf8')) + inj.end();
  return { out, inj };
}

const RED = '\x1b[31m';
const CYAN = '\x1b[36m';
const RST = '\x1b[0m';
const SGR_256 = '\x1b[38;5;174m'; // 256-color foreground (multi-param SGR)
const CURSOR_UP = '\x1b[A';       // CSI but NOT SGR — must pass through
const CLEAR_LINE = '\x1b[2K';     // CSI but NOT SGR — must pass through

describe('KIVUN_BIDI_FLATTEN_COLORS_RTL=on (default — strip SGR from RTL lines)', () => {
  const mod = loadInjector('on');
  const { RLE, PDF, RLM } = mod;

  it('drops a single SGR code on a Hebrew line', () => {
    const { out, inj } = runOnce(mod, RED + 'שלום' + RST + '\n');
    // Expected: RLM + (no RED) + RLE + שלום + PDF + (no RST) + \n
    assert.equal(out, RLM + RLE + 'שלום' + PDF + '\n');
    assert.equal(inj.flattenedSgrCount, 2, 'two SGR sequences should be counted as flattened');
  });

  it('drops mid-Hebrew SGR (Claude-style "color one word" pattern)', () => {
    const { out } = runOnce(mod, 'שלו' + RED + 'ם' + RST + '\n');
    assert.equal(out, RLM + RLE + 'שלום' + PDF + '\n');
  });

  it('drops multi-parameter SGR (e.g., 256-color foreground)', () => {
    const { out } = runOnce(mod, SGR_256 + 'שלום' + RST + '\n');
    assert.equal(out, RLM + RLE + 'שלום' + PDF + '\n');
  });

  it('drops SGR around inline English run inside Hebrew (the "React 19" pattern)', () => {
    const { out } = runOnce(mod, 'אנחנו עובדים עם ' + RED + 'React 19' + RST + ' היום\n');
    // SGR gone; English text and Hebrew text both present, wrapper bracketed
    assert.ok(!out.includes('\x1b'), 'no escape bytes should remain');
    assert.ok(out.includes('React 19'), 'English content must survive');
    assert.ok(out.includes('אנחנו עובדים עם'), 'Hebrew prefix must survive');
    assert.ok(out.includes('היום'), 'Hebrew suffix must survive');
    assert.ok(out.startsWith(RLM), 'line-start RLM still injected');
  });

  it('does NOT touch SGR on a Latin (LTR) line', () => {
    const input = RED + 'hello' + RST + ' world\n';
    const { out, inj } = runOnce(mod, input);
    // Latin first → no RLM, no flatten (lineIsRTL=false)
    assert.equal(out, input);
    assert.equal(inj.flattenedSgrCount, 0);
  });

  it('does NOT touch non-SGR CSI sequences on Hebrew lines (cursor/clear/etc.)', () => {
    const { out } = runOnce(mod, CURSOR_UP + 'שלום' + CLEAR_LINE + '\n');
    // Cursor + clear are CSI but final byte is 'A' / 'K', not 'm' — must pass.
    assert.ok(out.includes(CURSOR_UP), 'cursor-up CSI must survive');
    assert.ok(out.includes(CLEAR_LINE), 'clear-line CSI must survive');
  });

  it('does NOT touch OSC sequences (e.g., window title)', () => {
    // OSC 0; some title BEL — must pass through untouched even on Hebrew lines.
    const OSC = '\x1b]0;title\x07';
    const { out } = runOnce(mod, OSC + 'שלום\n');
    assert.ok(out.includes(OSC), 'OSC sequence must survive flatten');
  });

  it('handles SGR split across chunk boundaries — entire sequence dropped', () => {
    const inj = new mod.Injector();
    // Split mid-CSI: chunk 1 ends mid-params, chunk 2 has the final byte.
    let out = inj.write(Buffer.from('שלום\x1b[3', 'utf8'));
    out += inj.write(Buffer.from('1m more\x1b[0m\n', 'utf8'));
    out += inj.end();
    // Both SGRs should be flattened — no escape bytes in output
    assert.ok(!out.includes('\x1b'), `no escapes should remain (got ${JSON.stringify(out)})`);
    assert.ok(out.includes('שלום'), 'Hebrew survives');
    assert.ok(out.includes('more'), 'mid-line text survives');
  });

  it('does NOT flatten when the very first line was Latin and a later line is Hebrew', () => {
    // First line is Latin → lineIsRTL stays false on that line. Second
    // line is Hebrew → lineIsRTL becomes true → SGR on it gets flattened.
    const inj = new mod.Injector();
    const ltrLine = 'hello ' + RED + 'world' + RST + '\n';
    const rtlLine = RED + 'שלום' + RST + '\n';
    const out = inj.write(Buffer.from(ltrLine + rtlLine, 'utf8')) + inj.end();
    // Latin line keeps SGR (passthrough)
    assert.ok(out.includes(ltrLine.split('\n')[0]), 'Latin line SGR must survive');
    // Hebrew line has SGR stripped — שלום appears bracketed without escapes
    assert.ok(out.includes(mod.RLM + mod.RLE + 'שלום' + mod.PDF), 'Hebrew line SGR stripped');
  });

  it('stays compatible with strip-bullet (v1.1.8): bullet stripped AND colors flattened on Hebrew bullet line', () => {
    // Strip-bullet active + flatten active → the colored bullet line
    // becomes pure Hebrew with no bullet and no SGR.
    const prev = process.env.KIVUN_BIDI_STRIP_BULLET;
    process.env.KIVUN_BIDI_STRIP_BULLET = 'on';
    try {
      const m = loadInjector('on');
      const { out } = runOnce(m, RED + '●' + RST + ' שלום\n');
      // Expected: RLM + ' ' + RLE + שלום + PDF + \n (no SGR, no bullet)
      assert.ok(!out.includes('\x1b'), `flatten dropped SGR (got ${JSON.stringify(out)})`);
      assert.ok(!out.includes('●'), 'bullet stripped');
      assert.ok(out.includes('שלום'), 'Hebrew survives');
      assert.ok(out.startsWith(m.RLM), 'RLM still injected');
    } finally {
      if (prev === undefined) delete process.env.KIVUN_BIDI_STRIP_BULLET;
      else process.env.KIVUN_BIDI_STRIP_BULLET = prev;
    }
  });
});

describe('KIVUN_BIDI_FLATTEN_COLORS_RTL=off (legacy passthrough)', () => {
  const mod = loadInjector('off');
  const { RLE, PDF, RLM } = mod;

  it('preserves SGR on Hebrew lines (matches v1.1.9 behavior)', () => {
    const { out, inj } = runOnce(mod, RED + 'שלום' + RST + '\n');
    // Legacy: SGR codes pass through — RED before the bracket, RST inside, PDF after
    assert.equal(out, RLM + RED + RLE + 'שלום' + RST + PDF + '\n');
    assert.equal(inj.flattenedSgrCount, 0);
  });
});

describe('KIVUN_BIDI_FLATTEN_COLORS_RTL unset (defaults to on)', () => {
  const mod = loadInjector(undefined);
  const { RLE, PDF, RLM } = mod;

  it('matches on-mode — strips SGR from Hebrew line by default', () => {
    const { out, inj } = runOnce(mod, RED + 'שלום' + RST + '\n');
    assert.equal(out, RLM + RLE + 'שלום' + PDF + '\n');
    assert.equal(inj.flattenedSgrCount, 2);
  });
});
