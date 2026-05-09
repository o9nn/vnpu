#!/usr/bin/env bash
# tests/run_grammar_check.sh - Verify ANTLR grammar and lex/yacc parser parity
#
# Usage (from repo root):
#   tests/run_grammar_check.sh
#
# Checks that every keyword, data type, port type, membrane name, and
# comparison operator present in the ANTLR grammar also appears in the
# lex/yacc sources and vice-versa.

set -euo pipefail

ANTLR="grammar/Vnpu.g4"
LEXER="src/parser/vnpu.l"
PARSER="src/parser/vnpu.y"

FAIL=0

echo "=== Grammar Parity Check ==="
echo "ANTLR  : $ANTLR"
echo "Lexer  : $LEXER"
echo "Parser : $PARSER"
echo ""

# ── helpers ─────────────────────────────────────────────────────────────────

check_in_antlr() {
    local label="$1"; local kw="$2"
    if ! grep -q "'$kw'" "$ANTLR"; then
        echo "  FAIL: $label '$kw' is missing from $ANTLR"
        FAIL=1
    fi
}

check_in_lexer() {
    local label="$1"; local kw="$2"
    if ! grep -q "\"$kw\"" "$LEXER"; then
        echo "  FAIL: $label '$kw' is missing from $LEXER"
        FAIL=1
    fi
}

check_keyword() {
    local kw="$1"
    check_in_antlr "keyword" "$kw"
    check_in_lexer  "keyword" "$kw"
}

# ── keywords ────────────────────────────────────────────────────────────────

echo "--- Keywords ---"
for kw in vnpu device tensor kernel graph isolate policy membrane \
           entry ports allows denies when and or; do
    check_keyword "$kw"
done

# ── data types ──────────────────────────────────────────────────────────────

echo "--- Data Types ---"
for dt in f16 f32 bf16 i8 i16 i32 i64 u8; do
    check_in_antlr "dtype" "$dt"
    check_in_lexer  "dtype" "$dt"
done

# ── port types ───────────────────────────────────────────────────────────────

echo "--- Port Types ---"
for pt in Intent Evidence Tensor Bytes; do
    check_in_antlr "port type" "$pt"
    check_in_lexer  "port type" "$pt"
done

# ── membrane names ───────────────────────────────────────────────────────────

echo "--- Membrane Names ---"
for mem in inner trans outer; do
    check_in_antlr "membrane" "$mem"
    check_in_lexer  "membrane" "$mem"
done

# ── comparison operators ─────────────────────────────────────────────────────

echo "--- Comparison Operators ---"
for op in ">=" "<=" "!=" "=="; do
    if ! grep -qF "$op" "$ANTLR"; then
        echo "  FAIL: operator '$op' missing from $ANTLR"
        FAIL=1
    fi
    if ! grep -qF "$op" "$LEXER"; then
        echo "  FAIL: operator '$op' missing from $LEXER"
        FAIL=1
    fi
done

# ── qualID in policy expressions ─────────────────────────────────────────────

echo "--- Policy expression qualID ---"
# The ANTLR grammar must include qualID in the expr rule (for budget.tokens etc.)
if ! grep -qE "qualID.*compOp|compOp.*qualID" "$ANTLR"; then
    echo "  FAIL: ANTLR grammar expr rule does not support qualID (dotted) comparisons"
    FAIL=1
fi

# ── result ───────────────────────────────────────────────────────────────────

echo ""
if [[ $FAIL -eq 0 ]]; then
    echo "Grammar parity check: PASSED"
else
    echo "Grammar parity check: FAILED ($FAIL issue(s))"
fi

exit $FAIL
