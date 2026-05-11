#!/usr/bin/env bash
# tests/run_e2e.sh - vNPU End-to-End Test Runner
#
# Usage (from repo root):
#   tests/run_e2e.sh [path/to/vnpu_parser]
#
# Runs every fixture under tests/fixtures/valid/ (must succeed + golden match)
# and tests/fixtures/invalid/ (must fail with a non-zero exit code).

set -euo pipefail

PARSER="${1:-src/parser/vnpu_parser}"
VALID_DIR="tests/fixtures/valid"
INVALID_DIR="tests/fixtures/invalid"
GOLDENS_DIR="tests/goldens"
TMPDIR=$(mktemp -d)
PASS=0
FAIL=0
declare -a ERRORS=()

cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

if [[ ! -x "$PARSER" ]]; then
    echo "ERROR: parser not found or not executable: $PARSER" >&2
    echo "       Build it with:  make -C src/parser build" >&2
    exit 1
fi

# ── helpers ─────────────────────────────────────────────────────────────────

pass() { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1 — $2"; FAIL=$((FAIL+1)); ERRORS+=("$1: $2"); }

# run_valid <fixture_path>
run_valid() {
    local fixture="$1"
    local name; name="$(basename "$fixture" .vnpu)"
    local outfile="$TMPDIR/$name.h"
    local stdout="$TMPDIR/$name.stdout"
    local stderr="$TMPDIR/$name.stderr"

    if ! "$PARSER" "$outfile" < "$fixture" >"$stdout" 2>"$stderr"; then
        fail "$name" "unexpected failure (exit $?)"
        cat "$stderr" >&2 || true
        return
    fi

    if [[ ! -f "$outfile" ]]; then
        fail "$name" "no output file generated"
        return
    fi

    local golden="$GOLDENS_DIR/$name.h"
    if [[ -f "$golden" ]]; then
        # Compare everything except the first comment line (contains filename)
        if diff <(tail -n +2 "$golden") <(tail -n +2 "$outfile") >/dev/null 2>&1; then
            pass "$name (golden match)"
        else
            fail "$name" "golden mismatch"
            diff <(tail -n +2 "$golden") <(tail -n +2 "$outfile") || true
        fi
    else
        pass "$name"
    fi
}

# run_invalid <fixture_path>
run_invalid() {
    local fixture="$1"
    local name; name="$(basename "$fixture" .vnpu)"
    local stdout="$TMPDIR/$name.stdout"
    local stderr="$TMPDIR/$name.stderr"

    if "$PARSER" /dev/null < "$fixture" >"$stdout" 2>"$stderr"; then
        fail "$name" "expected failure but parser succeeded"
    else
        pass "$name (correctly rejected)"
    fi
}

# ── main ────────────────────────────────────────────────────────────────────

echo "=== vNPU E2E Test Suite ==="
echo "Parser : $PARSER"
echo ""

echo "--- Valid Fixtures ---"
found_valid=0
for f in "$VALID_DIR"/*.vnpu; do
    [[ -f "$f" ]] || continue
    found_valid=1
    run_valid "$f"
done
[[ $found_valid -eq 1 ]] || echo "  (no valid fixtures found)"

echo ""
echo "--- Invalid Fixtures ---"
found_invalid=0
for f in "$INVALID_DIR"/*.vnpu; do
    [[ -f "$f" ]] || continue
    found_invalid=1
    run_invalid "$f"
done
[[ $found_invalid -eq 1 ]] || echo "  (no invalid fixtures found)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [[ ${#ERRORS[@]} -gt 0 ]]; then
    echo ""
    echo "Failed tests:"
    for e in "${ERRORS[@]}"; do
        echo "  ✗ $e"
    done
fi

[[ $FAIL -eq 0 ]]
