#!/bin/bash
set -euo pipefail

BIN_DIR="${LIDWATCH_BIN_DIR:-$HOME/.local/bin}"
BINARY_DEST="$BIN_DIR/lidwatch"
AGENT_LABEL="com.lidwatch.agent"
PLIST_DEST="$HOME/Library/LaunchAgents/$AGENT_LABEL.plist"
LOG_PATH="$HOME/Library/Logs/lidwatch.log"
STATE_DIR="$HOME/Library/Application Support/lidwatch"

if [ -f "$PLIST_DEST" ]; then
    echo ":: unloading LaunchAgent"
    launchctl unload "$PLIST_DEST" 2>/dev/null || true
    rm -f "$PLIST_DEST"
fi

if [ -x "$BINARY_DEST" ]; then
    echo ":: removing binary $BINARY_DEST"
    rm -f "$BINARY_DEST"
fi

if [ -d "$STATE_DIR" ]; then
    echo ":: removing state directory $STATE_DIR"
    rm -rf "$STATE_DIR"
fi

if [ -f "$LOG_PATH" ]; then
    echo ":: removing log $LOG_PATH"
    rm -f "$LOG_PATH"
fi

echo "✅ uninstalled."
