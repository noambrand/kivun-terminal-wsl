// test/core.test.js — 10 ship-blocking fixtures (Noam-approved 2026-04-23).
// ALL MUST PASS before feat/bidi-wrapper-heavy merges and v1.1.0 tags.
// Partition rationale: docs/specs/ROADMAP.md and HEAVY spec §7.
//
// These are placeholder stubs. Real assertions land when the injector is
// written (post-approval).

const { describe, it } = require('node:test');

describe('HEAVY §7 core fixtures (ship-blocking)', () => {
  it.todo('#1 plain ASCII line — no brackets, no regression');
  it.todo('#2 pure Hebrew line — one RLE at start, one PDF before \n');
  it.todo('#3 Hello שלום world — Hebrew run bracketed between Latin');
  it.todo('#4 multiple Hebrew runs separated by Latin — each gets its own pair');
  it.todo('#5 שלום עולם — Hebrew-space-Hebrew as single bracket pair');
  it.todo('#9 ANSI SGR mid-Hebrew run — bracket stays open through color change');
  it.todo('#10 chunk boundary mid-Hebrew run — PDF at end, RLE re-emitted next chunk');
  it.todo('#11 chunk boundary mid-UTF-8 codepoint — StringDecoder buffers correctly');
  it.todo('#13 \n inside Hebrew run — PDF before \n, fresh run on next line');
  it.todo('#16 ~500-char Hebrew paragraph — single bracket pair, no corruption');
});
