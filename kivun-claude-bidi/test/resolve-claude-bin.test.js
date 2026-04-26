'use strict';

// v1.1.5: bare `claude` in pty.spawn caused execvp(3) failed when
// ~/.local/bin (where Anthropic's curl installer drops the binary) was
// not on PATH. resolveClaudeBin must prefer absolute install slots over
// bare-name PATH lookup.
//
// v1.1.6: a login-shell discovery step (`bash -lc "command -v claude"`)
// was added between the absolute slots and the bare-name fallback so
// nvm/n/pnpm/yarn-global/snap/corp installs are also found without
// requiring the user to set KIVUN_CLAUDE_BIN.

const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');

const {
  resolveClaudeBin,
  _internal: { tryAbsoluteSlots, tryLoginShellLookup },
} = require('../lib/resolve-claude-bin');

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

  it('discovers claude from a custom PATH via bash -lc fallback (nvm/pnpm-style)', () => {
    // POSIX-only test. On Windows the `bash` on PATH is usually git-bash,
    // which translates between Win32 and POSIX paths in ways that don't
    // match the WSL/Linux runtime the wrapper actually targets. CI runs
    // this on ubuntu-latest where the behavior is what production sees.
    if (process.platform === 'win32') return;

    // Simulate: claude is at /tmp/.../custom-bin/claude (NOT in any of
    // the standard absolute slots), but the user's PATH has it. The
    // resolver's bash -lc step must find it.
    const home = fs.mkdtempSync(path.join(sandbox, 'nvm-home-'));
    const customBin = path.join(home, 'custom-bin');
    fs.mkdirSync(customBin, { recursive: true });
    const target = path.join(customBin, 'claude');
    fs.writeFileSync(target, '#!/bin/sh\nexit 0\n');
    fs.chmodSync(target, 0o755);

    const env = {
      HOME: home,
      PATH: `${customBin}:/usr/bin:/bin`,
    };

    let bashOk = true;
    try {
      require('child_process').execFileSync('bash', ['--version'], {
        stdio: 'ignore',
        timeout: 1000,
      });
    } catch (_) { bashOk = false; }
    if (!bashOk) return;

    assert.equal(resolveClaudeBin(env), target);
  });

  it('falls back to bare "claude" when nothing is found anywhere', () => {
    const home = fs.mkdtempSync(path.join(sandbox, 'empty-home-'));
    // Use an empty PATH so login-shell lookup also misses, and skip
    // unless system-level slots really do lack claude (dev machine
    // sanity).
    const systemSlots = ['/usr/local/bin/claude', '/usr/bin/claude'];
    for (const p of systemSlots) {
      try { fs.accessSync(p, fs.constants.X_OK); return; } catch (_) { /* ok */ }
    }
    const env = { HOME: home, PATH: '/nonexistent' };
    assert.equal(resolveClaudeBin(env), 'claude');
  });

  describe('tryAbsoluteSlots (internal)', () => {
    it('returns null when nothing exists', () => {
      const home = fs.mkdtempSync(path.join(sandbox, 'abs-empty-'));
      // skip if real /usr/bin/claude exists -- can't assert null then
      try { fs.accessSync('/usr/bin/claude', fs.constants.X_OK); return; } catch (_) { /* ok */ }
      try { fs.accessSync('/usr/local/bin/claude', fs.constants.X_OK); return; } catch (_) { /* ok */ }
      assert.equal(tryAbsoluteSlots({ HOME: home }), null);
    });

    it('skips slots whose target is missing or not executable', () => {
      // POSIX-only: Windows ignores Unix mode bits, so X_OK passes on
      // a 0644 file. The "not executable" branch can't be exercised
      // there. Test "missing" instead, which works on every OS.
      if (process.platform === 'win32') {
        const home = fs.mkdtempSync(path.join(sandbox, 'abs-missing-'));
        // Don't create ~/.local/bin/claude at all -- accessSync throws ENOENT.
        try { fs.accessSync('/usr/bin/claude', fs.constants.X_OK); return; } catch (_) { /* ok */ }
        try { fs.accessSync('/usr/local/bin/claude', fs.constants.X_OK); return; } catch (_) { /* ok */ }
        assert.equal(tryAbsoluteSlots({ HOME: home }), null);
        return;
      }
      const home = fs.mkdtempSync(path.join(sandbox, 'abs-noexec-'));
      const binDir = path.join(home, '.local/bin');
      fs.mkdirSync(binDir, { recursive: true });
      const target = path.join(binDir, 'claude');
      fs.writeFileSync(target, '#!/bin/sh\nexit 0\n');
      fs.chmodSync(target, 0o644);
      try { fs.accessSync('/usr/bin/claude', fs.constants.X_OK); return; } catch (_) { /* ok */ }
      try { fs.accessSync('/usr/local/bin/claude', fs.constants.X_OK); return; } catch (_) { /* ok */ }
      assert.equal(tryAbsoluteSlots({ HOME: home }), null);
    });
  });

  describe('tryLoginShellLookup (internal)', () => {
    it('returns null on a PATH that does not contain claude', () => {
      const env = { PATH: '/nonexistent', HOME: sandbox };
      assert.equal(tryLoginShellLookup(env), null);
    });
  });
});
