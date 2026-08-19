export const meta = {
  name: 'helpx5-update',
  description: 'База знаний help-центра: разбор новых материалов → план правок → статьи → ревью',
  whenToUse: 'Прогон скилла helpx5, когда в Inbox базы знаний появились новые материалы',
  phases: [
    { title: 'Разбор', detail: 'по агенту на материал: о чём он и какие статьи задевает' },
    { title: 'План', detail: 'сведение разборов с текущей базой: создать / обновить / объединить' },
    { title: 'Письмо', detail: 'по агенту на статью: текст по конвенции + медиа + карта связей' },
    { title: 'Ревью', detail: 'по агенту на статью: конвенция, стиль, противоречия с базой' },
  ],
}

// args = { materials: [{md5, name, kind, dir, video}], day, kb, skill, help }
// args может прийти строкой JSON — разбираем оба варианта, иначе прогон уходит вхолостую
const A = typeof args === 'string' ? JSON.parse(args) : (args || {})
const KB = A.kb || '/home/coder/Work/3. projects/x5transport/Продукты/Сайт х5т/Help-центр/knowledge-base'
const HELP = A.help || '/home/coder/Work/3. projects/x5transport/Продукты/Сайт х5т/Help-центр'
const SKILL = A.skill || '/home/coder/Work/3. projects/WibeSkills/skills/helpx5'
const MATERIALS = A.materials || []
const DAY = A.day || 'сегодня'

if (!MATERIALS.length) {
  log('Материалов не передано — нечего разбирать.')
  return { error: 'empty materials' }
}

const RULES = `Правила статьи — ${SKILL}/article-rules.md (прочитай перед работой).
Конвенция разметки — ${HELP}/md-format.md. Категории — ${HELP}/content-ops.md §2.
Текущая база: мастер-копии ${KB}/articles/*.md, снимок ${KB}/cms-snapshot.json.`

const DIGEST_SCHEMA = {
  type: 'object',
  required: ['material', 'summary', 'topics', 'quality'],
  properties: {
    material: { type: 'string' },
    summary: { type: 'string', description: 'о чём материал в 2–3 предложениях' },
    audience: { type: 'string', description: 'перевозчик | водитель | грузовладелец | все' },
    topics: {
      type: 'array',
      description: 'пользовательские задачи, которые материал закрывает',
      items: {
        type: 'object',
        required: ['task', 'covered'],
        properties: {
          task: { type: 'string', description: 'задача словами пользователя' },
          covered: { type: 'string', description: 'что именно есть в материале по этой задаче' },
          locator: { type: 'string', description: 'страница вики / стр. PDF / тайм-код видео' },
          existing_article: { type: 'string', description: 'слаг статьи базы, если тема уже есть' },
        },
      },
    },
    media: {
      type: 'array',
      description: 'годные картинки/кадры: путь + что на них',
      items: {
        type: 'object',
        required: ['path', 'shows'],
        properties: { path: { type: 'string' }, shows: { type: 'string' }, locator: { type: 'string' } },
      },
    },
    contradictions: {
      type: 'array',
      description: 'расхождения с тем, что уже написано в базе',
      items: { type: 'string' },
    },
    quality: { type: 'string', description: 'годен / частично / мусор — и почему' },
  },
}

const PLAN_SCHEMA = {
  type: 'object',
  required: ['actions'],
  properties: {
    actions: {
      type: 'array',
      items: {
        type: 'object',
        required: ['action', 'slug', 'title', 'category', 'audience', 'brief'],
        properties: {
          action: { type: 'string', description: 'create | update | merge' },
          slug: { type: 'string' },
          title: { type: 'string' },
          category: { type: 'string', description: 'слаг СУЩЕСТВУЮЩЕЙ категории' },
          audience: { type: 'string' },
          brief: { type: 'string', description: 'что должно быть в статье: шаги, факты, границы' },
          sources: {
            type: 'array',
            items: {
              type: 'object',
              required: ['material'],
              properties: { material: { type: 'string' }, locator: { type: 'string' } },
            },
          },
          merges: { type: 'array', description: 'слаги статей базы, которые поглощаются', items: { type: 'string' } },
          change_reason: { type: 'string' },
        },
      },
    },
    gaps: { type: 'array', description: 'темы, по которым материала не хватило', items: { type: 'string' } },
    conflicts: { type: 'array', description: 'противоречия для решения человеком', items: { type: 'string' } },
  },
}

