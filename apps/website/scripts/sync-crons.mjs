#!/usr/bin/env node
// Build the scheduled-jobs catalog: public/crons/manifest.json.
//
//   node scripts/sync-crons.mjs
//
// Four kinds of schedule run this platform, and until now no one place listed
// them. They live in four different systems -- Inngest cron functions, bare
// setInterval timers inside two long-lived processes, GitHub Actions across
// three repositories, and a Railway service whose schedule is set in a web
// dashboard -- and the only way to answer "what runs at 09:00?" was to grep
// three checkouts and then log in and look.
//
// Everything except the Railway dashboard is read from source on disk, so the
// answer is the code rather than a wiki page that drifts. The manifest records
// the exact commit of each repository, and the page shows it.
//
// The two claims this script deliberately does NOT make:
//   - that a job is running. A schedule in a file says when it WOULD fire.
//     GitHub Actions in the bot repository, for one, have not fired since
//     billing lapsed, and those rows say so rather than showing green.
//   - that an unresolved period is some default. A period the scan cannot read
//     stays undefined and only its raw text is published.
//
// Every entry needs a line in scripts/crons-annotations.json saying what it
// does. A new timer with no annotation fails this script rather than shipping
// an unexplained row -- which is the mechanism that keeps the catalog from
// decaying the moment someone adds a job.

