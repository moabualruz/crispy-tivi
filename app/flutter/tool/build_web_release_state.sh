#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
FLUTTER_DIR="$ROOT_DIR/app/flutter"
RUST_FFI_DIR="$ROOT_DIR/rust/crates/crispy-ffi"
WEB_BUILD_DIR="$FLUTTER_DIR/build/web"
WASM_OUT_DIR="$WEB_BUILD_DIR/pkg"
WASM_PACK_BIN="${WASM_PACK_BIN:-$HOME/.cargo/bin/wasm-pack}"

if [[ ! -x "$WASM_PACK_BIN" ]]; then
  echo "wasm-pack not found at $WASM_PACK_BIN" >&2
  exit 1
fi

echo "Building Flutter web release..."
(cd "$FLUTTER_DIR" && flutter build web)

echo "Rebuilding Rust wasm package for flutter_rust_bridge web runtime..."
rm -rf "$WASM_OUT_DIR"
(cd "$RUST_FFI_DIR" && "$WASM_PACK_BIN" build \
  --target no-modules \
  --out-dir "../../../app/flutter/build/web/pkg" \
  --out-name crispy_ffi)

echo
echo "Web release bundle rebuilt:"
echo "  $WEB_BUILD_DIR"
