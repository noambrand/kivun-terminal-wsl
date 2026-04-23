'use strict';

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
  if (off < buf.length) {
    out += inj.write(buf.subarray(off));
  }
  out += inj.end();
  return out;
}

describe('HEAVY §7 extended fixtures (nice-to-have)', () => {
  it('#6 Hebrew-comma-Hebrew as single bracket pair — RLM prefix', () => {
    assert.equal(
      runOnce('שלום, עולם\n'),
      RLM + RLE + 'שלום, עולם' + PDF + '\n',
    );
  });

  it('#7 Hebrew-period-English — run closes at period, RLM at line start', () => {
    assert.equal(
      runOnce('שלום. Hello\n'),
      RLM + RLE + 'שלום' + PDF + '. Hello\n',
    );
  });

  it('#8 (שלום) — paren buffered at line start, RLM injected before the paren', () => {
    assert.equal(
      runOnce('(שלום)\n'),
      RLM + '(' + RLE + 'שלום' + PDF + ')\n',
    );
  });

  it('#12 chunk boundary mid-CSI escape — split after \\x1b[3, RLM on the first chunk', () => {
    const input = 'שלו\x1b[31mם\x1b[0m\n';
    const expected = RLM + RLE + 'שלו\x1b[31mם\x1b[0m' + PDF + '\n';
    const out = runChunked(input, [9]);
    assert.equal(out, expected);
  });

  it('#14 Hebrew presentation forms (U+FB1D–FB4F) — treated as Hebrew, RLM prefix', () => {
    const shinShinDot = String.fromCodePoint(0xFB2A);
    const alefPatah = String.fromCodePoint(0xFB2E);
    const input = shinShinDot + alefPatah + '\n';
    assert.equal(runOnce(input), RLM + RLE + shinShinDot + alefPatah + PDF + '\n');
  });

  it('#15 emoji between Hebrew runs — bracket closes and reopens, RLM once at line start', () => {
    const thumbsUp = String.fromCodePoint(0x1F44D);
    const input = 'שלום' + thumbsUp + 'עולם\n';
    const expected =
      RLM + RLE + 'שלום' + PDF + thumbsUp + RLE + 'עולם' + PDF + '\n';
    assert.equal(runOnce(input), expected);
  });

  it('#17 bracketed-paste with Hebrew — RLM before the paste sequence', () => {
    const input = '\x1b[200~שלום\x1b[201~\n';
    const expected = RLM + '\x1b[200~' + RLE + 'שלום\x1b[201~' + PDF + '\n';
    assert.equal(runOnce(input), expected);
  });

  it('#18 alt-screen toggle with Hebrew on both sides — RLM once per line', () => {
    const input = '\x1b[?1049hשלום\x1b[?1049lעולם\n';
    const expected =
      RLM + '\x1b[?1049h' + RLE + 'שלום\x1b[?1049lעולם' + PDF + '\n';
    assert.equal(runOnce(input), expected);
  });
});
