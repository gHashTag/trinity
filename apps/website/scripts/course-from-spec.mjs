#!/usr/bin/env node
// course-from-spec.mjs -- the course at #/course from `specs/course/course.t27`.
//
// Reads the course spec and its Russian contract (`specs/course/course-ru.t27`) through the real
// compiler (`t27_compiler.wasm`), checks the constant schema, evaluates every `test` block against
// the declared constants, then checks what the spec points at:
//
//   - every widget a lesson opens or offers is in the widget gallery (queenWidgets.generated.ts,
//     itself generated from specs/widgets/gallery.t27), no two lessons open the same one, and
//     every gallery widget is used by some lesson;
//   - every lesson spec exists under public/t27/files/ and compiles clean, all seven backends;
//   - the Russian bundle the contract names covers every field, carries no key the course does
//     not have, keeps every number and {placeholder} of the English field, and neither language
//     makes a superlative claim (the docs generator's FORBIDDEN_* lists).
//
// The course adds no words of its own: each one is in the spec or the bundle. Writes the files
// nobody edits by hand:
//
//   src/lib/course.generated.ts   what src/pages/Course.tsx draws
//   public/learn/course.t27       the spec, byte for byte (the page links to it)
//
// Run:      node scripts/course-from-spec.mjs            (write)
//           node scripts/course-from-spec.mjs --check    (fail if the committed files are stale)
//           node scripts/course-from-spec.mjs --json     (print the course as JSON)
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { CYRILLIC, SITE, checkSchema, compilerErrors, constsOf, loadCompiler, sha256, verdictOf } from './agents-from-specs.mjs'
import { FORBIDDEN_EN, FORBIDDEN_RU } from './docs-from-specs.mjs'
import { runSpecTests } from './viewport-from-spec.mjs'

const WASM = 'public/t27/t27_compiler.wasm'
export const COURSE_SPEC = 'specs/course/course.t27'
export const RU_SPEC = 'specs/course/course-ru.t27'
export const TS_OUT = 'src/lib/course.generated.ts'
export const PUBLIC_SPEC_OUT = 'public/learn/course.t27'
export const GALLERY_TS = 'src/lib/queenWidgets.generated.ts'
export const LESSON_SPEC_ROOT = 'public/t27/files'
const BACKENDS = ['c', 'js', 'rust', 'ts', 'verilog', 'verilog_hir', 'zig']

const REQUIRED = {
  KIND: 'str', ID: 'str', SCHEMA_VERSION: 'u8', GENERATED: 'arr', ROUTE: 'str', GALLERY: 'str', LOCALES: 'arr', RU_CONTRACT: 'str',
  PROGRESS_KEY: 'str', SENDS_NOTHING: 'bool', COHORT_ROUTE: 'str', TOOL_FRAME_HEIGHT: 'u16', PLAYER_FRAME_HEIGHT: 'u16', TITLE: 'str', DESCRIPTION: 'str',
  LESSONS_PER_MODULE: 'u8', MODULE_COUNT: 'u8', MODULE_IDS: 'arr', MODULE_TITLES: 'arr', MODULE_LINES: 'arr',
  LESSON_COUNT: 'u8', LESSON_IDS: 'arr', LESSON_MODULES: 'arr', LESSON_WIDGETS: 'arr', LESSON_ALSO: 'arr', LESSON_SPECS: 'arr',
  LESSON_TITLES: 'arr', LESSON_GOALS: 'arr', LESSON_TEXTS: 'arr', LESSON_TASKS: 'arr',
}
const RU_REQUIRED = {
  KIND: 'str', LOCALE: 'str', SOURCE_LOCALE: 'str', SOURCE_SPEC: 'str', BUNDLE_REPO: 'str', BUNDLE_PATH: 'str', BUNDLE_FORMAT: 'str',
  MODULE_FIELDS: 'arr', LESSON_FIELDS: 'arr', UI_KEY: 'str', FALLBACK: 'str', COVERAGE_REQUIRED: 'bool', ORPHANS_ALLOWED: 'bool', ENABLED: 'bool',
}
const PARALLEL = {
  MODULE_COUNT: ['MODULE_IDS', 'MODULE_TITLES', 'MODULE_LINES'],
  LESSON_COUNT: ['LESSON_IDS', 'LESSON_MODULES', 'LESSON_WIDGETS', 'LESSON_ALSO', 'LESSON_SPECS', 'LESSON_TITLES', 'LESSON_GOALS', 'LESSON_TEXTS', 'LESSON_TASKS'],
}
// The English field each Russian field translates.
const MODULE_SOURCE = { TITLE: 'MODULE_TITLES', LINE: 'MODULE_LINES' }
const LESSON_SOURCE = { TITLE: 'LESSON_TITLES', GOAL: 'LESSON_GOALS', TEXT: 'LESSON_TEXTS', TASK: 'LESSON_TASKS' }
// The page strings: every SAY_ constant, plus the title and description.
const sayNames = (f) => ['TITLE', 'DESCRIPTION', ...Object.keys(f).filter((k) => k.startsWith('SAY_')).map((k) => k.slice(4)).sort()]
const sayOf = (f, key) => (key === 'TITLE' || key === 'DESCRIPTION' ? f[key] : f[`SAY_${key}`])

