# Kivun Terminal — fonts and BiDi rendering

Reference notes on which monospace fonts work well for Hebrew + Latin terminal
output inside Konsole, why the current default produces a "Latin looks bold"
optical effect on some screens, and what the candidate replacements look like.

This doc is informational. No font change is committed yet — the picker UI
and install-time font-package selection are open questions captured at the
bottom.

## Current default

The shipped Konsole profile pins **Miriam Mono CLM** at size 12, with
**FreeMono** as the fallback used only when Miriam Mono CLM is not installed:

```
Font=Miriam Mono CLM,12,-1,5,50,0,0,0,0,0
```

Miriam Mono CLM (from the Culmus project) is a Hebrew-first monospace whose
Hebrew glyphs fill the cell tightly, with none of the split-apart gaps that
proportional fonts (Noto Sans Hebrew, Heebo, Rubik, Assistant) show once
Konsole locks every glyph to a fixed cell. The previous default,
`DejaVu Sans Mono`, rendered Hebrew with wide gaps on a clean machine.

The font is **not hard-coded**. Each profile writer picks it at write time:

```sh
if fc-list 2>/dev/null | grep -qiE "miriam *mono *clm"; then
    KIVUN_FONT="Miriam Mono CLM"   # installed via fonts-culmus
else
    KIVUN_FONT="FreeMono"          # always present via fonts-freefont-ttf
fi
```

So if the Culmus install fails, the profile cleanly falls back to FreeMono,
and a later `fonts-culmus` install upgrades the font on the next launch. The
generic `monospace` is Konsole's own last resort if neither font exists.

This selection is written in three places, all to the same Konsole profile
at `~/.local/share/konsole/KivunTerminal.profile`:

| File | Purpose |
|---|---|
| `linux/install.sh` | Written on first install |
| `linux/kivun-launch.sh` | Re-written at launch (Linux path) |
| `payload/kivun-launch.sh` | Re-written at launch inside the Windows installer payload |

The installer installs `fonts-culmus` (Miriam Mono CLM), `fonts-freefont-ttf`
(FreeMono fallback), and `fonts-noto-color-emoji`.

## Why English in mixed Hebrew/English lines can look "bold"

Konsole picks a glyph from the primary monospace font for each Latin
codepoint and from the fallback chain for each Hebrew/Arabic codepoint
(or vice-versa, depending on which family has which coverage). When the
two families have different stroke weights, the eye reads the heavier one
as bold even though no SGR-bold escape is set.

Two common patterns:

1. **Primary has Latin only, Hebrew comes from a fallback.** Latin looks
   normal; Hebrew looks thin → user reads Latin as "bolder than the Hebrew".
2. **Primary has Hebrew, Latin comes from a fallback.** Hebrew looks
   normal; Latin looks fat → user reads Latin as "bold".

DejaVu Sans Mono's Hebrew glyphs are noticeably lighter-stroked than its
Latin glyphs (the Hebrew was contributed years after the Latin, by a
different designer). On a screen full of mixed Hebrew + English code
identifiers, the Latin reads as "bolder" by contrast — this matches the
DejaVu default.

### How to confirm which pattern is happening

In WSL:

```bash
fc-match -s monospace:lang=he | head -5
fc-match -s monospace:lang=en | head -5
```

Different first hit between the two lists = mismatched fallback = the
perceived-bold problem. A real SGR-bold escape would affect Hebrew on the
same line too; if **only Latin** looks heavy, it is fallback, not SGR.

## Candidate replacements

Curated to fonts tested in Konsole 23.x for (a) monospace cell alignment,
(b) correct cursor positioning across Hebrew runs, (c) matched stroke
weights between scripts.

