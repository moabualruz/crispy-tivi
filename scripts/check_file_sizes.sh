#!/usr/bin/env bash
# CI script: Fail if any human-written source file exceeds 500 lines.
# Excludes: lib/src/rust/, lib/l10n/, *.g.dart, *.freezed.dart
#
# Usage: bash scripts/check_file_sizes.sh [max_lines]
# Exit code 0 = pass, 1 = violations found

set -euo pipefail

MAX_LINES="${1:-500}"
VIOLATIONS=0

check_dir() {
  local dir="$1"
  local ext="$2"
  [ -d "$dir" ] || return 0

  while IFS= read -r -d '' file; do
    # Normalize to forward slashes
    normalized="${file//\\//}"

    # Exclude generated / auto-managed files
    case "$normalized" in
      lib/src/rust/*|*/lib/src/rust/*)           continue ;; # FRB generated Dart
      lib/l10n/*|*/lib/l10n/*)                   continue ;; # l10n generated
      *.g.dart)                                  continue ;; # build_runner
      *.freezed.dart)                            continue ;; # freezed
      */frb_generated.rs)                        continue ;; # FRB generated Rust
      */target/*)                                continue ;; # Cargo build output
    esac

    lines=$(wc -l < "$file")
    if [ "$lines" -gt "$MAX_LINES" ]; then
      echo "VIOLATION: $normalized ($lines lines, $((lines - MAX_LINES)) over limit)"
      VIOLATIONS=$((VIOLATIONS + 1))
    fi
  done < <(find "$dir" -name "*.$ext" -print0)
}

echo "Checking file sizes (max $MAX_LINES lines)..."

check_dir "lib" "dart"
check_dir "rust" "rs"

if [ "$VIOLATIONS" -gt 0 ]; then
  echo ""
  echo "FAILED: $VIOLATIONS file(s) exceed $MAX_LINES lines."
  exit 1
fi

echo "PASSED: All files within $MAX_LINES line limit."
exit 0
