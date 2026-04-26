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

// Set statusLine config: {type, command, padding}.
//
// padding=1 reserves a second line of vertical space at the bottom of
// every Claude Code session, so statusline.mjs (which writes two lines:
// project/model/context on top, session/weekly usage bars below) can
// actually render both. Without this, Claude Code 2.x clips to a single
// line and silently drops the second `process.stdout.write` from the
// status command. The earlier note "the confirmed-working Windows
// settings file omits it" turned out to be wrong on Claude Code 2.1+.
//
// SECURITY: a path containing `"` or `\` would break the old string-concat
// form `'node "' + p + '"'` and inject arbitrary shell into the command
// Claude Code runs at every render. Use JSON.stringify on the full
// command string — that produces a JSON-safe, shell-safe quoted string
// (`JSON.stringify('a"b')` → `'"a\\"b"'`). Claude Code's statusLine
// executes `command` via a shell, so we still have one quoting level to
// care about; JSON.stringify handles both.
const normalizedPath = statuslinePath.replace(/\\/g, '/');
settings.statusLine = {
    type: 'command',
    command: 'node ' + JSON.stringify(normalizedPath),
    padding: 1
};

// Write back
fs.writeFileSync(settingsFile, JSON.stringify(settings, null, 2) + '\n');