import { readFileSync, writeFileSync, mkdirSync, readdirSync, statSync, existsSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { join, resolve, dirname, relative, basename } from 'node:path'
import { fileURLToPath } from 'node:url'
import { lookup } from 'node:dns/promises'
import { get } from 'node:https'
import {
  maskComments, callArguments, resolvePeriod, extractInngestCrons, extractGithubSchedules,
  entryTags, checkAnnotations, sortEntries, tally,
} from './crons-lib.mjs'

const HERE = dirname(fileURLToPath(import.meta.url))
const WEBSITE = join(HERE, '..')
const OUT_DIR = join(WEBSITE, 'public/crons')

function fail(msg) {
  console.error(`sync-crons: ${msg}`)
  process.exit(1)
}

// ---------------------------------------------------------------------------
// The repositories
//
// `dirty` is scoped to the directories this scan actually reads. A repository
// full of unrelated scratch files is not evidence that the catalog was built
// from uncommitted schedules, and a boolean that is always true says nothing.
// ---------------------------------------------------------------------------
const REPOS = [
  {
    name: '999-multibots-telegraf',
    root: process.env.BOT_ROOT || '/Users/playom/999-multibots-telegraf',
    private: true,
    scan: ['src', 'apps/vibee-editor/render', '.github/workflows'],
  },
  {
    name: 't27',
    root: process.env.T27_ROOT || '/Users/playom/t27',
    private: false,
    scan: ['.github/workflows'],
  },
  {
    name: 'trinity',
    root: process.env.TRINITY_ROOT || resolve(WEBSITE, '../..'),
    private: false,
    scan: ['.github/workflows'],
  },
]

const git = (root, args) => execFileSync('git', ['-C', root, ...args], { encoding: 'utf8' }).trim()

for (const repo of REPOS) {
  if (!existsSync(repo.root)) fail(`${repo.name} not found at ${repo.root}`)
  repo.commit = git(repo.root, ['rev-parse', 'HEAD'])
  repo.branch = git(repo.root, ['rev-parse', '--abbrev-ref', 'HEAD'])
  const paths = repo.scan.filter((p) => existsSync(join(repo.root, p)))
  repo.dirty = git(repo.root, ['status', '--porcelain', '--', ...paths]).length > 0
}

const byName = Object.fromEntries(REPOS.map((r) => [r.name, r]))
const BOT = byName['999-multibots-telegraf']

const sourceUrl = (repo, file, line) =>
  `https://github.com/gHashTag/${repo.name}/blob/${repo.commit}/${file}#L${line}`

// ---------------------------------------------------------------------------
// Walking a source tree
// ---------------------------------------------------------------------------
const SKIP_DIRS = new Set(['node_modules', 'dist', 'build', '__tests__', '.git', 'coverage'])

function walk(dir, out = []) {
  for (const name of readdirSync(dir).sort()) {
    const path = join(dir, name)
    const stat = statSync(path)
    if (stat.isDirectory()) {
      if (SKIP_DIRS.has(name)) continue
      walk(path, out)
      continue
    }
    if (!name.endsWith('.ts') || name.endsWith('.d.ts')) continue
    if (name.endsWith('.test.ts') || name.endsWith('.spec.ts')) continue
    out.push(path)
  }
  return out
}

const read = (path) => readFileSync(path, 'utf8')
const lineOf = (masked, index) => masked.slice(0, index).split('\n').length

const entries = []

// ---------------------------------------------------------------------------
// 1. Inngest cron functions
// ---------------------------------------------------------------------------
for (const path of walk(join(BOT.root, 'src'))) {
  const text = read(path)
  if (!text.includes('createFunction')) continue
  const file = relative(BOT.root, path)
  for (const found of extractInngestCrons(maskComments(text))) {
    if (!found.functionId) {
      console.log(`  warning: ${file}:${found.line} has a cron with no function id, skipped`)
      continue
    }
    entries.push({
      id: `inngest/${BOT.name}/${found.functionId}`,
      kind: 'inngest',
      repo: BOT.name,
      name: found.functionId,
      schedule: { kind: 'cron', expr: found.expr, tz: 'UTC' },
      where: { file, line: found.line, host: `railway:${BOT.name}`, service: 'inngest' },
      sourceUrl: sourceUrl(BOT, file, found.line),
      repoPrivate: BOT.private,
      probe: null,
      health: 'ok',
    })
  }
}

// ---------------------------------------------------------------------------
// 2. Process timers
//
// A `setInterval` is a schedule when the process keeps it for its whole life,
// and is not one when a request handler starts it and clears it again a minute
// later. Nothing in the syntax separates the two, so the ones that are NOT
// schedules are named here, each with the reason. The list is a deny-list on
// purpose: a new timer that nobody classified shows up in the scan, has no
// annotation, and fails the run -- whereas an allow-list would silently miss it.
//
// Each excuse names its exact LINE, never a file alone. A file-wide excuse goes
// on excusing that file forever: a real standing timer added twenty lines below
// the per-request poller would leave the catalog without a word -- the one
// failure this whole script exists to prevent. Pinning costs an excuse that
// goes stale when the file shifts, and a stale excuse is reported by line and
// by reason below rather than quietly ceasing to apply.
// ---------------------------------------------------------------------------
const NOT_A_SCHEDULE = [
  {
    file: 'src/core/lipsync/async-lipsync-manager.ts',
    line: 937,
    why: 'polls one lipsync job and clears itself when that job finishes',
  },
  {
    file: 'src/handlers/handleTextToVideoDirect.ts',
    line: 348,
    why: 'polls one video generation for the request that started it',
  },
  {
    file: 'src/helpers/telegramLongAnswer.ts',
    line: 102,
    why: 'keeps the "typing" indicator alive for a single answer; the caller stops it',
  },
  {
    file: 'apps/vibee-editor/render/src/graceful-shutdown.ts',
    line: 51,
    why: 'runs only between the shutdown signal and the last connection closing',
  },
  {
    file: 'apps/vibee-editor/render/render-server.ts',
    line: 5732,
    why: 'started inside a request handler, per request, and cleared with it',
  },
]
const excusesUsed = new Set()

const TIMER_ROOTS = [
  { dir: 'src', host: `railway:${'999-multibots-telegraf'}`, service: 'bot' },
  { dir: 'apps/vibee-editor/render', host: 'railway:vibee-render', service: 'render' },
]

// Where a period is passed in rather than written at the timer. The scan reads
// the caller's own text for the default -- it does not carry a number of its
// own, so a change at the call site changes the catalog.
const PERIOD_CALLERS = {
  'src/services/crmProactive.ts': ['src/index.ts'],
}

const timerFiles = new Set()
for (const root of TIMER_ROOTS) {
  const base = join(BOT.root, root.dir)
  if (!existsSync(base)) fail(`${root.dir} not found under ${BOT.root}`)
  for (const path of walk(base)) {
    const file = relative(BOT.root, path)
    if (timerFiles.has(file)) continue
    const text = read(path)
    if (!text.includes('setInterval')) continue
    timerFiles.add(file)
    const masked = maskComments(text)
    const callers = (PERIOD_CALLERS[file] ?? []).map((f) => read(join(BOT.root, f)))
    const re = /\bsetInterval\s*\(/g
    let m
    while ((m = re.exec(masked))) {
      const open = masked.indexOf('(', m.index)
      const line = lineOf(masked, m.index)
      const excused = NOT_A_SCHEDULE.find((x) => x.file === file && x.line === line)
      if (excused) {
        excusesUsed.add(`${excused.file}:${excused.line}`)
        continue
      }
      const raw = (callArguments(masked, open)[1] ?? '').trim()
      const everyMs = resolvePeriod(raw, [text, ...callers])
      if (everyMs === undefined) {
        console.log(`  note: ${file}:${line} period "${raw}" is not readable from source; raw text only`)
      }
      const slug = `${basename(file).replace(/\.ts$/, '')}-L${line}`
      entries.push({
        id: `timer/${BOT.name}/${slug}`,
        kind: 'timer',
        repo: BOT.name,
        name: slug,
        schedule: { kind: 'interval', ...(everyMs === undefined ? {} : { everyMs }), raw, tz: 'UTC' },
        where: { file, line, host: root.host, service: root.service },
        sourceUrl: sourceUrl(BOT, file, line),
        repoPrivate: BOT.private,
        probe: null,
        health: 'ok',
      })
    }
  }
}

const staleExcuses = NOT_A_SCHEDULE.filter((x) => !excusesUsed.has(`${x.file}:${x.line}`))
if (staleExcuses.length) {
  console.error(`sync-crons: ${staleExcuses.length} entr(ies) in NOT_A_SCHEDULE no longer match a timer:`)
  for (const x of staleExcuses) console.error(`  ${x.file}:${x.line} -- ${x.why}`)
  fail('the timer moved or went away; re-pin the line or drop the entry')
}

// ---------------------------------------------------------------------------
// 3. GitHub Actions
// ---------------------------------------------------------------------------
const ACTIONS_DEAD =
  'GitHub Actions on this repository have not run since 2026-06-02 (billing); ' +
  'the schedule stands in the file but does not fire.'

for (const repo of REPOS) {
  const dir = join(repo.root, '.github/workflows')
  if (!existsSync(dir)) continue
  for (const name of readdirSync(dir).sort()) {
    if (!name.endsWith('.yml') && !name.endsWith('.yaml')) continue
    const file = `.github/workflows/${name}`
    const { name: title, crons } = extractGithubSchedules(read(join(dir, name)))
    const stem = name.replace(/\.ya?ml$/, '')
    crons.forEach((cron, i) => {
      const slug = i === 0 ? stem : `${stem}-${i + 1}`
      entries.push({
        id: `github-actions/${repo.name}/${slug}`,
        kind: 'github-actions',
        repo: repo.name,
        name: crons.length > 1 && title ? `${title} (${i + 1})` : title || stem,
        schedule: { kind: 'cron', expr: cron.expr, tz: 'UTC' },
        where: { file, line: cron.line, host: 'github-actions', service: null },
        sourceUrl: sourceUrl(repo, file, cron.line),
        repoPrivate: repo.private,
        probe: null,
        health: repo.name === BOT.name ? 'warn' : 'ok',
        note: repo.name === BOT.name ? ACTIONS_DEAD : null,
      })
    })
  }
}

// ---------------------------------------------------------------------------
// 4. Railway
//
// The one source that is not a checkout. A Railway cron's schedule is set in
// the dashboard and is not in any file here, so the entry says that plainly
// instead of printing an expression nobody can verify. What CAN be checked from
// here is whether the service answers, and that is what the probe does.
// ---------------------------------------------------------------------------
const RAILWAY = JSON.parse(read(join(HERE, 'railway-services.json')))
const RAILWAY_NOTE =
  'The schedule is configured in the Railway dashboard for project ' +
  `${RAILWAY.project} and is not readable from the checkout; the probe below is what this catalog can verify.`

const HTTP_TIMEOUT_MS = 6000

function httpStatus(url) {
  return new Promise((done) => {
    const req = get(url, { timeout: HTTP_TIMEOUT_MS }, (res) => {
      done(res.statusCode ?? null)
      res.resume()
      res.destroy()
    })
    req.on('timeout', () => { req.destroy(); done(null) })
    req.on('error', () => done(null))
  })
}

/**
 * Does the first domain of a service resolve, and does it answer?
 *
 * Two separate facts, kept separate. A name that does not resolve is a
 * different failure from a name that resolves and then refuses the connection,
 * and collapsing them into one "down" would hide which one to go and fix.
 */
async function probeDomain(domain) {
  const url = `https://${domain}/`
  const at = new Date().toISOString()
  let dns = false
  try {
    await lookup(domain)
    dns = true
  } catch {
    dns = false
  }
  return { url, dns, http: dns ? await httpStatus(url) : null, at }
}

const hosts = []
for (const service of RAILWAY.services) {
  if (service.role === 'store' || !service.domains.length) continue
  const p = await probeDomain(service.domains[0])
  hosts.push({ name: service.name, role: service.role, domain: service.domains[0], dns: p.dns, http: p.http, at: p.at })
  if (service.role !== 'cron') continue
  entries.push({
    id: `railway-cron/${RAILWAY.project}/${service.name}`,
    kind: 'railway-cron',
    repo: 'railway',
    name: service.name,
    schedule: { kind: 'cron', tz: 'UTC' },
    where: { file: null, line: null, host: `railway:${service.name}`, service: service.name },
    sourceUrl: null,
    repoPrivate: true,
    probe: p,
    health: !p.dns ? 'fail' : p.http === null ? 'warn' : 'ok',
    note: RAILWAY_NOTE,
  })
}
for (const service of RAILWAY.services) {
  if (service.role !== 'cron' || service.domains.length) continue
  fail(`railway service ${service.name} has role cron but no domain to probe`)
}

// ---------------------------------------------------------------------------
// One id, one schedule
//
// A timer's id is its file's base name and its line, so two files with the same
// base name can collide. `resolveManifestCron` refuses an ambiguous id and the
// page then shows neither job -- fail here instead, where the two files can be
// named.
// ---------------------------------------------------------------------------
const byId = new Map()
for (const entry of entries) {
  const first = byId.get(entry.id)
  if (first) {
    fail(
      `two schedules claim the id ${entry.id}: ` +
        `${first.where.file}:${first.where.line} and ${entry.where.file}:${entry.where.line}`,
    )
  }
  byId.set(entry.id, entry)
}

// ---------------------------------------------------------------------------
// The annotation gate
// ---------------------------------------------------------------------------
const ANNOTATIONS_PATH = join(HERE, 'crons-annotations.json')
const annotations = JSON.parse(read(ANNOTATIONS_PATH))
const { missing, stale } = checkAnnotations(entries.map((e) => e.id), annotations)

if (missing.length) {
  console.error(`sync-crons: ${missing.length} scheduled job(s) have no annotation in ${relative(WEBSITE, ANNOTATIONS_PATH)}:`)
  for (const id of missing) console.error(`  ${id}`)
  console.error('Add {"what": "<one English sentence>"} for each, then run again.')
  process.exit(1)
}
for (const id of stale) console.log(`  warning: annotation for ${id} matches nothing in the scan`)

for (const entry of entries) {
  const note = annotations[entry.id].note ?? null
  entry.what = annotations[entry.id].what
  // A note the scan produced (a dead runner, a schedule that lives elsewhere)
  // outranks the hand-written one: it is the fact the reader most needs.
  entry.note = entry.note ?? note
  entry.tags = entryTags(entry)
}

// ---------------------------------------------------------------------------
// The manifest
// ---------------------------------------------------------------------------
const FEATURED = entries.find((e) => e.kind === 'inngest' && e.id.endsWith('/daily-sales-advisor'))
if (!FEATURED) fail('the daily sales advisor was not found in the scan; nothing to feature')

const crons = sortEntries(entries)
const health = { ok: 0, warn: 0, fail: 0 }
for (const e of crons) health[e.health]++

mkdirSync(OUT_DIR, { recursive: true })
writeFileSync(join(OUT_DIR, 'manifest.json'), JSON.stringify({
  version: 1,
  generatedAt: new Date().toISOString(),
  generatedFrom: REPOS.map((r) => ({
    repo: `gHashTag/${r.name}`,
    commit: r.commit,
    shortCommit: r.commit.slice(0, 9),
    branch: r.branch,
    dirty: r.dirty,
    private: r.private,
  })),
  cronCount: crons.length,
  byKind: tally(crons.map((e) => e.kind)),
  byRepo: tally(crons.map((e) => e.repo)),
  byHost: tally(crons.map((e) => e.where.host)),
  tags: tally(crons.flatMap((e) => e.tags)),
  health,
  featured: FEATURED.id,
  crons,
  hosts,
}, null, 2) + '\n')

console.log(`sync-crons: ${crons.length} scheduled jobs -> public/crons/manifest.json`)
console.log(`  kinds: ${Object.entries(tally(crons.map((e) => e.kind))).map(([k, n]) => `${n} ${k}`).join(' · ')}`)
console.log(`  health: ${health.ok} ok · ${health.warn} warn · ${health.fail} fail`)
for (const r of REPOS) console.log(`  ${r.name} @ ${r.commit.slice(0, 9)} (${r.branch})${r.dirty ? ' DIRTY' : ''}`)
for (const h of hosts) console.log(`  probe ${h.domain}: dns ${h.dns ? 'ok' : 'FAIL'}, http ${h.http ?? 'no answer'}`)
const unresolved = crons.filter((e) => e.schedule.kind === 'interval' && e.schedule.everyMs === undefined)
if (unresolved.length) console.log(`  warning: ${unresolved.length} interval(s) published with raw text only`)
