# kivun-claude-bidi

BiDi wrapper for Claude Code running under Konsole on Linux (WSL or native).
Injects Unicode RLE/PDF bracket pairs around Hebrew runs in Claude Code's
output stream so Hebrew renders right-to-left regardless of Konsole profile
settings.

**Status: scaffold only.** Injector logic is not yet implemented. See
[`docs/specs/CLAUDE_CODE_TASK_RTL_WRAPPER_HEAVY.md`](../docs/specs/CLAUDE_CODE_TASK_RTL_WRAPPER_HEAVY.md)
for the architecture spec and [`docs/specs/ROADMAP.md`](../docs/specs/ROADMAP.md)
for the ship plan.

## Fixture partition

See ROADMAP.md. Ship-blocking core = 10 fixtures in `test/core.test.js`.
Nice-to-have = 8 fixtures in `test/extended.test.js`. Partition approved
2026-04-23.

## v1.1.0 posture

Wrapper is opt-in. Enable by setting `KIVUN_BIDI_WRAPPER=on` in
`~/.config/kivun-terminal/config.txt`. Default-on lands in v1.2.0 after
a feedback cycle — see ROADMAP.md for criteria.

## Copy/paste note

Pasted text copied from a wrapped Konsole session may contain zero-width
direction marks (RLE U+202B, PDF U+202C). To strip them:

    tr -d '‫‬'

Most modern tools handle these transparently; this is only needed when
pasting into tools that render the marks as visible boxes.

## License

MIT — see repository root LICENSE.
