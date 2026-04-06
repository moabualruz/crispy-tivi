#!/usr/bin/env bash
# fix_domain_flutter_imports.sh
#
# Replaces `import 'package:flutter/foundation.dart';` with
# `import 'package:meta/meta.dart';` in domain files ONLY when
# the file uses no flutter/foundation symbols beyond @immutable.
#
# Reports files that need manual attention.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$REPO_ROOT/lib"

# Symbols from flutter/foundation.dart that are NOT in meta/meta.dart
# If any are found in a file, we skip auto-replacement.
FLUTTER_ONLY_SYMBOLS=(
  "kIsWeb"
  "kDebugMode"
  "kProfileMode"
  "kReleaseMode"
  "setEquals"
  "mapEquals"
  "listEquals"
  "debugPrint"
  "Uint8List"
  "ValueNotifier"
  "ChangeNotifier"
  "ValueListenable"
  "Listenable"
  "FlutterError"
  "FlutterMemoryAllocations"
  "DiagnosticLevel"
  "DiagnosticsNode"
  "debugger"
  "compute"
  "consolidateHttpClientResponseBytes"
)

echo "=== Fix Domain Flutter/Foundation Imports ==="
echo ""

# Find all domain files importing flutter/foundation.dart
domain_dirs=()
while IFS= read -r d; do
  domain_dirs+=("$d")
done < <(find "$LIB" -type d -name "domain" 2>/dev/null)

if [ ${#domain_dirs[@]} -eq 0 ]; then
  echo "No domain directories found."
  exit 0
fi

changed=0
manual=0

for dir in "${domain_dirs[@]}"; do
  while IFS= read -r file; do
    # Check if file imports flutter/foundation.dart
    if ! grep -q "import 'package:flutter/foundation.dart'" "$file" 2>/dev/null; then
      continue
    fi

    rel="${file#"$REPO_ROOT/"}"

    # Check for flutter-only symbols
    needs_manual=0
    for sym in "${FLUTTER_ONLY_SYMBOLS[@]}"; do
      # Look for the symbol outside of import lines
      if grep -v "^import " "$file" | grep -qw "$sym" 2>/dev/null; then
        needs_manual=1
        echo "  MANUAL: $rel"
        echo "          Uses '$sym' from flutter/foundation — replace manually"
        manual=$((manual + 1))
        break
      fi
    done

    if [ "$needs_manual" -eq 0 ]; then
      # Safe to replace: only @immutable (or nothing) used from flutter/foundation
      echo "  FIXING: $rel"
      sed -i "s|import 'package:flutter/foundation.dart';|import 'package:meta/meta.dart';|g" "$file"
      changed=$((changed + 1))
      echo "          Replaced flutter/foundation → meta/meta"
    fi
  done < <(find "$dir" -name "*.dart" 2>/dev/null)
done

echo ""
echo "--- Results ---"
echo "  Auto-fixed:   $changed file(s)"
echo "  Manual fixes: $manual file(s)"
echo ""

if [ "$changed" -gt 0 ]; then
  echo "--- Running flutter analyze on changed files ---"
  # Run dart format on lib/ to normalize
  cd "$REPO_ROOT"
  dart format lib/ --set-exit-if-changed 2>&1 | tail -5 || {
    echo "  (dart format reported formatting changes — re-run dart format lib/)"
  }
  echo ""
  echo "  Run 'flutter analyze' to verify zero issues."
fi

if [ "$manual" -gt 0 ]; then
  echo ""
  echo "--- Manual Fix Instructions ---"
  echo "  Files above use flutter/foundation symbols beyond @immutable."
  echo "  Options:"
  echo "    1. Move the file out of domain/ if it truly has UI/platform concerns."
  echo "    2. Replace flutter/foundation symbols with pure-Dart equivalents:"
  echo "       - kIsWeb          → pass as constructor param or use dart:io Platform"
  echo "       - Uint8List        → dart:typed_data"
  echo "       - ChangeNotifier  → remove from domain (belongs in application layer)"
  echo "       - setEquals/listEquals/mapEquals → implement inline or use collection pkg"
fi
