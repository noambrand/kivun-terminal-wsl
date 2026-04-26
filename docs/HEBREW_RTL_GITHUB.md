# Writing Hebrew (and other RTL languages) in GitHub-rendered Markdown

A working guide based on the bugs we hit while building Kivun Terminal's bilingual README. Same rules apply to Arabic, Persian, Urdu, and any other RTL language.

GitHub renders Markdown to HTML and then displays it through its own CSS. Every step in that pipeline has its own opinion about text direction. The pipeline gets it wrong by default for RTL content, and the workarounds aren't symmetric — what fixes a paragraph doesn't fix a list, what fixes a list doesn't fix a blockquote.

This page documents the patterns that actually work on github.com today (April 2026, last verified against the README in this repo).

## The core problem

Markdown source has no direction metadata. GitHub renders every paragraph as LTR by default. Hebrew text inside an LTR paragraph is still typed and stored left-to-right in source order — the *visual* flip happens at render time only if the renderer decides the line is RTL.

The renderer decides per-element, not per-document. Wrapping the whole Hebrew section in `<div dir="rtl">` is necessary but not sufficient: many child elements (markdown lists, blockquotes, table cells) silently break out of that direction context.

## The patterns that work

### 1. Wrap the section in `<div dir="rtl">`

```markdown
<div dir="rtl">

## הסבר בעברית

טקסט בעברית כאן.

</div>
```

The blank lines inside the `<div>` matter — without them, GitHub's parser may stop interpreting the contents as Markdown.

This wrapper handles plain paragraphs and headings correctly. Lists, blockquotes, tables: see below.

### 2. Convert markdown lists (`- ...`) to raw `<ul dir="rtl">`

This is the bug that bit us most often. A markdown bullet list inside the `<div dir="rtl">` wrapper renders LTR if any line starts with an English strong character — `**Windows:**`, `[Adaptive-RTL-Extension]`, a code span like `` `wsl --install` ``. The renderer decides the list direction based on the first strong character of each line, not the parent element.

Don't fight it with markdown. Replace the whole list with raw HTML:

```html
<ul dir="rtl" align="right">
  <li><strong>Windows:</strong> <code>wsl --install</code> חד-פעמי, אז להוריד את <code>Kivun_Terminal_Setup.exe</code> מ-<a href="...">הגרסה האחרונה</a> ולהריץ.</li>
  <li><strong>Linux:</strong> <code>git clone</code> + <code>./linux/install.sh</code>.</li>
</ul>
```

The `align="right"` is belt-and-suspenders — `dir="rtl"` should be enough on conforming renderers, but `align` was respected by every GitHub-flavored markdown variant we tested.

You lose markdown's ergonomics (`-` becomes `<li>`, `**bold**` becomes `<strong>`, `[text](url)` becomes `<a href="url">text</a>`, etc.). Worth it.

### 3. Convert markdown blockquotes (`> ...`) to raw `<blockquote dir="rtl">`

Same root cause as lists. The Markdown `>` syntax produces a `<blockquote>` element that does NOT inherit direction from `<div dir="rtl">` reliably:

```html
<blockquote dir="rtl" align="right">
<strong>Windows 11 - Smart App Control חוסם את ההתקנה.</strong> טקסט המשך כאן.
</blockquote>
```

### 4. Flip arrow characters (`→` ↔ `←`)

Arrows are directional glyphs that pass through any BiDi engine unchanged. They look at where they're aimed in source order, not in visual flow. So in RTL Hebrew context:

| Source | Reads as | Correct? |
|---|---|---|
| `Start → Smart App Control → Off` | "Start" appears on the right, then arrow points away from it (correct visually for LTR readers, wrong for RTL) | Wrong in RTL |
| `Start ← Smart App Control ← Off` | Arrow points right-to-left — same direction as Hebrew reads | Correct in RTL |

Rule: in Hebrew/Arabic/Persian text describing a left-to-right *visual* sequence, use `←`. The reader's eye moves right-to-left and the arrow should match.

