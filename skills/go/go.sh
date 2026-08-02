#!/usr/bin/env bash
# go.sh — запуск/управление живучими фоновыми сессиями Claude Code в tmux.
# Сессия живёт на сервере в tmux и не умирает при обрыве SSH / закрытии VS Code.
set -euo pipefail

RUNS_DIR="${HOME}/.claude/go-runs"
CLAUDE_BIN="${CLAUDE_BIN:-$HOME/.local/bin/claude}"
mkdir -p "$RUNS_DIR"

die() { echo "go: $*" >&2; exit 1; }

usage() {
  cat <<'EOF'
go.sh — живучие фоновые сессии Claude Code (tmux)

  go.sh run "<задача>" [опции]   запустить фоновую сессию
  go.sh list                     список сессий и их статус
  go.sh status <name>            подробный статус одной сессии
  go.sh log <name> [N]           последние N (20) сообщений сессии
  go.sh tail <name>              живой хвост сырого вывода терминала
  go.sh more <name> "<задача>"   продолжить сессию новой задачей (контекст сохраняется)
  go.sh back <name>              как вернуть ран в интерактивный чат (id + команды)
  go.sh attach <name>            подключиться к окну tmux (Ctrl-b d — отцепиться)
  go.sh stop <name>              остановить сессию

Опции run:
  --name N        имя сессии (по умолчанию run-MMDD-HHMMSS); повтор имени завершённого
                  рана убирает его папку в архив .old/
  --dir PATH      рабочая директория (по умолчанию текущая)
  --fresh         не наследовать контекст текущего чата (чистая сессия)
  --resume ID     форкнуть конкретную сессию по её id
  --model M       модель (по умолчанию — из глобальных настроек)
  --effort E      low|medium|high|xhigh|max
  --safe          permission-mode acceptEdits (по умолчанию bypassPermissions)
  --tui           интерактивное окно вместо headless (требует, чтобы CLI-бинарник
                  был один раз залогинен вручную: запустить `claude` в терминале)
EOF
}

run_dir()  { echo "$RUNS_DIR/$1"; }
need_run() { [[ -d "$(run_dir "$1")" ]] || die "нет сессии '$1' (go.sh list)"; }
# "=" — точное совпадение имени: без него tmux матчит -t по префиксу
# и go-a цепляет/убивает чужую go-ab
tmux_name(){ echo "=go-$1"; }
alive()    { tmux has-session -t "$(tmux_name "$1")" 2>/dev/null; }
# чтение поля из meta.env, устойчивое к отсутствию файла (обрыв при создании рана)
meta_get() { grep -m1 "^$2=" "$(run_dir "$1")/meta.env" 2>/dev/null | cut -d= -f2- || true; }

jsonl_path() {
  local id="$1"
  find "$HOME/.claude/projects" -maxdepth 2 -name "$id.jsonl" -print -quit 2>/dev/null
}

