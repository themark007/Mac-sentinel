#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MacSentinel"
BUNDLE="$ROOT/dist/$APP_NAME.app"
SIGNED_ROOT="/tmp/macsentinel-build"
SIGNED_BUNDLE="$SIGNED_ROOT/$APP_NAME.app"
ZIP_PATH="$ROOT/dist/$APP_NAME.zip"

mkdir -p "$ROOT/.build/module-cache"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"

export CLANG_MODULE_CACHE_PATH="$ROOT/.build/module-cache"
swift build -c release --scratch-path "$ROOT/.build"

cp "$ROOT/.build/release/$APP_NAME" "$BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ROOT/Packaging/Info.plist" "$BUNDLE/Contents/Info.plist"
chmod +x "$BUNDLE/Contents/MacOS/$APP_NAME"

mkdir -p "$SIGNED_ROOT"
ditto --norsrc "$BUNDLE" "$SIGNED_BUNDLE"

if command -v codesign >/dev/null 2>&1; then
    xattr -cr "$SIGNED_BUNDLE" >/dev/null 2>&1 || true
    codesign --force --deep --sign - "$SIGNED_BUNDLE" >/dev/null 2>&1 || true
fi

ditto -c -k --keepParent "$SIGNED_BUNDLE" "$ZIP_PATH"

echo "$BUNDLE"
echo "$ZIP_PATH"
echo "$SIGNED_BUNDLE"
