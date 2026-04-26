'use strict';

// Regression tests for KIVUN_BIDI_STRIP_INCOMING (added in v1.1.9).
//
// Background: ChatGPT analysis (April 2026) flagged the wrapper as a
// nondeterministic renderer because Claude's stream could in theory
// contain explicit Unicode directional controls (LRE/RLE/PDF/LRO/RLO and
// LRI/RLI/FSI/PDI) that compound with the wrapper's own RLM injection.
// Strip-incoming gives the wrapper sole authority over directionality
// AND, because of the side log, lets us measure how often pollution
// actually happens rather than guessing.
//
// What's stripped:
//   U+202A LRE  U+202B RLE  U+202C PDF  U+202D LRO  U+202E RLO
//   U+2066 LRI  U+2067 RLI  U+2068 FSI  U+2069 PDI
//
// What's preserved:
//   U+200E LRM  U+200F RLM   (the wrapper itself injects RLM)
//
// Modes:
//   off  - passthrough, no count, no log
//   auto - strip + count + log once on first detection (default)
//   on   - strip + count + log every chunk where stripping happened
//
// Pinning all of this so a future "let's clean up the strip helper" PR
// can't silently undo any of it.

const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

// Per-test temp log file. Pointing KIVUN_BIDI_LOG_FILE at a known path
// keeps the tests off the user's real ~/.local/state log and lets us
// assert what was written.
const TMP_LOG = path.join(os.tmpdir(), `kivun-bidi-strip-test-${process.pid}.log`);

// The injector reads KIVUN_BIDI_STRIP_INCOMING and KIVUN_BIDI_LOG_FILE at
// module load. Mirrors the strip-bullet.test.js loader pattern: invalidate
// the require cache, set env, load, restore env.
function loadInjector(envValue, logFile) {
  delete require.cache[require.resolve('../lib/injector')];
  const prevMode = process.env.KIVUN_BIDI_STRIP_INCOMING;
  const prevLog = process.env.KIVUN_BIDI_LOG_FILE;
  if (envValue === undefined) delete process.env.KIVUN_BIDI_STRIP_INCOMING;
  else process.env.KIVUN_BIDI_STRIP_INCOMING = envValue;
  if (logFile === undefined) delete process.env.KIVUN_BIDI_LOG_FILE;
  else process.env.KIVUN_BIDI_LOG_FILE = logFile;
  try {
    return require('../lib/injector');
  } finally {
    if (prevMode === undefined) delete process.env.KIVUN_BIDI_STRIP_INCOMING;
    else process.env.KIVUN_BIDI_STRIP_INCOMING = prevMode;
    if (prevLog === undefined) delete process.env.KIVUN_BIDI_LOG_FILE;
    else process.env.KIVUN_BIDI_LOG_FILE = prevLog;
  }
}

function runChunks(mod, chunks) {
  const inj = new mod.Injector();
  let out = '';
  for (const c of chunks) {
    out += inj.write(typeof c === 'string' ? Buffer.from(c, 'utf8') : c);
  }
  out += inj.end();
  return { out, inj };
}

function clearLog() {
  try { fs.unlinkSync(TMP_LOG); } catch (_) { /* not present */ }
}

function readLog() {
  try { return fs.readFileSync(TMP_LOG, 'utf8'); } catch (_) { return ''; }
}

// All nine controls we strip, plus the two we keep, in one fixture string.
// Codepoints written explicitly as escapes so the source file stays
// readable in any editor.
const ALL_STRIPPED = '‪‫‬‭‮⁦⁧⁨⁩';
const KEPT = '‎‏'; // LRM + RLM

describe('KIVUN_BIDI_STRIP_INCOMING=off (passthrough)', () => {
  before(() => clearLog());
  after(() => clearLog());

  it('does not strip any directional control chars', () => {
    const mod = loadInjector('off', TMP_LOG);
    const input = 'hi' + ALL_STRIPPED + 'bye\n';
    const { out, inj } = runChunks(mod, [input]);
    assert.equal(out, input, 'every input byte must survive');
    assert.equal(inj.stripIncomingCount, 0, 'no counting in off mode');
  });

  it('writes nothing to the side log even when controls are present', () => {
    clearLog();
    const mod = loadInjector('off', TMP_LOG);
    runChunks(mod, ['hi' + ALL_STRIPPED + 'bye\n']);
    assert.equal(readLog(), '', 'off mode must be log-silent');
  });
});

