---
name: task-test
description: Прогоняет автотесты задачи (до 3 попыток авто-fix), e2e против acceptance criteria PRD, останавливается для manual-показа на prod-build. Активируется на «task-test», «прогони тесты», «протестируй задачу». Шаг 8 продуктового workflow.
recommended_model: sonnet
---

# Task Test

Гейты: **unit → e2e (per-Task AC + NFR) → Story manual gate на prod-build (если Task последняя в Story)**. Task в статусе `testing` в `stories.md`.

Контекст — `../_shared/project-config.md` + проектный `CLAUDE.md`. Approve — `../_shared/approve-protocol.md`. Бэклог — `../_shared/backlog.md`. Хендофф — `../_shared/handoff-protocol.md`. Worktree — `../_shared/worktree-protocol.md`.

## Старт

Approve **не нужен**. Иду делать. Worktree Story уже на диске — `cd` в него.

## Шаг 1: Unit-тесты (`TEST_RUNNER`)

Запусти unit-команду из `LOCAL_CHECK`.

**Падают — до 3 попыток авто-fix.** После 3 — стоп, отчёт на бизнес-языке.

**Не правь сам тест, чтобы он зеленел.** Чини **код**. Тест действительно неверный — отдельный коммит с обоснованием.

## Шаг 2: E2E (`E2E`) против AC + NFR

Тестов на AC/NFR этой Task нет — сгенерируй из `DOCS_ROOT/<epic-slug>/PRD.md` (Acceptance criteria + NFR) и `tech-spec.md` (Реализация NFR). Покрывай:
- 1 e2e на каждый AC Task
- 1 e2e на каждый NFR Task с автопроверкой (performance, sticky, keyboard, viewport)
- 1 e2e на каждый edge case Task

При падении — **1 повтор авто-fix** (не 3). После — стоп, отчёт. Лимит петли см. `../_shared/handoff-protocol.md`.

Падение связано с непонятным API e2e-инструмента — Context7 MCP за свежим API перед повтором.

## Шаг 3: Полнота событий

Проверь, что в реальном прогоне e2e события долетают до `ANALYTICS_PROVIDER` (через тестовый fixture; нет fixture'а — создай в этой задаче). Сверяй с tech-spec.

## Шаг 3.5: Visual regression (только для UI-задач)

Task создаёт/меняет UI-компонент с записью в «Preview → Code mapping» (tech-spec) — добавь визуальный тест: скриншот страницы сравнивается с baseline preview-фикстуры, `maxDiffPixelRatio: 0.05`.

Baseline генерируется первым прогоном против preview-фикстуры. При расхождении >5%:
- Код отошёл от preview случайно → чини код
- Preview устарел осознанно → обнови фикстуру + новый baseline (с записью в коммите «обновили эталон, причина: X»)
- НЕ обновляй baseline молча — это сломает контракт

## Шаг 4: Task done

Все тесты Task зелёные — статус Task в `stories.md` → проверь, последняя ли это Task Story:
- **Не последняя** — статус Task → `done`, пересчитай rollup Story, закоммить `stories.md`. Manual gate здесь НЕ запускается (он на уровне Story). Иди в Шаг 6.
- **Последняя в Story** — статус Task → `done`, иди в Шаг 5 (Story-level gate).

## Шаг 5: Story-level gate (только если эта Task — последняя в Story)

Все Tasks Story в `done` и все e2e зелёные — собираем Story manual gate **на prod-build** (не dev): сделай prod-build + start, прогони Story-уровень e2e (все AC всех Tasks Story).

После зелёного прогона — ⏸ **реальный гейт**, решает человек:

> «Story `<slug>` собрана на prod-build (localhost). E2e зелёные: N AC + M NFR. Открой и проверь UX-санити:
> 1. <ключевой flow Story>
> 2. <критичный UX-инвариант — клавиатура / sticky / 320px>
> 3. <финальное "выглядит как я хочу?">
>
> Скажи: ✅ Story готова к ship / ❌ что не так»

**Жди ответа.** Manual gate — короткий sanity, не полный flow (полный покрыт e2e).

## Шаг 6: Хендофф

Применяй `../_shared/handoff-protocol.md`.

- **Task done, не последняя в Story** — следующий шаг `task-docs`:
  > Готово: тесты Task `<task-slug>` зелёные, статус → done
  > Следующий шаг: task-docs
  > Промпт: `Запусти task-docs для Task "<task-slug>" эпика "<epic-slug>". Ветка feature/<epic-slug>/<story-slug>, бэклог — DOCS_ROOT/<epic-slug>/stories.md.`

- **Story ✅ на гейте** — следующий шаг `task-ship`:
  > Готово: Story `<story-slug>` собрана на prod-build, e2e зелёные, manual ✅
  > Следующий шаг: task-ship
  > Промпт: `Запусти task-ship для Story "<story-slug>" эпика "<epic-slug>". Ветка feature/<epic-slug>/<story-slug>, бэклог — DOCS_ROOT/<epic-slug>/stories.md.`

- **❌ на гейте** — статус Task → `in-progress`, описание проблемы в `stories.md`, хендофф назад в `task-build`:
  > Готово: Story manual gate — ❌. Что не так: <описание>
  > Следующий шаг: task-build (доработка)
  > Промпт: `Запусти task-build для эпика "<epic-slug>" — доработка Story "<story-slug>" по результату manual gate: <проблема>. Ветка feature/<epic-slug>/<story-slug>, бэклог — DOCS_ROOT/<epic-slug>/stories.md.`

## Принципы

- Не правь тест, чтобы он зеленел — чини код.
- Не помечай Story-задачу `done` пока пользователь не подтвердил Story manual.
- Долгие тесты — `run_in_background`.
- Падают — root cause, не shortcut. `--no-verify` не использовать.
- **Manual ВСЕГДА на prod-build, не dev.**
