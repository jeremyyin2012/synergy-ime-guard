#!/bin/bash
set -euo pipefail

LABEL="io.github.jeremyyin2012.synergy-ime-guard"
APP_DIR="$HOME/Library/Application Support/SynergyIMEGuard"
BIN_DIR="$APP_DIR/bin"
BIN_PATH="$BIN_DIR/synergy-ime-guard"
TOOLS_DIR="$APP_DIR/scripts"
STATE_DIR="$APP_DIR/state"
STATE_PATH="$STATE_DIR/restore.json"
CONFIG_PATH="$APP_DIR/config.plist"
LOG_DIR="$HOME/Library/Logs/SynergyIMEGuard"
SYNERGY_LOG="$HOME/Library/Logs/Synergy/synergy.log"
PLIST_PATH="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"
SERVICE="$DOMAIN/$LABEL"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_BINARY="$SCRIPT_DIR/synergy-ime-guard"
STAGING_DIR=""
BACKUP_DIR=""

usage() {
  cat <<'EOF'
Usage: ./install.sh [--binary PATH] [--synergy-log PATH]

Installs Synergy IME Guard for the current macOS user. Synergy must be running,
ABC must be available, and Synergy language synchronization must be disabled.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --binary)
      [[ $# -ge 2 ]] || { echo "--binary requires a path" >&2; exit 2; }
      SOURCE_BINARY="$2"
      shift 2
      ;;
    --synergy-log)
      [[ $# -ge 2 ]] || { echo "--synergy-log requires a path" >&2; exit 2; }
      SYNERGY_LOG="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

cleanup() {
  if [[ -n "$STAGING_DIR" && -d "$STAGING_DIR" ]]; then
    rm -rf "$STAGING_DIR"
  fi
}
trap cleanup EXIT

wait_for_service_exit() {
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    if ! launchctl print "$SERVICE" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.1
  done
  return 1
}

bootstrap_agent() {
  local plist="$1"
  local attempt
  for attempt in 1 2 3; do
    if launchctl bootstrap "$DOMAIN" "$plist"; then
      return 0
    fi
    launchctl bootout "$SERVICE" >/dev/null 2>&1 || true
    wait_for_service_exit || true
    sleep 0.3
  done
  return 1
}

restore_previous_install() {
  launchctl kill SIGTERM "$SERVICE" >/dev/null 2>&1 || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    [[ ! -f "$STATE_PATH" ]] && break
    sleep 0.1
  done
  launchctl bootout "$SERVICE" >/dev/null 2>&1 || true
  wait_for_service_exit || true
  if [[ -f "$STATE_PATH" && -x "$BIN_PATH" ]]; then
    "$BIN_PATH" once enter \
      --log "$SYNERGY_LOG" \
      --screen "$SCREEN_NAME" \
      --state "$STATE_PATH" || true
  fi
  if [[ -f "$STATE_PATH" ]]; then
    echo "Rollback paused because the saved input source could not be restored." >&2
    echo "The current binary and state were preserved for retry." >&2
    return 1
  fi
  if [[ -f "$BACKUP_DIR/binary" ]]; then
    mkdir -p "$BIN_DIR"
    cp "$BACKUP_DIR/binary" "$BIN_PATH"
    chmod 0755 "$BIN_PATH"
  else
    rm -f "$BIN_PATH"
  fi
  if [[ -f "$BACKUP_DIR/config.plist" ]]; then
    cp "$BACKUP_DIR/config.plist" "$CONFIG_PATH"
    chmod 0600 "$CONFIG_PATH"
  else
    rm -f "$CONFIG_PATH"
  fi
  if [[ -d "$BACKUP_DIR/scripts" ]]; then
    mkdir -p "$TOOLS_DIR"
    rm -f "$TOOLS_DIR/status.sh" "$TOOLS_DIR/uninstall.sh"
    for tool in status.sh uninstall.sh; do
      if [[ -f "$BACKUP_DIR/scripts/$tool" ]]; then
        cp "$BACKUP_DIR/scripts/$tool" "$TOOLS_DIR/$tool"
        chmod 0755 "$TOOLS_DIR/$tool"
      fi
    done
  fi
  if [[ -f "$BACKUP_DIR/agent.plist" ]]; then
    cp "$BACKUP_DIR/agent.plist" "$PLIST_PATH"
    chmod 0600 "$PLIST_PATH"
    if ! bootstrap_agent "$PLIST_PATH"; then
      echo "The previous files were restored, but its LaunchAgent could not be reactivated." >&2
      return 1
    fi
  else
    rm -f "$PLIST_PATH"
  fi
  return 0
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Synergy IME Guard can only be installed on macOS." >&2
  exit 1
fi
if [[ "$(id -u)" -eq 0 ]]; then
  echo "Do not run this installer with sudo or as root." >&2
  exit 1
fi
if ! launchctl print "$DOMAIN" >/dev/null 2>&1; then
  echo "No active Aqua launchd session was found for the current user." >&2
  exit 1
fi
if [[ ! -x "$SOURCE_BINARY" ]]; then
  echo "Executable not found: $SOURCE_BINARY" >&2
  exit 1
fi

CURRENT_ARCH="$(uname -m)"
BINARY_INFO="$(/usr/bin/file "$SOURCE_BINARY")"
if [[ "$BINARY_INFO" != *"Mach-O"* || "$BINARY_INFO" != *"$CURRENT_ARCH"* ]]; then
  echo "The binary is not compatible with this Mac ($CURRENT_ARCH)." >&2
  exit 1
fi
codesign --verify "$SOURCE_BINARY"

DISCOVERY="$("$SOURCE_BINARY" discover)" || {
  echo "Synergy must be running with exactly one synergy-core process." >&2
  exit 1
}
SCREEN_NAME="$(printf '%s' "$DISCOVERY" | plutil -extract screenName raw -o - -)"
SYNC_LANGUAGE="$(printf '%s' "$DISCOVERY" | plutil -extract syncLanguage raw -o - -)"
if [[ -z "$SCREEN_NAME" ]]; then
  echo "Could not discover this Mac's Synergy screen name." >&2
  exit 1
fi
if [[ "$SYNC_LANGUAGE" == "true" ]]; then
  echo "Disable Synergy language synchronization before installing." >&2
  exit 1
fi

STAGING_DIR="$(mktemp -d "${TMPDIR%/}/synergy-ime-guard.install.XXXXXX")"
BACKUP_DIR="$STAGING_DIR/backup"
mkdir -p "$BACKUP_DIR" "$STAGING_DIR/new"
cp "$SOURCE_BINARY" "$STAGING_DIR/new/synergy-ime-guard"
chmod 0755 "$STAGING_DIR/new/synergy-ime-guard"
if [[ ! -f "$SCRIPT_DIR/status.sh" || ! -f "$SCRIPT_DIR/uninstall.sh" ]]; then
  echo "status.sh and uninstall.sh must be next to install.sh." >&2
  exit 1
fi
cp "$SCRIPT_DIR/status.sh" "$STAGING_DIR/new/status.sh"
cp "$SCRIPT_DIR/uninstall.sh" "$STAGING_DIR/new/uninstall.sh"
chmod 0755 "$STAGING_DIR/new/"*.sh

CHECK_REPORT="$($STAGING_DIR/new/synergy-ime-guard check \
  --log "$SYNERGY_LOG" \
  --screen "$SCREEN_NAME" \
  --state "$STAGING_DIR/preflight-state.json")"
ABC_AVAILABLE="$(printf '%s' "$CHECK_REPORT" | plutil -extract abcAvailable raw -o - -)"
if [[ "$ABC_AVAILABLE" != "true" ]]; then
  echo "The macOS ABC input source is not available." >&2
  exit 1
fi

plutil -create xml1 "$STAGING_DIR/new/config.plist"
plutil -insert ScreenName -string "$SCREEN_NAME" "$STAGING_DIR/new/config.plist"
plutil -insert SynergyLogPath -string "$SYNERGY_LOG" "$STAGING_DIR/new/config.plist"
plutil -insert StatePath -string "$STATE_PATH" "$STAGING_DIR/new/config.plist"
plutil -insert Version -string "$("$SOURCE_BINARY" version)" "$STAGING_DIR/new/config.plist"

plutil -create xml1 "$STAGING_DIR/new/agent.plist"
plutil -insert Label -string "$LABEL" "$STAGING_DIR/new/agent.plist"
plutil -insert ProgramArguments -array "$STAGING_DIR/new/agent.plist"
plutil -insert ProgramArguments.0 -string "$BIN_PATH" "$STAGING_DIR/new/agent.plist"
plutil -insert ProgramArguments.1 -string run "$STAGING_DIR/new/agent.plist"
plutil -insert ProgramArguments.2 -string --log "$STAGING_DIR/new/agent.plist"
plutil -insert ProgramArguments.3 -string "$SYNERGY_LOG" "$STAGING_DIR/new/agent.plist"
plutil -insert ProgramArguments.4 -string --screen "$STAGING_DIR/new/agent.plist"
plutil -insert ProgramArguments.5 -string "$SCREEN_NAME" "$STAGING_DIR/new/agent.plist"
plutil -insert ProgramArguments.6 -string --state "$STAGING_DIR/new/agent.plist"
plutil -insert ProgramArguments.7 -string "$STATE_PATH" "$STAGING_DIR/new/agent.plist"
plutil -insert RunAtLoad -bool true "$STAGING_DIR/new/agent.plist"
plutil -insert KeepAlive -dictionary "$STAGING_DIR/new/agent.plist"
plutil -insert KeepAlive.SuccessfulExit -bool false "$STAGING_DIR/new/agent.plist"
plutil -insert LimitLoadToSessionType -string Aqua "$STAGING_DIR/new/agent.plist"
plutil -insert ProcessType -string Background "$STAGING_DIR/new/agent.plist"
plutil -insert ThrottleInterval -integer 2 "$STAGING_DIR/new/agent.plist"
plutil -insert Umask -integer 63 "$STAGING_DIR/new/agent.plist"
plutil -insert StandardOutPath -string "$LOG_DIR/guard.log" "$STAGING_DIR/new/agent.plist"
plutil -insert StandardErrorPath -string "$LOG_DIR/guard-error.log" "$STAGING_DIR/new/agent.plist"
plutil -lint "$STAGING_DIR/new/agent.plist" >/dev/null

mkdir -p "$BIN_DIR" "$TOOLS_DIR" "$STATE_DIR" "$LOG_DIR" "$HOME/Library/LaunchAgents"
chmod 0700 "$APP_DIR" "$BIN_DIR" "$TOOLS_DIR" "$STATE_DIR" "$LOG_DIR"

[[ -f "$BIN_PATH" ]] && cp "$BIN_PATH" "$BACKUP_DIR/binary"
[[ -f "$CONFIG_PATH" ]] && cp "$CONFIG_PATH" "$BACKUP_DIR/config.plist"
[[ -f "$PLIST_PATH" ]] && cp "$PLIST_PATH" "$BACKUP_DIR/agent.plist"
if [[ -d "$TOOLS_DIR" ]]; then
  mkdir -p "$BACKUP_DIR/scripts"
  for tool in status.sh uninstall.sh; do
    [[ -f "$TOOLS_DIR/$tool" ]] && cp "$TOOLS_DIR/$tool" "$BACKUP_DIR/scripts/$tool"
  done
fi

if [[ -f "$PLIST_PATH" ]]; then
  launchctl kill SIGTERM "$SERVICE" >/dev/null 2>&1 || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    [[ ! -f "$STATE_PATH" ]] && break
    sleep 0.1
  done
  launchctl bootout "$SERVICE" >/dev/null 2>&1 || true
  wait_for_service_exit || true
  if [[ -f "$STATE_PATH" && -x "$BIN_PATH" && -f "$CONFIG_PATH" ]]; then
    OLD_SCREEN="$(plutil -extract ScreenName raw -o - "$CONFIG_PATH")"
    OLD_LOG="$(plutil -extract SynergyLogPath raw -o - "$CONFIG_PATH")"
    "$BIN_PATH" once enter --log "$OLD_LOG" --screen "$OLD_SCREEN" --state "$STATE_PATH"
  fi
  if [[ -f "$STATE_PATH" ]]; then
    if ! bootstrap_agent "$PLIST_PATH" >/dev/null 2>&1; then
      echo "The previous LaunchAgent could not be reactivated automatically." >&2
    fi
    echo "Upgrade stopped because the saved input source could not be restored." >&2
    exit 1
  fi
fi

cp "$STAGING_DIR/new/synergy-ime-guard" "$BIN_PATH.new"
chmod 0755 "$BIN_PATH.new"
mv -f "$BIN_PATH.new" "$BIN_PATH"
cp "$STAGING_DIR/new/config.plist" "$CONFIG_PATH.new"
chmod 0600 "$CONFIG_PATH.new"
mv -f "$CONFIG_PATH.new" "$CONFIG_PATH"
cp "$STAGING_DIR/new/status.sh" "$TOOLS_DIR/status.sh.new"
cp "$STAGING_DIR/new/uninstall.sh" "$TOOLS_DIR/uninstall.sh.new"
chmod 0755 "$TOOLS_DIR/"*.new
mv -f "$TOOLS_DIR/status.sh.new" "$TOOLS_DIR/status.sh"
mv -f "$TOOLS_DIR/uninstall.sh.new" "$TOOLS_DIR/uninstall.sh"
cp "$STAGING_DIR/new/agent.plist" "$PLIST_PATH.new"
chmod 0600 "$PLIST_PATH.new"
mv -f "$PLIST_PATH.new" "$PLIST_PATH"

if ! bootstrap_agent "$PLIST_PATH"; then
  if restore_previous_install; then
    echo "Activation failed; the previous installation was restored." >&2
  fi
  exit 1
fi
sleep 1
if ! launchctl print "$SERVICE" 2>/dev/null | grep -q 'state = running'; then
  if restore_previous_install; then
    echo "The guard did not remain loaded; the previous installation was restored." >&2
  fi
  exit 1
fi
if ! "$BIN_PATH" check \
  --log "$SYNERGY_LOG" \
  --screen "$SCREEN_NAME" \
  --state "$STATE_PATH" >/dev/null; then
  if restore_previous_install; then
    echo "Post-install diagnostics failed; the previous installation was restored." >&2
  fi
  exit 1
fi

echo "Synergy IME Guard $("$BIN_PATH" version) is installed."
echo "Screen: $SCREEN_NAME"
echo "Status: $TOOLS_DIR/status.sh"
