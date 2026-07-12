'use strict';

// [NEW v1.7.0] Auto-continue after a rate-limit reset.
//
// When Claude Code prints the 5-hour usage-limit block, the session stays
// alive but idle until the user comes back and types something. This module
// watches the wrapped pty output for that block, waits until the real reset
// time has passed, and then types "continue" ONCE so unattended work resumes.
//
// It does NOT bypass the limit: it waits for the reset the provider itself
// reports (statusline `resets_at` epoch, else the time parsed from the block
// message, else a conservative fixed wait) and only then resumes. Opt-in,
// capped, quiet-hours-aware, and disclosed (see README ToS note).
//
// Pure stdlib. The clock and the poll timer are INJECTED (a `now()` fn plus
// `setInterval`/`clearInterval`) so tests drive time without real timers —
// mirroring how the wrapper injects `env`/`writeErr` for testability. Tests
// can also pump `checkTimers()` directly.

const fs = require('fs');

// Verbatim block prefix, supplied by the user (authoritative). Matched on the
// stable prefix only so time-format variations don't defeat detection. Do NOT
// over-match / guess additional strings.
const LIMIT_PATTERNS = [/Claude usage limit reached/i];

// Secondary extractor: pull a reset time out of "...reset at <time>" for the
// message-parse fallback (used only when the statusline epoch is unavailable).
const RESET_TIME_RE = /reset[a-z]*\s+(?:at|by)?\s*(\d{1,2})(?::(\d{2}))?\s*(a\.?m\.?|p\.?m\.?)?/i;

const GRACE_S = 60;             // wait this many seconds PAST the reset epoch
const DEFAULT_MAX = 5;          // max resumes per session (B2)
const DEFAULT_FALLBACK_MIN = 300; // fixed-wait minutes when epoch unknown (B3)
const POLL_MS = 1000;           // how often the injected timer pumps checkTimers
const BUF_CAP = 4096;           // rolling output buffer cap for cross-chunk match

// Strip ANSI/VT escapes so the plain text can be pattern-matched.
const ANSI_RE = /\x1B(?:[@-Z\\-_]|\[[0-?]*[ -\/]*[@-~]|\][^\x07]*(?:\x07|\x1B\\))/g;
function stripAnsi(s) {
  return String(s).replace(ANSI_RE, '');
}

function intOr(v, dflt) {
  const n = parseInt(String(v == null ? '' : v).trim(), 10);
  return Number.isFinite(n) && n >= 0 ? n : dflt;
}

// Parse "09:00-17:00" (local) into minute-of-day bounds. Returns null when the
// value is empty or malformed (→ quiet hours disabled). Supports a window that
// wraps past midnight (e.g. "22:00-06:00").
function parseQuiet(spec) {
  const m = /^(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})$/.exec(String(spec || '').trim());
  if (!m) return null;
  const a = parseInt(m[1], 10) * 60 + parseInt(m[2], 10);
  const b = parseInt(m[3], 10) * 60 + parseInt(m[4], 10);
  if (a < 0 || a > 1439 || b < 0 || b > 1439) return null;
  return { start: a, end: b };
}

function inQuiet(window, nowMs) {
  if (!window) return false;
  const d = new Date(nowMs);
  const cur = d.getHours() * 60 + d.getMinutes();
  if (window.start === window.end) return false;
  if (window.start < window.end) return cur >= window.start && cur < window.end;
  // wraps past midnight
  return cur >= window.start || cur < window.end;
}

// Parse a clock time out of the block message and resolve it to the next
// occurrence at or after `nowMs` (local time). Returns epoch ms or null.
function parseResetFromMessage(text, nowMs) {
  const m = RESET_TIME_RE.exec(text);
  if (!m) return null;
  let hour = parseInt(m[1], 10);
  const min = m[2] ? parseInt(m[2], 10) : 0;
  const ap = (m[3] || '').replace(/\./g, '').toLowerCase();
  if (hour > 23 || min > 59) return null;
  if (ap === 'pm' && hour < 12) hour += 12;
  if (ap === 'am' && hour === 12) hour = 0;
  const d = new Date(nowMs);
  d.setHours(hour, min, 0, 0);
  let ms = d.getTime();
  if (ms <= nowMs) ms += 24 * 60 * 60 * 1000; // next day
  return ms;
}

