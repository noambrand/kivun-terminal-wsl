'use strict';

// RTL cost optimizer (EXPERIMENT, issue #98) — unit tests.
//
// IMPORTANT: this file must NOT require ../lib/rtl-cost-optimizer at the
// top level. The "off path never loads the module" test below inspects
// require.cache, so the module may only be loaded lazily inside tests
// that run after it.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const { makeStdinPipeline } = require('../lib/wrapper');

function fakeChild() {
  const received = [];
  return { received, write: (c) => received.push(c) };
}

function errSink() {
  const lines = [];
  const fn = (s) => lines.push(s);
  fn.lines = lines;
  return fn;
}

function loadOptimizer() {
  return require('../lib/rtl-cost-optimizer');
}

// ---------------------------------------------------------------------------
// Gating / wrapper wiring
// ---------------------------------------------------------------------------

test('off by default: raw passthrough, same chunk object, no end handler, silent', () => {
  const child = fakeChild();
  const err = errSink();
  const { onStdin, onStdinEnd } = makeStdinPipeline(child, {}, false, err);
  assert.equal(onStdinEnd, null);
  const buf = Buffer.from('hello');
  onStdin(buf);
  assert.equal(child.received.length, 1);
  assert.equal(child.received[0], buf); // the SAME object — no decode, no copy
  assert.equal(err.lines.length, 0);
});

test('off path never loads the optimizer module', () => {
  const child = fakeChild();
  makeStdinPipeline(child, {}, false);
  makeStdinPipeline(child, {}, true);
  // Scope to lib/ — this test file's own path contains the same name.
  const needle = path.join('lib', 'rtl-cost-optimizer');
  const loaded = Object.keys(require.cache).some((p) => p.includes(needle));
  assert.equal(loaded, false);
});

test('off path forwards split multi-byte bytes untouched (no StringDecoder)', () => {
  const child = fakeChild();
  const { onStdin } = makeStdinPipeline(child, {}, false);
  const b1 = Buffer.from([0xd7]);
  const b2 = Buffer.from([0xa9]);
  onStdin(b1);
  onStdin(b2);
  assert.equal(child.received.length, 2);
  assert.equal(child.received[0], b1);
  assert.equal(child.received[1], b2);
});

test("only the literal 'on' enables; 'true'/'1' stay off; case/space tolerated", () => {
  const child = fakeChild();
  for (const v of ['true', '1', 'yes', '']) {
    const { onStdinEnd } = makeStdinPipeline(child, { KIVUN_RTL_COST_OPTIMIZER: v }, false);
    assert.equal(onStdinEnd, null, `value '${v}' must not enable`);
  }
  const { onStdinEnd } = makeStdinPipeline(child, { KIVUN_RTL_COST_OPTIMIZER: ' ON ' }, false);
  assert.notEqual(onStdinEnd, null);
});

test('enabled + TTY: one skip notice, passthrough, no end handler', () => {
  const child = fakeChild();
  const err = errSink();
  const { onStdin, onStdinEnd } = makeStdinPipeline(
    child, { KIVUN_RTL_COST_OPTIMIZER: 'on' }, true, err,
  );
  assert.equal(onStdinEnd, null);
  assert.equal(err.lines.length, 1);
  assert.match(err.lines[0], /applies to piped input only; skipped for interactive TUI/);
  const buf = Buffer.from('x');
  onStdin(buf);
  assert.equal(child.received[0], buf);
});

// ---------------------------------------------------------------------------
// StdinPromptOptimizer (enabled, piped)
// ---------------------------------------------------------------------------

function makeOptimizer(extraEnv = {}) {
  const { StdinPromptOptimizer } = loadOptimizer();
  const err = errSink();
  const env = { KIVUN_RTL_COST_OPTIMIZER: 'on', KIVUN_RTL_COST_OPTIMIZER_AUDIT: 'off', ...extraEnv };
  return { opt: new StdinPromptOptimizer(env, { writeErr: err }), err };
}

test('line buffering: nothing emitted until the newline', () => {
  const { opt } = makeOptimizer();
  assert.equal(opt.write(Buffer.from('תקן את הבאג')), '');
  const out = opt.write(Buffer.from('\n'));
  assert.ok(out.endsWith('\n'));
  assert.ok(out.includes('תקן את הבאג'));
});

test('multi-byte char split across two chunks decodes cleanly', () => {
  const { opt } = makeOptimizer();
  let out = opt.write(Buffer.from([0xd7]));
  out += opt.write(Buffer.from([0xa9, 0x0a])); // ש + \n
  assert.ok(out.includes('ש'));
  assert.ok(!out.includes('�'));
});

test('non-RTL line passes through verbatim — no notice, no transform', () => {
  const { opt, err } = makeOptimizer();
  const out = opt.write(Buffer.from('fix the build\n'));
  assert.equal(out, 'fix the build\n');
  assert.equal(err.lines.length, 0);
});

