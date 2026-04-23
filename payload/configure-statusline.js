// configure-statusline.js
// Adds statusLine configuration to Claude Code settings.json
// Usage: node configure-statusline.js <path-to-statusline.mjs>

const fs = require('fs');
const path = require('path');

const statuslinePath = process.argv[2];
if (!statuslinePath) {
    process.exit(1);
}

const claudeDir = path.join(process.env.HOME || process.env.USERPROFILE, '.claude');
const settingsFile = path.join(claudeDir, 'settings.json');

// Ensure .claude directory exists
try { fs.mkdirSync(claudeDir, { recursive: true }); } catch(e) {}

// Read existing settings or start fresh
let settings = {};
try {
    settings = JSON.parse(fs.readFileSync(settingsFile, 'utf8'));
} catch(e) {}

// Set statusLine config matching the minimal working schema: {type, command}.
// Claude Code's zod schema allows optional `padding` but the confirmed-working
// Windows settings file omits it, so we omit too.
//
// SECURITY: a path containing `"` or `\` would break the old string-concat
// form `'node "' + p + '"'` and inject arbitrary shell into the command
// Claude Code runs at every render. Use JSON.stringify on the full
// command string - that produces a JSON-safe, shell-safe quoted string
// (`JSON.stringify('a"b')` → `'"a\\"b"'`). Claude Code's statusLine
// executes `command` via a shell, so we still have one quoting level to
// care about; JSON.stringify handles both.
const normalizedPath = statuslinePath.replace(/\\/g, '/');
settings.statusLine = {
    type: 'command',
    command: 'node ' + JSON.stringify(normalizedPath)
};

// Write back
fs.writeFileSync(settingsFile, JSON.stringify(settings, null, 2) + '\n');
