'use strict';

const { StringDecoder } = require('node:string_decoder');
const { containsRTL, guessRTLLanguage } = require('./detector');
const { normalizeRTLInput } = require('./normalizer');
const { compressPrompt } = require('./compressor');
const { estimateTokens, compareEstimate } = require('./estimator');

function isOn(value) {
  return String(value || '').toLowerCase() === 'on';
}

function isOff(value) {
  return String(value || '').toLowerCase() === 'off';
}

function optimizerConfig(env = process.env) {
  return {
    enabled: isOn(env.KIVUN_RTL_COST_OPTIMIZER),
    mode: String(env.KIVUN_RTL_COST_OPTIMIZER_MODE || 'prompt').toLowerCase(),
    showPreview: isOn(env.KIVUN_RTL_COST_OPTIMIZER_SHOW_PREVIEW || 'on'),
    showEstimate: isOn(env.KIVUN_RTL_COST_OPTIMIZER_SHOW_ESTIMATE || 'on'),
    audit: !isOff(env.KIVUN_RTL_COST_OPTIMIZER_AUDIT || 'on'),
  };
}

function optimizePrompt(input, env = process.env) {
  const config = optimizerConfig(env);
  const original = String(input || '');
  if (!config.enabled || config.mode !== 'prompt' || !containsRTL(original)) {
    return { changed: false, original, optimized: original, config };
  }
  const normalized = normalizeRTLInput(original);
  const optimized = compressPrompt(normalized);
  return {
    changed: optimized.trim() !== original.trim(),
    original,
    normalized,
    optimized,
    language: guessRTLLanguage(original),
    estimate: compareEstimate(original, optimized),
    config,
  };
}

class StdinPromptOptimizer {
  constructor(env = process.env) {
    this.env = env;
    this.config = optimizerConfig(env);
    this.decoder = new StringDecoder('utf8');
    this.buffer = '';
  }

  write(chunk) {
    if (!this.config.enabled || this.config.mode !== 'prompt') return { chunks: [chunk], notice: '', audit: [] };
    const text = typeof chunk === 'string' ? chunk : this.decoder.write(chunk);
    return this._writeText(text);
  }

  end() {
    const rest = this.decoder.end();
    if (!this.config.enabled || this.config.mode !== 'prompt') return { chunks: rest ? [rest] : [], notice: '', audit: [] };
    return this._writeText(rest, true);
  }

  _writeText(text, force = false) {
    const chunks = [];
    let notice = '';
    const audit = [];
    for (const ch of text) {
      if (ch === '\r' || ch === '\n') {
        const line = this.buffer;
        this.buffer = '';
        const result = optimizePrompt(line, this.env);
        if (result.changed) {
          chunks.push(result.optimized + ch);
          notice += this._notice(result);
          audit.push(toAuditEntry(result));
        } else {
          chunks.push(line + ch);
        }
      } else if (ch === '\u0003' || ch === '\u0004') {
        this.buffer = '';
        chunks.push(ch);
      } else if (ch === '\b' || ch === '\u007f') {
        this.buffer = this.buffer.slice(0, -1);
      } else if (ch >= ' ' || ch === '\t') {
        this.buffer += ch;
      } else {
        if (this.buffer) {
          chunks.push(this.buffer);
          this.buffer = '';
        }
        chunks.push(ch);
      }
    }
    if (force && this.buffer) {
      const result = optimizePrompt(this.buffer, this.env);
      chunks.push(result.changed ? result.optimized : this.buffer);
      if (result.changed) {
        notice += this._notice(result);
        audit.push(toAuditEntry(result));
      }
      this.buffer = '';
    }
    return { chunks, notice, audit };
  }

  _notice(result) {
    const lines = ['\n[kivun-optimizer] RTL prompt optimized before sending to Claude.'];
    if (this.config.showEstimate && result.estimate) {
      lines.push(`[kivun-optimizer] estimate: ${result.estimate.originalTokens} -> ${result.estimate.optimizedTokens} tokens (${result.estimate.savedPercent}% saved).`);
    }
    if (this.config.showPreview) {
      lines.push('[kivun-optimizer] preview:');
      lines.push(result.optimized);
    }
    return `${lines.join('\n')}\n`;
  }
}

class TuiPromptOptimizer {
  constructor(env = process.env) {
    this.env = env;
    this.config = optimizerConfig(env);
    this.decoder = new StringDecoder('utf8');
    this.buffer = '';
    this.safeToReplace = true;
    this.inBracketedPaste = false;
    this.escBuffer = '';
  }

