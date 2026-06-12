# NMT-канон: роутинг «задача → файл»

Канон Next Move Theory / AJTBD (Ivan Zamesin) — источник правды по методологии для всех продуктовых и маркетинговых скиллов. Читается **в рантайме**: скилл открывает нужный файл перед тем, как отвечать/генерировать, и не полагается на generic JTBD из трейна модели — методология Замесина существенно расходится с Christensen/Ulwick/Moesta.

**Корень канона:** `NMT_CANON_ROOT` из project-config; если не задан — `<библиотека скиллов>/../canon/Next-Move-Theory-Canon/` (submodule репозитория WibeSkills). Если файла нет по пути — сообщи, не выдумывай содержимое.

**Приватный слой (опционально, `COURSE_NOTES_ROOT`):** `mechanics-navigator.md` — 82 механики × 15 задач (расширение публичных ~26), `theory-canon.md` — флаги F1–F33 для аудита. Нет слоя — работаем только от канона.

## Ленивая загрузка

Не читай весь канон. Узкий вопрос → один файл из таблицы. Широкая/стратегическая задача → сначала два обзорных (`ajtbd-key-theses.md` + `nmt-key-theses.md`), затем нужные глубокие. Файл, уже прочитанный в этой сессии, не перечитывай.

## Таблица роутинга

| Задача / вопрос | Файл (от корня канона) |
|---|---|
| Вся методология AJTBD одним файлом; канонические определения (работа, ценность, сегмент, Aha Moment, Consideration Activators) | `Advanced-Jobs-To-Be-Done/ajtbd-key-theses.md` |
| Интегративный корень NMT: 4 столпа + ToC, цепочка к прибыли, локальный vs глобальный оптимум | `Next-Move-Theory/nmt-key-theses.md` |
| 8 элементов работы, критерии успеха (направление + уровень), вопросы для интервью по элементам | `Advanced-Jobs-To-Be-Done/job-structure.md` |
| Граф работ: уровни Big/Core/Small/Micro (относительны охвату продукта), подъём на уровень, Previous/Next Job | `Advanced-Jobs-To-Be-Done/job-graph.md` |
| Типы работ: Regular / Orientation / Tax / Fake / Emotional / Viral; частотность | `Advanced-Jobs-To-Be-Done/job-types-and-properties.md` |
| Critical Chain: разрывы, циклы, hand-off'ы, placement Aha Moment, отвал как разрыв цепи | `Advanced-Jobs-To-Be-Done/critical-chain.md` |
| Ценность: формула `P(outcome) × Outcome − Cost`, 6 измерений стоимости, 8 порядков приоритета критериев, карта «критерии → механики», Red Queen | `Advanced-Jobs-To-Be-Done/value-creation.md` |
| Каталог механик создания ценности (публичные ~26; через `COURSE_NOTES_ROOT` — 82) | `Advanced-Jobs-To-Be-Done/value-creation-mechanics.md` |
| Смена поведения: свитчинг = замена графа работ, привычка (не воевать в лоб), страхи, 7 триггеров восприимчивости | `Advanced-Jobs-To-Be-Done/behaviour-change.md` |
| 5 компонент Consideration Activators (что вложить в голову клиента до переключения) | `Advanced-Jobs-To-Be-Done/consideration-activators.md` |
| Объективные барьеры vs страхи; 6 классов барьеров | `Advanced-Jobs-To-Be-Done/barrier-removal.md` |
| Коммуникация: формула value prop, one-liner, 7 формул креативов, 9–10-блочный лендинг как диагностика | `Advanced-Jobs-To-Be-Done/communication.md` |
| Внимание клиента как ресурс: воронка = переходы внимания, первый Aha максимально влево | `Advanced-Jobs-To-Be-Done/customers-attention-management.md` |
| Сегментация по графам работ (не по демографии), каузальные критерии vs симптомы, порядок срезов, Map of Segments | `Advanced-Jobs-To-Be-Done/segmentation.md` |
| Научный фундамент: аллостаз, prediction error, эмоции, привычка, loss aversion | `Advanced-Jobs-To-Be-Done/scientific-foundations.md` |
| B2B: сделка как граф работ по ролям, личные работы ЛПР > бизнес-работы | `Advanced-Jobs-To-Be-Done/b2b.md` |
| ABCDX: маржа × удовлетворённость, увольнение C/D, X как сигнал роста | `ABCDX-Segmentation/abcdx-segmentation-key-theses.md` |
| RAT: список позитивных допущений, формула приоритета, MVP = зонд, пивот = смена набора допущений | `Riskiest-Assumption-Test/rat-key-theses.md` |
| Главный алгоритм: 10 шагов, 3 фазы, гейты, анти-паттерны | `Algorithms/the-algorithm.md` |
| Гайд AJTBD-интервью: принципы, банк вопросов, рекрут только плативших | `HowTos/basic-ajtbd-interview-guide-and-principles.md` |
| Фокус как управление вниманием компании, два трека инвестиций | `Next-Move-Theory/focus-as-company-attention-management.md` |
| Вычитание как мета-оператор всех столпов | `Next-Move-Theory/subtraction.md` |
| Локальный vs глобальный оптимум, дилемма инноватора | `Next-Move-Theory/local-vs-global-optimum.md` |

## Ключевые инварианты (короткая шпаргалка, без замены чтения канона)

- **Работа** = спецификация перехода A → B ради работы уровнем выше; `я хочу + глагол` — главный элемент из 8, не вся работа; каждый глагол — отдельная работа.
- **Ценность** = энергоэффективность для мозга против его предсказания; **Aha Moment** = ценность выше предсказания (не signup/login); Problem = ниже. Сокращения PPE/NPE не использовать.
- **Сегмент** = похожие Core Jobs + похожие критерии успеха **в похожем порядке приоритета**; демография — не первый срез; Big Job — контекст мотивации, не критерий сегментации.
- **Фича — не ценность**, а транспорт ценности; планируем гипотезами ценности, не фичами.
- **Four Forces — deprecated**, выбор сегмента — selection screen (added value · demand · margin · size×switchability + existential-гейт).
- **RAT**: выживание мультипликативно; самый сильный ход — выбросить допущение, а не проверить.
