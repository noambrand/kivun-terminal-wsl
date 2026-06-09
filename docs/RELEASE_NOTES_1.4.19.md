<p align="center">
  <img src="https://github.com/noambrand/kivun-terminal-wsl/releases/download/v1.4.19/Kivun_Terminal_v1.4.13.gif" width="700" alt="Kivun Terminal demo — Hebrew RTL Claude Code session">
</p>

# Kivun Terminal — Claude Code with real right‑to‑left (Hebrew / Arabic) support

Run **Claude Code** in a terminal that displays **Hebrew, Arabic, Persian, Urdu** and other right‑to‑left languages correctly — on **Windows** (via WSL) and **Linux**.

## ⬇️ Install on Windows — 3 steps

1. Download **`Kivun_Terminal_Setup.exe`** below.
2. Double‑click it. No admin needed — it installs just for you.
3. If Windows Subsystem for Linux isn’t set up yet, the installer **offers to install it for you** (one approval prompt), then asks you to restart. Run the installer once more after the restart — that’s it.

Launch **Kivun Terminal** from your desktop and start chatting with Claude. 🎉

> 📹 Prefer to watch first? **[Play the demo video (MP4)](https://github.com/noambrand/kivun-terminal-wsl/releases/download/v1.4.19/Kivun_Terminal_v1.4.13.mp4)**

## ✨ What you get
- Real RTL / bidirectional text for **11 languages** (Hebrew, Arabic, Persian, Urdu, and more)
- A calm **light‑blue terminal theme**
- **Desktop shortcut** + right‑click **“Open with Kivun Terminal”** on any folder
- Claude Code, Node.js and everything it needs — **installed for you**

## 🐧 Linux
Download `kivun-terminal-linux-1.4.19.tar.gz` below, extract, and run `./install.sh`.

## First time with Claude?
You’ll need a Claude Pro/Max subscription or an Anthropic API key — Claude asks for it on first launch. Get one at <https://console.anthropic.com/>.

---

## What’s new in v1.4.19
Clearer help when a PC just needs one quick setting turned on:

- **If the installer keeps asking you to restart, it now tells you why.** WSL runs Linux inside a small virtual machine, and some PCs ship with **“virtualization” turned off** in their startup settings (BIOS/UEFI) — so that virtual machine can never start. Instead of looping, the installer now **detects this and shows simple, step‑by‑step instructions** for turning virtualization on. It’s a one‑time, ~2‑minute change that only you can make (no app is allowed to change a firmware setting). After that, just run the installer again and it continues on its own.
- **Correct version shown.** The installer window now displays the right version number (recent builds mistakenly showed v1.4.15).

See the [full changelog](https://github.com/noambrand/kivun-terminal-wsl/blob/main/docs/CHANGELOG.md) for technical details.
