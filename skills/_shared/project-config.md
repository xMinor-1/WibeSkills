# Project Config — анкета проекта (ШАБЛОН)

> Это пустой шаблон из общей библиотеки скиллов. **Не заполняй его здесь.**
> Скопируй в проект (`<project>/.claude/project-config.md`) и заполни там.
> Скилл-движок смотрит вверх по дереву: общие скиллы берутся из `Work/.claude/skills/`,
> а специфика проекта — из локального `<project>/.claude/`.
>
> Раздел **ЯДРО** обязателен. **ОПЦИОНАЛЬНЫЕ МОДУЛИ** заполняй только если подключаешь
> соответствующий скилл. Пока поле пустое (`<...>`), скилл, которому оно нужно,
> остановится и спросит, а не угадает.

---

# ЯДРО

## 0. Режим работы

- **MODE** — <app | work — см. `_shared/mode.md`. `app` = я довожу код до прода (полный pipeline). `work` = финальный код пишет живой программист, моя цель — проработка + PRD + прототип + handoff. Пусто = `app`.>
- **TRACK_DEFAULT** — <fast | prd | indie | enterprise — см. `_shared/tracks.md`. Дефолтный трек для kickoff, когда задача не говорит иного. Фактический TRACK эпика живёт в `DOCS_ROOT/<epic-slug>/epic-meta.md`. Пусто = kickoff спросит.>

## 1. Продукт

- **PROJECT** — <название проекта>
- **ONE_LINER** — <одно предложение: что это, для кого, сегмент>
- **VISION_DOC** — <путь к vision-доку | нет>
- **PRD_DOC** — <путь к PRD | нет>

## 2. Аудитория и коммуникация

- **USER_PERSONA** — <кто владелец продукта / основной пользователь, уровень тех-погружения>
- **COMM_LANGUAGE** — <язык общения, напр. русский>
- **COMM_STYLE** — <бизнес-язык | технический — см. communication-style.md>

## 3. Стек и репозиторий

- **CODE_ROOT** — <корень кода | не используется>
- **STACK** — <язык / фреймворки>
- **DB** — <база данных>
- **ARCH_PATTERN** — <напр. Clean Architecture | MVC | ...>
- **TEST_RUNNER** — <команда юнит-тестов>
- **E2E** — <команда e2e | нет>
- **LOCAL_CHECK** — <линт / typecheck / build перед коммитом>
- **VERIFY_CMD** — <точечная проверка одной Task по её пакету: тесты Task + typecheck + diff в границах `Разрешено править`. Принимает task-slug, отдаёт exit-code + JSON. Пусто = проверяем полным `LOCAL_CHECK` (медленно, без проверки границ). См. `_shared/executor-protocol.md`.>
- **EXECUTOR** — <кто пишет код на стадии fill: `inherit` (та же модель, что оркестратор — дефолт) | `sonnet` / `haiku` | `external:<команда>` (внешний CLI, получает путь к пакету аргументом). Не-`inherit` требует task-packet на каждую Task.>
- **EXECUTOR_EFFORT** — <стартовая ступень лестницы: `medium` (дефолт) | `low` | `high`. Ретрай после красного `verify` поднимает на ступень автоматически; см. `_shared/executor-protocol.md` §«Модель и effort».>
- **REVIEWER** — <модель модельных линз cross-review. Обязана быть **выше** `EXECUTOR`. Пусто = топ-модель сессии, effort `high`.>
- **REPO_URL** — <url репозитория>
- **MAIN_BRANCH** — <main | master>

## 4. Деплой

- **DEPLOY_METHOD** — <как деплоится | не используется>
- **DEPLOY_STEPS** — <шаги деплоя>
- **HEALTHCHECK** — <как проверить, что живо>
- **PROD_URL** — <прод-адрес>
- **DEPLOY_SECRETS** — <где лежат секреты / что нужно>

## 5. Бэклог и артефакты

- **DOCS_ROOT** — <папка артефактов, напр. docs/>
- **WIP_LIMIT** — <макс. число Task в статусе `in-progress` одновременно, по всем эпикам. Пусто = 7. Потребитель — `agile-coach`, см. `_shared/backlog.md` §WIP.>

Бэклог эпика — файл `<DOCS_ROOT>/<epic-slug>/stories.md`.
Пакеты Task (если `EXECUTOR` ≠ `inherit`) — `<DOCS_ROOT>/<epic-slug>/tasks/<task-slug>.md`.
Лог прогонов delivery — `<DOCS_ROOT>/<epic-slug>/delivery-log.jsonl`.

---

# ОПЦИОНАЛЬНЫЕ МОДУЛИ

## A. Аналитика (`analytics-insights`, `market-research`)

- **ANALYTICS_PROVIDER** — <провайдер аналитики | нет>
- **ANALYTICS_ACCESS** — <как получить доступ к данным>
- **TRACK_HELPER** — <функция/способ трекинга событий в коде>
- **MARKET_RESEARCH_ACCESS** — <какие источники доступны: web / Wordstat / опросы / ...>

## B. Юридический режим (`epic-legal-review`)

- **LEGAL_REGIME** — <РФ (152/149-ФЗ) | GDPR | CCPA | generic | не используется>
- **LEGAL_DOCS** — <где лежат оферта / политика / согласия>
- **LEGAL_PRESET** — <назначается при epic-legal-review>
- **LEGAL_NOTES** — <нюансы юр-поверхности продукта>

## C. Трекер задач (`tracker-sync`)

- **TRACKER** — <Notion | Linear | Jira | GitHub Issues | не используется>
- **TRACKER_ACCESS** — <токены / id доски / как подключиться>

## D. Маркетинг (`marketing-*`)

- **BRAND_VOICE** — <тон бренда: какой можно, какой нельзя>
- **CHANNELS** — <каналы продвижения>
- **TARGET_SEGMENTS** — <ICP / сегменты аудитории>
- **MARKETING_DOCS** — <папка маркетинг-артефактов>

## F. UX-паттерны (`ux-patterns`, `epic-preview`, `mvp`)

- **PLATFORM_FOCUS** — <mobile-web | iOS | Android | desktop-web | mix — основная платформа для подбора паттернов>
- **UX_FOUNDATION_DOC** — <путь к базе паттернов | пусто = `DOCS_ROOT/ux-foundation/pattern-library.md` | свой док, напр. STYLE-GUIDE дизайн-системы>

## E. Методология NMT / AJTBD (`market-research`, `craft-value-proposition`, `ask-nmt`, `epic-prd`, `marketing-*`)

- **NMT_CANON_ROOT** — <путь к канону | пусто = дефолт `<библиотека скиллов>/../canon/Next-Move-Theory-Canon/` (submodule в WibeSkills)>
- **COURSE_NOTES_ROOT** — <путь к приватному слою конспектов курса (mechanics-navigator.md — 82 механики, theory-canon.md — флаги F1–F33) | нет>

Правила использования:
1. **Canon-first.** Методологические определения скиллы берут из канона в рантайме (роутинг — `_shared/nmt-canon-routing.md`), а не из выжимок в тексте скилла и не из generic JTBD в трейне модели.
2. **Приватный слой опционален.** Если `COURSE_NOTES_ROOT` задан и файлы существуют — каталог механик расширяется с ~26 (публичный канон) до 82 (курс). Если нет — скилл работает только от канона и не падает.
3. Приватный слой — конспект платного курса, **в публичные репозитории не попадает**.
