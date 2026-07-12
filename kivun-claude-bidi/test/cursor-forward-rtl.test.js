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

describe('interactive input-box editing — line-start navigation cursor-forward is NOT touched (v1.1.14)', () => {
  // Regression for the Hebrew-typing corruption. A July 2026 DUMP_RAW
  // capture of live Hebrew input showed Claude's TUI redraws the whole
  // screen per keystroke, navigating from screen-home to the input box:
  //
  //   \x1b[H  \r  \x1b[NC  \x1b[38B  <hebrew char>
  //   home   col1  fwd-N   down-38   write at (row39, colN)
  //
  // The \x1b[NC there is cursor NAVIGATION to reach the input column, not
  // inter-word spacing. The v1.1.13 substitution wrongly converted it to N
  // spaces while flushing the line-start buffer (the char after it is the
  // line's first strong char → lineIsRTL flips true), painting a growing
  // run of spaces onto the top row every keystroke and desyncing editing.
  //
  // Fix: never substitute cursor-forward that is flushed from the
  // line-start buffer (before the line's first strong char). Genuine
  // inter-word cursor-forward always arrives AFTER the first strong char,
  // so it is unaffected (the suite above still passes).
  const mod = loadInjector('on');
  const { RLM } = mod;

  const H = '\x1b[H';      // cursor home
  const DOWN38 = '\x1b[38B';

  it('is a byte-exact passthrough for one input-box keystroke (no RLM, no spaces)', () => {
    // One real keystroke: type 'ל' into the input box at column 4. The whole
    // redraw is absolute cursor navigation (home → forward → down 38), so the
    // wrapper must touch nothing: no line-start RLM (v1.1.15 — it would land at
    // the home cell and knock the input one column off, so Backspace stops
    // showing) and no spaces painted.
    const input = H + '\r' + '\x1b[3C' + DOWN38 + 'ל' + '\n';
    const { out, inj } = runOnce(mod, input);
    assert.equal(out, input, 'input-box keystroke must pass through unchanged');
    assert.ok(!out.includes(RLM), 'no RLM injected on an absolute-navigation redraw');
    assert.equal(inj.cursorForwardReplacedCount, 0, 'navigation cursor-forward must NOT be replaced');
    assert.ok(out.includes('\x1b[3C'), 'the navigation escape survives intact');
    assert.ok(!out.includes('   '), 'no run of spaces painted over the top row');
  });

  it('preserves multi-column navigation forward (deeper into the line)', () => {
    // Later keystroke: input column 9 → \x1b[9C. Under the old bug this
    // wrote 9 spaces onto row 1.
    const input = H + '\r' + '\x1b[9C' + DOWN38 + 'י' + '\n';
    const { out, inj } = runOnce(mod, input);
    assert.ok(out.includes('\x1b[9C'), 'the 9-column navigation escape survives');
    assert.ok(!out.includes('         '), 'no 9-space run painted onto the top row');
    assert.equal(inj.cursorForwardReplacedCount, 0);
  });

  it('still converts a genuine inter-word cursor-forward on the SAME line (but injects no RLM)', () => {
    // Line-start navigation forward is preserved and no RLM is injected
    // (v1.1.15), but an inter-word \x1b[1C that appears AFTER the first Hebrew
    // word is still flattened to a space — that BiDi-run fix keeps real Hebrew
    // OUTPUT lines whole and is independent of the (suppressed) RLM.
    const input = H + '\r' + '\x1b[3C' + DOWN38 + 'שלום' + '\x1b[1C' + 'עולם' + '\n';
    const { out, inj } = runOnce(mod, input);
    assert.equal(out, H + '\r' + '\x1b[3C' + DOWN38 + 'שלום עולם' + '\n');
    assert.ok(!out.includes(RLM), 'no RLM injected on an absolute-navigation redraw');
    assert.ok(out.includes('\x1b[3C'), 'line-start navigation preserved');
    assert.ok(!out.includes('\x1b[1C'), 'inter-word cursor-forward flattened to a space');
    assert.equal(inj.cursorForwardReplacedCount, 1, 'exactly the inter-word one is replaced');
  });

  it('backspace redraw (erase, no glyph) leaves navigation forward intact', () => {
    // A backspace redraw moves to the deleted char and erases to EOL with
    // no strong char written — the line-start buffer is dumped raw on the
    // trailing CR and must not gain spaces either.
    const input = H + '\r' + '\x1b[9C' + DOWN38 + '\x1b[K' + '\r' + '\n';
    const { out, inj } = runOnce(mod, input);
    assert.ok(out.includes('\x1b[9C'), 'navigation forward survives on an erase-only redraw');
    assert.ok(!out.includes('         '), 'no 9-space run painted');
    assert.equal(inj.cursorForwardReplacedCount, 0);
  });
});

describe('input-box RLM suppression on absolute-navigation redraws (v1.1.15)', () => {
  // A follow-up July 2026 DUMP_RAW capture (after the v1.1.14 cursor-forward
  // fix) proved the space-painting was gone but the injector was STILL the
  // only thing changing the stream: it stamped one line-start RLM per Hebrew
  // keystroke at the screen-home cell (row 1, col 1) — because Claude's
  // alt-screen redraws each keystroke via `\x1b[H \r \x1b[NC \x1b[38B <char>`,
  // and the CR + Hebrew-first-char makes the wrapper think a paragraph line
  // started. That stray RLM never reaches the input row, so it sets no
  // direction; it just shoves the input one column off and swallows Backspace.
  //
  // Fix: when the pre-strong-char line-start buffer carries absolute/vertical
  // cursor motion (NAV_CURSOR_RE), suppress the RLM. Genuine scrolling lines
  // keep it. Replaying the real capture through the fixed wrapper yields a
  // byte-for-byte passthrough.
  const mod = loadInjector('on');
  const { RLM } = mod;

  const H = '\x1b[H';
  const DOWN38 = '\x1b[38B';

  it('is a byte-exact passthrough for a full word typed letter-by-letter', () => {
    // Type 'שלום' the way the real dump showed it: each keystroke re-homes,
    // forwards to the growing input column, drops 38 rows, writes one glyph,
    // erases to EOL, and CRs back. Nothing here is a paragraph start.
    const keystroke = (col, ch) => H + '\r' + `\x1b[${col}C` + DOWN38 + ch + '\x1b[K' + '\r';
    const input =
      keystroke(2, 'ש') + keystroke(3, 'ל') + keystroke(4, 'ו') + keystroke(5, 'ם');
    const { out, inj } = runOnce(mod, input);
    assert.equal(out, input, 'the whole typing sequence must pass through unchanged');
    assert.ok(!out.includes(RLM), 'zero RLMs injected across the whole word');
    assert.equal(inj.cursorForwardReplacedCount, 0, 'no cursor-forward replaced');
    assert.equal(inj.flattenedSgrCount, 0, 'no SGR flattened');
  });

  it('still injects the line-start RLM on a GENUINE scrolling Hebrew line (no regression)', () => {
    // A real output line arrives right after a newline with only a bullet +
    // space before the first Hebrew char — no absolute/vertical motion — so
    // the RLM that fixes the `● שלום` first-line-LTR bug must still fire.
    const { out } = runOnce(mod, '\n● שלום עולם\n');
    assert.ok(out.includes(RLM), 'scrolling Hebrew line keeps its line-start RLM');
    assert.ok(out.indexOf(RLM) < out.indexOf('ש'), 'RLM precedes the first Hebrew char');
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
