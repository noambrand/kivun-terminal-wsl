'use strict';

const GLOSSARY_TERMS = [
  'CMakeLists.txt',
  'MISRA C',
  'CERT C',
  'Claude Code',
  'Sourcegraph',
  'cpptestcli',
  'Parasoft',
  'Ampcode',
  'CMake',
  'SARIF',
  'DTP',
];

const PATH_OR_FILE_RE = /(?:[A-Za-z]:\\|\.\.?\/|\/|~\/)?[\w.-]+(?:[\\/][\w .@+()-]+)+|[\w.-]+\.(?:c|cc|cpp|cxx|h|hpp|js|ts|tsx|jsx|json|yaml|yml|toml|ini|md|txt|log|sh|ps1|bat|cmake|py|java|cs|go|rs)/g;
const COMMAND_RE = /\b(?:npm|pnpm|yarn|node|python3?|pip|cmake|make|ninja|git|docker|wsl|bash|cpptestcli|pytest|ruff|mypy|npm test|npm install)\b(?:\s+[-\w./:=@]+){0,6}/gi;

function unique(items) {
  return [...new Set(items.filter(Boolean))];
}

function extractTechnicalTerms(text) {
  const source = String(text || '');
  const found = [];
  for (const term of GLOSSARY_TERMS) {
    if (new RegExp(`\\b${term.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'i').test(source)) {
      found.push(term);
    }
  }
  found.push(...(source.match(PATH_OR_FILE_RE) || []));
  found.push(...(source.match(COMMAND_RE) || []).map((s) => s.trim()));
  return unique(found);
}

module.exports = { GLOSSARY_TERMS, extractTechnicalTerms };
