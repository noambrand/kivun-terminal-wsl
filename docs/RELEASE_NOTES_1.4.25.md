<p align="center">
  <img src="https://github.com/noambrand/kivun-terminal-wsl/releases/download/v1.4.25/Kivun_Terminal_v1.4.13.gif" width="700" alt="Kivun Terminal demo — Hebrew RTL Claude Code session">
</p>

# Kivun Terminal — Claude Code with real right‑to‑left (Hebrew / Arabic) support

Run **Claude Code** in a terminal that displays **Hebrew, Arabic, Persian, Urdu** and other right‑to‑left languages correctly — on **Windows** (via WSL) and **Linux**.

## ⬇️ Install on Windows — 3 steps

1. Download **`Kivun_Terminal_Setup.exe`** below.
2. Double‑click it. No admin needed — it installs just for you.
3. If Windows Subsystem for Linux isn’t set up yet, the installer **offers to install it for you** (one approval prompt), then asks you to restart. Run the installer once more after the restart — that’s it.

> 📹 Prefer to watch first? **[Play the demo video (MP4)](https://github.com/noambrand/kivun-terminal-wsl/releases/download/v1.4.25/Kivun_Terminal_v1.4.13.mp4)**

## 🏢 On a locked‑down work PC? (antivirus blocks the WSL download)
Some corporate antivirus blocks the large WSL download, so the normal install can’t finish. Use the **offline installer** — it needs no downloads and antivirus doesn’t flag it. See **[offline/README.md](https://github.com/noambrand/kivun-terminal-wsl/tree/main/offline)**: download two official files (Microsoft + Ubuntu), copy them next to `offline-install.cmd`, and run it as administrator.

## ✅ How to test it works
Launch **Kivun Terminal** from your desktop and send Claude a short message (Hebrew or English). Press **Alt+Shift** to switch the keyboard between English and Hebrew. 🎉

## 🆘 Something not working? Send a 1‑click report
Open **“Kivun Diagnostics”** from your Start menu — or, if the installer didn’t finish, download **`kivun-diagnostics.cmd`** from the Assets below and double‑click it. It saves **`Kivun-Report.txt`** to your Desktop. **Email it to noambbb@gmail.com** (or attach it to a [GitHub issue](https://github.com/noambrand/kivun-terminal-wsl/issues)). It only captures your Windows/WSL setup, **sends nothing automatically**, and needs **no admin**.

## ✨ What you get
- Real RTL / bidirectional text for **11 languages** (Hebrew, Arabic, Persian, Urdu, and more)
- **Alt+Shift** to switch keyboard between English and your language — opens in the language you’re already using
- A calm **light‑blue terminal theme**
- **Desktop shortcut** + right‑click **“Open with Kivun Terminal”** on any folder
- Claude Code, Node.js and everything it needs — **installed for you**

## 🐧 Linux
Download `kivun-terminal-linux-1.4.25.tar.gz` below, extract, and run `./install.sh`.

## First time with Claude?
You’ll need a Claude Pro/Max subscription or an Anthropic API key — Claude asks for it on first launch. Get one at <https://console.anthropic.com/>.

---

## What’s new in v1.4.25
- **Offline / antivirus‑safe install for locked‑down PCs.** If corporate antivirus blocks the WSL download (we confirmed McAfee Web Protection doing this), the normal `wsl --install` can’t finish. New **`offline-install.cmd`** installs WSL2 + Ubuntu from two official local files using only native, Microsoft‑signed tools (`dism`, `msiexec`, `wsl --install --from-file`) — no PowerShell, no Store, no downloads — so antivirus has nothing to block. The installer bundles it and its failure messages now point to it instead of dead‑ending.

See the [full changelog](https://github.com/noambrand/kivun-terminal-wsl/blob/main/docs/CHANGELOG.md) for technical details.
