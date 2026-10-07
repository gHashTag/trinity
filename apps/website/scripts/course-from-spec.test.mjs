import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { SITE, loadCompiler } from './agents-from-specs.mjs'
import { TS_OUT, buildCourses, digitsOf, publicSpecOf, readInputs } from './course-from-spec.mjs'

const analyze = await loadCompiler(readFileSync(join(SITE, 'public/t27/t27_compiler.wasm')))
const inputs = await readInputs()
const build = (over = {}) => buildCourses({ ...inputs, analyze, ...over })
/** The inputs with course i's files changed: { specText?, ruText?, bundleText? }. */
const withCourse = (i, change) => ({ courses: inputs.courses.map((c, j) => (j === i ? { ...c, ...change(c) } : c)) })
const fails = async (over, needle) => {
  const out = await build(over)
  assert.ok(out.problems.some((p) => p.includes(needle)), `expected a problem naming ${needle}, got:\n${out.problems.join('\n')}`)
  assert.equal(out.ts, null)
}
const replaced = (text, from, to) => {
  assert.ok(text.includes(from), `the mutation target is gone: ${from}`)
  return text.replace(from, to)
}
const spec = (i, from, to) => withCourse(i, (c) => ({ specText: replaced(c.specText, from, to) }))
const bundle = (i) => JSON.parse(inputs.courses[i].bundleText)
const withBundle = (i, b) => withCourse(i, () => ({ bundleText: JSON.stringify(b) }))

test('the committed specs build clean and the derived files are current', async () => {
  const out = await build()
  assert.deepEqual(out.problems, [])
  assert.equal(readFileSync(join(SITE, TS_OUT), 'utf8'), out.ts)
  for (const [rel, text] of out.publicSpecs) assert.equal(readFileSync(join(SITE, rel), 'utf8'), text)
  for (const c of out.courses) assert.equal(c.sendsNothing, true)
})

test('every course is 27 modules of one lesson each, with its own address and share path', async () => {
  const out = await build()
  assert.ok(out.courses.length >= 2)
  for (const c of out.courses) {
    assert.equal(c.lessons.length, 27, c.id)
    assert.equal(c.modules.length, 27, c.id)
    for (const m of c.modules) assert.deepEqual(m.lessons, [m.id], `${c.id} ${m.id}`)
  }
  assert.equal(out.courses[0].share, 'learn/')
  for (const c of out.courses.slice(1)) assert.equal(c.share, `learn/${c.id}/`)
  assert.equal(new Set(out.courses.map((c) => c.route)).size, out.courses.length)
  assert.deepEqual(out.publicSpecs.map(([rel]) => rel), out.courses.map((c) => publicSpecOf(c.id)))
})

test('the courses are chained: the last lesson of one leads to lesson 1 of the next', async () => {
  const out = await build()
  out.courses.forEach((c, i) => {
    const prev = out.courses[i - 1]
    const next = out.courses[i + 1]
    assert.equal(c.prev?.id ?? null, prev?.id ?? null)
    assert.equal(c.next?.id ?? null, next?.id ?? null)
    if (next) {
      assert.equal(c.next.first, next.lessons[0].id)
      assert.equal(c.next.route, next.route)
      assert.equal(c.next.title.en, next.say.en.TITLE)
    }
    if (prev) assert.equal(c.prev.last, prev.lessons.at(-1).id)
  })
})

test('every lesson opens its own widget and a spec, and the gallery is covered', async () => {
  const out = await build()
  const lessons = out.courses.flatMap((c) => c.lessons)
  const main = lessons.map((l) => l.widget.id)
  assert.equal(new Set(main).size, main.length)
  const used = new Set(lessons.flatMap((l) => [l.widget.id, ...l.also.map((a) => a.id)]))
  for (const w of inputs.gallery.widgets) assert.ok(used.has(w.id), `${w.id} is used`)
  for (const l of lessons) {
    assert.ok(l.widget.preview, `${l.id} frames a page`)
    assert.ok(l.spec?.path, `${l.id} shows a spec`)
  }
})

test('a lesson that opens a widget the gallery lacks fails the build', async () => {
  await fails(spec(1, '"fasm-skyline", "idcode"', '"no-such-widget", "idcode"'), 'no-such-widget')
})

test('a gallery widget left out of every lesson fails the build', async () => {
  await fails(spec(1, '"race-the-bee,wars,tri-game-tick,tri-game-vault"', '"wars,tri-game-tick,tri-game-vault"'), 'race-the-bee is in no lesson')
})

test('two lessons opening the same widget fail the build, inside a course or across two', async () => {
  await fails(spec(1, '"fasm-skyline", "idcode"', '"idcode", "idcode"'), 'LESSON_WIDGETS must be unique')
  await fails(spec(2, '"t27-vs-nvfp4", "uart-bucket"', '"idcode", "uart-bucket"'), 'LESSON_WIDGETS must be unique')
})