function createAutoContinue(opts) {
  const {
    stateFile = null,
    log = () => {},
    now = () => Date.now(),
    write = () => {},
    config = {},
    // Injected timer (defaults to the globals). Tests pass no-ops and pump
    // checkTimers() by hand.
    setInterval: setIntervalFn = (fn, ms) => setInterval(fn, ms),
    clearInterval: clearIntervalFn = (h) => clearInterval(h),
  } = opts || {};

  const MAX = intOr(config.max, DEFAULT_MAX);
  const FALLBACK_MIN = intOr(config.fallbackMin, DEFAULT_FALLBACK_MIN);
  const QUIET = parseQuiet(config.quiet);

  // State: 'IDLE' → 'BLOCKED' (armed) → 'DONE'. `capped` is a terminal state
  // once the per-session resume cap is hit.
  let state = 'IDLE';
  let armedAt = null;   // epoch ms at which we may inject
  let resumeCount = 0;
  let capped = false;
  let buf = '';
  let disposed = false;

  function readResetsAtMs(nowMs) {
    if (!stateFile) return null;
    try {
      const j = JSON.parse(fs.readFileSync(stateFile, 'utf8'));
      const sec = j && j.five_hour && j.five_hour.resets_at;
      if (typeof sec === 'number' && sec > 0) {
        const ms = sec * 1000;
        // A freshly-observed block's real reset is ALWAYS in the future. An
        // epoch already <= now is stale — a previous window's reset, or the
        // statusline hasn't yet written the new window's epoch when we saw the
        // limit line. Trusting it would fire "continue" immediately, before the
        // real reset (and re-block/re-fire until the cap). Reject → fall through
        // to the message-parse / fixed-wait paths, which resolve to the future.
        if (ms > nowMs) return ms;
        log(`auto-continue: ignoring stale state-file resets_at (${new Date(ms).toISOString()} <= now)`);
      }
    } catch { /* missing / unreadable / malformed → fall through */ }
    return null;
  }

  // Decide when to inject. Prefer the statusline epoch, else the message time,
  // else a conservative fixed wait. Every branch resolves to a FUTURE instant.
  function resolveArmAt(plainText, nowMs) {
    const fromState = readResetsAtMs(nowMs);
    if (fromState != null) {
      return { at: fromState + GRACE_S * 1000, src: 'state-file' };
    }
    const fromMsg = parseResetFromMessage(plainText, nowMs);
    if (fromMsg != null && fromMsg > nowMs) {
      return { at: fromMsg + GRACE_S * 1000, src: 'message-parse' };
    }
    return { at: nowMs + FALLBACK_MIN * 60 * 1000, src: 'fixed-wait' };
  }

  function arm(plainText) {
    const nowMs = now();
    if (resumeCount >= MAX) {
      capped = true;
      log(`auto-continue: resume cap (${MAX}) reached; disarmed for this session`);
      return;
    }
    const { at, src } = resolveArmAt(plainText, nowMs);
    state = 'BLOCKED';
    armedAt = at;
    buf = ''; // clear so the same block text can't re-match as a "new" block
    log(`auto-continue: blocked; armed for ${new Date(at).toISOString()} (via ${src})`);
  }

  function fire() {
    write('continue\r');
    resumeCount += 1;
    state = 'DONE';
    armedAt = null;
    log(`auto-continue: injected "continue" (resume ${resumeCount}/${MAX}) at ${new Date(now()).toISOString()}`);
    if (resumeCount >= MAX) {
      capped = true;
      log(`auto-continue: resume cap (${MAX}) reached; disarmed for this session`);
    }
  }

  function checkTimers() {
    if (disposed || state !== 'BLOCKED' || armedAt == null) return;
    const nowMs = now();
    if (nowMs < armedAt) return;
    if (inQuiet(QUIET, nowMs)) return; // B4: hold inside quiet hours, re-check later
    fire();
  }

  function observeOutput(chunk) {
    if (disposed || capped) return;
    // Only a NEW block arms; repeated block lines while already armed are
    // ignored. (After DONE, a fresh match re-arms.)
    if (state === 'BLOCKED') return;
    buf = (buf + stripAnsi(chunk)).slice(-BUF_CAP);
    for (const re of LIMIT_PATTERNS) {
      if (re.test(buf)) {
        arm(buf);
        return;
      }
    }
  }

  function observeUserInput() {
    if (disposed) return;
    // The user is active. Never double-drive a session they resumed by hand:
    // disarm and let a genuinely NEW block re-arm later.
    if (state === 'BLOCKED') {
      state = 'IDLE';
      armedAt = null;
      buf = '';
      log('auto-continue: disarmed (user input while armed)');
    }
  }

  function dispose() {
    if (disposed) return;
    disposed = true;
    armedAt = null;
    if (pollHandle != null) {
      try { clearIntervalFn(pollHandle); } catch { /* noop */ }
      pollHandle = null;
    }
  }

  let pollHandle = setIntervalFn(checkTimers, POLL_MS);
  if (pollHandle && typeof pollHandle.unref === 'function') pollHandle.unref();

  return { observeOutput, observeUserInput, checkTimers, dispose };
}

module.exports = {
  createAutoContinue,
  // exported for tests
  stripAnsi,
  parseResetFromMessage,
  parseQuiet,
  inQuiet,
  LIMIT_PATTERNS,
  GRACE_S,
};
