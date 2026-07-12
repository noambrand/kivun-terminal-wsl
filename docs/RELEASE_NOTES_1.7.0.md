# Kivun Terminal 1.7.0 — Auto-continue after the limit resets

## What's new

When Claude Code hits the 5-hour usage limit, your session does not close — it
just waits, idle, until you come back and type something. **Kivun 1.7.0 can do
that waiting for you.**

Turn on the new **Auto-continue** setting and Kivun will:

1. Notice when the 5-hour limit is reached.
2. Wait until the limit's real reset time has passed.
3. Type **`continue`** once, so your work picks up where it left off — even if
   you stepped away.

It is **off by default**. Nothing changes unless you switch it on.

## How to turn it on

Open your Kivun **config.txt** and set:

```
AUTO_CONTINUE=true
```

That is the only change most people need. There are three optional safety knobs
right next to it:

- `AUTO_CONTINUE_MAX=5` — the most times it will auto-resume in one session
  before it stops on its own.
- `AUTO_CONTINUE_QUIET=` — a quiet window in your local time, e.g.
  `AUTO_CONTINUE_QUIET=23:00-07:00`, during which it never types anything (it
  waits and resumes once the window ends, if still blocked).
- `AUTO_CONTINUE_FALLBACK_MIN=300` — if the exact reset time can't be read, wait
  this many minutes after the block before resuming.

## Important caveats — please read

- **Resumes only; it does not restart a closed session.** Your PC must stay on
  (not asleep), the Kivun window must stay open, and the `claude` process must
  still be running. If the window is closed, there is nothing to resume.
- **If you resume manually first, nothing is injected.** Any key you press while
  it is waiting cancels the automatic `continue`. It will never "double-drive" a
  session you already came back to.
- **It types only the single word `continue`.** It does not send any other
  input.
- **Focus / prompt caveat.** Kivun cannot read the screen. If Claude is sitting
  on a question or a permission prompt at the exact moment the timer fires, the
  `continue` goes to that prompt. If you run unattended, consider Claude Code's
  own auto-accept options so a prompt isn't left waiting.
- **It does not bypass the limit.** It waits for the real reset time the provider
  reports, then resumes. It cannot get you more quota or earlier access.

## A note on terms of service

Auto-continue automates around a provider's rate limit and can spend quota on
work while you are away. This is a personal-use convenience, disclosed here so
you can decide. Unattended automated continuation may be against your provider's
usage policy, and it can consume your quota on work you did not watch. The
defaults are deliberately conservative (off by default, capped, quiet-hours
aware). **Use it at your own discretion.**

## For the curious — how it works

Kivun's BiDi wrapper already sits between your terminal and Claude Code, so it
can see the exact limit message and type `continue` directly into Claude — no
key-press simulation, and it works with the window minimized. The status line
now records the precise reset time to a small local file
(`~/.local/state/kivun-terminal/rate-limit.json`) so the timer waits exactly the
right amount. If you use Kivun in left-to-right mode, turning on auto-continue
enables a pass-through mode that adds the timer **without** changing how your
text is displayed.
