'use strict';

// [NEW v1.7.0] Auto-continue after a rate-limit reset.
// Driven by an injected fake clock + a fake child.write — no real timers, no
// real pty. Every test pumps `checkTimers()` by hand after moving the clock.

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const {
  createAutoContinue,
  parseResetFromMessage,
  resumeText,
  boolOr,
  GRACE_S,
} = require('../lib/auto-continue');
const { makeOutputSink } = require('../lib/wrapper');

// ── helpers ───────────────────────────
function makeClock(startMs) {
  let t = startMs;
  return { now: () => t, set: (ms) => { t = ms; }, advance: (ms) => { t += ms; } };
}

// AC factory: no-op injected timer so nothing fires except when we pump.
function build({ stateFile = null, clock, config = {} } = {}) {
  const writes = [];
  const logs = [];
  const ac = createAutoContinue({
    stateFile,
    now: clock.now,
    write: (s) => writes.push(s),
    log: (m) => logs.push(m),
    // Default safeResume OFF in tests so the timing assertions stay on the simple
    // 'continue\r'; the safe-resume text has its own dedicated tests below.
    config: { safeResume: false, ...config },
    setInterval: () => 0,
    clearInterval: () => {},
  });
  return { ac, writes, logs };
}

function tmpStateFile(resetsAtSec, pct = 100) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'kivun-ac-'));
  const p = path.join(dir, 'rate-limit.json');
  fs.writeFileSync(p, JSON.stringify({ five_hour: { pct, resets_at: resetsAtSec }, ts: Date.now() }));
  return p;
}

const LIMIT = 'Claude usage limit reached. Your limit will reset at 3pm';
const LIMIT_ANSI = '\x1b[1m\x1b[31mClaude usage limit reached.\x1b[0m Your limit will reset at 3pm\r\n';

