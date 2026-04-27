'use strict';

// HEAVY §8 NON-GOAL: do not substitute directional characters.
// Direction comes from BiDi markers (RLE/PDF/RLM) only, never from
// character substitution. Arrows (→ ← ↑ ↓), box-drawing chars
// (├ └ │ ─ ┌ ┐ ┘ ┤), and other directionally-asymmetric glyphs pass
// through unchanged. Browser-layer RTL extensions sometimes swap
// → ↔ ← in Hebrew paragraphs; that is correct for DOM content but
// WRONG for terminal output because tree renderers and status
// indicators in Claude Code rely on the original glyph. If you are
// reading this and considering adding a substitution table — don't.
// See docs/specs/BIDI_ALGORITHM.md for the full rationale.

const { StringDecoder } = require('node:string_decoder');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');

const RLE = '‫';
const PDF = '‬';
// RLM injected at line-start when the line's first strong char is RTL.
// Empirically verified via docs/research/paragraph-direction-test.sh that
// Konsole honors RLM at position 0 for paragraph-direction detection; other
// positions and RLE/RLI wraps don't flip paragraph direction on Konsole.
// This is what fixes the Claude Code `● שלום` first-line LTR bug.
const RLM = '‏';

// Strip leading bullet markers (●) on Hebrew lines. Konsole 23.x's BiDi
// "first non-whitespace char" heuristic classifies neutrals like ● as
// LTR-anchoring, which keeps the line LTR even with RLM at start. Just
// removing the bullet means the first visible char is Hebrew → BiDi
// flips the line to RTL automatically without any tricks.
//
// Opt-in via KIVUN_BIDI_STRIP_BULLET=on. Default off so v1.1.0–v1.1.7
// fixtures stay green and users who depend on bullet visibility aren't
// surprised.
const STRIP_BULLET = process.env.KIVUN_BIDI_STRIP_BULLET === 'on';
const BULLET_STRIP_RE = /[●•·∗•●]\s*/g;

// Strip-incoming bidi controls from the upstream stream so the wrapper has
// sole authority over directionality. Stripped: U+202A–U+202E (embedding
// controls LRE/RLE/PDF/LRO/RLO) and U+2066–U+2069 (isolate controls
// LRI/RLI/FSI/PDI). Preserved: U+200E (LRM) and U+200F (RLM) — the wrapper
// itself injects RLM and treats LRM as a useful neutral override.
//
// Modes (KIVUN_BIDI_STRIP_INCOMING):
//   off  — passthrough, no counting, no logging
//   auto — strip + count + log a single line on first detection (default)
//   on   — strip + count + log every chunk where stripping happened
//
// Rationale: Konsole 23.x's BiDi engine has known mis-positioning bugs for
// mixed RTL/LTR content. If Claude (or its child processes) emit explicit
// bidi controls, those compound with the wrapper's RLM injection and make
// rendering nondeterministic. Stripping them isolates the wrapper as the
// only directionality source. Even when the strip count is 0 the feature
// pays its way as a diagnostic — the side log answers "is my stream
// polluted?" without needing a packet capture.
//
// Side log: $KIVUN_BIDI_LOG_FILE if set, else
// $XDG_STATE_HOME/kivun-terminal/bidi-strip.log (XDG default
// ~/.local/state/kivun-terminal/bidi-strip.log). Test override via
// KIVUN_BIDI_LOG_FILE keeps unit tests off the user's real log.
const STRIP_INCOMING_MODE = (process.env.KIVUN_BIDI_STRIP_INCOMING || 'auto').toLowerCase();

