'use strict';

// HEAVY §3: pty wrapper main loop.
// Spawns the claude binary under node-pty, pipes pty stdout through the
// HEAVY bracket Injector, passes stdin through unchanged, and forwards
// resize + terminating signals to the child.

const pty = require('node-pty');
const { Injector } = require('./injector');
const { resolveClaudeBin } = require('./resolve-claude-bin');

function currentSize(stdout) {
  return {
    cols: stdout.columns || 80,
    rows: stdout.rows || 24,
  };
}

// #98 EXPERIMENT — RTL cost optimizer wiring. Decided ONCE at startup:
//   off (the default)   → raw passthrough, byte-identical to the
//                         pre-experiment wrapper; the optimizer module is
//                         never even require()d.
//   on + stdin is a TTY → one stderr notice, then raw passthrough
//                         (interactive TUI input is never touched).
//   on + piped stdin    → line-buffered StdinPromptOptimizer.
// onStdinEnd is non-null only in the piped case: line buffering must flush
// a final unterminated line at pipe EOF; the passthrough never needed an
// 'end' handler and does not get one.
function makeStdinPipeline(child, env, isTTY, writeErr = (s) => process.stderr.write(s)) {
  const enabled = String((env || {}).KIVUN_RTL_COST_OPTIMIZER || '').trim().toLowerCase() === 'on';
  if (!enabled) {
    return { onStdin: (chunk) => child.write(chunk), onStdinEnd: null };
  }
  if (isTTY) {
    writeErr('kivun-claude-bidi: RTL cost optimizer applies to piped input only; skipped for interactive TUI\n');
    return { onStdin: (chunk) => child.write(chunk), onStdinEnd: null };
  }
  // Lazy require: the optimizer code loads only in this opt-in branch.
  const { StdinPromptOptimizer } = require('./rtl-cost-optimizer');
  const optimizer = new StdinPromptOptimizer(env, { writeErr });
  return {
    onStdin: (chunk) => {
      const out = optimizer.write(chunk);
      if (out) child.write(out);
    },
    onStdinEnd: () => {
      const out = optimizer.end();
      if (out) child.write(out);
    },
  };
}

function run(args, env = process.env) {
  const cmd = resolveClaudeBin(env);
  const { cols, rows } = currentSize(process.stdout);

  let child;
  try {
    child = pty.spawn(cmd, args, {
      name: env.TERM || 'xterm-256color',
      cols,
      rows,
      cwd: process.cwd(),
      env,
    });
  } catch (err) {
    process.stderr.write(
      `kivun-claude-bidi: cannot spawn '${cmd}': ${err.message}\n`,
    );
    process.exit(127);
  }

  const injector = new Injector();

  const stdin = process.stdin;
  const hadRawMode = stdin.isTTY;
  if (hadRawMode) stdin.setRawMode(true);
  stdin.resume();

  const { onStdin, onStdinEnd } = makeStdinPipeline(child, env, hadRawMode);
  stdin.on('data', onStdin);
  if (onStdinEnd) stdin.on('end', onStdinEnd);

  child.onData((data) => {
    process.stdout.write(injector.write(data));
  });

  const onResize = () => {
    const next = currentSize(process.stdout);
    try { child.resize(next.cols, next.rows); } catch (_) { /* child gone */ }
  };
  process.stdout.on('resize', onResize);

  const forward = (sig) => () => {
    try { child.kill(sig); } catch (_) { /* child gone */ }
  };
  const sigHandlers = {
    SIGINT: forward('SIGINT'),
    SIGTERM: forward('SIGTERM'),
    SIGHUP: forward('SIGHUP'),
  };
  for (const [sig, h] of Object.entries(sigHandlers)) {
    process.on(sig, h);
  }

  child.onExit(({ exitCode, signal }) => {
    process.stdout.write(injector.end());

    stdin.off('data', onStdin);
    if (onStdinEnd) stdin.off('end', onStdinEnd);
    if (hadRawMode) {
      try { stdin.setRawMode(false); } catch (_) { /* not a TTY */ }
    }
    stdin.pause();

    process.stdout.off('resize', onResize);
    for (const [sig, h] of Object.entries(sigHandlers)) {
      process.off(sig, h);
    }

    if (signal) process.exit(128 + signal);
    process.exit(exitCode ?? 0);
  });
}

module.exports = { run, resolveClaudeBin, makeStdinPipeline };
