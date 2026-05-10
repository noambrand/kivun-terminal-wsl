'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  containsRTL,
  guessRTLLanguage,
  normalizeRTLInput,
  optimizePrompt,
  compareEstimate,
  StdinPromptOptimizer,
  TuiPromptOptimizer,
} = require('../lib/rtl-cost-optimizer');

const ON = {
  KIVUN_RTL_COST_OPTIMIZER: 'on',
  KIVUN_RTL_COST_OPTIMIZER_MODE: 'prompt',
  KIVUN_RTL_COST_OPTIMIZER_SHOW_PREVIEW: 'on',
  KIVUN_RTL_COST_OPTIMIZER_SHOW_ESTIMATE: 'on',
};

describe('RTL cost optimizer', () => {
  it('is disabled by default', () => {
    const input = 'תבדוק למה CMake נכשל בפרויקט ותתקן בלי לשבור את הבדיקות';
    const out = optimizePrompt(input, {});
    assert.equal(out.changed, false);
    assert.equal(out.optimized, input);
  });

  it('detects Hebrew and Arabic input', () => {
    assert.equal(containsRTL('hello שלום'), true);
    assert.equal(containsRTL('تحقق من CMake'), true);
    assert.equal(containsRTL('plain ascii'), false);
    assert.equal(guessRTLLanguage('שלום'), 'hebrew');
    assert.equal(guessRTLLanguage('مرحبا'), 'arabic');
  });

  it('normalizes RTL text without touching fenced code blocks', () => {
    const input = 'שָׁלוֹם\u202B   עולם\n```js\nconst x = "שָׁלוֹם";\n```';
    const out = normalizeRTLInput(input);
    assert.match(out, /^שלום עולם/);
    assert.match(out, /const x = "שָׁלוֹם";/);
    assert.doesNotMatch(out.split('```')[0], /\u202B/);
  });

  it('compresses the Hebrew CMake fixture into a compact English task', () => {
    const input = 'תבדוק למה CMake נכשל בפרויקט ותתקן בלי לשבור את הבדיקות';
    const out = optimizePrompt(input, ON);
    assert.equal(out.changed, true);
    assert.match(out.optimized, /Use English for internal reasoning/);
    assert.match(out.optimized, /Investigate the CMake build failure and fix the root cause/);
    assert.match(out.optimized, /Preserve existing tests/);
    assert.match(out.optimized, /Return a concise summary in Hebrew/);
    assert.match(out.optimized, /CMake/);
  });

  it('compresses Arabic developer requests locally', () => {
    const input = 'تحقق لماذا CMake يفشل في المشروع وأصلح السبب بدون كسر الاختبارات';
    const out = optimizePrompt(input, ON);
    assert.equal(out.changed, true);
    assert.match(out.optimized, /Investigate the CMake build failure and fix the root cause/);
    assert.match(out.optimized, /Return a concise summary in the user's RTL language/);
  });

  it('shows heuristic savings for verbose RTL requests', () => {
    const input = 'תבדוק למה CMake נכשל בפרויקט ותתקן בלי לשבור את הבדיקות. '.repeat(8);
    const out = optimizePrompt(input, ON);
    const estimate = compareEstimate(input, out.optimized);
    assert.ok(estimate.savedTokens > 0, `expected positive savings, got ${JSON.stringify(estimate)}`);
    assert.ok(estimate.savedPercent >= 40, `expected >=40% savings, got ${estimate.savedPercent}%`);
  });

  it('line-buffers stdin and sends optimized prompt on Enter', () => {
    const opt = new StdinPromptOptimizer({ ...ON, KIVUN_RTL_COST_OPTIMIZER_SHOW_PREVIEW: 'off' });
    assert.deepEqual(opt.write(Buffer.from('תבדוק למה CMake נכשל')).chunks, []);
    const result = opt.write(Buffer.from('\n'));
    assert.equal(result.chunks.length, 1);
    assert.match(result.chunks[0], /Investigate the CMake build failure/);
    assert.match(result.notice, /RTL prompt optimized/);
    assert.equal(result.audit.length, 1);
    assert.equal(result.audit[0].language, 'hebrew');
    assert.equal(typeof result.audit[0].originalTokens, 'number');
  });

  it('TUI optimizer passes typed text through live, then replaces on Enter', () => {
    const opt = new TuiPromptOptimizer({ ...ON, KIVUN_RTL_COST_OPTIMIZER_SHOW_PREVIEW: 'off' });
    const typed = opt.write(Buffer.from('תבדוק למה CMake נכשל'));
    assert.deepEqual(typed.chunks, ['ת', 'ב', 'ד', 'ו', 'ק', ' ', 'ל', 'מ', 'ה', ' ', 'C', 'M', 'a', 'k', 'e', ' ', 'נ', 'כ', 'ש', 'ל']);

    const result = opt.write(Buffer.from('\r'));
    assert.equal(result.chunks[0], '\u0015');
    assert.match(result.chunks[1], /Investigate the CMake build failure/);
    assert.equal(result.chunks[2], '\r');
    assert.match(result.notice, /RTL prompt optimized/);
    assert.equal(result.audit.length, 1);
    assert.deepEqual(Object.keys(result.audit[0]).sort(), [
      'changed',
      'language',
      'optimizedTokens',
      'originalTokens',
      'savedPercent',
      'savedTokens',
      'time',
    ]);
  });

  it('TUI optimizer does not replace after cursor navigation', () => {
    const opt = new TuiPromptOptimizer(ON);
    opt.write(Buffer.from('תבדוק'));
    opt.write(Buffer.from('\x1b[D'));
    const result = opt.write(Buffer.from('\r'));
    assert.deepEqual(result.chunks, ['\r']);
    assert.equal(result.notice, '');
    assert.deepEqual(result.audit, []);
  });

  it('TUI optimizer tracks simple backspace edits', () => {
    const opt = new TuiPromptOptimizer({ ...ON, KIVUN_RTL_COST_OPTIMIZER_SHOW_PREVIEW: 'off' });
    opt.write(Buffer.from('תבדוק למה CMake נכשלל'));
    opt.write(Buffer.from('\u007f'));
    const result = opt.write(Buffer.from('\n'));
    assert.equal(result.chunks[0], '\u0015');
    assert.match(result.chunks[1], /Investigate the CMake build failure/);
    assert.equal(result.chunks[2], '\n');
  });
});
