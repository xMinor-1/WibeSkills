#!/usr/bin/env bash
# calibrate.sh — замер исполнителей (моделей) на СВОИХ закрытых задачах.
#
# Идея: у закрытой Task есть эталон — реальный код в git. Откатываем файлы
# реализации (тесты и пакет остаются), отдаём пакет исполнителю, смотрим
# четыре числа: зелено ли с первого раза, сколько кругов, вышел ли за границы,
# сколько стоило. Методика и правила интерпретации — README.md рядом.
#
# Команды:
#   calibrate.sh prepare <task-slug>              — песочница «до» + проверка, что тесты красные
#   calibrate.sh run     <task-slug> <executor>   — прогон исполнителя по пакету
#   calibrate.sh score   [--csv]                  — свод результатов
#   calibrate.sh clean   [<task-slug>]            — убрать песочницы
#
# Конфигурация — env или calibrate.env рядом со скриптом:
#   REPO        корень git-репозитория проекта     (обяз.)
#   VERIFY      команда проверки Task              (умолч. infra/verify-task.sh)
#   SANDBOX     где держать песочницы              (умолч. /tmp/calibrate-<проект>)
#   RESULTS     файл результатов jsonl             (умолч. <скрипт>/results.jsonl)
#
# Исполнитель (<executor>) — ключ из EXECUTORS ниже либо строка команды, в которой
# {packet} заменяется на путь к пакету. Прогоны НЕ бесплатны: скрипт ничего не
# запускает сам по себе и никогда не ходит в сеть за ключами.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$SCRIPT_DIR/calibrate.env" ]] && source "$SCRIPT_DIR/calibrate.env"

REPO="${REPO:-}"
VERIFY="${VERIFY:-infra/verify-task.sh}"
RESULTS="${RESULTS:-$SCRIPT_DIR/results.jsonl}"

# Известные исполнители. {packet} — путь к пакету внутри песочницы.
declare -A EXECUTORS=(
  [opus]='claude -p --model opus --permission-mode bypassPermissions "Прочитай пакет задачи {packet} и выполни его. Работай строго по пакету: PRD и tech-spec не читай."'
  [sonnet]='claude -p --model sonnet --permission-mode bypassPermissions "Прочитай пакет задачи {packet} и выполни его. Работай строго по пакету: PRD и tech-spec не читай."'
  [haiku]='claude -p --model haiku --permission-mode bypassPermissions "Прочитай пакет задачи {packet} и выполни его. Работай строго по пакету: PRD и tech-spec не читай."'
  # Внешние — требуют установленного CLI и ключа, см. README «Чем можно прогнать»:
  # [deepseek]='aider --model deepseek/deepseek-coder --yes --message-file {packet}'
  # [qwen]='aider --model openai/qwen-coder --yes --message-file {packet}'
)

die() { echo "ошибка: $*" >&2; exit 2; }
say() { echo "$@"; }

[[ -n "$REPO" ]] || die "не задан REPO (корень репозитория проекта)"
[[ -d "$REPO/.git" ]] || die "REPO не похож на git-репозиторий: $REPO"
PROJECT="$(basename "$REPO")"
SANDBOX="${SANDBOX:-/tmp/calibrate-$PROJECT}"

packet_path() {
  local slug="$1" root="${2:-$REPO}"
  find "$root/docs" -path "*/tasks/${slug}.md" -type f 2>/dev/null | head -1
}

allowed_paths() {  # пути реализации из пакета, кроме тестов
  awk '/^```allowed-paths$/{inside=1;next} inside&&/^```/{exit} inside{print}' "$1" \
    | sed 's/[[:space:]]*#.*$//' | grep -v '^[[:space:]]*$' \
    | grep -vE '(__tests__|\.test\.|\.spec\.)'
}

test_cmd() {
  awk '/^```test-cmd$/{inside=1;next} inside&&/^```/{exit} inside{print}' "$1" \
    | sed 's/[[:space:]]*#.*$//' | grep -v '^[[:space:]]*$' | head -1
}

