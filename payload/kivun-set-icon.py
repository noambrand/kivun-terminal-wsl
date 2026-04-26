#!/usr/bin/env python3
# Kivun Terminal — set _NET_WM_ICON on the Konsole window so VcXsrv
# (and other X servers that ignore Konsole's empty icon) show the
# Kivun figure instead of the default X server logo.
#
# Why a separate script: this is the only way to override the icon
# under VcXsrv, which ignores xseticon-style runtime updates unless
# we directly write the _NET_WM_ICON CARDINAL[] property via libX11.
# Konsole itself sets only an empty _NET_WM_ICON_NAME.
#
# Usage: kivun-set-icon.py <wid> <png-path>
#
# Deps: python3-xlib python3-pil (both apt-installable).

import sys
from PIL import Image, ImageDraw
from Xlib import X, display


def build_icon_property(png_path):
    src = Image.open(png_path).convert('RGBA')

    # If the source has an opaque background (very common for icon
    # exports), floodfill it from each corner with full transparency.
    # Threshold 60 catches dark navy / black bg; the orange figure
    # has much higher RGB sum so the fill stops at its silhouette.
    # Black eyes inside the figure are disconnected from the corners
    # so they survive.
    if src.getpixel((0, 0))[3] == 255:
        for corner in ((0, 0), (src.width - 1, 0),
                       (0, src.height - 1), (src.width - 1, src.height - 1)):
            ImageDraw.floodfill(src, corner, (0, 0, 0, 0), thresh=60)

    # _NET_WM_ICON is a CARDINAL[] of [w, h, ARGB pixels...] runs
    # concatenated for multiple sizes. The window manager picks the
    # closest size for each context (taskbar, alt-tab, title bar).
    # X11's 16-bit request length caps a single property change at
    # ~64K cardinals, so each size run must stay small individually.
    icon = []
    for size in (16, 32, 48, 64):
        img = src.resize((size, size), Image.LANCZOS)
        icon.append(size)
        icon.append(size)
        for r, g, b, a in img.getdata():
            icon.append((a << 24) | (r << 16) | (g << 8) | b)
    return icon


def main():
    if len(sys.argv) != 3:
        print(f'usage: {sys.argv[0]} <wid> <png-path>', file=sys.stderr)
        sys.exit(2)

    wid = int(sys.argv[1], 0)
    icon = build_icon_property(sys.argv[2])

    d = display.Display()
    win = d.create_resource_object('window', wid)
    NET_WM_ICON = d.intern_atom('_NET_WM_ICON')
    CARDINAL = d.intern_atom('CARDINAL')
    win.change_property(NET_WM_ICON, CARDINAL, 32, icon,
                        mode=X.PropModeReplace)
    d.sync()
    print(f'icon set on 0x{wid:x} (sizes 16/32/48/64)')


if __name__ == '__main__':
    main()