  write(chunk) {
    if (!this.config.enabled || this.config.mode !== 'prompt') return { chunks: [chunk], notice: '', audit: [] };
    const text = typeof chunk === 'string' ? chunk : this.decoder.write(chunk);
    return this._writeText(text);
  }

  end() {
    const rest = this.decoder.end();
    if (!this.config.enabled || this.config.mode !== 'prompt') return { chunks: rest ? [rest] : [], notice: '', audit: [] };
    return this._writeText(rest);
  }

  _writeText(text) {
    const chunks = [];
    let notice = '';
    const audit = [];
    for (const ch of text) {
      if (this.escBuffer) {
        this.escBuffer += ch;
        chunks.push(ch);
        if (this.escBuffer === '\x1b[200~') {
          this.inBracketedPaste = true;
          this.escBuffer = '';
        } else if (this.escBuffer === '\x1b[201~') {
          this.inBracketedPaste = false;
          this.escBuffer = '';
        } else if (!'\x1b[200~'.startsWith(this.escBuffer) && !'\x1b[201~'.startsWith(this.escBuffer)) {
          this.safeToReplace = false;
          this.escBuffer = '';
        }
        continue;
      }

      if (ch === '\x1b') {
        this.escBuffer = ch;
        chunks.push(ch);
        continue;
      }

      if (ch === '\r' || ch === '\n') {
        const result = this._submit(ch);
        chunks.push(...result.chunks);
        notice += result.notice;
        audit.push(...result.audit);
        continue;
      }

      if (ch === '\u0003' || ch === '\u0004') {
        this._resetLine();
        chunks.push(ch);
        continue;
      }

      if (ch === '\u0015') {
        this._resetLine();
        chunks.push(ch);
        continue;
      }

      if (ch === '\b' || ch === '\u007f') {
        this.buffer = this.buffer.slice(0, -1);
        chunks.push(ch);
        continue;
      }

      if (this.inBracketedPaste || ch >= ' ' || ch === '\t') {
        this.buffer += ch;
        chunks.push(ch);
        continue;
      }

      this.safeToReplace = false;
      chunks.push(ch);
    }
    return { chunks, notice, audit };
  }

  _submit(newline) {
    const line = this.buffer;
    const canReplace = this.safeToReplace && line && containsRTL(line);
    this._resetLine();
    if (!canReplace) return { chunks: [newline], notice: '', audit: [] };

    const result = optimizePrompt(line, this.env);
    if (!result.changed) return { chunks: [newline], notice: '', audit: [] };

    return {
      // The user already saw their typed text because we passed every key
      // through live. On Enter, ask the TUI to clear the current input line
      // (Ctrl+U), paste the optimized prompt, then submit it.
      chunks: ['\u0015', result.optimized, newline],
      notice: this._notice(result),
      audit: [toAuditEntry(result)],
    };
  }

  _resetLine() {
    this.buffer = '';
    this.safeToReplace = true;
    this.inBracketedPaste = false;
    this.escBuffer = '';
  }

  _notice(result) {
    const lines = ['[kivun-optimizer] RTL prompt optimized before sending to Claude.'];
    if (this.config.showEstimate && result.estimate) {
      lines.push(`[kivun-optimizer] estimate: ${result.estimate.originalTokens} -> ${result.estimate.optimizedTokens} tokens (${result.estimate.savedPercent}% saved).`);
    }
    if (this.config.showPreview) {
      lines.push('[kivun-optimizer] preview:');
      lines.push(result.optimized);
    }
    return `${lines.join('\n')}\n`;
  }
}

function toAuditEntry(result) {
  const estimate = result.estimate || {};
  return {
    time: new Date().toISOString(),
    language: result.language || 'rtl',
    changed: Boolean(result.changed),
    originalTokens: estimate.originalTokens || 0,
    optimizedTokens: estimate.optimizedTokens || 0,
    savedTokens: estimate.savedTokens || 0,
    savedPercent: estimate.savedPercent || 0,
  };
}

module.exports = {
  containsRTL,
  guessRTLLanguage,
  normalizeRTLInput,
  compressPrompt,
  estimateTokens,
  compareEstimate,
  optimizePrompt,
  optimizerConfig,
  StdinPromptOptimizer,
  TuiPromptOptimizer,
  toAuditEntry,
};
