export const meta = {
  name: 'helpx5-cjm',
  description: 'Восстановить путь пользователя по видео и пересобрать структуру базы под него',
  whenToUse: 'Когда структура разделов должна следовать пути пользователя, а не устройству системы',
  phases: [
    { title: 'Путь', detail: 'по агенту на видео: какие шаги проходит пользователь и где' },
    { title: 'Структура', detail: 'свести путь и разложить статьи по этапам' },
  ],
}

const A = typeof args === 'string' ? JSON.parse(args) : (args || {})
const KB = A.kb || '/home/coder/Work/3. projects/x5transport/Продукты/Сайт х5т/Help-центр/knowledge-base'
const SKILL = A.skill || '/home/coder/Work/3. projects/WibeSkills/skills/helpx5'
const VIDEOS = A.videos || []

if (!VIDEOS.length) {
  log('Видео не переданы.')
  return { error: 'empty videos' }
}

const STEP_SCHEMA = {
  type: 'object',
  required: ['video', 'steps'],
  properties: {
    video: { type: 'string' },
    role: { type: 'string', description: 'кто действует: перевозчик-логист, водитель, грузовладелец' },
    scenario: { type: 'string', description: 'какой отрезок пути показан целиком, одной фразой' },
    steps: {
      type: 'array',
      description: 'шаги в том порядке, в каком они идут в записи',
      items: {
        type: 'object',
        required: ['order', 'action', 'surface'],
        properties: {
          order: { type: 'number' },
          action: { type: 'string', description: 'что делает пользователь, его словами' },
          surface: { type: 'string', description: 'веб-кабинет | мобильное приложение | письмо | бот' },
          screen: { type: 'string', description: 'раздел или экран, где это происходит' },
          locator: { type: 'string', description: 'тайм-код' },
          blocker: { type: 'string', description: 'что мешает продолжить, если видно' },
        },
      },
    },
    entry_point: { type: 'string', description: 'с чего человек начинает этот отрезок' },
    exit_point: { type: 'string', description: 'чем отрезок заканчивается, что получил человек' },
  },
}

const IA_SCHEMA = {
  type: 'object',
  required: ['stages', 'orphans'],
  properties: {
    dominant_surface: { type: 'string' },
    stages: {
      type: 'array',
      description: 'этапы пути = разделы базы, по порядку прохождения',
      items: {
        type: 'object',
        required: ['slug', 'name', 'order', 'why', 'articles'],
        properties: {
          slug: { type: 'string' },
          name: { type: 'string', description: 'название раздела словами пользователя' },
          order: { type: 'number' },
          audience: { type: 'string' },
          why: { type: 'string', description: 'какой момент пути закрывает раздел' },
          description: { type: 'string', description: 'подзаголовок раздела для сайта' },
          articles: {
            type: 'array',
            items: {
              type: 'object',
              required: ['slug', 'order'],
              properties: {
                slug: { type: 'string' },
                order: { type: 'number', description: 'порядок внутри раздела = порядок шагов' },
                from: { type: 'string', description: 'из какого раздела переезжает' },
                note: { type: 'string' },
              },
            },
          },
        },
      },
    },
    merges: {
      type: 'array',
      description: 'статьи, которые стоит слить как избыточные',
      items: {
        type: 'object',
        required: ['keep', 'absorb', 'why'],
        properties: { keep: { type: 'string' }, absorb: { type: 'array', items: { type: 'string' } }, why: { type: 'string' } },
      },
    },
    orphans: { type: 'array', description: 'статьи, не попавшие ни в один этап', items: { type: 'string' } },
    gaps: { type: 'array', description: 'шаги пути, по которым статьи нет', items: { type: 'string' } },
  },
}