cmd_run() {
  local prompt="" name="" dir="$PWD" model="" effort="${CLAUDE_EFFORT:-}" \
        perm="bypassPermissions" resume="${CLAUDE_CODE_SESSION_ID:-}" tui=0
  [[ $# -gt 0 && ${1:0:2} != "--" ]] && { prompt="$1"; shift; }
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)   name="$2"; shift 2 ;;
      --dir)    dir="$2"; shift 2 ;;
      --model)  model="$2"; shift 2 ;;
      --effort) effort="$2"; shift 2 ;;
      --resume) resume="$2"; shift 2 ;;
      --fresh)  resume=""; shift ;;
      --safe)   perm="acceptEdits"; shift ;;
      --tui)    tui=1; shift ;;
      --print)  tui=0; shift ;;
      -h|--help) usage; exit 0 ;;
      *) if [[ -z "$prompt" ]]; then prompt="$1"; shift; else die "неизвестный аргумент: $1"; fi ;;
    esac
  done
  [[ -n "$prompt" ]] || die "нужна задача: go.sh run \"<что делать>\""
  [[ -d "$dir" ]]    || die "нет директории: $dir"
  [[ -x "$CLAUDE_BIN" ]] || CLAUDE_BIN="$(command -v claude)" || die "claude не найден"

  name="${name:-run-$(date +%m%d-%H%M%S)}"
  name="${name//[^a-zA-Z0-9_-]/-}"
  local rd; rd="$(run_dir "$name")"
  alive "$name" && die "сессия '$name' уже работает (go.sh attach $name)"
  # завершённый ран с тем же именем не удаляем (там REPORT.md), а убираем в архив
  if [[ -e "$rd" ]]; then
    mkdir -p "$RUNS_DIR/.old"
    mv "$rd" "$RUNS_DIR/.old/${name}-$(date +%s)"
    echo "прошлый ран '$name' убран в $RUNS_DIR/.old/"
  fi
  mkdir -p "$rd"

  # форкаем контекст текущего чата, если он есть и это не --fresh
  if [[ -n "$resume" && -z "$(jsonl_path "$resume")" ]]; then resume=""; fi

  # интерактивное окно упрётся в мастера, если CLI не готов — проверяем до запуска
  if (( tui )); then
    if [[ "$(jq -r '.hasCompletedOnboarding // false' "$HOME/.claude.json" 2>/dev/null)" != "true" ]]; then
      echo "go: CLI-бинарник не проходил онбординг — в --tui ран встанет на мастере входа." >&2
      echo "    Разово: запусти 'claude' в терминале, выбери тему и войди." >&2
    fi
    if [[ "$perm" == "bypassPermissions" \
       && "$(jq -r '.bypassPermissionsModeAccepted // false' "$HOME/.claude.json" 2>/dev/null)" != "true" ]]; then
      perm="acceptEdits"
      echo "go: bypassPermissions в интерактивном окне требует разового подтверждения — стартую с acceptEdits." >&2
      echo "    Нужен bypass: разово прими диалог сам ('claude --permission-mode bypassPermissions')." >&2
    fi
  fi

  local sid; sid="$(uuidgen)"

  # meta.env пишем ДО всего остального: осиротевшая папка без него ломала list
  cat > "$rd/meta.env" <<EOF
name=$name
session_id=$sid
parent_session=${resume:-none}
dir=$dir
model=${model:-default}
effort=${effort:-default}
permission_mode=$perm
mode=$( (( tui )) && echo tui || echo headless )
started=$(date +%s)
started_h=$(date '+%Y-%m-%d %H:%M:%S')
EOF

  printf '%s' "$prompt" > "$rd/prompt.txt"
  # гарантия отчёта: REPORT.md обещан документацией, а не доброй волей сессии
  printf '\n\nВ конце работы запиши краткий итог в файл %s — что сделано, что нет и почему, ключевые решения.' \
    "$rd/REPORT.md" >> "$rd/prompt.txt"

  # -n делает ран узнаваемым в пикере /resume — так его можно открыть в чате VS Code
  local args=( --session-id "$sid" --permission-mode "$perm" -n "go: $name" )
  [[ -n "$model" ]]  && args+=( --model "$model" )
  [[ -n "$effort" ]] && args+=( --effort "$effort" )
  [[ -n "$resume" ]] && args+=( --resume "$resume" --fork-session )
  (( tui )) || args+=( --print --output-format text )

  {
    echo '#!/usr/bin/env bash'
    printf 'cd %q || exit 1\n' "$dir"
    printf '%q' "$CLAUDE_BIN"
    printf ' %q' "${args[@]}"
    printf ' -- "$(cat %q)"\n' "$rd/prompt.txt"   # "--": промпт с ведущим "-" не станет опцией
    printf 'code=$?\n'
    printf 'printf "finished=%%s\\nexit_code=%%s\\n" "$(date +%%s)" "$code" >> %q\n' "$rd/meta.env"
    printf 'echo; echo "[go] сессия %s завершила работу, код $code"\n' "$name"
    (( tui )) && printf 'exec bash\n' || printf 'sleep 2\n'
  } > "$rd/cmd.sh"
  chmod +x "$rd/cmd.sh"

  tmux new-session -d -s "go-$name" -c "$dir" "$rd/cmd.sh"
  touch "$rd/raw.log"
  # цель панели — "=имя:" (двоеточие обязательно, иначе "can't find pane")
  tmux pipe-pane -o -t "$(tmux_name "$name"):" "cat >> $rd/raw.log" 2>/dev/null || true

  echo "запущена фоновая сессия: $name"
  echo "  режим:    $( (( tui )) && echo 'интерактивный tmux' || echo 'headless (отработает и выйдет)')"
  echo "  дир:      $dir"
  if [[ -n "$resume" ]]; then echo "  контекст: форк текущего чата ($resume)"; else echo "  контекст: чистая сессия"; fi
  echo "  id:       $sid"
  echo "  смотреть: go.sh log $name   |   tmux attach -t $(tmux_name "$name")"
}

