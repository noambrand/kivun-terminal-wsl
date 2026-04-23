'use strict';

// HEAVY §5: terminal detection. v1 is Konsole-only because that's our
// testing exposure. v2 widens to any terminal that passes the §1
// integration gate (gnome-terminal+VTE, alacritty, etc.).
//
// To widen the allowlist later, append entries to KNOWN_TERMINALS - each
// entry needs a name, a predicate on the env, and an integration-gate
// test result filed in docs/research/.

const KNOWN_TERMINALS = [
  {
    name: 'konsole',
    matches: (env) => Boolean(env.KONSOLE_VERSION) || Boolean(env.KONSOLE_DBUS_SESSION),
    profile: (env) => env.KONSOLE_PROFILE_NAME || null,
  },
];

function detectTerminal(env = process.env) {
  for (const t of KNOWN_TERMINALS) {
    if (t.matches(env)) {
      return { ok: true, name: t.name, profile: t.profile(env) };
    }
  }
  return {
    ok: false,
    reason: 'not running in a supported terminal (v1 requires Konsole)',
  };
}

module.exports = { detectTerminal, KNOWN_TERMINALS };
