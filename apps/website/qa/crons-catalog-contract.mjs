// The scheduled-jobs catalog, checked against what it claims.
//
// The page's whole value is that it is not a hand-kept list: every row names a
// file and a line, and every schedule was read out of that file. So the gate
// asks the two questions a hand-kept list always fails: does the cited line
// still exist, and does it still say what the manifest says it says?
//
// It also refuses the thing a public page must never carry: a person's
// telegram id, a server address, or anything shaped like a credential.

import assert from 'node:assert/strict'
import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { canonicalCronUrl, cronExplorerHash, describeCron, describeInterval, nextRuns, parseCron, resolveManifestCron, validCronId } from '../src/lib/cronsCatalog.ts'

const manifest = JSON.parse(readFileSync('public/crons/manifest.json', 'utf8'))
const KINDS = new Set(['railway-cron', 'inngest', 'timer', 'github-actions'])
const HEALTH = new Set(['ok', 'warn', 'fail'])

const ROOTS = {
  '999-multibots-telegraf': process.env.BOT_ROOT || '/Users/playom/999-multibots-telegraf',
  t27: process.env.T27_ROOT || '/Users/playom/t27',
  trinity: process.env.TRINITY_ROOT || new URL('../../..', import.meta.url).pathname,
}

assert.equal(manifest.version, 1)
assert.equal(manifest.cronCount, manifest.crons.length, 'the count and the list must agree')
assert.ok(manifest.crons.length > 0, 'an empty catalog would say the farm runs nothing')

// A telegram id, a bare IPv4 address or a credential has no place on a public page.
const FORBIDDEN = [
  { name: 'telegram id', re: /\b\d{9,10}\b/ },
  { name: 'IPv4 address', re: /\b(?:\d{1,3}\.){3}\d{1,3}\b/ },
  { name: 'bearer token', re: /Bearer\s+[A-Za-z0-9._-]{10,}/ },
  { name: 'bot token', re: /\b\d{8,10}:[A-Za-z0-9_-]{35}\b/ },
  { name: 'url credential', re: /:\/\/[^\s/:@]+:[^\s@]+@/ },
]
const asText = JSON.stringify(manifest)
for (const { name, re } of FORBIDDEN) {
  const hit = re.exec(asText)
  assert.ok(!hit, `the catalog carries something shaped like a ${name} (${hit ? hit[0].slice(0, 4) : ''}…) — it must not`)
}

let checkedSource = 0
const seen = new Set()
for (const entry of manifest.crons) {
  assert.ok(validCronId(entry.id), `invalid id: ${entry.id}`)
  assert.ok(!seen.has(entry.id), `duplicate id: ${entry.id}`)
  seen.add(entry.id)
  assert.ok(KINDS.has(entry.kind), `unknown kind on ${entry.id}: ${entry.kind}`)
  assert.ok(HEALTH.has(entry.health), `unknown health on ${entry.id}: ${entry.health}`)
  assert.equal(typeof entry.name, 'string')
  assert.ok(entry.what && entry.what.length > 10, `${entry.id} says nothing about what it does`)
  assert.equal(resolveManifestCron(manifest, entry.id).id, entry.id)
  assert.ok(entry.tags.includes(`kind/${entry.kind}`), `${entry.id} is not tagged by its kind`)
  assert.ok(entry.tags.includes(`health/${entry.health}`), `${entry.id} is not tagged by its health`)

  // The schedule has to be readable, in both languages, and produce real dates.
  if (entry.schedule.kind === 'cron' && entry.schedule.expr) {
    assert.ok(parseCron(entry.schedule.expr), `${entry.id}: unparsable cron ${entry.schedule.expr}`)
    const runs = nextRuns(entry.schedule.expr, new Date(), 3)
    assert.equal(runs.length, 3, `${entry.id}: no future runs from ${entry.schedule.expr}`)
    assert.ok(runs[0] < runs[1] && runs[1] < runs[2], `${entry.id}: runs are not in order`)
    for (const lang of ['en', 'ru']) assert.ok(describeCron(entry.schedule.expr, lang).length > 0)
  } else if (entry.schedule.kind === 'interval') {
    assert.ok(entry.schedule.everyMs || entry.schedule.raw, `${entry.id}: an interval with neither a period nor its source text`)
    if (entry.schedule.everyMs) {
      assert.ok(entry.schedule.everyMs > 0, `${entry.id}: a non-positive period`)
      for (const lang of ['en', 'ru']) assert.ok(describeInterval(entry.schedule.everyMs, lang).length > 0)
    }
  }

  // The cited line still exists, and still carries the thing that was read.
  if (entry.where.file && entry.where.line) {
    const root = ROOTS[entry.repo] ?? ROOTS[entry.repo.replace('gHashTag/', '')]
    if (root && existsSync(join(root, entry.where.file))) {
      const lines = readFileSync(join(root, entry.where.file), 'utf8').split('\n')
      const line = lines[entry.where.line - 1] ?? ''
      const near = lines.slice(Math.max(0, entry.where.line - 3), entry.where.line + 2).join('\n')
      if (entry.kind === 'inngest') {
        assert.ok(near.includes('cron'), `${entry.id}: ${entry.where.file}:${entry.where.line} no longer declares a cron`)
        if (entry.schedule.expr) assert.ok(near.includes(entry.schedule.expr), `${entry.id}: the expression at that line is not ${entry.schedule.expr}`)
      } else if (entry.kind === 'timer') {
        assert.ok(near.includes('setInterval'), `${entry.id}: ${entry.where.file}:${entry.where.line} is no longer a timer`)
      } else if (entry.kind === 'github-actions') {
        assert.ok(near.includes('cron'), `${entry.id}: ${entry.where.file}:${entry.where.line} no longer carries a schedule`)
      }
      assert.ok(line !== undefined)
      checkedSource += 1
    }
  }

  // A private repository gets no public link; a public one gets a real link.
  if (entry.sourceUrl) assert.match(entry.sourceUrl, /^https:\/\/github\.com\/gHashTag\//)
}

// The counts on the page are sums of the list, not numbers typed beside it.
const byKind = {}
const byHealth = { ok: 0, warn: 0, fail: 0 }
for (const entry of manifest.crons) {
  byKind[entry.kind] = (byKind[entry.kind] ?? 0) + 1
  byHealth[entry.health] += 1
}
assert.deepEqual(manifest.byKind, byKind, 'byKind disagrees with the list it summarises')
assert.deepEqual(manifest.health, byHealth, 'the health counts disagree with the list')

assert.equal(resolveManifestCron(manifest, null).id, manifest.featured)
for (const bad of ['nope', '../x', 'a/b', 'a/b/c/d', 'x?y=1']) {
  assert.throws(() => resolveManifestCron(manifest, bad), `a malformed id must not fall back to the featured job: ${bad}`)
}
assert.equal(canonicalCronUrl(manifest.featured), `https://t27.ai/${cronExplorerHash(manifest.featured)}`)
assert.ok(cronExplorerHash(manifest.featured, { embedded: true }).includes('embed=1'))

console.log(`Cron catalog: PASS (${manifest.cronCount} jobs, ${checkedSource} source lines re-read, ${Object.keys(byKind).length} kinds)`)