# продолжить существующую сессию новой задачей (контекст сохраняется)
cmd_more() {
  need_run "$1"
  local rd; rd="$(run_dir "$1")"
  alive "$1" && die "сессия '$1' ещё работает — дождись её (go.sh status $1)"
  local sid dir perm model effort
  sid="$(meta_get "$1" session_id)"
  [[ -n "$sid" ]] || die "meta.env рана '$1' отсутствует или повреждён — продолжить нельзя"
  dir="$(meta_get "$1" dir)"; [[ -d "$dir" ]] || dir="$PWD"
  perm="$(meta_get "$1" permission_mode)"; perm="${perm:-bypassPermissions}"
  model="$(meta_get "$1" model)"
  effort="$(meta_get "$1" effort)"
  printf '%s' "$2" > "$rd/prompt.txt"
  printf '\n\nВ конце работы обнови итог в файле %s.' "$rd/REPORT.md" >> "$rd/prompt.txt"
  local args=( --resume "$sid" --permission-mode "$perm" --print --output-format text )
  [[ -n "$model"  && "$model"  != "default" ]] && args+=( --model "$model" )
  [[ -n "$effort" && "$effort" != "default" ]] && args+=( --effort "$effort" )
  {
    echo '#!/usr/bin/env bash'
    printf 'cd %q || exit 1\n' "$dir"
    printf '%q' "$CLAUDE_BIN"
    printf ' %q' "${args[@]}"
    printf ' -- "$(cat %q)"\n' "$rd/prompt.txt"
    printf 'code=$?\n'
    printf 'printf "finished=%%s\\nexit_code=%%s\\n" "$(date +%%s)" "$code" >> %q\n' "$rd/meta.env"
    printf 'echo; echo "[go] продолжение сессии %s завершено, код $code"\n' "$1"
    printf 'sleep 2\n'
  } > "$rd/cmd.sh"
  chmod +x "$rd/cmd.sh"
  tmux new-session -d -s "go-$1" -c "$dir" "$rd/cmd.sh"
  touch "$rd/raw.log"
  tmux pipe-pane -o -t "$(tmux_name "$1"):" "cat >> $rd/raw.log" 2>/dev/null || true
  echo "сессия '$1' продолжена новой задачей (контекст сохранён, id $sid)"
}

# печать сообщений из jsonl сессии
cmd_log() {
  need_run "$1"
  local n="${2:-20}"; local sid; sid="$(meta_get "$1" session_id)"
  [[ -n "$sid" ]] || { echo "(meta.env рана отсутствует — лог недоступен)"; return 0; }
  local f; f="$(jsonl_path "$sid")"
  [[ -n "$f" ]] || { echo "(сессия ещё не начала писать лог)"; return 0; }
  python3 - "$f" "$n" <<'PY'
import json, sys
path, n = sys.argv[1], int(sys.argv[2])
rows = []
for line in open(path, encoding='utf-8', errors='replace'):
    try: ev = json.loads(line)
    except Exception: continue
    if not isinstance(ev, dict): continue
    msg = ev.get('message') or {}
    if not isinstance(msg, dict): msg = {}
    role = msg.get('role') or ev.get('type')
    content = msg.get('content')
    if not content: continue
    if isinstance(content, str):
        rows.append((role, content.strip())); continue
    if not isinstance(content, list): continue
    for b in content:
        if not isinstance(b, dict): continue
        t = b.get('type')
        if t == 'text' and (b.get('text') or '').strip():
            rows.append((role, b['text'].strip()))
        elif t == 'tool_use':
            inp = b.get('input') if isinstance(b.get('input'), dict) else {}
            hint = inp.get('command') or inp.get('file_path') or inp.get('pattern') or inp.get('description') or ''
            rows.append(('tool', f"{b.get('name')}: {str(hint)[:120]}"))
for role, text in rows[-n:]:
    tag = {'user': '>', 'assistant': '*', 'tool': '  ~'}.get(role, str(role))
    print(f"{tag} {text[:1500]}")
PY
}