// ── tests ─────────────────────────────
describe('auto-continue v1.7.0', () => {
  it('UT_DetectLimitLine — ANSI-wrapped limit line arms and eventually injects', () => {
    const base = 1_800_000_000_000;
    const resetsAtSec = Math.floor(base / 1000) + 3600;
    const clock = makeClock(base);
    const { ac, writes } = build({ stateFile: tmpStateFile(resetsAtSec), clock });

    ac.observeOutput(LIMIT_ANSI);
    clock.set(resetsAtSec * 1000 + GRACE_S * 1000);
    ac.checkTimers();
    assert.deepEqual(writes, ['continue\r']);
  });

  it('UT_ResumeText — safe reconcile prompt vs plain continue', () => {
    assert.equal(resumeText(false), 'continue');
    assert.match(resumeText(true), /git status/);
    assert.match(resumeText(true), /do not repeat/);
  });

  it('UT_BoolOr — config boolean parsing falls back to default', () => {
    assert.equal(boolOr(undefined, true), true);
    assert.equal(boolOr('false', true), false);
    assert.equal(boolOr(' OFF ', true), false);
    assert.equal(boolOr('1', false), true);
    assert.equal(boolOr('maybe', true), true);
  });

  it('UT_SafeResumeInjectsPrompt — safeResume on types the reconcile prompt, not bare continue', () => {
    const base = 1_800_000_000_000;
    const resetsAtSec = Math.floor(base / 1000) + 3600;
    const clock = makeClock(base);
    const { ac, writes } = build({
      stateFile: tmpStateFile(resetsAtSec), clock, config: { safeResume: true },
    });

    ac.observeOutput(LIMIT);
    clock.set(resetsAtSec * 1000 + GRACE_S * 1000);
    ac.checkTimers();
    assert.deepEqual(writes, [resumeText(true) + '\r']);
  });

  it('UT_SafeResumeDefaultOn — omitting safeResume defaults to the prompt (production default)', () => {
    const base = 1_800_000_000_000;
    const resetsAtSec = Math.floor(base / 1000) + 3600;
    const clock = makeClock(base);
    // Bypass build()'s test-only safeResume:false to verify the REAL default (on).
    const writes = [];
    const ac = createAutoContinue({
      stateFile: tmpStateFile(resetsAtSec),
      now: clock.now,
      write: (s) => writes.push(s),
      config: {},                      // no safeResume → default true
      setInterval: () => 0,
      clearInterval: () => {},
    });
    ac.observeOutput(LIMIT);
    clock.set(resetsAtSec * 1000 + GRACE_S * 1000);
    ac.checkTimers();
    assert.deepEqual(writes, [resumeText(true) + '\r']);
  });

  it('UT_IgnoreNonLimitOutput — ordinary output never arms', () => {
    const base = 1_800_000_000_000;
    const clock = makeClock(base);
    const { ac, writes } = build({ clock, config: { fallbackMin: 1 } });

    ac.observeOutput('\x1b[32mBuilding project...\x1b[0m\r\n');
    ac.observeOutput('All tests passed. usage looks fine.\r\n');
    clock.advance(24 * 60 * 60 * 1000);
    ac.checkTimers();
    assert.deepEqual(writes, []);
  });

  it('UT_ResetsAtFromStateFile — target is resets_at + GRACE (epoch math)', () => {
    const base = 1_800_000_000_000;
    const resetsAtSec = Math.floor(base / 1000) + 7200;
    const clock = makeClock(base);
    const { ac, writes } = build({ stateFile: tmpStateFile(resetsAtSec), clock });

    ac.observeOutput(LIMIT);
    // one second before target → nothing
    clock.set(resetsAtSec * 1000 + (GRACE_S - 1) * 1000);
    ac.checkTimers();
    assert.deepEqual(writes, []);
    // exactly at target → fire
    clock.set(resetsAtSec * 1000 + GRACE_S * 1000);
    ac.checkTimers();
    assert.deepEqual(writes, ['continue\r']);
  });

  it('UT_ResetsAtFallbackParse — parse time from message when state file absent', () => {
    const base = 1_800_000_000_000;
    const clock = makeClock(base);
    const { ac, writes } = build({ clock }); // no stateFile

    const expected = parseResetFromMessage(LIMIT, base) + GRACE_S * 1000;
    assert.ok(Number.isFinite(expected), 'message time must parse');

    ac.observeOutput(LIMIT);
    clock.set(expected - 1000);
    ac.checkTimers();
    assert.deepEqual(writes, []);
    clock.set(expected);
    ac.checkTimers();
    assert.deepEqual(writes, ['continue\r']);
  });

  it('UT_InjectOnce — the timer fires exactly once', () => {
    const base = 1_800_000_000_000;
    const resetsAtSec = Math.floor(base / 1000) + 60;
    const clock = makeClock(base);
    const { ac, writes } = build({ stateFile: tmpStateFile(resetsAtSec), clock });

    ac.observeOutput(LIMIT);
    clock.set(resetsAtSec * 1000 + GRACE_S * 1000);
    ac.checkTimers();
    // pump many more times, well past target
    clock.advance(60 * 60 * 1000);
    ac.checkTimers();
    ac.checkTimers();
    assert.deepEqual(writes, ['continue\r']);
  });

  it('UT_UserInputDisarms — a keystroke while armed cancels the injection', () => {
    const base = 1_800_000_000_000;
    const resetsAtSec = Math.floor(base / 1000) + 3600;
    const clock = makeClock(base);
    const { ac, writes } = build({ stateFile: tmpStateFile(resetsAtSec), clock });

    ac.observeOutput(LIMIT);
    ac.observeUserInput(); // user resumed manually
    clock.set(resetsAtSec * 1000 + GRACE_S * 1000);
    ac.checkTimers();
    assert.deepEqual(writes, []);
  });

  it('UT_RearmOnNewBlock — DONE state re-arms on a fresh limit line', () => {
    const base = 1_800_000_000_000;
    const firstSec = Math.floor(base / 1000) + 3600;
    const stateFile = tmpStateFile(firstSec);
    const clock = makeClock(base);
    const { ac, writes } = build({ stateFile, clock });

    ac.observeOutput(LIMIT);
    clock.set(firstSec * 1000 + GRACE_S * 1000);
    ac.checkTimers();
    assert.deepEqual(writes, ['continue\r']);

    // A NEW block later, with a NEW reset epoch written to the same file.
    const secondSec = Math.floor(clock.now() / 1000) + 3600;
    fs.writeFileSync(stateFile, JSON.stringify({ five_hour: { pct: 100, resets_at: secondSec }, ts: Date.now() }));
    ac.observeOutput(LIMIT);
    clock.set(secondSec * 1000 + GRACE_S * 1000);
    ac.checkTimers();
    assert.deepEqual(writes, ['continue\r', 'continue\r']);
  });

  it('UT_PassthroughRelay — passthrough sink relays raw bytes and tees observeOutput', () => {
    const injector = { write: (d) => 'X:' + d, end: () => 'END' };

    // passthrough on: raw bytes out, injector NOT applied, observeOutput teed raw
    const outP = [];
    const teed = [];
    const sinkP = makeOutputSink({
      injector,
      env: { KIVUN_BIDI_PASSTHROUGH: '1' },
      writeOut: (s) => outP.push(s),
      observeOutput: (d) => teed.push(d),
    });
    sinkP.onData('hello');
    sinkP.onEnd();
    assert.deepEqual(outP, ['hello']);
    assert.deepEqual(teed, ['hello']);

    // passthrough off: injector transform applied (legacy behavior preserved)
    const outN = [];
    const sinkN = makeOutputSink({
      injector,
      env: {},
      writeOut: (s) => outN.push(s),
    });
    sinkN.onData('hello');
    sinkN.onEnd();
    assert.deepEqual(outN, ['X:hello', 'END']);
  });

  it('UT_StatuslineStateWrite — statusline writes rate-limit.json atomically with exact schema', () => {
    const stateHome = fs.mkdtempSync(path.join(os.tmpdir(), 'kivun-sl-'));
    const statusline = path.join(__dirname, '..', '..', 'payload', 'statusline.mjs');
    const input = JSON.stringify({
      model: { display_name: 'Opus' },
      rate_limits: { five_hour: { used_percentage: 42.6, resets_at: 1_800_000_500 } },
    });
    const res = spawnSync('node', [statusline], {
      input,
      env: { ...process.env, XDG_STATE_HOME: stateHome },
      encoding: 'utf8',
    });
    assert.equal(res.status, 0, res.stderr);
    const p = path.join(stateHome, 'kivun-terminal', 'rate-limit.json');
    const j = JSON.parse(fs.readFileSync(p, 'utf8'));
    assert.deepEqual(Object.keys(j).sort(), ['five_hour', 'ts']);
    assert.deepEqual(Object.keys(j.five_hour).sort(), ['pct', 'resets_at']);
    assert.equal(j.five_hour.pct, 43);
    assert.equal(j.five_hour.resets_at, 1_800_000_500);
    assert.equal(typeof j.ts, 'number');
  });

  it('UT_MaxResumesCap — stops after AUTO_CONTINUE_MAX resumes', () => {
    const base = 1_800_000_000_000;
    const firstSec = Math.floor(base / 1000) + 3600;
    const stateFile = tmpStateFile(firstSec);
    const clock = makeClock(base);
    const { ac, writes } = build({ stateFile, clock, config: { max: 1 } });

    ac.observeOutput(LIMIT);
    clock.set(firstSec * 1000 + GRACE_S * 1000);
    ac.checkTimers();
    assert.deepEqual(writes, ['continue\r']);

    // cap reached → a new block must NOT arm
    const secondSec = Math.floor(clock.now() / 1000) + 3600;
    fs.writeFileSync(stateFile, JSON.stringify({ five_hour: { pct: 100, resets_at: secondSec }, ts: Date.now() }));
    ac.observeOutput(LIMIT);
    clock.set(secondSec * 1000 + GRACE_S * 1000);
    ac.checkTimers();
    assert.deepEqual(writes, ['continue\r']);
  });

  it('UT_FallbackFixedWait — no epoch and no parseable time → fixed wait', () => {
    const base = 1_800_000_000_000;
    const clock = makeClock(base);
    // message with NO reset time in it
    const { ac, writes } = build({ clock, config: { fallbackMin: 10 } });

    ac.observeOutput('Claude usage limit reached.\r\n');
    clock.set(base + 10 * 60 * 1000 - 1000);
    ac.checkTimers();
    assert.deepEqual(writes, []);
    clock.set(base + 10 * 60 * 1000);
    ac.checkTimers();
    assert.deepEqual(writes, ['continue\r']);
  });

  it('UT_QuietHoursBlocksThenResumes — holds inside quiet hours, resumes after', () => {
    // Build a target at a known local wall-clock, then a quiet window that
    // covers that instant and ends a few minutes later.
    const base = new Date(2026, 6, 12, 12, 0, 0, 0).getTime(); // local noon
    const resetsAtSec = Math.floor(base / 1000) + 3600;        // ~13:00 local
    const targetMs = resetsAtSec * 1000 + GRACE_S * 1000;      // ~13:01 local
    const td = new Date(targetMs);
    const pad = (n) => String(n).padStart(2, '0');
    const startMin = td.getHours() * 60 + td.getMinutes();
    const endMin = startMin + 3;
    const quiet = `${pad(Math.floor(startMin / 60))}:${pad(startMin % 60)}-${pad(Math.floor(endMin / 60))}:${pad(endMin % 60)}`;

    const clock = makeClock(base);
    const { ac, writes } = build({ stateFile: tmpStateFile(resetsAtSec), clock, config: { quiet } });

    ac.observeOutput(LIMIT);
    // at target, but inside quiet hours → held
    clock.set(targetMs);
    ac.checkTimers();
    assert.deepEqual(writes, []);
    // after the quiet window closes → resumes
    clock.set(targetMs + 4 * 60 * 1000);
    ac.checkTimers();
    assert.deepEqual(writes, ['continue\r']);
  });

  it('UT_StaleStateEpochNoPrematureFire — a past state-file resets_at must NOT fire now (falls through to the future)', () => {
    const base = 1_800_000_000_000;
    const staleSec = Math.floor(base / 1000) - 7200; // 2h in the PAST (stale)
    const clock = makeClock(base);
    const { ac, writes } = build({ stateFile: tmpStateFile(staleSec), clock });

    ac.observeOutput(LIMIT); // message also carries "reset at 3pm"
    // Clock UNMOVED. The stale/past epoch would have fired "continue" right
    // here (the bug). It must not — a freshly-seen block resets in the future.
    ac.checkTimers();
    assert.deepEqual(writes, [], 'must not fire on a stale/past state-file epoch');

    // Instead it armed via message-parse for the next 3pm; fires only then.
    const expected = parseResetFromMessage(LIMIT, base) + GRACE_S * 1000;
    clock.set(expected - 1000);
    ac.checkTimers();
    assert.deepEqual(writes, []);
    clock.set(expected);
    ac.checkTimers();
    assert.deepEqual(writes, ['continue\r']);
  });
});
