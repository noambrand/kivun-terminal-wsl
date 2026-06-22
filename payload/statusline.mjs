#!/usr/bin/env node

// Claude Code Status Line — 2-Line Layout with Usage Bars
// [UPDATED] v2.2 — effort level on line 1 (default); cost/cache/tpm opt-in via env vars

import fs from 'fs';
import path from 'path';
import os from 'os';

const C = {
  g: '\x1b[32m',
  y: '\x1b[33m',
  r: '\x1b[31m',
  c: '\x1b[36m',
  d: '\x1b[90m',
  b: '\x1b[34m',
  m: '\x1b[35m',
  n: '\x1b[0m'
};

// ── Env-var opt-in flags (parsed once per invocation) ──
const truthy = v => /^(1|true|yes|on)$/i.test(String(v || ''));
const SHOW_COST  = truthy(process.env.KIVUN_SL_COST);
const SHOW_CACHE = truthy(process.env.KIVUN_SL_CACHE);
const SHOW_TPM   = truthy(process.env.KIVUN_SL_TPM);

// ── Effort source resolver ────────────
// Resolution order:
//   1) d.effort.level from stdin JSON (Anthropic issue #40261 — open as of 2026-05)
//   2) env CLAUDE_CODE_EFFORT_LEVEL
//   3) effortLevel in ~/.claude/settings.json (stale on mid-session /effort overrides)
// Returns null when no source available → field is hidden.
function readEffort(d) {
  const fromJson = d.effort?.level;
  if (fromJson) return String(fromJson);
  const fromEnv = process.env.CLAUDE_CODE_EFFORT_LEVEL;
  if (fromEnv) return String(fromEnv);
  try {
    const settingsPath = path.join(os.homedir(), '.claude', 'settings.json');
    const s = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
    if (s.effortLevel) return String(s.effortLevel);
  } catch {}
  return null;
}

// ── Progress Bar Builder ──────────────
function makeBar(pct, width = 10) {
  const filled = Math.round((pct / 100) * width);
  const empty = width - filled;
  let color = C.g;
  if (pct >= 80) color = C.r;
  else if (pct >= 50) color = C.y;
  return `${color}${'█'.repeat(filled)}${C.d}${'░'.repeat(empty)}${C.n}`;
}

// ── Reset Countdown ───────────────────
function resetIn(epochSec) {
  if (!epochSec) return '';
  const diffMs = epochSec * 1000 - Date.now();
  if (diffMs <= 0) return 'now';
  const totalMin = Math.floor(diffMs / 60000);
  const h = Math.floor(totalMin / 60);
  const m = totalMin % 60;
  if (h >= 24) {
    const d = Math.floor(h / 24);
    const rh = h % 24;
    return `${d}d${rh}h`;
  }
  return h > 0 ? `${h}h${String(m).padStart(2, '0')}m` : `${m}m`;
}

// ── Model ─────────────────────────────
function fieldModel(d) {
  const name = d.model?.display_name || '?';
  const color = /opus/i.test(name) ? C.g : C.y;
  return `${color}${name}${C.n}`;
}

// ── Context Used ──────────────────────
function fieldContextUsed(d) {
  const used = Math.round(d.context_window?.used_percentage || 0);
  return `Context ${makeBar(used)} ${used}%`;
}

// ── Project Folder ────────────────────
function fieldProject(d) {
  const dir = d.workspace?.current_dir || d.cwd || '';
  const folder = dir.split(/[/\\]/).filter(Boolean).pop() || '~';
  return `${C.c}${folder}${C.n}`;
}

// ── Cumulative session tokens, INCLUDING sub-agents ──
// Claude Code's context_window.total_* counts only the MAIN agent's current
// context window (and, since v2.1.132, isn't even cumulative), so sub-agent
// (Task) usage never shows up there. To get a true session total we sum
// input+output across the session transcript PLUS the sibling subagents/ tree
// (Claude Code writes each sub-agent to <session>/subagents/**/*.jsonl).
//
// Done per render, so it must stay cheap: results are cached per file by
// size+mtime in a tmp file, and append-only growth is parsed INCREMENTALLY
// (only the bytes added since last render). Any failure falls back to the
// context_window value, so the field can never break or block the statusline.
function collectJsonl(dir, out) {
  let entries;
  try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch { return; }
  for (const e of entries) {
    const p = dir + '/' + e.name;
    if (e.isDirectory()) collectJsonl(p, out);
    else if (e.name.endsWith('.jsonl')) out.push(p);
  }
}

