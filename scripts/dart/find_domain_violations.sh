#!/usr/bin/env bash
# find_domain_violations.sh
#
# Quick check: ALL domain boundary violations.
# Exits with code 1 if any violations are found (useful in CI).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$REPO_ROOT/lib"

violations=0

echo "=== Domain Boundary Violations ==="
echo ""

# ─────────────────────────────────────────────────────────────
# 1. Flutter imports in domain/
# ─────────────────────────────────────────────────────────────
echo "[1] Flutter imports in domain/"
results=$(grep -rn "import 'package:flutter" \
  "$LIB/features/"*/domain/ \
  "$LIB/core/domain/" \
  2>/dev/null || true)
if [ -n "$results" ]; then
  while IFS= read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    import=$(echo "$line" | cut -d: -f3- | sed 's/^ *//')
    echo "  VIOLATION ${file#"$REPO_ROOT/"}:$lineno"
    echo "            $import"
    violations=$((violations + 1))
  done <<< "$results"
else
  echo "  OK — none found"
fi
echo ""

# ─────────────────────────────────────────────────────────────
# 2. Riverpod imports in domain/
# ─────────────────────────────────────────────────────────────
echo "[2] Riverpod imports in domain/"
results=$(grep -rn "import 'package:flutter_riverpod\|import 'package:riverpod" \
  "$LIB/features/"*/domain/ \
  "$LIB/core/domain/" \
  2>/dev/null || true)
if [ -n "$results" ]; then
  while IFS= read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    import=$(echo "$line" | cut -d: -f3- | sed 's/^ *//')
    echo "  VIOLATION ${file#"$REPO_ROOT/"}:$lineno"
    echo "            $import"
    violations=$((violations + 1))
  done <<< "$results"
else
  echo "  OK — none found"
fi
echo ""

# ─────────────────────────────────────────────────────────────
# 3. fromJson/toJson in domain entities
# ─────────────────────────────────────────────────────────────
echo "[3] fromJson/toJson in domain entities (serialization belongs in data layer)"
results=$(grep -rn "factory.*fromJson\|Map.*toJson\b" \
  "$LIB/features/"*/domain/entities/ \
  "$LIB/core/domain/entities/" \
  2>/dev/null || true)
if [ -n "$results" ]; then
  while IFS= read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    content=$(echo "$line" | cut -d: -f3- | sed 's/^ *//')
    echo "  VIOLATION ${file#"$REPO_ROOT/"}:$lineno"
    echo "            $content"
    violations=$((violations + 1))
  done <<< "$results"
else
  echo "  OK — none found"
fi
echo ""

# ─────────────────────────────────────────────────────────────
# 4. IconData/Color/Widget references in domain
# ─────────────────────────────────────────────────────────────
echo "[4] IconData/Color/Widget references in domain (UI belongs in presentation layer)"
results=$(grep -rn "IconData\|import 'package:flutter/material\|import 'package:flutter/widgets\|: Color\b\|: Widget\b" \
  "$LIB/features/"*/domain/ \
  "$LIB/core/domain/" \
  2>/dev/null || true)
if [ -n "$results" ]; then
  while IFS= read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    content=$(echo "$line" | cut -d: -f3- | sed 's/^ *//')
    echo "  VIOLATION ${file#"$REPO_ROOT/"}:$lineno"
    echo "            $content"
    violations=$((violations + 1))
  done <<< "$results"
else
  echo "  OK — none found"
fi
echo ""

# ─────────────────────────────────────────────────────────────
# 5. Concrete CacheService imports in presentation/providers/
# ─────────────────────────────────────────────────────────────
echo "[5] CacheService imported directly in presentation/providers/ (use repository abstractions)"
results=$(grep -rn "import.*cache_service" \
  "$LIB/features/"*/presentation/providers/ \
  2>/dev/null || true)
if [ -n "$results" ]; then
  while IFS= read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    import=$(echo "$line" | cut -d: -f3- | sed 's/^ *//')
    echo "  VIOLATION ${file#"$REPO_ROOT/"}:$lineno"
    echo "            $import"
    violations=$((violations + 1))
  done <<< "$results"
else
  echo "  OK — none found"
fi
echo ""

# ─────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────
echo "=== Summary ==="
echo "  Total violations: $violations"
echo ""

if [ "$violations" -gt 0 ]; then
  echo "  Run scripts/dart/audit_ddd_solid_dry.sh for full analysis."
  echo "  Run scripts/dart/fix_domain_flutter_imports.sh for auto-fixable imports."
  exit 1
else
  echo "  Domain boundaries are clean."
  exit 0
fi
