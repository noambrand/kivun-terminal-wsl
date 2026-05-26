# Kivun Terminal v1.4.13

**Claude Code on Windows with real right‑to‑left (RTL) support.** Hebrew, Arabic, Persian, Urdu and 8 more RTL languages render correctly inside a Linux Konsole (WSL2 + Ubuntu) — something Windows Terminal cannot do.

---

## ✨ What's new in v1.4.13 — work on multiple projects at once

Until now, launching Kivun while a window was already open **closed the open one** and started fresh, so you could only work on one project at a time. That's fixed.

- **A second launch now opens a new TAB** in your existing Kivun window instead of closing it — so you can run several projects side by side.
- **Each tab is named by its project folder** (e.g. `gvSIG`, `my-app`) instead of every tab reading "Kivun Terminal".
- **Tabs open in the folder you picked** and keep the light‑blue Kivun theme.
- **Your open sessions are never closed.** If no existing window can be reused, a normal new window opens instead — nothing is ever killed.
- **New `KIVUN_TABBED` setting** in `config.txt` (default `on`). Set it to `off` if you'd rather get a separate window per launch.

> First launch after updating opens one window; from the **second launch onward** you'll get tabs. To start fresh, close any Kivun windows left over from the previous version, then launch again.

<details>
<summary>How it works (technical)</summary>

WSLg doesn't provide a D‑Bus *session* bus, and `konsole --new-tab` won't reliably attach to a running window under WSLg. So the launcher now runs a tiny reusable per‑user session bus and adds the tab through Konsole's D‑Bus API (`Window.newSession` with the profile **Name** + chosen directory, then `Session.runCommand`). It removes the old `pkill konsole` that was closing live windows, and falls back to a new window whenever no reachable Konsole is found.
</details>

---

## 📥 Install

1. Download **`Kivun_Terminal_Setup.exe`** below and run it.
2. The installer sets up WSL2 + Ubuntu (if needed), Konsole, Claude Code, and the desktop + right‑click integration.
3. Launch from the **Kivun Terminal** desktop shortcut, or right‑click any folder → **Open with Kivun Terminal**.

**Linux users:** download **`kivun-terminal-linux-1.4.13.tar.gz`** (apt/dnf/pacman/zypper supported).

### First run
You'll need a **Claude Pro/Max subscription** or an [Anthropic API key](https://console.anthropic.com). The first launch walks you through login.

---

## What Kivun Terminal does

| Feature | Details |
|---|---|
| **Real RTL rendering** | Hebrew, Arabic, Persian, Urdu, Pashto, Kurdish, Dari, Uyghur, Sindhi, Azerbaijani + more — type and read right‑to‑left normally |
| **BiDi wrapper** | Seven complementary fixes for Claude Code's RTL/bullet‑line direction bug ([claude-code#39881](https://github.com/anthropics/claude-code/issues/39881)) |
| **Multi‑project tabs** | New in v1.4.13 — each project in its own tab, named by folder |
| **Keyboard switching** | **Alt+Shift** toggles Hebrew ⇄ English layouts (with VcXsrv, the default) |
| **Folder picker** | Desktop shortcut opens a dialog to type/paste a path or browse the tree |
| **Statusline** | Active model, context %, and session/weekly usage limits |
| **Theme** | Custom light‑blue Konsole profile + color scheme |

### What gets installed
Ubuntu (WSL2) · Konsole · Claude Code (official installer) · the `kivun-claude-bidi` Node wrapper · the Kivun Konsole profile/theme · Explorer right‑click integration.

### Requirements
Windows 10/11 with WSL2 · ~2 GB for WSL + Ubuntu · a Claude Pro/Max subscription or Anthropic API key.

---

## Docs & help
- [Installation guide](https://github.com/noambrand/kivun-terminal-wsl/blob/main/docs/README_INSTALLATION.md)
- [Troubleshooting](https://github.com/noambrand/kivun-terminal-wsl/blob/main/docs/TROUBLESHOOTING.md)
- [Full changelog](https://github.com/noambrand/kivun-terminal-wsl/blob/main/docs/CHANGELOG.md)

> Don't need RTL? The LTR‑only sister project [ClaudeCode Launchpad CLI](https://github.com/noambrand/kivun-terminal) starts faster and needs no WSL.

---

MIT licensed.