// Flatten ANSI SGR (color/style) sequences inside RTL lines. ON by default
// (v1.1.10). Empirically confirmed via Konsole 23.08.5 A/B test (April 2026)
// that mixed-content LTR-run positioning inside Hebrew sentences is broken
// because Konsole's BiDi runs only span continuous-attribute regions — any
// color change splits the run and Qt mis-positions the resulting fragments.
// Stripping SGR escapes from RTL lines means the whole line is one
// attribute run and Konsole positions the LTR runs (English, code,
// numbers) at their correct UAX #9 logical positions.
//
// Trade-off: visible loss of syntax highlighting on Hebrew lines. Most
// Hebrew-focused users prefer correct positioning over color; users with
// English-dominant workflows can set this off to get color back at the
// cost of broken positioning when Hebrew appears.
//
// Modes (KIVUN_BIDI_FLATTEN_COLORS_RTL):
//   off — passthrough; SGR codes reach Konsole as-is on every line
//   on  — strip SGR codes from any line whose first strong char is Hebrew
//         (default — Hebrew users gain positioning, lose color)
const FLATTEN_COLORS_MODE = (process.env.KIVUN_BIDI_FLATTEN_COLORS_RTL || 'on').toLowerCase();
const CP_M = 0x6D;
const CP_C_UPPER = 0x43;
// Cursor-forward CSI parser: matches `\x1b[NC` (move cursor N columns
// forward, default 1). v1.1.13: empirically confirmed via DUMP_RAW that
// Claude Code's TUI uses cursor-forward instead of literal space chars
// for inter-word spacing, which splits Konsole's BiDi runs the same way
// SGR colors do. On RTL lines under FLATTEN_COLORS_RTL=on we substitute
// each cursor-forward with the equivalent number of space characters --
// visually identical (cursor-forward moved over presumed-blank cells;
// spaces write to the same cells), but no attribute-region boundary so
// the BiDi run survives whole.
const CSI_CURSOR_FORWARD_RE = /^\x1b\[(\d*)C$/;

// Per-run RLE/PDF bracketing of Hebrew runs INSIDE RTL paragraphs.
// Default OFF in v1.1.11+. Confirmed via Konsole 23.08.5 A/B test
// (April 2026, post-v1.1.10): bracketing each Hebrew run separately
// on an RTL line creates multiple attribute-change regions which
// Konsole's per-region BiDi mispositions — even with FLATTEN_COLORS_RTL
// stripping all SGR. The very RLE/PDF marks the wrapper emits act as
// attribute-region boundaries to Konsole. The same line rendered with
// just RLM at line-start (no per-run brackets) renders correctly.
//
// Hebrew runs INSIDE LTR PARAGRAPHS still get bracketed normally —
// the Hebrew is an exception inside an LTR flow and needs the marker
// for direction. Only RTL-paragraph runs are affected.
//
// Modes (KIVUN_BIDI_BRACKET_RTL_RUNS):
//   off — no per-run RLE/PDF bracketing on RTL lines (default v1.1.11+)
//   on  — bracket every Hebrew run regardless of paragraph direction
//         (legacy v1.1.0 - v1.1.10 behavior)
const BRACKET_RTL_RUNS = (process.env.KIVUN_BIDI_BRACKET_RTL_RUNS || 'off').toLowerCase();
// Char class covers U+202A LRE, U+202B RLE, U+202C PDF, U+202D LRO, U+202E RLO,
// U+2066 LRI, U+2067 RLI, U+2068 FSI, U+2069 PDI. Does NOT touch U+200E LRM
// or U+200F RLM (we keep those — RLM is what the wrapper itself injects).
const STRIP_INCOMING_RE = /[‪-‮⁦-⁩]/g;

// Cached at module load — tests that flip env vars then invalidate the
// require cache get a fresh STRIP_LOG_FILE per load, which is what the
// strip-incoming.test.js loader pattern relies on.
const STRIP_LOG_FILE = (function _resolveStripLogPath() {
  if (process.env.KIVUN_BIDI_LOG_FILE) return process.env.KIVUN_BIDI_LOG_FILE;
  const stateRoot = process.env.XDG_STATE_HOME || path.join(os.homedir(), '.local', 'state');
  return path.join(stateRoot, 'kivun-terminal', 'bidi-strip.log');
})();

function _logBidiStrip(message) {
  if (STRIP_INCOMING_MODE === 'off') return;
  try {
    fs.mkdirSync(path.dirname(STRIP_LOG_FILE), { recursive: true });
    fs.appendFileSync(STRIP_LOG_FILE, `[${new Date().toISOString()}] ${message}\n`);
  } catch (_) {
    // Logging is best-effort; never let a write failure crash the wrapper.
  }
}

// Raw upstream byte dump — debugging-only counterpart to strip-incoming.
// Off by default. When on, the wrapper appends every chunk it receives
// from Claude to a side file BEFORE the strip pass runs, so a hex/text
// inspection of the file shows exactly what was on the wire — bidi
// controls included. Useful for "the strip log says 0 detections but
// rendering looks bidi-confused" cases, and for proving that stream
// pollution we suspected really exists (or really doesn't).
//
// Modes (KIVUN_BIDI_DUMP_RAW):
//   off — no dump (default)
//   on  — append every chunk to the dump file with a timestamp marker
//
// Dump file: $KIVUN_BIDI_DUMP_RAW_FILE if set, else
// $XDG_STATE_HOME/kivun-terminal/bidi-raw-dump.bin (XDG default
// ~/.local/state/kivun-terminal/bidi-raw-dump.bin). At session start
// (constructor), if the existing dump file is larger than 5 MiB it gets
// renamed to .old so the new session always has a known starting point
// instead of running away in unbounded growth.
const DUMP_RAW_MODE = (process.env.KIVUN_BIDI_DUMP_RAW || 'off').toLowerCase();
const DUMP_RAW_FILE = (function _resolveDumpRawPath() {
  if (process.env.KIVUN_BIDI_DUMP_RAW_FILE) return process.env.KIVUN_BIDI_DUMP_RAW_FILE;
  const stateRoot = process.env.XDG_STATE_HOME || path.join(os.homedir(), '.local', 'state');
  return path.join(stateRoot, 'kivun-terminal', 'bidi-raw-dump.bin');
})();
const DUMP_RAW_ROTATE_BYTES = 5 * 1024 * 1024;

function _rotateDumpIfLarge() {
  if (DUMP_RAW_MODE === 'off') return;
  try {
    const st = fs.statSync(DUMP_RAW_FILE);
    if (st.size > DUMP_RAW_ROTATE_BYTES) {
      fs.renameSync(DUMP_RAW_FILE, DUMP_RAW_FILE + '.old');
    }
  } catch (_) {
    // File doesn't exist yet — that's fine, nothing to rotate.
  }
}

function _appendDumpRaw(chunk) {
  if (DUMP_RAW_MODE === 'off') return;
  try {
    fs.mkdirSync(path.dirname(DUMP_RAW_FILE), { recursive: true });
    // Buffer chunks pass through as bytes; string chunks get utf8-encoded.
    // This matches what the wrapper actually saw on the wire.
    const buf = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk, 'utf8');
    fs.appendFileSync(DUMP_RAW_FILE, buf);
  } catch (_) {
    // Best-effort; never let dump failure crash the wrapper.
  }
}