cmd_prepare() {
  local slug="${1:-}"; [[ -n "$slug" ]] || die "укажи task-slug"
  local packet; packet="$(packet_path "$slug")"
  [[ -n "$packet" ]] || die "пакет не найден: docs/*/tasks/$slug.md"

  local wt="$SANDBOX/$slug"
  [[ -e "$wt" ]] && die "песочница уже есть: $wt (calibrate.sh clean $slug)"
  mkdir -p "$SANDBOX"

  git -C "$REPO" worktree add --detach "$wt" HEAD >/dev/null 2>&1 || die "не создать worktree"
  say "песочница: $wt"

  # Откат реализации: файлы из allowed-paths убираем, тесты и пакет оставляем.
  local removed=0 f
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if [[ -e "$wt/$f" ]]; then
      git -C "$wt" rm -q --cached "$f" >/dev/null 2>&1
      mv "$wt/$f" "$wt/$f.calibrate-backup"
      removed=$((removed + 1))
    fi
  done < <(allowed_paths "$packet")
  say "откачено файлов реализации: $removed"
  [[ $removed -gt 0 ]] || die "нечего откатывать — проверь allowed-paths пакета"

  # Тесты обязаны быть красными: иначе замер бессмыслен.
  local tc; tc="$(test_cmd "$packet")"
  local code_root="$wt/product-mvp"; [[ -d "$code_root" ]] || code_root="$wt"
  if (cd "$code_root" && eval "$tc") >/dev/null 2>&1; then
    say "ВНИМАНИЕ: тесты зелёные на откаченном коде — задача не годится для замера"
    exit 1
  fi
  say "тесты красные — песочница готова"
  say "пакет внутри песочницы: ${packet/$REPO/$wt}"
}

cmd_run() {
  local slug="${1:-}" executor="${2:-}"
  [[ -n "$slug" && -n "$executor" ]] || die "нужны task-slug и executor"
  local wt="$SANDBOX/$slug"
  [[ -d "$wt" ]] || die "нет песочницы, сначала prepare"

  local packet; packet="$(packet_path "$slug" "$wt")"
  [[ -n "$packet" ]] || die "пакет не найден внутри песочницы"

  local cmd="${EXECUTORS[$executor]:-$executor}"
  cmd="${cmd//\{packet\}/$packet}"
  say "исполнитель: $executor"
  say "команда: $cmd"

  local started; started="$(date +%s)"
  (cd "$wt" && eval "$cmd") > "$wt/.executor.log" 2>&1
  local exec_code=$?
  local elapsed=$(( $(date +%s) - started ))
  say "исполнитель завершился: код $exec_code, ${elapsed}с"

  # Первая проверка = «зелено с первого раза».
  local verdict first_green
  verdict="$(cd "$wt" && bash "$VERIFY" "$slug" --base HEAD --quiet 2>/dev/null | tail -1)"
  if grep -q '"verdict":"pass"' <<<"$verdict"; then first_green=true; else first_green=false; fi

  local out_of_scope
  out_of_scope="$(grep -o '"out_of_scope":\[[^]]*\]' <<<"$verdict" | grep -o '"' | wc -l)"
  out_of_scope=$(( out_of_scope / 2 ))

  printf '{"task":"%s","executor":"%s","first_pass_green":%s,"out_of_scope_files":%d,"wall_clock_s":%d,"exec_exit":%d,"verdict":%s}\n' \
    "$slug" "$executor" "$first_green" "$out_of_scope" "$elapsed" "$exec_code" "${verdict:-null}" >> "$RESULTS"

  say "результат записан в $RESULTS"
  say "$verdict"
  say ""
  say "Дальше — вручную: раунды cross-review и стоимость в лог не попадают автоматически."
  say "Стоимость смотри в отчёте провайдера, раунды — по прогону task-cross-review."
}

cmd_score() {
  [[ -f "$RESULTS" ]] || die "нет результатов: $RESULTS"
  say "исполнитель        задач  зелёных с 1-го  выходов за границы  среднее время"
  python3 - "$RESULTS" <<'PY'
import json, sys, collections
rows = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
by = collections.defaultdict(list)
for r in rows: by[r["executor"]].append(r)
for ex, rs in sorted(by.items()):
    n = len(rs)
    green = sum(1 for r in rs if r.get("first_pass_green"))
    oos = sum(r.get("out_of_scope_files", 0) for r in rs)
    avg = sum(r.get("wall_clock_s", 0) for r in rs) / n if n else 0
    note = "  (выборка мала)" if n < 8 else ""
    print(f"{ex:<18} {n:>5}  {green:>13}  {oos:>18}  {avg:>11.0f}с{note}")
PY
}

cmd_clean() {
  local slug="${1:-}"
  if [[ -n "$slug" ]]; then
    git -C "$REPO" worktree remove --force "$SANDBOX/$slug" 2>/dev/null
    say "убрано: $slug"
  else
    for d in "$SANDBOX"/*; do
      [[ -d "$d" ]] || continue
      git -C "$REPO" worktree remove --force "$d" 2>/dev/null
    done
    git -C "$REPO" worktree prune
    say "песочницы убраны"
  fi
}

case "${1:-}" in
  prepare) shift; cmd_prepare "$@" ;;
  run)     shift; cmd_run "$@" ;;
  score)   shift; cmd_score "$@" ;;
  clean)   shift; cmd_clean "$@" ;;
  *) sed -n '2,26p' "${BASH_SOURCE[0]}"; exit 0 ;;
esac
