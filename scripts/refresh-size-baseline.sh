#!/usr/bin/env bash
#
# Regenerate .githooks/file-size-baseline.txt from the current tree.
#
# The baseline is the ratchet for CLAUDE.md §8.5: every tracked .swift file
# already over the 500-line hard cap is recorded with its current length, and
# the pre-commit hook refuses to let any of them grow past that number. New
# files over the cap are rejected outright and never enter the baseline.
#
# Run this after splitting a file, so the ratchet tightens to the new, lower
# number and the old slack is not silently reclaimed later.
#
# Usage: bash scripts/refresh-size-baseline.sh

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

OUT=.githooks/file-size-baseline.txt
MAX_LINES=500

{
  echo "# CLAUDE.md §8.5 ratchet baseline - regenerate with scripts/refresh-size-baseline.sh"
  echo "# Format: <max-permitted-lines> <path>"
  echo "#"
  echo "# These files predate enforcement of the $MAX_LINES-line hard cap. The pre-commit"
  echo "# hook fails any commit that grows one past the number recorded here, and"
  echo "# fails any NEW file over $MAX_LINES lines. The list only shrinks."
  git ls-files '*.swift' | while read -r f; do
    n=$(wc -l < "$f" | tr -d ' ')
    if [ "$n" -gt "$MAX_LINES" ]; then echo "$n $f"; fi
  done | sort -k2
} > "$OUT"

count=$(grep -cv '^#' "$OUT" || true)
echo "Wrote $OUT - $count file(s) over the $MAX_LINES-line cap."