function _writeDumpMarker(label) {
  if (DUMP_RAW_MODE === 'off') return;
  try {
    fs.mkdirSync(path.dirname(DUMP_RAW_FILE), { recursive: true });
    fs.appendFileSync(DUMP_RAW_FILE, `\n=== ${label} ${new Date().toISOString()} ===\n`);
  } catch (_) {
    // Best-effort.
  }
}

const HEBREW_BLOCK_START = 0x0590;
const HEBREW_BLOCK_END = 0x05FF;
const HEBREW_PRES_START = 0xFB1D;
const HEBREW_PRES_END = 0xFB4F;

const CP_SPACE = 0x0020;
const CP_LF = 0x0A;
const CP_CR = 0x0D;
const CP_ESC = 0x1B;
const CP_BEL = 0x07;
const CP_LBRACKET = 0x5B;
const CP_RBRACKET = 0x5D;
const CP_BACKSLASH = 0x5C;

const EXTENDABLE_PUNCT = new Set([
  0x002C, 0x002E, 0x003B, 0x003A, 0x003F,
  0x05F3, 0x05F4,
]);

// Cap on line-start buffer. Claude's bullet-prefix lines are typically
// under 200 chars before the first strong Hebrew char; this is a safety
// valve so a pathological input (e.g., an infinite escape sequence without
// a newline) doesn't hold the stream hostage.
const LINE_START_BUFFER_MAX = 2048;

