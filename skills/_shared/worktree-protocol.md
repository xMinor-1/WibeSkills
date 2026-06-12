# Worktree-протокол

Правило для скиллов, которые пишут или меняют код (`task-build`, фиксы `task-cross-review`, авто-fix `task-test`, мерж `task-ship`). Цель — параллельные Stories / агенты **никогда** не топчут друг друга в одной рабочей копии и ветке.

## Базовое правило

**1 Story = 1 worktree = 1 feature-ветка.** Worktree **переживает границы чатов**: каждый скилл = свой чат (см. [chat-lifecycle.md](chat-lifecycle.md)), но все скиллы одной Story работают в одном и том же worktree на диске.

| Что | Имя |
|---|---|
| Ветка | `feature/<epic-slug>/<story-slug>` |
| Worktree | `../<project>-<story-slug>` (рядом с основной рабочей копией) |
| Чаты | много (по одному на скилл), все `cd` в один worktree Story |

**Никогда:**
- Не пиши код в `MAIN_BRANCH` напрямую.
- Не используй одну feature-ветку из двух **параллельных** Story одновременно.
- Не оставляй commits в чужой Story-ветке (даже «попутно поправил»).

## Главный агент (task-build / фиксы внутри task-test, task-cross-review)

**Старт Story** — первая Task в чате `task-build`, worktree ещё нет:

```bash
git fetch origin <MAIN_BRANCH>
git worktree add ../<project>-<story-slug> -b feature/<epic-slug>/<story-slug> origin/<MAIN_BRANCH>
cd ../<project>-<story-slug>
```

**Любой следующий скилл Story** (`task-cross-review`, `task-test`, `task-docs`, `task-ship`, или `task-build` следующей Task) запускается в **новом чате**, но worktree уже существует на диске — `git worktree list`, `cd` в него, `git status`. Не создавай дубль. Состояние Story между чатами — в самой ветке + в `stories.md`.

## Subagents через Agent tool

| Тип subagent'а | `isolation` | Почему |
|---|---|---|
| Пишет код / запускает Bash | **`worktree`** | Получит свой свежий worktree, не сломает Story-worktree |
| Read-only анализ (`Explore`, `code-explorer`, `code-reviewer` без правок) | не нужен | Читает, не пишет |
| Параллельные ревьюеры в `task-cross-review` | не нужен (read-only) | Смотрят diff, не правят |

**Если subagent должен внести правки в Story-ветку:**
1. **Предпочтительно:** subagent правит в своём изолированном worktree, возвращает diff/patch, главный агент применяет в Story-worktree сам.
2. **Альтернатива:** главный агент правит сам на основе рекомендаций read-only subagent'а.

Не отдавай subagent'у запись напрямую в Story-worktree — это и есть «пересечение».

## Cleanup после ship

```bash
cd <основная рабочая копия>
git worktree remove ../<project>-<story-slug>
git branch -d feature/<epic-slug>/<story-slug>
git push origin --delete feature/<epic-slug>/<story-slug>
```

Если `git worktree remove` ругается на uncommitted changes — **разбирайся**, не делай `--force` вслепую.

## Анти-паттерны

- ❌ Два чата редактируют один файл в одной ветке без знания друг о друге.
- ❌ Subagent с Write/Bash без `isolation: "worktree"`.
- ❌ Главный агент чекаутится на Story-ветку в основной рабочей копии, пока другая Story работает там же.
- ❌ Subagent пишет в Story-worktree параллельно с главным агентом.

## Отладка

```bash
git worktree list      # все активные worktree'и
git branch -a          # ветки
git worktree prune     # убрать запись об удалённом worktree
```
