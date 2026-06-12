# WibeSkills

**Библиотека скиллов продуктовой разработки для Claude Code** — полный цикл от идеи до прода (workflow Epic → Story → Task, русский язык), усиленный методологией **Next Move Theory / Advanced Jobs To Be Done** Вани Замесина. Канон методологии подключён как git submodule и читается скиллами в рантайме — методология обновляется через `git pull`, а не переписыванием скиллов.

## Состав

```
WibeSkills/
├── skills/        ← библиотека скиллов (см. skills/README.md)
│   ├── _shared/   ← общие протоколы: project-config, handoff, backlog, approve…
│   └── <скиллы>/  ← продуктовый pipeline + standalone-скиллы
├── canon/         ← submodule: Next-Move-Theory-Canon-and-Skills (Ivan Zamesin)
└── ROADMAP.md     ← план слияния скиллов Замесина в наш workflow
```

**Продуктовый pipeline:** `market-research` → `craft-value-proposition` → `epic-prd` → `epic-preview` → `epic-tech-spec` → `epic-arch-review` → `agile-coach decompose` → `task-build` → `task-cross-review` → `task-test` → `task-docs` → `task-ship` → `analytics-insights` (замыкание цикла).

**Standalone:** `ask-nmt`*, `marketing-gtm`, `marketing-copywriting`, `marketing-promotion`, `marketing-smm`, `epic-legal-review`, `tracker-sync`, `pipeline-retro`, `video-distill`.

\* — портируется из скиллов Замесина, см. [ROADMAP.md](ROADMAP.md).

## Как подключить

```bash
# 1. Клонируй вместе с каноном
git clone --recurse-submodules https://github.com/xMinor-1/WibeSkills.git

# 2. Подключи библиотеку к рабочей папке (симлинк — правки сразу версионируются)
ln -s /path/to/WibeSkills/skills /path/to/workspace/.claude/skills

# 3. Скопируй skills/_shared/project-config.md в проект и заполни
cp WibeSkills/skills/_shared/project-config.md <project>/.claude/project-config.md
```

## Обновление канона

```bash
git submodule update --remote canon
git add canon && git commit -m "canon: bump to upstream"
```

## Статус

🚧 WIP — идёт слияние скиллов Замесина в наш workflow. План и прогресс — в [ROADMAP.md](ROADMAP.md).

## Атрибуция и лицензия

Методология Advanced Jobs To Be Done и Next Move Theory, а также канон в `canon/` — **Ivan Zamesin** ([nextmovetheory.com](https://nextmovetheory.com), [github.com/zamesin](https://github.com/zamesin/Next-Move-Theory-Canon-and-Skills)). Часть скиллов этой библиотеки — производные от его скиллов и канона.

Репозиторий распространяется по [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/) — см. [LICENSE.md](LICENSE.md): свободное использование и адаптация с указанием авторства, некоммерчески, производные — под той же лицензией.