function isHebrew(cp) {
  return (cp >= HEBREW_BLOCK_START && cp <= HEBREW_BLOCK_END) ||
         (cp >= HEBREW_PRES_START && cp <= HEBREW_PRES_END);
}

// Tight predicate — Latin letters only. Widening to full UAX #9 L-class
// coverage (Cyrillic, Greek, CJK, etc.) is v2 work. Claude Code output is
// Latin + Hebrew in practice.
function isStrongLTR(cp) {
  if (cp >= 0x0041 && cp <= 0x005A) return true;
  if (cp >= 0x0061 && cp <= 0x007A) return true;
  if (cp >= 0x00C0 && cp <= 0x02AF) return true;
  return false;
}

function isCsiFinal(cp) {
  return cp >= 0x40 && cp <= 0x7E;
}

class Injector {
  constructor() {
    this.decoder = new StringDecoder('utf8');
    this.inCsi = false;
    this.inOsc = false;
    this.oscSawEsc = false;
    this.afterEsc = false;
    this.insideRun = false;
    // Codepoints provisionally inside a run, awaiting a following Hebrew
    // codepoint to confirm them as run-internal. See HEAVY §2 punctuation
    // rule.
    this.pending = [];
    // Line-start RLM buffering. Hold chars since last \n until we know
    // whether the first strong char is RTL (Hebrew → inject RLM) or LTR
    // (Latin → no RLM). See `docs/research/paragraph-direction-test.sh`.
    this.atLineStart = true;
    this.lineStartBuffer = '';
    // Mirror ANSI state during line-start buffering so that CSI/OSC internal
    // bytes (e.g., the `h` terminating `\x1b[?1049h`) don't get misread as
    // strong-L chars. Main inCsi/inOsc/afterEsc are not advanced during
    // buffering — the buffer is re-processed at flush time and those vars
    // update correctly then.
    this._lsInCsi = false;
    this._lsInOsc = false;
    this._lsOscSawEsc = false;
    this._lsAfterEsc = false;
    // strip-incoming counters. Public field (`stripIncomingCount`) so unit
    // tests can assert on it directly without parsing the side log.
    this.stripIncomingCount = 0;
    this._stripLoggedFirst = false;
    // FLATTEN_COLORS_RTL state. lineIsRTL is set in _flushLineStartBuffer
    // based on whether the line's first strong char is Hebrew. _csiBuf
    // accumulates ESC...final-byte sequences so we can drop SGR ones on
    // RTL lines instead of byte-by-byte emit (v1.1.10).
    this.lineIsRTL = false;
    this._csiBuf = '';
    // Public counter — number of SGR sequences this Injector dropped.
    // Useful for tests + diagnostic output.
    this.flattenedSgrCount = 0;
    // Public counter — number of cursor-forward CSI sequences replaced
    // with literal spaces on RTL lines (v1.1.13).
    this.cursorForwardReplacedCount = 0;
    // Per-run bracketing tracking — set when we emit RLE for a run so
    // the matching PDF emit knows whether it should fire. When BRACKET_RTL_RUNS
    // is off and the line is RTL, runIsBracketed stays false through the run
    // and no PDF gets emitted at the end (mirrors no RLE at start).
    this.runIsBracketed = false;
    // Per-session raw-dump bookkeeping. Rotate any leftover oversized dump
    // file from a prior session, then write a session-start marker so each
    // run is delineated in the file when the user inspects it later.
    _rotateDumpIfLarge();
    _writeDumpMarker('session start');
  }

