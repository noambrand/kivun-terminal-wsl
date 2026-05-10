'use strict';

const { guessRTLLanguage } = require('./detector');
const { normalizeRTLInput } = require('./normalizer');
const { extractTechnicalTerms } = require('./glossary');

const INTENTS = [
  {
    name: 'cmake-failure',
    terms: [/cmake/i, /CMakeLists\.txt/i],
    words: [/נכשל|שגיא|למה|תבדוק|תקן|תתקן/, /فشل|يفشل|خطأ|تحقق|أصلح|اصلح/],
    task: 'Investigate the CMake build failure and fix the root cause.',
    constraints: ['Preserve existing tests.', 'Do not change public APIs unless required.'],
  },
  {
    name: 'test-failure',
    terms: [/test|pytest|npm test|בדיק|اختبار|tests?/i],
    words: [/נכשל|תקן|תתקן|שבור|למה/, /فشل|يفشل|أصلح|اصلح|كسر/],
    task: 'Investigate the failing tests and fix the root cause.',
    constraints: ['Keep the test intent unchanged.', 'Avoid broad refactors.'],
  },
  {
    name: 'static-analysis',
    terms: [/MISRA C|CERT C|Parasoft|cpptestcli|DTP|SARIF/i],
    words: [/תקן|תבדוק|בעיה|דוח|חריג|violation/i, /أصلح|اصلح|تحقق|تقرير|مخالفة/],
    task: 'Analyze the static-analysis findings and implement the smallest correct fixes.',
    constraints: ['Preserve source behavior.', 'Do not suppress findings without justification.'],
  },
  {
    name: 'bug-fix',
    terms: [/bug|error|exception|crash|fail/i],
    words: [/באג|שגיא|קריס|נכשל|תקן|תתקן|למה/, /خلل|خطأ|استثناء|تعطل|فشل|أصلح|اصلح/],
    task: 'Investigate the reported bug and fix the root cause.',
    constraints: ['Keep the change narrowly scoped.', 'Add or run a focused verification when practical.'],
  },
];

function compressPrompt(input) {
  const normalized = normalizeRTLInput(input);
  const language = guessRTLLanguage(normalized);
  const technicalTerms = extractTechnicalTerms(normalized);
  const match = chooseIntent(normalized, technicalTerms);
  const task = match ? match.task : buildGenericTask(normalized, technicalTerms);
  const constraints = match ? match.constraints : ['Keep the change narrowly scoped.', 'Preserve code, commands, paths, logs, and identifiers exactly.'];

  const lines = [
    'Use English for internal reasoning.',
    '',
    'Do not translate code identifiers or paths.',
    '',
    'Task:',
    task,
    '',
    'Constraints:',
    ...constraints.map((c) => `- ${c}`),
    '',
  ];
  if (technicalTerms.length > 0) {
    lines.push('Technical terms to preserve:', ...technicalTerms.slice(0, 12).map((term) => `- ${term}`), '');
  }
  lines.push(
    'Final output:',
    `Return a concise summary in ${finalLanguageName(language)}.`,
  );
  return lines.join('\n');
}

function chooseIntent(text, technicalTerms) {
  return INTENTS.find((intent) => {
    const hasTerm = intent.terms.some((re) => re.test(text)) ||
      technicalTerms.some((term) => intent.terms.some((re) => re.test(term)));
    const hasWord = intent.words.some((re) => re.test(text));
    return hasTerm && hasWord;
  }) || INTENTS.find((intent) => intent.words.some((re) => re.test(text)));
}

function buildGenericTask(text, technicalTerms) {
  const compact = text
    .replace(/```[\s\S]*?```/g, '[preserved code block]')
    .replace(/\s+/g, ' ')
    .trim();
  const suffix = technicalTerms.length > 0 ? ` Focus on: ${technicalTerms.slice(0, 6).join(', ')}.` : '';
  if (compact.length <= 80) return `Handle the user's developer request.${suffix}`;
  return `Handle the user's developer request: ${compact.slice(0, 180)}${compact.length > 180 ? '…' : ''}${suffix}`;
}

function finalLanguageName(language) {
  switch (language) {
    case 'hebrew': return 'Hebrew';
    case 'arabic': return 'the user\'s RTL language';
    case 'syriac': return 'Syriac';
    case 'thaana': return 'Dhivehi';
    case 'nko': return "N'Ko";
    case 'adlam': return 'Adlam';
    default: return "the user's RTL language";
  }
}

module.exports = { compressPrompt, finalLanguageName };
