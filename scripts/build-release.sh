#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$PROJECT_DIR/VERSION")"
DIST_DIR="$PROJECT_DIR/dist"
ARM_BUILD="$PROJECT_DIR/.build/release-arm64"
INTEL_BUILD="$PROJECT_DIR/.build/release-x86_64"
STAGE_DIR="$DIST_DIR/synergy-ime-guard-v$VERSION-macos-universal"
ARCHIVE="$DIST_DIR/synergy-ime-guard-v$VERSION-macos-universal.tar.gz"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "VERSION must be a numeric semantic version" >&2
  exit 1
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "build-release.sh requires macOS" >&2
  exit 1
fi

SOURCE_VERSION="$(sed -n 's/.*version = "\([^"]*\)".*/\1/p' \
  "$PROJECT_DIR/Sources/SynergyIMEGuardCore/Constants.swift")"
if [[ "$SOURCE_VERSION" != "$VERSION" ]]; then
  echo "VERSION ($VERSION) does not match source version ($SOURCE_VERSION)" >&2
  exit 1
fi

mkdir -p "$DIST_DIR"
swift build \
  --package-path "$PROJECT_DIR" \
  --configuration release \
  --arch arm64 \
  --scratch-path "$ARM_BUILD"
swift build \
  --package-path "$PROJECT_DIR" \
  --configuration release \
  --arch x86_64 \
  --scratch-path "$INTEL_BUILD"

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
lipo -create \
  "$ARM_BUILD/arm64-apple-macosx/release/synergy-ime-guard" \
  "$INTEL_BUILD/x86_64-apple-macosx/release/synergy-ime-guard" \
  -output "$STAGE_DIR/synergy-ime-guard"
chmod 0755 "$STAGE_DIR/synergy-ime-guard"
codesign --force --sign - "$STAGE_DIR/synergy-ime-guard"
codesign --verify --verbose "$STAGE_DIR/synergy-ime-guard"

cp "$PROJECT_DIR/scripts/install.sh" "$STAGE_DIR/install.sh"
cp "$PROJECT_DIR/scripts/uninstall.sh" "$STAGE_DIR/uninstall.sh"
cp "$PROJECT_DIR/scripts/status.sh" "$STAGE_DIR/status.sh"
cp "$PROJECT_DIR/LICENSE" "$STAGE_DIR/LICENSE"
chmod 0755 "$STAGE_DIR"/*.sh

rm -f "$ARCHIVE" "$ARCHIVE.sha256"
COPYFILE_DISABLE=1 tar \
  --uid 0 \
  --gid 0 \
  --uname root \
  --gname wheel \
  -C "$DIST_DIR" \
  -czf "$ARCHIVE" \
  "$(basename "$STAGE_DIR")"
(
  cd "$DIST_DIR"
  shasum -a 256 "$(basename "$ARCHIVE")" > "$(basename "$ARCHIVE").sha256"
)

echo "Built $ARCHIVE"
lipo -archs "$STAGE_DIR/synergy-ime-guard"
cat "$ARCHIVE.sha256"
