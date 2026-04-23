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

describe('HEAVY §7 core fixtures (ship-blocking)', () => {
  it('#1 plain ASCII line', () => {
    assert.equal(runOnce('hello world\n'), 'hello world\n');
  });

  it('#2 pure Hebrew line — RLM prefix + bracket', () => {
    assert.equal(runOnce('שלום\n'), RLM + RLE + 'שלום' + PDF + '\n');
  });

  it('#3 Hello שלום world — no RLM (first strong is L)', () => {
    assert.equal(
      runOnce('Hello שלום world\n'),
      'Hello ' + RLE + 'שלום' + PDF + ' world\n',
    );
  });

  it('#4 multiple Hebrew runs separated by Latin — no RLM', () => {
    assert.equal(
      runOnce('foo שלום bar עולם baz\n'),
      'foo ' + RLE + 'שלום' + PDF + ' bar ' + RLE + 'עולם' + PDF + ' baz\n',
    );
  });

  it('#5 שלום עולם as single bracket pair — RLM prefix', () => {
    assert.equal(
      runOnce('שלום עולם\n'),
      RLM + RLE + 'שלום עולם' + PDF + '\n',
    );
  });

  it('#9 ANSI SGR mid-Hebrew run — RLM prefix, bracket stays open across color change', () => {
    const input = 'שלו\x1b[31mם\x1b[0m\n';
    const expected = RLM + RLE + 'שלו\x1b[31mם\x1b[0m' + PDF + '\n';
    assert.equal(runOnce(input), expected);
  });

  it('#10 chunk boundary mid-Hebrew run — PDF at chunk end, RLE reopens next chunk (RLM only once)', () => {
    const out = runChunked('שלוםעולם', [6]);
    assert.equal(out, RLM + RLE + 'שלו' + PDF + RLE + 'םעולם' + PDF);
  });

  it('#11 chunk boundary mid-UTF-8 codepoint — StringDecoder buffers, RLM after decode', () => {
    const out = runChunked('שלום', [1]);
    assert.equal(out, RLM + RLE + 'שלום' + PDF);
  });

  it('#13 newline inside Hebrew run — each line gets its own RLM prefix', () => {
    assert.equal(
      runOnce('שלום\nעולם\n'),
      RLM + RLE + 'שלום' + PDF + '\n' + RLM + RLE + 'עולם' + PDF + '\n',
    );
  });

  it('#16 long Hebrew paragraph (~500 chars) — single RLM + single bracket pair', () => {
    const hebrew = 'ש'.repeat(500);
    assert.equal(
      runOnce(hebrew + '\n'),
      RLM + RLE + hebrew + PDF + '\n',
    );
  });
});

describe('Line-start RLM edge cases', () => {
  it('bullet-prefix Hebrew line (Claude Code pattern) — RLM at position 0', () => {
    assert.equal(
      runOnce('● שלום\n'),
      RLM + '● ' + RLE + 'שלום' + PDF + '\n',
    );
  });

  it('mixed Latin-first line — no RLM (first strong is L)', () => {
    assert.equal(
      runOnce('Hello ● שלום world\n'),
      'Hello ● ' + RLE + 'שלום' + PDF + ' world\n',
    );
  });

  it('empty line with just whitespace — no RLM, no modification', () => {
    assert.equal(runOnce('   \n'), '   \n');
  });

  it('chunk boundary mid-line-start-buffer (hold across chunks)', () => {
    const out = runChunked('● שלום\n', [3]);
    assert.equal(out, RLM + '● ' + RLE + 'שלום' + PDF + '\n');
  });
});
