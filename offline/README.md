# Installing Kivun Terminal on a locked-down PC (offline / antivirus-safe)

**Most PCs don't need this.** Just run `Kivun_Terminal_Setup.exe`; if WSL isn't set
up, follow its prompt and Windows downloads WSL2 + Ubuntu for you.

**Use this only if the normal install can't download WSL** — e.g. corporate
antivirus (we've seen **McAfee Web Protection** do exactly this) blocks the large WSL
download, or the PC has no internet / no Microsoft Store. This path installs WSL2 +
Ubuntu from **official files you place on the PC**, using only built-in,
Microsoft-signed tools (`dism`, `msiexec`, `wsl --install --from-file`) — **no
PowerShell, no Store, no downloads during install — so antivirus has nothing to
block.** It's the one method proven to work on a fully locked-down PC.

## 1. Download the two official files (on any PC with internet)

| File | Official source |
|------|-----------------|
| **WSL runtime** — `wsl.<version>.x64.msi` | <https://github.com/microsoft/WSL/releases> &nbsp;(latest, e.g. `wsl.2.7.8.0.x64.msi`) |
| **Ubuntu 24.04** — `ubuntu-24.04.<n>-wsl-amd64.wsl` | <https://releases.ubuntu.com/noble/> &nbsp;(e.g. `ubuntu-24.04.4-wsl-amd64.wsl`) |

Both are published and signed by **Microsoft** and **Canonical**. Nothing here is
repackaged — you get them straight from the vendors.

## 2. Put them next to `offline-install.cmd`

`offline-install.cmd` ships with Kivun (it's in your install folder,
`%LOCALAPPDATA%\Kivun-WSL\`, and here in the repo). Copy it and the two files above
into **one folder**. A **USB stick** is fine if the target PC has no internet.

## 3. Run it as administrator

Right-click **`offline-install.cmd`** → **Run as administrator**. It will:

0. Check hardware **virtualization** is on in BIOS/UEFI (WSL2 can't boot otherwise — it shows you exactly how to enable it, per PC maker).
1. Enable the WSL Windows features with **DISM** (local, no download).
2. Install the WSL runtime from the **Microsoft-signed MSI** (`msiexec`).
3. If it says **reboot required** → reboot and run it again (it resumes automatically).
4. Import **Ubuntu** from the official image (`wsl --install --from-file`).
5. Verify.

## 4. Finish

Run **`Kivun_Terminal_Setup.exe`**. With WSL + Ubuntu now present, it sets up Claude
**inside** Ubuntu (those downloads happen on WSL's own network, which corporate web
filters generally don't inspect) and creates the desktop shortcut.

---

### Why this is needed
The normal installer uses Microsoft's online `wsl --install`. On a PC whose antivirus
blocks large binary downloads, that can't complete. Installing from local files with
DISM + a signed MSI is the reliable fallback — and because every tool is native and
signed, the antivirus doesn't flag it. **Never disable your antivirus to install
Kivun; use this offline path instead.**
