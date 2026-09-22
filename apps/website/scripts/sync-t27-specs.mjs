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
// A checkout beside this repository, not somebody's home directory. The line
// used to read `/Users/playom/t27` -- `playra` with one letter wrong -- and the
// typo was not cosmetic, because WASM_SRC on the next line is derived from it.
// `existsSync(WASM_SRC)` was therefore false on every machine, including the
// one that wrote it, so every refresh took the fallback branch below and
// re-vendored the wasm already sitting in public/t27. That is the whole
// mechanism behind gHashTag/t27#4487: the browser ran a compiler built from
// source committed in no repository, because one character kept the real build
// permanently out of reach.
const T27 = process.env.T27_ROOT || join(HERE, '../../../../t27')
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

// Where t27 itself comes from.
//
// For a year it came from this line's default: a working copy on one laptop.
// That is how the library fell 540 specs behind master -- specs/tools (94),
// bootstrap/tests (90), specs/ternary (60), specs/igla (44), specs/crons (33),
// specs/agents (27), specs/skills (26) are all on master and none of them were
// on the branch the last sync happened to be standing on. No workflow could fix
// it either: CI has no /Users/playom/t27, so the daily scan skipped the
// repository that holds two thirds of the corpus.
//
// So GitHub is the source, like the other four founding repositories, and the
// local checkout is the opt-in (T27_LOCAL=1) for whoever is changing the
// compiler and needs to see uncommitted specs on the page.
const FROM_LOCAL = process.env.T27_LOCAL === '1' || process.env.T27_LOCAL === 'true'
if (FROM_LOCAL && !existsSync(SPECS_SRC)) fail(`T27_LOCAL is set but no spec corpus at ${SPECS_SRC} (set T27_ROOT)`)

// The compiler wasm is built by cargo, which CI does not run either. The copy
// already vendored beside the corpus is the one the browser loads today, so a
// spec refresh reuses it and says so; only a compiler change needs the build.
// Read before the output directory is wiped, not after.
const VENDORED_WASM = join(OUT_DIR, 't27_compiler.wasm')
let wasmBuf, wasmFrom
if (existsSync(WASM_SRC)) { wasmBuf = readFileSync(WASM_SRC); wasmFrom = 'cargo build in the local checkout' }
else if (existsSync(VENDORED_WASM)) {
  wasmBuf = readFileSync(VENDORED_WASM); wasmFrom = 'the copy already vendored here'
  // Say it out loud. Re-vendoring is the right default for a spec refresh, but
  // it is the wrong outcome for anyone who just built the compiler and expects
  // to see it, and silence is what let the last one drift unnoticed.
  console.log(`  note: no cargo build at ${WASM_SRC}, re-vendoring the existing wasm`)
  console.log('        set T27_ROOT if your t27 checkout is somewhere else')
}
else fail(`no compiler wasm.\n  cd ${T27}/bindings/wasm-explorer\n  cargo build --target wasm32-unknown-unknown --release`)

const gh = (args) => execFileSync('gh', args, { encoding: 'utf8', timeout: 120000, maxBuffer: 60 * 1024 * 1024 }).trim()

// One request, no working copy left behind. Returns the extracted root.
//
// `slug` is owner/name. It used to be a bare name with `gHashTag/` welded in
// here, which is why a corpus repo owned by anyone else could not be fetched at
// all -- see EXTRA_REPOS below for what that cost.
//
// Three attempts, not one. These are large downloads -- trinity-fpga alone is
// 353 MB over about a minute and a half -- and on 2026-09-21 one of them failed
// once. That single hiccup cost the manifest all 64 of that repository's specs,
// and the run still exited 0. Backoff is 2s, 6s: long enough to outlast a
// transient refusal, short enough that a genuinely dead repository is not
// waited on for minutes.
function tarball(slug, ref) {
  const dir = mkdtempSync(join(tmpdir(), `t27-${slug.replace(/\W/g, '-')}-`))
  let last
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      execFileSync('sh', ['-c',
        `gh api "repos/${slug}/tarball/${ref}" > "${dir}/a.tar.gz" && tar -xzf "${dir}/a.tar.gz" -C "${dir}"`,
      ], { stdio: 'ignore' })
      const inner = execFileSync('sh', ['-c', `ls -d "${dir}"/*/ | head -1`], { encoding: 'utf8' }).trim()
      return { dir, root: inner.replace(/\/$/, '') }
    } catch (e) {
      last = e
      if (attempt < 3) {
        console.log(`  ${slug}: tarball attempt ${attempt} failed, retrying`)
        execFileSync('sleep', [String(attempt * 2 + (attempt - 1) * 2)])
      }
    }
  }
  throw last
}

