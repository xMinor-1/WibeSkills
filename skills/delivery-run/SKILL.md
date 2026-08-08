---
name: delivery-run
description: Авто-оркестратор delivery — прогоняет Tasks из stories.md через сабагентов (build → cross-review → test → docs) инструментом Workflow, сегментами между человеческими гейтами, с докладом о прогрессе. Активируется на «delivery-run», «погнали кодить», «запусти delivery», «прогони стори автоматически». Только MODE=app. Ручной фоллбэк — task-* скиллы по одному.
recommended_model: opus
---

# Delivery-run — авто-прогон delivery-цепочки

Оркестрирует `task-build → task-cross-review → task-test → task-docs` сабагентами
через инструмент Workflow. Контракт (роли, git, skip-список, стоп-статусы) —
**[delivery-workflow.md](../_shared/delivery-workflow.md)**, здесь — порядок работы скилла.

## Режим (app-only)

Прочитай `MODE` ([mode.md](../_shared/mode.md)). Если `work` — стоп: здесь финальный код
пишет живой программист; предложи `dev-handoff` и жди решения.

## Старт

1. Прочитай `stories.md` эпика ([backlog.md](../_shared/backlog.md)) и `epic-meta.md` (TRACK).
2. Проверь пререквизиты по TRACK: PRD (+tech-spec, если трек их предполагает; для TRACK=prd
   достаточно PRD-machine с lite-tech-spec-секцией). Нет — стоп, скажи чего не хватает.
3. Определи **сегмент**: todo-Tasks до ближайшего человеческого гейта (Story manual-gate / ship).
   Покажи пользователю план сегмента одной таблицей (Tasks, порядок, что параллелится) — и запускай
   (approve на запуск не нужен; approve-операции внутри всё равно вернутся как `needs_approve`).

## Прогон сегмента

1. Сгенерируй Workflow-скрипт: orchestration-граф из stories.md — **константой в скрипте**
   (у скрипта нет FS-доступа). Стадии и промпты сабагентов — по контракту delivery-workflow.md
   (цель = AC + touches + deps + пути к артефактам; указание читать SKILL.md стадии,
   секция «Workflow-режим»; shape structured output).
   `EXECUTOR` ≠ `inherit` → стадия build разворачивается в **package → dispatch → verify**
   (delivery-workflow.md, раздел «Стадия dispatch»); `external:<команда>` исполняется через Bash
   оркестратором, а не сабагентом.
2. Запусти ран. Между стадиями: сливай task-ветки в Story-ветку (merge --no-ff),
   обновляй статусы в stories.md (single-writer — только ты), дописывай строку по Task
   в `DOCS_ROOT/<epic-slug>/delivery-log.jsonl` (метрики — executor-protocol.md).
3. Ран завершился — разбери результат:
   - все стадии `ok` → сегмент готов;
   - `needs_decision` / `needs_approve` / `blocked` → доложи на бизнес-языке, жди решения;
   - ран упал технически → продолжи через `resumeFromRunId`.

## Гейт и следующий сегмент

Сводка по Story на бизнес-языке ([communication-style.md](../_shared/communication-style.md)):
что сделано, что проверить, риски. Story manual-gate — человек смотрит на prod-build и говорит ✅/❌.

- ✅ и Story последняя перед ship → хендофф в `task-ship` (ship остаётся отдельным approved-шагом).
- ✅ и есть следующие Stories → сгенерируй скрипт следующего сегмента из **актуального** stories.md.
- ❌ → возврат: Task в in-progress, замечания в stories.md, новый сегмент с фиксом.

## Принципы

- Один ран = один безгейтовый сегмент. Человеческие гейты не автоматизируются никогда.
- Статусы и git — только через оркестратора; сабагенты возвращают данные, не пишут состояние.
- Доклад пользователю — итогами сегментов, не потоком технических логов.
- Что-то идёт не так два раза подряд — остановись и предложи ручной фоллбэк (task-* по одному).
