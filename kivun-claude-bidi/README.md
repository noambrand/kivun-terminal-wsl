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

## RTL cost optimizer (experiment, off by default)

`lib/rtl-cost-optimizer/` transforms **piped** Hebrew/Arabic prompts before
they reach Claude (issue #98; successor to the rejected PR #84 design):
it strips niqqud/diacritics and invisible direction marks, collapses
whitespace (fenced code blocks untouched), and — unless
`KIVUN_RTL_COST_OPTIMIZER_SCAFFOLD=off` — wraps the **full request
verbatim** in a short English frame. The user's request is never replaced
or truncated; #84 was rejected precisely for substituting canned intent
templates, and no template code exists here.

Honesty matters more than marketing: **savings are unproven.** The
scaffold adds English text, so input tokens may *increase* (the stderr
estimate shows a negative delta when it does). The experiment measures
whether English internal reasoning shortens Hebrew *output*, which costs
~2x tokens per word. Each piped line is treated as one prompt (a newline
submits in the TUI). Interactive TUI typing is never touched — when the
flag is on and stdin is a TTY, the wrapper prints one notice and passes
input through unchanged. Off (the default), the stdin path is
byte-identical to previous releases and the module is never loaded.

Per-prompt metrics (sizes and token estimates only, never prompt text)
append to `~/.local/state/kivun-terminal/rtl-cost-optimizer.jsonl` while
`KIVUN_RTL_COST_OPTIMIZER_AUDIT=on`. All knobs are documented in
`payload/config.txt`.

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
