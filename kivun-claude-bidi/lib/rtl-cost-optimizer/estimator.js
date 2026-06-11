'use strict';

const { containsRTL } = require('./detector');

function estimateTokens(text) {
  const source = String(text || '');
  let total = 0;
  let inCode = false;
  for (const rawLine of source.split(/\r?\n/)) {
    const line = rawLine || '';
    if (/^\s*```/.test(line)) {
      total += Math.max(1, line.length / 3);
      inCode = !inCode;
      continue;
    }
    if (inCode || looksLikeCodeOrLog(line)) total += line.length / 3;
    else if (containsRTL(line)) total += line.length / 2;
    else total += line.length / 4;
  }
  return Math.max(1, Math.ceil(total));
}

function looksLikeCodeOrLog(line) {
  return /^\s*(?:[$>#]|\w+Error:|at\s+\S+|\[\w+\]|\d{4}-\d{2}-\d{2})/.test(line) ||
    /(?:[A-Za-z]:\\|\/[^\s]+|\.(?:js|ts|cpp|c|h|py|json|yml|yaml|cmake|log)\b|\b(?:error|warning):)/i.test(line);
}

function compareEstimate(original, transformed) {
  const originalTokens = estimateTokens(original);
  const transformedTokens = estimateTokens(transformed);
  // Honest delta - NO clamp. A negative delta means the transformation
  // ADDED input tokens (the scaffold costs more than normalization saves);
  // hiding that behind Math.max(0, ...) was exactly the kind of dishonest
  // accounting that sank PR #84.
  const deltaTokens = originalTokens - transformedTokens;
  const deltaPercent = originalTokens === 0 ? 0 : Math.round((deltaTokens / originalTokens) * 100);
  return { originalTokens, transformedTokens, deltaTokens, deltaPercent };
}

module.exports = { estimateTokens, compareEstimate, looksLikeCodeOrLog };
