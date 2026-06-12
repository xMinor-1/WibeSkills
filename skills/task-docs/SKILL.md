---
name: task-docs
description: Генерирует пользовательскую документацию + support-документацию для AI-агентов + analytics.md со списком событий. Активируется на «task-docs», «сделай документацию», «опиши фичу». Шаг 9 продуктового workflow.
recommended_model: sonnet
---

# Task Docs

Документируешь готовую задачу в **3 файла**. После зелёных тестов в `task-test`.

Контекст — `../_shared/project-config.md` + проектный `CLAUDE.md`. Approve — `../_shared/approve-protocol.md`. Бэклог — `../_shared/backlog.md`. Хендофф — `../_shared/handoff-protocol.md`.

## Старт

Approve **не нужен**. Иду делать.

## Шаг 1: Три файла

Прочитай шаблоны:
- `templates/user.md` — для конечных пользователей
- `templates/support.md` — для AI-агентов поддержки (как устроено внутри)
- `templates/analytics.md` — список tracked events

Создай по шаблонам:
- `DOCS_ROOT/<feature-slug>/user.md` — тон дружелюбный, без жаргона
- `DOCS_ROOT/<feature-slug>/support.md` — тон технический, плотный, ссылки `file:line`
- `DOCS_ROOT/<feature-slug>/analytics.md` — из tech-spec секция Tracked events

## Шаг 2: Связь с бэклогом

В `DOCS_ROOT/<epic-slug>/stories.md` рядом с Task допиши ссылку на `DOCS_ROOT/<feature-slug>/`. Статус Task оставь `done` (уже выставлен в `task-test`). Закоммить `stories.md`.

## Шаг 3: Хендофф

Применяй `../_shared/handoff-protocol.md`. `task-docs` запускается только для Task, которая **не последняя** в Story (последняя идёт сразу в `task-ship` через Story gate). Поэтому хендофф — на следующую Task:
> Готово: документация Task `<task-slug>` — `DOCS_ROOT/<feature-slug>/`
> Следующий шаг: task-build (следующая Task Story)
> Промпт: `Запусти task-build для эпика "<epic-slug>" — следующая Task Story "<story-slug>". Бэклог — DOCS_ROOT/<epic-slug>/stories.md, worktree Story уже существует.`

## Принципы

- user.md и support.md — **разные** документы для разных аудиторий.
- Не дублируй PRD в support.md — ставь ссылку.
- analytics.md обязательно — это вход для `analytics-insights`.
- Если пользователь хочет копию документации в трекере — это отдельный скилл `tracker-sync` по запросу.
