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

/**
 * A spec's own header comments, as its description.
 *
 * Specs open with either `//` or `;` comment lines. SPDX, decorative rules and
 * the φ banner are dropped -- they are boilerplate on nearly every file and say
 * nothing about the individual spec.
 */
function describe(text) {
  const out = []
  for (const raw of text.split('\n')) {
    const line = raw.trim()
    if (line === '') { if (out.length) break; else continue }
    const m = line.match(/^(?:\/\/|;)\s?(.*)$/)
    if (!m) break
    const body = m[1].trim()
    if (!body) continue
    if (/^SPDX-License-Identifier/i.test(body)) continue
    if (/^[=\-_*#~]{4,}$/.test(body)) continue
    if (/φ|phi\^?2/i.test(body) && /TRINITY/i.test(body)) continue
    if (/^DO NOT EDIT/i.test(body)) continue
    out.push(body)
    if (out.length >= 6) break
  }
  return out.join(' ').replace(/\s+/g, ' ').trim() || null
}

/**
 * Tags, derived from what a spec actually is rather than hand-applied.
 *
 * 760 specs cannot be tagged by hand and stay correct, so every tag here comes
 * from a signal already in the file: its path, the node kinds its AST really
 * contains, and what the backends produced. Nothing is inferred from the
 * filename alone, and nothing is invented.
 *
 * Three families, kept deliberately separate so combining them means something:
 *   domain/    what the spec is about        (fpga, ml, numeric …)
 *   has/       what it structurally contains (tests, structs, functions …)
 *   size/, src/, plus a bare health tag.
 */
const DOMAIN_BY_SEGMENT = {
  fpga: 'fpga', boards: 'fpga', testbench: 'fpga', pins: 'fpga',
  ml: 'ml', nn: 'ml', layers: 'ml', activation: 'ml', transformer: 'ml',
  recurrent: 'ml', rl: 'ml', loss: 'ml', optimizer: 'ml', hslm: 'ml',
  numeric: 'numeric', math: 'math', physics: 'physics', sacred: 'sacred',
  isa: 'isa', compiler: 'compiler', parser: 'compiler', codegen: 'compiler',
  lsp: 'compiler', vm: 'compiler', jit: 'compiler', runtime: 'compiler',
  crypto: 'crypto', vsa: 'vsa', brain: 'brain', agent: 'agent',
  net: 'network', server: 'network', api: 'network', interop: 'network',
  storage: 'storage', memory: 'storage', file: 'storage', io: 'storage',
  collections: 'collections', trees: 'collections', sort: 'collections',
  search: 'collections', graph: 'graph',
  test_framework: 'testing', conformance: 'testing', benchmarks: 'testing',
  tutorial: 'tutorial', demos: 'tutorial', examples: 'tutorial',
  github: 'tools', git: 'tools', tools: 'tools', shell: 'tools', cli: 'tools',
  encoding: 'encoding', ternary: 'ternary', tri27: 'ternary',
  // Added after checking what actually landed in domain/other: these five
  // segments accounted for most of it.
  utils: 'utils', pipeline: 'pipeline', ar: 'reasoning', base: 'base',
  sandbox: 'tools', config: 'tools', provider: 'network', account: 'network',
  auth: 'network', queen: 'agent', bus: 'network', sync: 'network',
  enrichment: 'tools', contrib: 'other',
}

function deriveTags(rel, repo, kinds, entry) {
  const tags = new Set()
  const segs = rel.split('/').slice(0, -1)

  for (const s of segs) {
    const d = DOMAIN_BY_SEGMENT[s.toLowerCase()]
    if (d) tags.add(`domain/${d}`)
  }
  // A spec with no recognised segment is still a spec; say so rather than
  // leaving it untagged and unfindable.
  if (![...tags].some((t) => t.startsWith('domain/'))) tags.add('domain/other')

  // Structure, straight from the tree the compiler produced.
  if (kinds.TestBlock) tags.add('has/tests')
  if (kinds.InvariantBlock) tags.add('has/invariants')
  if (kinds.BenchBlock) tags.add('has/benches')
  if (kinds.StructDecl) tags.add('has/structs')
  if (kinds.EnumDecl) tags.add('has/enums')
  if (kinds.FnDecl) tags.add('has/functions')
  if (kinds.UseDecl) tags.add('has/imports')
  if (kinds.ConstDecl && !kinds.FnDecl) tags.add('has/constants-only')
  if (kinds.StmtWhile || kinds.StmtFor) tags.add('has/loops')
  if (kinds.ExprSwitch) tags.add('has/switch')

  const lines = entry.lines
  tags.add(lines < 50 ? 'size/tiny' : lines < 150 ? 'size/small' : lines < 400 ? 'size/medium' : 'size/large')

  tags.add(`src/${repo}`)
  tags.add(`health/${entry.health}`)
  if (entry.loss > 0) tags.add('issue/dropped-content')
  if (entry.tcErrors > 0) tags.add('issue/type-errors')
  if (entry.failedBackends.length) tags.add('issue/backend-rejected')

  return [...tags].sort()
}

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

  let a = null
  try { a = analyze(text) } catch { a = null }

  // Count node kinds once; tags and the UI histogram both read from this.
  const kinds = {}
  if (a?.ast) {
    const walk = (n) => { kinds[n.kind] = (kinds[n.kind] || 0) + 1; n.children.forEach(walk) }
    walk(a.ast)
  }
  const failedBackends = a ? Object.entries(a.targets).filter(([, v]) => !v.ok).map(([k]) => k) : []
  const loss = a ? a.discarded.length + a.swallowed.length + a.lexerDiscarded.length : 0
  const tcErrors = a?.typecheck?.errorCount ?? 0
  // Three states, worst-wins. "fail" means something refused to produce output
  // at all; "warn" means it produced output but the compiler flagged or dropped
  // something on the way.
  const health = !a || a.astError || failedBackends.length ? 'fail' : loss > 0 || tcErrors > 0 ? 'warn' : 'ok'

  const parts = rel.split('/')
  // Two segments, not one: with the corpus widened past specs/, a single
  // segment would lump all 497 specs under "specs" and all 147 chip specs
  // under "chips", throwing away the grouping that makes the list navigable.
  const category = parts.length > 2 ? `${parts[0]}/${parts[1]}` : parts.length > 1 ? parts[0] : 'root'
  // A spec's `module X {` line is a better label than its filename when the two
  // disagree, which they often do.
  const moduleMatch = text.match(/^\s*module\s+([A-Za-z0-9_-]+)/m)
  entries.push({
    path: rel,
    category,
    name: parts[parts.length - 1].replace(/\.t27$/, ''),
    module: moduleMatch ? moduleMatch[1] : null,
    lines: text.split('\n').length,
    bytes: Buffer.byteLength(text, 'utf8'),
    description: describe(text),
    health,
    tokens: a?.tokenCount ?? 0,
    nodes: a?.nodeCount ?? 0,
    depth: a?.astDepth ?? 0,
    loss,
    tcErrors,
    failedBackends,
    // Output size per backend, so the library can show what a spec actually
    // produces without re-running the compiler.
    outBytes: a ? Object.fromEntries(Object.entries(a.targets).map(([k, v]) => [k, v.ok ? v.bytes : null])) : {},
    repo: src.repo,
    kinds,
  })
  const e = entries[entries.length - 1]
  e.tags = deriveTags(rel, src.repo, kinds, e)
}
}