function sessionTokensInOut(d) {
  const transcript = d.transcript_path;
  if (!transcript) return null;
  const files = [transcript];
  collectJsonl(transcript.replace(/\.jsonl$/, '') + '/subagents', files);

  const key = encodeURIComponent(transcript).replace(/[^a-z0-9]/gi, '_').slice(-60);
  const cachePath = path.join(os.tmpdir(), 'kivun-sl-tokens-' + key + '.json');
  let cache = {};
  try { cache = JSON.parse(fs.readFileSync(cachePath, 'utf8')); } catch {}

  let totalIn = 0, totalOut = 0, dirty = false;
  for (const f of files) {
    let st;
    try { st = fs.statSync(f); } catch { continue; }
    const ent = cache[f];
    // Unchanged since last render → reuse the cached per-file totals.
    if (ent && ent.size === st.size && ent.mtimeMs === st.mtimeMs) {
      totalIn += ent.inTok; totalOut += ent.outTok;
      continue;
    }
    // Resume from the last byte offset when the file only grew (append-only);
    // otherwise (new/shrunk/rotated) reparse from the start.
    let offset = 0, inTok = 0, outTok = 0;
    if (ent && st.size >= ent.size && st.size >= ent.offset) {
      offset = ent.offset; inTok = ent.inTok; outTok = ent.outTok;
    }
    try {
      const len = st.size - offset;
      let consumedBytes = 0;
      if (len > 0) {
        const fd = fs.openSync(f, 'r');
        const buf = Buffer.allocUnsafe(len);
        fs.readSync(fd, buf, 0, len, offset);
        fs.closeSync(fd);
        const text = buf.toString('utf8');
        const lastNl = text.lastIndexOf('\n');
        if (lastNl >= 0) {
          const whole = text.slice(0, lastNl);          // only complete lines
          for (const ln of whole.split('\n')) {
            if (!ln) continue;
            try {
              const u = JSON.parse(ln).message?.usage;
              if (u) { inTok += u.input_tokens || 0; outTok += u.output_tokens || 0; }
            } catch {}
          }
          consumedBytes = Buffer.byteLength(whole, 'utf8') + 1; // + the '\n'
        }
      }
      cache[f] = { size: st.size, mtimeMs: st.mtimeMs, offset: offset + consumedBytes, inTok, outTok };
      dirty = true;
      totalIn += inTok; totalOut += outTok;
    } catch { /* unreadable file — skip, keep going */ }
  }

  if (dirty) {
    try {
      const tmp = cachePath + '.' + process.pid;
      fs.writeFileSync(tmp, JSON.stringify(cache));
      fs.renameSync(tmp, cachePath);
    } catch {}
  }
  return totalIn + totalOut;
}

// ── Total Tokens (cumulative session, incl. sub-agents) ──
function fieldTokens(d) {
  let total = sessionTokensInOut(d);
  if (total == null) {
    // Fallback: no transcript_path (older Claude Code / tests) → main window.
    total = (d.context_window?.total_input_tokens || 0) + (d.context_window?.total_output_tokens || 0);
  }
  let label;
  if (total >= 1_000_000) label = (total / 1_000_000).toFixed(1) + 'M';
  else if (total >= 1_000) label = Math.round(total / 1_000) + 'K';
  else label = String(total);
  return `${C.y}total tokens:${label}${C.n}`;
}