describe('KIVUN_BIDI_STRIP_INCOMING=auto (strip + log once on first detection — default)', () => {
  before(() => clearLog());
  after(() => clearLog());

  it('strips every char in U+202A-U+202E and U+2066-U+2069', () => {
    clearLog();
    const mod = loadInjector('auto', TMP_LOG);
    const { out, inj } = runChunks(mod, ['hi' + ALL_STRIPPED + 'bye\n']);
    assert.equal(out, 'hibye\n', 'all 9 control chars must be removed');
    assert.equal(inj.stripIncomingCount, 9);
  });

  it('preserves LRM (U+200E) and RLM (U+200F) — wrapper relies on RLM', () => {
    clearLog();
    const mod = loadInjector('auto', TMP_LOG);
    // Use a plain ASCII line so the line-start-buffer / RLE-PDF
    // bracketing doesn't add anything of its own. We just want to
    // confirm LRM/RLM survive the strip pass intact.
    const { out } = runChunks(mod, ['x' + KEPT + 'y\n']);
    assert.equal(out, 'x' + KEPT + 'y\n');
  });

  it('counts cumulatively across chunks', () => {
    clearLog();
    const mod = loadInjector('auto', TMP_LOG);
    const { inj } = runChunks(mod, [
      'a‫b',
      'c⁧d',
      'e‬f\n',
    ]);
    assert.equal(inj.stripIncomingCount, 3);
  });

  it('logs exactly one "first detection" line per session, not per chunk', () => {
    clearLog();
    const mod = loadInjector('auto', TMP_LOG);
    runChunks(mod, [
      'a‫b',
      'c⁧d',
      'e‬f\n',
    ]);
    const log = readLog();
    const firstDetectionMatches = (log.match(/first detection/g) || []).length;
    assert.equal(firstDetectionMatches, 1, 'auto mode must not spam — one first-detection line only');
  });

  it('writes a session-end summary line on end()', () => {
    clearLog();
    const mod = loadInjector('auto', TMP_LOG);
    runChunks(mod, ['x⁧y\n']);
    const log = readLog();
    assert.match(log, /session end .* total 1 bidi control/);
  });

  it('writes nothing when the stream is clean', () => {
    clearLog();
    const mod = loadInjector('auto', TMP_LOG);
    const { inj } = runChunks(mod, ['just plain text\n']);
    assert.equal(inj.stripIncomingCount, 0);
    assert.equal(readLog(), '', 'clean stream must produce no log lines');
  });

  it('does not break the existing strip-bullet pipeline (Hebrew bullet line still RTL)', () => {
    // Belt and suspenders: confirm the v1.1.8 strip-bullet path still
    // produces the same output shape when strip-incoming runs ahead of
    // it on a chunk that has no controls to strip.
    const prev = process.env.KIVUN_BIDI_STRIP_BULLET;
    process.env.KIVUN_BIDI_STRIP_BULLET = 'on';
    try {
      const mod = loadInjector('auto', TMP_LOG);
      const { RLE, PDF, RLM } = mod;
      const { out } = runChunks(mod, ['● שלום\n']);
      assert.equal(out, RLM + RLE + 'שלום' + PDF + '\n');
    } finally {
      if (prev === undefined) delete process.env.KIVUN_BIDI_STRIP_BULLET;
      else process.env.KIVUN_BIDI_STRIP_BULLET = prev;
    }
  });
});

describe('KIVUN_BIDI_STRIP_INCOMING=on (verbose — log every chunk)', () => {
  before(() => clearLog());
  after(() => clearLog());

  it('strips just like auto', () => {
    clearLog();
    const mod = loadInjector('on', TMP_LOG);
    const { out, inj } = runChunks(mod, ['hi' + ALL_STRIPPED + 'bye\n']);
    assert.equal(out, 'hibye\n');
    assert.equal(inj.stripIncomingCount, 9);
  });

  it('logs every chunk that stripped something (not just the first)', () => {
    clearLog();
    const mod = loadInjector('on', TMP_LOG);
    runChunks(mod, [
      'a‫b',
      'c⁧d',
      'e‬f\n',
    ]);
    const log = readLog();
    // 1 first-detection line + 2 follow-up chunk lines + 1 session-end line = 4 total
    const lineCount = log.trim().split('\n').length;
    assert.equal(lineCount, 4, `verbose mode should log per-chunk + session end (got: ${log})`);
  });
});

describe('KIVUN_BIDI_STRIP_INCOMING unset (defaults to auto)', () => {
  before(() => clearLog());
  after(() => clearLog());

  it('matches auto-mode behavior — strips and counts', () => {
    clearLog();
    const mod = loadInjector(undefined, TMP_LOG);
    const { out, inj } = runChunks(mod, ['hi‫bye\n']);
    assert.equal(out, 'hibye\n');
    assert.equal(inj.stripIncomingCount, 1);
  });
});