// Tarballs were extracted to temp dirs; nothing should outlive this run.
for (const s of sources) if (s.tmp) rmSync(s.tmp, { recursive: true, force: true })

// ---------------------------------------------------------------------------
// Language-audit exceptions
//
// `qa/ru_audit.mjs` fails the build on any English sentence over 45 characters
// that renders under ?lang=ru. That gate is right, and it should stay strict:
// it exists to catch untranslated UI.
//
// Spec descriptions are not UI. They are comments quoted verbatim out of 760
// source files, in the language their authors wrote them in. Translating them
// would misrepresent the files; hiding them would gut the page. So they are
// registered as exceptions -- the same treatment the site already gives
// bibliography entries and code samples.
//
// Generated here rather than hand-maintained, so the list cannot drift from
// what the page actually renders.
const EXC_PATH = join(WEBSITE, 'qa/language-exceptions.json')
if (existsSync(EXC_PATH)) {
  const exc = JSON.parse(readFileSync(EXC_PATH, 'utf8'))
  exc.ru = exc.ru || {}
  const descs = [...new Set(entries.map((e) => e.description).filter(Boolean))]
  // Only the ones the audit would actually flag; anything shorter passes on
  // its own and does not belong in an exception list.
  exc.ru.specs = descs.filter((d) => d.length > 45).sort()
  writeFileSync(EXC_PATH, JSON.stringify(exc, null, 2) + '\n')
  console.log(`  qa exceptions: ${exc.ru.specs.length} spec descriptions registered for the RU audit`)
}

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

const byCategory = {}
for (const e of entries) byCategory[e.category] = (byCategory[e.category] || 0) + 1

const health = { ok: 0, warn: 0, fail: 0 }
for (const e of entries) health[e.health]++
const backendFailures = {}
for (const e of entries) for (const b of e.failedBackends) backendFailures[b] = (backendFailures[b] || 0) + 1

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
  repos: sources.map((s) => ({ repo: s.repo, commit: s.commit ?? sha, specs: entries.filter((e) => e.repo === s.repo).length })),
  duplicatesSkipped: duplicates,
  // Every tag with its count, so the UI can render facets without walking 760
  // entries on each keystroke.
  tags: Object.fromEntries(
    Object.entries(
      entries.reduce((acc, e) => {
        for (const t of e.tags) acc[t] = (acc[t] || 0) + 1
        return acc
      }, {}),
    ).sort((a, b) => (a[0] === b[0] ? 0 : b[1] - a[1] || a[0].localeCompare(b[0]))),
  ),
  health,
  backendFailures,
  featured: FEATURED,
  totals: {
    tokens: entries.reduce((a, e) => a + e.tokens, 0),
    nodes: entries.reduce((a, e) => a + e.nodes, 0),
    lossAffected: entries.filter((e) => e.loss > 0).length,
    tcAffected: entries.filter((e) => e.tcErrors > 0).length,
  },
  specs: entries,
}, null, 0))

console.log(`sync-t27-specs: ${entries.length} specs, ${Object.keys(byCategory).length} categories`)
console.log(`  sources: ${sources.map((s) => s.repo).join(', ')}  (${duplicates} duplicate files skipped by content hash)`)
console.log(`  health: ${health.ok} ok · ${health.warn} warn · ${health.fail} fail`)
if (Object.keys(backendFailures).length) console.log(`  backend failures: ${JSON.stringify(backendFailures)}`)
console.log(`  t27 @ ${shortSha}${dirty ? ' (DIRTY -- snapshot includes uncommitted spec/compiler changes)' : ''}`)
console.log(`  wasm ${(wasmBytes / 1024).toFixed(0)} KB -> public/t27/t27_compiler.wasm`)
if (dirty) console.log(`  warning: commit t27 before shipping, or the recorded SHA understates the snapshot`)
