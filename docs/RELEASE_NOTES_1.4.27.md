**Two things ship in this release: the invisible native launcher (v1.4.26,
never released as its own build) and a new off-by-default RTL cost-optimizer
experiment.**

**No more black window flash.** 🎉 Starting Kivun Terminal used to flash a
black command window and park a minimized console on your taskbar for the
whole session. Both are gone: the desktop shortcut and right-click "Open
with Kivun Terminal" now go through a small native launcher
(`KivunTerminal.exe`) that does its work in a completely invisible window —
Konsole is the only thing you see. Nothing else about launching changed
(folder picker, automatic Claude install, all of it), and if something goes
wrong you get a clear error popup with the last lines of the launch log. If
your antivirus blocks the new unsigned launcher, use the **"Kivun Terminal
(console)"** Start-menu shortcut — it launches exactly like previous
versions. Credit: continues [PR #83](https://github.com/noambrand/kivun-terminal-wsl/pull/83)
by **@zuwasi**.

**New experiment: RTL cost optimizer — OFF by default.**

> **Update (measured after release): it saves no tokens.** Paired A/B
> testing on Opus 4.8 and Sonnet 4.6 — including with extended thinking
> maxed out — found the net output-token effect statistically
> indistinguishable from zero, and the English frame *adds* input tokens.
> A Hebrew answer costs ~31% more tokens than the same English answer, but
> that "tax" is in the output tokenizer and can't be recovered while
> keeping Hebrew replies. Recommended: leave it off. Full data in PR
> #102 / #84. The description below is preserved as the original release text.

Set
`KIVUN_RTL_COST_OPTIMIZER=on` in `config.txt` and prompts you **pipe** into
Claude in Hebrew/Arabic get cleaned up before they're sent: niqqud/diacritics
and invisible direction marks stripped, whitespace collapsed (fenced code
blocks untouched), and the **full request, verbatim,** wrapped in a short
English frame asking Claude to reason in English and reply in your language.

Honest disclosure, because this is an experiment and not a proven win: the
English frame **adds** text, so your *input* tokens may go **up** (the
stderr estimate shows a negative delta when they do). What the experiment
actually tests is whether English internal reasoning shortens Hebrew
*output*, which costs roughly 2× tokens per word. Interactive typing in the
terminal is **never** touched — this applies to piped input only. While
enabled, per-prompt metrics (sizes and token estimates only — **never your
prompt text**) append to
`~/.local/state/kivun-terminal/rtl-cost-optimizer.jsonl` so you can judge
for yourself. All knobs are documented in `config.txt`.

Leave the flag off and the input path is byte-identical to previous
releases — the optimizer code isn't even loaded.

Credit: rebuilt from the direction in
[PR #84](https://github.com/noambrand/kivun-terminal-wsl/pull/84) by
**@zuwasi**, per the must-fixes in
[#98](https://github.com/noambrand/kivun-terminal-wsl/issues/98).
