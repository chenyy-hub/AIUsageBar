#!/bin/bash
# =============================================================================
# AIUsageBar Build Script
# =============================================================================
# Builds AIUsageBar.app from Swift source and copies to /Applications.
#
# Usage:
#   ./Scripts/build.sh            # Build to ~/Desktop/AIUsageBar.app
#   ./Scripts/build.sh --install  # Build + copy to /Applications
#   ./Scripts/build.sh --clean    # Clean build artifacts
# =============================================================================

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="AIUsageBar"
BUILD_DIR="$PROJECT_DIR/.build"
RESOURCES_DIR="$PROJECT_DIR/Resources"

# ----- Parse args -----
INSTALL=false
CLEAN=false
for arg in "$@"; do
    case "$arg" in
        --install) INSTALL=true ;;
        --clean)   CLEAN=true ;;
    esac
done

if $CLEAN; then
    echo "🧹 Cleaning build artifacts..."
    rm -rf "$BUILD_DIR"
    echo "Done."
    exit 0
fi

echo "🏗️  Building $APP_NAME..."
cd "$PROJECT_DIR"

# Build with SwiftPM
swift build \
    --configuration release \
    --build-path "$BUILD_DIR" \
    --product "$APP_NAME" \
    -Xlinker -rpath -Xlinker /usr/lib/swift

BINARY="$BUILD_DIR/release/$APP_NAME"
if [ ! -f "$BINARY" ]; then
    echo "❌ Build failed: binary not found at $BINARY"
    exit 1
fi
echo "✅ Build succeeded."

# ----- Create .app bundle -----
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
rm -rf "$APP_BUNDLE"

mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$RESOURCES_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Create app icon (using a system icon as placeholder)
mkdir -p "$APP_BUNDLE/Contents/Resources/AppIcon.icns" 2>/dev/null || true

# Codesign (required for menu bar apps)
CODESIGN_IDENTITY=""
if CODESIGN_IDENTITY=$(security find-identity -v -p basic 2>/dev/null | grep -E 'Apple Development|Mac Developer' | head -1 | awk '{print $2}'); then
    echo "🔑 Signing with identity: $CODESIGN_IDENTITY"
    codesign --force --sign "$CODESIGN_IDENTITY" \
             --options runtime \
             --entitlements /dev/null \
             "$APP_BUNDLE"
    echo "✅ Signed."
else
    echo "⚠️  No signing identity found. App may show gatekeeper warning."
    echo "   Run manually: codesign --force --deep --sign \"<identity>\" \"$APP_BUNDLE\""
fi

# ----- Install / Deploy -----
if $INSTALL; then
    INSTALL_PATH="/Applications/$APP_NAME.app"
    rm -rf "$INSTALL_PATH"
    cp -R "$APP_BUNDLE" "$INSTALL_PATH"
    echo "📦 Installed to $INSTALL_PATH"
    echo ""
    echo "🟢 按住 ⌘ 拖拽 AIUsageBar 到菜单栏即可使用"
    echo "   或直接打开: open '$INSTALL_PATH'"
    open "$INSTALL_PATH"
else
    DEST="$HOME/Desktop/$APP_NAME.app"
    rm -rf "$DEST"
    cp -R "$APP_BUNDLE" "$DEST"
    echo "📦 Copied to $DEST"
    echo ""
    echo "Run: open '$DEST'"
    open "$DEST"
fi

echo "🎉 Done."
