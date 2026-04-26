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
  }

  write(chunk) {
    const text = typeof chunk === 'string' ? chunk : this.decoder.write(chunk);
    let out = this._process(text);
    out += this._flushAtBoundary(false);
    return out;
  }

  end(chunk) {
    let text = '';
    if (chunk !== undefined && chunk !== null) {
      text += typeof chunk === 'string' ? chunk : this.decoder.write(chunk);
    }
    text += this.decoder.end();
    let out = this._process(text);
    if (this.lineStartBuffer.length > 0) {
      out += this._flushLineStartBuffer(false);
    }
    out += this._flushAtBoundary(true);
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
    if (this.inCsi) {
      if (isCsiFinal(cp)) this.inCsi = false;
      return ch;
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
      if (cp === CP_LBRACKET) this.inCsi = true;
      else if (cp === CP_RBRACKET) this.inOsc = true;
      return ch;
    }
    if (cp === CP_ESC) {
      let out = '';
      if (this.insideRun && this.pending.length > 0) {
        out += String.fromCodePoint(...this.pending);
        this.pending = [];
      }
      this.afterEsc = true;
      return out + ch;
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
      out += PDF;
      this.insideRun = false;
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
      out += PDF;
      this.insideRun = false;
    }
    return out;
  }
}

module.exports = { Injector, RLE, PDF, RLM, isHebrew };
