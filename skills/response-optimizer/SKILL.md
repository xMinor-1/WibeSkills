---
name: response-optimizer
description: Фоновый оптимизатор ответов — НЕ вызывается руками и НЕ активируется по триггер-фразам. Работает автоматически через хуки Claude Code, настроенные в ~/.claude/settings.json — SessionStart подсовывает full.md при старте сессии, UserPromptSubmit подсовывает light.md на каждый ввод пользователя. Эта карточка нужна только как источник файлов и инструкция подключения на новой машине.
recommended_model: sonnet
---

# response-optimizer — фоновый оптимизатор ответов

Скилл не участвует в pipeline и не вызывается вручную. Его файлы уходят в контекст хуками Claude Code:

- `full.md` — полный свод правил, инъекция при старте сессии (`SessionStart`, matcher `startup|clear|compact` — правила возвращаются после `/clear` и компакта контекста);
- `light.md` — выжимка, инъекция на каждый ввод пользователя (`UserPromptSubmit`, матчеров не имеет).

Оба файла — без frontmatter: они целиком попадают в контекст.

## Подключение на новой машине

В `~/.claude/settings.json` добавить блок `hooks` (путь поправить под расположение библиотеки):

```json
"hooks": {
  "SessionStart": [
    {
      "matcher": "startup|clear|compact",
      "hooks": [
        { "type": "command", "command": "cat /home/coder/Work/projects/WibeSkills/skills/response-optimizer/full.md" }
      ]
    }
  ],
  "UserPromptSubmit": [
    {
      "hooks": [
        { "type": "command", "command": "cat /home/coder/Work/projects/WibeSkills/skills/response-optimizer/light.md" }
      ]
    }
  ]
}
```

Проверка: `jq . ~/.claude/settings.json` (валидность), затем новая сессия — при старте в контексте полный текст, с каждым вводом приходит лёгкая версия. В VS Code изменения подхватываются после Restart Extension Host.

## Стоимость по токенам

- `full.md` — ~800 токенов один раз при старте / `/clear` / компакте.
- `light.md` — ~200 токенов на каждый ввод; при желании урезать — сокращать именно этот файл.
