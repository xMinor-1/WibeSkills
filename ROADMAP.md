# ROADMAP — слияние скиллов Замесина в наш workflow

**Принципы слияния** (зафиксированы 2026-06-12):

- **Методология — за Замесиным** (канон в рантайме — источник правды), **workflow — наш** (Epic → Story → Task, хендоффы «один чат = один скилл», project-config, артефакты в `DOCS_ROOT/`, русский язык).
- **Canon-first + приватный слой.** Скиллы читают публичный канон из `canon/Next-Move-Theory-Canon/`. Конспекты платного курса (82 механики `mechanics-navigator.md`, флаги F1–F33 `theory-canon.md`) в репо НЕ попадают — лежат локально вне репо; скиллы подхватывают их через опциональный `COURSE_NOTES_ROOT` из project-config (graceful degradation: нет слоя — работаем от канона).
- **Наш формат скиллов** — компактный (~200–250 строк): инварианты методологии не дублируем в тексте скилла, а читаем из канона в рантайме.
- **Инженерные паттерны Замесина** имплантируем по ходу портирования: user-claims ledger (данные/наблюдение/догадка), adversarial critic gates (max 2 раунда → эскалация), step ledger (пропуск стадии объявляется), режимы Quick/Deep.

---

## Этап 0 — каркас ✅

- [x] Репозиторий, `git init`, ветка `main`
- [x] Библиотека переехала: `Work/.claude/skills` → `skills/` + симлинк обратно
- [x] Канон подключён как submodule `canon/`
- [x] README, ROADMAP, LICENSE, .gitignore

## Этап 1 — привязка канона + новые скиллы

- [x] `_shared/project-config.md`: поля `NMT_CANON_ROOT` (дефолт — `canon/Next-Move-Theory-Canon/` относительно репо) и опциональный `COURSE_NOTES_ROOT` (приватный слой курса, вне репо)
- [x] `_shared/nmt-canon-routing.md` — таблица «задача → файл канона» (адаптация роутинга из `canon/CLAUDE.md`)
- [x] **Портировать `craft-value-proposition`** — новый шаг 0.5 пайплайна (`market-research` → CVP → `epic-prd`): извлечение доминирующих критериев успеха → граф работ + Critical Chain → генерация 12–20 гипотез ценности по каталогу механик → фильтр (реализуемость / юнит-экономика / конкурентность) → RICE → primary + supplementary → RAT-карточки → спека для PRD. Русский, наш формат, артефакт `DOCS_ROOT/<epic>/value-proposition.md`, хендофф в `epic-prd`. Механики: канон (~26) + приватный слой (82) если доступен. *(2026-06-12: SKILL.md + шаблон + карта пайплайна + хендофф из market-research)*
- [x] **Портировать `ask-nmt`** — разговорный советник по методологии: lazy-роутинг по канону, 5 режимов (объясни / диагностируй / прожми / примени / научи), хендоффы в наши скиллы-продюсеры. Русский, без файлов-артефактов по умолчанию. *(2026-06-12 — Этап 1 закрыт)*

## Этап 2 — слияние market-research

- [x] Пересборка `market-research` на каркасе Замесина: intake gate с адаптивными вопросами, user-claims ledger, **selection screen** (4 измерения + existential-гейт — вместо Four Forces), pivot-ветка (альтернативные Big-Job рынки под активы), Quick/Deep режимы. Вшитая методология (~95 строк «Ядро AJTBD» + «Навигатор механик») заменена canon-first чтением в рантайме; добавлены гейты-самокритика (max 2 раунда) и step ledger; вердикт ⚠️ NARROW-семантика = «✅ с явным сужением до суб-сегмента»; ❌ + переносимые активы → предложение перезапуска на pivot-рынке. Шаблон артефакта пересобран (выжимка без терминов → гипотеза 9 полей → снимок рынка → карта сегментов → отстройка → стратегия+pivot → RAT → вердикт → леджер). *(2026-06-12 — Этап 2 закрыт)*
- [x] Сохранить наше: AJTBD-гипотеза 9 полей, триггер + факт траты в прошлом как ось спроса (обязательный блок каждого сегмента), вердикт ✅/⚠️/❌ с честным «не стоит», хендофф в CVP/`epic-prd`, `COMM_LANGUAGE`/`COMM_STYLE`, артефакт в `DOCS_ROOT/<epic-slug>/market-research.md`

