**No more black window flash.** 🎉

Until now, starting Kivun Terminal briefly flashed a black command window,
and a minimized console sat on your taskbar for the whole session. Both are
gone: the desktop shortcut and the right-click "Open with Kivun Terminal"
now go through a new native launcher (`KivunTerminal.exe`) that does its
work in a completely invisible window. Konsole is the only thing you see.

**Nothing else changed about how launches work.** The same launcher logic
runs underneath — folder picker, automatic Claude install, all of it. If
something does go wrong, you now get a clear error popup with the last
lines of the launch log instead of a vanishing console.

**If your antivirus complains:** the new launcher is a small unsigned
program, and some antivirus tools are suspicious of those. If it gets
blocked or quarantined, use the **"Kivun Terminal (console)"** shortcut in
the Start menu — it launches exactly the same way the previous versions
did, with a visible console. (See TROUBLESHOOTING.md for details.)

Credit: this feature continues [PR #83](https://github.com/noambrand/kivun-terminal-wsl/pull/83)
by **@zuwasi** — thanks for pushing the no-flash idea forward.
