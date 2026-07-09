# Рефакторинг скиллов 09.07.2026 — что сделано и как продолжать

Резюме пересборки (коммит `7cbe867`). Назначение: если что-то сломается —
не откатываться, а чинить вперёд по этой карте.

## Что было и что стало

| Было | Стало |
|---|---|
| Один процесс на все задачи | 4 трека: `fast` / `prd` / `indie` / `enterprise` (`_shared/tracks.md`) |
| Вход — «вспомни нужный скилл» | Роутер `kickoff`: где живёт задача → MODE+TRACK → `epic-meta.md` → первый скилл |
| Delivery = ручные хендоффы «открой новый чат» | `delivery-run`: task-цепочка сабагентами через Workflow (контракт `_shared/delivery-workflow.md`) |
| Один PRD-шаблон (инженерный) | PRD-machine (для кода) + PRD-human (формат X5 1→12) в `epic-prd/templates/` |
| Карта pipeline без треков | Единая карта c колонкой TRACK — `_shared/handoff-protocol.md` (ЕДИНСТВЕННОЕ место маршрутизации) |

## Ключевые решения (не нарушать при доработках)

1. **1 ран Workflow = 1 безгейтовый сегмент.** Workflow не умеет ждать человека —
   скрипт всегда завершается на границе гейта; следующий сегмент = новый скрипт
   из актуального stories.md. Не пытаться «останавливать» ран изнутри.
2. **Single-writer:** статусы stories.md пишет только оркестратор delivery-run.
   Сабагентам запись запрещена (иначе merge-конфликты параллельных Task).
3. **Git-контракт:** build-сабагент коммитит в task-ветке своего worktree,
   возвращает branch+sha; оркестратор мержит в Story-ветку до review/test.
   Проверено спайком: 2 параллельных агента + merge --no-ff — ок.
4. **Сабагенты не видят библиотеку скиллов** — промпт велит прочитать SKILL.md
   с диска и работать по секции «Workflow-режим» (skip-список: без Story-worktree,
   без хендоффов, без ожидания гейтов, без записи статусов, approve → `needs_approve`).
5. **Discovery остался ручным** (человек в цикле) — автоматизирован только delivery.
6. **TRACK живёт в артефакте** (`epic-meta.md` / frontmatter PRD), не в памяти чата.
   Порядок разрешения — `tracks.md` § Персистентность.
7. **kickoff не вклинивается** в хендофф-промпты и явные вызовы скиллов — правило
   обхода в его SKILL.md.
8. **Стиль** — единый источник `_shared/communication-style.md`; human-артефакты
   (X5, enterprise) = zero-slop; легенда 🔲/✅ в PRD X5 — допустимый формат.

## Что где (изменённые зоны)

- Новое: `skills/{kickoff,mvp,delivery-run}/`, `_shared/{tracks,delivery-workflow}.md`,
  `_shared/templates/` (root/project/folder-доки), `epic-prd/templates/PRD-{machine,human}.md`
- Правки: task-{build,cross-review,test,docs} (секции «Workflow-режим»),
  agile-coach (track-условный decompose, хендофф в delivery-run), epic-prd
  (профили, Шаг 0 challenge-the-build, Шаг 2.5 enterprise-блок), market-research/CVP
  (`RESEARCH_RIGOR: lite` = 1 раунд гейтов), все ключевые `_shared/*`
- Вне репо: `Work/CLAUDE.md` (индекс проектов), CLAUDE.md во всех 10 проектах,
  summary в папках, реорг `x5transport/Продукты` (3 бакета + `_общее/`,
  перенесены grid-redesign и Исследование активации)

## Известные хвосты (продолжать отсюда, не откатываться)

- [ ] `delivery-run` не гонялся на реальном эпике — первый прогон: маленькая
  todo-Story LiftBook (`docs/telegram-mini-app/stories.md`, Stories 3–6), без ship.
- [ ] ROADMAP Этап 3 остаток: Aha Moment placement; canon-first конвертация вшитого
  «Ядра AJTBD» в epic-prd (сознательно отложено — не ломать рабочий скилл без прогона).
- [ ] SessionStart-хук для kickoff-правила не ставился (пока только строка в CLAUDE.md).
- [ ] Push в GitHub не делался — по команде владельца.
- [ ] kickoff/mvp не прогонялись end-to-end — проверить на первой реальной задаче.

## Если сломалось

- Ручной фоллбэк delivery всегда работает: task-* скиллы по одному через хендоффы
  (карта — `handoff-protocol.md` § Ручной фоллбэк). `delivery-run` — ускоритель, не замена.
- История: до пересборки — коммит `a0b4f09`, пересборка — `7cbe867`. Диф между ними =
  полный объём изменений.
- Контекст решений: план-файл `~/.claude/plans/lovely-nibbling-hinton.md` + memory
  `wibeskills-two-axes-model`.
