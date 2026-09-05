#!/usr/bin/env node
// Vendor the t27 spec corpus and the compiler wasm bridge into public/.
//
// The explorer page runs the REAL compiler in the browser, so the two things it
// needs are the spec sources and the wasm build of `bootstrap/src/compiler.rs`.
// Both are copied here rather than fetched at runtime: the page then works
// offline, deterministically, with no dependency on GitHub availability or
// rate limits.
//
// The cost of vendoring is drift, so the manifest records the exact t27 commit
// the snapshot came from and the page displays it. Re-run this script to
// refresh:
//
//   node scripts/sync-t27-specs.mjs
//
// Requires the wasm bridge to be built first:
//   cd /Users/playom/t27/bindings/wasm-explorer
//   cargo build --target wasm32-unknown-unknown --release

import { readFileSync, writeFileSync, mkdirSync, rmSync, cpSync, existsSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { join, relative, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = dirname(fileURLToPath(import.meta.url))
const WEBSITE = join(HERE, '..')
const T27 = process.env.T27_ROOT || '/Users/playom/t27'
const SPECS_SRC = join(T27, 'specs')
const WASM_SRC = join(T27, 'bindings/wasm-explorer/target/wasm32-unknown-unknown/release/t27_wasm_explorer.wasm')

const OUT_DIR = join(WEBSITE, 'public/t27')
const SPECS_OUT = join(OUT_DIR, 'specs')

function fail(msg) {
  console.error(`sync-t27-specs: ${msg}`)
  process.exit(1)
}

if (!existsSync(SPECS_SRC)) fail(`spec corpus not found at ${SPECS_SRC} (set T27_ROOT)`)
if (!existsSync(WASM_SRC)) fail(`wasm bridge not built.\n  cd ${T27}/bindings/wasm-explorer\n  cargo build --target wasm32-unknown-unknown --release`)

const sha = execFileSync('git', ['-C', T27, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim()
const shortSha = sha.slice(0, 9)
const dirty = execFileSync('git', ['-C', T27, 'status', '--porcelain', '--', 'specs', 'bootstrap/src/compiler.rs'], { encoding: 'utf8' }).trim()

// Walk without a dependency -- `find` is already required by nothing else here.
const files = execFileSync('find', [SPECS_SRC, '-name', '*.t27', '-type', 'f'], { encoding: 'utf8' })
  .split('\n').filter(Boolean).sort()

if (!files.length) fail('no .t27 files found')

rmSync(OUT_DIR, { recursive: true, force: true })
mkdirSync(SPECS_OUT, { recursive: true })

const entries = []
for (const abs of files) {
  const rel = relative(SPECS_SRC, abs)
  const text = readFileSync(abs, 'utf8')
  const dest = join(SPECS_OUT, rel)
  mkdirSync(dirname(dest), { recursive: true })
  writeFileSync(dest, text)

  const parts = rel.split('/')
  // A spec's `module X {` line is a better label than its filename when the two
  // disagree, which they often do.
  const moduleMatch = text.match(/^\s*module\s+([A-Za-z0-9_]+)/m)
  entries.push({
    path: rel,
    category: parts.length > 1 ? parts[0] : 'root',
    name: parts[parts.length - 1].replace(/\.t27$/, ''),
    module: moduleMatch ? moduleMatch[1] : null,
    lines: text.split('\n').length,
    bytes: Buffer.byteLength(text, 'utf8'),
  })
}

cpSync(WASM_SRC, join(OUT_DIR, 't27_compiler.wasm'))
const wasmBytes = readFileSync(WASM_SRC).length

const byCategory = {}
for (const e of entries) byCategory[e.category] = (byCategory[e.category] || 0) + 1

writeFileSync(join(OUT_DIR, 'manifest.json'), JSON.stringify({
  generatedFrom: {
    repo: 'gHashTag/t27',
    commit: sha,
    shortCommit: shortSha,
    specsOrCompilerDirty: dirty.length > 0,
  },
  wasmBytes,
  specCount: entries.length,
  totalLines: entries.reduce((a, e) => a + e.lines, 0),
  categories: Object.fromEntries(Object.entries(byCategory).sort((a, b) => b[1] - a[1])),
  specs: entries,
}, null, 0))

console.log(`sync-t27-specs: ${entries.length} specs, ${Object.keys(byCategory).length} categories`)
console.log(`  t27 @ ${shortSha}${dirty ? ' (DIRTY -- snapshot includes uncommitted spec/compiler changes)' : ''}`)
console.log(`  wasm ${(wasmBytes / 1024).toFixed(0)} KB -> public/t27/t27_compiler.wasm`)
if (dirty) console.log(`  warning: commit t27 before shipping, or the recorded SHA understates the snapshot`)
