# HEAVY §1 integration gate - status

**Gate:** run the three `printf` lines from HEAVY §1 inside a real Konsole
and visually confirm BiDi renders (line 2 and line 3 must show Hebrew
right-to-left while Latin remains in correct positions).

```bash
printf 'plain: שלום עולם\n'
printf 'bracketed: ‫שלום עולם‬\n'
printf 'mixed: Hello ‫שלום‬ world\n'
```

## Status (as of 2026-04-23)

**Deferred.** Noam-approved canary-gated ship approach - document the gate
as required pre-tag, don't block wrapper development on it.

## Why deferred

WSLg Konsole on the dev machine was non-functional when the MEDIUM spec
was in play (2026-04-23 decision trail; see
`docs/specs/CLAUDE_CODE_TASK_RTL_WRAPPER_MEDIUM_DEFERRED.md` preamble).
No native Linux box, no VM, no Kubuntu live USB available at the time
the wrapper was built. HEAVY's Assumption B (Konsole honors UAX #9
RLE/PDF embeddings) is near-universal for any BiDi-capable terminal,
so the gate is low-risk but not zero-risk.

## Required before v1.1.0 tag

Before anyone pushes `v1.1.0`, one of:

1. **Preferred:** run the three-line gate on a native Linux Konsole (KDE
   Neon VM, Kubuntu live USB, fellow dev's box). Log the Konsole version,
   ICU version (`konsole --version` for Konsole; `icuinfo` for ICU), the
   host OS, and a screenshot of the output. Commit the log to this folder
   as `integration-gate-<YYYY-MM-DD>.md`.
2. **Fallback:** if WSLg Konsole is working on the tagger's machine by
   tag time, the gate can run there. Note the WSLg caveat in the log.
3. **Acceptable risk path:** if both of the above are blocked, tag v1.1.0
   anyway with an explicit "integration gate not yet run" note in the
   release body, and treat the production canary (1 full day of real
   Claude Code use by the lead dev) as the primary verification. This
   is what "canary-gated ship" means in ROADMAP.md context.

Whatever path is taken, the log file must exist in this folder before
`v1.2.0` gate criteria can even be evaluated - you cannot flip the
default-on switch if the underlying assumption was never empirically
checked.

## Expected outcome

Under Assumption B, all three lines render correctly. Line 1 may appear
reversed (that's the baseline bug the wrapper fixes). Lines 2 and 3 must
show Hebrew right-to-left with Latin in correct positions.

If any line is broken, HEAVY's assumption is invalid and no version
of this wrapper can help - escalate to architectural discussion (switch
terminal? patch ink? change platform?). See HEAVY §1 "Fail" row.
