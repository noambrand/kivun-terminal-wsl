'use strict';

// HEAVY §3: pty wrapper main loop.
// Spawns the claude binary under node-pty, pipes pty stdout through the
// HEAVY bracket Injector, passes stdin through unchanged, and forwards
// resize + terminating signals to the child.

const pty = require('node-pty');
const { Injector } = require('./injector');

const DEFAULT_CLAUDE_BIN = 'claude';

function resolveClaudeBin(env) {
  return env.KIVUN_CLAUDE_BIN || DEFAULT_CLAUDE_BIN;
}

function currentSize(stdout) {
  return {
    cols: stdout.columns || 80,
    rows: stdout.rows || 24,
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

  const onStdin = (chunk) => child.write(chunk);
  stdin.on('data', onStdin);

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

module.exports = { run, resolveClaudeBin };
