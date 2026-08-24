---
name: response-optimizer
description: Фоновый хук стиля — НЕ вызывается руками и НЕ активируется по триггер-фразам. Работает автоматически через хуки Claude Code в ~/.claude/settings.json — UserPromptSubmit подсовывает style-light.md (выжимку _shared/communication-style.md) на каждый ввод пользователя, SessionStart пересобирает выжимку. Эта карточка нужна только как инструкция подключения на новой машине.
recommended_model: sonnet
---

# response-optimizer — фоновый хук стиля

Скилл не участвует в pipeline и не вызывается вручную. Держит правила стиля общения
(zero-slop, бизнес-язык, approve-список) у конца контекста — рядом с последним сообщением,
где они не «выветриваются» в длинной сессии:

- `style-light.md` — выжимка стиля, инъекция на каждый ввод пользователя (`UserPromptSubmit`).
  Собирается скриптом `build-style-light.py` из блоков `<!-- light:... -->` в
  `_shared/communication-style.md`; руками не править — перезаписывается.
- `build-style-light.py` — пересборка выжимки; гоняется хуком `SessionStart`
  (matcher `startup|clear|compact`), чтобы правки communication-style подхватывались.
  `--check` — проверить актуальность без записи.

Полная версия правил живёт в `_shared/communication-style.md` и в контекст хуками
не подаётся: скиллы читают её сами, когда готовят артефакт для людей.
История: раньше хуки инжектили ещё `full.md` + `light.md` (универсальный «Response
Optimizer») и полный communication-style на старте — убрано 2026-08-21 как дубль
глобального CLAUDE.md (~2.5 тыс. токенов на сообщение → ~1.5 тыс.).

Файл-инъекция — без frontmatter: он целиком попадает в контекст.

## Подключение на новой машине

В `~/.claude/settings.json` задать `env.WIBESKILLS` (путь к библиотеке на этой машине;
тот же путь — фоллбэком в `${WIBESKILLS:-...}`) и блок `hooks`. `2>/dev/null || true` —
чтобы отсутствие файла не валило хук:

```json
"env": {
  "WIBESKILLS": "/home/coder/Work/3. projects/WibeSkills"
},
"hooks": {
  "SessionStart": [
    {
      "matcher": "startup|clear|compact",
      "hooks": [
        { "type": "command", "command": "python3 \"${WIBESKILLS:-/home/coder/Work/3. projects/WibeSkills}/skills/response-optimizer/build-style-light.py\" 2>/dev/null || true" }
      ]
    }
  ],
  "UserPromptSubmit": [
    {
      "hooks": [
        { "type": "command", "command": "cat \"${WIBESKILLS:-/home/coder/Work/3. projects/WibeSkills}/skills/response-optimizer/style-light.md\" 2>/dev/null || true" }
      ]
    }
  ]
}
```

В боевом settings.json в `UserPromptSubmit` стоит ещё хук `skills/go/notify-hook.sh` —
это часть скилла `go`, к response-optimizer не относится.

Проверка: `jq . ~/.claude/settings.json` (валидность), затем новая сессия — с каждым
вводом приходит выжимка стиля. В VS Code изменения подхватываются после Restart Extension Host.

## Стоимость по токенам

`style-light.md` (~4.8 КБ) — на каждый ввод. Урезать — сокращать light-блоки
в `_shared/communication-style.md` (выжимка пересоберётся сама на старте сессии).
