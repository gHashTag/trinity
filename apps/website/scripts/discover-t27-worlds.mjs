#!/usr/bin/env node
// discover-t27-worlds.mjs -- find every public GitHub repository that writes .t27 specs and
// vendor the ones nobody listed by hand into the catalog behind #/specs and the Queen map.
//
// The catalog knew five repositories, all typed into scripts/sync-t27-specs.mjs. A sixth
// (gHashTag/trios, 71 specs) sat in the same owner's inventory unnoticed, and a seventh
// (dmitrii-f-t27/trinity-memory, 37) belongs to another owner; neither could reach the map,
// and the "+ Repository" dialog only saves a map on one device. So the scan is a program
// with a contract -- public/t27/files/specs/catalog/discovery.t27, read through the vendored
// compiler and checked before GitHub is touched -- not a list in a script.
//
//   node scripts/discover-t27-worlds.mjs scan   --out /absolute/NEW-report.json
//   node scripts/discover-t27-worlds.mjs vendor --report /absolute/report.json
//
// scan    reads the public inventories of the owners the spec names, adds GitHub code search
//         hits for `extension:t27` as candidates (best effort: the index is incomplete and
//         noisy), lists the .t27 files of every candidate from its default-branch tree and
//         compiles the first PROBE_FILES of them with the vendored wasm. A repository
//         qualifies when one probed file holds at least MIN_DECLARATIONS declarations: the
//         compiler accepts any text as an empty module, so parsing alone proves nothing (a
//         licence file named .t27 "compiles", and code search returns forty of those).
// vendor  pulls each qualified non-founding world as a tarball at the commit the scan saw,
//         drops files whose bytes are already in the catalog, writes the rest under
//         public/t27/files/<name>/ (gHashTag) or public/t27/files/<owner>/<name>/ (any other
//         owner) and rewrites public/t27/manifest.json: the world's previous entries are
//         replaced, every other entry stays byte for byte. The FOUNDING sources are never
//         touched here; they come from a local t27 checkout through sync-t27-specs.mjs,
//         unmerged branches included.
//
// Reports are never overwritten (--out refuses an existing file). Public reads only; no
// GitHub writes, no private repositories, no credentials in any artifact.
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync, renameSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { dirname, join, relative, resolve } from 'node:path'
import { tmpdir } from 'node:os'
import { fileURLToPath } from 'node:url'
import { SITE, checkSchema, constsOf, loadCompiler, sha256 } from './agents-from-specs.mjs'
import { runSpecTests } from './viewport-from-spec.mjs'
import { corpusAggregates, corpusEntry, registerDescriptionExceptions } from './t27-corpus.mjs'

export const SPEC = 'public/t27/files/specs/catalog/discovery.t27'
export const WASM = 'public/t27/t27_compiler.wasm'
export const MANIFEST = 'public/t27/manifest.json'
export const FILES = 'public/t27/files'
export const EXCEPTIONS = 'qa/language-exceptions.json'
export const EXPECTED_MODULE = 'catalog_discovery'
export const REQUIRED = {
  KIND: 'str', ID: 'str', NAME: 'str', GENERATED: 'arr',
  OWNERS: 'arr', CODE_SEARCH: 'str', CODE_SEARCH_PAGES: 'u8',
  PUBLIC_ONLY: 'bool', SKIP_FORKS: 'bool', SKIP_ARCHIVED: 'bool', MIRRORS: 'arr', FOUNDING: 'arr',
  PROBE_FILES: 'u8', MIN_DECLARATIONS: 'u8',
  MAX_WORLDS: 'u8', MAX_FILES_PER_WORLD: 'u16', MAX_FILE_BYTES: 'u32',
}
/** What makes a file t27 rather than text: a declaration the parser recognised. */
export const DECLARATION_KINDS = new Set(['FnDecl', 'StructDecl', 'EnumDecl', 'ConstDecl', 'TypeDecl', 'TestBlock', 'InvariantBlock', 'BenchBlock'])
export const REPO_RE = /^[a-z0-9](?:[a-z0-9-]{0,37}[a-z0-9])?\/[a-z0-9_.-]{1,100}$/
const OWNER_RE = /^[A-Za-z0-9][A-Za-z0-9-]{0,38}$/
const SHA_RE = /^[a-f0-9]{40}$/

