#!/usr/bin/env bash
# tests/validate_examples.sh - Compile every example in examples/ and publish headers
#
# Usage (from repo root):
#   tests/validate_examples.sh [path/to/vnpu_parser]
#
# On success each example produces a generated header under /tmp/vnpu-headers/
# which CI uploads as an artifact.

set -euo pipefail

PARSER="${1:-src/parser/vnpu_parser}"
OUTDIR="${VNPU_HEADERS_DIR:-/tmp/vnpu-headers}"
FAIL=0

if [[ ! -x "$PARSER" ]]; then
    echo "ERROR: parser not found or not executable: $PARSER" >&2
    exit 1
fi

mkdir -p "$OUTDIR"

echo "=== Validating Examples ==="
echo "Parser  : $PARSER"
echo "Output  : $OUTDIR"
echo ""

for f in examples/*.vnpu; do
    [[ -f "$f" ]] || continue
    name="$(basename "$f" .vnpu)"
    outfile="$OUTDIR/${name}.h"

    if "$PARSER" "$outfile" < "$f" >/dev/null 2>&1; then
        echo "  OK : $name → $outfile"
    else
        echo "  FAIL: $name"
        # Re-run to show diagnostics
        "$PARSER" /dev/null < "$f" || true
        FAIL=$((FAIL+1))
    fi
done

echo ""
if [[ $FAIL -eq 0 ]]; then
    echo "All examples validated successfully."
    echo "Generated headers available in $OUTDIR/"
else
    echo "$FAIL example(s) failed to compile."
fi

exit $FAIL
