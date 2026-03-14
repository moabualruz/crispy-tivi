#!/usr/bin/env bash
# Build an AppImage from the Flutter Linux release bundle.
# Usage: bash scripts/build_appimage.sh <version>
set -euo pipefail

VERSION="${1:?Usage: build_appimage.sh <version>}"
APP_DIR="CrispyTivi.AppDir"
BUNDLE_DIR="build/linux/x64/release/bundle"
TOOL_URL="https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"

if [ ! -d "$BUNDLE_DIR" ]; then
  echo "ERROR: Flutter Linux bundle not found at $BUNDLE_DIR"
  echo "Run 'flutter build linux --release' first."
  exit 1
fi

# Clean previous AppDir
rm -rf "$APP_DIR"

# Create AppDir structure
mkdir -p "$APP_DIR/usr/bin"
mkdir -p "$APP_DIR/usr/lib"
mkdir -p "$APP_DIR/usr/share/icons/hicolor/256x256/apps"

# Copy bundle contents
cp -r "$BUNDLE_DIR"/* "$APP_DIR/usr/bin/"

# Move shared libs to usr/lib if present
if [ -d "$APP_DIR/usr/bin/lib" ]; then
  mv "$APP_DIR/usr/bin/lib"/* "$APP_DIR/usr/lib/" 2>/dev/null || true
  rmdir "$APP_DIR/usr/bin/lib" 2>/dev/null || true
fi

# Create .desktop file
cat > "$APP_DIR/crispy_tivi.desktop" << EOF
[Desktop Entry]
Type=Application
Name=CrispyTivi
Comment=Cross-platform media streaming
Exec=crispy_tivi
Icon=crispy_tivi
Terminal=false
Categories=AudioVideo;Video;Player;
EOF

# Copy icon (fallback to a placeholder if not found)
if [ -f "assets/icons/app_icon.png" ]; then
  cp "assets/icons/app_icon.png" "$APP_DIR/crispy_tivi.png"
  cp "assets/icons/app_icon.png" \
    "$APP_DIR/usr/share/icons/hicolor/256x256/apps/crispy_tivi.png"
else
  echo "WARNING: No icon found at assets/icons/app_icon.png"
  # Create minimal 1x1 PNG placeholder
  printf '\x89PNG\r\n\x1a\n' > "$APP_DIR/crispy_tivi.png"
fi

# Create AppRun
cat > "$APP_DIR/AppRun" << 'APPRUN'
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH:-}"
exec "${HERE}/usr/bin/crispy_tivi" "$@"
APPRUN
chmod +x "$APP_DIR/AppRun"

# Download appimagetool if not present
if [ ! -f "appimagetool-x86_64.AppImage" ]; then
  echo "Downloading appimagetool..."
  curl -fsSL -o appimagetool-x86_64.AppImage "$TOOL_URL"
  chmod +x appimagetool-x86_64.AppImage
fi

# Build AppImage
ARCH=x86_64 ./appimagetool-x86_64.AppImage "$APP_DIR" \
  "CrispyTivi-${VERSION}-x86_64.AppImage"

chmod +x "CrispyTivi-${VERSION}-x86_64.AppImage"

# Cleanup
rm -rf "$APP_DIR"

echo "AppImage created: CrispyTivi-${VERSION}-x86_64.AppImage"
