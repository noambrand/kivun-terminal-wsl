#!/usr/bin/env bash
# Bump the project version in lockstep across the VERSION file and all
# "current-version" stamps in docs that go stale on every release.
#
# Historical version references (e.g. "fixed in v1.3.0", changelog entries,
# code comments referencing the version a fix shipped in) are deliberately
# NOT touched — they're correct history, not stale stamps.
#
# Usage: ./tools/bump-version.sh 1.3.6
#
# After running, review with `git diff`, then:
#   git add -A && git commit -m "chore(release): v$NEW" && git push
#   git tag -a vX.Y.Z -m "..." && git push origin vX.Y.Z
#
# A CI consistency check (.github/workflows/verify-version-stamps.yml)
# verifies these stamps stay in sync with VERSION on every push, so an
# accidental partial bump fails CI before a release is cut.

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: $0 <new-version>   (e.g. 1.3.6)" >&2
  exit 1
fi

NEW="$1"

if ! [[ "$NEW" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: '$NEW' is not a semver-style x.y.z" >&2
  exit 1
fi

cd "$(dirname "$0")/.."

OLD=$(tr -d '[:space:]' < VERSION)
echo "Bumping $OLD → $NEW"

# 1. The VERSION file itself (preserve trailing newline if present originally).
printf '%s\n' "$NEW" > VERSION

# 2. docs/README.md  — three current-version stamps.
#    a) line 1 header:           "# Kivun Terminal v1.3.5"
#    b) compare-table cell:      "Kivun Terminal v1.3.5 |"  (note trailing space + pipe)
#    c) "What's new in vX" header (and the surrounding paragraph if any)
sed -i \
  -e "s|^# Kivun Terminal v[0-9][0-9.]*$|# Kivun Terminal v$NEW|" \
  -e "s|Kivun Terminal v[0-9][0-9.]* |Kivun Terminal v$NEW |g" \
  -e "s|^### What's new in v[0-9][0-9.]*$|### What's new in v$NEW|" \
  docs/README.md

# 3. docs/README_INSTALLATION.md — title-bar stamp.
sed -i \
  -e "s|^# Kivun Terminal v[0-9][0-9.]* - Full Installation Guide|# Kivun Terminal v$NEW - Full Installation Guide|" \
  docs/README_INSTALLATION.md

# 4. docs/TROUBLESHOOTING.md — title-bar stamp.
sed -i \
  -e "s|^# Kivun Terminal v[0-9][0-9.]* - Troubleshooting|# Kivun Terminal v$NEW - Troubleshooting|" \
  docs/TROUBLESHOOTING.md

# 5. payload/folder-picker.hta — the update-check FALLBACK_VERSION (used when no
#    VERSION file is present in the install dir). Must track the shipped version
#    or the picker nags about a "newer" release that is actually the installed one.
sed -i -E "s/(var FALLBACK_VERSION = \")[0-9]+\.[0-9]+\.[0-9]+(\";)/\1$NEW\2/" payload/folder-picker.hta

# 6. installer/Kivun_Terminal_Setup.nsi — the !ifndef PRODUCT_VERSION fallback
#    for LOCAL makensis builds (CI overrides it via -DPRODUCT_VERSION from VERSION).
#    Keeping it current means even a hand-run local build never stamps a stale
#    version — the drift that showed the installer as "v1.4.25" all the way to v1.5.15.
sed -i -E "s/(!define PRODUCT_VERSION \")[0-9]+\.[0-9]+\.[0-9]+(\")/\1$NEW\2/" installer/Kivun_Terminal_Setup.nsi

echo "Bumped. Diff summary:"
git diff --stat VERSION docs/README.md docs/README_INSTALLATION.md docs/TROUBLESHOOTING.md payload/folder-picker.hta installer/Kivun_Terminal_Setup.nsi
echo ""
echo "Next steps:"
echo "  git diff                                # review"
echo "  # add a new entry at the top of docs/CHANGELOG.md for v$NEW"
echo "  # optionally write docs/RELEASE_NOTES_$NEW.md (preferred user-facing notes)"
echo "  git add -A && git commit -m \"chore(release): v$NEW\""
echo "  git push origin <branch>"
echo "  git tag -a v$NEW -m \"v$NEW\""
echo "  git push origin v$NEW   # tag-push triggers the build + release"
