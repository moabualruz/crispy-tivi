#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_DIR="$ROOT_DIR/app/flutter"
OUT_FILE="${TMPDIR:-/tmp}/crispy_flutter_analyze.txt"

cd "$APP_DIR"

set +e
flutter analyze >"$OUT_FILE" 2>&1
analyze_exit=$?
set -e

cat "$OUT_FILE"

errors=$(grep -Ec '^[[:space:]]*error • ' "$OUT_FILE" || true)
warnings=$(grep -Ec '^[[:space:]]*warning • ' "$OUT_FILE" || true)
infos=$(grep -Ec '^[[:space:]]*info • ' "$OUT_FILE" || true)

echo ""
echo "Analyzer summary:"
echo "  errors:   $errors"
echo "  warnings: $warnings"
echo "  infos:    $infos"

if [[ "$errors" -gt 0 || "$warnings" -gt 0 ]]; then
  echo ""
  echo "FAILED: flutter analyze reported warnings/errors."
  exit 1
fi

if [[ "$analyze_exit" -ne 0 ]]; then
  echo ""
  echo "PASS with info backlog: flutter analyze exited non-zero due to info-level findings only."
else
  echo ""
  echo "PASS: flutter analyze reported zero warnings/errors."
fi