cmd_status() {
  need_run "$1"; local rd; rd="$(run_dir "$1")"
  cat "$rd/meta.env" 2>/dev/null || echo "(meta.env отсутствует — ран оборван при создании)"
  if alive "$1"; then
    local sid f age=""
    sid="$(meta_get "$1" session_id)"
    f=""; [[ -n "$sid" ]] && f="$(jsonl_path "$sid")"
    [[ -n "$f" ]] && age=$(( $(date +%s) - $(stat -c %Y "$f") ))
    if [[ -n "$age" && $age -lt 60 ]]; then echo "state=работает (активность ${age}с назад)"
    elif [[ -n "$age" ]]; then echo "state=простаивает / ждёт (тишина $((age/60)) мин)"
    else echo "state=стартует"; fi
  else
    echo "state=остановлена"
  fi
}

cmd_list() {
  local found=0
  for rd in "$RUNS_DIR"/*/; do
    [[ -d "$rd" ]] || continue
    local n; n="$(basename "$rd")"; found=1
    local st="остановлена"; alive "$n" && st="жива"
    local started; started="$(meta_get "$n" started_h)"
    local task; task="$(head -c 70 "$rd/prompt.txt" 2>/dev/null | tr '\n' ' ' || true)"
    printf '%-22s %-12s %s  — %s\n' "$n" "$st" "${started:-?}" "${task:-?}"
  done
  (( found )) || echo "фоновых сессий нет"
}

# как вернуть ран в интерактивный чат
cmd_back() {
  need_run "$1"; local rd; rd="$(run_dir "$1")"
  local sid dir; sid="$(meta_get "$1" session_id)"
  [[ -n "$sid" ]] || die "meta.env рана '$1' отсутствует — id сессии неизвестен"
  dir="$(meta_get "$1" dir)"
  alive "$1" && echo "ВНИМАНИЕ: ран ещё работает — сначала дождись конца или go.sh stop $1"
  echo "ран:     $1"
  echo "id:      $sid"
  echo "дир:     $dir"
  echo
  echo "в чат VS Code:  /resume  → выбрать «go: $1» (открыть надо чат, запущенный в $dir)"
  echo "в терминале:    claude --resume $sid          (в директории $dir)"
  echo "итог в чат сюда: go.sh log $1 40   и   $rd/REPORT.md"
}

case "${1:-}" in
  run)     shift; cmd_run "$@" ;;
  list|ls) cmd_list ;;
  status)  shift; cmd_status "${1:?имя}" ;;
  log)     shift; cmd_log "${1:?имя}" "${2:-20}" ;;
  tail)    shift; need_run "$1"; tail -f "$(run_dir "$1")/raw.log" | sed -u 's/\x1b\[[0-9;?]*[a-zA-Z]//g' ;;
  more|say) shift; cmd_more "${1:?имя}" "${2:?текст задачи}" ;;
  back)    shift; cmd_back "${1:?имя}" ;;
  attach)  shift; need_run "$1"; exec tmux attach -t "$(tmux_name "$1")" ;;
  stop)    shift; need_run "$1"; tmux kill-session -t "$(tmux_name "$1")" 2>/dev/null && echo "остановлена: $1" || echo "уже не работает: $1" ;;
  ""|-h|--help|help) usage ;;
  *) die "неизвестная команда: $1 (go.sh --help)" ;;
esac
