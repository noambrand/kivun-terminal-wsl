'use strict';

// Resolve a real, executable absolute path to the claude binary.
// Strategy (in order):
//   1. KIVUN_CLAUDE_BIN env override (manual escape hatch)
//   2. Standard absolute install slots: ~/.local/bin, /usr/local/bin,
//      /usr/bin -- covers >95% of users (curl installer, apt, manual).
//   3. ASK A LOGIN SHELL: `bash -lc "command -v claude"`. Catches
//      nvm/n/pnpm/yarn-global/snap/corp installs whose paths are added
//      to PATH only by the user's .bashrc / .profile. This is the
//      "actively discover" step -- the resolver does not assume; it
//      asks bash to find claude using whatever PATH the user really has.
//   4. Bare name "claude" as a last-ditch PATH lookup at spawn time.
//
// Split out from wrapper.js so the strategy can be unit-tested without
// requiring node-pty (a native module).
//
// v1.1.5 added (1)+(2)+(4). v1.1.6 adds (3) so the resolver actively
// discovers the binary instead of assuming standard slots -- prompted by
// users who install Claude via nvm/pnpm/yarn-global. The bash shellout
// has a hard 2-second timeout so a hung rc file cannot block the
// wrapper from starting.

const fs = require('fs');
const path = require('path');
const child_process = require('child_process');

const DEFAULT_CLAUDE_BIN = 'claude';

// Mirror :_do_install verify in payload/kivun-terminal.bat so the
// resolver and the launcher cannot disagree about what "installed" means
// for the standard install paths.
const ABSOLUTE_CANDIDATES = [
  (env) => env.HOME && path.join(env.HOME, '.local/bin/claude'),
  () => '/usr/local/bin/claude',
  () => '/usr/bin/claude',
];

function tryAbsoluteSlots(env) {
  for (const candidate of ABSOLUTE_CANDIDATES) {
    const p = candidate(env);
    if (!p) continue;
    try {
      fs.accessSync(p, fs.constants.X_OK);
      return p;
    } catch (_) { /* try next slot */ }
  }
  return null;
}

function tryLoginShellLookup(env) {
  // bash -lc sources .profile / .bash_profile / .bashrc and runs the
  // command in that environment, so nvm/n/pnpm/yarn paths added by
  // those rc files are visible. `command -v` is the POSIX way to ask
  // "where is X" -- prints absolute path on success, exits non-zero on
  // miss. stdio: ignore stderr so a noisy rc file doesn't pollute our
  // log; timeout so a hung rc file cannot block the wrapper.
  try {
    const out = child_process.execFileSync(
      'bash',
      ['-lc', 'command -v claude'],
      {
        encoding: 'utf8',
        timeout: 2000,
        env,
        stdio: ['ignore', 'pipe', 'ignore'],
      },
    ).trim();
    if (!out) return null;
    // command -v can print an alias or builtin definition; only accept
    // a real executable file. Symlinks are fine (followed by access).
    try {
      fs.accessSync(out, fs.constants.X_OK);
      return out;
    } catch (_) { return null; }
  } catch (_) {
    // bash missing, timeout, command -v miss, or rc-file error.
    return null;
  }
}

// SECURITY (v1.4.9, audit #4): KIVUN_CLAUDE_BIN is a manual escape hatch
// (e.g. for users running Claude from a non-standard install slot), but
// it's also propagated through the picker's per-profile env-vars feature.
// A malicious profiles.json could set it to /tmp/evil and we'd silently
// run that as if it were claude. Restrict to executable files under one
// of a small set of trusted prefixes (the same slots tryAbsoluteSlots
// would have considered, plus the user's home — power users who need
// custom paths can symlink into ~/.local/bin).
function isAllowedClaudeBinPath(p, env) {
  if (typeof p !== 'string' || p.length === 0) return false;
  if (p.indexOf('\0') !== -1) return false;
  let abs;
  try {
    abs = path.resolve(p);
  } catch (_) { return false; }
  const home = env.HOME || env.USERPROFILE || '';
  const allowedPrefixes = [
    home && path.join(home, '.local', 'bin') + path.sep,
    home && path.join(home, '.nvm') + path.sep,
    home && path.join(home, '.bun') + path.sep,
    '/usr/local/bin/',
    '/usr/bin/',
    '/opt/',
    '/snap/',
  ].filter(Boolean);
  let prefixOk = false;
  for (const pref of allowedPrefixes) {
    if (abs === pref.replace(/[\\/]$/, '') || abs.indexOf(pref) === 0) {
      prefixOk = true;
      break;
    }
  }
  if (!prefixOk) return false;
  try {
    fs.accessSync(abs, fs.constants.X_OK);
  } catch (_) { return false; }
  return true;
}

function resolveClaudeBin(env = process.env) {
  if (env.KIVUN_CLAUDE_BIN) {
    if (isAllowedClaudeBinPath(env.KIVUN_CLAUDE_BIN, env)) return env.KIVUN_CLAUDE_BIN;
    // Untrusted path — fall through to standard discovery rather than
    // failing loudly, so a malicious profile env-var can't even DoS the
    // wrapper. Standard slots are searched next.
  }

  const absolute = tryAbsoluteSlots(env);
  if (absolute) return absolute;

  const discovered = tryLoginShellLookup(env);
  if (discovered) return discovered;

  return DEFAULT_CLAUDE_BIN;
}

module.exports = {
  resolveClaudeBin,
  DEFAULT_CLAUDE_BIN,
  // Exported for tests; not part of the wrapper's public API.
  _internal: { tryAbsoluteSlots, tryLoginShellLookup },
};
