![Kivun Terminal Demo](https://raw.githubusercontent.com/noambrand/kivun-terminal-wsl/main/Kivun_Terminal_v1.4.13.gif)

# Kivun Terminal v1.4.14

**Claude Code on Windows with real right‑to‑left (RTL) support.** Hebrew, Arabic, Persian, Urdu and 8 more RTL languages render correctly inside a Linux Konsole (WSL2 + Ubuntu) — something Windows Terminal cannot do.

---

## ✨ What's new in v1.4.14 — picker always opens on Opus

The folder picker now always defaults to **Opus** when it opens, regardless of which model you used in the previous session.

Previously, if you launched a session with Sonnet, the Default profile would remember Sonnet and silently show it as selected the next time the picker opened — even though you never asked for Sonnet to be the permanent default. This release fixes that.

**What changed:**
- The **Default profile** no longer persists the model. Every time you open the picker it starts on Opus.
- If you want a different model for a session, select it in the picker before launching — it will apply to that session only (Default profile always resets to Opus on next open).
- **Named project profiles** are unaffected. If you've saved a project profile with Sonnet or Haiku, switching to that profile still loads that model.

**In short:** Opus is always the starting point. Only an explicit, active choice changes it.

---

## Download

**Windows installer:** `Kivun_Terminal_Setup.exe` below.

**Linux users:** download **`kivun-terminal-linux-1.4.14.tar.gz`** (apt/dnf/pacman/zypper supported).

---

## Full feature list (unchanged from v1.4.13)

| Feature | Details |
|---|---|
| **RTL / BiDi rendering** | Hebrew, Arabic, Persian, Urdu, and 8 more — rendered correctly |
| **Multi‑project tabs** | Each project in its own tab, named by folder |
| **Picker default: Opus** | New in v1.4.14 — picker always opens on Opus |
| **Language flags** | 11 RTL languages via `RESPONSE_LANGUAGE` in config.txt |
| **Status bar** | Model, context %, session + weekly usage at a glance |
| **Linux support** | apt/dnf/pacman/zypper tarball |
