**Typing Hebrew in the Claude prompt is clean again — plus a snappier keyboard and an honest color message.** ⌨️🔤🎨

### Typing Hebrew no longer corrupts the line

The headline fix. Typing and editing Hebrew in the Claude prompt could paint a
growing run of spaces over the top banner, leave the cursor sitting one character
off from where you were typing, and stop Backspace from visibly deleting.

The cause was found by recording the real keystrokes and replaying them, not by
guessing: Claude redraws the whole screen on every keystroke and jumps to the
input box with a cursor move, and Kivun's Hebrew wrapper mistook that jump for
real spacing between words. Two targeted fixes make the input box a byte-exact
pass-through, so:

- Letters no longer overwrite each other and the top banner stays put.
- The cursor sits exactly where you type.
- Backspace and the arrow keys edit normally.

The Hebrew shaping of Claude's **output** is untouched — only the editable prompt
line was corrected.

### The keyboard toggle wakes up immediately after a cold start

Right after opening Kivun, the Alt+Shift language toggle could do nothing for up
to about a minute, then start working. Kivun now keeps a light watch through
Claude's startup and re-arms the keyboard only if it was actually dropped, so
Alt+Shift switches Hebrew/English on the **first** press. The toggle stays
**Alt+Shift**, exactly like Windows.

### An honest message when you change the terminal color

Changing the color in the folder picker's **Advanced options** now tells you the
truth: **close all Kivun windows and reopen** to see the new color. A new tab in
the same window keeps the old color because Konsole remembers its color per
window, so the previous "open a new tab to see it" wording could not deliver.
Your choice is still saved right away and shows on the next fresh window.

### Updating

Install v1.6.3 over your current version. Your `config.txt` and settings are
kept. Nothing to configure.
