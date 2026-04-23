#!/usr/bin/env bash
# paragraph-direction-test.sh
#
# Purpose: empirically determine which Unicode marker (if any) forces Konsole
# into RTL paragraph direction for the specific pattern that breaks Claude
# Code's first-response line — a leading `●` bullet followed by Hebrew text.
#
# Background: TROUBLESHOOTING.md claims Konsole uses "first-visible-char
# wins" paragraph detection, which would make zero-width marks like RLM
# ineffective. But we've never actually verified that on this machine with
# BidiLineLTR=false. This test does it in 30 seconds.
#
# How to run:
#   1. Open Kivun Terminal (Konsole will appear).
#   2. In Konsole, run:
#        bash /mnt/c/Users/noam.ORHITEC/Downloads/ClaudeCodeProjects/Kivun-Terminal_website/Kivun-Terminal_website/kivun-terminal-wsl/docs/research/paragraph-direction-test.sh
#   3. Look at each numbered line. Report which lines are right-aligned
#      (Hebrew hugs the right edge of the terminal) vs left-aligned
#      (content starts at the left edge).
#
# A line being "right-aligned" means the paragraph direction was detected
# as RTL. That's the fix we're trying to achieve for Claude's bullet-
# prefixed Hebrew responses.

RLM=$'‏'   # Right-to-Left Mark (zero-width, strong-R)
LRM=$'‎'   # Left-to-Right Mark (zero-width, strong-L) — control
RLE=$'‫'   # Right-to-Left Embedding (opens RTL bracket)
PDF=$'‬'   # Pop Directional Format (closes bracket)
RLI=$'⁧'   # Right-to-Left Isolate (modern alternative to RLE)
PDI=$'⁩'   # Pop Directional Isolate (closes RLI)

clear
echo "================================================================"
echo "  BiDi paragraph-direction test — which variants right-align?"
echo "================================================================"
echo ""
echo "Control: pure Hebrew, no neutrals (expected: right-aligned)"
echo "--> [1] שלום עולם"
echo ""
echo "Control: pure Latin (expected: left-aligned)"
echo "--> [2] hello world"
echo ""
echo "Baseline broken case: bullet then Hebrew (currently left-aligned)"
echo "--> [3] ● שלום עולם"
echo ""
echo "Test A: RLM at line start (before bullet)"
echo "--> [4] ${RLM}● שלום עולם"
echo ""
echo "Test B: RLM right before Hebrew (after bullet+space)"
echo "--> [5] ● ${RLM}שלום עולם"
echo ""
echo "Test C: whole line wrapped in RLE/PDF"
echo "--> [6] ${RLE}● שלום עולם${PDF}"
echo ""
echo "Test D: whole line wrapped in RLI/PDI isolate (UAX #9 modern)"
echo "--> [7] ${RLI}● שלום עולם${PDI}"
echo ""
echo "Test E: RLM before bullet + RLE around Hebrew"
echo "--> [8] ${RLM}● ${RLE}שלום עולם${PDF}"
echo ""
echo "Test F: LRM before bullet (control — expected left-aligned)"
echo "--> [9] ${LRM}● שלום עולם"
echo ""
echo "================================================================"
echo ""
echo "Report back: which numbered lines are RIGHT-aligned (Hebrew hugs"
echo "the right edge)? Expected right-aligned: [1]. Expected left-"
echo "aligned: [2], [9]. The interesting answers are [3] through [8]."