// Exclusions, all of them copies of files counted elsewhere rather than
// judgement calls about what deserves to be in the library:
//   .git/      object store
//   .claude/   git worktrees -- second checkouts of files already counted
//   public/t27/files/  THIS corpus, vendored into the website repository. The
//     trinity tarball carries it, so without this line a refresh vendors its
//     own output back in: the first run produced 563 "trinity" specs, which
//     were the previous snapshot of t27 wearing a different path.
const specFiles = (root) => execFileSync('find', [
  root, '-name', '*.t27', '-type', 'f',
  '-not', '-path', `${root}/.git/*`,
  '-not', '-path', `${root}/.claude/*`,
  '-not', '-path', '*/public/t27/files/*',
], { encoding: 'utf8' }).split('\n').filter(Boolean).sort()

const T27_REF = process.env.T27_REF || 'master'
// The eight-lesson course and hello_world live on a branch that was never
// merged, so master alone would delete the whole onboarding path from the site.
// Named refs contribute only the paths the main ref does not have, which means
// this list retires itself: merge the course and the overlay contributes zero.
const OVERLAY_REFS = (process.env.T27_OVERLAY_REFS ?? 'fix/reject-vibee-specs').split(',').map((s) => s.trim()).filter(Boolean)

let sha, shortSha, dirty, t27Root, t27Tmp, overlayUsed = []
if (FROM_LOCAL) {
  sha = execFileSync('git', ['-C', T27, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim()
  dirty = execFileSync('git', ['-C', T27, 'status', '--porcelain', '--', 'specs', 'chips', 'compiler', 'bootstrap/src/compiler.rs'], { encoding: 'utf8' }).trim()
  t27Root = T27
} else {
  sha = gh(['api', `repos/gHashTag/t27/commits/${T27_REF}`, '--jq', '.sha'])
  dirty = ''
  const main = tarball('gHashTag/t27', T27_REF)
  t27Root = main.root
  t27Tmp = main.dir
  // Overlay: copy in only what the main ref is missing, and record what each
  // one actually contributed rather than claiming the whole branch.
  const have = new Set(specFiles(t27Root).map((f) => relative(t27Root, f)))
  for (const ref of OVERLAY_REFS) {
    let extra
    try { extra = tarball('gHashTag/t27', ref) } catch { console.log(`  warning: overlay ref ${ref} unreachable, skipped`); continue }
    const added = []
    for (const abs of specFiles(extra.root)) {
      const rel = relative(extra.root, abs)
      if (have.has(rel)) continue
      const dest = join(t27Root, rel)
      mkdirSync(dirname(dest), { recursive: true })
      writeFileSync(dest, readFileSync(abs))
      have.add(rel)
      added.push(rel)
    }
    rmSync(extra.dir, { recursive: true, force: true })
    overlayUsed.push({ ref, commit: gh(['api', `repos/gHashTag/t27/commits/${ref}`, '--jq', '.sha']), added: added.length, paths: added.sort() })
    console.log(`  overlay ${ref}: ${added.length} path(s) not on ${T27_REF}`)
  }
}
shortSha = sha.slice(0, 9)

// Every .t27 in the repo, not just specs/ -- `chips/` alone holds ~147 real
// specs, and a corpus that quietly stops at specs/ cannot show a problem living
// outside it. What is left out is listed at specFiles() above.
const t27Files = specFiles(t27Root)

if (!t27Files.length) fail('no .t27 files found')

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
//
// The list was four names long until 2026-09-21, and the corpus it was
// rebuilding had ten. The five missing ones were vendored here by some other
// route and this script knew nothing about them, so every run WIPED them:
// trios 58 specs, tt-trinity-euler 46, dmitrii-f-t27/trinity-memory 37,
// turbobaby-user-bot 12, tt-trinity-gamma 1 -- 154 of 1407, amputated in
// silence and re-committed as a refresh. Measured by running it: 1407 in,
// 1259 out. One of the five is not even owned by gHashTag, which is the
// reason `tarball()` now takes owner/name instead of welding the owner in.
//
// Entries are owner/name. The manifest key stays the bare name for our own
// repos, because that is what `specUrl` and the contribute links already
// build `github.com/gHashTag/<key>` from.
// ---------------------------------------------------------------------------
const EXTRA_REPOS = (process.env.T27_SKIP_REMOTE ? [] : [
  'gHashTag/tri-net',
  'gHashTag/trinity-fpga',
  'gHashTag/trinity',
  'gHashTag/tt-trinity-corona',
  'gHashTag/tt-trinity-euler',
  'gHashTag/tt-trinity-gamma',
  'gHashTag/trios',
  'gHashTag/turbobaby-user-bot',
  'dmitrii-f-t27/trinity-memory',
])

const sources = [{ repo: 't27', root: t27Root, files: t27Files, commit: FROM_LOCAL ? null : sha, tmp: t27Tmp }]

for (const slug of EXTRA_REPOS) {
  const [owner, name] = slug.split('/')
  const repo = owner === 'gHashTag' ? name : slug
  // A skip used to be a `console.log` and a `continue`, and the run still
  // exited 0. On 2026-09-21 that printed one warning line and wrote a manifest
  // missing 64 specs -- a whole repository -- which is a corpus that lies about
  // its own size, published, with nothing red anywhere. A source named in
  // EXTRA_REPOS that cannot be read is a failed sync, not a smaller corpus.
  //
  // The escape hatch is deliberate and narrow: a repository that is genuinely
  // gone should be DELETED FROM THE LIST above, which is a decision a person
  // makes once, in a diff, rather than a warning nobody reads every run.
  // T27_ALLOW_MISSING is for reproducing an old manifest offline.
  const ALLOW_MISSING = process.env.T27_ALLOW_MISSING === '1'
  const lost = (what, e) => {
    if (!ALLOW_MISSING) fail(`${slug} ${what}.\n  A source in EXTRA_REPOS that cannot be read is a failed sync.\n  If the repository is gone, remove it from EXTRA_REPOS in this file.\n  To reproduce an older manifest anyway: T27_ALLOW_MISSING=1\n  ${e?.message ?? ''}`)
    console.log(`  warning: ${slug} ${what}, skipped (T27_ALLOW_MISSING=1)`)
  }
  let branch
  try {
    branch = gh(['api', `repos/${slug}`, '--jq', '.default_branch'])
  } catch (e) {
    lost('unreachable', e)
    continue
  }
  const sha = gh(['api', `repos/${slug}/commits/${branch}`, '--jq', '.sha'])
  let pulled
  try {
    pulled = tarball(slug, branch)
  } catch (e) {
    lost('tarball failed after 3 attempts', e)
    continue
  }
  sources.push({ repo, root: pulled.root, files: specFiles(pulled.root), commit: sha, tmp: pulled.dir })
}

// Provenance this script does not compute, read before the wipe removes it.
//
// `discover-t27-worlds.mjs vendor` writes two things into the manifest that
// nothing here can reconstruct: `discoveredAt` on a world's repo row, and the
// `discovery` block naming the contract each world was admitted under. That
// division of labour held while EXTRA_REPOS listed four founding sources and
// mergeWorld owned the rest -- it stopped holding the moment this script
// started pulling all ten, because it rewrites those rows now. The first
// ten-repo run dropped `manifest.discovery` entirely and left every repo row
// looking founding, which `qa/t27-world-discovery.mjs` reads as five
// hand-vendored sources having become ten.
//
// So carry the scan's facts and refresh ours. `at`, `branch`, `files`,
// `duplicatesSkipped` and `spec.sha256` describe a scan on a stated day and
// stay true of it; `commit` and `specs` are claims about the corpus in this
// file, and a preserved commit sitting beside a freshly pulled repos[].commit
// is a manifest that contradicts itself. A world this script no longer pulls
// drops out rather than lingering as provenance for specs that are gone.
const priorManifestPath = join(OUT_DIR, 'manifest.json')
const priorManifest = existsSync(priorManifestPath) ? JSON.parse(readFileSync(priorManifestPath, 'utf8')) : null
const discoveredAt = new Map((priorManifest?.repos ?? []).filter((r) => r.discoveredAt).map((r) => [r.repo, r.discoveredAt]))
const priorDiscovery = priorManifest?.discovery ?? null

// Wipe what this script writes, and only that.
//
// This was `rmSync(OUT_DIR)`, which also deleted two tracked artifacts it does
// not produce and cannot restore: shared-core.json (2.3 MB, `npm run core`) and
// universe-atlas.json (1.1 MB, `npm run atlas`). Nothing warned, and nothing in
// package.json chains the three, so a refresh left the Queen's shared-core and
// universe pages pointing at files that were no longer there.
rmSync(SPECS_OUT, { recursive: true, force: true })
rmSync(join(OUT_DIR, 'manifest.json'), { force: true })
mkdirSync(SPECS_OUT, { recursive: true })

// Run the same wasm the browser runs, here, over the whole corpus. Health has
// to be known before a row is drawn -- the alternative is compiling 667 specs
// in the browser just to colour a list, which would take minutes.
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
// Not just how many, but which. A count cannot answer "does this spec exist
// anywhere else?", which is the question a reader of a multi-repository corpus
// actually has -- and the losing bytes are discarded here, so if this list is
// not written now nothing downstream can reconstruct it.
const duplicatePairs = []

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
  if (already) { duplicates++; duplicatePairs.push({ path: rel, repo: src.repo, sameAs: already }); continue }
  seenContent.set(hash, rel)

  const dest = join(SPECS_OUT, rel)
  mkdirSync(dirname(dest), { recursive: true })
  writeFileSync(dest, text)

  entries.push(corpusEntry(rel, src.repo, text, analyze))
}
}

