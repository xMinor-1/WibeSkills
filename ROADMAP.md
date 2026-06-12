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

- [ ] Пересборка `market-research` на каркасе Замесина: intake gate с адаптивными вопросами, user-claims ledger, **selection screen** (4 измерения + existential-гейт — вместо Four Forces), pivot-ветка (альтернативные Big-Job рынки под активы), Quick/Deep режимы
- [ ] Сохранить наше: AJTBD-гипотеза 9 полей, триггер + факт траты в прошлом как ось спроса, вердикт ✅/⚠️/❌ с честным «не стоит», хендофф в CVP/`epic-prd`, `COMM_LANGUAGE`/`COMM_STYLE`, артефакт в `DOCS_ROOT/<epic-slug>/market-research.md`

## Этап 3 — обогащение существующих скиллов

- [ ] `epic-prd`: **challenge-the-build gate** до интервью (5 Whys по бизнес-цели, subtraction-first, локальный vs глобальный оптимум, 2–4 альтернативы постройке) · edge-cases от разрывов Critical Chain (~90% покрытия) · ladder «фича → Core Job → Big Job → механика» для каждого требования · placement Aha Moment (максимально влево) · вход — `value-proposition.md` из CVP
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
