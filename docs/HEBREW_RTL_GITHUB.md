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

### 8. Use real flag images, not regional-indicator emojis (🇬🇧 / 🇮🇱)

The two-character regional-indicator pairs (`🇬🇧` = U+1F1EC U+1F1E7, `🇮🇱` = U+1F1EE U+1F1F1) render as actual flags on Mac, Linux, iOS, and Android — but **Windows renders them as the literal letter pair** ("GB", "IL"). Microsoft's default emoji font has no flag glyphs, by design. Most readers of an open-source GitHub README are on Windows. Don't use these emojis where readers expect a flag.

Use a flag-image CDN instead. We use [flagcdn.com](https://flagcdn.com), which serves SVG/PNG flags by ISO country code:

```html
<!-- In a heading or paragraph -->
## English <img src="https://flagcdn.com/24x18/gb.png" alt="GB flag" width="24" height="18" align="absmiddle">

<!-- In a centered language pill at the top of the README -->
<p align="center">
  <a href="#english"><img src="https://flagcdn.com/24x18/gb.png" alt="GB flag" width="24" height="18" align="absmiddle"> <strong>English</strong></a>
</p>
```

GitHub strips inline `<img>` from anchor slugs, so a heading like `## English <img ...>` produces the slug `#english` (no trailing dash). Same heading with the emoji `## English 🇬🇧` would produce `#english-` (trailing dash from the stripped emoji-as-separator). If you migrate from emoji to image, update the anchor links in the same change.

The same applies to `:uk:` / `:israel:` shortcodes — GitHub renders those via Twemoji, but only inside `<p>` and list contexts, not always inside headings, and the reader's experience still depends on the renderer.

## What we tested but did NOT use

- **`<bdi>`** — works in real browsers but GitHub's CSP/sanitizer strips it from rendered Markdown.
- **`text-align: right` via inline `style=""`** — GitHub's sanitizer drops `style` attributes on most elements.
- **CSS isolation directives in code blocks** — irrelevant; we wanted *display* RTL, not character-level isolation.
- **Unicode RLM (U+200F) at line starts** — works but invisible in source, so it confused future-us reading the diff. We use it programmatically inside the `kivun-claude-bidi` wrapper (terminal output) but not in human-edited Markdown.

## Quick checklist when adding Hebrew to a README

1. Section wrapped in `<div dir="rtl">` with blank lines inside? ✅
2. Any bullet lists in that section converted to `<ul dir="rtl">`? ✅
3. Any blockquotes converted to `<blockquote dir="rtl">`? ✅
4. Any `→` arrows in Hebrew prose flipped to `←`? ✅
5. Code, paths, commands left in English? ✅
6. Em-dashes replaced with hyphens? ✅
7. Lines that opened with English content reordered or wrapped in `<p dir="rtl">`? ✅
8. Country flags rendered via `<img>` from a flag CDN, not via regional-indicator emojis (Windows shows those as letter pairs)? ✅

If a section still renders LTR after all of the above, the next debugging step is "view the rendered HTML on github.com, find the element with the wrong direction, see what wrapper is needed." It is almost always a markdown-to-HTML construct that didn't inherit the parent direction.

## See also

- [Anthropic Claude Code BiDi tracking issue](https://github.com/anthropics/claude-code/issues/39881) — the upstream bug this whole project works around.
- [`docs/specs/BIDI_ALGORITHM.md`](specs/BIDI_ALGORITHM.md) — the algorithm Kivun Terminal's `kivun-claude-bidi` wrapper uses for terminal-output BiDi (different problem from Markdown rendering, same root cause: no direction metadata in the source).