  // Best-effort strip + accounting on raw upstream text. Runs before any
  // state-machine processing so the line-start buffer / RLE-PDF bracketing
  // never sees the stripped chars at all. See block comment near
  // STRIP_INCOMING_MODE for rationale and modes.
  _stripIncoming(text) {
    if (STRIP_INCOMING_MODE === 'off' || text.length === 0) return text;
    const before = text.length;
    const out = text.replace(STRIP_INCOMING_RE, '');
    const removed = before - out.length;
    if (removed > 0) {
      this.stripIncomingCount += removed;
      if (!this._stripLoggedFirst) {
        _logBidiStrip(`first detection — stripped ${removed} bidi control char(s) (cumulative ${this.stripIncomingCount}); set KIVUN_BIDI_STRIP_INCOMING=off in config.txt to passthrough`);
        this._stripLoggedFirst = true;
      } else if (STRIP_INCOMING_MODE === 'on') {
        _logBidiStrip(`stripped ${removed} bidi control char(s) (cumulative ${this.stripIncomingCount})`);
      }
    }
    return out;
  }

  write(chunk) {
    _appendDumpRaw(chunk);
    const raw = typeof chunk === 'string' ? chunk : this.decoder.write(chunk);
    const text = this._stripIncoming(raw);
    let out = this._process(text);
    out += this._flushAtBoundary(false);
    return out;
  }

  end(chunk) {
    if (chunk !== undefined && chunk !== null) _appendDumpRaw(chunk);
    let raw = '';
    if (chunk !== undefined && chunk !== null) {
      raw += typeof chunk === 'string' ? chunk : this.decoder.write(chunk);
    }
    raw += this.decoder.end();
    const text = this._stripIncoming(raw);
    let out = this._process(text);
    if (this.lineStartBuffer.length > 0) {
      out += this._flushLineStartBuffer(false);
    }
    out += this._flushAtBoundary(true);
    if (this.stripIncomingCount > 0 && STRIP_INCOMING_MODE !== 'off') {
      _logBidiStrip(`session end — total ${this.stripIncomingCount} bidi control char(s) stripped this session`);
    }
    _writeDumpMarker('session end');
    return out;
  }

  _process(text) {
    let out = '';
    for (const ch of text) {
      out += this._step(ch.codePointAt(0), ch);
    }
    return out;
  }

  _step(cp, ch) {
    if (this.atLineStart) {
      return this._stepAtLineStart(cp, ch);
    }
    return this._stepAfterLineStart(cp, ch);
  }

  _stepAtLineStart(cp, ch) {
    // Inside ANSI sequence → just buffer, don't classify (CSI params like
    // digits or finals like 'h' must not be treated as strong chars).
    if (this._lsInCsi) {
      this.lineStartBuffer += ch;
      if (isCsiFinal(cp)) this._lsInCsi = false;
      return '';
    }
    if (this._lsInOsc) {
      this.lineStartBuffer += ch;
      if (cp === CP_BEL) {
        this._lsInOsc = false;
        this._lsOscSawEsc = false;
      } else if (this._lsOscSawEsc && cp === CP_BACKSLASH) {
        this._lsInOsc = false;
        this._lsOscSawEsc = false;
      } else {
        this._lsOscSawEsc = (cp === CP_ESC);
      }
      return '';
    }
    if (this._lsAfterEsc) {
      this.lineStartBuffer += ch;
      this._lsAfterEsc = false;
      if (cp === CP_LBRACKET) this._lsInCsi = true;
      else if (cp === CP_RBRACKET) this._lsInOsc = true;
      return '';
    }
    if (cp === CP_ESC) {
      this.lineStartBuffer += ch;
      this._lsAfterEsc = true;
      return '';
    }

    if (isHebrew(cp)) {
      return this._flushLineStartBuffer(true) + this._stepAfterLineStart(cp, ch);
    }
    if (isStrongLTR(cp)) {
      return this._flushLineStartBuffer(false) + this._stepAfterLineStart(cp, ch);
    }
    if (cp === CP_LF || cp === CP_CR) {
      this.lineStartBuffer += ch;
      const out = this.lineStartBuffer;
      this.lineStartBuffer = '';
      return out;
    }
    this.lineStartBuffer += ch;
    if (this.lineStartBuffer.length > LINE_START_BUFFER_MAX) {
      return this._flushLineStartBuffer(false);
    }
    return '';
  }

