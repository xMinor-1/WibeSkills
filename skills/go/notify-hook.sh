#!/usr/bin/env bash
# UserPromptSubmit-хук: напоминает чату о завершённых go-ранах, итог которых ещё
# не доложен пользователю. Страховка на случай, когда вахта await умерла вместе
# с чатом (закрыт VS Code, перезапуск extension host): при следующем сообщении
# в том же чате Claude увидит напоминание и доложит сам, без /goon.
# Молчит, если докладывать нечего. Ставится в ~/.claude/settings.json.
# Покрывает только раны, форкнутые из чата (parent_session=<id чата>): раны,
# запущенные с --fresh, хук не матчит — их итог забирается вручную через /goon.
set -uo pipefail

RUNS_DIR="$HOME/.claude/go-runs"
[[ -d "$RUNS_DIR" ]] || exit 0
GOSH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/go.sh"

input="$(cat 2>/dev/null || true)"
sid="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null || true)"
[[ -n "$sid" ]] || exit 0

for rd in "$RUNS_DIR"/*/; do
  [[ -d "$rd" ]] || continue
  [[ -f "$rd/.reported" ]] && continue
  st="$(cat "$rd/state" 2>/dev/null || true)"
  case "$st" in
    finished*|failed*|stopped*) ;;
    *) continue ;;
  esac
  # докладываем только в чат, который этот ран запускал
  parent="$(grep -m1 '^parent_session=' "$rd/meta.env" 2>/dev/null | cut -d= -f2- || true)"
  [[ "$parent" == "$sid" ]] || continue
  n="$(basename "$rd")"
  echo "Фоновый ран /go «$n» завершился (${st}), итог пользователю ещё не доложен. Сначала коротко доложи результат по правилам скилла /goon: прочитай ${rd}REPORT.md и лог (\"$GOSH\" log $n 40), проверь ключевые утверждения, затем отметь доклад командой: \"$GOSH\" ack $n. После этого отвечай на текущее сообщение пользователя."
done

exit 0
