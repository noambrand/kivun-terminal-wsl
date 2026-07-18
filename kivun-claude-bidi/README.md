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

## RTL cost optimizer (experiment, off by default — measured as no-benefit)

`lib/rtl-cost-optimizer/` transforms **piped** Hebrew/Arabic prompts before
they reach Claude (issue #98; successor to the rejected PR #84 design):
it strips niqqud/diacritics and invisible direction marks, collapses
whitespace (fenced code blocks untouched), and — unless
`KIVUN_RTL_COST_OPTIMIZER_SCAFFOLD=off` — wraps the **full request
verbatim** in a short English frame. The user's request is never replaced
or truncated; #84 was rejected precisely for substituting canned intent
templates, and no template code exists here.

**Verdict after measurement: it does not save tokens.** Paired A/B testing
on Opus 4.8 and Sonnet 4.6 — including with extended thinking maxed out —
found the net output-token effect statistically indistinguishable from
zero (e.g. Opus 4.8 at `--effort xhigh`: −0.5%, 95% CI [−5.8%, +4.8%]),
while the English scaffold *adds* input tokens. The reason is structural:
a Hebrew answer costs ~31% more tokens than the same English answer (the
"Hebrew tax"), that cost lives entirely in the output tokenizer, and the
optimizer correctly keeps the answer in Hebrew — so it cannot reach it.
The "reason in English" lever has nothing to grab because Claude already
reasons efficiently regardless of prompt language. Kept off by default and
shipped only as a documented experiment; full data in PR #102 / #84.

Each piped line is treated as one prompt (a newline submits in the TUI).
Interactive TUI typing is never touched — when the flag is on and stdin is
a TTY, the wrapper prints one notice and passes input through unchanged.
Off (the default), the stdin path is byte-identical to previous releases
and the module is never loaded.

Per-prompt metrics (sizes and token estimates only, never prompt text)
append to `~/.local/state/kivun-terminal/rtl-cost-optimizer.jsonl` while
`KIVUN_RTL_COST_OPTIMIZER_AUDIT=on`. All knobs are documented in
`payload/config.txt`.

## Test coverage

Ship-blocking core = 10 fixtures in `test/core.test.js`. Extended = 8 in
`test/extended.test.js`. Those files pin the **legacy** env combo
(`FLATTEN_COLORS_RTL=off`, `BRACKET_RTL_RUNS=on`); `test/*-defaults.test.js`
re-run the same inputs against the **shipping defaults** (`FLATTEN=on`,
`BRACKET=off`) — the code path real users run — and
`test/known-limitations.test.js` pins default-mode behavior for a few narrow
edge inputs so future changes to them are caught in review. End-to-end smoke at
`test/smoke.sh` exercises the wrapper via node-pty against a fake-claude
stand-in.

## What the wrapper guarantees

Working at the terminal byte-stream layer, the wrapper holds these properties:

- **Mixed-line run ordering.** On a Hebrew-first line, embedded English/code/
  number tokens keep their internal left-to-right order and are positioned
  correctly relative to the Hebrew (line-start RLM sets paragraph direction).
- **No character substitution.** Arrows (`→ ← ↑ ↓`) and box-drawing chars
  (`├ └ │ ─ ┌ ┐ ┘ ┤`) pass through byte-for-byte — never mirrored or swapped,
  so tree renderers and status indicators stay intact (HEAVY §8).
- **Streaming-safe chunk handling.** Direction decisions survive Claude's
  token-by-token streaming: the line-start buffer is held across `write()`
  calls and UTF-8 codepoints split across chunk boundaries are re-assembled.
- **Input passthrough.** Absolute/vertical cursor motion (the alt-screen input
  box) suppresses the line-start RLM, so live Hebrew editing is not corrupted
  (v1.1.14/v1.1.15).

For the Claude **desktop app** (a different surface, not the terminal),
[liorshaya/claude-desktop-rtl](https://github.com/liorshaya/claude-desktop-rtl)
is a separate DOM/CSS-based tool.

## Copy/paste note

Pasted text copied from a wrapped Konsole session may contain zero-width
direction marks (RLE U+202B, PDF U+202C). To strip them:

    tr -d '‫‬'

Most modern tools handle these transparently; this is only needed when
pasting into tools that render the marks as visible boxes.

## License

MIT - see repository root LICENSE.