  _flushLineStartBuffer(injectRlm) {
    const buffered = this.lineStartBuffer;
    this.lineStartBuffer = '';
    this.atLineStart = false;
    // Reset buffer-local ANSI shadow state; main inCsi/inOsc/afterEsc take
    // over via _stepAfterLineStart below.
    this._lsInCsi = false;
    this._lsInOsc = false;
    this._lsOscSawEsc = false;
    this._lsAfterEsc = false;
    // FLATTEN_COLORS_RTL: set lineIsRTL BEFORE re-feeding the buffered
    // content so SGR escapes inside the line-start region get the same
    // flatten treatment as SGR escapes after the first strong char.
    this.lineIsRTL = injectRlm;
    let buffered_processed = buffered;
    if (injectRlm && STRIP_BULLET) {
      buffered_processed = buffered_processed.replace(BULLET_STRIP_RE, '');
    }
    let out = injectRlm ? RLM : '';
    for (const ch of buffered_processed) {
      out += this._stepAfterLineStart(ch.codePointAt(0), ch);
    }
    return out;
  }

  _stepAfterLineStart(cp, ch) {
    // CSI buffer-and-decide: accumulate the whole ESC[...final-byte
    // sequence so we can drop it as a unit if it turns out to be SGR
    // (final byte 'm') on an RTL line. Without buffering we'd already
    // have emitted ESC + [ + params before knowing it was SGR.
    if (this.inCsi) {
      this._csiBuf += ch;
      if (isCsiFinal(cp)) {
        this.inCsi = false;
        const seq = this._csiBuf;
        this._csiBuf = '';
        if (cp === CP_M && this.lineIsRTL && FLATTEN_COLORS_MODE === 'on') {
          this.flattenedSgrCount += 1;
          return '';
        }
        // v1.1.13: cursor-forward replacement on RTL lines. Claude's TUI
        // uses CSI [NC instead of literal spaces between words; on RTL
        // lines this splits the BiDi run the same way SGR colors did.
        // Replace with N space chars so the line is one continuous BiDi
        // region. Visually identical (cursor moved over blank cells; we
        // write spaces into those same cells).
        if (cp === CP_C_UPPER && this.lineIsRTL && FLATTEN_COLORS_MODE === 'on') {
          const m = seq.match(CSI_CURSOR_FORWARD_RE);
          if (m) {
            const n = m[1] === '' ? 1 : parseInt(m[1], 10);
            this.cursorForwardReplacedCount += 1;
            return ' '.repeat(n);
          }
        }
        return seq;
      }
      return '';
    }
    if (this.inOsc) {
      if (cp === CP_BEL) {
        this.inOsc = false;
        this.oscSawEsc = false;
      } else if (this.oscSawEsc && cp === CP_BACKSLASH) {
        this.inOsc = false;
        this.oscSawEsc = false;
      } else {
        this.oscSawEsc = (cp === CP_ESC);
      }
      return ch;
    }
    if (this.afterEsc) {
      this.afterEsc = false;
      this._csiBuf += ch;
      if (cp === CP_LBRACKET) {
        this.inCsi = true;
        return '';
      }
      // Not a CSI — flush whatever we accumulated. OSC (ESC ]) gets the
      // accumulated bytes flushed and resumes per-byte from here on; any
      // other ESC + char (e.g., ESC 7 / ESC =) also flushes immediately.
      const seq = this._csiBuf;
      this._csiBuf = '';
      if (cp === CP_RBRACKET) this.inOsc = true;
      return seq;
    }
    if (cp === CP_ESC) {
      let out = '';
      if (this.insideRun && this.pending.length > 0) {
        out += String.fromCodePoint(...this.pending);
        this.pending = [];
      }
      this.afterEsc = true;
      this._csiBuf = ch;
      return out;
    }
    const out = this._stepText(cp, ch);
    if (cp === CP_LF || cp === CP_CR) {
      this.atLineStart = true;
    }
    return out;
  }

