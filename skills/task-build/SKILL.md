---
name: task-build
description: Реализует одну Task из файлового бэклога — пишет код в feature-ветке, добавляет tracked events, автотесты, соблюдая Clean Code + Clean Architecture. Активируется на «task-build», «возьми задачу», «начни делать <задача>», «реализуй». Шаг 6 продуктового workflow.
recommended_model: opus
---

# Task Build

Берёшь Task из бэклога эпика (`DOCS_ROOT/<epic-slug>/stories.md`, статус `todo`), пишешь код в feature-ветке, покрываешь автотестами, добавляешь events.

Контекст — `../_shared/project-config.md` + проектный `CLAUDE.md`. Approve — `../_shared/approve-protocol.md`. Бэклог — `../_shared/backlog.md`. Хендофф — `../_shared/handoff-protocol.md`. Worktree — `../_shared/worktree-protocol.md`.

## Режим (app-only)

Прочитай `MODE` — `../_shared/mode.md`. Если `MODE: work` — **стоп, не разворачивай pipeline**: в work-режиме финальный код пишет живой программист. Объясни это одной строкой и предложи `dev-handoff` (handoff-пакет) либо `epic-tech-spec` (спека для разработчика). Жди решения. Если `app` или MODE не задан — пропусти этот блок, работай как обычно.

## Workflow-режим (если ты сабагент внутри `delivery-run`)

Промпт сказал «Workflow-режим» — работаешь по контракту `../_shared/delivery-workflow.md`:
- **Пропусти** Шаг 2 (Story-worktree): работай в выданном изолированном worktree, коммить в своей task-ветке.
- **Пропусти** Шаг 8 (хендофф-блок) и обновления статусов в `stories.md` (Старт п.2, Шаг 7) — статусы пишет оркестратор.
- Approve-операции (миграции, auth/payments) **не выполняй** — верни `needs_approve`.
- Верни structured output: status (`ok`/`needs_approve`/`blocked`), branch, sha, затронутые файлы, 1-2 строки итога.
- TRACK=prd/fast (нет preview/tech-spec): работай от PRD-machine (lite-tech-spec-секция); UI — без preview-эталона, отметь это в итоге.

Остальные шаги (контекст, реализация, events, автотесты, LOCAL_CHECK, коммит) — как написано ниже.

## Старт

Approve **не нужен** для обычной задачи (локальные правки в feature-ветке).
Approve **нужен** если задача затрагивает: миграции БД, auth/payments/referrals.

Задача не указана явно — возьми **топ из `stories.md`**: Task статуса `todo` с чистыми `deps`, из самой ранней parallel group (логика — `../_shared/backlog.md`).

После выбора:
1. Открой Task в `stories.md` → читай описание, родительскую Story, orchestration-блок.
2. Статус Task в `stories.md` → `in-progress`. Пересчитай rollup Story (алгоритм — `../_shared/backlog.md`), закоммить `stories.md`.

## Шаг 1: Контекст

1. Читай `DOCS_ROOT/<epic-slug>/PRD.md` + `tech-spec.md`.
2. Нужна архитектурная подсказка — subagent `feature-dev:code-architect`.
3. Нужно глубокое понимание текущего кода — subagent `feature-dev:code-explorer`.
4. Сомневаешься в текущем API библиотеки стека — Context7 MCP за свежими доками (если подключён). Не для базовых вещей.

## Шаг 2: Worktree + ветка

Следуй `../_shared/worktree-protocol.md`: **1 Story = 1 worktree = 1 ветка** `feature/<epic-slug>/<story-slug>`.
- Первая Task Story — создай worktree из `MAIN_BRANCH`.
- Следующая Task той же Story — worktree уже существует на диске (этот скилл — новый чат), `cd` в него.

## Шаг 3: Реализация (Clean Architecture, паттерн ARCH_PATTERN)

См. `ARCH_PATTERN` в project-config + проектный `CLAUDE.md`. Типовые слои:
- `domain/` — типы и чистые функции (без зависимостей)
- `use-cases/` — бизнес-логика, зависимости через параметры
- `ports/` — интерфейсы
- `infra/` — адаптеры (репозитории ORM, внешние API)
- `ui/` — компоненты

**Принципы:**
- Имена читаются как текст без комментариев
- Маленькие функции, одна ответственность
- Не дублируй существующий код — переиспользуй
- Не делай преждевременных абстракций
- Комментарии — только если «почему» неочевидно

**Если Task — UI:**
1. Открой `DOCS_ROOT/<epic-slug>/preview/index.html` (или `e2e/preview-fixtures/...`) side-by-side.
2. Найди в tech-spec секцию «Preview → Code mapping».
3. Реализуй компонент, **повторяя разметку preview** (тот же DOM, классы, структура). Подключи реальные данные.
4. Не «улучшай» preview — это эталон. Видишь проблему — отдельный feedback в `epic-preview` чат.
5. Visual regression в `task-test` сравнит с baseline. Расхождение >5% → красный.

**Юридический режим (если LEGAL_REGIME задан в модуле B, при работе с ПДн):**
- Хеши/шифрование где требует tech-spec
- Валидация на сервере для всех полей с персональными данными
- Не логируй ПДн в plain (маскированные / хешированные)
- Любое значимое действие → запись в audit-таблицу (кто, что, над чем, когда, ip)

## Шаг 4: Tracked events

Все из tech-spec — через `TRACK_HELPER` (модуль A project-config). Helper'а ещё нет — создай в этой задаче (если в scope) или попроси отдельную задачу. Не вызывай провайдер аналитики напрямую из компонентов.

## Шаг 5: Автотесты

**Обязательно** для каждой задачи:
- **Unit (`TEST_RUNNER`)** — на бизнес-логику в `domain/` и `use-cases/`
- **E2E (`E2E`)** — минимум 1 happy path на AC
- **Edge cases** — по 1 тесту на каждый edge case из PRD

Не пиши тесты как формальность — должны падать на пустой реализации, зеленеть после.

## Шаг 6: Локальная проверка

Запусти `LOCAL_CHECK` (из project-config). Порядок важен: typecheck → lint → build → test.

Что-то падает — чини **до** передачи дальше, не пуш.

**Лимит:** максимум 3 попытки авто-fix на чёрно-белый сигнал. После 3 — стоп, отчёт на бизнес-языке («не получается дотянуть Task X, упёрлись в Y, нужно решение»).

## Шаг 7: Коммит

```bash
git add <конкретные файлы>
git commit -m "feat(<area>): <что>"
```

Не используй `git add -A`. Hooks — НЕ обходить через `--no-verify`.

Статус Task в `stories.md` → `review`, рядом допиши ветку и список затронутых файлов. Закоммить `stories.md`.

## Шаг 8: Хендофф

Применяй `../_shared/handoff-protocol.md`:
> Готово: Task `<task-slug>` реализована, ветка `feature/<epic-slug>/<story-slug>`, статус → review
> Следующий шаг: task-cross-review
> Промпт: `Запусти task-cross-review для Task "<task-slug>" эпика "<epic-slug>". Ветка feature/<epic-slug>/<story-slug>, бэклог — DOCS_ROOT/<epic-slug>/stories.md.`

## Принципы

- Не пушь в `MAIN_BRANCH`, всегда feature-ветка.
- Не правь чужой код «попутно» — только то, что в scope.
- Упёрся в архитектурный конфликт — стоп, поднимай в `epic-arch-review`, не правь tech-spec на лету.
