#!/usr/bin/env bash
# ─────────────────────────────────────────────────────
# build_rust.sh — Cross-platform Rust FFI build script
# ─────────────────────────────────────────────────────
#
# Usage:
#   ./scripts/build_rust.sh [platform] [profile]
#
# Platforms: windows, linux, macos, android, ios, server
# Profiles:  debug, release (default: release)
#
# Examples:
#   ./scripts/build_rust.sh windows release
#   ./scripts/build_rust.sh android
#   ./scripts/build_rust.sh macos debug
#   ./scripts/build_rust.sh server
#
# Prerequisites:
#   - Rust toolchain (rustup + cargo)
#   - Platform-specific targets (see below)
#   - Android: cargo-ndk, Android NDK
#   - iOS/macOS: Xcode command line tools

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUST_DIR="$PROJECT_DIR/rust"

# ── Arguments ──────────────────────────────────────
PLATFORM="${1:-auto}"
PROFILE="${2:-release}"

if [ "$PROFILE" = "release" ]; then
  CARGO_FLAG="--release"
  CARGO_PROFILE="release"
else
  CARGO_FLAG=""
  CARGO_PROFILE="debug"
fi

# ── Auto-detect platform ──────────────────────────
if [ "$PLATFORM" = "auto" ]; then
  case "$(uname -s)" in
    Darwin)  PLATFORM="macos" ;;
    Linux)   PLATFORM="linux" ;;
    MINGW*|MSYS*|CYGWIN*) PLATFORM="windows" ;;
    *)
      echo "ERROR: Cannot auto-detect platform."
      echo "Specify: windows, linux, macos, android, ios"
      exit 1
      ;;
  esac
  echo "Auto-detected platform: $PLATFORM"
fi

# ── Build functions ────────────────────────────────

build_windows() {
  echo "==> Building crispy-ffi for Windows (x86_64)..."
  cd "$RUST_DIR"
  cargo build -p crispy-ffi $CARGO_FLAG
  echo "==> Built: target/$CARGO_PROFILE/crispy_ffi.dll"
}

build_linux() {
  echo "==> Building crispy-ffi for Linux (x86_64)..."
  cd "$RUST_DIR"
  cargo build -p crispy-ffi $CARGO_FLAG
  echo "==> Built: target/$CARGO_PROFILE/libcrispy_ffi.so"
}

build_macos() {
  echo "==> Building crispy-ffi for macOS (universal)..."
  cd "$RUST_DIR"

  # Ensure both targets are installed.
  rustup target add x86_64-apple-darwin 2>/dev/null || true
  rustup target add aarch64-apple-darwin 2>/dev/null || true

  # Build for both architectures.
  cargo build -p crispy-ffi $CARGO_FLAG \
    --target x86_64-apple-darwin
  cargo build -p crispy-ffi $CARGO_FLAG \
    --target aarch64-apple-darwin

  # Create universal binary with lipo.
  local out_dir="target/$CARGO_PROFILE"
  mkdir -p "$out_dir"
  lipo -create \
    "target/x86_64-apple-darwin/$CARGO_PROFILE/libcrispy_ffi.dylib" \
    "target/aarch64-apple-darwin/$CARGO_PROFILE/libcrispy_ffi.dylib" \
    -output "$out_dir/libcrispy_ffi.dylib"

  echo "==> Built: $out_dir/libcrispy_ffi.dylib (universal)"

  # Copy to macos/Frameworks for Xcode to pick up.
  local fw_dir="$PROJECT_DIR/macos/Frameworks"
  mkdir -p "$fw_dir"
  cp "$out_dir/libcrispy_ffi.dylib" "$fw_dir/"
  echo "==> Copied to macos/Frameworks/"
}

build_ios() {
  echo "==> Building crispy-ffi for iOS (aarch64)..."
  cd "$RUST_DIR"

  # Ensure target is installed.
  rustup target add aarch64-apple-ios 2>/dev/null || true

  # Build static library for iOS device.
  cargo build -p crispy-ffi $CARGO_FLAG \
    --target aarch64-apple-ios

  local lib_path="target/aarch64-apple-ios/$CARGO_PROFILE/libcrispy_ffi.a"
  echo "==> Built: $lib_path"

  # Copy to ios/Frameworks for Xcode to pick up.
  local fw_dir="$PROJECT_DIR/ios/Frameworks"
  mkdir -p "$fw_dir"
  cp "$lib_path" "$fw_dir/"
  echo "==> Copied to ios/Frameworks/"
}

build_android() {
  echo "==> Building crispy-ffi for Android..."
  cd "$RUST_DIR"

  # Ensure targets are installed.
  rustup target add aarch64-linux-android 2>/dev/null || true
  rustup target add armv7-linux-androideabi 2>/dev/null || true
  rustup target add x86_64-linux-android 2>/dev/null || true

  local jni_dir="$PROJECT_DIR/android/app/src/main/jniLibs"

  # Use cargo-ndk for cross-compilation.
  cargo ndk \
    -t aarch64-linux-android \
    -t armv7-linux-androideabi \
    -t x86_64-linux-android \
    -o "$jni_dir" \
    build -p crispy-ffi --release

  echo "==> Built Android native libs in $jni_dir"
  ls -la "$jni_dir"/*/libcrispy_ffi.so 2>/dev/null || true
}

build_server() {
  echo "==> Building crispy-server..."
  cd "$RUST_DIR"
  cargo build -p crispy-server $CARGO_FLAG
  echo "==> Built: target/$CARGO_PROFILE/crispy-server"
}

# ── Execute ────────────────────────────────────────

case "$PLATFORM" in
  windows) build_windows ;;
  linux)   build_linux ;;
  macos)   build_macos ;;
  ios)     build_ios ;;
  android) build_android ;;
  server)  build_server ;;
  all)
    build_windows
    build_linux
    build_server
    echo ""
    echo "NOTE: macOS, iOS, and Android require"
    echo "platform-specific hosts to build."
    ;;
  *)
    echo "ERROR: Unknown platform '$PLATFORM'"
    echo "Valid: windows, linux, macos, ios, android, server, all"
    exit 1
    ;;
esac

echo ""
echo "==> Rust build complete ($PLATFORM, $PROFILE)"
