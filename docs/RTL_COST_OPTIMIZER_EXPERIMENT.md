# RTL Cost Optimizer — Experiment & Findings

Status: **experiment complete, shipped OFF by default.**
Verdict: **it does not save tokens — not in general, and not even for users who want Hebrew/RTL replies.**

This document records what the RTL cost optimizer is, exactly what was tested,
the measured numbers, and why the result is structural rather than a tuning
problem. It is the consolidated write-up behind issue #98, PR #102 (the rebuilt
implementation), and PR #84 (@zuwasi's original prototype).

## What it is

`kivun-claude-bidi/lib/rtl-cost-optimizer/` transforms **piped** Hebrew/Arabic
prompts before they reach Claude Code:

1. **Normalize (lossless):** strip niqqud/diacritics and invisible direction
   marks, collapse runs of whitespace. Fenced code blocks pass through
   byte-for-byte. Maqaf (U+05BE) and ZWNJ (U+200C) are deliberately preserved.
2. **Scaffold (optional, on by default):** wrap the **full normalized request
   verbatim** in a short English frame ("Use English for internal reasoning…
   Reply in Hebrew."). The request is never replaced, summarized, or truncated.

It only acts on **piped** input; interactive TUI typing is never touched. It is
off by default; when off, the stdin path is byte-identical to previous releases
and the module is never even loaded.

## How it was measured

- **Real Claude calls**, not estimates: `claude -p --output-format json`,
  reading actual `usage.output_tokens`.
- **Bare `claude`, not the wrapper**, so the wrapper's BiDi output marks could
  not corrupt the JSON. Output tokens depend only on the prompt Claude receives,
  so feeding the transformed-vs-raw prompt to bare `claude` measures the exact
  same thing production would.
- **Paired design**: the same prompt sent raw (OFF) and transformed (ON).
- **Models**: Opus 4.8 (standard + 1M) and Sonnet 4.6. (Claude Code's
  `modelUsage` also lists a background helper model, Haiku — not a test target;
  an early mislabel was traced to this and corrected.)
- **Controlled effort**: the harness was found to inherit `CLAUDE_EFFORT=xhigh`
  ambiently; effort was then pinned explicitly per experiment.
- Roughly **110 real API calls**, about **$8** of usage in total.

## Experiments and results

### 1. Input-side dry run (free, no API)
Normalization alone trims ~5% of *input* tokens — real but tiny, and input is
~⅕ the price of output. The scaffold *adds* ~30–40 input tokens per prompt
(roughly doubles short prompts).

### 2. First A/B (single sample, 5 prompts, Opus 4.8 1M)
Showed a tempting **−7.4% output**. This turned out to be noise.

### 3. Repeated paired A/B with statistics (Opus 4.8, 5 prompts × 3 reps)
Mean **+4.7%** output (it *cost* more), 95% CI **[−0.1%, +9.6%]**, not
significant. The two prompts that drove the original −7.4% reversed and got
*longer* in all three repeats. Pooling all 25 Opus 4.8 samples: **+1.9%**,
95% CI **[−2.2%, +6.0%]** — 11 of 25 shorter, 14 longer, a coin flip. Two runs
of the *same model on the same prompts* disagreed in sign, which is the clearest
proof a single sample could not be trusted.

### 4. Hebrew output tax (Opus 4.8, identical question, reply language flipped)
A Hebrew answer costs **1.31× the tokens** of the same answer in English
(**+31%**). This is the theoretical ceiling for any output-side optimizer — and
it is unreachable without abandoning Hebrew replies.

### 5. Decisive test — A/B with extended thinking on (Opus 4.8, `--effort xhigh`)
The one scenario where "reason in English" could plausibly pay off (Hebrew reply
kept; only the hidden reasoning could shrink). Result over 5 prompts × 3 reps:
mean **−0.5%**, 95% CI **[−5.8%, +4.8%]**, t = −0.21 — indistinguishable from
zero, prompts scattered both directions. **No benefit even with reasoning
maxed out.**

## Why the result is structural

A Hebrew answer's token cost splits in two:

1. **The visible Hebrew answer** — ~31% more tokens than English (experiment 4).
   That cost lives in the tokenizer; the optimizer correctly keeps the answer in
   Hebrew, so it cannot touch it. The only way around it is to answer in English,
   which defeats the product.
2. **The hidden reasoning** before the answer — the scaffold's "think in English"
   can only bite here, and experiment 5 shows it does not move total tokens
   (Claude already reasons efficiently regardless of prompt language).

The expensive part cannot be optimized away while keeping Hebrew output, and the
part that could be does not shrink. There is nothing left to win at the prompt
layer. The only real levers for cutting Hebrew token cost are a better tokenizer
(Anthropic's call) or accepting English replies (a product decision, not an
optimization).

## Conclusion

- Shipping **off by default** is correct; there is no user segment for whom
  turning it on is justified by savings.
- The lossless normalization is harmless but immaterial; the scaffold is
  net-neutral-to-slightly-negative.
- Documentation across `config.txt`, the READMEs, CHANGELOG, and release notes
  states the measured "no benefit" rather than the pre-measurement "unproven."

Full discussion: PR #102 (rebuild) and PR #84 (@zuwasi's original direction).
