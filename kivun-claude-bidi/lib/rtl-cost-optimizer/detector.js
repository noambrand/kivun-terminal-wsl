'use strict';

// RTL script ranges used by Kivun users. Keep this local and deterministic:
// no external language detection services are called.
const RANGES = {
  hebrew: [
    [0x0590, 0x05FF],
    [0xFB1D, 0xFB4F],
  ],
  arabic: [
    [0x0600, 0x06FF],
    [0x0750, 0x077F],
    [0x0870, 0x089F],
    [0x08A0, 0x08FF],
    [0xFB50, 0xFDFF],
    [0xFE70, 0xFEFF],
  ],
  syriac: [[0x0700, 0x074F]],
  thaana: [[0x0780, 0x07BF]],
  nko: [[0x07C0, 0x07FF]],
  adlam: [[0x1E900, 0x1E95F]],
};

function inRanges(cp, ranges) {
  return ranges.some(([start, end]) => cp >= start && cp <= end);
}

function containsRTL(text) {
  for (const ch of String(text || '')) {
    const cp = ch.codePointAt(0);
    if (Object.values(RANGES).some((ranges) => inRanges(cp, ranges))) return true;
  }
  return false;
}

function guessRTLLanguage(text) {
  const counts = Object.fromEntries(Object.keys(RANGES).map((name) => [name, 0]));
  for (const ch of String(text || '')) {
    const cp = ch.codePointAt(0);
    for (const [name, ranges] of Object.entries(RANGES)) {
      if (inRanges(cp, ranges)) counts[name] += 1;
    }
  }

  const best = Object.entries(counts).sort((a, b) => b[1] - a[1])[0];
  if (!best || best[1] === 0) return 'unknown';
  // Persian, Urdu, Arabic, Kurdish, Dari, Uyghur, Sindhi and Pashto share
  // Arabic-script Unicode ranges. Without a dictionary or external service,
  // "arabic" is the safest script-level label.
  return best[0];
}

module.exports = { containsRTL, guessRTLLanguage, RANGES };
