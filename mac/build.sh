#!/bin/bash
# Kivun Terminal - local macOS .pkg builder
# Requires: macOS with Xcode Command Line Tools installed.
# Usage: ./mac/build.sh [version]

set -e

VERSION="${1:-$(cat VERSION 2>/dev/null || echo '1.0.6')}"
BUILD_DIR="build"
PKG_NAME="Kivun_Terminal_Setup_mac.pkg"
IDENTIFIER="com.kivun.terminal"

echo "=== Kivun Terminal macOS Builder ==="
echo "Version: $VERSION"

# Ensure we're on macOS
if [ "$(uname -s)" != "Darwin" ]; then
    echo "ERROR: This script must be run on macOS."
    exit 1
fi

# Ensure pkgbuild is available (ships with Xcode CLT)
if ! command -v pkgbuild &>/dev/null; then
    echo "ERROR: pkgbuild not found. Install Xcode Command Line Tools:"
    echo "  xcode-select --install"
    exit 1
fi

# Stage the scripts dir - postinstall needs its payload siblings so it can
# copy them into /usr/local/share/kivun-terminal/ during install.
mkdir -p "$BUILD_DIR/scripts"
cp mac/scripts/postinstall "$BUILD_DIR/scripts/"
cp payload/statusline.mjs "$BUILD_DIR/scripts/statusline.mjs"
cp payload/configure-statusline.js "$BUILD_DIR/scripts/configure-statusline.js"
cp payload/languages.sh "$BUILD_DIR/scripts/languages.sh"
cp mac/uninstall.sh "$BUILD_DIR/scripts/uninstall.sh"

# Stage the BiDi wrapper source - node_modules and .git excluded so the
# .pkg ships only sources; postinstall runs `npm install --production` on
# the target machine so node-pty builds against the local arch (Intel vs
# Apple Silicon) and libc. Mirrors the Windows installer's File /r /x.
if [ -d "kivun-claude-bidi" ]; then
    mkdir -p "$BUILD_DIR/scripts/kivun-claude-bidi"
    (cd kivun-claude-bidi && tar --exclude=node_modules --exclude=.git -cf - .) \
        | (cd "$BUILD_DIR/scripts/kivun-claude-bidi" && tar xf -)
    chmod +x "$BUILD_DIR/scripts/kivun-claude-bidi/bin/kivun-claude-bidi" 2>/dev/null || true
    echo "Staged kivun-claude-bidi wrapper source"
else
    echo "WARNING: kivun-claude-bidi/ not found at repo root - wrapper will not ship"
fi

# Integrity check: postinstall verifies statusline.mjs against this SHA
# before installing. macOS has `shasum`; Linux uses `sha256sum`.
if command -v shasum &>/dev/null; then
    shasum -a 256 "$BUILD_DIR/scripts/statusline.mjs" | awk '{print $1}' > "$BUILD_DIR/scripts/statusline.mjs.sha256"
elif command -v sha256sum &>/dev/null; then
    sha256sum "$BUILD_DIR/scripts/statusline.mjs" | awk '{print $1}' > "$BUILD_DIR/scripts/statusline.mjs.sha256"
fi
chmod +x "$BUILD_DIR/scripts/postinstall"

echo "Staged scripts:"
ls -la "$BUILD_DIR/scripts/"

# Build the package. --nopayload means no files are installed from the package
# itself; the postinstall script does all the work (installing Homebrew/Node/
# Claude Code, creating shortcuts, etc.).
pkgbuild \
    --nopayload \
    --scripts "$BUILD_DIR/scripts" \
    --identifier "$IDENTIFIER" \
    --version "$VERSION" \
    --install-location / \
    "$BUILD_DIR/$PKG_NAME"

echo
echo "=== Build complete ==="
ls -lh "$BUILD_DIR/$PKG_NAME"
pkgutil --check-signature "$BUILD_DIR/$PKG_NAME" 2>/dev/null || echo "(unsigned)"
echo
echo "Output: $BUILD_DIR/$PKG_NAME"
echo "To install locally for testing: sudo installer -pkg $BUILD_DIR/$PKG_NAME -target /"