// The companions a spec cites.
//
// A spec's SOURCES names the files it was written from -- a README, a report,
// a directory -- and scripts/docs-from-specs.mjs refuses a citation it cannot
// resolve, on the principle that a document may not point at something that is
// not there. Those files are not .t27, so the loop above skips them, and the
// first GitHub-sourced refresh deleted the ones a previous hand-vendored commit
// had put here -- the seven docs/system/*.md a chapter renders, and the reports
// evidence.t27 cites. They are copied from the same tarball, at the same commit,
// as the spec that names them.
//
// `trinity:`-prefixed paths are resolved against this repository instead and are
// not vendored, so they are skipped here.
// Two shapes name a file: a SOURCES list, and a single-string constant such as
// BODY_EN, whose value is the markdown a docs chapter renders. A value with no
// extension (DIAGRAM = "ladder", TABLE = "claims") is an identifier, not a path,
// and is skipped by the extension test below.
const SOURCES_DECL = /\bSOURCES\s*:\s*\[\d*\]\s*str\s*=\s*\[([^\]]*)\]/
const STRING_DECL = /\b[A-Z][A-Z0-9_]*\s*:\s*str\s*=\s*"([^"]+)"/g
const TEXT_FILE = /\.(md|markdown|txt|rst|adoc|csv|json|toml|ya?ml)$/i
let companions = 0
for (const src of sources) {
  for (const abs of src.files) {
    const text = readFileSync(abs, 'utf8')
    const decl = SOURCES_DECL.exec(text)
    const cited = [
      ...(decl ? [...decl[1].matchAll(/"([^"]+)"/g)].map((m) => m[1]) : []),
      ...[...text.matchAll(STRING_DECL)].map((m) => m[1]).filter((v) => TEXT_FILE.test(v)),
    ]
    for (const rel of cited) {
      if (rel.startsWith('trinity:') || rel.endsWith('.t27') || rel.includes('..') || rel.startsWith('/')) continue
      const from = join(src.root, rel)
      if (!existsSync(from)) continue
      const dest = join(SPECS_OUT, src.repo === 't27' ? rel : `${src.repo}/${rel}`)
      if (existsSync(dest)) continue
      mkdirSync(dirname(dest), { recursive: true })
      cpSync(from, dest, { recursive: true })
      companions += 1
    }
  }
}
if (companions) console.log(`  companions: ${companions} non-spec file(s) cited by SOURCES vendored beside their spec`)

// Tarballs were extracted to temp dirs; nothing should outlive this run.
for (const s of sources) if (s.tmp) rmSync(s.tmp, { recursive: true, force: true })

// Spec descriptions are comments quoted verbatim out of the source files, in the language
// their authors wrote them in; qa/ru_audit.mjs must not flag them as untranslated UI. The
// exception list is generated, never hand-maintained (see t27-corpus.mjs).
const registered = registerDescriptionExceptions(entries, join(WEBSITE, 'qa/language-exceptions.json'))
if (registered !== null) console.log(`  qa exceptions: ${registered} spec descriptions registered for the RU audit`)

writeFileSync(join(OUT_DIR, 't27_compiler.wasm'), wasmBuf)
const wasmBytes = wasmBuf.length

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

const { totalLines, categories, tags, health, notSource, backendFailures, totals } = corpusAggregates(entries)

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
// Sourced from GitHub there is nothing to guess: the overlay loop above copied
// in exactly the paths the main ref does not have, and kept the list. Sourced
// from a working copy the question is still open, so it is still asked.
const DEFAULT_REF = FROM_LOCAL ? (process.env.T27_DEFAULT_REF || 'origin/master') : T27_REF
const unreachable = []
let reachableChecked = 0
if (!FROM_LOCAL) {
  reachableChecked = entries.filter((e) => e.repo === 't27').length
  const overlayPaths = new Set(overlayUsed.flatMap((o) => o.paths))
  for (const e of entries) if (e.repo === 't27' && overlayPaths.has(e.path)) unreachable.push(e.path)
} else {
  let submodulePaths = []
  try {
    submodulePaths = execFileSync('git', ['-C', T27, 'config', '-f', '.gitmodules', '--get-regexp', 'path'], { encoding: 'utf8' })
      .split('\n').filter(Boolean).map((line) => line.trim().split(/\s+/)[1]).filter(Boolean)
  } catch {
    // No .gitmodules is a valid state, not an error.
  }
  const ownedByASubmodule = (rel) => submodulePaths.some((s) => rel === s || rel.startsWith(`${s}/`))
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
    // How this snapshot was taken, so a reader can tell a reproducible refresh
    // from one that shipped whatever was on somebody's disk.
    source: FROM_LOCAL ? 'local working copy' : `github tarball gHashTag/t27@${T27_REF}`,
    overlayRefs: overlayUsed.map(({ ref, commit, added }) => ({ ref, commit, added })),
    wasmSource: wasmFrom,
  },
  wasmBytes,
  specCount: entries.length,
  totalLines,
  categories,
  repos: sources.map((s) => {
    const row = { repo: s.repo, commit: s.commit ?? sha, specs: entries.filter((e) => e.repo === s.repo).length }
    // A repo row without `discoveredAt` means "hand-vendored, founding". Only
    // the scan can say otherwise, so the flag is carried, never invented.
    return discoveredAt.has(s.repo) ? { ...row, discoveredAt: discoveredAt.get(s.repo) } : row
  }),
  duplicatesSkipped: duplicates,
  duplicates: duplicatePairs.sort((x, y) => x.path.localeCompare(y.path)),
  tags,
  health,
  notSource,
  backendFailures,
  featured: FEATURED,
  totals,
  ...(priorDiscovery
    ? {
      discovery: {
        ...priorDiscovery,
        worlds: (priorDiscovery.worlds ?? [])
          .filter((w) => sources.some((s) => s.repo === w.label))
          .map((w) => {
            const s = sources.find((x) => x.repo === w.label)
            return { ...w, commit: s.commit ?? w.commit, specs: entries.filter((e) => e.repo === w.label).length }
          }),
      },
    }
    : {}),
  specs: entries,
}, null, 0))

