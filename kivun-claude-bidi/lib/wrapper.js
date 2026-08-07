'use strict';

// HEAVY §3: pty wrapper main loop.
// Spawns the claude binary under node-pty, pipes pty stdout through the
// HEAVY bracket Injector, passes stdin through unchanged, and forwards
// resize + terminating signals to the child.

const fs = require('fs');
const os = require('os');
const path = require('path');
// node-pty is a native module; require it lazily inside run() so the pure
// helpers (makeStdinPipeline / makeOutputSink) stay unit-testable on a host
// without node-pty built.
const { Injector } = require('./injector');
const { resolveClaudeBin } = require('./resolve-claude-bin');
const { createAutoContinue } = require('./auto-continue');

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

// [v1.7.0] Output sink seam — kept separate so `observeOutput` can be
// unit-tested without a real pty (mirrors makeStdinPipeline).
//   - `observeOutput` (when set) tees the RAW pty `data` to auto-continue
//     BEFORE any BiDi transform, so the limit line is matched verbatim.
//   - KIVUN_BIDI_PASSTHROUGH=1 relays raw bytes untouched and skips the
//     injector entirely (an LTR user who enables auto-continue forces the
//     wrapper on but wants NO BiDi transformation).
// Zero behavior change when neither flag is set: onData → writeOut(injector.
// write(data)), onEnd → writeOut(injector.end()), exactly as before.
function makeOutputSink({ injector, env, writeOut, observeOutput = null }) {
  const passthrough = String((env || {}).KIVUN_BIDI_PASSTHROUGH || '').trim() === '1';
  return {
    onData: (data) => {
      if (observeOutput) observeOutput(data);
      if (passthrough) writeOut(data);
      else writeOut(injector.write(data));
    },
    onEnd: () => {
      if (passthrough) return; // injector never used → nothing buffered to flush
      writeOut(injector.end());
    },
  };
}

// State dir for the shared rate-limit.json (written by statusline.mjs) and the
// auto-continue log. Matches the established `kivun-terminal` convention.
function stateDir(env) {
  const base = (env && env.XDG_STATE_HOME) || path.join(os.homedir(), '.local', 'state');
  return path.join(base, 'kivun-terminal');
}

function run(args, env = process.env) {
  const pty = require('node-pty');
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

  // [v1.7.0] Auto-continue after a rate-limit reset (opt-in, default off).
  let autoContinue = null;
  if (String(env.KIVUN_AUTO_CONTINUE || '').trim().toLowerCase() === 'on') {
    const dir = stateDir(env);
    let acLog = () => {};
    try {
      fs.mkdirSync(dir, { recursive: true });
      const logPath = path.join(dir, 'auto-continue.log');
      acLog = (msg) => {
        try { fs.appendFileSync(logPath, `${new Date().toISOString()} ${msg}\n`); } catch { /* noop */ }
      };
    } catch { /* logging is best-effort; never block the session */ }
    autoContinue = createAutoContinue({
      stateFile: path.join(dir, 'rate-limit.json'),
      log: acLog,
      write: (s) => child.write(s),
      config: {
        max: env.KIVUN_AUTO_CONTINUE_MAX,
        fallbackMin: env.KIVUN_AUTO_CONTINUE_FALLBACK_MIN,
        quiet: env.KIVUN_AUTO_CONTINUE_QUIET,
        safeResume: env.KIVUN_AUTO_CONTINUE_SAFE_RESUME,
      },
    });
  }

  const { onStdin, onStdinEnd } = makeStdinPipeline(child, env, hadRawMode);
  const onStdinTee = autoContinue
    ? (chunk) => { autoContinue.observeUserInput(); onStdin(chunk); }
    : onStdin;
  stdin.on('data', onStdinTee);
  if (onStdinEnd) stdin.on('end', onStdinEnd);

  const sink = makeOutputSink({
    injector,
    env,
    writeOut: (s) => process.stdout.write(s),
    observeOutput: autoContinue ? (data) => autoContinue.observeOutput(data) : null,
  });
  child.onData(sink.onData);

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
    sink.onEnd();
    if (autoContinue) autoContinue.dispose();

    stdin.off('data', onStdinTee);
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

module.exports = { run, resolveClaudeBin, makeStdinPipeline, makeOutputSink, stateDir };
