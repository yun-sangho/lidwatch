#!/bin/bash
set -euo pipefail

# lidwatch installer — builds from source and installs a LaunchAgent for
# the current user. No sudo required; everything lives under $HOME.

HERE="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${LIDWATCH_BIN_DIR:-$HOME/.local/bin}"
BINARY_DEST="$BIN_DIR/lidwatch"
AGENT_LABEL="com.lidwatch.agent"
PLIST_DEST="$HOME/Library/LaunchAgents/$AGENT_LABEL.plist"
LOG_PATH="$HOME/Library/Logs/lidwatch.log"

echo ":: building lidwatch (release, universal)..."
cd "$HERE"
swift build -c release --arch arm64 --arch x86_64

BUILT="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/lidwatch"
if [ ! -x "$BUILT" ]; then
    echo "error: built binary not found at $BUILT"
    exit 1
fi

echo ":: installing binary to $BINARY_DEST"
mkdir -p "$BIN_DIR"
install -m 755 "$BUILT" "$BINARY_DEST"

echo ":: writing LaunchAgent plist to $PLIST_DEST"
mkdir -p "$(dirname "$PLIST_DEST")"
sed \
    -e "s|__BINARY_PATH__|$BINARY_DEST|g" \
    -e "s|__LOG_PATH__|$LOG_PATH|g" \
    "$HERE/$AGENT_LABEL.plist.template" > "$PLIST_DEST"

echo ":: loading LaunchAgent"
launchctl unload "$PLIST_DEST" 2>/dev/null || true
launchctl load "$PLIST_DEST"

cat <<EOF

✅ installed. Enabled by default.

  binary:  $BINARY_DEST
  plist:   $PLIST_DEST
  logs:    $LOG_PATH

try:
  $BINARY_DEST status          # current state
  $BINARY_DEST disable         # stop acting on lid close
  $BINARY_DEST enable          # resume
  tail -f "$LOG_PATH"          # watch events live

If \$HOME/.local/bin is not in your PATH, either add it or run the
binary with its full path.
EOF
