'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { Injector, RLE, PDF } = require('../lib/injector');

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
  it('#6 Hebrew-comma-Hebrew as single bracket pair', () => {
    assert.equal(
      runOnce('שלום, עולם\n'),
      RLE + 'שלום, עולם' + PDF + '\n',
    );
  });

  it('#7 Hebrew-period-English — run closes at period', () => {
    assert.equal(
      runOnce('שלום. Hello\n'),
      RLE + 'שלום' + PDF + '. Hello\n',
    );
  });

  it('#8 (שלום) — Hebrew inside parens, parens stay outside', () => {
    assert.equal(
      runOnce('(שלום)\n'),
      '(' + RLE + 'שלום' + PDF + ')\n',
    );
  });

  it('#12 chunk boundary mid-CSI escape — split after \\x1b[3', () => {
    const input = 'שלו\x1b[31mם\x1b[0m\n';
    const expected = RLE + 'שלו\x1b[31mם\x1b[0m' + PDF + '\n';
    // Byte 9 = after 'שלו\x1b[3', next chunk starts at '1m...'.
    const out = runChunked(input, [9]);
    assert.equal(out, expected);
  });

  it('#14 Hebrew presentation forms (U+FB1D–FB4F) — treated as Hebrew', () => {
    const shinShinDot = String.fromCodePoint(0xFB2A);
    const alefPatah = String.fromCodePoint(0xFB2E);
    const input = shinShinDot + alefPatah + '\n';
    assert.equal(runOnce(input), RLE + shinShinDot + alefPatah + PDF + '\n');
  });

  it('#15 emoji between Hebrew runs — bracket closes and reopens', () => {
    const thumbsUp = String.fromCodePoint(0x1F44D);
    const input = 'שלום' + thumbsUp + 'עולם\n';
    const expected =
      RLE + 'שלום' + PDF + thumbsUp + RLE + 'עולם' + PDF + '\n';
    assert.equal(runOnce(input), expected);
  });

  it('#17 bracketed-paste sequence with Hebrew — Hebrew inside paste gets bracketed', () => {
    const input = '\x1b[200~שלום\x1b[201~\n';
    const expected = '\x1b[200~' + RLE + 'שלום\x1b[201~' + PDF + '\n';
    assert.equal(runOnce(input), expected);
  });

  it('#18 alt-screen toggle with Hebrew on both sides — brackets balanced', () => {
    const input = '\x1b[?1049hשלום\x1b[?1049lעולם\n';
    const expected =
      '\x1b[?1049h' + RLE + 'שלום\x1b[?1049lעולם' + PDF + '\n';
    assert.equal(runOnce(input), expected);
  });
});
