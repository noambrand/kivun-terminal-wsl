'use strict';

const { StringDecoder } = require('node:string_decoder');

const RLE = '‫';
const PDF = '‬';

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

function isHebrew(cp) {
  return (cp >= HEBREW_BLOCK_START && cp <= HEBREW_BLOCK_END) ||
         (cp >= HEBREW_PRES_START && cp <= HEBREW_PRES_END);
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
    // rule: space / comma / period / etc. between Hebrew words stay inside
    // the bracket pair, but only if the next strong char is also Hebrew.
    this.pending = [];
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
      // Flush pending inside the run before emitting ESC so buffered
      // codepoints don't end up emitted after the ANSI sequence (which
      // would reorder them relative to their position in the input).
      let out = '';
      if (this.insideRun && this.pending.length > 0) {
        out += String.fromCodePoint(...this.pending);
        this.pending = [];
      }
      this.afterEsc = true;
      return out + ch;
    }
    return this._stepText(cp, ch);
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

  // At a write-boundary we have no lookahead, so we flush any pending
  // codepoints as if the run continued (inside), then close the bracket.
  // The alternative — flushing outside — would break fixture #5 when the
  // paragraph ends on a trailing space. Inside-flush is conservative and
  // visually identical for a plain space.
  //
  // Never close a bracket mid-ANSI (invariant 2 from HEAVY §2) — a PDF
  // codepoint injected mid-CSI/OSC would corrupt the escape. Hold the
  // bracket open until the ANSI sequence completes, unless `force` is set
  // (stream end with dangling ANSI: close anyway, caller's problem).
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

module.exports = { Injector, RLE, PDF, isHebrew };
