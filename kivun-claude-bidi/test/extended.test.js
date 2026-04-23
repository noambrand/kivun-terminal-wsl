// test/extended.test.js — 8 nice-to-have fixtures (non-blocking for v1.1.0).
// Each has a documented fallback in HEAVY §2–§3. Failures ship as known
// limitations in v1.1.0 release notes rather than blocking the tag.
//
// Placeholder stubs; real assertions land post-approval alongside core.

const { describe, it } = require('node:test');

describe('HEAVY §7 extended fixtures (nice-to-have)', () => {
  it.todo('#6 Hebrew-comma-Hebrew — single bracket pair across comma');
  it.todo('#7 Hebrew-period-English — Hebrew run closes at period');
  it.todo('#8 (שלום) — Hebrew inside parens, parens stay outside brackets');
  it.todo('#12 chunk boundary mid-CSI escape — ANSI state resumes correctly');
  it.todo('#14 Hebrew presentation forms U+FB1D–FB4F — treated as Hebrew');
  it.todo('#15 emoji between Hebrew runs — bracket closes and reopens');
  it.todo('#17 bracketed-paste sequence with Hebrew — Hebrew inside bracketed');
  it.todo('#18 alt-screen toggle with Hebrew on both sides — balanced on each');
});
