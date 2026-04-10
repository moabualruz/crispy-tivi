#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FLUTTER_DIR="$ROOT_DIR/app/flutter"
BUILD_DIR="${WIDGETBOOK_BUILD_DIR:-build/widgetbook}"
HOST="${WIDGETBOOK_HOST:-127.0.0.1}"
PORT="${WIDGETBOOK_PORT:-3100}"

if [[ ! -f "$FLUTTER_DIR/$BUILD_DIR/index.html" ]]; then
  "$ROOT_DIR/scripts/design/build_widgetbook.sh"
fi

cd "$ROOT_DIR"
exec npx -y http-server "$FLUTTER_DIR/$BUILD_DIR" \
  -p "$PORT" \
  -a "$HOST" \
  -c-1 \
  --cors
