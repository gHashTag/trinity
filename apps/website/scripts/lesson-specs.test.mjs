// The world scan keeps what a course teaches from (scripts/lesson-specs.mjs).
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { existsSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { lessonSpecsOf, lessonSpecPaths } from './lesson-specs.mjs'

const WEBSITE = join(dirname(fileURLToPath(import.meta.url)), '..')

test('a course spec names its lesson specs in order', () => {
  const text = [
    'pub const LESSON_IDS : [2]str = ["a", "b"];',
    'pub const LESSON_SPECS : [2]str = [',
    '    "specs/basics/01_x.t27",',
    '    "specs/fpga/uart.t27",',
    '];',
  ].join('\n')
  assert.deepEqual(lessonSpecsOf(text), ['specs/basics/01_x.t27', 'specs/fpga/uart.t27'])
})

test('a spec without LESSON_SPECS names nothing', () => {
  assert.deepEqual(lessonSpecsOf('pub const LESSON_IDS : [1]str = ["a"];'), [])
})

test('every course on the site is read, and every lesson spec is on disk', () => {
  const paths = lessonSpecPaths(join(WEBSITE, 'specs/course'))
  // Seven courses of 27 lessons share specs: 146 distinct paths on 2026-10-08.
  assert.ok(paths.length >= 140, `only ${paths.length} lesson specs found`)
  for (const p of ['specs/basics/01_what_a_spec_is.t27', 'specs/fpga/mmcm.t27', 'specs/fpga/uart.t27'])
    assert.ok(paths.includes(p), `${p} is not a lesson spec`)
  const missing = paths.filter((p) => !existsSync(join(WEBSITE, 'public/t27/files', p)))
  assert.deepEqual(missing, [])
})

test('the scan carries the lesson specs across its wipe and lets them win', async () => {
  const { readFileSync } = await import('node:fs')
  const sync = readFileSync(join(WEBSITE, 'scripts/sync-t27-specs.mjs'), 'utf8')
  const read = sync.indexOf('lessonSpecPaths(')
  const wipe = sync.indexOf('rmSync(SPECS_OUT,')
  const write = sync.indexOf('writeFileSync(dest, text)')
  const pin = sync.indexOf('for (const [rel, text] of pinned)')
  assert.ok(read > -1 && read < wipe, 'the lesson specs are read before the wipe')
  assert.ok(pin > write, 'the course copy is written after the scan, so it wins')
})
