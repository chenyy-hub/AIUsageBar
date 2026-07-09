#!/bin/bash
# =============================================================================
# AIUsageBar — Code Signing Script
# =============================================================================
# 智能检测签名身份：
#   1. Apple Developer ID Application (distribute outside App Store)
#   2. Mac Developer / Apple Development (local development)
#   3. Ad-hoc signing (fallback)
#
# 用法:
#   ./Scripts/sign_app.sh                    # 签名 build/release/AIUsageBar.app
#   ./Scripts/sign_app.sh /path/to/App.app   # 签名指定路径
# =============================================================================

set -euo pipefail

APP_PATH="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."

# If no argument, use default release path
if [ -z "$APP_PATH" ]; then
    APP_PATH="$PROJECT_DIR/build/release/AIUsageBar.app"
fi

echo ""
echo "═══════════════════════════════════════════════"
echo "  AIUsageBar — Code Signing"
echo "═══════════════════════════════════════════════"
echo ""

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: App not found at: $APP_PATH"
    echo "   Run ./Scripts/build_release.sh first."
    exit 1
fi

echo "📦 App: $APP_PATH"
echo ""

# Detect signing identity (priority order)
IDENTITY=""
SIGN_ARGS="--force --deep --options runtime"

# 1. Check for Apple Developer ID Application (production distribution)
ID_APPLE_DEV_ID=$(security find-identity -v -p basic 2>/dev/null | grep "Developer ID Application" | head -1 | awk '{print $2}' || true)
if [ -n "$ID_APPLE_DEV_ID" ]; then
    IDENTITY="$ID_APPLE_DEV_ID"
    echo "🔑 Found: Developer ID Application (production)"
fi

# 2. Fallback to Mac Developer (development)
if [ -z "$IDENTITY" ]; then
    ID_MAC_DEV=$(security find-identity -v -p basic 2>/dev/null | grep "Mac Developer" | head -1 | awk '{print $2}' || true)
    if [ -n "$ID_MAC_DEV" ]; then
        IDENTITY="$ID_MAC_DEV"
        echo "🔑 Found: Mac Developer (development)"
    fi
fi

# 3. Fallback to Apple Development
if [ -z "$IDENTITY" ]; then
    ID_APPLE_DEV=$(security find-identity -v -p basic 2>/dev/null | grep "Apple Development" | head -1 | awk '{print $2}' || true)
    if [ -n "$ID_APPLE_DEV" ]; then
        IDENTITY="$ID_APPLE_DEV"
        echo "🔑 Found: Apple Development (development)"
    fi
fi

# Code sign
if [ -n "$IDENTITY" ]; then
    echo ""
    echo "✍️  Signing with identity: $IDENTITY"
    codesign $SIGN_ARGS --sign "$IDENTITY" "$APP_PATH"
    echo "✅ Code signing complete."
else
    echo "⚠️  No code signing identity found."
    echo "   Attempting ad-hoc signing... (may still trigger Gatekeeper)"
    codesign $SIGN_ARGS --sign - "$APP_PATH" 2>/dev/null && echo "✅ Ad-hoc signing complete." || echo "   ⚠️  Ad-hoc signing not possible."
fi

echo ""

# Verify
echo "🔍 Verification:"
codesign --verify --verbose "$APP_PATH" 2>&1 || {
    echo "   ⚠️  Code signing verification returned non-zero."
    echo "   The app may still work, but Gatekeeper may block it."
}

echo ""
echo "═══════════════════════════════════════════════"
echo "  ✅ Signing Complete"
echo "═══════════════════════════════════════════════"