Same goes for any directional glyph — `▶ ◀`, `» «`, etc. Use the RTL-pointing variant in RTL prose.

### 5. Don't translate code, paths, commands

```markdown
- **Windows:** `wsl --install` חד-פעמי
```

`wsl --install` stays English. So do file paths, commit messages, error strings, and anything someone might Cmd+F for. Translating them creates docs that look authentic but are useless for debugging.

### 6. Don't use em-dash inside Hebrew prose

In Hebrew typography the em-dash `—` reads visually as part of the previous word and creates seam-bugs in narrow column widths on some renderers. Use `-` (regular hyphen, U+002D) consistently. This is a project preference here, not a universal rule.

### 7. Mind the line-start strong-character rule

Even outside lists, a paragraph or table cell that starts with strong-LTR content will render LTR. If you have a Hebrew paragraph that opens with an English term:

```
ה-VS Code הוא IDE טוב, אבל...
```

The leading `ה-` is Hebrew-strong, so this renders RTL. But:

```
VS Code הוא IDE טוב, אבל...
```

renders LTR (the line *starts* with `V` which is LTR-strong) and the Hebrew gets stranded mid-line. Reorder so a Hebrew character comes first, or wrap the line:

```html
<p dir="rtl"><strong>VS Code</strong> הוא IDE טוב, אבל...</p>
```

### 8. Country flags: use a `<table>`, not a `<p>` or a markdown list

This one took five PRs to get right. The bug we kept hitting:

