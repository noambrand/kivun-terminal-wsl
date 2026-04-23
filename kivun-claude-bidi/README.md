# kivun-claude-bidi

BiDi wrapper for Claude Code. Injects Unicode RLE/PDF bracket pairs around
Hebrew runs in Claude Code's output stream and an RLM (U+200F) at the start
of any line whose first strong char is RTL - so Hebrew renders right-to-left
regardless of the host terminal's BiDi profile and the bullet-prefixed
first line is no longer LTR-stuck.

See [`docs/specs/CLAUDE_CODE_TASK_RTL_WRAPPER_HEAVY.md`](../docs/specs/CLAUDE_CODE_TASK_RTL_WRAPPER_HEAVY.md)
for the architecture spec.

## Where it ships

The wrapper is bundled into all three Kivun Terminal installers and is
default-on as of v1.1.0:

- **Windows (WSL):** Source ships under `%LOCALAPPDATA%\Kivun-WSL\kivun-claude-bidi\`. The launcher syncs it to `~/.local/share/kivun-terminal/kivun-claude-bidi/` on first run and runs `npm install` once inside WSL.
- **Linux:** `linux/install.sh` deploys to `~/.local/share/kivun-terminal/kivun-claude-bidi/` and runs `npm install --production` at install time. Launcher retries on first launch if npm wasn't on PATH yet.
- **macOS:** The `.pkg` postinstall deploys to `/usr/local/share/kivun-terminal/kivun-claude-bidi/` and runs `npm install --production` as the real user (so `node-pty` builds against the host arch).

Toggle with `KIVUN_BIDI_WRAPPER=on|off` in the platform-specific config
(see TROUBLESHOOTING.md for paths). Off → fall back to unwrapped `claude`.

## Test coverage

Ship-blocking core = 10 fixtures in `test/core.test.js`. Extended = 8 in
`test/extended.test.js`. End-to-end smoke at `test/smoke.sh` exercises the
wrapper via node-pty against a fake-claude stand-in.

## Copy/paste note

Pasted text copied from a wrapped Konsole session may contain zero-width
direction marks (RLE U+202B, PDF U+202C). To strip them:

    tr -d '‫‬'

Most modern tools handle these transparently; this is only needed when
pasting into tools that render the marks as visible boxes.

## License

MIT - see repository root LICENSE.
