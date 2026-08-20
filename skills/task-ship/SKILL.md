---
name: task-ship
description: Финальный approval пользователя, мерж feature-ветки, деплой, проверка health, обновление бэклога → done. Активируется на «task-ship», «задеплой», «выкати в прод», «отправь в прод». Шаг 10 продуктового workflow.
recommended_model: sonnet
---

# Task Ship

Финальный гейт + деплой **Story** (или эпика, если это была последняя Story). **Только после явного approve** код уходит в `MAIN_BRANCH` и в прод.

Контекст — `../_shared/project-config.md` + проектный `CLAUDE.md`. Approve — `../_shared/approve-protocol.md`. Бэклог — `../_shared/backlog.md`. Хендофф — `../_shared/handoff-protocol.md`. Worktree — `../_shared/worktree-protocol.md`. Деплой — поля `DEPLOY_*` в project-config.

## Режим (app-only)

Прочитай `MODE` — `../_shared/mode.md`. Если `MODE: work` — **стоп, не разворачивай pipeline**: в work-режиме финальный код пишет живой программист, а боевой деплой — ручной ⏸ гейт под контролем владельца (см. инфра-блок project-config). Объясни это одной строкой и предложи `dev-handoff`. Жди решения. Если `app` или MODE не задан — пропусти этот блок, работай как обычно.

## Старт

Approve **нужен**. Короткий план **на бизнес-языке**:
> «Готов выкатить Story `<slug>` в прод. Что меняется для пользователя: <2 строки>. Риски: <если есть, в терминах последствий>. Подтверди ✅ или скажи стоп.»

Это ⏸ реальный гейт. Worktree Story уже на диске — `cd` в него.

## Шаг 1: Epic regression перед деплоем (на prod-build)

Прогони полный epic-suite на prod-build (ловит «локально работало иначе»). Красный — **стоп, не деплой**. Хендофф назад в `task-build` для починки.

Эпик трогает Stories, которые могли быть затронуты соседними эпиками (auth трогает всё) — добавь их epic-suite в прогон.

## Шаг 2: Мерж в MAIN_BRANCH

```bash
git checkout <MAIN_BRANCH> && git pull origin <MAIN_BRANCH>
git merge --no-ff feature/<epic-slug>/<story-slug>
```

Конфликты — **разрешай**, не делай `git reset`.

```bash
git push origin <MAIN_BRANCH>
```

## Шаг 3: Деплой

Следуй `DEPLOY_METHOD` / `DEPLOY_STEPS` из project-config. Креды — из `DEPLOY_SECRETS`, **не печатай в открытых логах**.

Типовые варианты:
- **VPS (rsync + process manager):** build → rsync → install --production → reload процесса
- **Vercel / платформа:** push в `MAIN_BRANCH` триггерит деплой, дождись завершения
- **Docker / CI:** дождись green pipeline

## Шаг 4: Warmup + health-check ключевых маршрутов

После деплоя — прогрев ключевых страниц фичи (не только health-эндпоинт): без warmup первая загрузка фичи юзером = несколько секунд / иногда ошибка прокси.

Проверь `HEALTHCHECK` + ключевые маршруты Story (из tech-spec): все 200 OK, время ответа после warmup <1s, аналитика грузится, в логах нет error за последние 30 секунд.

Health красный — **rollback** (откат процесса / `git revert` + повторный деплой). Не оставляй прод сломанным.

## Шаг 5: Smoke на проде

Прогони тот же epic-suite против `PROD_URL`. Закрывает «прод реально работает как локально».

Красный → **rollback** (revert + redeploy). Бэклог остаётся не `done`.
Зелёный → продолжаем.

## Шаг 6: Обновление бэклога

В `DOCS_ROOT/<epic-slug>/stories.md`:
- Story → статус `done`, рядом допиши: коммит мержа, дата деплоя, ссылка на e2e-отчёт.
- Все Tasks этой Story → `done` (если ещё не).
- Пересчитай rollup эпика (пометка в блоке «📚 Артефакты эпика» в `PRD.md`).
Закоммить `stories.md` и `PRD.md` в `MAIN_BRANCH`.

## Шаг 7: Очистка

Следуй `../_shared/worktree-protocol.md` §Cleanup: удалить worktree, локальную и удалённую ветку Story.

## Шаг 8: Хендофф

Применяй `../_shared/handoff-protocol.md`.

- **Эпик ещё не закрыт (есть Story не в `done`)** — дефолт: следующий сегмент `delivery-run` (карта pipeline):
  > Готово: Story `<story-slug>` задеплоена — `PROD_URL`, smoke зелёный, бэклог обновлён
  > Следующий шаг: delivery-run (следующий сегмент)
  > Промпт: `Запусти delivery-run для эпика "<epic-slug>" — следующий сегмент. Бэклог — DOCS_ROOT/<epic-slug>/stories.md, начни со следующей todo-Story.`

  Ручной фоллбэк (пользователь ведёт delivery по шагам) — `task-build` следующей Story:
  > Следующий шаг: task-build (следующая Story)
  > Промпт: `Запусти task-build для эпика "<epic-slug>" — следующая Story. Бэклог — DOCS_ROOT/<epic-slug>/stories.md, начни с первой Task следующей todo-Story (новый worktree). agile-coach подскажет приоритет, если непонятно.`

- **Эпик закрыт (все Stories `done`)**:
  > Готово: Story `<story-slug>` задеплоена, эпик `<epic-slug>` закрыт целиком
  > Следующий шаг: нет (pipeline эпика завершён)
  > Промпт: `Эпик "<epic-slug>" закрыт. Через 1–2 недели запусти analytics-insights для гипотез к следующему эпику.`

## Принципы

- **Никогда не пушь в `MAIN_BRANCH` без manual ✅** Story в этой сессии и без зелёного epic-regression.
- **Никогда не используй `--no-verify`** или другие обходы pre-commit hooks.
- При проблемах с деплоем — rollback, не «авось пройдёт».
- Креды — не клади в файлы репо.
- Деплой невозможен (нет credentials, инфраструктура лежит) — стоп, спроси, не пиши заглушки.
- Все сообщения пользователю — на бизнес-языке.
- Юр-документы: если эпик трогает ПДн/платежи и пользователь прогонял `epic-legal-review` с правками в документах — это его зона ответственности проверить перед ✅. Ядро pipeline эту задачу не отслеживает.