// ── Duration ──────────────────────────
function fieldDuration(d) {
  const ms = d.cost?.total_duration_ms || 0;
  const totalMin = Math.floor(ms / 60000);
  const hrs = Math.floor(totalMin / 60);
  const mins = totalMin % 60;
  const fmt = hrs > 0
    ? `${hrs}:${String(mins).padStart(2, '0')}`
    : `${totalMin}m`;
  return `${C.d}duration:${fmt}${C.n}`;
}

// ── Full Path ─────────────────────────
function fieldFullPath(d) {
  const dir = d.workspace?.current_dir || d.cwd || '';
  if (!dir) return '';
  return `${C.d}${dir}${C.n}`;
}

// ── Effort Level (default-on, hides if unresolved) ──
function fieldEffort(d) {
  const level = readEffort(d);
  if (!level) return '';
  return `${C.m}effort:${level}${C.n}`;
}

// ── Session Cost (opt-in: KIVUN_SL_COST=1) ──
function fieldCost(d) {
  if (!SHOW_COST) return '';
  const usd = d.cost?.total_cost_usd;
  if (usd == null) return '';
  return `${C.g}$${Number(usd).toFixed(2)}${C.n}`;
}

// ── Cache Tokens (opt-in: KIVUN_SL_CACHE=1) ──
function fieldCache(d) {
  if (!SHOW_CACHE) return '';
  const cu = d.context_window?.current_usage;
  if (!cu) return '';
  const cache = (cu.cache_read_input_tokens || 0) + (cu.cache_creation_input_tokens || 0);
  if (cache <= 0) return '';
  let label;
  if (cache >= 1_000_000) label = (cache / 1_000_000).toFixed(1) + 'M';
  else if (cache >= 1_000) label = Math.round(cache / 1_000) + 'K';
  else label = String(cache);
  return `${C.b}cache:${label}${C.n}`;
}

// ── Tokens / Minute (opt-in: KIVUN_SL_TPM=1) ──
function fieldTpm(d) {
  if (!SHOW_TPM) return '';
  const ms = d.cost?.total_duration_ms || 0;
  if (ms < 5000) return '';
  const out = d.context_window?.total_output_tokens || 0;
  const tpm = Math.round(out / (ms / 60000));
  if (!tpm) return '';
  return `${C.c}tpm:${tpm}${C.n}`;
}

// ── 5-Hour Usage ──────────────────────
function fieldUsage5h(d) {
  const rl = d.rate_limits?.five_hour;
  if (!rl) return `Session ${C.d}-- undefined --${C.n}`;
  const pct = Math.round(rl.used_percentage || 0);
  const rst = resetIn(rl.resets_at);
  return `Session ${makeBar(pct)} ${pct}%${rst ? C.d + ' resets in ' + rst + C.n : ''}`;
}

// ── 7-Day Usage ───────────────────────
function fieldUsage7d(d) {
  const rl = d.rate_limits?.seven_day;
  if (!rl) return `Weekly ${C.d}-- undefined --${C.n}`;
  const pct = Math.round(rl.used_percentage || 0);
  const rst = resetIn(rl.resets_at);
  return `Weekly ${makeBar(pct)} ${pct}%${rst ? C.d + ' resets in ' + rst + C.n : ''}`;
}

// ── Line 1: session info ──────────────
const LINE1 = [
  fieldProject,
  fieldModel,
  fieldEffort,
  fieldContextUsed,
  fieldTokens,
  fieldCache,
  fieldTpm,
  fieldCost,
  fieldDuration,
  fieldFullPath
];

// ── Line 2: usage bars ───────────────
const LINE2 = [
  fieldUsage5h,
  fieldUsage7d
];

// ── Input / Output ────────────────────
let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => { raw += chunk; });
process.stdin.on('end', () => {
  try {
    const data = JSON.parse(raw);
    const sep = `${C.d}|${C.n}`;
    const top = LINE1.map(fn => fn(data)).filter(Boolean).join(` ${sep} `);
    const bot = LINE2.map(fn => fn(data)).filter(Boolean).join(`  ${sep}  `);
    process.stdout.write(top + '\n');
    if (bot) process.stdout.write(bot + '\n');
  } catch {
    process.stdout.write('statusline: parse error\n');
  }
});
