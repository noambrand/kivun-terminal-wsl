'use strict';

// Resolve a real, executable absolute path to the claude binary, or fall
// back to the bare name "claude" so that pty.spawn's PATH lookup gets a
// last shot. Split out from wrapper.js so it can be unit-tested without
// requiring node-pty (which is a native module and not always installed
// in lightweight test runs).
//
// v1.1.5 background: pty.spawn('claude') failed with execvp(3) on a
// user's Windows 11 machine because node-pty inherits PATH from the
// parent process; the parent here is a node child of `bash -c` from
// wsl.exe, whose PATH does NOT include ~/.local/bin -- the slot where
// Anthropic's curl installer drops the binary. The launcher's presence
// check (payload/kivun-terminal.bat) had the matching bug; both are
// fixed by checking absolute install slots directly.

const fs = require('fs');
const path = require('path');

const DEFAULT_CLAUDE_BIN = 'claude';

// Order mirrors :_do_install verify in payload/kivun-terminal.bat so the
// resolver and the launcher cannot disagree about what "installed" means.
const ABSOLUTE_CANDIDATES = [
  (env) => env.HOME && path.join(env.HOME, '.local/bin/claude'),
  () => '/usr/local/bin/claude',
  () => '/usr/bin/claude',
];

function resolveClaudeBin(env = process.env) {
  if (env.KIVUN_CLAUDE_BIN) return env.KIVUN_CLAUDE_BIN;
  for (const candidate of ABSOLUTE_CANDIDATES) {
    const p = candidate(env);
    if (!p) continue;
    try {
      fs.accessSync(p, fs.constants.X_OK);
      return p;
    } catch (_) { /* try next slot */ }
  }
  return DEFAULT_CLAUDE_BIN;
}

module.exports = { resolveClaudeBin, DEFAULT_CLAUDE_BIN };
