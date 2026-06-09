<p align="center">
  <img src="https://github.com/noambrand/kivun-terminal-wsl/releases/download/v1.4.20/Kivun_Terminal_v1.4.13.gif" width="700" alt="Kivun Terminal demo — Hebrew RTL Claude Code session">
</p>

# Kivun Terminal — Claude Code with real right‑to‑left (Hebrew / Arabic) support

Run **Claude Code** in a terminal that displays **Hebrew, Arabic, Persian, Urdu** and other right‑to‑left languages correctly — on **Windows** (via WSL) and **Linux**.

## ⬇️ Install on Windows — 3 steps

1. Download **`Kivun_Terminal_Setup.exe`** below.
2. Double‑click it. No admin needed — it installs just for you.
3. If Windows Subsystem for Linux isn’t set up yet, the installer **offers to install it for you** (one approval prompt), then asks you to restart. Run the installer once more after the restart — that’s it.

Launch **Kivun Terminal** from your desktop and start chatting with Claude. 🎉

> 📹 Prefer to watch first? **[Play the demo video (MP4)](https://github.com/noambrand/kivun-terminal-wsl/releases/download/v1.4.20/Kivun_Terminal_v1.4.13.mp4)**

## ✨ What you get
- Real RTL / bidirectional text for **11 languages** (Hebrew, Arabic, Persian, Urdu, and more)
- A calm **light‑blue terminal theme**
- **Desktop shortcut** + right‑click **“Open with Kivun Terminal”** on any folder
- Claude Code, Node.js and everything it needs — **installed for you**

## 🐧 Linux
Download `kivun-terminal-linux-1.4.20.tar.gz` below, extract, and run `./install.sh`.

## First time with Claude?
You’ll need a Claude Pro/Max subscription or an Anthropic API key — Claude asks for it on first launch. Get one at <https://console.anthropic.com/>.

---

## What’s new in v1.4.20
Building on v1.4.19’s “turn on virtualization” help, the steps are now **tailored to your PC maker** so you don’t have to guess which key opens BIOS:

- **Dell / ASUS / Acer** → press **F2** as the PC powers on
- **Lenovo** → **F1**, **F2**, or the small **Novo** button
- **HP** → **Esc**, then **F10**
- **Other / desktops** → **Del** (or F2)

…then enable **“Intel Virtual Technology” / “VT‑x”** (or **“SVM Mode”** on AMD), save (usually **F10**), and run the installer again — it continues on its own. (Reminder: WSL runs Linux inside a virtual machine, so this one‑time switch is required for the WSL version. The plain‑Windows version needs none of it.)

See the [full changelog](https://github.com/noambrand/kivun-terminal-wsl/blob/main/docs/CHANGELOG.md) for technical details.
