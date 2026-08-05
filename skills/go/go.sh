#!/usr/bin/env bash
# go.sh — запуск/управление живучими фоновыми сессиями Claude Code в tmux.
# Сессия живёт на сервере в tmux и не умирает при обрыве SSH / закрытии VS Code.
# Состояние рана — файл state: running | finished <code> | failed <прич> | stopped <ts>.
set -euo pipefail

RUNS_DIR="${HOME}/.claude/go-runs"
CLAUDE_BIN="${CLAUDE_BIN:-$HOME/.local/bin/claude}"
SELF="$(readlink -f "${BASH_SOURCE[0]}")"
MAX_RESTARTS=3
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
  go.sh say <name> "<текст>"     дополнение: живому рану — в очередь (подхватит после
                                 текущего прохода), завершённому — новый заход (= more)
  go.sh more <name> "<задача>"   продолжить ЗАВЕРШЁННУЮ сессию новой задачей
  go.sh await <name>             тихо ждать финала рана (для фоновой вахты из чата)
  go.sh ack <name>               отметить «итог доложен в чат» (гасит напоминания хука)
  go.sh back <name>              как вернуть ран в интерактивный чат (id + команды)
  go.sh attach <name>            подключиться к окну tmux (Ctrl-b d — отцепиться)
  go.sh stop <name>              остановить сессию (watchdog её НЕ воскресит)
  go.sh watchdog                 прогон авто-восстановления (обычно из cron)

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

Авто-восстановление: go.sh run сам ставит cron-задачу (*/2 мин). Ран в состоянии
running с умершим tmux (падение, перезагрузка сервера) возобновляется продолжением
той же сессии, до 3 рестартов. Останавливать раны только через go.sh stop.
EOF
}

run_dir()  { echo "$RUNS_DIR/$1"; }
need_run() { [[ -d "$(run_dir "$1")" ]] || die "нет сессии '$1' (go.sh list)"; }
# "=" — точное совпадение имени: без него tmux матчит -t по префиксу
# и go-a цепляет/убивает чужую go-ab
tmux_name(){ echo "=go-$1"; }
alive()    { tmux has-session -t "$(tmux_name "$1")" 2>/dev/null; }
# чтение поля из meta.env, устойчивое к отсутствию файла (обрыв при создании рана);
# берём ПОСЛЕДНЕЕ вхождение: у легаси-ранов finished=/exit_code= накоплены дублями
meta_get() { grep "^$2=" "$(run_dir "$1")/meta.env" 2>/dev/null | tail -1 | cut -d= -f2- || true; }
state_get(){ cat "$(run_dir "$1")/state" 2>/dev/null || true; }
set_state(){ printf '%s\n' "$2" > "$(run_dir "$1")/state"; }

jsonl_path() {
  local id="$1"
  # || true: ненулевой exit find (нет каталога/нечитаемый подкаталог) в подстановке
  # при присваивании убивал cmd_log/cmd_status через set -e
  find "$HOME/.claude/projects" -maxdepth 2 -name "$id.jsonl" -print -quit 2>/dev/null || true
}

# поднять tmux-окно с раннером ($1 имя, $2 фаза: first|more|revive)
launch_runner() {
  local rd d; rd="$(run_dir "$1")"
  d="$(meta_get "$1" dir)"; [[ -d "$d" ]] || d="$HOME"
  mkdir -p "$rd/inbox/done"
  # 8>&- 9>&- обязательно: cmd_watchdog держит flock на fd 9, cmd_more — на fd 8;
  # без закрытия свежефоркнутый tmux-СЕРВЕР наследует fd и держит лок вечно
  tmux new-session -d -s "go-$1" -c "$d" "$(printf '%q _runner %q %q' "$SELF" "$1" "$2")" 8>&- 9>&-
  touch "$rd/raw.log"
  # цель панели — "=имя:" (двоеточие обязательно, иначе "can't find pane")
  tmux pipe-pane -o -t "$(tmux_name "$1"):" "cat >> $rd/raw.log" 2>/dev/null || true
}

