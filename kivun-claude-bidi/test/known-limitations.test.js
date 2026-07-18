'use strict';

// F2 / F4 (v1.7.1) — behavior-pinning fixtures for a few narrow edge inputs
// under the shipping defaults. These assert only what the injector VERIFIABLY
// emits (whether a line-start RLM is present), so a future change to that
// behavior is caught in review. They make NO claim about how the result looks
// on screen — only about the bytes the wrapper produces.
//
// Design note: the wrapper decides direction per hard line from a byte stream,
// with no model of code fences or wrapped paragraphs. Any runtime heuristic to
// change that (comment detection, continuation-line inference) is intentionally
// out of scope — it would repeat the v1.1.14/v1.1.15 input-box bug class. The
// Claude desktop app is served by a separate DOM/CSS tool
// (liorshaya/claude-desktop-rtl) at a different layer.
process.env.KIVUN_BIDI_FLATTEN_COLORS_RTL = 'on';
process.env.KIVUN_BIDI_BRACKET_RTL_RUNS = 'off';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { Injector, RLM } = require('../lib/injector');

function runOnce(input) {
  const inj = new Injector();
  return inj.write(Buffer.from(input, 'utf8')) + inj.end();
}

describe('Default-mode behavior pins (byte-level; no visual claims)', () => {
  // A line whose first strong char is Hebrew gets a line-start RLM, whether or
  // not the rest of the line is an English command. Verified: RLM present.
  it('Hebrew-first line (with trailing English command) gets a line-start RLM', () => {
    const input = '# הסבר: run npm install --production\n';
    assert.equal(runOnce(input), RLM + '# הסבר: run npm install --production\n');
  });

  it('Pure-Hebrew comment line gets a line-start RLM', () => {
    const input = '# שלום עולם הכל בסדר\n';
    assert.equal(runOnce(input), RLM + '# שלום עולם הכל בסדר\n');
  });

  // Direction is decided per hard line: a Hebrew-first line gets an RLM, a
  // Latin-first line does not. Verified at the byte level on each line.
  it('per-line direction: Hebrew-first line has RLM, Latin-first line does not', () => {
    const input = 'זהו פסקה בעברית שנמשכת\nnpm install היא הפקודה\n';
    const lines = runOnce(input).split('\n');
    assert.ok(lines[0].startsWith(RLM), 'Hebrew-first line gets RLM');
    assert.ok(!lines[1].startsWith(RLM), 'Latin-first line gets no RLM');
  });
});
