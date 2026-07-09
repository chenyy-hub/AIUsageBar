#!/bin/bash
# =============================================================================
# AIUsageBar — Launch Agent Installer
# =============================================================================
# 安装 ~/Library/LaunchAgents/com.aiusagebar.app.plist
# 实现用户登录后自动启动 AIUsageBar
#
# 用法:
#   ./Scripts/install_launch_agent.sh    # 安装
#   ./Scripts/uninstall_launch_agent.sh  # 卸载
# =============================================================================

set -euo pipefail

APP_NAME="AIUsageBar"
APP_PATH="/Applications/$APP_NAME.app"
PLIST_LABEL="com.aiusagebar.app"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$PLIST_DIR/$PLIST_LABEL.plist"

echo ""
echo "═══════════════════════════════════════════════"
echo "  AIUsageBar — Launch Agent Installer"
echo "═══════════════════════════════════════════════"
echo ""

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo "⚠️  $APP_NAME not found in /Applications."
    echo "   Building and installing..."

    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    cd "$SCRIPT_DIR/.."

    if [ -f "Scripts/build_release.sh" ]; then
        bash Scripts/build_release.sh --install
    else
        echo "❌ Error: build_release.sh not found."
        echo "   Please run from the AIUsageBar project directory."
        exit 1
    fi
fi

# Check again
if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: $APP_PATH still not found after build."
    exit 1
fi

# Create plist
mkdir -p "$PLIST_DIR"

cat > "$PLIST_PATH" << PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_LABEL}</string>

    <key>ProgramArguments</key>
    <array>
        <string>open</string>
        <string>${APP_PATH}</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <false/>

    <key>StandardOutPath</key>
    <string>${HOME}/Library/Logs/${APP_NAME}.stdout.log</string>

    <key>StandardErrorPath</key>
    <string>${HOME}/Library/Logs/${APP_NAME}.stderr.log</string>
</dict>
</plist>
PLISTEOF

echo "📄 Plist created: $PLIST_PATH"

# Load the launch agent
launchctl load "$PLIST_PATH" 2>/dev/null || {
    # If already loaded, unload and reload
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
    launchctl load "$PLIST_PATH"
}

echo "✅ Launch agent loaded."
echo ""

# Verify
echo "🔍 Verification:"
launchctl list | grep "$PLIST_LABEL" && echo "   ✅ $APP_NAME registered in launchd" || echo "   ⚠️  Not found in launchctl list"

# Optional: start now
echo ""
echo "🚀 Starting $APP_NAME..."
open "$APP_PATH"
echo "✅ $APP_NAME launched."

echo ""
echo "═══════════════════════════════════════════════"
echo "  ✅ $APP_NAME auto-start is now active."
echo "  📍 $PLIST_PATH"
echo "  🔄 Will start automatically at next login."
echo "═══════════════════════════════════════════════"
