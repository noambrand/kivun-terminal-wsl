'use strict';

// HEAVY §4: TERM-value sanity check at startup.
// Warns and continues on dumb / empty TERM; silent otherwise.
// Not a blocker - the user may be redirecting output through a pipe,
// in which case TERM being unusual is fine and the wrapper still runs.

function checkCapability(env = process.env, warn = (m) => process.stderr.write(m + '\n')) {
  const term = env.TERM;
  if (term === undefined || term === '' || term === 'dumb') {
    const shown = term === undefined ? '' : term;
    warn(`kivun-claude-bidi: unusual TERM='${shown}'; BiDi may not render.`);
    return { ok: true, warned: true };
  }
  return { ok: true, warned: false };
}

module.exports = { checkCapability };
