**Product:** Claude Code CLI / TUI
**Version tested:** 2.1.71
**Category:** Internationalization / rendering / terminal UX
**Languages affected:** Hebrew, Arabic, Persian, Urdu, Kurdish, Pashto, Sindhi, Yiddish, Dari, Dhivehi, Uyghur, Balochi, Kashmiri, Syriac, Mandaic, Samaritan Hebrew, N'Ko, Adlam, Shahmukhi, Turoyo, Southern Azerbaijani, Jawi, and any right-to-left (RTL) or BiDi-mixed content.

---

## Summary

Claude Code prepends every assistant message with a fixed bullet character - `●` on Linux/Windows, `⏺` on macOS - as a visual indicator. Because this bullet is placed at the **logical start** of each assistant-message line, it becomes the first character a BiDi-capable terminal sees on that line. Per the Unicode Bidirectional Algorithm (UAX #9, rule P2), this bullet is a neutral character, and a strictly-compliant implementation should skip past it to find the first strong directional character (Hebrew/Arabic → R) and set the paragraph direction accordingly (RTL).

In practice, every terminal emulator tested (Konsole 24.x, GNOME Terminal, Windows Terminal) looks at the first *non-whitespace* character rather than the first *strong* character, picks LTR, and renders the entire line left-to-right - even when the remainder of the line is Hebrew or Arabic. The result: Claude's RTL replies visually look broken on line 1.

Requesting a first-class, upstream fix so RTL-language users get correct rendering without downstream hacks.

---

## Why this matters

- The RTL developer community (Hebrew, Arabic, Persian, Urdu, and others) is growing. Claude Code is increasingly used in Israel, the Gulf, Iran, Pakistan, and elsewhere where RTL is the norm for local content.
- RTL content flowing through a developer terminal includes error messages, documentation quotes, user-facing string literals, and localized content the developer is iterating on. Wrong rendering makes review hard and screen-reading impossible.
- The problem only exists because Claude Code decorates output. A raw text stream wouldn't trigger it - it's specifically the assistant-message indicator that breaks BiDi detection on every terminal.
- Third-party workarounds are not clean: patching `cli.js` locally gets overwritten by auto-update and trips antivirus supply-chain heuristics; teaching Claude via `--append-system-prompt` to format differently isn't reliable (Claude treats formatting hints as soft suggestions and ignores them on roughly half of replies).

---

## Reproduction

1. Install Claude Code 2.1.71 on Linux (e.g. WSL2 Ubuntu 24.04 with Konsole 22.04+).
2. Configure a system prompt: `Always respond in Hebrew.`
3. Ask Claude anything in Hebrew, e.g. `שלום, מה שלומך?`
4. Observe the response. First line renders: `● שלום! אני כאן לעזור לך...` - left-aligned, `●` visible on the left edge, Hebrew flows left-to-right from there.
5. Expected: the line should be right-aligned because its strong-directional content is Hebrew. Line 2+ (which have no `●` prefix) *do* render correctly right-aligned, proving the terminal BiDi engine itself works - only the `●`-prefixed line 1 is broken.

A raw terminal test without Claude Code confirms this is purely a Claude-Code-decoration issue: `printf '\u05e9\u05dc\u05d5\u05dd\n'` renders right-aligned; `printf '\u25cf \u05e9\u05dc\u05d5\u05dd\n'` renders left-aligned.

---

## Root cause

`cli.js` (minified) contains:
```js
B9 = YA.platform === "darwin" ? "⏺" : "●";
```
…and uses `B9` as the assistant-message prefix. Both characters have Unicode BiDi category `ON` (Other Neutral) or `So` (Symbol, Other). Per UAX #9 P2, neutrals should be skipped when determining paragraph direction, but most terminal implementations take a simpler "first visible character wins" approach. Since Anthropic can't change terminal implementations, the fix has to come from Claude Code.

---

## Proposed fix - two options

### Option A (recommended): make the indicator BiDi-aware

Prepend a strong-RTL marker to RTL-language responses, or wrap the indicator in a direction-override:

```js
// pseudo
const bullet = isDarwin ? "⏺" : "●";
const isRtlLocale = detectRtlFromResponseContent(responseText); // or from user prefs
const prefix = isRtlLocale ? `${bullet}\u200F` : bullet;        // U+200F = RLM
```

This preserves the bullet visually but makes the line start with a strong-RTL directional character for BiDi purposes. Paragraph direction resolves to RTL. Terminal renders right-aligned. Works in every compliant BiDi terminal.

Detection can be heuristic (check if first 50 characters of the response contain `\p{sc=Hebrew}`, `\p{sc=Arabic}`, etc.) or explicit (new setting / env var).

### Option B: add a settings knob to hide the indicator

```json
{
  "assistantIndicator": {
    "enabled": true,
    "character": "●",
    "hidden": false
  }
}
```

Users can opt-out of the bullet entirely. No BiDi work required; the line starts with response content directly, and terminals correctly auto-detect direction.

Either option is fine - A is smarter, B is simpler.

---

## What users currently do as a workaround (and why it's bad)

1. **Patching `cli.js` post-install** - works until the next auto-update. Also triggers Windows SmartScreen / Endpoint Protection heuristics because it modifies a signed npm package. Not shippable in any installer.
2. **System prompt telling Claude to start with a blank/non-Hebrew line** - unreliable; Claude ignores the instruction on roughly half of replies. Wastes tokens on every turn.
3. **Using a different BiDi-stronger terminal (mlterm, Ptyxis)** - solves this specific issue but those terminals have their own UX regressions and aren't feasible to mandate for a general audience.

---

Happy to provide reproduction screenshots, full terminal BiDi traces, or a patched `cli.js` demonstrating option A if that helps.
