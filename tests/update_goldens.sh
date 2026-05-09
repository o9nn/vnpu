#!/usr/bin/env bash
# tests/update_goldens.sh - Regenerate golden files from current compiler output
#
# Usage (from repo root):
#   tests/update_goldens.sh [path/to/vnpu_parser]
#
# Run this after making compiler changes.  The generated files should be
# reviewed and committed alongside the corresponding source change.

set -euo pipefail

PARSER="${1:-src/parser/vnpu_parser}"
GOLDENS="tests/goldens"
VALID_DIR="tests/fixtures/valid"
FAIL=0

if [[ ! -x "$PARSER" ]]; then
    echo "ERROR: parser not found or not executable: $PARSER" >&2
    echo "       Build it with:  make -C src/parser build" >&2
    exit 1
fi

mkdir -p "$GOLDENS"

echo "=== Updating Golden Files ==="
echo "Parser  : $PARSER"
echo "Goldens : $GOLDENS/"
echo ""

for f in "$VALID_DIR"/*.vnpu; do
    [[ -f "$f" ]] || continue
    name="$(basename "$f" .vnpu)"
    outfile="$GOLDENS/$name.h"

    if "$PARSER" "$outfile" < "$f" >/dev/null 2>&1; then
        echo "  Updated : $name.h"
    else
        echo "  FAIL    : $name (compiler returned non-zero)"
        FAIL=$((FAIL+1))
    fi
done

echo ""
if [[ $FAIL -eq 0 ]]; then
    echo "Golden files updated in $GOLDENS/"
    echo ""
    echo "Review the diffs and commit:"
    echo "  git diff tests/goldens/"
    echo "  git add tests/goldens/ && git commit -m 'test: update golden files'"
else
    echo "$FAIL fixture(s) failed — golden files may be incomplete."
fi

exit $FAIL