/* ── Фаза 1: путь по каждому видео ────────────────────────────────────────── */
phase('Путь')
const paths = (await parallel(VIDEOS.map((v) => () =>
  agent(
    `Восстанови путь пользователя по видеозаписи продукта X5 Транспорт (B2B-логистика).

ЗАПИСЬ: «${v.name}», разобранные материалы: ${v.dir}
Там transcript.md (речь с тайм-кодами, если она есть) и frames/ — кадры по сменам сцен.

${v.speech ? 'В записи есть речь: прочитай transcript.md целиком, он объясняет, что происходит.' :
  'В записи РЕЧИ НЕТ — это немая запись экрана. Единственный источник это кадры.'}
ОБЯЗАТЕЛЬНО посмотри ВСЕ кадры инструментом Read (это .png, ты их видишь) — по ним
определяется, в каком интерфейсе идёт работа и что человек нажимает.

Задача: выписать ШАГИ ПУТИ в том порядке, в каком они идут, глазами пользователя:
- что человек делает («заполняет анкету компании», «подписывает оферту», «делает ставку»),
  а не что делает система;
- где он это делает: веб-кабинет, мобильное приложение, письмо, бот — определи по кадрам
  (браузер с адресной строкой и широкой вёрсткой это веб; узкий экран с нижней навигацией
  это приложение);
- с чего отрезок начинается и чем заканчивается — что человек получил на выходе;
- где видно затруднение: ошибка, ожидание проверки, непонятный шаг.

Ничего не додумывай: чего не видно в записи — не пиши.`,
    { label: `путь:${v.name.slice(0, 26)}`, phase: 'Путь', schema: STEP_SCHEMA }
  )
))).filter(Boolean)

log(`Разобрано записей: ${paths.length}, шагов всего: ${paths.reduce((n, p) => n + (p.steps?.length || 0), 0)}`)

/* ── Фаза 2: структура базы по пути ───────────────────────────────────────── */
phase('Структура')
const ia = await agent(
  `Ты — информационный архитектор help-центра X5 Транспорт. Пересобери структуру базы так,
чтобы разделы шли по пути пользователя, а не по устройству системы.

ПУТЬ, ВОССТАНОВЛЕННЫЙ ПО ЗАПИСЯМ ПРОДУКТА:
${JSON.stringify(paths, null, 2)}

ТЕКУЩЕЕ СОСТОЯНИЕ БАЗЫ: ${KB}/cms-snapshot.json — 65 статей в шести разделах
(rejsy 28, biznes-schet 13, nachalo-raboty-s-prilozheniem 10, rabota-s-zayavkami 9,
prilozhenie 3, stavki 2). Тела статей — ${KB}/articles/*.md. Прочитай снимок целиком
и просмотри заголовки статей, прежде чем раскладывать.

ТРЕБОВАНИЯ ВЛАДЕЛЬЦА:
1. Доминанта — ВЕБ-КАБИНЕТ. Сейчас структура построена вокруг мобильного приложения
   («Приложение», «Начало работы с приложением» стоят вверху) — это неверно.
   Приложение это вторая поверхность, а не начало пути.
2. Разделы = этапы пути пользователя, в порядке прохождения: человек приходит с задачей
   и должен находить раздел там, где он сейчас находится в своём пути.
3. Глубина ровно один уровень: раздел → статья. Никакой тройной вложенности.
4. Избыточность убрать: если две-три статьи описывают один момент пути, предложи слияние
   (какую оставить, какие поглотить, почему).
5. Порядок статей внутри раздела = порядок шагов, а не алфавит.
6. Названия разделов словами пользователя, а не терминами системы.

Учитывай: часть пути видна в записях (регистрация, анкета, оферта, вход, торги, рейс,
ЭТрН, ярд, отметка на точке), остальное достраивай по составу статей.

Верни структуру: список этапов с порядком и составом статей, предложения по слияниям,
статьи-сироты и пробелы пути. Каждая из 65 статей должна попасть либо в этап, либо
в orphans — ничего не терять.

Правила разметки и стиля, если понадобятся: ${SKILL}/article-rules.md`,
  { label: 'структура по пути', phase: 'Структура', schema: IA_SCHEMA }
)

const placed = (ia?.stages || []).reduce((n, s) => n + (s.articles?.length || 0), 0)
log(`Этапов: ${ia?.stages?.length || 0} · размещено статей: ${placed} · сирот: ${ia?.orphans?.length || 0}`)

return { paths, ia, placed }
