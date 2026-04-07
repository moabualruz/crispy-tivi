#!/usr/bin/env bash
# Launch CrispyTivi with jemalloc preloaded.
# Fixes media_kit glibc arena retention (issue media-kit#68).
# Without this, freed video buffers stay in glibc malloc arenas
# and RSS never decreases after playback.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/../build/linux/x64/release/bundle"

# Find jemalloc — check common locations
JEMALLOC=""
for lib in \
  /usr/lib/libjemalloc.so.2 \
  /usr/lib/x86_64-linux-gnu/libjemalloc.so.2 \
  /usr/lib64/libjemalloc.so.2 \
  /usr/local/lib/libjemalloc.so; do
  if [ -f "$lib" ]; then
    JEMALLOC="$lib"
    break
  fi
done

if [ -n "$JEMALLOC" ]; then
  echo "Using jemalloc: $JEMALLOC"
  LD_PRELOAD="$JEMALLOC" exec "$APP_DIR/crispy_tivi" "$@"
else
  echo "jemalloc not found — running without it (install: sudo pacman -S jemalloc)"
  exec "$APP_DIR/crispy_tivi" "$@"
fi
