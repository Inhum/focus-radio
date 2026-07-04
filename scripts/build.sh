#!/usr/bin/env bash
# Собирает build/FocusRadio.app из radio.swift и подписывает.
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
cp -R Resources/*.lproj "$APP/Contents/Resources/"   # локализация (en/ru)

# Подпись. Если есть локальный сертификат «Focus Radio Self-Signed» — подписываем им
# (стабильная идентичность → выданные разрешения держатся между обновлениями).
# Иначе откат на ad-hoc. Сертификат создаётся один раз: ./scripts/make-cert.sh
IDENTITY="Focus Radio Self-Signed"
if security find-identity -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
    SIGN="$IDENTITY"; NOTE="сертификатом ${IDENTITY}"
else
    SIGN="-"; NOTE="ad-hoc (сертификата нет — см. scripts/make-cert.sh)"
fi
codesign --force --sign "$SIGN" "$APP" >/dev/null 2>&1 \
    && echo "→ Подписано $NOTE" \
    || echo "⚠ codesign не сработал (запуск всё равно возможен)"

echo "✓ Готово: $APP"
