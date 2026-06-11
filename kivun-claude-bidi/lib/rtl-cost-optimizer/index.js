'use strict';

// RTL cost optimizer — EXPERIMENT (issue #98, successor to rejected PR #84).
//
// Transforms PIPED Hebrew/Arabic prompts before they reach Claude Code:
//   1. normalize  — strip niqqud/diacritics and invisible directional
//                   controls, collapse whitespace (fenced ``` code blocks
//                   pass through untouched). Lossless for meaning.
//   2. scaffold   — wrap the FULL normalized request VERBATIM in a short
//                   English frame. Never substitutes, never truncates:
//                   PR #84 was rejected for replacing the user's request
//                   with canned intent templates, and that class of bug is
//                   structurally impossible here (there are no templates).
//
// HONEST ACCOUNTING: savings are UNPROVEN. The scaffold ADDS English
// text, so input tokens may INCREASE (the estimate delta goes negative).
// The experiment exists to measure whether English internal reasoning
// reduces OUTPUT tokens, which Hebrew pays ~2x for.
//
// Scope guarantees (the #98 must-fixes):
//   - off by default; the wrapper does not even require() this module
//     unless KIVUN_RTL_COST_OPTIMIZER=on (see wrapper.js makeStdinPipeline)
//   - piped stdin only; interactive TUI input is never touched
//   - no TuiPromptOptimizer, no compressor, no glossary

const fs = require('fs');
const os = require('os');
const path = require('path');
const { StringDecoder } = require('string_decoder');
const { containsRTL, guessRTLLanguage } = require('./detector');
const { normalizeRTLInput } = require('./normalizer');
const { compareEstimate } = require('./estimator');

const NOTICE_PREFIX = '[kivun-rtl-optimizer] ';

// Master switch: the literal string "on" only. "true"/"1" stay off so a
// half-remembered flag can never silently enable an experiment.
function flagOn(value) {
  return String(value || '').trim().toLowerCase() === 'on';
}

// Sub-flags default ON and turn off only with the literal "off" — so
// setting one to "true" (a natural mistake) never silently disables it.
function flagNotOff(value) {
  return String(value == null ? 'on' : value).trim().toLowerCase() !== 'off';
}

function readConfig(env) {
  const e = env || {};
  return {
    enabled: flagOn(e.KIVUN_RTL_COST_OPTIMIZER),
    scaffold: flagNotOff(e.KIVUN_RTL_COST_OPTIMIZER_SCAFFOLD),
    showPreview: flagNotOff(e.KIVUN_RTL_COST_OPTIMIZER_SHOW_PREVIEW),
    showEstimate: flagNotOff(e.KIVUN_RTL_COST_OPTIMIZER_SHOW_ESTIMATE),
    audit: flagNotOff(e.KIVUN_RTL_COST_OPTIMIZER_AUDIT),
  };
}

function buildScaffold(normalized, script) {
  // Hebrew is unambiguous from its script. Arabic-script codepoints are
  // shared by Arabic/Persian/Urdu/Pashto/Kurdish/..., so the generic form
  // is the only honest instruction for those.
  const reply = script === 'hebrew' ? 'Reply in Hebrew.' : "Reply in the user's language.";
  return 'Use English for internal reasoning. Do not translate code identifiers, paths, or commands. '
    + reply
    + '\n\nTask (verbatim from the user):\n'
    + normalized;
}

function transformPrompt(original, config) {
  const normalized = normalizeRTLInput(original);
  const script = guessRTLLanguage(normalized);
  const transformed = config.scaffold ? buildScaffold(normalized, script) : normalized;
  const estimate = compareEstimate(original, transformed);
  return { normalized, script, transformed, estimate };
}

function resolveAuditPath(env) {
  const e = env || {};
  if (e.KIVUN_RTL_COST_OPTIMIZER_AUDIT_FILE) return e.KIVUN_RTL_COST_OPTIMIZER_AUDIT_FILE;
  // Same state-dir convention as the injector's side logs.
  const stateHome = e.XDG_STATE_HOME || path.join(os.homedir(), '.local', 'state');
  return path.join(stateHome, 'kivun-terminal', 'rtl-cost-optimizer.jsonl');
}

function appendAudit(entry, env) {
  // Metrics only — an audit line NEVER contains prompt text. And metrics
  // must never break the terminal session: swallow all IO errors.
  try {
    const file = resolveAuditPath(env);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.appendFileSync(file, JSON.stringify(entry) + '\n');
  } catch {
    /* never break the session over metrics */
  }
}

// Line-buffered transformer for PIPED stdin (the wrapper instantiates this
// only when the optimizer is enabled AND stdin is not a TTY). Each complete
// line is treated as one prompt — piped input reaches the Claude TUI as
// typed lines, where every newline submits.
class StdinPromptOptimizer {
  constructor(env, opts) {
    this.env = env || {};
    this.config = readConfig(this.env);
    this.writeErr = (opts && opts.writeErr) || ((s) => process.stderr.write(s));
    this.decoder = new StringDecoder('utf8');
    this.buffer = '';
  }

  // Returns the string to forward to the PTY (may be '' while buffering).
  write(chunk) {
    let out = '';
    for (const ch of this.decoder.write(chunk)) {
      if (ch === '\u0003' || ch === '\u0004') {
        // Ctrl-C / Ctrl-D: forward immediately, drop the buffered line —
        // matching what the control character means at a terminal.
        this.buffer = '';
        out += ch;
        continue;
      }
      if (ch === '\n' || ch === '\r') {
        out += this.processLine(this.buffer) + ch;
        this.buffer = '';
        continue;
      }
      this.buffer += ch;
    }
    return out;
  }

  // Flush at pipe EOF: a final unterminated line is still a prompt.
  end() {
    const tail = this.decoder.end();
    if (tail) this.buffer += tail;
    if (!this.buffer) return '';
    const out = this.processLine(this.buffer);
    this.buffer = '';
    return out;
  }

  processLine(line) {
    if (!containsRTL(line)) return line; // verbatim — no notice, no audit
    const { script, transformed, estimate } = transformPrompt(line, this.config);
    if (this.config.showPreview) {
      this.writeErr(NOTICE_PREFIX + 'transformed prompt (verify the meaning is preserved):\n'
        + transformed + '\n');
    }
    if (this.config.showEstimate) {
      this.writeErr(NOTICE_PREFIX + 'heuristic token estimate: '
        + estimate.originalTokens + ' -> ' + estimate.transformedTokens
        + ' (delta ' + estimate.deltaTokens
        + '; a NEGATIVE delta means the transformation ADDED input tokens — '
        + 'this experiment measures output-token impact)\n');
    }
    if (this.config.audit) {
      appendAudit({
        time: new Date().toISOString(),
        script,
        scaffold: this.config.scaffold,
        originalChars: line.length,
        transformedChars: transformed.length,
        originalTokens: estimate.originalTokens,
        transformedTokens: estimate.transformedTokens,
        deltaTokens: estimate.deltaTokens,
      }, this.env);
    }
    return transformed;
  }
}

module.exports = {
  NOTICE_PREFIX,
  readConfig,
  buildScaffold,
  transformPrompt,
  resolveAuditPath,
  appendAudit,
  StdinPromptOptimizer,
};