const same = (a, b) => JSON.stringify(a) === JSON.stringify(b)
const uniq = (values) => new Set(values).size === values.length
const ID_RE = /^[a-z0-9][a-z0-9-]*$/
const listOf = (s) => (s ? s.split(',').map((x) => x.trim()) : [])
/** The digits of a text as a sorted multiset: a translation carries numbers, it never derives them. */
export const digitsOf = (s) => (s.match(/\d+(?:[.,]\d+)*/g) ?? []).map((n) => n.replace(/[^\d]/g, '')).sort()
export const placeholdersOf = (s) => (s.match(/\{\d+\}/g) ?? []).sort()
const forbidden = (s, re) => [...s.matchAll(new RegExp(re.source, re.flags))].map((m) => m[0])

/** The gallery as the widget generator wrote it. */
export function readGallery(root = SITE) {
  const ts = readFileSync(join(root, GALLERY_TS), 'utf8')
  const body = ts.match(/export const QUEEN_WIDGETS = ([\s\S]*?) as const\n/)?.[1]
  if (!body) throw new Error(`${GALLERY_TS}: no QUEEN_WIDGETS literal`)
  return JSON.parse(body)
}

export function semanticProblems(f, file = COURSE_SPEC) {
  const p = []
  if (f.KIND !== 'course') p.push(`${file}: KIND must be "course"`)
  if (f.SCHEMA_VERSION !== 1) p.push(`${file}: SCHEMA_VERSION must be 1`)
  if (!same(f.GENERATED, [TS_OUT, PUBLIC_SPEC_OUT])) p.push(`${file}: GENERATED must be ${JSON.stringify([TS_OUT, PUBLIC_SPEC_OUT])}`)
  if (f.RU_CONTRACT !== RU_SPEC) p.push(`${file}: RU_CONTRACT must be ${RU_SPEC}`)
  if (f.SENDS_NOTHING !== true) p.push(`${file}: SENDS_NOTHING must be true; progress stays in the reader's browser`)
  if (f.LOCALES[0] !== 'en') p.push(`${file}: LOCALES must start with "en", the language of the spec`)
  for (const [countName, arrays] of Object.entries(PARALLEL)) {
    for (const name of arrays) if (f[name].length !== f[countName]) p.push(`${file}: ${name}.length ${f[name].length} != ${countName} ${f[countName]}`)
  }
  if (f.MODULE_COUNT * f.LESSONS_PER_MODULE !== f.LESSON_COUNT) p.push(`${file}: MODULE_COUNT * LESSONS_PER_MODULE != LESSON_COUNT`)
  for (const ids of ['MODULE_IDS', 'LESSON_IDS']) {
    if (!uniq(f[ids])) p.push(`${file}: ${ids} must be unique`)
    f[ids].forEach((id) => { if (!ID_RE.test(id)) p.push(`${file}: ${ids} entry ${JSON.stringify(id)} is not a lower-case slug`) })
  }
  // Modules run in order, LESSONS_PER_MODULE lessons each.
  f.LESSON_MODULES.forEach((m, i) => {
    const want = f.MODULE_IDS[Math.floor(i / f.LESSONS_PER_MODULE)]
    if (m !== want) p.push(`${file}: LESSON_MODULES[${i}] is ${m}; lesson ${i + 1} belongs to module ${want}`)
  })
  for (const name of ['MODULE_TITLES', 'MODULE_LINES', 'LESSON_TITLES', 'LESSON_GOALS', 'LESSON_TEXTS', 'LESSON_TASKS']) {
    f[name].forEach((s, i) => { if (!s.trim()) p.push(`${file}: ${name}[${i}] is empty`) })
  }
  for (const key of sayNames(f)) {
    const s = sayOf(f, key)
    if (typeof s !== 'string' || !s.trim()) p.push(`${file}: ${key === 'TITLE' || key === 'DESCRIPTION' ? key : `SAY_${key}`} is empty`)
  }
  const english = [f.TITLE, f.DESCRIPTION, ...sayNames(f).map((k) => sayOf(f, k)), ...f.MODULE_TITLES, ...f.MODULE_LINES, ...f.LESSON_TITLES, ...f.LESSON_GOALS, ...f.LESSON_TEXTS, ...f.LESSON_TASKS]
  for (const s of english) for (const hit of forbidden(s, FORBIDDEN_EN)) p.push(`${file}: superlative ${JSON.stringify(hit)} in ${JSON.stringify(s.slice(0, 60))}`)
  return p
}