- Regional-indicator emojis (`🇬🇧 🇮🇱`) render as the literal letter pairs "GB"/"IL" on **Windows** — Microsoft's emoji font has no flag glyphs, by design. Most GitHub readers are on Windows. Don't use these emojis where readers expect flags.
- So we switched to PNG flags from [`flagcdn.com`](https://flagcdn.com) - real images that render the same on every OS. **But:** GitHub's renderer auto-injects `style="...display: block"` on every `<img>` inside markdown content. That `display: block` makes the flag stack on its own line above any sibling text or link, no matter how the markup is structured. Width, height, `align="absmiddle"`, `valign`, `<picture>` wrappers, image-outside-the-anchor — none of it overrides the injected `display: block`, because GitHub's HTML sanitizer drops your `style` attribute and the CSS class selector wins.
- Gemoji shortcodes (`:uk:`, `:israel:`) **partially** work — GitHub renders them as raw unicode chars in the API output (no `<g-emoji>` wrapper), and on the actual page Twemoji applies, but only sometimes and not reliably across viewers. Also, only specific aliases work: `:uk:`, `:gb:`, `:flag_gb:` are valid; `:israel:`, `:flag_il:` valid; `:flag-il:` (hyphen) is **not** valid.
- `shields.io` badges with `?logo=linkedin` (and similar) are **broken** — the LinkedIn icon was removed from shields.io's named-logos list. The icon never embeds in the SVG. Drop the `?logo=` param and use a clean text badge.

The only thing that actually puts flag image + text on a single line:

```html
<table align="center" border="0" cellspacing="0" cellpadding="6"><tr>
<td valign="middle"><img src="https://flagcdn.com/20x15/gb.png" alt="GB" width="20" height="15"></td>
<td valign="middle"><a href="#english"><b>English</b></a></td>
<td valign="middle"><img src="https://flagcdn.com/20x15/il.png" alt="IL" width="20" height="15"></td>
<td valign="middle"><a href="#%D7%A2%D7%91%D7%A8%D7%99%D7%AA"><b>עברית</b></a></td>
</tr></table>
```

Each `<td>` bounds the `display: block` to the cell's natural width; the table row forces horizontal layout. Trade-off: GitHub's CSS adds visible 1px borders on every `<th>`/`<td>` in markdown tables, and you cannot suppress them — `style="border:none"` is stripped. You will see grey cell borders. There is no way around this with content-only markup; the alternative (no table) is the flag-stacked-above-text problem.

GitHub strips inline `<img>` from anchor slugs, so `## English 🇬🇧` produces the slug `english-` (trailing dash from the stripped emoji), and `## English <img ...>` produces `english`. Update anchor links in the same change as you change heading flags.

### 9. The shields.io named-logo set is not stable

`?logo=NAME` on shields.io looks up `NAME` in their internal named-logos list. That list is not the same as simple-icons.org's full set, and shields.io periodically removes logos (notably `linkedin` as of mid-2026). When a logo is missing, shields.io silently returns the badge without it - no error, no warning, just no icon. Verify by curling the badge SVG and checking for `<image>`:

```bash
curl -s "https://img.shields.io/badge/X-Y-blue?logo=NAME" | grep -c '<image'
# 1 = logo embedded; 0 = NAME not in shields.io's named-logos list
```

If the logo is missing, options:
1. Drop the `?logo=` param and use a clean text badge.
2. Use a different badge generator (`custom-icon-badges.demolab.com` covers some that shields.io dropped, but its icon names are also non-portable).
3. Use a separate `<img>` with the icon next to the badge.

Inline `<svg>` is **not** an option — GitHub's sanitizer strips `<svg>` from markdown content entirely.

## What we tested but did NOT use

- **`<bdi>`** — works in real browsers but GitHub's CSP/sanitizer strips it from rendered Markdown.
- **`text-align: right` via inline `style=""`** — GitHub's sanitizer drops `style` attributes on most elements.
- **CSS isolation directives in code blocks** — irrelevant; we wanted *display* RTL, not character-level isolation.
- **Unicode RLM (U+200F) at line starts** — works but invisible in source, so it confused future-us reading the diff. We use it programmatically inside the `kivun-claude-bidi` wrapper (terminal output) but not in human-edited Markdown.
- **Inline `<svg>` for flag icons** — stripped by GitHub's sanitizer.
- **`<picture>` wrapper to override img display** — the inner `<img>` still gets `display: block` from GitHub's CSS injection.
- **`align="absmiddle"` / `valign="middle"` on `<img>`** — deprecated HTML4 attributes, stripped by GitHub.
- **`style="border:none"` on `<table>`/`<td>`** — GitHub strips `style` from table elements; cell borders persist.

## Quick checklist when adding Hebrew to a README

1. Section wrapped in `<div dir="rtl">` with blank lines inside? ✅
2. Any bullet lists in that section converted to `<ul dir="rtl">`? ✅
3. Any blockquotes converted to `<blockquote dir="rtl">`? ✅
4. Any `→` arrows in Hebrew prose flipped to `←`? ✅
5. Code, paths, commands left in English? ✅
6. Em-dashes replaced with hyphens? ✅
7. Lines that opened with English content reordered or wrapped in `<p dir="rtl">`? ✅
8. Country flags rendered via PNG `<img>` inside a `<table>` (not via regional-indicator emojis, not in a `<p>` — Windows shows emojis as letter pairs, and `<p>`-based layout stacks the flag above text)? ✅
9. shields.io `?logo=` params verified by curling the SVG and checking for `<image>` (the named-logo list is not stable; if missing, drop the `?logo=`)? ✅

If a section still renders LTR after all of the above, the next debugging step is "view the rendered HTML on github.com, find the element with the wrong direction, see what wrapper is needed." It is almost always a markdown-to-HTML construct that didn't inherit the parent direction.

## See also

- [Anthropic Claude Code BiDi tracking issue](https://github.com/anthropics/claude-code/issues/39881) — the upstream bug this whole project works around.
- [`docs/specs/BIDI_ALGORITHM.md`](specs/BIDI_ALGORITHM.md) — the algorithm Kivun Terminal's `kivun-claude-bidi` wrapper uses for terminal-output BiDi (different problem from Markdown rendering, same root cause: no direction metadata in the source).
