'use strict';

// U+061C (ARABIC LETTER MARK) belongs with the directional controls.
const BIDI_CONTROLS_RE = /[\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]/g;
// Cantillation + vowel points ONLY. The naive \u0591-\u05C7 range also eats
// real punctuation - U+05BE MAQAF (the Hebrew hyphen: stripping it turns
// "\u05E2\u05DC\u05BE\u05D9\u05D3\u05D9" into "\u05E2\u05DC\u05D9\u05D3\u05D9", a different word), U+05C0 PASEQ, U+05C3 SOF PASUQ,
// U+05C6 NUN HAFUKHA - so those are carved out.
const HEBREW_NIQQUD_RE = /[\u0591-\u05BD\u05BF\u05C1\u05C2\u05C4\u05C5\u05C7]/g;
// NOTE: ZWNJ/ZWJ (U+200C/U+200D) are deliberately NOT stripped - ZWNJ is
// orthographically required in Persian (e.g. "\u0645\u06CC\u200C\u062E\u0648\u0627\u0647\u0645").
const ARABIC_MARKS_RE = /[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]/g;

function splitFencedCode(text) {
  const lines = String(text || '').split(/(\r?\n)/);
  const parts = [];
  let current = '';
  let inCode = false;

  for (let i = 0; i < lines.length; i += 2) {
    const line = lines[i] || '';
    const eol = lines[i + 1] || '';
    if (/^\s*```/.test(line)) {
      if (current) {
        parts.push({ code: inCode, text: current });
        current = '';
      }
      inCode = !inCode;
      // Fence lines themselves are never normalized: both the opening AND
      // the closing ``` must stay verbatim at line start, or the block
      // stops being a block.
      parts.push({ code: true, text: line + eol });
      continue;
    }
    current += line + eol;
  }

  if (current) parts.push({ code: inCode, text: current });
  return parts;
}

function normalizeOutsideCode(text) {
  // No .trim() here: each part's trailing newline is the boundary that
  // keeps the next fence at line start. Trimming a part merged "a\n" +
  // "```js" into "a```js" and destroyed the code block.
  return text
    .replace(BIDI_CONTROLS_RE, '')
    .replace(HEBREW_NIQQUD_RE, '')
    .replace(ARABIC_MARKS_RE, '')
    .replace(/[\t ]+/g, ' ')
    .replace(/[ ]*\r?\n[ ]*/g, '\n')
    .replace(/\n{3,}/g, '\n\n');
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
