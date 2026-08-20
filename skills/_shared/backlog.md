# Файловый бэклог — формат и логика

Ядро pipeline **не зависит от трекера**. Бэклог эпика живёт в файле `DOCS_ROOT/<epic-slug>/stories.md`. Ведёт его `agile-coach`; скиллы `task-*` читают и обновляют статусы прямо в нём. Зеркало в Notion/Linear/Jira — опционально, через скилл `tracker-sync`.

## Иерархия

- **Epic** — фича целиком (2–4 недели). Один эпик = одна папка `DOCS_ROOT/<epic-slug>/`.
- **Story** — vertical slice, end-to-end testable инкремент (1–3 дня). 3–7 на эпик. Маленький эпик может иметь 1 Story.
- **Task** — атомарная единица работы для одного агента в одной feature-ветке (1–8 часов). Один слой архитектуры.

## stories.md — структура

```markdown
# Бэклог эпика: <название> (<epic-slug>)
Iteration: <MVP / v2 / ...>   Area: <зона>   Priority: <P0..P3>

## Story 1 — «<кто> <делает> <что>»  [status: todo]
Story-ветка: feature/<epic-slug>/<story-slug>
### AC для Story
- когда <условие>, то <ожидание>
### Manual gate
<что открыть на prod-build и проверить>
### Tasks
- [ ] A1 schema-users — `todo` — group A (parallel) — touches: db/schema — deps: —
- [ ] A2 domain-otp — `todo` — group A (parallel) — touches: src/auth/domain — deps: —
- [ ] B1 ui-phone-step — `todo` — group B — touches: src/auth/ui — deps: A1,A2

## Story 2 — «...»  [status: todo]
...
```

**Статусы Task / Story:** `todo` → `in-progress` → `review` → `testing` → `done` (+ `blocked`).
Скилл, меняющий статус, правит его прямо в `stories.md` и коммитит в Story-ветку (или main для agile-coach).
**Исключение — Workflow-режим (`delivery-run`):** статусы пишет только оркестратор между стадиями; сабагентам запись в `stories.md` запрещена (single-writer, см. [delivery-workflow.md](delivery-workflow.md)).

## Декомпозиция (двухуровневая, делает `agile-coach decompose`)

**Эпик → Stories (3–7):**
- Каждая Story = реальный user-flow, описывается одним предложением «<кто> <делает> <что>». Не описывается — режь дальше.
- Stories независимы по UI: Story A не требует Story B, чтобы её UI открывался.
- Story = одна Story-ветка, закрывается одним manual-ревью на prod-build.

**Story → Tasks (по слоям):**
- Режь по слоям/доменам: «schema users», «use-case sendOtp», «UI PhoneStep». Не «backend всё».
- Параллельные: две Tasks не трогают один файл → одна parallel group.
- Последовательность — только реальный output→input (migration → use-case, port → infra, use-case → UI).
- Тесты — не отдельная Task (`task-test` — шаг pipeline на каждой Task).
- XL Task — стоп, режь на 2–3 поменьше.

## Orchestration-граф

У каждой Task в `stories.md`: `group` (parallel group), `touches` (файлы/папки), `deps` (slug'и Task, от которых зависит). `task-build` при выборе «следующей Task» уважает граф: Task с незакрытыми deps недоступна; несколько Task одной group с чистыми deps можно брать параллельно (в разных чатах/worktree).

## Ссылка на task-packet (опционально)

Если код пишет не тот, кто проектировал (`EXECUTOR` ≠ `inherit` в project-config), у Task есть
самодостаточный пакет `DOCS_ROOT/<epic-slug>/tasks/<task-slug>.md` — протокол
[executor-protocol.md](executor-protocol.md). Строка Task остаётся индексом, в конец добавляется
ссылка — формат обратно совместим, старые бэклоги без пакетов читаются как раньше:

```markdown
- [ ] A1 schema-users — `todo` — group A (parallel) — touches: db/schema — deps: — — [пакет](./tasks/A1-schema-users.md)
```

## Auto-rollup статуса (делает `agile-coach`)

При изменении статуса Task — пересчитай родительскую Story, потом — пометку эпика в блоке «📚 Артефакты». Алгоритм (одинаков для Story по Tasks и для эпика по Stories):

```
все подзадачи done                                  → done
≥1 [in-progress, review, testing]                   → in-progress
≥1 blocked AND ни одной активной                    → blocked
все todo                                            → todo (не трогай)
```

**Никогда не понижай Story/эпик автоматически** (done → in-progress при переоткрытии) — спроси.

## WIP

Лимит на число Task в статусе `in-progress` — `WIP_LIMIT` из `project-config.md` (дефолт 7), считается по всем `stories.md` всех эпиков.

## Опциональное зеркало в трекер

Если пользователь хочет видеть бэклог в Notion/Linear/Jira — это делает скилл `tracker-sync` по запросу: читает `stories.md` + артефакты эпика, создаёт/обновляет страницы в трекере. Ядро pipeline в трекер не пишет и из него не читает. Конфиг трекера (`TRACKER_*`) — в `project-config.md`, раздел «Опциональные модули».
