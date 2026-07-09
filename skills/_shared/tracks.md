# TRACK — трек работы (сколько discovery и для кого PRD)

Вторая ось поведения, ортогональная [mode.md](mode.md) (MODE = кто доводит до прода).
TRACK отвечает на вопрос «сколько исследования и какой PRD нужен этой задаче».
Выбирается **на старте задачи** роутером `kickoff`, не прибит к проекту.

Единая карта «какие скиллы когда» — таблица pipeline в [handoff-protocol.md](handoff-protocol.md).
Здесь — только параметры треков.

## Четыре трека

| | **fast** | **prd** | **indie** | **enterprise** |
|---|---|---|---|---|
| Суть | MVP за один заход | требования уже продуманы → сразу в дело | самостоятельный продукт по NMT, без душных перепроверок | X5 / продукт для людей, глубокая проработка |
| Discovery | нет | нет (`RESEARCH_RIGOR: none`) | market-research + CVP, lite (`RESEARCH_RIGOR: lite`) | полный (`RESEARCH_RIGOR: full`) |
| PRD | нет — только `brief.md` | PRD-machine + lite-tech-spec-секция | PRD-machine | PRD-human (+ PRD-machine, если уходит в разработку) |
| `PRD_AUDIENCE` | — | `machine` | `machine` | `human` |
| Дальше | по MODE: код+деплой или прототип | decompose → `delivery-run` | preview → tech-spec → … → `delivery-run` | по MODE (X5 → `dev-handoff`) |
| Скилл-вход | `mvp` | `epic-prd` | `market-research` / `epic-prd` | `market-research` / `epic-prd` |

## Параметры, которые задаёт трек

- **RESEARCH_RIGOR** — `none | lite | full`. `lite`: adversarial-гейты самокритики max **1 раунд** (вместо 2), верификация только load-bearing утверждений, данные из открытых источников без глубокой перепроверки. `full`: как написано в скилле (2 раунда, полная верификация).
- **PRD_AUDIENCE** — `machine | human`. Выбирает шаблон в `epic-prd` (PRD-machine / PRD-human) и интервью-профиль. `human` = zero-slop ([communication-style.md](communication-style.md), раздел «Артефакты для людей»).

## Где живёт выбор (персистентность)

Выбор TRACK живёт **не в памяти чата**, а в артефакте эпика:
`DOCS_ROOT/<epic-slug>/epic-meta.md` — создаёт kickoff или первый скилл цепочки:

```markdown
# epic-meta
- TRACK: prd
- MODE: app
- PRD_AUDIENCE: machine
- RESEARCH_RIGOR: none
- Выбрано: kickoff, <дата>
```

При создании PRD.md значения дублируются в его frontmatter.

**Порядок разрешения TRACK для любого скилла:**
1. `epic-meta.md` эпика (или frontmatter PRD.md);
2. хендофф-промпт (обязан включать TRACK);
3. дефолтный TRACK из `project-config.md` (поле `TRACK_DEFAULT`);
4. нет нигде → спросить одной строкой.

## Дефолты по типу проекта (подсказка для kickoff)

- Продукт X5 (x5transport) → `enterprise`
- Свой side-проект → `indie`
- «Уже продумал, опишу требование» → `prd`
- «Набросай быстро / демо / посмотреть» → `fast`

Пользователь всегда может переопределить одним словом.