  _stepText(cp, ch) {
    if (this.insideRun) {
      return this._stepTextInRun(cp, ch);
    }
    if (isHebrew(cp)) {
      this.insideRun = true;
      // Skip RLE prefix on RTL lines when per-run bracketing is off:
      // line-start RLM + UAX #9 handle direction correctly without
      // creating extra attribute boundaries that confuse Konsole.
      if (this.lineIsRTL && BRACKET_RTL_RUNS === 'off') {
        this.runIsBracketed = false;
        return ch;
      }
      this.runIsBracketed = true;
      return RLE + ch;
    }
    return ch;
  }

  _stepTextInRun(cp, ch) {
    if (isHebrew(cp)) {
      const flushed = this._commitPendingInside();
      return flushed + ch;
    }
    if (cp === CP_LF || cp === CP_CR) {
      return this._commitPendingOutside() + ch;
    }
    if (cp === CP_SPACE) {
      this.pending.push(cp);
      return '';
    }
    if (EXTENDABLE_PUNCT.has(cp) && this.pending.length === 0) {
      this.pending.push(cp);
      return '';
    }
    return this._commitPendingOutside() + ch;
  }

  _commitPendingInside() {
    if (this.pending.length === 0) return '';
    const s = String.fromCodePoint(...this.pending);
    this.pending = [];
    return s;
  }

  _commitPendingOutside() {
    let out = '';
    if (this.insideRun) {
      // PDF only fires if we emitted RLE for this run. With per-run
      // bracketing off on RTL lines (v1.1.11+ default), runIsBracketed
      // stays false through the run and we emit no closing PDF.
      if (this.runIsBracketed) out += PDF;
      this.insideRun = false;
      this.runIsBracketed = false;
    }
    if (this.pending.length > 0) {
      out += String.fromCodePoint(...this.pending);
      this.pending = [];
    }
    return out;
  }

  // Line-start buffer is NOT flushed at chunk boundary — held across chunks
  // so the bullet-prefix RLM fix survives Claude's token-by-token streaming
  // (where "● " and the Hebrew that follows may arrive in separate write()
  // calls). Only end() force-flushes it.
  _flushAtBoundary(force) {
    if (!force && (this.inCsi || this.inOsc || this.afterEsc)) return '';
    let out = '';
    if (this.pending.length > 0) {
      out += String.fromCodePoint(...this.pending);
      this.pending = [];
    }
    if (this.insideRun) {
      if (this.runIsBracketed) out += PDF;
      this.insideRun = false;
      this.runIsBracketed = false;
    }
    // FLATTEN_COLORS: if the stream ended mid-CSI (orphan ESC + [ + params
    // with no final byte ever arriving), emit what we buffered so the
    // bytes don't get silently lost.
    if (force && this._csiBuf.length > 0) {
      out += this._csiBuf;
      this._csiBuf = '';
      this.afterEsc = false;
      this.inCsi = false;
    }
    return out;
  }
}

module.exports = { Injector, RLE, PDF, RLM, isHebrew };