console.log(`sync-t27-specs: ${entries.length} specs, ${Object.keys(categories).length} categories`)
console.log(`  sources: ${sources.map((s) => s.repo).join(', ')}  (${duplicates} duplicate files skipped by content hash)`)
// Over modules, and the line says so. These three used to cover every vendored
// file, which meant 81 of the failures were Markdown documents and damaged
// fixtures being counted as broken specs -- a number that could not go down.
console.log(`  health: ${health.ok} ok · ${health.warn} warn · ${health.fail} fail   (of ${health.ok + health.warn + health.fail} modules)`)
console.log(`  not a module: ${notSource.total}  ${Object.entries(notSource.byKind).sort((a, b) => b[1] - a[1]).map(([k, n]) => `${k} ${n}`).join(' · ')}`)
if (Object.keys(backendFailures).length) console.log(`  backend failures: ${JSON.stringify(backendFailures)}`)
console.log(`  t27 @ ${shortSha}${dirty ? ' (DIRTY -- snapshot includes uncommitted spec/compiler changes)' : ''}`)
console.log(`  wasm ${(wasmBytes / 1024).toFixed(0)} KB -> public/t27/t27_compiler.wasm  (${wasmFrom})`)
if (dirty) console.log(`  warning: commit t27 before shipping, or the recorded SHA understates the snapshot`)
