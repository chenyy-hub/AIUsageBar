#!/bin/bash
# =============================================================================
# AIUsageBar — Release Build Script
# =============================================================================
# 用法:
#   ./Scripts/build_release.sh            # 构建到 build/release/
#   ./Scripts/build_release.sh --install  # 构建 + 复制到 /Applications
#   ./Scripts/build_release.sh --clean    # 清理构建产物
# =============================================================================

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="AIUsageBar"
BUILD_DIR="$PROJECT_DIR/build"
RELEASE_DIR="$BUILD_DIR/release"
APP_BUNDLE="$RELEASE_DIR/$APP_NAME.app"
RESOURCES_DIR="$PROJECT_DIR/Resources"

# Parse args
INSTALL=false
CLEAN=false
for arg in "$@"; do
    case "$arg" in
        --install) INSTALL=true ;;
        --clean)   CLEAN=true   ;;
    esac
done

# ----- Clean -----
if $CLEAN; then
    echo "🧹 Cleaning build artifacts..."
    rm -rf "$BUILD_DIR"
    rm -rf "$PROJECT_DIR/.build"
    echo "Done."
    exit 0
fi

echo ""
echo "═══════════════════════════════════════════════"
echo "  AIUsageBar Release Build"
echo "═══════════════════════════════════════════════"
echo ""

# Step 1: Build
echo "📦 Step 1: Building release binary..."
cd "$PROJECT_DIR"
swift build --configuration release
echo "✅ Build complete."
echo ""

# Step 2: Create App Bundle
echo "📁 Step 2: Creating .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

BINARY="$PROJECT_DIR/.build/release/$APP_NAME"
if [ ! -f "$BINARY" ]; then
    echo "❌ Error: Binary not found at $BINARY"
    echo "   Build may have failed or path is wrong."
    exit 1
fi

cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$RESOURCES_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
echo "✅ Bundle structure created."
echo ""

# Step 3: Copy Resources
echo "🎨 Step 3: Copying resources..."
if [ -f "$RESOURCES_DIR/AppIcon.icns" ]; then
    cp "$RESOURCES_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    echo "   AppIcon.icns → copied."
else
    echo "   ⚠️  No AppIcon.icns found. App will use default icon."
fi
echo "✅ Resources copied."
echo ""

# Step 4: Code Sign
echo "🔑 Step 4: Code signing..."
SIGN_SCRIPT="$PROJECT_DIR/Scripts/sign_app.sh"
if [ -f "$SIGN_SCRIPT" ]; then
    bash "$SIGN_SCRIPT" "$APP_BUNDLE" || true
else
    echo "   ⚠️  sign_app.sh not found. Skipping signature."
fi
echo ""

# Step 5: Verify
echo "🔍 Step 5: Verification..."
if [ -d "$APP_BUNDLE" ]; then
    BUNDLE_SIZE=$(du -sh "$APP_BUNDLE" | cut -f1)
    echo "   Bundle: $APP_BUNDLE"
    echo "   Size:   $BUNDLE_SIZE"
    echo "   ✅ App bundle created successfully."
else
    echo "   ❌ Error: Bundle not found at $APP_BUNDLE"
    exit 1
fi
echo ""

# ----- Install to /Applications -----
if $INSTALL; then
    echo "📥 Installing to /Applications..."
    INSTALL_PATH="/Applications/$APP_NAME.app"
    rm -rf "$INSTALL_PATH"
    ditto "$APP_BUNDLE" "$INSTALL_PATH"
    echo "✅ Installed to $INSTALL_PATH"
    echo "   Run: open \"$INSTALL_PATH\""
fi

echo "═══════════════════════════════════════════════"
echo "  ✅ Release Build Complete"
echo "  📍 $APP_BUNDLE"
echo "═══════════════════════════════════════════════"