const REVIEW_SCHEMA = {
  type: 'object',
  required: ['slug', 'verdict', 'issues'],
  properties: {
    slug: { type: 'string' },
    verdict: { type: 'string', description: 'ok | fixed | blocked' },
    issues: { type: 'array', items: { type: 'string' } },
    fixed: { type: 'array', description: 'что поправил прямо в файле', items: { type: 'string' } },
  },
}

/* ── Фаза 1: разбор материалов, по агенту на материал ─────────────────────── */
phase('Разбор')
const digests = (await parallel(MATERIALS.map((m) => () =>
  agent(
    `Ты разбираешь исходный материал для базы знаний help-центра X5 Транспорт (B2B-логистика).

МАТЕРИАЛ: «${m.name}» (тип ${m.kind}).
Извлечённое содержимое: ${m.dir}
${m.video ? `Это ВИДЕО. Там же: transcript.md (речь с тайм-кодами) и frames/ — кадры по сменам сцен.
ОБЯЗАТЕЛЬНО посмотри кадры инструментом Read (это .png, ты их видишь). В записях экрана весь
смысл в интерфейсе, а не в звуке; часть роликов вообще без речи — тогда кадры единственный источник.` : ''}

Что сделать:
1. Прочитать всё содержимое папки материала (Read/Grep; для пачек — сначала meta.json).
2. Понять, какие ЗАДАЧИ ПОЛЬЗОВАТЕЛЯ материал закрывает — не «какие разделы интерфейса
   описаны», а что человек хочет сделать: зарегистрироваться, взять рейс, получить оплату.
3. Для каждой задачи посмотреть, есть ли уже статья в базе (${KB}/articles/, имена = слаги;
   быстрый поиск — Grep по заголовкам). Указать слаг, если тема уже покрыта.
4. Отметить годные картинки/кадры: путь и что на них видно.
5. Отметить расхождения с текущими статьями (изменился экран, другой срок, другая кнопка).

${RULES}

Статьи НЕ пиши — только разбор. Верни структуру по схеме.`,
    { label: `разбор:${m.name.slice(0, 28)}`, phase: 'Разбор', schema: DIGEST_SCHEMA }
  )
))).filter(Boolean)

log(`Разобрано материалов: ${digests.length} из ${MATERIALS.length}`)

/* ── Фаза 2: один план на всю базу (нужен барьер — план видит все разборы) ── */
phase('План')
const plan = await agent(
  `Ты — редактор базы знаний help-центра X5 Транспорт. Сведи разборы материалов
с текущей структурой базы и составь план правок.

РАЗБОРЫ МАТЕРИАЛОВ:
${JSON.stringify(digests, null, 2)}

ТЕКУЩАЯ БАЗА: ${KB}/cms-snapshot.json (список статей с разделами и заголовками),
тела — ${KB}/articles/*.md. Прочитай снимок целиком, прежде чем планировать.

Решения, которые нужно принять:
- Что создать новой статьёй, что дописать в существующую, что объединить.
- ОБЪЕДИНЯТЬ короткие куски: выгрузки вики содержат страницы на 3–5 строк, которые
  сами по себе статьёй быть не могут. Собирай их в одну статью по задаче пользователя.
- Не плодить дубли: если тема уже есть — action=update с указанием, что добавить.
- Категории брать только СУЩЕСТВУЮЩИЕ (из снимка). Новая категория — лишь если в имеющихся
  ≥8 статей и тема не лезет никуда; такое отметь в conflicts, не в actions.
- Демо-контент (категории demo-*) не трогать.
- В brief положи фактуру для писателя: шаги, точные названия кнопок, сроки, ограничения,
  и откуда это взято. Писатель не будет перечитывать материалы целиком.

${RULES}

Верни план по схеме. Действий столько, сколько реально нужно — не раздувай.`,
  { label: 'план базы', phase: 'План', schema: PLAN_SCHEMA }
)

const actions = (plan?.actions || []).filter((a) => a.slug && a.brief)
log(`План: ${actions.length} статей · пробелов ${plan?.gaps?.length || 0} · противоречий ${plan?.conflicts?.length || 0}`)

