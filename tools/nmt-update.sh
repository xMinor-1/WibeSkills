#!/usr/bin/env bash
# Обновить канон и скиллы Замесина, вернув русские описания.
#
# Официальный путь обновления (/nmt-update, install.sh) копирует канон и скиллы
# в корень ТЕКУЩЕГО проекта — здесь так нельзя: скиллы стоят симлинками на этот
# сабмодуль. Обновляемся только так.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CANON="$ROOT/canon"

echo "Версия сейчас: $(grep -m1 -E '^##[[:space:]]+[0-9]' "$CANON/CHANGELOG.md" || echo '—')"

# Наши правки description мешают fast-forward — откатываем перед pull.
git -C "$CANON" checkout -- Skills/claude 2>/dev/null || true
git -C "$CANON" pull --ff-only

echo "Версия после обновления: $(grep -m1 -E '^##[[:space:]]+[0-9]' "$CANON/CHANGELOG.md")"

python3 "$ROOT/tools/nmt-ru-descriptions.py"

echo
echo "Готово. Если в каноне появились новые скиллы — они выше помечены как «без перевода»,"
echo "добавь им русский текст в tools/nmt-ru-descriptions.py."