// ---------------------------------------------------------------------------
// The contract. Schema, module, ASCII and the spec's own tests, before any network call.
// ---------------------------------------------------------------------------
export function loadDiscoverySpec(analyze, specText, file = SPEC) {
  const problems = []
  if (/[^\x00-\x7f]/.test(specText)) problems.push(`${file}: non-ASCII byte in the spec (L3)`)
  const analysis = analyze(specText)
  if (analysis.astError) problems.push(`${file}: ${analysis.astError}`)
  const moduleName = analysis.ast?.name ?? null
  if (moduleName !== EXPECTED_MODULE) problems.push(`${file}: module must be ${EXPECTED_MODULE}, is ${moduleName}`)
  const dropped = (analysis.discarded?.length ?? 0) + (analysis.lexerDiscarded?.length ?? 0) + (analysis.swallowed?.length ?? 0)
  if (dropped) problems.push(`${file}: the compiler dropped ${dropped} item(s); a bare \`;\` line ahead of \`module\` is a statement, not a comment`)
  if (analysis.typecheck?.ok !== true) problems.push(`${file}: typecheck failed`)
  let consts = {}
  try { consts = constsOf(analysis) } catch (e) { problems.push(`${file}: ${e.message}`) }
  problems.push(...checkSchema(consts, REQUIRED, {}, file))
  const fields = Object.fromEntries(Object.entries(consts).map(([k, v]) => [k, v.value]))
  if (fields.KIND !== 'discovery') problems.push(`${file}: KIND must be "discovery"`)
  const tests = problems.length ? { tests: 0, asserts: 0, failures: [] } : runSpecTests(analysis, fields)
  for (const f of tests.failures) problems.push(`${file}: ${f}`)
  for (const key of ['OWNERS', 'MIRRORS', 'FOUNDING']) {
    for (const v of fields[key] ?? []) {
      if (key === 'OWNERS' ? !OWNER_RE.test(v) : !REPO_RE.test(v)) problems.push(`${file}: ${key} holds an invalid ${key === 'OWNERS' ? 'owner' : 'owner/repo'}: ${v}`)
    }
  }
  return { fields, sha256: sha256(Buffer.from(specText, 'utf8')), tests, problems, moduleName }
}

// ---------------------------------------------------------------------------
// Pure decisions. GitHub metadata is public API data, never instructions.
// ---------------------------------------------------------------------------
/** A repository record as GitHub returns it, reduced to what the scan needs, or null when its identity does not hold. */
export function repoIdentity(raw) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null
  const repo = String(raw.full_name ?? '').toLowerCase()
  if (!REPO_RE.test(repo)) return null
  const owner = String(raw.owner?.login ?? '')
  if (owner.toLowerCase() !== repo.split('/')[0]) return null
  if (String(raw.html_url ?? '').toLowerCase() !== `https://github.com/${repo}`) return null
  if (typeof raw.default_branch !== 'string' || !/^[\w./-]{1,255}$/.test(raw.default_branch)) return null
  return {
    repo, owner, name: repo.split('/')[1],
    description: typeof raw.description === 'string' ? raw.description.slice(0, 2000) : '',
    private: raw.private !== false, fork: raw.fork === true, archived: raw.archived === true,
    issuesEnabled: raw.has_issues === true, branch: raw.default_branch,
  }
}

/** Why a repository is not vendored, if it is not; founding and mirror status alongside. */
export function candidateVerdict(meta, f) {
  const founding = f.FOUNDING.includes(meta.repo)
  const mirror = f.MIRRORS.includes(meta.repo)
  let skip = null
  if (f.PUBLIC_ONLY && meta.private) skip = 'private'
  else if (mirror) skip = 'mirror'
  else if (f.SKIP_FORKS && meta.fork) skip = 'fork'
  else if (f.SKIP_ARCHIVED && meta.archived) skip = 'archived'
  return { skip, founding, mirror }
}

/** The .t27 blobs of a git tree, in path order; worktree copies and oversized files set aside. */
export function t27PathsOf(tree, f) {
  const paths = []
  let skippedLarge = 0
  for (const item of Array.isArray(tree?.tree) ? tree.tree : []) {
    if (item?.type !== 'blob' || typeof item.path !== 'string' || !item.path.endsWith('.t27')) continue
    if (item.path.split('/').some((s) => s === '.git' || s === '.claude' || s === '.' || s === '..' || s === '')) continue
    if (Number.isFinite(item.size) && item.size > f.MAX_FILE_BYTES) { skippedLarge++; continue }
    paths.push(item.path)
  }
  paths.sort()
  return { paths, skippedLarge, truncated: tree?.truncated === true }
}

