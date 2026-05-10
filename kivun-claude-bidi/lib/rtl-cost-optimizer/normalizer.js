'use strict';

const BIDI_CONTROLS_RE = /[\u200E\u200F\u202A-\u202E\u2066-\u2069]/g;
const HEBREW_NIQQUD_RE = /[\u0591-\u05C7]/g;
const ARABIC_MARKS_RE = /[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]/g;

function splitFencedCode(text) {
  const lines = String(text || '').split(/(\r?\n)/);
  const parts = [];
  let current = '';
  let inCode = false;
  let currentIsCode = false;

  for (let i = 0; i < lines.length; i += 2) {
    const line = lines[i] || '';
    const eol = lines[i + 1] || '';
    const fence = /^\s*```/.test(line);
    if (fence && current) {
      parts.push({ code: currentIsCode, text: current });
      current = '';
    }
    if (fence) {
      currentIsCode = !inCode;
      inCode = !inCode;
    }
    current += line + eol;
    if (fence) {
      parts.push({ code: currentIsCode, text: current });
      current = '';
      currentIsCode = inCode;
    }
  }

  if (current) parts.push({ code: currentIsCode, text: current });
  return parts;
}

function normalizeOutsideCode(text) {
  return text
    .replace(BIDI_CONTROLS_RE, '')
    .replace(HEBREW_NIQQUD_RE, '')
    .replace(ARABIC_MARKS_RE, '')
    .replace(/[\t ]+/g, ' ')
    .replace(/[ ]*\r?\n[ ]*/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function normalizeRTLInput(text) {
  return splitFencedCode(text).map((part) => {
    if (part.code) return part.text;
    return normalizeOutsideCode(part.text);
  }).join('').trim();
}

module.exports = {
  normalizeRTLInput,
  splitFencedCode,
  BIDI_CONTROLS_RE,
  HEBREW_NIQQUD_RE,
};
