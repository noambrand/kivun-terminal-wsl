**Hebrew font fix: Miriam Mono CLM now really installs.** 🔤

v1.4.34 made **Miriam Mono CLM** the default terminal font, but on a fresh
Ubuntu/WSL machine it never actually got installed, and the terminal quietly
fell back to **FreeMono**. Some users also saw a **"Failed to install x11-utils
(code 100)"** popup during setup. Both had the **same** cause.

**What went wrong.** The installer asked apt for a package called
`fonts-culmus`. That name exists on Debian, but on **Ubuntu** (what WSL runs)
the Culmus fonts ship as **`culmus`**. Because the font was requested on the
*same* line as `x11-utils`, the unknown name made apt abort the whole step with
code 100, and the Hebrew font was silently skipped.

**The fix.** The Hebrew font now installs in its own step, tries both package
names (`culmus`, then `fonts-culmus`), and is best-effort: if it cannot install,
FreeMono still renders Hebrew correctly, with no scary error dialog and no
aborted setup.

**Already on v1.4.34?** You do not need to reinstall. Run this once in Ubuntu,
then reopen Kivun Terminal:

```
sudo apt-get install -y culmus
```

The launcher re-checks your fonts on every start, so it switches to Miriam Mono
CLM automatically once Culmus is present.