# идемпотентно ставит cron-задачу watchdog (авто-восстановление упавших ранов);
# сверяет ПУТЬ: после переезда библиотеки скиллов устаревшая запись вычищается
ensure_watchdog() {
  command -v crontab >/dev/null 2>&1 || { echo "go: crontab недоступен — авто-восстановление отключено" >&2; return 0; }
  local want; want="$(printf '%q watchdog' "$SELF")"
  crontab -l 2>/dev/null | grep -Fq "$want" && return 0
  { crontab -l 2>/dev/null | grep -v "go\.sh.* watchdog" | grep -v '^# go\.sh watchdog' || true
    echo "# go.sh watchdog: авто-восстановление упавших фоновых ранов Claude"
    printf '*/2 * * * * %q watchdog >> %q 2>&1\n' "$SELF" "$RUNS_DIR/.watchdog.log"
  } | crontab -
  echo "  watchdog: поставлен в cron (каждые 2 мин, до $MAX_RESTARTS авто-рестартов на ран)"
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
  mkdir -p "$rd/inbox/done"

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

  printf '%s' "$prompt" > "$rd/task.txt"   # исходная задача — для list/status
  printf '%s' "$prompt" > "$rd/prompt.txt"
  # гарантия отчёта: REPORT.md обещан документацией, а не доброй волей сессии
  printf '\n\nВ конце работы запиши краткий итог в файл %s — что сделано, что нет и почему, ключевые решения.' \
    "$rd/REPORT.md" >> "$rd/prompt.txt"

  set_state "$name" "running"
  ensure_watchdog
  launch_runner "$name" first

  echo "запущена фоновая сессия: $name"
  echo "  режим:    $( (( tui )) && echo 'интерактивный tmux' || echo 'headless (отработает и выйдет)')"
  echo "  дир:      $dir"
  if [[ -n "$resume" ]]; then echo "  контекст: форк текущего чата ($resume)"; else echo "  контекст: чистая сессия"; fi
  echo "  id:       $sid"
  echo "  смотреть: go.sh log $name   |   дополнить на лету: go.sh say $name \"...\""
}