/**
 * Up to n paths to compile: the specs/ group first -- that is where a spec repository keeps
 * its specs -- then the rest, each group in path order and sampled evenly rather than cut at
 * the front. trinity-fpga's first three specs by name parse to empty modules under the
 * vendored compiler while 26 of its 64 do not; an unlucky prefix must not hide a world.
 */
export function probeOrder(paths, n) {
  const isSpec = (p) => p === 'specs' || p.startsWith('specs/') || p.includes('/specs/')
  const sorted = [...paths].sort()
  const spread = (list, k) => {
    if (k <= 0) return []
    if (list.length <= k) return list
    if (k === 1) return [list[0]]
    return [...new Set(Array.from({ length: k }, (_, i) => Math.round((i * (list.length - 1)) / (k - 1))))].map((i) => list[i])
  }
  const specs = spread(sorted.filter(isSpec), n)
  return [...specs, ...spread(sorted.filter((p) => !isSpec(p)), n - specs.length)]
}

/** Declarations anywhere in the tree the compiler built. Text that is not t27 yields an empty module: 0. */
export function declarationsOf(analysis) {
  let n = 0
  const walk = (node) => { if (DECLARATION_KINDS.has(node.kind)) n++; for (const c of node.children ?? []) walk(c) }
  if (analysis?.ast) walk(analysis.ast)
  return n
}

/**
 * Where a world's files live under public/t27/files and how its entries name it. The five
 * founding sources use the bare repository name (tri-net/, trinity-fpga/ ...); every other
 * gHashTag repository follows that convention, and another owner's repository carries the
 * owner too, so two owners with a repository of the same name cannot collide.
 */
export function worldPrefix(repo) {
  if (!REPO_RE.test(repo)) throw new Error(`invalid repository ${repo}`)
  const [owner, name] = repo.split('/')
  return owner === 'ghashtag' ? name : `${owner}/${name}`
}

/**
 * The manifest with one world's entries replaced. Pure: `manifest` is not mutated. Refuses a
 * founding repository, a duplicate path, and an entry whose repo label is not the world's.
 */
export function mergeWorld(manifest, world, entries, f) {
  if (f.FOUNDING.includes(world.repo)) throw new Error(`${world.repo} is a founding source; use sync-t27-specs.mjs`)
  if (!SHA_RE.test(world.commit)) throw new Error(`${world.repo}: commit must be a 40-hex sha`)
  const label = worldPrefix(world.repo)
  const kept = manifest.specs.filter((e) => e.repo !== label)
  const paths = new Set(kept.map((e) => e.path))
  for (const e of entries) {
    if (e.repo !== label) throw new Error(`${e.path}: repo label ${e.repo} is not ${label}`)
    if (!e.path.startsWith(`${label}/`)) throw new Error(`${e.path}: outside ${label}/`)
    if (paths.has(e.path)) throw new Error(`${e.path}: duplicate path`)
    paths.add(e.path)
  }
  const specs = [...kept, ...[...entries].sort((a, b) => (a.path < b.path ? -1 : a.path > b.path ? 1 : 0))]
  const aggregates = corpusAggregates(specs)
  const repos = manifest.repos.filter((r) => r.repo !== label)
  const record = { repo: label, commit: world.commit, specs: entries.length, discoveredAt: world.at, duplicatesSkipped: world.duplicatesSkipped ?? 0 }
  if (entries.length) repos.push(record)
  const prior = manifest.discovery?.worlds?.filter((w) => w.repo !== world.repo) ?? []
  const discovery = {
    spec: { path: SPEC, sha256: world.specSha256 },
    at: world.at,
    worlds: [...prior, ...(entries.length ? [{ repo: world.repo, label, commit: world.commit, branch: world.branch, specs: entries.length, files: world.files ?? entries.length, duplicatesSkipped: world.duplicatesSkipped ?? 0, skippedLarge: world.skippedLarge ?? 0, at: world.at }] : [])]
      .sort((a, b) => (a.repo < b.repo ? -1 : a.repo > b.repo ? 1 : 0)),
  }
  const { generatedFrom, wasmBytes, duplicatesSkipped, featured } = manifest
  return {
    generatedFrom, wasmBytes,
    specCount: specs.length,
    totalLines: aggregates.totalLines,
    categories: aggregates.categories,
    repos, duplicatesSkipped,
    tags: aggregates.tags,
    health: aggregates.health,
    backendFailures: aggregates.backendFailures,
    featured,
    totals: aggregates.totals,
    discovery,
    specs,
  }
}

