#!/usr/bin/env bash
# CI script: Fail if any human-written source file exceeds 500 lines
# beyond the tracked baseline backlog.
#
# Existing oversized files are recorded in scripts/ci/file_size_baseline.txt
# as a ratchet baseline. CI fails when:
# - a new file exceeds the line limit, or
# - a baseline file grows beyond its recorded line count.
#
# Excludes: lib/src/rust/, lib/l10n/, *.g.dart, *.freezed.dart
#
# Usage: bash scripts/check_file_sizes.sh [max_lines]
# Exit code 0 = pass, 1 = violations found

set -euo pipefail

MAX_LINES="${1:-500}"
VIOLATIONS=0
BASELINE_FILE="$(cd "$(dirname "$0")/.." && pwd)/scripts/ci/file_size_baseline.txt"

declare -A BASELINE=()
declare -A CURRENT=()

if [ -f "$BASELINE_FILE" ]; then
  while IFS='|' read -r path lines; do
    [ -n "${path:-}" ] || continue
    BASELINE["$path"]="$lines"
  done < "$BASELINE_FILE"
fi

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
      CURRENT["$normalized"]="$lines"
    fi
  done < <(find "$dir" -name "*.$ext" -print0)
}

echo "Checking file sizes (max $MAX_LINES lines)..."

check_dir "lib" "dart"
check_dir "rust" "rs"

for path in "${!CURRENT[@]}"; do
  lines="${CURRENT[$path]}"
  baseline_lines="${BASELINE[$path]:-}"
  if [ -z "$baseline_lines" ]; then
    echo "VIOLATION: $path ($lines lines, new oversized file)"
    VIOLATIONS=$((VIOLATIONS + 1))
    continue
  fi

  if [ "$lines" -gt "$baseline_lines" ]; then
    echo \
      "VIOLATION: $path ($lines lines, grew by $((lines - baseline_lines)) from baseline $baseline_lines)"
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
done

if [ "$VIOLATIONS" -gt 0 ]; then
  echo ""
  echo "FAILED: $VIOLATIONS file(s) exceed the file-size baseline."
  exit 1
fi

baseline_count="${#BASELINE[@]}"
current_count="${#CURRENT[@]}"
echo "PASSED: No new oversized files and no baseline regressions."
echo "Baseline oversized files: $baseline_count"
echo "Current oversized files: $current_count"
exit 0