/** Every widget named exists; main widgets are distinct and framable; every gallery widget is used. */
export function widgetProblems(f, gallery, file = COURSE_SPEC) {
  const p = []
  const byId = new Map(gallery.widgets.map((w) => [w.id, w]))
  if (!uniq(f.LESSON_WIDGETS)) p.push(`${file}: LESSON_WIDGETS must be unique; every lesson opens its own widget`)
  const used = new Set()
  f.LESSON_IDS.forEach((id, i) => {
    const main = f.LESSON_WIDGETS[i]
    const w = byId.get(main)
    if (!w) p.push(`${file}: lesson ${id} opens ${main}, which ${f.GALLERY} does not have`)
    else if (!w.preview) p.push(`${file}: lesson ${id} opens ${main}, a ${w.kind} with no framable page; offer it under LESSON_ALSO`)
    used.add(main)
    for (const also of listOf(f.LESSON_ALSO[i])) {
      if (!byId.has(also)) p.push(`${file}: lesson ${id} offers ${also}, which ${f.GALLERY} does not have`)
      if (also === main) p.push(`${file}: lesson ${id} offers its own widget ${also} again`)
      used.add(also)
    }
  })
  for (const w of gallery.widgets) if (!used.has(w.id)) p.push(`${file}: gallery widget ${w.id} is in no lesson; the course covers the whole gallery`)
  return p
}

/** Every lesson spec compiles clean on every backend. */
export function lessonSpecProblems(f, analyze, root = SITE, file = COURSE_SPEC) {
  const p = []
  f.LESSON_SPECS.forEach((path, i) => {
    if (!path) return
    const at = join(root, LESSON_SPEC_ROOT, path)
    if (!/^specs\/[A-Za-z0-9_\-/.]+\.t27$/.test(path)) { p.push(`${file}: LESSON_SPECS[${i}] ${path} is not specs/<path>.t27`); return }
    if (!existsSync(at)) { p.push(`${file}: LESSON_SPECS[${i}] ${LESSON_SPEC_ROOT}/${path} is missing`); return }
    const a = analyze(readFileSync(at, 'utf8'))
    const v = verdictOf(a)
    const bad = BACKENDS.filter((b) => !a.targets?.[b]?.ok)
    if (!v.typecheckOk || v.errors || v.discarded || !v.hirOk || bad.length) p.push(`${file}: lesson ${f.LESSON_IDS[i]} spec ${path} is not clean (${JSON.stringify(v)}${bad.length ? `, backends ${bad.join(',')}` : ''}); a lesson shows a spec that compiles`)
  })
  return p
}

