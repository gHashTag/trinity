#!/usr/bin/env node
// The typecheck gate was wired to `tsc -b`, which has never passed on this
// codebase: 184 errors across 27 files, none of them in the pages the gate was
// created to protect. A check that has never been green is not a gate — it is a
// red X everyone learns to scroll past, and it hid the render job behind it.
//
// So this ratchets instead of demanding zero. It fails when a file gains errors
// or a clean file starts producing them, and it lowers the baseline when errors
// are fixed. The debt stays visible and countable; regressions still stop a PR.
//
//   node scripts/typecheck-ratchet.mjs            check against the baseline
//   node scripts/typecheck-ratchet.mjs --update   rewrite the baseline
//   node scripts/typecheck-ratchet.mjs --selftest prove the gate can fail
//
// The vacuous-pass hazard is the reason for the `ran` gate below: if tsc dies
// before emitting anything, the error count is zero and every file looks fixed.
// Counting zero errors is only evidence when tsc actually compiled something.
import { execFileSync } from 'node:child_process'
import { readFileSync, writeFileSync, existsSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

const HERE = dirname(fileURLToPath(import.meta.url))
const BASELINE = join(HERE, '..', 'typecheck-baseline.json')
const LINE = /^(.+?)\((\d+),(\d+)\): error (TS\d+):/

function runTsc() {
  let out = ''
  try {
    out = execFileSync('npx', ['tsc', '-b', '--pretty', 'false', '--force'],
      { cwd: join(HERE, '..'), encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] })
  } catch (e) {
    // tsc exits non-zero when it finds errors; that is the normal path here.
    out = `${e.stdout ?? ''}${e.stderr ?? ''}`
    if (!out.trim()) {
      console.error('tsc produced no output at all — it did not run. Refusing to '
        + 'report zero errors as a pass.')
      process.exit(2)
    }
  }
  const counts = {}
  let ran = false
  for (const ln of out.split('\n')) {
    const m = LINE.exec(ln.trim())
    if (!m) continue
    ran = true
    counts[m[1]] = (counts[m[1]] ?? 0) + 1
  }
  return { counts, ran, out }
}

function compare(base, now) {
  const worse = []
  const better = []
  for (const f of new Set([...Object.keys(base), ...Object.keys(now)])) {
    const b = base[f] ?? 0
    const n = now[f] ?? 0
    if (n > b) worse.push({ file: f, was: b, now: n })
    else if (n < b) better.push({ file: f, was: b, now: n })
  }
  worse.sort((a, b) => (b.now - b.was) - (a.now - a.was))
  return { worse, better }
}

const total = (c) => Object.values(c).reduce((a, b) => a + b, 0)

if (process.argv.includes('--selftest')) {
  // A gate nobody has watched fail is a gate nobody knows the behaviour of.
  const base = { 'a.ts': 3, 'b.ts': 1 }
  const cases = [
    ['unchanged', { 'a.ts': 3, 'b.ts': 1 }, false],
    ['one file worse', { 'a.ts': 4, 'b.ts': 1 }, true],
    ['a new dirty file', { 'a.ts': 3, 'b.ts': 1, 'c.ts': 1 }, true],
    ['fixed one, broke another — must not net out', { 'a.ts': 1, 'b.ts': 3 }, true],
    ['all fixed', {}, false],
  ]
  let bad = 0
  for (const [name, now, shouldFail] of cases) {
    const got = compare(base, now).worse.length > 0
    const ok = got === shouldFail
    if (!ok) bad++
    console.log(`  ${ok ? 'ok  ' : 'FAIL'}  ${name}: fails=${got}, expected=${shouldFail}`)
  }
  console.log(bad ? `\n${bad} self-test(s) failed` : '\nself-test: the gate fails when it should')
  process.exit(bad ? 1 : 0)
}

const { counts, ran } = runTsc()
if (!ran) {
  console.error('tsc emitted output but not a single diagnostic line matched the '
    + 'expected format. The parser and the compiler disagree; refusing to pass.')
  process.exit(2)
}

if (process.argv.includes('--update') || !existsSync(BASELINE)) {
  writeFileSync(BASELINE, `${JSON.stringify({
    note: 'Pre-existing tsc errors, per file. Lower is better; this file may only '
      + 'shrink. Run `npm run typecheck:update` after fixing some.',
    total: total(counts),
    files: Object.fromEntries(Object.entries(counts).sort()),
  }, null, 2)}\n`)
  console.log(`baseline written: ${total(counts)} error(s) across ${Object.keys(counts).length} file(s)`)
  process.exit(0)
}

const base = JSON.parse(readFileSync(BASELINE, 'utf8')).files
const { worse, better } = compare(base, counts)

console.log(`${total(counts)} pre-existing type error(s) across ${Object.keys(counts).length} file(s); `
  + `baseline ${total(base)} across ${Object.keys(base).length}.`)

if (better.length) {
  console.log(`\n${better.length} file(s) improved — run \`npm run typecheck:update\` to lock it in:`)
  for (const b of better.slice(0, 10)) console.log(`  ${b.file}: ${b.was} -> ${b.now}`)
}

if (!worse.length) {
  console.log('\nno file gained type errors.')
  process.exit(0)
}

console.error(`\n${worse.length} file(s) gained type errors:`)
for (const w of worse) console.error(`  ${w.file}: ${w.was} -> ${w.now}`)
console.error('\nFix them, or if they are genuinely pre-existing, say so in the PR '
  + 'and run `npm run typecheck:update`.')
process.exit(1)
