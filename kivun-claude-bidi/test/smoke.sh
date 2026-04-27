#!/usr/bin/env bash
# smoke.sh — end-to-end wrapper + fake-claude smoke test.
# Verifies that bin/kivun-claude-bidi can spawn a stand-in binary under
# node-pty, pipe its output through the injector, and emit RLE/PDF
# brackets around Hebrew runs.

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RLE=$'‫'
PDF=$'‬'

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# Resolve node dynamically. Hardcoding /usr/bin/node only works on Linux
# distros that apt-installed nodejs there; on macOS node lives at
# /usr/local/bin/node (Intel + Homebrew) or /opt/homebrew/bin/node
# (Apple Silicon), and via nvm it's $NVM_DIR/versions/node/.../bin/node.
NODE_BIN="$(command -v node)"
if [ -z "$NODE_BIN" ]; then
  echo "ERROR: node not on PATH; smoke test requires Node.js" >&2
  exit 127
fi

KIVUN_CLAUDE_BIN="$NODE_BIN" \
KIVUN_BIDI_FORCE=1 \
KONSOLE_VERSION=230400 \
TERM=xterm-256color \
KIVUN_BIDI_FLATTEN_COLORS_RTL=off \
KIVUN_BIDI_BRACKET_RTL_RUNS=on \
  "$NODE_BIN" "$ROOT/bin/kivun-claude-bidi" "$SCRIPT_DIR/fake-claude.cjs" < /dev/null > "$tmp" 2>&1
# ^^^ Smoke fixtures pre-date v1.1.10 FLATTEN_COLORS_RTL and v1.1.11
# no-RTL-bracket. Opt back to the legacy combination so the assertions
# below (which check for RLE/PDF + SGR around Hebrew) keep matching.
# New behavior is exercised in the unit-test suites
# (flatten-colors-rtl.test.js, no-bracket-rtl-runs.test.js).

fail=0

check() {
  local label="$1"
  local needle="$2"
  if grep -q -- "$needle" "$tmp"; then
    echo "  pass  $label"
  else
    echo "  FAIL  $label  (missing: $(printf %q "$needle"))"
    fail=1
  fi
}

echo "smoke: fake-claude output through wrapper ->"
check "plain ascii unchanged"                    "plain ascii line"
check "pure Hebrew gets bracket pair"            "${RLE}שלום עולם${PDF}"
check "mixed Hebrew-in-Latin bracketed"          "Hello ${RLE}שלום${PDF} world"
check "multi-run: first run bracketed"           "foo ${RLE}שלום${PDF} bar"
check "multi-run: second run bracketed"          "bar ${RLE}עולם${PDF} baz"
check "ANSI SGR mid-Hebrew run: bracket starts at שלו" "mid-run SGR: ${RLE}שלו"
check "Hebrew-period-English: period outside"    "${RLE}שלום${PDF}. Hello"

if [[ $fail -ne 0 ]]; then
  echo ""
  echo "smoke: FAIL — captured output was:"
  cat "$tmp"
  exit 1
fi

echo "smoke: OK"
