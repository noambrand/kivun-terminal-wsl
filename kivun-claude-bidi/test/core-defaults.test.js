'use strict';

// F1 (v1.7.1) — core fixtures run against the SHIPPING DEFAULT env combo.
//
// core.test.js pins the legacy v1.1.0 combo (FLATTEN_COLORS_RTL='off',
// BRACKET_RTL_RUNS='on'). Those pins mean the richest fixture corpus never
// exercises the code path real users run: the shipping defaults are
// FLATTEN_COLORS_RTL='on' (strip SGR on RTL lines) and BRACKET_RTL_RUNS='off'
// (no per-run RLE/PDF on RTL lines — rely on the line-start RLM + UAX #9).
//
// This file re-runs the same INPUTS as core.test.js with the shipping
// defaults pinned, and asserts the default-mode expected output. Expectations
// are derived from the injector semantics (RTL lines: one leading RLM, SGR
// stripped, no per-run brackets; Latin-first lines: Hebrew islands still get
// RLE/PDF and SGR is NOT stripped), not pasted from actual output.
//
// Do NOT change the legacy-pinned core.test.js — it intentionally guards the
// legacy env combination.
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

describe('HEAVY §7 core fixtures — SHIPPING DEFAULTS (FLATTEN=on, BRACKET=off)', () => {
  it('#1 plain ASCII line — untouched', () => {
    assert.equal(runOnce('hello world\n'), 'hello world\n');
  });

  it('#2 pure Hebrew line — RLM prefix only, no per-run bracket', () => {
    assert.equal(runOnce('שלום\n'), RLM + 'שלום\n');
  });

  it('#3 Latin-first line — no RLM, Hebrew island still bracketed', () => {
    // Latin-first → lineIsRTL=false → island bracketing and SGR flattening
    // are NOT applied; identical to legacy behavior.
    assert.equal(
      runOnce('Hello שלום world\n'),
      'Hello ' + RLE + 'שלום' + PDF + ' world\n',
    );
  });

  it('#4 multiple Hebrew islands on a Latin-first line — still bracketed', () => {
    assert.equal(
      runOnce('foo שלום bar עולם baz\n'),
      'foo ' + RLE + 'שלום' + PDF + ' bar ' + RLE + 'עולם' + PDF + ' baz\n',
    );
  });

  it('#5 שלום עולם — RLM prefix, single unbracketed run', () => {
    assert.equal(runOnce('שלום עולם\n'), RLM + 'שלום עולם\n');
  });

  it('#9 ANSI SGR mid-Hebrew run — SGR stripped, no bracket', () => {
    // RTL line: FLATTEN drops both SGR sequences, BRACKET=off drops the
    // per-run RLE/PDF, leaving just the RLM prefix + plain Hebrew.
    assert.equal(runOnce('שלו\x1b[31mם\x1b[0m\n'), RLM + 'שלום\n');
  });

  it('#10 chunk boundary mid-Hebrew run — one RLM, no PDF/RLE reopen', () => {
    // No bracketing on RTL lines, so the chunk split leaves no PDF/RLE
    // seam — just the single leading RLM.
    assert.equal(runChunked('שלוםעולם', [6]), RLM + 'שלוםעולם');
  });

  it('#11 chunk boundary mid-UTF-8 codepoint — RLM after decode, no bracket', () => {
    assert.equal(runChunked('שלום', [1]), RLM + 'שלום');
  });

  it('#13 newline inside Hebrew run — each line gets its own RLM, no brackets', () => {
    assert.equal(
      runOnce('שלום\nעולם\n'),
      RLM + 'שלום\n' + RLM + 'עולם\n',
    );
  });

  it('#16 long Hebrew paragraph (~500 chars) — single RLM, no bracket', () => {
    const hebrew = 'ש'.repeat(500);
    assert.equal(runOnce(hebrew + '\n'), RLM + hebrew + '\n');
  });
});

describe('Line-start RLM edge cases — SHIPPING DEFAULTS', () => {
  it('bullet-prefix Hebrew line — RLM at position 0, no bracket', () => {
    assert.equal(runOnce('● שלום\n'), RLM + '● ' + 'שלום\n');
  });

  it('mixed Latin-first line — no RLM, Hebrew island still bracketed', () => {
    assert.equal(
      runOnce('Hello ● שלום world\n'),
      'Hello ● ' + RLE + 'שלום' + PDF + ' world\n',
    );
  });

  it('empty line with just whitespace — no RLM, no modification', () => {
    assert.equal(runOnce('   \n'), '   \n');
  });

  it('chunk boundary mid-line-start-buffer (hold across chunks)', () => {
    assert.equal(runChunked('● שלום\n', [3]), RLM + '● ' + 'שלום\n');
  });
});