test('a lesson with no spec fails the build', async () => {
  await fails(spec(1, '"specs/tutorial/04_control_flow.t27"', '""'), 'names no spec')
})

test('a lesson spec that does not compile clean fails the build', async () => {
  await fails(spec(1, '"specs/tutorial/04_control_flow.t27"', '"specs/no/such.t27"'), 'specs/no/such.t27')
})

test('a course that is not 27 lessons fails the build', async () => {
  await fails({ catalogText: replaced(inputs.catalogText, 'pub const LESSONS_PER_MODULE : u8 = 1;', 'pub const LESSONS_PER_MODULE : u8 = 3;') }, 'test')
  await fails(spec(1, 'pub const LESSON_COUNT : u8 = 27;', 'pub const LESSON_COUNT : u8 = 26;'), 'the_course_is_three_cubed')
})

test('a course whose share path breaks the rule fails the build', async () => {
  await fails(spec(2, 'pub const SHARE_PATH : str = "learn/ai-numbers/";', 'pub const SHARE_PATH : str = "learn/";'), 'SHARE_PATH must be learn/ai-numbers/')
})

test('a lesson in two courses fails the build: its page can show one', async () => {
  // Lesson 2 of each course: no spec test names it. Each lesson is its own module, so its id
  // appears in MODULE_IDS, LESSON_MODULES and LESSON_IDS; every copy moves together.
  const first = JSON.parse(inputs.courses[0].specText.match(/pub const LESSON_IDS : \[\d+\]str = (\[[^\]]*\]);/)[1])[1]
  const second = JSON.parse(inputs.courses[1].specText.match(/pub const LESSON_IDS : \[\d+\]str = (\[[^\]]*\]);/)[1])[1]
  const b = bundle(1)
  for (const part of ['modules', 'lessons']) {
    b[part][first] = b[part][second]
    delete b[part][second]
  }
  const moved = withCourse(1, (c) => ({ specText: c.specText.split(`"${second}"`).join(`"${first}"`), bundleText: JSON.stringify(b) }))
  await fails(moved, `lesson ${first} is in two courses`)
})

test('a course left out of the catalog fails the build', async () => {
  await fails({ catalogText: replaced(inputs.catalogText, 'pub const COURSE_COUNT : u8 = 4;', 'pub const COURSE_COUNT : u8 = 5;') }, 'the_basics_come_first')
})

test('a broken claim in a spec fails its own test block', async () => {
  await fails(spec(0, 'pub const LESSONS_PER_MODULE : u8 = 1;', 'pub const LESSONS_PER_MODULE : u8 = 3;'), 'test')
})

test('a superlative in English fails the build', async () => {
  await fails(spec(1, 'An FPGA is a grid you configure', 'The best FPGA is a grid you configure'), 'superlative')
})

test('Cyrillic in a spec fails the build; Russian lives in the bundle', async () => {
  await fails(spec(2, 'pub const SAY_KICKER : str = "Course";', 'pub const SAY_KICKER : str = "Курс";'), 'Cyrillic')
})

test('a Russian field that changes a number fails the build', async () => {
  const b = bundle(1)
  b.lessons['seven-backends-and-t27b'].TEXT = replaced(b.lessons['seven-backends-and-t27b'].TEXT, '307', '308')
  await fails(withBundle(1, b), 'lessons.seven-backends-and-t27b.TEXT numbers')
})

test('a Russian field that drops a placeholder fails the build', async () => {
  const b = bundle(1)
  b.ui.PROGRESS = replaced(b.ui.PROGRESS, '{1}', 'N')
  await fails(withBundle(1, b), 'ui.PROGRESS')
})

test('a missing Russian field fails the build (COVERAGE_REQUIRED)', async () => {
  const b = bundle(1)
  const id = Object.keys(b.lessons)[0]
  delete b.lessons[id].TASK
  await fails(withBundle(1, b), `lessons.${id}.TASK is missing`)
})

test('a Russian key the course does not have fails the build (ORPHANS_ALLOWED false)', async () => {
  const b = bundle(0)
  b.lessons['no-such-lesson'] = { TITLE: 'Урок' }
  await fails(withBundle(0, b), 'lessons.no-such-lesson is not a lesson')
})

test('a Russian superlative fails the build', async () => {
  const b = bundle(0)
  b.modules[Object.keys(b.modules)[1]].TITLE = 'Лучший чип'
  await fails(withBundle(0, b), 'superlative')
})

test('digitsOf reads a number once, whatever its separators', () => {
  assert.deepEqual(digitsOf('68.4% of 1,234 and 7'), ['1234', '684', '7'])
})
