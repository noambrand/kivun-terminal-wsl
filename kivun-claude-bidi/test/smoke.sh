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

KIVUN_CLAUDE_BIN=/usr/bin/node \
KIVUN_BIDI_FORCE=1 \
KONSOLE_VERSION=230400 \
TERM=xterm-256color \
  node "$ROOT/bin/kivun-claude-bidi" "$SCRIPT_DIR/fake-claude.cjs" < /dev/null > "$tmp" 2>&1

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