test('EOF flushes a final unterminated line', () => {
  const { opt } = makeOptimizer();
  assert.equal(opt.write(Buffer.from('שלום')), '');
  const out = opt.end();
  assert.ok(out.includes('שלום'));
});

test('Ctrl-C / Ctrl-D forwarded immediately and clear the buffer', () => {
  const { opt } = makeOptimizer();
  assert.equal(opt.write(Buffer.from('שלום')), '');
  const out = opt.write(Buffer.from([0x03]));
  assert.equal(out, '\u0003');
  assert.equal(opt.end(), ''); // buffer was dropped
});

// ---------------------------------------------------------------------------
// Normalization
// ---------------------------------------------------------------------------

test('niqqud and harakat are stripped', () => {
  const { normalizeRTLInput } = require('../lib/rtl-cost-optimizer/normalizer');
  // Explicit escapes so invisible marks survive editors/normalization:
  // שָׁלוֹם (shalom with niqqud), مُحَمَّد (Muhammad with harakat).
  assert.equal(normalizeRTLInput('שָׁלוֹם'), 'שלום');
  assert.equal(normalizeRTLInput('مُحَمَّد'), 'محمد');
});

test('directional controls including ALM are stripped', () => {
  const { normalizeRTLInput } = require('../lib/rtl-cost-optimizer/normalizer');
  const input = '‏שלום‎‫!‬⁦ok⁩؜';
  assert.equal(normalizeRTLInput(input), 'שלום!ok');
});

test('maqaf (Hebrew hyphen) is preserved — stripping it changes words', () => {
  const { normalizeRTLInput } = require('../lib/rtl-cost-optimizer/normalizer');
  const alYedei = 'על־ידי'; // על־ידי
  assert.equal(normalizeRTLInput(alYedei), alYedei);
});

test('ZWNJ is preserved (Persian orthography requires it)', () => {
  const { normalizeRTLInput } = require('../lib/rtl-cost-optimizer/normalizer');
  const mikhaham = 'می‌خواهم'; // می‌خواهم
  assert.equal(normalizeRTLInput(mikhaham), mikhaham);
});

test('whitespace collapsed: tabs/runs to one space, 3+ newlines to 2', () => {
  const { normalizeRTLInput } = require('../lib/rtl-cost-optimizer/normalizer');
  assert.equal(normalizeRTLInput('שלום\t\tעולם   טוב'), 'שלום עולם טוב');
  assert.equal(normalizeRTLInput('א\n\n\n\nב'), 'א\n\nב');
});

test('fenced code is byte-identical and fences stay at line start', () => {
  const { normalizeRTLInput } = require('../lib/rtl-cost-optimizer/normalizer');
  const code = 'const x  =  "שָׁלוֹם";  // double  spaces preserved';
  const input = 'תתקן את זה\n```js\n' + code + '\n```\nתודה';
  const out = normalizeRTLInput(input);
  assert.ok(out.includes(code), 'code body must be untouched');
  assert.match(out, /\n```js\n/, 'opening fence must stay on its own line');
  assert.match(out, /\n```\n/, 'closing fence must stay on its own line');
});

// ---------------------------------------------------------------------------
// Scaffold — the #84 blocker-2 regression suite
// ---------------------------------------------------------------------------

test('BLOCKER-2 REGRESSION: the full request is carried verbatim, never substituted', () => {
  const { transformPrompt, readConfig } = loadOptimizer();
  // The request class #84 destroyed: mentions CMake but asks to REMOVE it.
  // #84's intent matcher turned this into "Investigate the CMake build
  // failure and fix the root cause." — the opposite of the user's request.
  const request = 'תסיר את CMake מהפרויקט ותחליף אותו ב-Meson';
  const config = readConfig({ KIVUN_RTL_COST_OPTIMIZER: 'on' });
  const { transformed } = transformPrompt(request, config);
  assert.ok(transformed.includes(request), 'full normalized request must appear verbatim');
  assert.doesNotMatch(transformed, /Investigate the CMake build failure/);
});

test('Hebrew scaffold frame', () => {
  const { transformPrompt, readConfig } = loadOptimizer();
  const config = readConfig({ KIVUN_RTL_COST_OPTIMIZER: 'on' });
  const { transformed } = transformPrompt('תקן את הבאג', config);
  assert.ok(transformed.startsWith('Use English for internal reasoning.'));
  assert.ok(transformed.includes('Reply in Hebrew.'));
  assert.ok(transformed.includes('Task (verbatim from the user):'));
});

test("Arabic-script input gets the generic reply instruction (script is shared)", () => {
  const { transformPrompt, readConfig } = loadOptimizer();
  const config = readConfig({ KIVUN_RTL_COST_OPTIMIZER: 'on' });
  const { transformed } = transformPrompt('أصلح هذا الخطأ', config);
  assert.ok(transformed.includes("Reply in the user's language."));
});