/** The Russian bundle against its contract and the English fields. */
export function bundleProblems(f, ru, bundle, bundlePath) {
  const p = []
  const strict = ru.COVERAGE_REQUIRED
  const check = (where, en, tr) => {
    if (typeof tr !== 'string' || !tr.trim()) { if (strict) p.push(`${bundlePath}: ${where} is missing`); return }
    if (!CYRILLIC.test(tr)) p.push(`${bundlePath}: ${where} has no Cyrillic; untranslated`)
    if (!same(digitsOf(en), digitsOf(tr))) p.push(`${bundlePath}: ${where} numbers ${JSON.stringify(digitsOf(tr))} != English ${JSON.stringify(digitsOf(en))}`)
    if (!same(placeholdersOf(en), placeholdersOf(tr))) p.push(`${bundlePath}: ${where} placeholders ${placeholdersOf(tr).join(' ')} != English ${placeholdersOf(en).join(' ')}`)
    for (const hit of forbidden(tr, FORBIDDEN_RU)) p.push(`${bundlePath}: ${where} superlative ${JSON.stringify(hit)}`)
  }
  if (bundle.$spec !== RU_SPEC) p.push(`${bundlePath}: $spec must be ${RU_SPEC}`)
  if (bundle.locale !== ru.LOCALE) p.push(`${bundlePath}: locale ${bundle.locale} != contract ${ru.LOCALE}`)
  const ui = bundle[ru.UI_KEY] ?? {}
  const modules = bundle.modules ?? {}
  const lessons = bundle.lessons ?? {}
  const says = sayNames(f)
  for (const k of says) check(`${ru.UI_KEY}.${k}`, sayOf(f, k), ui[k])
  f.MODULE_IDS.forEach((id, i) => { for (const field of ru.MODULE_FIELDS) check(`modules.${id}.${field}`, f[MODULE_SOURCE[field]][i], modules[id]?.[field]) })
  f.LESSON_IDS.forEach((id, i) => { for (const field of ru.LESSON_FIELDS) check(`lessons.${id}.${field}`, f[LESSON_SOURCE[field]][i], lessons[id]?.[field]) })
  if (!ru.ORPHANS_ALLOWED) {
    const known = new Set(['$spec', '$note', 'locale', ru.UI_KEY, 'modules', 'lessons'])
    for (const k of Object.keys(bundle)) if (!known.has(k)) p.push(`${bundlePath}: key ${k} is not part of the course`)
    for (const k of Object.keys(ui)) if (!says.includes(k)) p.push(`${bundlePath}: ${ru.UI_KEY}.${k} names no SAY_ constant`)
    for (const [k, v] of Object.entries(modules)) {
      if (!f.MODULE_IDS.includes(k)) p.push(`${bundlePath}: modules.${k} is not a module`)
      for (const field of Object.keys(v)) if (!ru.MODULE_FIELDS.includes(field)) p.push(`${bundlePath}: modules.${k}.${field} is not a translated field`)
    }
    for (const [k, v] of Object.entries(lessons)) {
      if (!f.LESSON_IDS.includes(k)) p.push(`${bundlePath}: lessons.${k} is not a lesson`)
      for (const field of Object.keys(v)) if (!ru.LESSON_FIELDS.includes(field)) p.push(`${bundlePath}: lessons.${k}.${field} is not a translated field`)
    }
  }
  return p
}

/** What a lesson's frame shows for one gallery widget. */
const frameOf = (w, f) => ({
  id: w.id, kind: w.kind, title: w.title, url: w.url, preview: w.preview,
  height: w.kind === 'player' ? f.PLAYER_FRAME_HEIGHT : f.TOOL_FRAME_HEIGHT,
})

