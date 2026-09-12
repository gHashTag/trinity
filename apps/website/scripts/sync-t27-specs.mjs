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

import { readFileSync, writeFileSync, mkdirSync, rmSync, cpSync, existsSync, mkdtempSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { join, relative, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { tmpdir } from 'node:os'
import { createHash } from 'node:crypto'
// One entry, one tag, one summary, one aggregate: the same code whichever writer runs.
// scripts/discover-t27-worlds.mjs adds the repositories a GitHub scan finds through the
// same functions, so a spec means the same thing however it reached the catalog.
import { corpusEntry, corpusAggregates, registerDescriptionExceptions } from './t27-corpus.mjs'

const HERE = dirname(fileURLToPath(import.meta.url))
const WEBSITE = join(HERE, '..')
const T27 = process.env.T27_ROOT || '/Users/playom/t27'
const SPECS_SRC = join(T27, 'specs')
const WASM_SRC = join(T27, 'bindings/wasm-explorer/target/wasm32-unknown-unknown/release/t27_wasm_explorer.wasm')

const OUT_DIR = join(WEBSITE, 'public/t27')
// `files/`, not `specs/`: paths inside are repo-root-relative now, so a spec
// from specs/demos/ would otherwise land at specs/specs/demos/.
const SPECS_OUT = join(OUT_DIR, 'files')

function fail(msg) {
  console.error(`sync-t27-specs: ${msg}`)
  process.exit(1)
}

if (!existsSync(SPECS_SRC)) fail(`spec corpus not found at ${SPECS_SRC} (set T27_ROOT)`)
if (!existsSync(WASM_SRC)) fail(`wasm bridge not built.\n  cd ${T27}/bindings/wasm-explorer\n  cargo build --target wasm32-unknown-unknown --release`)

const sha = execFileSync('git', ['-C', T27, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim()
const shortSha = sha.slice(0, 9)
const dirty = execFileSync('git', ['-C', T27, 'status', '--porcelain', '--', 'specs', 'chips', 'compiler', 'bootstrap/src/compiler.rs'], { encoding: 'utf8' }).trim()

// Every .t27 in the repo, not just specs/ -- `chips/` alone holds ~147 real
// specs, and a corpus that quietly stops at specs/ cannot show a problem living
// outside it. Two exclusions, both duplicates rather than judgement calls:
//   .git/     -- object store
//   .claude/  -- git worktrees, i.e. second checkouts of files already counted
//                (the same compiler/ast.t27 appears in every worktree)
const localFiles = execFileSync('find', [
  T27, '-name', '*.t27', '-type', 'f',
  '-not', '-path', `${T27}/.git/*`,
  '-not', '-path', `${T27}/.claude/*`,
], { encoding: 'utf8' }).split('\n').filter(Boolean).sort()

if (!localFiles.length) fail('no .t27 files found')

// ---------------------------------------------------------------------------
// Other repositories
//
// The corpus is spread across several repos. They are pulled as tarballs
// rather than cloned: one request each, no working copies to keep in sync, and
// nothing writable left behind.
//
// `chips/{euler,gamma,phi}` inside t27 are byte-identical to the
// tt-trinity-{euler,gamma,phi} repos (verified by blob SHA), so content-hash
// dedup below keeps them from appearing twice. A knowledge library full of
// duplicates is worse than a smaller honest one.
// ---------------------------------------------------------------------------
const EXTRA_REPOS = (process.env.T27_SKIP_REMOTE ? [] : [
  'tri-net',
  'trinity-fpga',
  'trinity',
  'tt-trinity-corona',
])

const sources = [{ repo: 't27', root: T27, files: localFiles, commit: null }]

for (const repo of EXTRA_REPOS) {
  let branch
  try {
    branch = execFileSync('gh', ['api', `repos/gHashTag/${repo}`, '--jq', '.default_branch'], { encoding: 'utf8' }).trim()
  } catch {
    console.log(`  warning: ${repo} unreachable, skipped`)
    continue
  }
  const sha = execFileSync('gh', ['api', `repos/gHashTag/${repo}/commits/${branch}`, '--jq', '.sha'], { encoding: 'utf8' }).trim()
  const dir = mkdtempSync(join(tmpdir(), `t27-${repo}-`))
  try {
    execFileSync('sh', ['-c',
      `gh api "repos/gHashTag/${repo}/tarball/${branch}" > "${dir}/a.tar.gz" && tar -xzf "${dir}/a.tar.gz" -C "${dir}"`,
    ], { stdio: 'ignore' })
  } catch {
    console.log(`  warning: ${repo} tarball failed, skipped`)
    continue
  }
  const inner = execFileSync('sh', ['-c', `ls -d "${dir}"/*/ | head -1`], { encoding: 'utf8' }).trim()
  const found = execFileSync('find', [inner, '-name', '*.t27', '-type', 'f'], { encoding: 'utf8' })
    .split('\n').filter(Boolean).sort()
  sources.push({ repo, root: inner.replace(/\/$/, ''), files: found, commit: sha, tmp: dir })
}

rmSync(OUT_DIR, { recursive: true, force: true })
mkdirSync(SPECS_OUT, { recursive: true })

// Run the same wasm the browser runs, here, over the whole corpus. Health has
// to be known before a row is drawn -- the alternative is compiling 667 specs
// in the browser just to colour a list, which would take minutes.
const wasmBuf = readFileSync(WASM_SRC)
const { instance: wasmInst } = await WebAssembly.instantiate(wasmBuf, {})
const { memory, t27_alloc, t27_free, t27_analyze } = wasmInst.exports

function analyze(src) {
  const b = Buffer.from(src, 'utf8')
  const p = t27_alloc(b.length)
  new Uint8Array(memory.buffer, p, b.length).set(b)
  const o = t27_analyze(p, b.length)
  const n = new DataView(memory.buffer).getUint32(o, true)
  const json = Buffer.from(new Uint8Array(memory.buffer, o + 4, n)).toString('utf8')
  t27_free(o, 4 + n)
  return JSON.parse(json)
}

// describe(), deriveTags(), summarise() and the domain table live in scripts/t27-corpus.mjs.

const entries = []
const seenContent = new Map() // content hash -> path already kept
let duplicates = 0

for (const src of sources) {
for (const abs of src.files) {
  // Namespaced by repo, then the path inside it, so a spec's real home stays
  // visible instead of being flattened into one bucket.
  const inRepo = relative(src.root, abs)
  const rel = src.repo === 't27' ? inRepo : `${src.repo}/${inRepo}`
  const text = readFileSync(abs, 'utf8')

  // Same bytes as something already taken? Skip it. t27 vendors three whole
  // chip repos, so without this the library would carry 147 phantom entries.
  const hash = createHash('sha256').update(text).digest('hex')
  const already = seenContent.get(hash)
  if (already) { duplicates++; continue }
  seenContent.set(hash, rel)

  const dest = join(SPECS_OUT, rel)
  mkdirSync(dirname(dest), { recursive: true })
  writeFileSync(dest, text)

  entries.push(corpusEntry(rel, src.repo, text, analyze))
}
}

// Tarballs were extracted to temp dirs; nothing should outlive this run.
for (const s of sources) if (s.tmp) rmSync(s.tmp, { recursive: true, force: true })

// Spec descriptions are comments quoted verbatim out of the source files, in the language
// their authors wrote them in; qa/ru_audit.mjs must not flag them as untranslated UI. The
// exception list is generated, never hand-maintained (see t27-corpus.mjs).
const registered = registerDescriptionExceptions(entries, join(WEBSITE, 'qa/language-exceptions.json'))
if (registered !== null) console.log(`  qa exceptions: ${registered} spec descriptions registered for the RU audit`)

cpSync(WASM_SRC, join(OUT_DIR, 't27_compiler.wasm'))
const wasmBytes = readFileSync(WASM_SRC).length

// The course comes first, in reading order, and the page opens on its first
// lesson. Everything else keeps its path order behind them.
//
// `hello_world` sits at the head as the five-minute overview; the numbered
// lessons then take each construct in turn. Sorting is by filename, which is
// why they are numbered rather than named.
const FEATURED = 'specs/demos/hello_world.t27'
const tutorial = entries
  .filter((e) => e.path.startsWith('specs/tutorial/') || e.path === FEATURED)
  .sort((a, b) => (a.path === FEATURED ? -1 : b.path === FEATURED ? 1 : a.path.localeCompare(b.path)))
const rest = entries.filter((e) => !tutorial.includes(e))

tutorial.forEach((e, i) => {
  e.tutorial = true
  e.lesson = i // 0 = hello_world, then 1..N in reading order
})
if (tutorial.length) tutorial[0].featured = true
else console.log(`  warning: no tutorial specs found -- page will open on the first entry`)

entries.length = 0
entries.push(...tutorial, ...rest)

const { totalLines, categories, tags, health, backendFailures, totals } = corpusAggregates(entries)

// ---------------------------------------------------------------------------
// Which vendored specs could someone else actually reproduce?
//
// t27 is the one source pulled from a LOCAL WORKING COPY rather than a tarball
// of a committed ref, so whatever is on this machine ships. `specsOrCompilerDirty`
// already says "something was uncommitted", which is true and not actionable:
// it does not say WHAT, and a boolean cannot be diffed between syncs.
//
// The concrete hazard is not hypothetical. Every spec of the teaching Course --
// hello_world plus the eight tutorial lessons -- lives on an unmerged t27 branch
// and not on master. Re-vendoring "from master" to pick up a compiler fix would
// therefore DELETE the entire onboarding path from the site, silently, and the
// manifest as it stood would have reported nothing but a flipped boolean.
//
// Submodules are not counted: `chips/{euler,gamma,phi}` are separate
// repositories, and asking the superproject's history about their paths returns
// "no commit" for files that are perfectly well committed elsewhere. That
// mistake produced a 46-file false alarm before this was written.
const DEFAULT_REF = process.env.T27_DEFAULT_REF || 'origin/master'
let submodulePaths = []
try {
  submodulePaths = execFileSync('git', ['-C', T27, 'config', '-f', '.gitmodules', '--get-regexp', 'path'], { encoding: 'utf8' })
    .split('\n').filter(Boolean).map((line) => line.trim().split(/\s+/)[1]).filter(Boolean)
} catch {
  // No .gitmodules is a valid state, not an error.
}
const ownedByASubmodule = (rel) => submodulePaths.some((s) => rel === s || rel.startsWith(`${s}/`))

const unreachable = []
let reachableChecked = 0
for (const e of entries) {
  if (e.repo !== 't27') continue          // other repos ship a committed tarball sha
  if (ownedByASubmodule(e.path)) continue // committed in its own repository
  reachableChecked += 1
  try {
    execFileSync('git', ['-C', T27, 'cat-file', '-e', `${DEFAULT_REF}:${e.path}`], { stdio: 'ignore' })
  } catch {
    unreachable.push(e.path)
  }
}
unreachable.sort()
if (unreachable.length) {
  console.log(`  note: ${unreachable.length} of ${reachableChecked} t27 specs are not on ${DEFAULT_REF};`)
  console.log('        a re-vendor from that ref alone would drop them. First few:')
  for (const p of unreachable.slice(0, 5)) console.log(`          ${p}`)
}

writeFileSync(join(OUT_DIR, 'manifest.json'), JSON.stringify({
  generatedFrom: {
    repo: 'gHashTag/t27',
    commit: sha,
    shortCommit: shortSha,
    specsOrCompilerDirty: dirty.length > 0,
    // Named, not counted: a list can be diffed between two syncs and a number
    // cannot. Submodule-owned paths are excluded rather than silently passing.
    defaultRef: DEFAULT_REF,
    t27SpecsChecked: reachableChecked,
    unreachableFromDefaultRef: unreachable,
  },
  wasmBytes,
  specCount: entries.length,
  totalLines,
  categories,
  repos: sources.map((s) => ({ repo: s.repo, commit: s.commit ?? sha, specs: entries.filter((e) => e.repo === s.repo).length })),
  duplicatesSkipped: duplicates,
  tags,
  health,
  backendFailures,
  featured: FEATURED,
  totals,
  specs: entries,
}, null, 0))

console.log(`sync-t27-specs: ${entries.length} specs, ${Object.keys(categories).length} categories`)
console.log(`  sources: ${sources.map((s) => s.repo).join(', ')}  (${duplicates} duplicate files skipped by content hash)`)
console.log(`  health: ${health.ok} ok · ${health.warn} warn · ${health.fail} fail`)
if (Object.keys(backendFailures).length) console.log(`  backend failures: ${JSON.stringify(backendFailures)}`)
console.log(`  t27 @ ${shortSha}${dirty ? ' (DIRTY -- snapshot includes uncommitted spec/compiler changes)' : ''}`)
console.log(`  wasm ${(wasmBytes / 1024).toFixed(0)} KB -> public/t27/t27_compiler.wasm`)
if (dirty) console.log(`  warning: commit t27 before shipping, or the recorded SHA understates the snapshot`)
