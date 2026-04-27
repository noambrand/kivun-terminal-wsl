'use strict';

// Regression tests for the v1.1.13 cursor-forward CSI replacement
// (an extension of FLATTEN_COLORS_RTL coverage).
//
// Background: April 2026 DUMP_RAW capture confirmed Claude Code's TUI
// emits CSI cursor-forward sequences (`\x1b[NC`) instead of literal
// space characters as inter-word spacing on lines it draws. The
// 19 KB dump from one short Hebrew session contained 306 cursor-
// forward CSIs. Konsole's BiDi engine treats each `\x1b[NC` as an
// attribute-region boundary the same way it treats SGR color changes,
// so v1.1.10 FLATTEN_COLORS_RTL (which only stripped SGR) didn't catch
// them and the BiDi run kept getting split between every word.
//
// Fix: on RTL lines under FLATTEN_COLORS_RTL=on, replace each
// `\x1b[NC` with N literal space characters. Visually identical
// (cursor-forward moves over blank cells; spaces write to the same
// cells) but no attribute boundary so the BiDi run survives whole.
//
// LTR lines are NEVER affected — the wrapper only touches CSI bytes
// when the line's first strong char is Hebrew. Status bars, English
// prompts, code-box outlines, etc. all pass through unchanged.

// Both new (v1.1.13) and old (v1.1.10) FLATTEN_COLORS_RTL behavior
// are gated on the same env var. v1.1.11 BRACKET_RTL_RUNS default
// is off.

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

function loadInjector(flattenValue) {
  delete require.cache[require.resolve('../lib/injector')];
  const prev = process.env.KIVUN_BIDI_FLATTEN_COLORS_RTL;
  if (flattenValue === undefined) delete process.env.KIVUN_BIDI_FLATTEN_COLORS_RTL;
  else process.env.KIVUN_BIDI_FLATTEN_COLORS_RTL = flattenValue;
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

const CF1 = '\x1b[1C'; // cursor forward 1 column (no param defaults to 1 too)
const CF_DEFAULT = '\x1b[C';
const CF5 = '\x1b[5C';
const CF42 = '\x1b[42C';

describe('KIVUN_BIDI_FLATTEN_COLORS_RTL=on (default) — cursor-forward → spaces on RTL lines', () => {
  const mod = loadInjector('on');
  const { RLM } = mod;

  it('replaces a single \\x1b[1C between Hebrew words with one space', () => {
    // Mimics the actual Claude pattern from the dump.
    const { out, inj } = runOnce(mod, 'טכנולוגיית' + CF1 + 'React' + CF1 + 'מאפשרת\n');
    // Expected: RLM + 'טכנולוגיית React מאפשרת\n' (cursor-forwards substituted)
    assert.equal(out, RLM + 'טכנולוגיית React מאפשרת\n');
    assert.equal(inj.cursorForwardReplacedCount, 2, 'two cursor-forward CSIs replaced');
    assert.ok(!out.includes('\x1b'), 'no escape bytes remain in output');
  });

  it('handles cursor-forward without explicit param (\\x1b[C = 1 column)', () => {
    const { out, inj } = runOnce(mod, 'אחת' + CF_DEFAULT + 'שתיים\n');
    assert.equal(out, RLM + 'אחת שתיים\n');
    assert.equal(inj.cursorForwardReplacedCount, 1);
  });

  it('replaces multi-column cursor-forward with that many spaces', () => {
    const { out } = runOnce(mod, 'ראשון' + CF5 + 'שני\n');
    // 5-column move → 5 spaces
    assert.equal(out, RLM + 'ראשון     שני\n');
  });

  it('replaces large cursor-forward (e.g., 42 columns of padding)', () => {
    const { out } = runOnce(mod, 'מילה' + CF42 + 'אחרת\n');
    assert.equal(out, RLM + 'מילה' + ' '.repeat(42) + 'אחרת\n');
  });

  it('does NOT touch cursor-forward on a Latin-first (LTR) line', () => {
    // LTR line: lineIsRTL=false, no replacement. The escape passes through.
    const input = 'Hello' + CF1 + 'World\n';
    const { out, inj } = runOnce(mod, input);
    assert.equal(out, input, 'LTR line must keep cursor-forward intact');
    assert.equal(inj.cursorForwardReplacedCount, 0);
  });

  it('does NOT touch other CSI cursor sequences (cursor-up, cursor-back)', () => {
    // CSI A = up, CSI D = back. Only "C" (forward) gets replaced.
    const CURSOR_UP = '\x1b[A';
    const CURSOR_BACK = '\x1b[D';
    const { out } = runOnce(mod, 'שלום' + CURSOR_UP + CURSOR_BACK + 'עולם\n');
    // Up + back must survive intact; only between-word spacing on RTL
    // lines is the targeted pattern.
    assert.ok(out.includes(CURSOR_UP), 'cursor-up must survive');
    assert.ok(out.includes(CURSOR_BACK), 'cursor-back must survive');
  });

  it('still drops SGR colors on the same line as a cursor-forward — both fixes compound', () => {
    const RED = '\x1b[31m';
    const RST = '\x1b[0m';
    const { out, inj } = runOnce(mod, RED + 'שלום' + RST + CF1 + 'עולם\n');
    // SGR dropped + cursor-forward → space
    assert.equal(out, RLM + 'שלום עולם\n');
    assert.equal(inj.flattenedSgrCount, 2);
    assert.equal(inj.cursorForwardReplacedCount, 1);
  });

  it('replicates the actual Claude-dump pattern verbatim', () => {
    // Real bytes from April 2026 DUMP_RAW capture (with the leading
    // bullet + cursor-forward stripped down to the relevant region).
    // The dump showed: 'טכנולוגיית React\\x1b[1Cמאפשרת\\x1b[1Cלבנות\\x1b[1Cממשקי\\x1b[1Cמשתמש\\x1b[1Cמודרניים'
    const { out, inj } = runOnce(
      mod,
      'טכנולוגיית React' + CF1 + 'מאפשרת' + CF1 + 'לבנות' + CF1 + 'ממשקי' + CF1 + 'משתמש' + CF1 + 'מודרניים\n',
    );
    // Each cursor-forward becomes a real space; whole line is one
    // attribute region; React and 'ממשקי משתמש מודרניים' all in their
    // logical positions.
    assert.equal(
      out,
      RLM + 'טכנולוגיית React מאפשרת לבנות ממשקי משתמש מודרניים\n',
    );
    assert.equal(inj.cursorForwardReplacedCount, 5);
    assert.ok(!out.includes('\x1b'), 'no escape bytes remain on RTL line');
  });
});

describe('KIVUN_BIDI_FLATTEN_COLORS_RTL=off (legacy passthrough)', () => {
  const mod = loadInjector('off');
  const { RLM } = mod;

  it('preserves cursor-forward CSI verbatim — same as v1.1.10 and earlier', () => {
    const input = 'שלום' + CF1 + 'עולם\n';
    const { out, inj } = runOnce(mod, input);
    // RLM at line-start still gets injected (that's a separate fix), but
    // the CSI is NOT replaced when flatten is off.
    assert.equal(out, RLM + input);
    assert.equal(inj.cursorForwardReplacedCount, 0);
  });
});
