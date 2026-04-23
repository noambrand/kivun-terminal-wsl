#!/usr/bin/env node
'use strict';

// Minimal stand-in for the `claude` binary — used by test/smoke.sh to
// exercise the wrapper without needing a real Claude Code install.
// Emits a few HEAVY §7 fixture shapes and exits cleanly.

process.stdout.write('plain ascii line\n');
process.stdout.write('שלום עולם\n');
process.stdout.write('Hello שלום world\n');
process.stdout.write('foo שלום bar עולם baz\n');
process.stdout.write('\x1b[31mcolored שלום\x1b[0m\n');
process.stdout.write('mid-run SGR: שלו\x1b[31mם\x1b[0m fin\n');
process.stdout.write('שלום. Hello\n');
process.exit(0);
