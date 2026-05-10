# Kivun RTL Cost Optimizer

The Kivun RTL Cost Optimizer is an optional feature for Hebrew, Arabic,
Persian, Urdu and other RTL-language Claude Code sessions.

It does **not** make RTL languages cheaper at the tokenizer level. It saves
cost by minimizing how much verbose RTL text is sent into Claude Code's agent
loop. Your natural RTL request is converted locally into a compact English
technical prompt, while the final answer is still requested in your RTL
language.

## Enable it

### Windows picker menu

1. Open Kivun Terminal from the desktop shortcut.
2. In **RTL Cost Optimizer**, read the cost guidance and check
   **Enable optimizer**.
3. Optionally toggle **Show optimized prompt preview** and
   **Show token estimate**.
4. Relaunch Kivun Terminal so the wrapper receives the updated environment.

The picker saves these switches directly to `config.txt`.

### Manual config

Edit your Kivun config file:

| Platform | Config path |
|---|---|
| Windows / WSL | `%LOCALAPPDATA%\Kivun-WSL\config.txt` |
| Linux | `~/.config/kivun-terminal/config.txt` |

Set:

```ini
KIVUN_RTL_COST_OPTIMIZER=on
KIVUN_RTL_COST_OPTIMIZER_MODE=prompt
KIVUN_RTL_COST_OPTIMIZER_SHOW_PREVIEW=on
KIVUN_RTL_COST_OPTIMIZER_SHOW_ESTIMATE=on
KIVUN_RTL_COST_OPTIMIZER_AUDIT=on
```

Restart Kivun Terminal. The optimizer runs inside the existing
`kivun-claude-bidi` wrapper; no external service is used.

### Linux helper command

Linux installs also include a visible helper:

```bash
kivun-optimizer status      # show current optimizer + spacing settings
kivun-optimizer on          # start/enable optimizer
kivun-optimizer off         # stop/disable optimizer
kivun-optimizer log         # show recent optimizer metric entries
kivun-optimizer native      # disable wrapper; use Konsole native BiDi
kivun-optimizer wrapper     # re-enable wrapper BiDi processing
kivun-optimizer spaces-off  # disable the BiDi cursor-spacing workaround
kivun-optimizer spaces-on   # re-enable the BiDi cursor-spacing workaround
```

Restart Kivun Terminal after changing settings.

## How to operate it

1. Launch Kivun Terminal normally.
2. Type a developer request in Hebrew, Arabic, Persian, Urdu, etc.
3. Press Enter.
4. Interactive Claude Code uses a raw terminal UI. Kivun therefore skips prompt
   replacement in interactive TUI sessions to avoid corrupting typing, spacing,
   or screen layout. The optimizer remains available for non-interactive/piped
   prompt input.
5. If preview is enabled for non-interactive input, Kivun prints:
   - the compact English prompt it will send to Claude Code
   - a heuristic before/after token estimate
6. Claude Code receives the optimized English technical prompt and is told to
   return a concise summary in your RTL language.

Interactive TUI sessions do not print preview/estimate text into the terminal by
default because that can corrupt Claude Code's live screen. For optimized
non-interactive/piped input, safe metrics are written to
`~/.local/share/kivun-terminal/optimizer.log` on Linux/WSL. Each line is JSON and
contains only token estimates and language metadata, not your prompt text. Set
`KIVUN_RTL_COST_OPTIMIZER_AUDIT=off` to disable this metrics log.

Example input:

```text
תבדוק למה CMake נכשל בפרויקט ותתקן בלי לשבור את הבדיקות
```

Optimized prompt sent to Claude:

```text
Use English for internal reasoning.
Do not translate code identifiers or paths.
Task:
Investigate the CMake build failure and fix the root cause.
Constraints:
- Preserve existing tests.
- Do not change public APIs unless required.
Technical terms to preserve:
- CMake
Final output:
Return a concise summary in Hebrew.
```

## What is preserved

The optimizer is local and conservative. It preserves code identifiers, paths,
filenames, commands, logs and fenced code blocks. Known technical terms such as
`CMake`, `CMakeLists.txt`, `MISRA C`, `CERT C`, `Parasoft`, `cpptestcli`,
`DTP`, `SARIF`, `Sourcegraph`, `Ampcode`, and `Claude Code` are carried into
the optimized prompt.

## Token estimate

The displayed estimate is heuristic, not Anthropic billing data:

- English prose: `characters / 4`
- Hebrew or Arabic prose: `characters / 2`
- Code/log text: `characters / 3`

The unit test suite includes a repeated Hebrew CMake request that demonstrates
positive estimated savings (at least 40%) after compression.

## Disable it

Set:

```ini
KIVUN_RTL_COST_OPTIMIZER=off
```

and restart Kivun Terminal.

## Known limitations

- Current mode is line-oriented `prompt` mode. The optimizer transforms a
  completed prompt when you press Enter.
- Very short RTL prompts may not save tokens because the optimized prompt still
  includes safety instructions. The savings are intended for verbose requests
  that would otherwise be carried through the Claude Code agent loop.
- Language detection is script-level and local. Arabic-script languages such as
  Persian, Urdu, Kurdish and Dari are grouped under a generic RTL-language
  final-output instruction unless the surrounding Kivun response-language prompt
  already specifies the exact language.
- The estimate is for comparison only; actual Claude billing and context use are
  determined by Claude Code and Anthropic.
