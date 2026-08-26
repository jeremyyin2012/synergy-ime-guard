#!/bin/bash
set -euo pipefail

LABEL="io.github.jeremyyin2012.synergy-ime-guard"
APP_DIR="$HOME/Library/Application Support/SynergyIMEGuard"
BIN_PATH="$APP_DIR/bin/synergy-ime-guard"
CONFIG_PATH="$APP_DIR/config.plist"
STATE_PATH="$APP_DIR/state/restore.json"
LOG_DIR="$HOME/Library/Logs/SynergyIMEGuard"
PLIST_PATH="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"
SERVICE="$DOMAIN/$LABEL"
KEEP_LOGS=false

if [[ "${1:-}" == "--keep-logs" ]]; then
  KEEP_LOGS=true
elif [[ $# -gt 0 ]]; then
  echo "Usage: ./uninstall.sh [--keep-logs]" >&2
  exit 2
fi

if [[ "$(uname -s)" != "Darwin" || "$(id -u)" -eq 0 ]]; then
  echo "Run this uninstaller as the installed macOS user, without sudo." >&2
  exit 1
fi

if [[ -f "$CONFIG_PATH" ]]; then
  SCREEN_NAME="$(plutil -extract ScreenName raw -o - "$CONFIG_PATH")"
  SYNERGY_LOG="$(plutil -extract SynergyLogPath raw -o - "$CONFIG_PATH")"
  CONFIGURED_STATE="$(plutil -extract StatePath raw -o - "$CONFIG_PATH")"
  if [[ "$CONFIGURED_STATE" != "$STATE_PATH" ]]; then
    echo "Refusing to remove an installation with an unexpected state path." >&2
    exit 1
  fi

  launchctl kill SIGTERM "$SERVICE" >/dev/null 2>&1 || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    [[ ! -f "$STATE_PATH" ]] && break
    sleep 0.1
  done
  launchctl bootout "$SERVICE" >/dev/null 2>&1 || true

  if [[ -f "$STATE_PATH" && -x "$BIN_PATH" ]]; then
    "$BIN_PATH" once enter \
      --log "$SYNERGY_LOG" \
      --screen "$SCREEN_NAME" \
      --state "$STATE_PATH"
  fi
fi

if [[ -f "$STATE_PATH" ]]; then
  echo "Uninstall stopped: the saved input source could not be restored." >&2
  echo "The state and executable were preserved for another retry." >&2
  exit 1
fi

launchctl bootout "$SERVICE" >/dev/null 2>&1 || true
rm -f "$PLIST_PATH"
case "$APP_DIR" in
  "$HOME/Library/Application Support/SynergyIMEGuard") rm -rf "$APP_DIR" ;;
  *) echo "Unexpected application path; refusing removal." >&2; exit 1 ;;
esac
if [[ "$KEEP_LOGS" == false ]]; then
  case "$LOG_DIR" in
    "$HOME/Library/Logs/SynergyIMEGuard") rm -rf "$LOG_DIR" ;;
    *) echo "Unexpected log path; refusing removal." >&2; exit 1 ;;
  esac
fi

echo "Synergy IME Guard was uninstalled."