/* ── Фазы 3–4: pipeline — каждая статья идёт «письмо → ревью» без барьера ─── */
const written = await pipeline(
  actions,
  (a) =>
    agent(
      `Напиши статью help-центра X5 Транспорт и сохрани её файлом.

ДЕЙСТВИЕ: ${a.action}
ФАЙЛ: ${KB}/articles/${a.slug}.md ${a.action === 'update' ? '(существует — правь его, сохранив фронтматтер и cms_id)' : '(создать)'}
ЗАГОЛОВОК: ${a.title}
РАЗДЕЛ: ${a.category} · АУДИТОРИЯ: ${a.audience}
${a.merges?.length ? `ПОГЛОЩАЕТ статьи: ${a.merges.join(', ')} — их содержимое перенеси сюда, а сами файлы НЕ удаляй (решение об удалении принимает человек, отметь это в change_reason).` : ''}

ЧТО ДОЛЖНО БЫТЬ В СТАТЬЕ:
${a.brief}

ИСТОЧНИКИ (перечитай при нехватке фактуры):
${JSON.stringify(a.sources || [], null, 2)}

Порядок работы:
1. Прочитай ${SKILL}/article-rules.md — там каркас, разметка и стиль. Соблюдай буквально.
2. ${a.action === 'update' ? 'Прочитай текущий файл статьи и правь точечно, не переписывая целиком то, что и так верно.' : 'Посмотри 2–3 соседние статьи того же раздела, чтобы попасть в тон и структуру.'}
3. Картинки: если в источниках есть годные — скопируй их в ${KB}/media/${a.slug}/
   и сошлись из текста коротким именем файла. Подпись в alt — для читателя.
4. Запиши файл статьи (Write/Edit).
5. Запиши карточку связей ОТДЕЛЬНЫМ файлом ${KB}/content-map.d/${a.slug}.json —
   не трогай общий content-map.json (в него пишут все агенты сразу, затрёте друг друга).
   Формат файла: {"sources": [{"material": "...", "locator": "..."}], "media": ["имя.png"],
   "change_reason": "${a.change_reason || ''}"} — locator это страница вики, «стр. 7» или таймкод «01:12».

Ничего не выдумывай: нет факта в источниках — не пиши его. Верни одной строкой:
слаг, сколько шагов, сколько картинок, что осталось непокрытым.`,
      { label: `пишу:${a.slug.slice(0, 26)}`, phase: 'Письмо' }
    ),
  (_res, a) =>
    agent(
      `Проверь статью ${KB}/articles/${a.slug}.md как придирчивый редактор help-центра.

Проверяй по ${SKILL}/article-rules.md:
1. Каркас: фронтматтер заполнен, категория существует (сверь с ${KB}/cms-snapshot.json),
   первый блок «> **Коротко:**», заголовки платформ ровно «## Веб-ЛК» / «## Приложение».
2. Шаги: одно действие на шаг, повелительное наклонение, названия кнопок как в интерфейсе.
3. Стиль: язык пользователя, а не системы. Никаких «осуществляется», «данный функционал»,
   канцелярита, штампов и декоративных эмодзи.
4. Картинки: ссылки ведут на существующие файлы в ${KB}/media/${a.slug}/, подписи осмысленные.
5. Противоречия: сравни с 2–3 соседними статьями раздела «${a.category}» — не спорит ли
   статья с ними по фактам, нет ли дубля.
6. Карта связей: существует ${KB}/content-map.d/${a.slug}.json с источниками и медиа.
   Нет файла — создай его сам по данным статьи.

Мелкие огрехи (стиль, разметка, подписи) — ПОЧИНИ прямо в файле (Edit).
Смысловые проблемы (нет фактуры, спорит с другой статьёй, выдуманные числа) — не чини,
опиши в issues и поставь verdict=blocked.`,
      { label: `ревью:${a.slug.slice(0, 26)}`, phase: 'Ревью', schema: REVIEW_SCHEMA }
    )
)

const reviews = written.filter(Boolean)
const blocked = reviews.filter((r) => r.verdict === 'blocked')

return {
  day: DAY,
  materials: digests.length,
  planned: actions.length,
  written: reviews.length,
  blocked: blocked.map((r) => ({ slug: r.slug, issues: r.issues })),
  gaps: plan?.gaps || [],
  conflicts: plan?.conflicts || [],
  contradictions: digests.flatMap((d) => (d.contradictions || []).map((c) => `${d.material}: ${c}`)),
}
