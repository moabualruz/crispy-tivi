#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "${ROOT_DIR}"

echo "Restoring Linux Flutter release state..."

# Linux integration tests rewrite the managed Linux Flutter config to point at
# the Flutter test listener. Regenerate the managed Linux build state before
# launching the release bundle manually.
rm -rf linux/flutter/ephemeral build/linux .dart_tool/flutter_build

flutter build linux

echo
echo "Linux release bundle rebuilt:"
echo "  ${ROOT_DIR}/build/linux/x64/release/bundle/crispy_tivi"