export function courseOf(f, ru, bundle, gallery, specSha, playerBuild) {
  const byId = new Map(gallery.widgets.map((w) => [w.id, w]))
  const say = (locale) => Object.fromEntries(sayNames(f).map((k) => [k, locale === 'en' ? sayOf(f, k) : bundle[ru.UI_KEY][k]]))
  const specFrame = (path) => (path ? {
    path, source: `t27/files/${path}`,
    preview: `play/embed.html?spec=${encodeURIComponent(path)}&tab=term${playerBuild ? `&v=${playerBuild}` : ''}`,
    height: f.PLAYER_FRAME_HEIGHT,
  } : null)
  return {
    source: { spec: COURSE_SPEC, publicSpec: PUBLIC_SPEC_OUT, ruContract: RU_SPEC, ruBundle: ru.BUNDLE_PATH, sha256: specSha, schemaVersion: f.SCHEMA_VERSION, gallery: f.GALLERY },
    route: f.ROUTE,
    cohortRoute: f.COHORT_ROUTE,
    progressKey: f.PROGRESS_KEY,
    sendsNothing: f.SENDS_NOTHING,
    locales: f.LOCALES,
    say: { en: say('en'), ru: say('ru') },
    modules: f.MODULE_IDS.map((id, i) => ({
      id, n: i + 1,
      lessons: f.LESSON_IDS.filter((_, j) => f.LESSON_MODULES[j] === id),
      en: { title: f.MODULE_TITLES[i], line: f.MODULE_LINES[i] },
      ru: { title: bundle.modules[id].TITLE, line: bundle.modules[id].LINE },
    })),
    lessons: f.LESSON_IDS.map((id, i) => ({
      id, n: i + 1, module: f.LESSON_MODULES[i],
      widget: frameOf(byId.get(f.LESSON_WIDGETS[i]), f),
      also: listOf(f.LESSON_ALSO[i]).map((a) => frameOf(byId.get(a), f)),
      spec: specFrame(f.LESSON_SPECS[i]),
      en: { title: f.LESSON_TITLES[i], goal: f.LESSON_GOALS[i], text: f.LESSON_TEXTS[i], task: f.LESSON_TASKS[i] },
      ru: { title: bundle.lessons[id].TITLE, goal: bundle.lessons[id].GOAL, text: bundle.lessons[id].TEXT, task: bundle.lessons[id].TASK },
    })),
  }
}

export const renderTs = (course) => `// GENERATED by scripts/course-from-spec.mjs from ${COURSE_SPEC} and ${course.source.ruBundle}\n// spec sha256 ${course.source.sha256}\n// Do not edit: change the .t27 source (or the Russian bundle) and regenerate.\n\nexport const COURSE = ${JSON.stringify(course, null, 2)} as const\n\nexport type Course = typeof COURSE\nexport type CourseLesson = Course['lessons'][number]\nexport type CourseFrame = CourseLesson['widget']\n`

function readSpec(name, text, analyze, required) {
  const problems = []
  const analysis = analyze(text)
  const verdict = verdictOf(analysis)
  if (!verdict.typecheckOk || verdict.discarded > 0 || !verdict.hirOk) problems.push(`${name}: compiler verdict not clean (${JSON.stringify(verdict)})`)
  problems.push(...compilerErrors(analysis).map((m) => `${name}: ${m}`))
  if (/[^\x00-\x7f]/.test(text)) problems.push(`${name}: non-ASCII byte in the spec (L3)`)
  if (CYRILLIC.test(text)) problems.push(`${name}: Cyrillic in the spec (LANG-EN); Russian belongs in the bundle`)
  let consts = {}
  try { consts = constsOf(analysis) } catch (e) { problems.push(`${name}: ${e.message}`) }
  // Page strings are SAY_<NAME> constants: any number of them, each a str.
  const says = Object.fromEntries(Object.keys(consts).filter((k) => k.startsWith('SAY_')).map((k) => [k, 'str']))
  problems.push(...checkSchema(consts, required, says, name))
  const fields = Object.fromEntries(Object.entries(consts).map(([k, v]) => [k, v.value]))
  let tests = { tests: 0, asserts: 0, failures: [] }
  if (problems.length === 0) {
    tests = runSpecTests(analysis, fields)
    if (tests.tests === 0) problems.push(`${name}: no test block; the spec must test its own invariants`)
    problems.push(...tests.failures.map((m) => `${name}: test ${m}`))
  }
  return { analysis, fields, tests, problems }
}

