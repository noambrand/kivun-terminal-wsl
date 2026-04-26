'use strict';

// Regression test for v1.1.4 -> v1.1.5: bare `claude` in pty.spawn caused
// execvp(3) failed when ~/.local/bin (where Anthropic's curl installer
// drops the binary) was not on PATH. resolveClaudeBin must now prefer
// known absolute install slots over bare-name PATH lookup.

const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');

const { resolveClaudeBin } = require('../lib/resolve-claude-bin');

describe('resolveClaudeBin', () => {
  let sandbox;
  before(() => {
    sandbox = fs.mkdtempSync(path.join(os.tmpdir(), 'kivun-resolve-'));
  });
  after(() => {
    fs.rmSync(sandbox, { recursive: true, force: true });
  });

  it('honours KIVUN_CLAUDE_BIN env override above all else', () => {
    const env = { KIVUN_CLAUDE_BIN: '/nope/explicit/claude', HOME: sandbox };
    assert.equal(resolveClaudeBin(env), '/nope/explicit/claude');
  });

  it('returns absolute ~/.local/bin/claude when it exists+executable', () => {
    const home = fs.mkdtempSync(path.join(sandbox, 'home-'));
    const binDir = path.join(home, '.local/bin');
    fs.mkdirSync(binDir, { recursive: true });
    const target = path.join(binDir, 'claude');
    fs.writeFileSync(target, '#!/bin/sh\nexit 0\n');
    fs.chmodSync(target, 0o755);

    const env = { HOME: home };
    assert.equal(resolveClaudeBin(env), target);
  });

  it('falls back to bare "claude" when no absolute slot has an executable', () => {
    const home = fs.mkdtempSync(path.join(sandbox, 'empty-home-'));
    // No claude anywhere under home; /usr/local/bin/claude and
    // /usr/bin/claude may or may not exist on the test runner -- this
    // assertion only meaningfully runs when they don't. Skip in that
    // case to keep the test machine-independent.
    const fsConst = fs.constants.X_OK;
    let systemHasClaude = false;
    for (const p of ['/usr/local/bin/claude', '/usr/bin/claude']) {
      try { fs.accessSync(p, fsConst); systemHasClaude = true; break; } catch (_) { /* ok */ }
    }
    if (systemHasClaude) return; // can't assert fallback in this environment

    const env = { HOME: home };
    assert.equal(resolveClaudeBin(env), 'claude');
  });
});
