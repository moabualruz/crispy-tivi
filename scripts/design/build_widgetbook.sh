#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FLUTTER_DIR="$ROOT_DIR/app/flutter"
TARGET="${WIDGETBOOK_TARGET:-lib/widgetbook.dart}"
BUILD_DIR="${WIDGETBOOK_BUILD_DIR:-build/widgetbook}"

cd "$FLUTTER_DIR"

if [[ "${WIDGETBOOK_RUN_BUILD_RUNNER:-0}" == "1" ]]; then
  flutter pub run build_runner build --delete-conflicting-outputs
fi

flutter build web \
  --release \
  --target "$TARGET" \
  --output "$BUILD_DIR"

printf 'Widgetbook build: %s\n' "$FLUTTER_DIR/$BUILD_DIR"
