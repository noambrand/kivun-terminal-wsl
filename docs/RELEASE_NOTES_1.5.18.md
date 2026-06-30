**Alt+Shift now switches on your very first press.** ⌨️

After v1.5.17 made Kivun cycle the right keyboard languages, a smaller annoyance
remained: on a freshly opened window you sometimes had to press **Alt+Shift** a
few times before Hebrew/English actually switched, then it worked. It felt random.

**What went wrong.** Your launch log pinned it exactly. The keyboard layout is
set up *before* the terminal window exists. WSLg then **drops that setup the
moment the new window grabs focus** — a known WSLg behavior. Kivun re-applies the
layout to fix this, but the re-apply **waited a fixed 2 seconds before its first
try**. That left a roughly 2-second gap, right when the window appears and you can
already type, where Alt+Shift did nothing. Whether you hit the gap depended only
on how fast you reached for the key, so it seemed inconsistent.

**The fix.** Kivun now re-arms the keyboard **the instant the window is ready**,
with no wait, so your first Alt+Shift switches. It re-applies **only if** WSLg
drops the layout again (re-applying would reset you to English, so it will not do
that while you are typing), and it keeps a brief watch so a slow cold start cannot
leave it half-armed. Confirmed live on a clean `wsl --shutdown` start.

**Already on v1.5.17?** Just update to v1.5.18 and reopen Kivun, nothing to
configure. The language list and the startup timing are both correct now.
