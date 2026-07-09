#!/bin/bash
# =============================================================================
# AIUsageBar — Launch Agent Uninstaller
# =============================================================================
# 卸载 ~/Library/LaunchAgents/com.aiusagebar.app.plist
# =============================================================================

set -euo pipefail

PLIST_LABEL="com.aiusagebar.app"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"

echo ""
echo "═══════════════════════════════════════════════"
echo "  AIUsageBar — Launch Agent Uninstaller"
echo "═══════════════════════════════════════════════"
echo ""

# Unload from launchd
if [ -f "$PLIST_PATH" ]; then
    echo "📤 Unloading launch agent..."
    launchctl unload "$PLIST_PATH" 2>/dev/null && echo "   ✅ Unloaded from launchd" || echo "   ⚠️  Not currently loaded"
    rm "$PLIST_PATH"
    echo "   🗑️  Plist deleted: $PLIST_PATH"
else
    echo "   ⚠️  No plist found at $PLIST_PATH"
fi

echo ""
echo "🔍 Verification:"
if launchctl list | grep -q "$PLIST_LABEL"; then
    echo "   ⚠️  $PLIST_LABEL still registered"
else
    echo "   ✅ $PLIST_LABEL removed from launchd"
fi

echo ""
echo "═══════════════════════════════════════════════"
echo "  ✅ Auto-start disabled."
echo "═══════════════════════════════════════════════"
