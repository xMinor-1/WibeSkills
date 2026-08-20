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

**Оси поведения:** MODE (`app`/`work` — кто доводит до прода, `_shared/mode.md`) × TRACK (`fast`/`prd`/`indie`/`enterprise` — сколько discovery и для кого PRD, `_shared/tracks.md`). Вход в любую задачу — роутер `kickoff`. Единая карта маршрутизации — `_shared/handoff-protocol.md`.

**Продуктовый pipeline:** `kickoff` → [`mvp` (трек fast) | `epic-prd` (трек prd) | `market-research` → `craft-value-proposition` → `epic-prd` (треки indie/enterprise)] → `ux-patterns` (шаг 1.5: паттерн-контракт для preview) → `epic-preview` → `epic-tech-spec` → `epic-arch-review` → `agile-coach decompose` → **`delivery-run`** (авто-оркестрация `task-build → task-cross-review → task-test → task-docs` сабагентами через Workflow, сегментами между человеческими гейтами; контракт — `_shared/delivery-workflow.md`) → `task-ship` → `analytics-insights` (замыкание цикла). Ручной фоллбэк delivery — task-скиллы по одному. В MODE=work инженерная часть заканчивается `dev-handoff` — пакетом для живого разработчика вместо delivery-контура.

**Два PRD:** `epic-prd` имеет два шаблона — PRD-machine (инженерный контракт для агентов/кода) и PRD-human (документ-решение для людей, формат эталонов X5). Выбор — по треку.

**Standalone:** `ask-nmt`, `triz-resolve`, `helpx5`, `go`/`goon`, `response-optimizer`, `marketing-gtm`, `marketing-copywriting`, `marketing-promotion`, `marketing-smm`, `epic-legal-review`, `tracker-sync`, `todo`, `pipeline-retro`, `video-distill`.

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
