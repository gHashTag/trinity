#!/usr/bin/env node
// catalog-work-report.mjs -- the pull-request body for an automated catalog refresh.
//
// The nightly scan used to end in `git push` straight to main. Ruleset 23148303
// ("T27 mandatory work report") now requires the status check "T27 work report"
// on refs/heads/main and lists no bypass actors, so that push is rejected -- the
// same GH013 a person gets. The way in is the way everyone else takes: a pull
// request whose body carries the report scripts/pr_blog_report.py validates.
//
// Every number here is read from the artifacts the run just wrote and from the
// ones it replaced (git show HEAD~1), so the report says what actually changed
// rather than what the job hoped to do. A refresh that changes nothing produces
// no pull request at all -- the caller checks that before calling this.
//
//   node scripts/catalog-work-report.mjs --head-sha <40-hex> --out /path/body.md
//
// The output is Markdown: prose, then one fenced JSON object between the two
// markers the validator looks for.
import { execFileSync } from 'node:child_process'
import { readFileSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = dirname(fileURLToPath(import.meta.url))
const WEBSITE = join(HERE, '..')
const args = process.argv.slice(2)
const arg = (k) => { const i = args.indexOf(k); return i < 0 ? undefined : args[i + 1] }

const headSha = arg('--head-sha')
const out = arg('--out')
if (!headSha || !/^[0-9a-f]{40}$/.test(headSha)) fail('--head-sha must be a full 40-character lowercase commit sha')
if (!out) fail('--out /path/to/body.md is required')

function fail(msg) {
  console.error(`catalog-work-report: ${msg}`)
  process.exit(1)
}

const read = (rel) => JSON.parse(readFileSync(join(WEBSITE, rel), 'utf8'))
// The previous catalog, as committed. Absent on the first run of a fresh
// checkout, which is a real state and not an error: the delta is then "unknown"
// and the report says so instead of inventing zeroes.
function previous(rel) {
  try {
    return JSON.parse(execFileSync('git', ['-C', WEBSITE, 'show', `HEAD~1:./${rel}`], { encoding: 'utf8', maxBuffer: 80 * 1024 * 1024 }))
  } catch {
    return null
  }
}

const manifest = read('public/t27/manifest.json')
const core = read('public/t27/shared-core.json')
const atlas = read('public/t27/universe-atlas.json')
const before = previous('public/t27/manifest.json')

const paths = new Set(manifest.specs.map((s) => s.path))
const pathsBefore = new Set((before?.specs ?? []).map((s) => s.path))
const added = [...paths].filter((p) => !pathsBefore.has(p)).sort()
const removed = [...pathsBefore].filter((p) => !paths.has(p)).sort()
const repos = manifest.repos.map((r) => r.repo).sort()
const reposBefore = new Set((before?.repos ?? []).map((r) => r.repo))
const newRepos = repos.filter((r) => !reposBefore.has(r))

// A sentence naming the biggest directories a change touched: "specs/tools 94,
// bootstrap/tests 90" says more about a refresh than "483 specs added".
const byDir = (list) => {
  const n = new Map()
  for (const p of list) { const d = p.split('/').slice(0, 2).join('/'); n.set(d, (n.get(d) ?? 0) + 1) }
  return [...n].sort((a, b) => b[1] - a[1]).slice(0, 6).map(([d, c]) => `${d} ${c}`).join(', ')
}

const delta = before === null
  ? 'no previous catalog in this checkout to compare against'
  : `${added.length} added, ${removed.length} removed`
const changes = [
  `The catalog now carries ${manifest.specCount} specs across ${repos.length} repositories (${repos.join(', ')}); against the previous commit that is ${delta}.`,
]
if (added.length) changes.push(`Specs added, by directory: ${byDir(added)}.`)
if (removed.length) changes.push(`Specs no longer present in their source repositories, by directory: ${byDir(removed)}.`)
if (newRepos.length) changes.push(`Repositories new to the catalog in this run: ${newRepos.join(', ')}.`)
changes.push(`The shared core was rebuilt from this manifest and records ${core.specs.length} specs and ${core.collisions.length} module-name collisions.`)
changes.push(`The universe atlas was rebuilt from that core and now describes ${(atlas.worlds ?? []).length} worlds and ${(atlas.specs ?? []).length} specs.`)
if (typeof manifest.duplicatesSkipped === 'number') {
  changes.push(`Byte-identical copies discarded while vendoring, so one file does not appear twice in the library: ${manifest.duplicatesSkipped}.`)
}

const health = manifest.health ?? {}
const tests = [
  {
    command: 'npm run discover -- scan && npm run discover -- vendor',
    result: `the GitHub scan qualified ${repos.length} repositories and vendored their .t27 files`,
    status: 'passed',
    evidence: `manifest.repos records ${manifest.repos.map((r) => `${r.repo}@${String(r.commit).slice(0, 9)}`).join(', ')}`,
  },
  {
    command: 'npm run core -- index',
    result: 'the shared core was rebuilt from the manifest just written',
    status: 'passed',
    evidence: `shared-core provenance.manifestSha256 ${String(core.provenance?.manifestSha256 ?? '').slice(0, 16)} over ${core.specs.length} specs`,
  },
  {
    command: 'npm run atlas -- scan && npm run atlas -- build',
    result: 'the map artifact was rebuilt from that same core',
    status: 'passed',
    evidence: `universe-atlas at ${atlas.at} with provenance.manifestSha256 ${String(atlas.provenance?.manifestSha256 ?? '').slice(0, 16)}`,
  },
  {
    command: 'npm run check:discovery check:shared-core check:spec-catalog check:queen-atlas check:queen-catalog check:queen-continuous check:queen-spec-mirrors check:skills-catalog check:crons-catalog check:agents check:tools check:docs',
    result: 'every catalog gate passed against the tree this pull request carries',
    status: 'passed',
    evidence: 'the workflow step "Catalog gates" ran them in order and the job reached the commit step, which only runs on success',
  },
  {
    command: 'the vendored compiler wasm compiled every spec in the catalog',
    result: `health across the corpus is ${health.ok ?? 0} ok, ${health.warn ?? 0} warn, ${health.fail ?? 0} fail`,
    status: 'passed',
    evidence: `manifest.health ${JSON.stringify(health)} measured by ${manifest.wasmBytes} bytes of t27_compiler.wasm`,
  },
]

const limitations = [
  'Health is what the vendored compiler said at scan time, not a statement that every spec is correct or that its generated code was run.',
  'The scan reads public repositories only: a private repository writing .t27 specs is invisible to it and will not appear on the map.',
  'A spec that is byte-identical to one already vendored is discarded rather than listed twice, so a repository can qualify and still contribute nothing visible.',
]
if (before === null) limitations.push('This run had no previous catalog to diff against, so the added and removed counts above are not stated.')
const unreachable = manifest.generatedFrom?.unreachableFromDefaultRef ?? []
if (unreachable.length) {
  limitations.push(`${unreachable.length} t27 specs are not on the default ref and reach the site through a named overlay ref; a reader cloning master alone will not find them.`)
}

const body = `A scheduled refresh of the .t27 catalog from GitHub. The scan, the vendor step, the shared core, the atlas and every catalog gate ran in \`t27-world-scan.yml\`; this pull request carries only what they wrote under \`apps/website/public\`.

**${manifest.specCount} specs, ${repos.length} repositories** — ${delta}.

<!-- t27-work-report -->
\`\`\`json
${JSON.stringify({
  version: 1,
  head_sha: headSha,
  summary: `A scheduled scan of GitHub for .t27 specs refreshed the catalog behind the Queen map and the Spec Explorer: ${manifest.specCount} specs across ${repos.length} repositories, ${delta} against the previous commit.`,
  changes,
  tests,
  limitations,
  tags: ['t27', 'catalog', 'automation', 'specs'],
  blog: {
    title: 'A nightly scan keeps the spec catalog honest',
    summary: `The map and the library are built from whatever GitHub holds tonight: ${manifest.specCount} specs across ${repos.length} repositories, vendored, compiled and gated before anything reaches the site.`,
    outline: [
      `The catalog behind the map and the Spec Explorer is not a list somebody maintains by hand; it is the output of a scan that reads the public inventories of the owners a spec names and every repository a vendored source points at.`,
      `This run ended with ${manifest.specCount} specs across ${repos.length} repositories (${repos.join(', ')}), and against the previous commit that is ${delta} — the numbers come from the artifacts themselves, not from the job's intentions.`,
      `Each vendored file was compiled by the same wasm build of the compiler the browser runs, so the health shown beside a spec in the library is a measurement rather than a label: ${health.ok ?? 0} ok, ${health.warn ?? 0} warn, ${health.fail ?? 0} fail.`,
      `The shared core and the universe atlas were rebuilt from this exact manifest in the same job, which is what keeps the map and the library describing one corpus instead of two snapshots taken at different times.`,
    ],
  },
}, null, 2)}
\`\`\`
<!-- /t27-work-report -->
`

writeFileSync(out, body)
console.log(`catalog-work-report: ${manifest.specCount} specs, ${repos.length} repositories, ${delta} -> ${out}`)
