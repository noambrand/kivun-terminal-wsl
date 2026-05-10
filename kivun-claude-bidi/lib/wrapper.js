'use strict';

// HEAVY §3: pty wrapper main loop.
// Spawns the claude binary under node-pty, pipes pty stdout through the
// HEAVY bracket Injector, passes stdin through unchanged, and forwards
// resize + terminating signals to the child.

const fs = require('node:fs');
const path = require('node:path');
const pty = require('node-pty');
const { Injector } = require('./injector');
const { resolveClaudeBin } = require('./resolve-claude-bin');
const { StdinPromptOptimizer, optimizerConfig } = require('./rtl-cost-optimizer');

function currentSize(stdout) {
  return {
    cols: stdout.columns || 80,
    rows: stdout.rows || 24,
  };
}

function optimizerAuditPath(env = process.env) {
  if (env.KIVUN_RTL_COST_OPTIMIZER_AUDIT_LOG) return env.KIVUN_RTL_COST_OPTIMIZER_AUDIT_LOG;
  const home = env.HOME || env.USERPROFILE || process.cwd();
  return path.join(home, '.local', 'share', 'kivun-terminal', 'optimizer.log');
}

function writeOptimizerAudit(entries, env = process.env) {
  if (!entries || entries.length === 0) return;
  const file = optimizerAuditPath(env);
  try {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    const lines = entries.map((entry) => JSON.stringify(entry)).join('\n') + '\n';
    fs.appendFileSync(file, lines, 'utf8');
  } catch (_) {
    // Audit logging must never break the terminal session.
  }
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

  const rtlCostOptimizerConfig = optimizerConfig(env);
  const stdinOptimizer = (rtlCostOptimizerConfig.enabled && !hadRawMode)
    ? new StdinPromptOptimizer(env)
    : null;
  const optimizerNoticeToStderr = Boolean(stdinOptimizer && !hadRawMode);
  const optimizerAudit = Boolean(stdinOptimizer && rtlCostOptimizerConfig.audit);
  if (rtlCostOptimizerConfig.enabled && hadRawMode) {
    process.stderr.write('kivun-claude-bidi: RTL cost optimizer skipped for interactive Claude TUI.\n');
  } else if (stdinOptimizer) {
    process.stderr.write('kivun-claude-bidi: RTL cost optimizer enabled (prompt mode).\n');
  }

  const onStdin = (chunk) => {
    if (!stdinOptimizer) {
      child.write(chunk);
      return;
    }
    const result = stdinOptimizer.write(chunk);
    if (result.notice && optimizerNoticeToStderr) process.stderr.write(result.notice);
    if (optimizerAudit && result.audit) writeOptimizerAudit(result.audit, env);
    for (const next of result.chunks) child.write(next);
  };
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
    if (stdinOptimizer) {
      const pendingInput = stdinOptimizer.end();
      if (pendingInput.notice && optimizerNoticeToStderr) process.stderr.write(pendingInput.notice);
      if (optimizerAudit && pendingInput.audit) writeOptimizerAudit(pendingInput.audit, env);
    }

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

module.exports = { run, resolveClaudeBin, optimizerAuditPath, writeOptimizerAudit };
