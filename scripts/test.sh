#!/usr/bin/env bash
# Собирает release и прогоняет самотест по всем 14 станциям.
# Выходит с ненулевым кодом, если не все играют.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/build.sh" release

echo "→ Самотест (может занять несколько минут)…"
exec "$ROOT/build/FocusRadio.app/Contents/MacOS/FocusRadio" --test-all
