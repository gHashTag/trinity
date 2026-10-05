import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { SITE, loadCompiler } from './agents-from-specs.mjs'
import { PUBLIC_SPEC_OUT, TS_OUT, buildCourse, digitsOf, readInputs } from './course-from-spec.mjs'

const analyze = await loadCompiler(readFileSync(join(SITE, 'public/t27/t27_compiler.wasm')))
const inputs = await readInputs()
const build = (over = {}) => buildCourse({ ...inputs, analyze, ...over })
const fails = async (over, needle) => {
  const out = await build(over)
  assert.ok(out.problems.some((p) => p.includes(needle)), `expected a problem naming ${needle}, got:\n${out.problems.join('\n')}`)
  assert.equal(out.ts, null)
}
const bundle = () => JSON.parse(inputs.bundleText)

test('the committed spec builds clean and the derived files are current', async () => {
  const out = await build()
  assert.deepEqual(out.problems, [])
  assert.equal(readFileSync(join(SITE, TS_OUT), 'utf8'), out.ts)
  assert.equal(readFileSync(join(SITE, PUBLIC_SPEC_OUT), 'utf8'), inputs.specText)
  assert.equal(out.course.lessons.length, 27)
  assert.equal(out.course.modules.length, 9)
  assert.equal(out.course.sendsNothing, true)
})

test('every gallery widget is in the course, and every lesson opens its own', async () => {
  const out = await build()
  const main = out.course.lessons.map((l) => l.widget.id)
  assert.equal(new Set(main).size, main.length)
  const used = new Set(out.course.lessons.flatMap((l) => [l.widget.id, ...l.also.map((a) => a.id)]))
  for (const w of inputs.gallery.widgets) assert.ok(used.has(w.id), `${w.id} is used`)
  for (const l of out.course.lessons) assert.ok(l.widget.preview, `${l.id} frames a page`)
})

test('a lesson that opens a widget the gallery lacks fails the build', async () => {
  await fails({ specText: inputs.specText.replace('"fasm-skyline", "idcode"', '"no-such-widget", "idcode"') }, 'no-such-widget')
})

test('a gallery widget left out of every lesson fails the build', async () => {
  await fails({ specText: inputs.specText.replace('"race-the-bee,wars,tri-game-tick,tri-game-vault"', '"wars,tri-game-tick,tri-game-vault"') }, 'race-the-bee is in no lesson')
})

test('two lessons opening the same widget fail the build', async () => {
  await fails({ specText: inputs.specText.replace('"fasm-skyline", "idcode"', '"idcode", "idcode"') }, 'LESSON_WIDGETS must be unique')
})

test('a lesson spec that does not compile clean fails the build', async () => {
  await fails({ specText: inputs.specText.replace('"specs/tutorial/04_control_flow.t27"', '"specs/no/such.t27"') }, 'specs/no/such.t27')
})

test('a broken claim in the spec fails its own test block', async () => {
  await fails({ specText: inputs.specText.replace('pub const LESSONS_PER_MODULE : u8 = 3;', 'pub const LESSONS_PER_MODULE : u8 = 4;') }, 'test')
})

test('a superlative in English fails the build', async () => {
  await fails({ specText: inputs.specText.replace('An FPGA is a grid you configure', 'The best FPGA is a grid you configure') }, 'superlative')
})

test('Cyrillic in the spec fails the build; Russian lives in the bundle', async () => {
  await fails({ specText: inputs.specText.replace('pub const SAY_KICKER : str = "Course";', 'pub const SAY_KICKER : str = "Курс";') }, 'Cyrillic')
})

test('a Russian field that changes a number fails the build', async () => {
  const b = bundle()
  b.lessons['seven-backends-and-t27b'].TEXT = b.lessons['seven-backends-and-t27b'].TEXT.replace('307', '308')
  await fails({ bundleText: JSON.stringify(b) }, 'lessons.seven-backends-and-t27b.TEXT numbers')
})

test('a Russian field that drops a placeholder fails the build', async () => {
  const b = bundle()
  b.ui.PROGRESS = b.ui.PROGRESS.replace('{1}', 'N')
  await fails({ bundleText: JSON.stringify(b) }, 'ui.PROGRESS')
})

test('a missing Russian field fails the build (COVERAGE_REQUIRED)', async () => {
  const b = bundle()
  delete b.lessons.capstone.TASK
  await fails({ bundleText: JSON.stringify(b) }, 'lessons.capstone.TASK is missing')
})

test('a Russian key the course does not have fails the build (ORPHANS_ALLOWED false)', async () => {
  const b = bundle()
  b.lessons['no-such-lesson'] = { TITLE: 'Урок' }
  await fails({ bundleText: JSON.stringify(b) }, 'lessons.no-such-lesson is not a lesson')
})

test('a Russian superlative fails the build', async () => {
  const b = bundle()
  b.modules.chip.TITLE = 'Лучший чип'
  await fails({ bundleText: JSON.stringify(b) }, 'superlative')
})

test('digitsOf reads a number once, whatever its separators', () => {
  assert.deepEqual(digitsOf('68.4% of 1,234 and 7'), ['1234', '684', '7'])
})
