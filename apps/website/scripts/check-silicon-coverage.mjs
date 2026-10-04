#!/usr/bin/env node
//
// Fails when a spec in the corpus names a silicon-verified format but has not
// been classified in src/data/siliconHistory.ts.
//
// Why this exists. The first version of SPEC_TO_FORMAT listed six paths. The
// corpus carries the GF ladder three times -- under specs/, chips/euler/ and
// trinity-fpga/t27/ -- so twelve specs describing formats that HAVE been
// measured on silicon rendered "No hardware run". Nothing caught it, because a
// missing entry and a deliberate omission look identical from inside the app:
// both fall through to the same empty branch. That is the wrong-denominator
// class -- a census run over specs/ while the app indexes the whole tree.
//
// So the rule is not "everything must be mapped". It is "everything must be
// DECIDED": present in SPEC_TO_FORMAT, in FAMILY_SPECS, or in EXCLUDED with a
// stated reason. A new gf-anything file added to the corpus fails the build
// until someone says which of the three it is.
//
// The tables are read by compiling the real TypeScript module and evaluating it,
// not by pattern-matching its source. A regex over source answering a question
// about behaviour is how the original defect survived review in the first place.
//
// Usage:
//   node scripts/check-silicon-coverage.mjs
//   node scripts/check-silicon-coverage.mjs --self-test   # prove it can fail

import { readFileSync, readdirSync, statSync } from 'node:fs'
import { join, relative, sep } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)
const here = fileURLToPath(new URL('.', import.meta.url))
const ROOT = join(here, '..')
const CORPUS = join(ROOT, 'public', 't27', 'files')
const TABLE_TS = join(ROOT, 'src', 'data', 'siliconHistory.ts')

/** Compile and evaluate the real module so the guard reads the real tables. */
function loadTables() {
  const esbuild = require('esbuild')
  const src = readFileSync(TABLE_TS, 'utf8')
  const { code } = esbuild.transformSync(src, { loader: 'ts', format: 'cjs' })
  const module = { exports: {} }
  // siliconHistory.ts imports nothing at runtime, so an empty require is correct
  // here -- and a loud failure if that ever stops being true.
  const fn = new Function('exports', 'module', 'require', code)
  fn(module.exports, module, (id) => {
    throw new Error(`siliconHistory.ts gained a runtime import (${id}); update this guard`)
  })
  return module.exports
}

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name)
    if (statSync(p).isDirectory()) walk(p, out)
    else if (name.endsWith('.t27')) out.push(p)
  }
  return out
}

/**
 * Does this spec name a format that has hardware results? Deliberately
 * over-inclusive: it is cheap to exclude a file with a reason, and expensive to
 * discover months later that a whole directory was never considered.
 */
const LADDER = /(^|[/_])gf(4|6|8|12|16|20|24|32)([._]|$)/i
const MODULES = /^\s*module\s+(GF(4|6|8|12|16|20|24|32)|triformat-gf\d+)\b/im

function namesAVerifiedFormat(absPath, relPath) {
  if (LADDER.test(relPath)) return true
  // Only read the file when the path is silent -- a module line can name the
  // format where the filename does not.
  const head = readFileSync(absPath, 'utf8').slice(0, 4000)
  return MODULES.test(head)
}

function main() {
  const selfTest = process.argv.includes('--self-test')
  const t = loadTables()
  const mapped = new Set(Object.keys(t.SPEC_TO_FORMAT))
  const excluded = new Set(Object.keys(t.EXCLUDED))
  const family = new Set(t.FAMILY_SPECS)

  const files = walk(CORPUS)
  const corpus = new Set(files.map((f) => relative(CORPUS, f).split(sep).join('/')))

  const undecided = []
  for (const abs of files) {
    const rel = relative(CORPUS, abs).split(sep).join('/')
    if (!namesAVerifiedFormat(abs, rel)) continue
    if (mapped.has(rel) || excluded.has(rel) || family.has(rel)) continue
    undecided.push(rel)
  }

  // The reverse direction: a table entry naming a path the corpus does not have
  // is dead weight that silently stops applying. This is the check that catches
  // a typo, and a corpus resync that moved files.
  const stale = []
  for (const [label, set] of [['SPEC_TO_FORMAT', mapped], ['EXCLUDED', excluded], ['FAMILY_SPECS', family]]) {
    for (const p of set) if (!corpus.has(p)) stale.push(`${label}: ${p}`)
  }

  // A gate that cannot fail is decoration. Inject a path the corpus does not
  // classify and require the detector to report it.
  if (selfTest) {
    const probe = 'specs/__guard_probe__/gf16.t27'
    const detected = LADDER.test(probe) && !mapped.has(probe) && !excluded.has(probe) && !family.has(probe)
    console.log(detected
      ? 'self-test: PASS — an unclassified gf16 path is detected'
      : 'self-test: FAIL — the detector would not notice a new unmapped spec')
    if (!detected) process.exit(1)
  }

  console.log(`silicon coverage: ${corpus.size} specs scanned · ` +
    `${mapped.size} mapped · ${family.size} family · ${excluded.size} excluded`)

  let bad = false
  if (undecided.length) {
    bad = true
    console.error(`\n${undecided.length} spec(s) name a verified format but are not classified.`)
    console.error('Add each to SPEC_TO_FORMAT, FAMILY_SPECS, or EXCLUDED (with a reason) ' +
      'in src/data/siliconHistory.ts:\n')
    for (const p of undecided) console.error(`  ${p}`)
  }
  if (stale.length) {
    bad = true
    console.error(`\n${stale.length} table entr(ies) name a path the corpus does not contain:\n`)
    for (const p of stale) console.error(`  ${p}`)
  }
  if (bad) process.exit(1)
  console.log('every spec naming a verified format is classified.')
}

main()
