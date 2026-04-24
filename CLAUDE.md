# Working notes for AI agents on this repo

## Decision-making

**When the bulletproof option is obvious, do it. Do not ask.**

If you have validated half of a feature (e.g. the decline path of an installer prompt) and the other half is obviously the path users actually care about (e.g. the auto-install path itself), add the validation - don't offer the user a choice between the obviously-right and obviously-wrong option. Framing an obvious call as a question shifts engineering judgment onto the user and risks them picking the worse option for the wrong reason (saving CI minutes, looking decisive, etc.).

Reserve questions for genuine trade-offs - cost vs. benefit, scope, taste. Completeness and self-doubt are not the same as helpfulness when the answer is obvious.

## Bulletproofing this product specifically

This repo ships a launcher that runs on someone else's Windows machine. The user-visible failure mode that ate v1.1.0 was: launcher said "Claude not found", then claimed to fall back, then crashed running the missing binary. Treat every launcher path as a path that must work end-to-end on a clean machine - not just "exit cleanly when broken." The CI in `.github/workflows/validate-launcher-windows.yml` exists to enforce this; if you add a new launcher branch, add a CI job that exercises it against real WSL.