// ---------------------------------------------------------------------------
// GitHub, through the gh CLI the other catalog scripts use. Public reads only.
// ---------------------------------------------------------------------------
const gh = (args) => JSON.parse(execFileSync('gh', args, { encoding: 'utf8', timeout: 120000, maxBuffer: 60 * 1024 * 1024 }))
const sleep = (ms) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms)
const assertRepo = (repo) => { if (!REPO_RE.test(repo)) throw new Error(`invalid repository ${repo}`) }

function ownerInventory(owner) {
  if (!OWNER_RE.test(owner)) throw new Error(`invalid owner ${owner}`)
  const pages = gh(['api', `users/${owner}/repos?per_page=100&type=owner&sort=full_name`, '--paginate', '--slurp'])
  return { pages: pages.length, repos: pages.flat().map(repoIdentity).filter(Boolean) }
}

function codeSearch(f) {
  const repos = new Set()
  let totalCount = null, pages = 0, status = 'ok', error = null
  try {
    for (let page = 1; page <= f.CODE_SEARCH_PAGES; page++) {
      if (page > 1) sleep(6500) // the code-search budget is ten calls a minute
      const result = gh(['api', `search/code?q=${encodeURIComponent(f.CODE_SEARCH)}&per_page=100&page=${page}`])
      pages++
      totalCount = Number.isSafeInteger(result.total_count) ? result.total_count : totalCount
      const items = Array.isArray(result.items) ? result.items : []
      for (const item of items) { const r = String(item?.repository?.full_name ?? '').toLowerCase(); if (REPO_RE.test(r)) repos.add(r) }
      if (items.length < 100) break
    }
  } catch (e) {
    status = pages ? 'partial' : 'unavailable'
    error = String(e.message ?? e).split('\n')[0].slice(0, 200)
  }
  return { query: f.CODE_SEARCH, status, error, pages, totalCount, repos: [...repos].sort() }
}

function probeFile(repo, path, commit, analyze) {
  assertRepo(repo)
  const blob = gh(['api', `repos/${repo}/contents/${path.split('/').map(encodeURIComponent).join('/')}?ref=${commit}`])
  if (blob.encoding !== 'base64' || typeof blob.content !== 'string') return { path, bytes: blob.size ?? null, declarations: null, error: 'no-content' }
  const text = Buffer.from(blob.content, 'base64').toString('utf8')
  let declarations = 0
  try { declarations = declarationsOf(analyze(text)) } catch { declarations = 0 }
  return { path, bytes: Buffer.byteLength(text), declarations }
}

