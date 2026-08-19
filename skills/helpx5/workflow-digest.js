export const meta = {
  name: 'helpx5-digest',
  description: 'Только разбор материалов: по агенту на материал, результат в файлы digests/',
  whenToUse: 'Когда нужно разобрать новую партию материалов параллельно основному прогону',
  phases: [{ title: 'Разбор', detail: 'по агенту на материал, конспект сохраняется файлом' }],
}

// Отдельный прогон под фазу разбора: его можно гнать рядом с основным workflow.js,
// не мешая ему, — разборы копятся в файлах и переживают обрыв сессии.
const A = typeof args === 'string' ? JSON.parse(args) : (args || {})
const KB = A.kb || '/home/coder/Work/3. projects/x5transport/Продукты/Сайт х5т/Help-центр/knowledge-base'
const HELP = A.help || '/home/coder/Work/3. projects/x5transport/Продукты/Сайт х5т/Help-центр'
const SKILL = A.skill || '/home/coder/Work/3. projects/WibeSkills/skills/helpx5'
const MATERIALS = A.materials || []

if (!MATERIALS.length) {
  log('Материалов не передано.')
  return { error: 'empty materials' }
}

const DIGEST_SCHEMA = {
  type: 'object',
  required: ['material', 'summary', 'topics', 'quality'],
  properties: {
    material: { type: 'string' },
    summary: { type: 'string' },
    audience: { type: 'string' },
    topics: {
      type: 'array',
      items: {
        type: 'object',
        required: ['task', 'covered'],
        properties: {
          task: { type: 'string' },
          covered: { type: 'string' },
          locator: { type: 'string' },
          existing_article: { type: 'string', description: 'слаг статьи прод-базы, если тема уже есть' },
          interface: { type: 'string', description: 'веб-ЛК | приложение | оба' },
        },
      },
    },
    media: {
      type: 'array',
      items: {
        type: 'object',
        required: ['path', 'shows'],
        properties: { path: { type: 'string' }, shows: { type: 'string' }, locator: { type: 'string' } },
      },
    },
    contradictions: { type: 'array', items: { type: 'string' } },
    quality: { type: 'string' },
  },
}

phase('Разбор')
const digests = (await parallel(MATERIALS.map((m) => () =>
  agent(
    `Разбери материал для базы знаний help-центра X5 Транспорт (B2B-логистика).

МАТЕРИАЛ: «${m.name}» (${m.kind}), содержимое: ${m.dir}
${m.video ? `Это ВИДЕО: там transcript.md (речь с тайм-кодами) и frames/ — кадры по сменам сцен.
ОБЯЗАТЕЛЬНО посмотри кадры инструментом Read — часть роликов немые, кадры единственный источник.` : ''}

ЦЕЛЕВАЯ БАЗА — боевая база X5, её зеркало: ${KB}/prod/ (articles/*.md, manifest.json со слагами
и documentId, categories.json с 7 категориями). Прочитай manifest.json и categories.json прежде,
чем судить о новизне тем.

Что сделать:
1. Прочитай содержимое материала (для пачек начни с meta.json и README).
2. Выдели ЗАДАЧИ ПОЛЬЗОВАТЕЛЯ, которые материал закрывает — не разделы интерфейса, а что человек
   хочет сделать. Для каждой укажи, про какой интерфейс речь: веб-кабинет ЛК ТРК, мобильное
   приложение или оба (это важно: в базе одна статья описывает оба интерфейса разделами).
3. Для каждой задачи проверь, есть ли уже статья в прод-базе — укажи её слаг в existing_article.
4. Отметь годные картинки и кадры: путь и что на них видно.
5. Отметь расхождения с текстами прод-базы (изменилась кнопка, срок, экран).
6. СОХРАНИ свой разбор файлом ${KB}/digests/${m.md5}.json (создай папку digests, если её нет) —
   тем же объектом, что вернёшь по схеме. Файл нужен, чтобы разбор пережил обрыв сессии.

Статьи не пиши. Ничего не выдумывай: нет факта в материале — не пиши его.
Правила базы, если понадобятся: ${SKILL}/article-rules.md, ${HELP}/md-format.md.`,
    { label: `разбор:${m.name.slice(0, 28)}`, phase: 'Разбор', schema: DIGEST_SCHEMA }
  )
))).filter(Boolean)

log(`Разобрано: ${digests.length} из ${MATERIALS.length}`)

return {
  materials: digests.length,
  topics: digests.reduce((n, d) => n + (d.topics?.length || 0), 0),
  digests: digests.map((d) => ({ material: d.material, topics: d.topics?.length || 0, quality: d.quality })),
  contradictions: digests.flatMap((d) => (d.contradictions || []).map((c) => `${d.material}: ${c}`)),
}
