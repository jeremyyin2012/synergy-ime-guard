#!/bin/bash
set -euo pipefail

LABEL="io.github.jeremyyin2012.synergy-ime-guard"
APP_DIR="$HOME/Library/Application Support/SynergyIMEGuard"
BIN_PATH="$APP_DIR/bin/synergy-ime-guard"
CONFIG_PATH="$APP_DIR/config.plist"
DOMAIN="gui/$(id -u)"
SERVICE="$DOMAIN/$LABEL"

if [[ ! -x "$BIN_PATH" || ! -f "$CONFIG_PATH" ]]; then
  echo "Synergy IME Guard is not installed." >&2
  exit 1
fi

SCREEN_NAME="$(plutil -extract ScreenName raw -o - "$CONFIG_PATH")"
SYNERGY_LOG="$(plutil -extract SynergyLogPath raw -o - "$CONFIG_PATH")"
STATE_PATH="$(plutil -extract StatePath raw -o - "$CONFIG_PATH")"

if launchctl print "$SERVICE" >/dev/null 2>&1; then
  echo "launch_agent=loaded"
else
  echo "launch_agent=not_loaded"
fi
"$BIN_PATH" check \
  --log "$SYNERGY_LOG" \
  --screen "$SCREEN_NAME" \
  --state "$STATE_PATH"
