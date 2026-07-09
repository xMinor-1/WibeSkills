---
name: task-cross-review
description: Параллельное кросс-ревью задачи 4 ревьюерами — код-качество, безопасность (OWASP + юр-режим), UX vs PRD, полнота аналитики. Активируется на «task-cross-review», «кросс-ревью», «прогони ревью», «проверь PR». Шаг 7 продуктового workflow.
recommended_model: sonnet
---

# Task Cross Review

Прогоняешь diff feature-ветки через **4 параллельных ревьюера**. Task в статусе `review` в `stories.md`.

Контекст — `../_shared/project-config.md` + проектный `CLAUDE.md`. Approve — `../_shared/approve-protocol.md`. Бэклог — `../_shared/backlog.md`. Хендофф — `../_shared/handoff-protocol.md`. Worktree — `../_shared/worktree-protocol.md`.

## Режим (app-only)

Прочитай `MODE` — `../_shared/mode.md`. Если `MODE: work` — **стоп, не разворачивай pipeline**: в work-режиме финальный код пишет живой программист. Объясни это одной строкой и предложи `dev-handoff` (handoff-пакет) либо `epic-tech-spec` (спека для разработчика). Жди решения. Если `app` или MODE не задан — пропусти этот блок, работай как обычно.

## Workflow-режим (внутри `delivery-run`)

В авто-оркестрации **4 линзы запускает сам оркестратор** параллельными read-only сабагентами (сабагент не может спавнить вложенных) — промпты линз берёт из Шага 2 ниже, синтез и вердикт делает по Шагу 3. Сабагент-ревьюер одной линзы: читай diff Story-ветки, верни structured output с находками (file:line, severity), — без хендоффов и записи статусов. Лимит петли 2 раунда считает оркестратор; исчерпан → `needs_decision`. Контракт — `../_shared/delivery-workflow.md`.

## Старт

Approve **не нужен**. Иду делать. Worktree Story уже существует на диске — `cd` в него (`git worktree list`).

## Шаг 1: Diff

```bash
git diff <MAIN_BRANCH>...feature/<epic-slug>/<story-slug>
git log <MAIN_BRANCH>..feature/<epic-slug>/<story-slug>
```

## Шаг 2: Параллельный запуск 4 ревьюеров

В одном сообщении (не последовательно) — `Agent` tool. Ревьюеры read-only, isolation не нужен.

### 1. Код-качество (`feature-dev:code-reviewer`)
> «Ревью diff против Clean Code + Clean Architecture (см. проектный CLAUDE.md, `ARCH_PATTERN`). Проверь: слои не нарушены, имена понятные, без дублирования, без преждевременных абстракций, без мёртвых комментариев. Только high-confidence проблемы.»

### 2. Безопасность
> «Ревью diff на безопасность: OWASP Top 10 (XSS, инъекции, CSRF, broken auth, sensitive exposure), валидация входов на сервере, требования юр-режима LEGAL_REGIME (персональные данные: шифрование/хеши, не логируем plain; audit-логи на ключевых действиях). Список конкретных уязвимостей с file:line.»

### 3. UX vs PRD
> «Открой `DOCS_ROOT/<epic-slug>/PRD.md` и сравни реализацию с acceptance criteria. Что покрыто, что не покрыто, где UX противоречит PRD. Edge cases — все ли обработаны?»

### 4. Аналитика
> «Открой `DOCS_ROOT/<epic-slug>/PRD.md` (Tracked events) и `tech-spec.md` (Tracked events) → проверь, что **каждое** событие реально вызывается через `TRACK_HELPER`. Список: что покрыто, что пропущено, где параметры не совпадают со спекой.»

## Шаг 3: Финальный синтез + разрешение конфликтов

Прочитай `templates/cross-review.md`. Создай `DOCS_ROOT/<epic-slug>/reviews/<task-slug>.md` по структуре.

Ревьюеры независимы — могут давать **противоречивые** рекомендации. Разрешай по приоритету:

1. **Безопасность / юр-режим** — побеждает всегда
2. **Корректность по PRD AC** — следующий
3. **UX** — третий
4. **Код-стилистика** — последний (часто можно отложить)

В отчёт пиши **разрешённый** список фиксов, не сырые рекомендации каждого.

Сомневаешься в API библиотеки (паттерн кажется устаревшим/новым) — Context7 MCP за свежей докой, чтобы не ловить ложные блокеры.

**Правила вердикта:**
- Любой блокер по безопасности или юр-режиму → `BLOCK`
- Непокрытые AC или незатреканные events → `CHANGES REQUESTED`
- Только minor/nits → `APPROVE`

## Шаг 4: Обновление бэклога + хендофф

Применяй `../_shared/handoff-protocol.md`.

- **APPROVE** — статус Task в `stories.md` → `testing`, закоммить. Хендофф:
  > Готово: cross-review Task `<task-slug>` — APPROVE, отчёт `DOCS_ROOT/<epic-slug>/reviews/<task-slug>.md`
  > Следующий шаг: task-test
  > Промпт: `Запусти task-test для Task "<task-slug>" эпика "<epic-slug>". Ветка feature/<epic-slug>/<story-slug>, бэклог — DOCS_ROOT/<epic-slug>/stories.md.`

- **CHANGES REQUESTED / BLOCK** — статус Task → `in-progress`, в `stories.md` рядом с Task допиши список фиксов + **счётчик раунда** (`cross-review раунд 1/2`), закоммить. Хендофф назад:
  > Готово: cross-review Task `<task-slug>` — CHANGES (раунд N/2). Что чинить: <список>
  > Следующий шаг: task-build (доработка)
  > Промпт: `Запусти task-build для Task "<task-slug>" эпика "<epic-slug>" — доработка по cross-review (раунд N/2). Список фиксов — в DOCS_ROOT/<epic-slug>/reviews/<task-slug>.md и stories.md. Ветка feature/<epic-slug>/<story-slug>.`

**Лимит петли cross-review ↔ build = 2 раунда per Task.** После 2-го `CHANGES/BLOCK` подряд — не готовь хендофф назад, эскалируй пользователю:
> «Task `<slug>`: после 2 раундов ревью + правок не сходимся. Что не закрылось: <список>. Нужно решение: A) принять как есть, B) переписать с другой стратегией, C) разбить на 2 поменьше.»

## Принципы

- Все 4 ревьюера — **параллельно** одним сообщением.
- Не дублируй работу ревьюеров: они читают код сами, ты — агрегатор.
- Confidence-based: minor стилистика без объяснения «почему плохо в нашем контексте» — не в Critical.
- **Считай раунды.** Лимит — 2.
