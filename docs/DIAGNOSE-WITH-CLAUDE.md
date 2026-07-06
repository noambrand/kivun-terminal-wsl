# כיוון נתקע או לא נפתח? תנו את הקובץ הזה ל-Claude Code — הוא יאבחן בשבילכם

**מה זה:** אם ההתקנה של Kivun Terminal לא הסתיימה, החלון לא נפתח, או שזה "נתקע" —
אתם לא צריכים לשלוח לוגים ידנית. פשוט פתחו את Claude Code שרץ אצלכם על המחשב,
והדביקו לו את כל הטקסט שמתחת לקו `--- For Claude Code ---`. Claude יאסוף את הלוגים,
יבדוק את מצב WSL, ויגיד לכם בשפה פשוטה מה הבעיה ומה הצעד הבא. אפשר גם לבקש ממנו
לכתוב סיכום קצר לשלוח בחזרה (למייל **noambbb@gmail.com**).

**קודם כול — שאלה אחת שפותרת את רוב המקרים:** האם עשיתם **הפעלה מחדש (Restart)**
למחשב מאז ההתקנה? WSL (מנוע הלינוקס של Windows) מסיים להידלק רק אחרי Restart אחד.
אם עוד לא הפעלתם מחדש — עשו Restart ונסו שוב; לרוב זה מסיר את ה"נתקע".

---
--- For Claude Code ---

You are running on the Windows PC where **Kivun Terminal** failed, and the user wants
you to diagnose it. Kivun is a one-click installer that runs Claude Code inside
**WSL2 + Ubuntu + Konsole** so Hebrew/RTL renders correctly. Two symptoms were reported:

1. After install, **no "please restart Windows" prompt appeared**.
2. Launching Kivun **got stuck ~6 times** — the terminal window never appeared, or it hung.

Your job: gather evidence (read-only first), then tell the user the single most likely
cause and the concrete next step, in plain language. Optionally write a short report they
can send back. Work through the steps and report what each one shows.

### Step 1 — Collect the logs (read-only)
Read and summarize any errors in these files (each may or may not exist yet):
- `%LOCALAPPDATA%\Kivun-WSL\LAUNCH_LOG.txt` — the Windows-side launcher
- `%LOCALAPPDATA%\Kivun-WSL\BASH_LAUNCH_LOG.txt` — the WSL/Konsole window (window problems live here)
- `%LOCALAPPDATA%\Kivun-WSL\install-log.txt` — the installer

Shortcut: there is a one-click collector at `%LOCALAPPDATA%\Kivun-WSL\kivun-diagnostics.cmd`
(also **Start Menu → "Kivun Diagnostics"**). It bundles all of the above into
`Kivun-Report.txt` on the Desktop — you can run it and read that one file instead.

### Step 2 — Check WSL + the reboot marker (this explains BOTH symptoms)
Run each and report the output:
- `wsl -l -v` → is **Ubuntu** installed, is it **VERSION 2**, and what STATE (Running / Stopped / Installing)?
- `wsl --status` → default distro and default version
- `wsl --version` → the WSL app version (a very old one often needs `wsl --update`)
- `reg query "HKCU\Software\Kivun-WSL" /v WslRebootPending`
  → if this value **exists / = 1**, WSL was just installed and **a restart is still pending**.
    That by itself explains a hang: until the user restarts, every `wsl` call waits forever
    (this is exactly the "stuck" symptom). The fix is a normal Windows restart, then relaunch.
- Was the installer run **as admin**? `wsl --install` needs admin. If Ubuntu is missing from
  `wsl -l -v`, a non-admin first run may have skipped the WSL install silently — which is also
  why **no restart was ever requested** (nothing was installed that needed one).

### Step 3 — WSL is installed but the WINDOW never appears (WSLg wedge)
- `wsl -d Ubuntu -- bash -lc 'echo DISPLAY=$DISPLAY'` — an empty value means WSLg isn't handing WSL a display.
- Optional live paint test: `wsl -d Ubuntu -- bash -lc 'command -v xeyes >/dev/null && (xeyes & sleep 3)'`
  If **nothing paints on screen**, WSLg is "wedged." Cure: close all windows, run `wsl --shutdown`,
  wait ~8 seconds, then relaunch Kivun (or use **Start Menu → "Repair Kivun Display"**).
  ⚠️ Ask the user before `wsl --shutdown` — it closes ALL their WSL sessions.

### Step 4 — WSL is missing entirely
If Ubuntu is not listed in `wsl -l -v`, WSL never installed. Likely causes:
- Not run as administrator, or corporate policy blocks `wsl --install`.
- **Virtualization disabled in BIOS/UEFI.** Check it:
  `systeminfo | findstr /i "Virtualization Hyper-V"` — or Task Manager → Performance → CPU →
  "Virtualization: Enabled." If it's disabled, it must be turned on in the PC's BIOS/UEFI;
  no app (including the installer) can change that setting.

### Step 5 — Verdict + (optional) a report to send back
Give the user a plain-language verdict: the single most likely cause — **pending restart /
WSLg wedge / WSL not installed / virtualization off / outdated WSL** — and the ONE next step.
If they want to send it to the developer, write a short summary to
`%USERPROFILE%\Desktop\Kivun-handoff.txt` containing: the outputs from Step 2, the top errors
from the Step 1 logs, the Windows build (`ver`), and your verdict. They email that file to
**noambbb@gmail.com**.

### Guardrails
- Steps 1, 2, 4 are read-only. Step 3's `wsl --shutdown` is the only state-changing command —
  confirm with the user first.
- Never restart the PC for the user; only tell them if a restart is the fix.
- Don't guess: base the verdict on what the logs and the `wsl` commands actually returned.