| Font | Latin | Hebrew | Arabic shaping | Notes |
|---|---|---|---|---|
| **FreeMono** (current default) | ✓ | ✓ (tight) | partial | Ships via `fonts-freefont-ttf`; Hebrew fills the cell, no gaps |
| **Cascadia Mono** ≥ 2404 | ✓ | ✓ | partial | Microsoft, ships with Windows Terminal; matched stroke weights — strong "safe default" for mixed Hebrew/Latin |
| **Liberation Mono** | ✓ | ✓ | partial | Usually already installed; Courier-like Latin, decent Hebrew |
| **DejaVu Sans Mono** (old default — avoid for Hebrew) | ✓ | ✓ (gappy) | partial | Hebrew letters narrow in the cell → words look split apart |
| **Noto Sans Mono** + Noto Sans Hebrew/Arabic | ✓ | via fallback | ✓ | Google's "designed to coexist" pair; Hebrew can look gappy in mono |
| **Iosevka Term** | ✓ | ✓ | ✗ | Configurable weights, narrow cell, good for small font sizes |
| **Miriam Mono CLM** | ✓ | ✓ (best Hebrew) | ✗ | Hebrew-first design, plainer Latin — `sudo apt install fonts-culmus` |
| **Hack** | ✓ | via fallback | ✗ | Popular; needs explicit Hebrew fallback configured |

Trap fonts: anything proportional masquerading as monospace (Arial Hebrew,
David), and "Arabic monospace" fonts that drop contextual shaping — they
render but BiDi cell alignment breaks.

## Suggested fallback stacks

Listed for reference. Konsole reads `Font=` as a single family; the actual
fallback chain is resolved by Fontconfig (`~/.config/fontconfig/fonts.conf`).
A balanced chain to set in a user override:

```xml
<alias>
  <family>monospace</family>
  <prefer>
    <family>Cascadia Mono</family>
    <family>Miriam Mono CLM</family>
    <family>Noto Sans Arabic</family>
    <family>DejaVu Sans Mono</family>
  </prefer>
</alias>
```

Stricter dev-focused (no Arabic):

```xml
<alias>
  <family>monospace</family>
  <prefer>
    <family>JetBrains Mono</family>
    <family>Miriam Mono CLM</family>
    <family>DejaVu Sans Mono</family>
  </prefer>
</alias>
```

## How to change the font manually today

No picker UI yet. Two paths:

### A. Edit the Konsole profile in place

```bash
sed -i 's/^Font=.*/Font=Cascadia Mono,11,-1,5,50,0,0,0,0,0/' \
    ~/.local/share/konsole/KivunTerminal.profile
```

Then relaunch. If the chosen font is not installed, install it first
(`fonts-cascadia-code`, `fonts-jetbrains-mono`, `fonts-noto-mono`, etc.
package names vary by distro).

### B. Add a Fontconfig user override

Drop a file at `~/.config/fontconfig/conf.d/99-kivun.conf` containing one of
the `<alias>` blocks above and run `fc-cache -f`. This affects every app
that resolves `monospace`, not just Kivun.

## Open questions (decide later)

These are deferred — captured here so they are not lost.

1. **Default change.** Switch the shipped default from DejaVu Sans Mono to
   Cascadia Mono (or JetBrains Mono)? Pro: removes the perceived-bold
   effect for most users. Con: needs `fonts-cascadia-code` installed on
   Linux, and that package only exists on Ubuntu 24.04+ / Debian 13+ — older
   distros need a manual download or fallback to DejaVu.
2. **Picker UI.** Add a font dropdown to `payload/folder-picker.hta` with
   a curated allowlist? Smallest version: two presets ("Balanced (Cascadia
   Mono)" / "Hebrew-first (DejaVu Sans Mono)"). Larger version: full
   `fc-list` filter against an allowlist file with detection of which
   are actually installed.
3. **Install-time font package.** Have `linux/install.sh` install
   `fonts-cascadia-code` (or `fonts-jetbrains-mono`, `fonts-noto-mono`)
   automatically? Adds ~5–10 MB to install size; removes the "font not
   found, falls back to something worse" surprise.
4. **Diagnostic command.** Add `kivun-fonts` (or `kivun-optimizer fonts`)
   that prints the `fc-match` chain for `he` and `en` and flags mismatch?
   Cheap, self-contained, and answers "why does my Hebrew look weird" in
   one command.
5. **Allowlist maintenance.** Any curated font allowlist will rot without
   a regression check. Either accept that the list is a "tested as of vX.Y"
   snapshot or set up a screenshot-diff harness against Konsole rendering.