export async function scan({ out }) {
  const analyze = await loadCompiler(readFileSync(resolve(SITE, WASM)))
  const spec = loadDiscoverySpec(analyze, readFileSync(resolve(SITE, SPEC), 'utf8'))
  if (spec.problems.length) throw new Error(`contract:\n  ${spec.problems.join('\n  ')}`)
  const f = spec.fields
  const at = new Date().toISOString()
  const byRepo = new Map(), sources = new Map(), inventory = {}
  for (const owner of f.OWNERS) {
    const { pages, repos } = ownerInventory(owner)
    inventory[owner] = { pages, repos: repos.length, public: repos.filter((r) => !r.private).length }
    for (const r of repos) { byRepo.set(r.repo, r); sources.set(r.repo, [...(sources.get(r.repo) ?? []), `owner:${owner}`]) }
  }
  const search = codeSearch(f)
  const unread = []
  for (const repo of search.repos) {
    sources.set(repo, [...(sources.get(repo) ?? []), 'code-search'])
    if (byRepo.has(repo)) continue
    try { const meta = repoIdentity(gh(['api', `repos/${repo}`])); if (meta) byRepo.set(repo, meta); else unread.push(repo) } catch { unread.push(repo) }
  }
  const candidates = []
  for (const meta of [...byRepo.values()].sort((a, b) => (a.repo < b.repo ? -1 : 1))) {
    const verdict = candidateVerdict(meta, f)
    const row = { ...meta, sources: sources.get(meta.repo), ...verdict, commit: null, t27Files: 0, truncated: false, skippedLarge: 0, probed: [], qualified: false, reason: verdict.skip }
    candidates.push(row)
    if (verdict.skip) { console.error(`${meta.repo}: ${row.reason}`); continue }
    try {
      const head = gh(['api', `repos/${meta.repo}/commits/${encodeURIComponent(meta.branch)}`])
      if (!SHA_RE.test(String(head.sha))) throw new Error('head')
      row.commit = head.sha
      const listing = t27PathsOf(gh(['api', `repos/${meta.repo}/git/trees/${row.commit}?recursive=1`]), f)
      row.t27Files = listing.paths.length; row.truncated = listing.truncated; row.skippedLarge = listing.skippedLarge
      if (!listing.paths.length) { row.reason = 'no-t27-files'; console.error(`${meta.repo}: ${row.reason}`); continue }
      for (const path of probeOrder(listing.paths, f.PROBE_FILES)) {
        row.probed.push(probeFile(meta.repo, path, row.commit, analyze))
        if ((row.probed.at(-1).declarations ?? 0) >= f.MIN_DECLARATIONS) break // one declaration is the proof; the rest would be cost
      }
      row.qualified = row.probed.some((p) => (p.declarations ?? 0) >= f.MIN_DECLARATIONS)
      row.reason = row.qualified ? (verdict.founding ? 'founding' : 'qualified') : 'no-declarations'
    } catch (e) {
      row.reason = 'github-read-failed'; row.error = String(e.message ?? e).split('\n')[0].slice(0, 200)
    }
    console.error(`${meta.repo}: ${row.reason}${row.t27Files ? ` (${row.t27Files} .t27)` : ''}`)
  }
  const qualified = candidates.filter((c) => c.qualified && !c.founding).map((c) => c.repo)
  const worlds = qualified.slice(0, f.MAX_WORLDS)
  const report = {
    version: 1, at,
    spec: { path: SPEC, sha256: spec.sha256, module: spec.moduleName, tests: spec.tests.tests, asserts: spec.tests.asserts },
    constants: f,
    owners: f.OWNERS, inventory, codeSearch: search, unreadable: unread,
    scope: 'Public owner inventories and GitHub code search hits, each candidate read from its default-branch tree and probed with the vendored compiler. Not all GitHub; no private repositories; no GitHub writes.',
    candidates,
    founding: candidates.filter((c) => c.founding).map((c) => c.repo),
    worlds, overflow: qualified.slice(f.MAX_WORLDS),
    skipped: Object.fromEntries([...new Set(candidates.map((c) => c.reason))].sort().map((r) => [r, candidates.filter((c) => c.reason === r).length])),
  }
  writeFileSync(resolve(out), JSON.stringify(report, null, 2) + '\n', { flag: 'wx' })
  return report
}