# ── раннер: работает ВНУТРИ tmux-окна (не вызывать руками) ──────────────────
# Фаза first — новая сессия (+форк родителя), more/revive — продолжение той же.
# После основного прохода разбирает inbox (go.sh say), затем пишет терминальный state.
cmd_runner() {
  local name="$1" phase="${2:-first}"
  local rd; rd="$(run_dir "$name")"
  [[ -d "$rd" ]] || exit 1
  local sid dir perm model effort parent runmode
  sid="$(meta_get "$name" session_id)"
  dir="$(meta_get "$name" dir)"
  perm="$(meta_get "$name" permission_mode)"; perm="${perm:-bypassPermissions}"
  model="$(meta_get "$name" model)"
  effort="$(meta_get "$name" effort)"
  parent="$(meta_get "$name" parent_session)"
  runmode="$(meta_get "$name" mode)"
  [[ -n "$sid" ]] || { set_state "$name" "failed нет session_id"; exit 1; }
  # гонка watchdog vs stop: стоп мог прилететь между решением о запуске и стартом
  [[ "$(state_get "$name")" == stopped* ]] && { echo "[go] ран '$name' остановлен — выхожу"; exit 0; }
  # tmux наследует окружение СОЗДАЮЩЕГО клиента: у cron-возрождённых ранов PATH
  # был бы /usr/bin:/bin без ~/.local/bin и /usr/local/bin — чиним всегда
  export PATH="$HOME/.local/bin:/usr/local/bin:/snap/bin:$PATH"
  export LANG="${LANG:-C.UTF-8}"
  cd "$dir" 2>/dev/null || cd "$HOME"
  mkdir -p "$rd/inbox/done"
  shopt -s nullglob

  local base=( "$CLAUDE_BIN" --permission-mode "$perm" )
  [[ -n "$model"  && "$model"  != "default" ]] && base+=( --model "$model" )
  [[ -n "$effort" && "$effort" != "default" ]] && base+=( --effort "$effort" )

  local first_args=()
  if [[ "$phase" == "first" ]]; then
    first_args=( --session-id "$sid" -n "go: $name" )
    [[ -n "$parent" && "$parent" != "none" ]] && first_args+=( --resume "$parent" --fork-session )
  else
    first_args=( --resume "$sid" )
  fi

  finish() {
    set_state "$name" "finished $1"
    # замена, не append: дубли finished= ломали meta_get и захламляли status
    if grep -q '^finished=' "$rd/meta.env" 2>/dev/null; then
      sed -i -e "s/^finished=.*/finished=$(date +%s)/" -e "s/^exit_code=.*/exit_code=$1/" "$rd/meta.env"
    else
      printf 'finished=%s\nexit_code=%s\n' "$(date +%s)" "$1" >> "$rd/meta.env"
    fi
    echo; echo "[go] сессия $name завершила работу, код $1"
  }

  # интерактивный режим: без --print, без inbox — пользователь общается с окном сам
  if [[ "$runmode" == "tui" ]]; then
    local CODE=0
    "${base[@]}" "${first_args[@]}" -- "$(cat "$rd/prompt.txt")" || CODE=$?
    finish "$CODE"
    exec bash
  fi

  base+=( --print --output-format text )

  # основной проход + ретраи на случай падения самого claude
  local CODE=0 tries=0 prev=0
  "${base[@]}" "${first_args[@]}" -- "$(cat "$rd/prompt.txt")" || CODE=$?
  while (( CODE != 0 && tries < 2 )); do
    tries=$(( tries + 1 )); prev=$CODE; CODE=0
    sleep 5
    if [[ -n "$(jsonl_path "$sid")" ]]; then
      "${base[@]}" --resume "$sid" -- "Предыдущий запуск прервался (код $prev). Продолжи задачу с места остановки и доведи до конца. Итог — в $rd/REPORT.md." || CODE=$?
    elif [[ "$phase" == "first" ]]; then
      # сессия даже не успела создаться — повторяем старт как есть
      "${base[@]}" "${first_args[@]}" -- "$(cat "$rd/prompt.txt")" || CODE=$?
    else
      # more/revive без существующей сессии: --resume обречён, стартуем с нуля тем же id
      "${base[@]}" --session-id "$sid" -n "go: $name" -- "$(cat "$rd/prompt.txt")" || CODE=$?
    fi
  done

  # разбор очереди дополнений (go.sh say), присланных пока сессия работала;
  # файлы уходят в done/ только ПОСЛЕ успешной доставки — краш посреди прохода
  # оставляет их в inbox, и revive-заход дренирует заново
  while :; do
    while :; do
      local files=( "$rd/inbox/"*.txt )
      (( ${#files[@]} )) || break
      local pf="$rd/prompt-cont.txt" f
      : > "$pf"
      for f in "${files[@]}"; do cat "$f" >> "$pf"; printf '\n\n' >> "$pf"; done
      printf 'Выше — дополнение владельца к текущей задаче, присланное пока ты работал. Выполни его с учётом уже сделанного и обнови итог в %s.' \
        "$rd/REPORT.md" >> "$pf"
      CODE=0
      "${base[@]}" --resume "$sid" -- "$(cat "$pf")" || CODE=$?
      if (( CODE != 0 )); then
        sleep 5; prev=$CODE; CODE=0
        "${base[@]}" --resume "$sid" -- "Предыдущий проход прервался (код $prev). Заверши дополнение владельца и обнови итог в $rd/REPORT.md." || CODE=$?
      fi
      (( CODE != 0 )) && break   # недоставленные остаются в inbox
      for f in "${files[@]}"; do mv "$f" "$rd/inbox/done/$(basename "$f")" 2>/dev/null || true; done
    done
    finish "$CODE"
    # анти-гонка say: сообщение могло упасть между последним глобом и finish
    local post=( "$rd/inbox/"*.txt )
    if (( ${#post[@]} )) && (( CODE == 0 )); then set_state "$name" "running"; else break; fi
  done
  sleep 2
}

# продолжить ЗАВЕРШЁННУЮ сессию новой задачей (контекст сохраняется)
cmd_more() {
  need_run "$1"
  local rd; rd="$(run_dir "$1")"
  local sid; sid="$(meta_get "$1" session_id)"
  [[ -n "$sid" ]] || die "meta.env рана '$1' отсутствует или повреждён — продолжить нельзя"
  # сериализация: два параллельных продолжения (напр. два say у самого финиша рана)
  # без лока клобберили prompt.txt и роняли второе на duplicate tmux session
  exec 8>>"$rd/.more.lock"
  flock 8
  if alive "$1"; then
    # ран уже работает (в т.ч. поднят параллельным more секунду назад) —
    # не умираем, а ставим задачу ему в очередь: дренаж доставит в ту же сессию
    mkdir -p "$rd/inbox/done"
    local f="$rd/inbox/$(date +%s%N).txt"
    printf '%s' "$2" > "$f.tmp" && mv "$f.tmp" "$f"
    echo "сессия '$1' уже работает — дополнение поставлено ей в очередь"
    return 0
  fi
  printf '%s' "$2" > "$rd/task.txt"
  printf '%s' "$2" > "$rd/prompt.txt"
  printf '\n\nВ конце работы обнови итог в файле %s.' "$rd/REPORT.md" >> "$rd/prompt.txt"
  rm -f "$rd/.reported"
  echo 0 > "$rd/.restarts"
  # обновить started: иначе продолженный ран без 90с-форы, и watchdog может
  # затереть новую задачу revive-промптом в окне до старта tmux
  sed -i -e "s/^started=.*/started=$(date +%s)/" -e "s/^started_h=.*/started_h=$(date '+%Y-%m-%d %H:%M:%S')/" "$rd/meta.env"
  set_state "$1" "running"
  ensure_watchdog
  launch_runner "$1" more
  echo "сессия '$1' продолжена новой задачей (контекст сохранён, id $sid)"
}

# дополнение на лету: живому рану — в inbox, мёртвому — новый заход (more)
cmd_say() {
  need_run "$1"
  [[ "$(meta_get "$1" mode)" == "tui" ]] && die "ран '$1' интерактивный — пиши прямо в его окно (go.sh attach $1)"
  local rd; rd="$(run_dir "$1")"
  if alive "$1"; then
    mkdir -p "$rd/inbox/done"
    local f="$rd/inbox/$(date +%s%N).txt"
    printf '%s' "$2" > "$f.tmp" && mv "$f.tmp" "$f"
    echo "передано в живой ран '$1' — подхватит после текущего прохода"
    # анти-гонка: ран мог финишировать, не заметив сообщение. Одноразовая проверка
    # по таймеру теряла файл, если teardown tmux длился дольше неё — поэтому цикл:
    # ждём, пока файл потреблён дренажем ЛИБО ран дошёл до терминального состояния
    local i
    for i in {1..10}; do
      sleep 3
      [[ -e "$f" ]] || return 0          # доставлено (дренаж забрал или в done/)
      alive "$1" && continue             # ран работает — очередь дойдёт штатно
      case "$(state_get "$1")" in
        running*)
          # tmux умер, state running — подберёт watchdog вместе с inbox,
          # но при исчерпанных рестартах watchdog поставит failed и очередь зависнет
          local rs; rs="$(cat "$rd/.restarts" 2>/dev/null || echo 0)"
          if (( rs >= MAX_RESTARTS )); then
            mv "$f" "$f.claim" 2>/dev/null || return 0   # файл уже забрали — доставлено
            rm -f "$f.claim"
            echo "ран исчерпал авто-рестарты — продолжаю сессию новым заходом"
            cmd_more "$1" "$2"
          else
            echo "ран упал — дополнение в очереди, watchdog доставит при возобновлении"
          fi
          return 0
          ;;
        *)
          # терминальное состояние: раннер очередь больше не заберёт.
          # mv-заявка: провал mv = файл забрал последний вздох дренажа = доставлено
          mv "$f" "$f.claim" 2>/dev/null || return 0
          rm -f "$f.claim"
          echo "ран успел завершиться, не увидев дополнение — продолжаю сессию новым заходом"
          cmd_more "$1" "$2"
          return 0
          ;;
      esac
    done
    # ~30с: ран жив и работает длинный проход — файл заберёт очередной дренаж
  else
    case "$(state_get "$1")" in
      running*)
        # ран упал и ждёт watchdog: more затёр бы возобновление исходной задачи —
        # кладём в inbox, revive доставит дополнение вместе с продолжением
        local rs; rs="$(cat "$rd/.restarts" 2>/dev/null || echo 0)"
        if (( rs >= MAX_RESTARTS )); then
          cmd_more "$1" "$2"
        else
          mkdir -p "$rd/inbox/done"
          local f="$rd/inbox/$(date +%s%N).txt"
          printf '%s' "$2" > "$f.tmp" && mv "$f.tmp" "$f"
          echo "ран упал и ждёт watchdog — дополнение в очереди, уйдёт ему при возобновлении"
        fi
        ;;
      *) cmd_more "$1" "$2" ;;
    esac
  fi
}

# тихое ожидание финала рана — для фоновой вахты из чата (Bash run_in_background)
cmd_await() {
  need_run "$1"
  local st
  while :; do
    st="$(state_get "$1")"
    case "$st" in
      finished*|failed*|stopped*) break ;;
    esac
    # legacy-раны без state: завершение определяем по смерти tmux
    if [[ -z "$st" ]] && ! alive "$1"; then st="finished $(meta_get "$1" exit_code)"; break; fi
    sleep 10
  done
  echo "go-run '$1' завершился: $st — прочитай REPORT.md и лог, доложи пользователю, затем go.sh ack $1"
}

cmd_ack() {
  need_run "$1"
  # ack во время running пометил бы «доложенной» ЕЩЁ НЕ завершённую задачу
  # (после параллельного more) и навсегда отключил бы хук-страховку
  [[ "$(state_get "$1")" == running* ]] && die "ран '$1' сейчас в работе — ack только после финиша"
  touch "$(run_dir "$1")/.reported"
  echo "ран '$1' помечен как доложенный"
}

# авто-восстановление: running-раны с умершим tmux перезапускаются продолжением сессии
cmd_watchdog() {
  exec 9>>"$RUNS_DIR/.watchdog.lock"
  flock -n 9 || exit 0
  local wl="$RUNS_DIR/.watchdog.log"
  [[ -f "$wl" && "$(stat -c%s "$wl" 2>/dev/null || echo 0)" -gt 262144 ]] && : > "$wl"
  local rd n st started now restarts
  now="$(date +%s)"
  for rd in "$RUNS_DIR"/*/; do
    [[ -d "$rd" ]] || continue
    n="$(basename "$rd")"
    st="$(state_get "$n")"
    [[ "$st" == running* ]] || continue
    [[ "$(meta_get "$n" mode)" == "tui" ]] && continue
    alive "$n" && continue
    started="$(meta_get "$n" started)"; started="${started:-0}"
    (( now - started < 90 )) && continue   # фора только что созданным ранам
    restarts="$(cat "$rd/.restarts" 2>/dev/null || echo 0)"
    if (( restarts >= MAX_RESTARTS )); then
      set_state "$n" "failed после $restarts авто-рестартов"
      local qn
      qn="$( { ls "${rd}inbox/"*.txt 2>/dev/null || true; } | grep -c . || true )"
      { printf '\n---\n[watchdog %s] ран падал %s раз(а); авто-восстановление остановлено, нужен разбор вручную (go.sh log %s).\n' \
          "$(date '+%F %T')" "$restarts" "$n"
        if [[ "$qn" -gt 0 ]]; then
          printf '[watchdog] в inbox остались недоставленные дополнения: %s шт — go.sh say после разбора.\n' "$qn"
        fi
      } >> "$rd/REPORT.md"
      echo "[watchdog $(date '+%F %T')] ран '$n' исчерпал рестарты — помечен failed"
      continue
    fi
    # финальная сверка перед вмешательством: закрывает гонки со stop и more
    [[ "$(state_get "$n")" == running* ]] || continue
    alive "$n" && continue
    echo $(( restarts + 1 )) > "$rd/.restarts"
    if [[ -n "$(jsonl_path "$(meta_get "$n" session_id)")" ]]; then
      printf 'Фоновый ран был прерван извне (упал процесс или перезагрузился сервер). Продолжи прерванную задачу с места остановки и доведи до конца. Итог — в %s.' \
        "$(run_dir "$n")/REPORT.md" > "$(run_dir "$n")/prompt.txt"
      launch_runner "$n" revive
    else
      # сессия так и не создалась — прежний prompt.txt с исходным ТЗ цел, стартуем с нуля
      launch_runner "$n" first
    fi
    echo "[watchdog $(date '+%F %T')] возобновил ран '$n' (рестарт $(( restarts + 1 )) из $MAX_RESTARTS)"
  done
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
  echo "run_state=$(state_get "$1")"
  local q r
  q="$( { ls "$rd/inbox/"*.txt 2>/dev/null || true; } | grep -c . || true )"
  [[ "$q" -gt 0 ]] && echo "inbox=дополнений в очереди: $q"
  r="$(cat "$rd/.restarts" 2>/dev/null || echo 0)"
  [[ "$r" -gt 0 ]] && echo "restarts=авто-восстановлений: $r"
  [[ -f "$rd/.reported" ]] && echo "reported=итог доложен в чат"
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
  local found=0 rd n st started task
  for rd in "$RUNS_DIR"/*/; do
    [[ -d "$rd" ]] || continue
    n="$(basename "$rd")"; found=1
    if alive "$n"; then
      st="жива"
    else
      case "$(state_get "$n")" in
        finished*) if [[ -f "$rd/.reported" ]]; then st="завершена"; else st="завершена·не доложена"; fi ;;
        failed*)   st="упала" ;;
        stopped*)  st="остановлена" ;;
        running*)  st="оборвана→watchdog" ;;
        *)         st="остановлена" ;;
      esac
    fi
    started="$(meta_get "$n" started_h)"
    task="$( { head -c 70 "$rd/task.txt" 2>/dev/null || head -c 70 "$rd/prompt.txt" 2>/dev/null || true; } | tr '\n' ' ' )"
    printf '%-22s %-22s %s  — %s\n' "$n" "$st" "${started:-?}" "${task:-?}"
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

