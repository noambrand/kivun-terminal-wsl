'use strict';

// F1 (v1.7.1) — extended fixtures against the SHIPPING DEFAULT env combo.
// See core-defaults.test.js for the rationale. extended.test.js pins the
// legacy combo; this file re-runs the same inputs with the shipping defaults
// (FLATTEN_COLORS_RTL='on', BRACKET_RTL_RUNS='off') and asserts default-mode
// output. All inputs here are RTL lines (first strong char Hebrew), so the
// expected output is one leading RLM, SGR stripped, and no per-run brackets.
process.env.KIVUN_BIDI_FLATTEN_COLORS_RTL = 'on';
process.env.KIVUN_BIDI_BRACKET_RTL_RUNS = 'off';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { Injector, RLE, PDF, RLM } = require('../lib/injector');

function runOnce(input) {
  const inj = new Injector();
  return inj.write(Buffer.from(input, 'utf8')) + inj.end();
}

function runChunked(input, byteLengths) {
  const buf = Buffer.from(input, 'utf8');
  const inj = new Injector();
  let out = '';
  let off = 0;
  for (const len of byteLengths) {
    out += inj.write(buf.subarray(off, off + len));
    off += len;
  }
  if (off < buf.length) out += inj.write(buf.subarray(off));
  out += inj.end();
  return out;
}

describe('HEAVY §7 extended fixtures — SHIPPING DEFAULTS (FLATTEN=on, BRACKET=off)', () => {
  it('#6 Hebrew-comma-Hebrew — RLM prefix, single unbracketed run', () => {
    assert.equal(runOnce('שלום, עולם\n'), RLM + 'שלום, עולם\n');
  });

  it('#7 Hebrew-period-English — RLM prefix, run flows unbracketed into Latin', () => {
    assert.equal(runOnce('שלום. Hello\n'), RLM + 'שלום. Hello\n');
  });

  it('#8 (שלום) — paren buffered at line start, RLM before the paren, no bracket', () => {
    assert.equal(runOnce('(שלום)\n'), RLM + '(שלום)\n');
  });

  it('#12 chunk boundary mid-CSI escape — SGR stripped, RLM only, no bracket', () => {
    const out = runChunked('שלו\x1b[31mם\x1b[0m\n', [9]);
    assert.equal(out, RLM + 'שלום\n');
  });

  it('#14 Hebrew presentation forms (U+FB1D–FB4F) — RLM prefix, no bracket', () => {
    const shinShinDot = String.fromCodePoint(0xFB2A);
    const alefPatah = String.fromCodePoint(0xFB2E);
    assert.equal(
      runOnce(shinShinDot + alefPatah + '\n'),
      RLM + shinShinDot + alefPatah + '\n',
    );
  });

  it('#15 emoji between Hebrew runs — RLM once, runs flow unbracketed around emoji', () => {
    const thumbsUp = String.fromCodePoint(0x1F44D);
    assert.equal(
      runOnce('שלום' + thumbsUp + 'עולם\n'),
      RLM + 'שלום' + thumbsUp + 'עולם\n',
    );
  });

  it('#17 bracketed-paste with Hebrew — RLM before the paste sequence, no bracket', () => {
    assert.equal(
      runOnce('\x1b[200~שלום\x1b[201~\n'),
      RLM + '\x1b[200~שלום\x1b[201~\n',
    );
  });

  it('#18 alt-screen toggle with Hebrew on both sides — RLM once, no bracket', () => {
    assert.equal(
      runOnce('\x1b[?1049hשלום\x1b[?1049lעולם\n'),
      RLM + '\x1b[?1049hשלום\x1b[?1049lעולם\n',
    );
  });
});
