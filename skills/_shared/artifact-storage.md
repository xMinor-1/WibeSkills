# Хранение артефактов эпика

Применяется в `market-research`, `epic-prd`, `ux-patterns`, `epic-preview`, `epic-tech-spec`, `epic-arch-review`, `agile-coach decompose`.

**Артефакты живут на диске — это единственный источник правды.** Трекер (Notion / Linear / Jira) не нужен ядру pipeline. Если он подключён — зеркалит на диск опциональный скилл `tracker-sync` по запросу, ядро про трекер ничего не знает.

## Структура папки эпика

```
DOCS_ROOT/<epic-slug>/
├── market-research.md   ← market-research (опц.)
├── PRD.md               ← epic-prd
├── ux-patterns.md       ← ux-patterns — паттерн-контракт для preview
├── preview/index.html   ← epic-preview
├── tech-spec.md         ← epic-tech-spec
├── arch-review.md       ← epic-arch-review
├── stories.md           ← agile-coach decompose — файловый бэклог: Stories + Tasks + статусы
└── reviews/<task-slug>.md  ← task-cross-review
```

Документация фичи после релиза — отдельно: `DOCS_ROOT/<feature-slug>/{user,support,analytics}.md`.
Инсайты аналитики — `DOCS_ROOT/insights/<YYYY-MM-DD>.md`.
База UX-паттернов проекта (накопительная, ведёт `ux-patterns`) — `DOCS_ROOT/ux-foundation/pattern-library.md`.

## Навигация по эпику

В начале `PRD.md` — блок «📚 Артефакты эпика» со списком файлов и их статусом:

```
## 📚 Артефакты эпика
- 📄 PRD.md — ✅ готов
- 🧭 ux-patterns.md — будет создан ux-patterns
- 🎨 preview/index.html — будет создан epic-preview
- 🔧 tech-spec.md — будет создан epic-tech-spec
- 🏗 arch-review.md — будет создан epic-arch-review
- 📦 stories.md — будет создан agile-coach decompose
```

Каждый скилл при создании своего артефакта обновляет статус строки в этом блоке (✅ + вердикт, если есть).

## stories.md — файловый бэклог

Ведёт `agile-coach`. Содержит Stories и Tasks эпика со статусами (`todo / in-progress / review / testing / done / blocked`), orchestration-граф (parallel groups, dependencies, touches), AC Story, manual gate. Скиллы `task-*` читают и обновляют статусы прямо в этом файле. Формат — в [backlog.md](backlog.md).

## Запрет

Артефакт пишется в свой файл и больше никуда. Зеркалирование в трекер — только через `tracker-sync` и только по явному запросу пользователя.
