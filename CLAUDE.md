# WibeSkills — суть и правила

Библиотека скиллов продуктовой разработки (Epic → Story → Task, русский) на методологии
NMT/AJTBD Замесина; канон — git submodule `canon/`, читается скиллами в рантайме.
Подключена к `Work/.claude/skills` симлинком. Полное описание — [README.md](README.md),
план развития — [ROADMAP.md](ROADMAP.md).

## Режимы

- **MODE** — `app` · **TRACK_DEFAULT** — `prd` (правки библиотеки — обычно уже продуманные требования)

## Где что лежит

| Что | Где |
|---|---|
| Скиллы | `skills/<name>/SKILL.md` |
| Общие протоколы (оси MODE×TRACK, handoff, delivery, стиль) | `skills/_shared/` |
| Шаблоны CLAUDE.md/summary | `skills/_shared/templates/` |
| Канон методологии | `canon/Next-Move-Theory-Canon/` (роутинг — `skills/_shared/nmt-canon-routing.md`) |

## Правила проекта

- Формат скилла: компактный (~200–250 строк), методологию читать из канона, не вшивать.
- Правки протоколов `_shared/` затрагивают все проекты — прогонять `pipeline-retro` после серии правок.
- Канон обновлять `git submodule update --remote canon`; свои правки в canon/ не коммитить.
- Лицензия CC BY-NC-SA 4.0, атрибуция Замесина обязательна.
