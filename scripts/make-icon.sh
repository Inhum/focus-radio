#!/usr/bin/env bash
# Генерирует Resources/FocusRadio.icns из scripts/make-icon.swift
# и превью docs/icon.png для README.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ICONSET="build/FocusRadio.iconset"
mkdir -p build docs
rm -rf "$ICONSET"

swift scripts/make-icon.swift "$ICONSET"
iconutil -c icns "$ICONSET" -o Resources/FocusRadio.icns

cp "$ICONSET/icon_256x256.png" docs/icon.png
rm -rf "$ICONSET"
echo "✓ Resources/FocusRadio.icns"
echo "✓ docs/icon.png"