cmd_stop() {
  need_run "$1"
  # стоп-метка ДО kill: иначе watchdog воскресит ран как «упавший»
  case "$(state_get "$1")" in
    running*|"") set_state "$1" "stopped $(date '+%F %T')" ;;
  esac
  tmux kill-session -t "$(tmux_name "$1")" 2>/dev/null && echo "остановлена: $1 (watchdog не воскресит)" || echo "уже не работает: $1"
}

case "${1:-}" in
  run)     shift; cmd_run "$@" ;;
  _runner) shift; cmd_runner "${1:?имя}" "${2:-first}" ;;
  list|ls) cmd_list ;;
  status)  shift; cmd_status "${1:?имя}" ;;
  log)     shift; cmd_log "${1:?имя}" "${2:-20}" ;;
  tail)    shift; need_run "$1"; tail -f "$(run_dir "$1")/raw.log" | sed -u 's/\x1b\[[0-9;?]*[a-zA-Z]//g' ;;
  more)    shift; cmd_more "${1:?имя}" "${2:?текст задачи}" ;;
  say)     shift; cmd_say "${1:?имя}" "${2:?текст дополнения}" ;;
  await)   shift; cmd_await "${1:?имя}" ;;
  ack)     shift; cmd_ack "${1:?имя}" ;;
  watchdog) cmd_watchdog ;;
  back)    shift; cmd_back "${1:?имя}" ;;
  attach)  shift; need_run "$1"; exec tmux attach -t "$(tmux_name "$1")" ;;
  stop)    shift; cmd_stop "${1:?имя}" ;;
  ""|-h|--help|help) usage ;;
  *) die "неизвестная команда: $1 (go.sh --help)" ;;
esac
