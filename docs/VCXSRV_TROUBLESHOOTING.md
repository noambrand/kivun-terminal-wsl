# VcXsrv Troubleshooting

This page is for people whose `BASH_LAUNCH_LOG.txt` shows:

```
INFO - VcXsrv configured but unreachable; using WSLg
```

## TL;DR — should I care?

**On modern Windows 11 (WSLg >= 1.0.65) with a recent Konsole: probably not.** WSLg is the X server that ships built-in to WSL2. The launcher falls back to WSLg automatically and it handles keyboard switching, display, clipboard, and RTL/BiDi rendering correctly for the vast majority of users. The fact that VcXsrv was configured but unreachable does not mean Kivun Terminal is broken — open it and try Hebrew + Alt+Shift. If both work, you can stop reading here.

## When you should fix it

- Alt+Shift does not switch your keyboard layout in Konsole.
- Konsole's display is glitchy, fonts render at the wrong size, or the cursor jumps.
- You're on an older WSL2 build (`wsl --version` shows WSLg < 1.0.65).
- You're not using stock Ubuntu and your distro has known WSLg integration issues.

In any of those cases, real VcXsrv connectivity is worth the setup.

## Why VcXsrv is usually unreachable

The launcher's bash side (`payload/kivun-launch.sh`) does an `xdpyinfo` probe against the WSL gateway IP on display `:0`. If that probe fails inside 3 seconds, it falls back to WSLg. The probe fails when any of these are true:

1. **VcXsrv is not running.** The launcher tries to start it via `C:\Program Files\VcXsrv\xlaunch.exe -run kivun.xlaunch`, but the start is fire-and-forget — if VcXsrv hasn't opened its TCP socket within ~2 seconds, the bash probe gives up.
2. **Windows Firewall blocks inbound TCP 6000.** WSL2's Hyper-V vEthernet adapter is treated as a "Public" network. The default VcXsrv firewall rules are usually for "Private" only, so the SYN packet is dropped silently (you'll see `connect: timed out` from `nc -zv 172.21.x.1 6000` inside WSL).
3. **VcXsrv is running with `-nolisten tcp`.** Rare on current builds, but happens if XLaunch was configured to disable TCP.
4. **X11 access control rejects the connection.** VcXsrv defaults to access-control-on. The launcher tries `xhost +si:localuser:$USER` to authorize, but `xhost` itself needs a working connection first, so this only works if access control is already off.

## Fix #1 — Add the firewall rule

Run **as Administrator** in `cmd.exe` (or right-click a `.bat` file containing this line and choose "Run as administrator"):

```
netsh advfirewall firewall add rule name="Kivun VcXsrv (WSL TCP 6000)" dir=in action=allow protocol=TCP localport=6000 profile=any
```

To remove later:

```
netsh advfirewall firewall delete rule name="Kivun VcXsrv (WSL TCP 6000)"
```

## Fix #2 — Make VcXsrv listen on TCP and skip access control

Edit `%LOCALAPPDATA%\Kivun-WSL\kivun.xlaunch` (or replace it with the snippet below) and change two attributes:

```xml
<XLaunch ...
         DisableAC="True"
         ExtraParams="-listen tcp"
         ... />
```

- `DisableAC="True"` adds `-ac` to the VcXsrv command line. This disables X11 access control, so any process that can reach TCP 6000 can connect.
- `ExtraParams="-listen tcp"` makes TCP listening explicit so it does not depend on the build's default.

**Security trade-off:** with `-ac`, any local Windows process can connect to display `:0` (and snoop keys / windows). The Windows Firewall rule from Fix #1 limits external reach to localhost + WSL, so the practical exposure on a single-user laptop is minimal. On a multi-user or shared machine, this is not appropriate — stick with WSLg in that case.

## Fix #3 — Prove it works

After applying both fixes, kill any existing VcXsrv (`taskkill /F /IM vcxsrv.exe`), then either re-run Kivun Terminal or test directly from a WSL prompt:

```bash
# Should print "TCP_OK"
timeout 3 bash -c '</dev/tcp/172.21.128.1/6000' && echo TCP_OK || echo TCP_FAIL

# Should print "name of display: 172.21.128.1:0" and a vendor string
DISPLAY=172.21.128.1:0 xdpyinfo | head -3
```

If both work, the next launch of Kivun Terminal will log `SUCCESS - VcXsrv is reachable` instead of falling back to WSLg.

## How the launcher decides

`payload/kivun-launch.sh` only enters this code path when `USE_VCXSRV=true` is set in `payload/config.txt`. If you do not need VcXsrv, set it to `false` in your config — the launcher will skip the probe entirely and use WSLg straight away, with no fallback message.
