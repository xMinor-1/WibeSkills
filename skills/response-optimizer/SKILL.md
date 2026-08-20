---
name: response-optimizer
description: Фоновый оптимизатор ответов — НЕ вызывается руками и НЕ активируется по триггер-фразам. Работает автоматически через хуки Claude Code, настроенные в ~/.claude/settings.json — SessionStart подсовывает full.md при старте сессии, UserPromptSubmit подсовывает light.md на каждый ввод пользователя. Эта карточка нужна только как источник файлов и инструкция подключения на новой машине.
recommended_model: sonnet
---

# response-optimizer — фоновый оптимизатор ответов

Скилл не участвует в pipeline и не вызывается вручную. Его файлы уходят в контекст хуками Claude Code:

- `full.md` — полный свод правил, инъекция при старте сессии (`SessionStart`, matcher `startup|clear|compact` — правила возвращаются после `/clear` и компакта контекста); тем же хуком целиком подаётся `_shared/communication-style.md`;
- `light.md` — выжимка, инъекция на каждый ввод пользователя (`UserPromptSubmit`, матчеров не имеет);
- `style-light.md` — выжимка стиля, идёт на каждый ввод вместе с `light.md`. Собирается скриптом `build-style-light.py` из блоков `<!-- light:... -->` в `_shared/communication-style.md` (пересборка — первым хуком `SessionStart`); руками не править — перезаписывается.

Файлы-инъекции — без frontmatter: они целиком попадают в контекст.

## Подключение на новой машине

В `~/.claude/settings.json` задать `env.WIBESKILLS` (путь к библиотеке на этой машине; тот же путь — фоллбэком в `${WIBESKILLS:-...}`) и блок `hooks`. `2>/dev/null || true` — чтобы отсутствие файла не валило хук:

```json
"env": {
  "WIBESKILLS": "/home/coder/Work/3. projects/WibeSkills"
},
"hooks": {
  "SessionStart": [
    {
      "matcher": "startup|clear|compact",
      "hooks": [
        { "type": "command", "command": "python3 \"${WIBESKILLS:-/home/coder/Work/3. projects/WibeSkills}/skills/response-optimizer/build-style-light.py\" 2>/dev/null || true" },
        { "type": "command", "command": "cat \"${WIBESKILLS:-/home/coder/Work/3. projects/WibeSkills}/skills/response-optimizer/full.md\" 2>/dev/null || true" },
        { "type": "command", "command": "cat \"${WIBESKILLS:-/home/coder/Work/3. projects/WibeSkills}/skills/_shared/communication-style.md\" 2>/dev/null || true" }
      ]
    }
  ],
  "UserPromptSubmit": [
    {
      "hooks": [
        { "type": "command", "command": "cat \"${WIBESKILLS:-/home/coder/Work/3. projects/WibeSkills}/skills/response-optimizer/light.md\" 2>/dev/null || true" },
        { "type": "command", "command": "cat \"${WIBESKILLS:-/home/coder/Work/3. projects/WibeSkills}/skills/response-optimizer/style-light.md\" 2>/dev/null || true" }
      ]
    }
  ]
}
```

В боевом settings.json в `UserPromptSubmit` стоит ещё хук `skills/go/notify-hook.sh` — это часть скилла `go`, к response-optimizer не относится.

Проверка: `jq . ~/.claude/settings.json` (валидность), затем новая сессия — при старте в контексте полный текст, с каждым вводом приходит лёгкая версия. В VS Code изменения подхватываются после Restart Extension Host.

## Стоимость по токенам

- `full.md` + `communication-style.md` — разово при старте / `/clear` / компакте.
- `light.md` + `style-light.md` — на каждый ввод; урезать — сокращать `light.md` и light-блоки в `communication-style.md` (style-light.md пересоберётся сам).