export async function vendor({ report: reportPath }) {
  const report = JSON.parse(readFileSync(resolve(reportPath), 'utf8'))
  const analyze = await loadCompiler(readFileSync(resolve(SITE, WASM)))
  const specText = readFileSync(resolve(SITE, SPEC), 'utf8')
  const spec = loadDiscoverySpec(analyze, specText)
  if (spec.problems.length) throw new Error(`contract:\n  ${spec.problems.join('\n  ')}`)
  if (report.version !== 1 || report.spec?.sha256 !== spec.sha256) throw new Error('report was made under another contract; scan again')
  const f = spec.fields
  let manifest = JSON.parse(readFileSync(resolve(SITE, MANIFEST), 'utf8'))
  const root = resolve(SITE, FILES)
  const worlds = report.candidates.filter((c) => report.worlds.includes(c.repo) && c.qualified && !c.founding && !c.skip)
  const refreshed = new Set(worlds.map((w) => worldPrefix(w.repo)))
  // Bytes already in the catalog, from the entries that stay: a spec vendored twice is a lie.
  const known = new Map()
  for (const e of manifest.specs) if (!refreshed.has(e.repo)) known.set(sha256(readFileSync(join(root, e.path))), e.path)
  const summary = []
  for (const world of worlds) {
    assertRepo(world.repo); if (!SHA_RE.test(world.commit)) throw new Error(`${world.repo}: bad commit`)
    const label = worldPrefix(world.repo)
    const dir = mkdtempSync(join(tmpdir(), `t27-world-`))
    try {
      execFileSync('sh', ['-c', `gh api "repos/${world.repo}/tarball/${world.commit}" > "${dir}/a.tar.gz" && tar -xzf "${dir}/a.tar.gz" -C "${dir}"`], { stdio: 'ignore' })
      const inner = execFileSync('sh', ['-c', `ls -d "${dir}"/*/ | head -1`], { encoding: 'utf8' }).trim().replace(/\/$/, '')
      const found = execFileSync('find', [inner, '-name', '*.t27', '-type', 'f', '-not', '-path', `${inner}/.git/*`, '-not', '-path', `${inner}/.claude/*`], { encoding: 'utf8' })
        .split('\n').filter(Boolean).sort().slice(0, f.MAX_FILES_PER_WORLD)
      const entries = []
      let duplicates = 0, skippedLarge = 0
      const staged = []
      for (const abs of found) {
        const bytes = readFileSync(abs)
        if (bytes.length > f.MAX_FILE_BYTES) { skippedLarge++; continue }
        const hash = sha256(bytes)
        if (known.has(hash)) { duplicates++; continue }
        const rel = `${label}/${relative(inner, abs)}`
        if (rel.split('/').some((s) => !/^[A-Za-z0-9_.-]+$/.test(s) || s === '.' || s === '..')) { skippedLarge++; continue }
        known.set(hash, rel)
        staged.push([rel, bytes])
        entries.push(corpusEntry(rel, label, bytes.toString('utf8'), analyze))
      }
      // Replace the world on disk only after every file of it was read and compiled.
      rmSync(join(root, label), { recursive: true, force: true })
      for (const [rel, bytes] of staged) { mkdirSync(dirname(join(root, rel)), { recursive: true }); writeFileSync(join(root, rel), bytes) }
      manifest = mergeWorld(manifest, { repo: world.repo, commit: world.commit, branch: world.branch, at: report.at, specSha256: spec.sha256, files: found.length, duplicatesSkipped: duplicates, skippedLarge }, entries, f)
      summary.push({ repo: world.repo, label, commit: world.commit.slice(0, 9), files: found.length, specs: entries.length, duplicates, skippedLarge, health: entries.reduce((h, e) => ({ ...h, [e.health]: (h[e.health] ?? 0) + 1 }), {}) })
    } finally { rmSync(dir, { recursive: true, force: true }) }
  }
  const dest = resolve(SITE, MANIFEST), temp = `${dest}.${process.pid}.tmp`
  writeFileSync(temp, JSON.stringify(manifest, null, 0), { flag: 'wx' }); renameSync(temp, dest)
  const registered = registerDescriptionExceptions(manifest.specs, resolve(SITE, EXCEPTIONS))
  return { worlds: summary, specCount: manifest.specCount, repos: manifest.repos.length, registered }
}

async function main() {
  const args = process.argv.slice(2), command = args.shift() ?? 'help'
  const arg = (k) => { const i = args.indexOf(k); return i < 0 ? undefined : args[i + 1] }
  try {
    if (command === 'scan') {
      if (!arg('--out')) throw new Error('--out /absolute/NEW-report.json is required')
      const report = await scan({ out: arg('--out') })
      console.log(JSON.stringify({ owners: report.owners, candidates: report.candidates.length, founding: report.founding.length, worlds: report.worlds, codeSearch: report.codeSearch.status, skipped: report.skipped }))
    } else if (command === 'vendor') {
      if (!arg('--report')) throw new Error('--report /absolute/report.json is required')
      console.log(JSON.stringify(await vendor({ report: arg('--report') })))
    } else {
      console.log('t27 world discovery (public scan, never acceptance)\n  node scripts/discover-t27-worlds.mjs scan --out /absolute/NEW-report.json\n  node scripts/discover-t27-worlds.mjs vendor --report /absolute/report.json\nThen: npm run core -- index; npm run atlas -- scan --discovery /absolute/report.json --out /absolute/NEW-atlas.json; npm run atlas -- build --report /absolute/NEW-atlas.json\nReports never overwritten. Founding sources never rewritten. No GitHub writes.')
    }
  } catch (e) {
    console.error(`discover-t27-worlds: ${e.message}`)
    process.exitCode = 1
  }
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) main()
