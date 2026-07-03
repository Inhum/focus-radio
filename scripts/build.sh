#!/usr/bin/env bash
# Собирает build/FocusRadio.app из radio.swift и подписывает ad-hoc.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

NAME="FocusRadio"
APP="build/$NAME.app"
CONFIG="${1:-release}"   # release | debug

echo "→ Сборка $NAME ($CONFIG)…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

SWIFT_FLAGS=(-O -swift-version 5)
[ "$CONFIG" = "debug" ] && SWIFT_FLAGS=(-Onone -g -swift-version 5)

swiftc "${SWIFT_FLAGS[@]}" -o "$APP/Contents/MacOS/$NAME" radio.swift

cp Resources/Info.plist "$APP/Contents/Info.plist"
[ -f Resources/FocusRadio.icns ] && cp Resources/FocusRadio.icns "$APP/Contents/Resources/"

codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "✓ Готово: $APP"