export async function buildCourse({ specText, ruText, bundleText, analyze, gallery, root = SITE }) {
  const course = readSpec(COURSE_SPEC, specText, analyze, REQUIRED)
  const ru = readSpec(RU_SPEC, ruText, analyze, RU_REQUIRED)
  const problems = [...course.problems, ...ru.problems]
  if (course.analysis.ast?.name !== 'course') problems.push(`${COURSE_SPEC}: module must be course`)
  if (ru.analysis.ast?.name !== 'course_ru') problems.push(`${RU_SPEC}: module must be course_ru`)
  const f = course.fields
  const r = ru.fields
  let bundle = null
  if (problems.length === 0) {
    problems.push(...semanticProblems(f))
    if (r.SOURCE_SPEC !== COURSE_SPEC) problems.push(`${RU_SPEC}: SOURCE_SPEC must be ${COURSE_SPEC}`)
    if (!f.LOCALES.includes(r.LOCALE)) problems.push(`${RU_SPEC}: LOCALE ${r.LOCALE} is not in the course's LOCALES`)
    if (!r.BUNDLE_PATH.startsWith('apps/website/')) problems.push(`${RU_SPEC}: BUNDLE_PATH must be under apps/website/`)
    try { bundle = JSON.parse(bundleText) } catch (e) { problems.push(`${r.BUNDLE_PATH}: not JSON (${e.message})`) }
    if (bundle) problems.push(...bundleProblems(f, r, bundle, r.BUNDLE_PATH))
    problems.push(...widgetProblems(f, gallery))
    problems.push(...lessonSpecProblems(f, analyze, root))
  }
  const specSha = sha256(Buffer.from(specText, 'utf8'))
  const playerBuild = gallery.widgets.find((w) => w.kind === 'player')?.preview?.match(/[?&]v=([A-Za-z0-9]+)/)?.[1] ?? ''
  const out = problems.length ? null : courseOf(f, r, bundle, gallery, specSha, playerBuild)
  return {
    problems, fields: f, specSha, course: out,
    tests: { tests: course.tests.tests + ru.tests.tests, asserts: course.tests.asserts + ru.tests.asserts },
    ts: out ? renderTs(out) : null, publicSpec: out ? specText : null,
  }
}

export async function readInputs(root = SITE) {
  const ruText = readFileSync(join(root, RU_SPEC), 'utf8')
  const bundleRel = ruText.match(/pub const BUNDLE_PATH : str = "([^"]+)";/)?.[1] ?? ''
  const bundleAt = join(root, bundleRel.replace(/^apps\/website\//, ''))
  return {
    specText: readFileSync(join(root, COURSE_SPEC), 'utf8'),
    ruText,
    bundleText: existsSync(bundleAt) ? readFileSync(bundleAt, 'utf8') : '',
    gallery: readGallery(root),
  }
}

async function main() {
  const check = process.argv.includes('--check')
  const json = process.argv.includes('--json')
  const analyze = await loadCompiler(readFileSync(join(SITE, WASM)))
  const out = await buildCourse({ ...(await readInputs()), analyze })
  if (out.problems.length) {
    console.error(`course-from-spec: ${out.problems.length} problem(s)`)
    for (const p of out.problems) console.error('  ' + p)
    process.exit(1)
  }
  if (json) { process.stdout.write(JSON.stringify(out.course, null, 2) + '\n'); return }
  const targets = [[TS_OUT, out.ts], [PUBLIC_SPEC_OUT, out.publicSpec]]
  if (check) {
    const stale = targets.filter(([rel, text]) => !existsSync(join(SITE, rel)) || readFileSync(join(SITE, rel), 'utf8') !== text)
    if (stale.length) {
      console.error(`course-from-spec --check: stale ${stale.map(([r]) => r).join(', ')}; run node scripts/course-from-spec.mjs`)
      process.exit(1)
    }
  } else {
    for (const [rel, text] of targets) {
      mkdirSync(dirname(join(SITE, rel)), { recursive: true })
      writeFileSync(join(SITE, rel), text)
    }
  }
  const c = out.course
  const widgets = new Set(c.lessons.flatMap((l) => [l.widget.id, ...l.also.map((a) => a.id)]))
  console.log(`course-from-spec: ${check ? 'up to date' : 'wrote'} ${targets.map(([r]) => r).join(', ')}; spec ${out.specSha.slice(0, 16)}; ${c.lessons.length} lessons in ${c.modules.length} modules, ${widgets.size} widgets, ${c.lessons.filter((l) => l.spec).length} lesson specs compile clean; locales ${c.locales.join(', ')}; spec tests ${out.tests.tests}, asserts ${out.tests.asserts}, all hold`)
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((e) => { console.error(e); process.exit(1) })
}