## Этап 2.5 — модель «2 оси × entry-router» + авто-delivery ✅ (2026-07-09)

- [x] Ось **TRACK** (`fast`/`prd`/`indie`/`enterprise`) — `_shared/tracks.md`, поле `TRACK_DEFAULT` в project-config, персистентность в `epic-meta.md`
- [x] Роутер **`kickoff`** (вход в любую задачу) + скилл **`mvp`** (fast-трек: бриф → код/прототип за один заход)
- [x] **`delivery-run`** — авто-оркестрация task-цепочки через Workflow-сабагентов: контракт `_shared/delivery-workflow.md` (1 ран = 1 безгейтовый сегмент, single-writer stories.md, git-контракт branch+sha → Story-ветка, стоп-статусы needs_decision/needs_approve), секции «Workflow-режим» в task-{build,cross-review,test,docs}
- [x] Единая карта маршрутизации в `handoff-protocol.md` (колонка TRACK); правки chat-lifecycle / backlog / worktree / approve-protocol
- [x] **Два шаблона PRD** в `epic-prd`: PRD-machine (+lite-tech-spec для трека prd) и PRD-human (из эталонов X5: СРМ/Процессы, ЦП/CDP) + 3 интервью-профиля + challenge-the-build gate + ladder-проверка
- [x] `RESEARCH_RIGOR: lite` в market-research / CVP (1 раунд гейтов для трека indie)
- [x] communication-style: краткость, анти-слоп/эмодзи-правила, zero-slop для human-артефактов

## Этап 3 — обогащение существующих скиллов (остаток)

- [x] `epic-prd`: challenge-the-build gate · edge-cases от разрывов Critical Chain · ladder «фича → Core Job → Big Job → механика» *(2026-07-09, в рамках Этапа 2.5)*
- [ ] `epic-prd`: placement Aha Moment (максимально влево) · вход — `value-proposition.md` из CVP (только для треков, где CVP был — не prd/fast)
- [ ] `epic-prd`: конвертировать вшитые ~90 строк «Ядро AJTBD» + «Навигатор механик» в canon-first чтение (по образцу market-research) — отложено, чтобы не ломать работающий скилл без прогона
- [ ] `marketing-gtm` + `marketing-copywriting`: 7 формул креативов на языке работ, 5 компонент Consideration Activators, 10-блочная структура лендинга как диагностика конверсии, правило «фичи — доказательство, не сообщение»
- [ ] `marketing-promotion` / `marketing-smm`: точечная синхронизация терминов

## Этап 4 — терминологическая ревизия

- [ ] Все скиллы: «активирующее знание (3 части)» → **Consideration Activators (5 компонент)**, ввести Aha Moment как операционное понятие, «гедонистическая адаптация» → Red Queen, убрать остатки Four Forces
- [ ] Ссылки на `notes/AJTBD/...` → canon-first + `COURSE_NOTES_ROOT` (graceful degradation)
- [ ] `ajtbd-check` (user-level, `~/.claude/skills`): канон — первичный источник судейства, theory-canon.md курса — приватный второй слой

## Этап 5 — публикация

- [ ] README двуязычный (ru основной + en-интро), полный legal-текст CC BY-NC-SA 4.0
- [ ] Аудит: никаких приватных путей/данных/курс-материалов в истории
- [ ] Репо → public
- [ ] Удалить `Work/канон/` (заменён submodule)

---

## Процесс репликации обновлений канона

Раз в ~месяц (или по анонсу в его рассылке): `git submodule update --remote canon` → diff по `canon/Next-Move-Theory-Canon/` → если менялись ключевые файлы (`*-key-theses.md`, `value-creation*.md`, `the-algorithm.md`) — прогнать `pipeline-retro` на предмет расхождений скиллов с обновлённым каноном.