test('scaffold off: output is the normalized text only', () => {
  const { transformPrompt, readConfig } = loadOptimizer();
  const config = readConfig({
    KIVUN_RTL_COST_OPTIMIZER: 'on',
    KIVUN_RTL_COST_OPTIMIZER_SCAFFOLD: 'off',
  });
  const { transformed } = transformPrompt('שָׁלוֹם  עולם', config);
  assert.equal(transformed, 'שלום עולם');
  assert.ok(!transformed.includes('Use English'));
});

// ---------------------------------------------------------------------------
// Estimator
// ---------------------------------------------------------------------------

test('compareEstimate returns the delta schema', () => {
  const { compareEstimate } = require('../lib/rtl-cost-optimizer/estimator');
  const r = compareEstimate('שלום עולם', 'שלום עולם');
  for (const k of ['originalTokens', 'transformedTokens', 'deltaTokens', 'deltaPercent']) {
    assert.equal(typeof r[k], 'number', k);
  }
});

test('delta can be NEGATIVE (scaffold adds tokens) and positive (normalize-only)', () => {
  const { transformPrompt, readConfig } = loadOptimizer();
  const scaffolded = readConfig({ KIVUN_RTL_COST_OPTIMIZER: 'on' });
  const short = transformPrompt('תקן באג', scaffolded);
  assert.ok(short.estimate.deltaTokens < 0,
    `short prompt + scaffold must show NEGATIVE delta, got ${short.estimate.deltaTokens}`);

  const stripOnly = readConfig({
    KIVUN_RTL_COST_OPTIMIZER: 'on',
    KIVUN_RTL_COST_OPTIMIZER_SCAFFOLD: 'off',
  });
  const sloppy = transformPrompt('שָׁלוֹם    שָׁלוֹם    שָׁלוֹם   \t  שָׁלוֹם', stripOnly);
  assert.ok(sloppy.estimate.deltaTokens > 0,
    `sloppy prompt, strip-only must show positive delta, got ${sloppy.estimate.deltaTokens}`);
});

test('notices: preview shows transformed text, estimate warns about NEGATIVE; flags suppress', () => {
  const { opt, err } = makeOptimizer();
  opt.write(Buffer.from('תקן את הבאג\n'));
  const joined = err.lines.join('');
  assert.match(joined, /transformed prompt \(verify the meaning is preserved\)/);
  assert.match(joined, /NEGATIVE delta means the transformation ADDED input tokens/);

  const { opt: quiet, err: quietErr } = makeOptimizer({
    KIVUN_RTL_COST_OPTIMIZER_SHOW_PREVIEW: 'off',
    KIVUN_RTL_COST_OPTIMIZER_SHOW_ESTIMATE: 'off',
  });
  quiet.write(Buffer.from('תקן את הבאג\n'));
  assert.equal(quietErr.lines.length, 0);
});

// ---------------------------------------------------------------------------
// Audit
// ---------------------------------------------------------------------------

test('audit writes one JSONL line with the metrics schema and NO prompt text', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'kivun-opt-'));
  const file = path.join(dir, 'audit.jsonl');
  const { opt } = makeOptimizer({
    KIVUN_RTL_COST_OPTIMIZER_AUDIT: 'on',
    KIVUN_RTL_COST_OPTIMIZER_AUDIT_FILE: file,
  });
  opt.write(Buffer.from('תקן את הבאג בקובץ הראשי\n'));
  const raw = fs.readFileSync(file, 'utf8').trim();
  const entry = JSON.parse(raw);
  assert.deepEqual(Object.keys(entry).sort(), [
    'deltaTokens', 'originalChars', 'originalTokens', 'scaffold',
    'script', 'time', 'transformedChars', 'transformedTokens',
  ]);
  assert.equal(entry.script, 'hebrew');
  assert.doesNotMatch(raw, /[֐-׿]/, 'audit file must contain no Hebrew at all');
  fs.rmSync(dir, { recursive: true, force: true });
});

test('AUDIT=off writes nothing', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'kivun-opt-'));
  const file = path.join(dir, 'audit.jsonl');
  const { opt } = makeOptimizer({ KIVUN_RTL_COST_OPTIMIZER_AUDIT_FILE: file });
  opt.write(Buffer.from('תקן את הבאג\n'));
  assert.equal(fs.existsSync(file), false);
  fs.rmSync(dir, { recursive: true, force: true });
});

test('audit path follows the state-dir convention and honors XDG_STATE_HOME', () => {
  const { resolveAuditPath } = loadOptimizer();
  const def = resolveAuditPath({});
  assert.ok(def.endsWith(path.join('.local', 'state', 'kivun-terminal', 'rtl-cost-optimizer.jsonl')), def);
  const xdg = resolveAuditPath({ XDG_STATE_HOME: '/tmp/state' });
  assert.equal(xdg, path.join('/tmp/state', 'kivun-terminal', 'rtl-cost-optimizer.jsonl'));
});
