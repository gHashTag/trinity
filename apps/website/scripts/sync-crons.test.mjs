import assert from 'node:assert/strict'
import test from 'node:test'
import {
  maskComments, callArguments, evalPeriod, resolvePeriod, lookupDefinitions,
  cronBucket, intervalBucket, scheduleBucket,
  extractInngestCrons, extractGithubSchedules, checkAnnotations, entryTags, sortEntries,
} from './crons-lib.mjs'

// The four things this file protects are the four places the catalog could lie
// quietly: a period read as the wrong number, a period filed in the wrong
// bucket, a schedule attributed to the wrong job, and a new job shipped with no
// description at all. None of them makes the sync fail on its own.

test('evaluates the period arithmetic the repositories actually write', () => {
  assert.equal(evalPeriod('60000'), 60_000)
  assert.equal(evalPeriod('60_000'), 60_000)
  assert.equal(evalPeriod('10 * 60 * 1000'), 600_000)
  assert.equal(evalPeriod('5 * 60 * 1000'), 300_000)
  assert.equal(evalPeriod('86_400_000'), 86_400_000)
  assert.equal(evalPeriod('(30 + 30) * 1000'), 60_000)
  assert.equal(evalPeriod('60 * 60 * 1000 // an hour, matching renderJobs'), 3_600_000)
  // The two tunable idioms: the literal default is the answer, and the
  // environment variable is not readable from source.
  assert.equal(evalPeriod("Number(process.env.CRM_PROACTIVE_MINUTES ?? '30')"), 30)
  assert.equal(evalPeriod('Math.max(60_000, Number(process.env.AUTOPILOT_INTERVAL_MS) || 30 * 60_000)'), 1_800_000)
  // `||` is JavaScript's `||`: a period that resolves to zero is falsy and the
  // written default wins, which is what the running process would do. `??` is
  // not `||`, and keeps the zero.
  assert.equal(evalPeriod('0 || 60_000'), 60_000)
  assert.equal(evalPeriod('0 ?? 60_000'), 0)
  // An identifier is undefined rather than a guess.
  assert.equal(evalPeriod('intervalMs'), undefined)
  assert.equal(evalPeriod(''), undefined)
})

test('resolves a period that is written somewhere else', () => {
  const service = `
    const DAY = 86_400_000
    export function startBillingMonitor(intervalMs = DAY): void {
      billingInterval = setInterval(() => { void check() }, intervalMs)
    }
  `
  assert.equal(resolvePeriod('intervalMs', [service]), 86_400_000)

  // A member expression resolves by its last segment, and the timer's own file
  // has no value to give: `everyMs: number` is a type, and the log line uses
  // the name rather than defining it. The answer is in the caller.
  const proactive = `
    interface Opts { ownerId: string; everyMs: number }
    const timer = setInterval(run, opts.everyMs)
    logger.info('started', { everyMinutes: Math.round(opts.everyMs / 60_000) })
  `
  const caller = `
    const proactiveMinutes = Number(process.env.CRM_PROACTIVE_MINUTES ?? '30')
    startCrmProactive(carrier, { ownerId, everyMs: proactiveMinutes * 60_000 })
  `
  assert.equal(resolvePeriod('opts.everyMs', [proactive, caller]), 1_800_000)
  assert.equal(resolvePeriod('opts.everyMs', [proactive]), undefined)

  assert.deepEqual(lookupDefinitions('everyMs', proactive), [])

  // When a name does have several definitions, a wrong first one must not end
  // the search -- the scan tries them in file order until one evaluates.
  const twice = `
    const opts = { everyMs: fromSomewhereElse }
    function run(everyMs = 45 * 60_000) {}
  `
  assert.deepEqual(lookupDefinitions('everyMs', twice), ['fromSomewhereElse', '45 * 60_000'])
  assert.equal(resolvePeriod('everyMs', [twice]), 2_700_000)
})

test('classifies both kinds of schedule into the same buckets', () => {
  assert.equal(cronBucket('*/15 * * * *'), 'minutes')
  assert.equal(cronBucket('0 * * * *'), 'hourly')
  assert.equal(cronBucket('0 */2 * * *'), 'hourly')
  assert.equal(cronBucket('41 5 * * *'), 'daily')
  assert.equal(cronBucket('0 3 * * 0'), 'weekly')
  assert.equal(cronBucket('0 5 1 1 *'), 'unknown')
  assert.equal(cronBucket(undefined), 'unknown')

  assert.equal(intervalBucket(30_000), 'minutes')
  assert.equal(intervalBucket(3_599_999), 'minutes')
  assert.equal(intervalBucket(3_600_000), 'hourly')
  assert.equal(intervalBucket(86_400_000), 'daily')
  assert.equal(intervalBucket(7 * 86_400_000), 'weekly')
  assert.equal(intervalBucket(undefined), 'unknown')

  assert.equal(scheduleBucket({ kind: 'cron', expr: '0 9 * * *' }), 'daily')
  assert.equal(scheduleBucket({ kind: 'interval', everyMs: 600_000 }), 'minutes')
  // A Railway cron carries no expression, and says so instead of guessing.
  assert.equal(scheduleBucket({ kind: 'cron' }), 'unknown')
})

test('attributes an Inngest cron to the function that owns it', () => {
  const module = `
export const earlier = inngest.createFunction(
  { id: 'some-other-function' },
  { event: 'thing/happened' },
  async () => {},
)

export const dailySalesAdvisor = inngest.createFunction(
  { id: 'daily-sales-advisor', retries: 1 },
  { cron: '0 9 * * *' },
  async ({ step }) => {},
)

export const unnamed = inngest.createFunction(
  { retries: 1 },
  { cron: '*/30 * * * *' },
  async () => {},
)
`
  const found = extractInngestCrons(maskComments(module))
  assert.deepEqual(found.map((f) => [f.functionId, f.expr]), [
    // Not 'some-other-function': the id has to sit inside the same call.
    ['daily-sales-advisor', '0 9 * * *'],
    // No id in the call, so the const that holds the function names it.
    ['unnamed', '*/30 * * * *'],
  ])
  assert.equal(module.split('\n')[found[0].line - 1].includes("cron: '0 9 * * *'"), true)

  // A cron written inside a comment is not a schedule.
  assert.deepEqual(extractInngestCrons(maskComments("// { cron: '0 4 * * *' }\n")), [])
})

test('reads every cron out of a workflow schedule block and nothing else', () => {
  const workflow = `name: Pages Health Check

on:
  schedule:
    - cron: '*/15 * * * *'  # Every 15 minutes
    - cron: "0 3 * * 0"
  workflow_dispatch:

jobs:
  check:
    steps:
      - name: not a schedule
        with:
          cron: '0 0 * * *'
          windows:
            - cron: '0 0 * * *'
`
  const { name, crons } = extractGithubSchedules(workflow)
  assert.equal(name, 'Pages Health Check')
  // Two, not four. The decoy on line 14 is rejected by shape -- it has no
  // leading dash -- but the one on line 16 has the exact shape of a schedule
  // and is rejected only because `workflow_dispatch:` on line 7 dedents back to
  // the schedule block's own level and ends it. Without that, a `- cron:` under
  // any later key in the file would be catalogued as a workflow schedule.
  assert.deepEqual(crons, [
    { expr: '*/15 * * * *', line: 5 },
    { expr: '0 3 * * 0', line: 6 },
  ])
  assert.deepEqual(extractGithubSchedules('on:\n  push:\n'), { name: null, crons: [] })
})

test('a job with no annotation fails the sync, a stale annotation only warns', () => {
  const ids = [
    'timer/999-multibots-telegraf/crmProactive-L375',
    'timer/999-multibots-telegraf/newTimer-L12',
  ]
  const annotations = {
    'timer/999-multibots-telegraf/crmProactive-L375': { what: 'Runs one proactive seller turn.' },
    'github-actions/trinity/deleted-workflow': { what: 'Gone.' },
  }
  const { missing, stale } = checkAnnotations(ids, annotations)
  assert.deepEqual(missing, ['timer/999-multibots-telegraf/newTimer-L12'])
  assert.deepEqual(stale, ['github-actions/trinity/deleted-workflow'])

  // The gate has to be empty for a fully annotated scan, or it would fail every
  // run and teach whoever meets it to pass --force.
  assert.deepEqual(checkAnnotations([ids[0]], { [ids[0]]: { what: 'x' } }), { missing: [], stale: [] })
})

test('splits call arguments and tags an entry the way the page facets it', () => {
  const call = "setInterval(exclusiveTick('notifications, queue', () => tick()), 60_000)"
  const args = callArguments(call, call.indexOf('('))
  assert.equal(args.length, 2)
  assert.equal(args[1].trim(), '60_000')

  const entry = {
    kind: 'timer',
    repo: '999-multibots-telegraf',
    schedule: { kind: 'interval', everyMs: 1_800_000 },
    where: { host: 'railway:vibee-render' },
    health: 'ok',
  }
  assert.deepEqual(entryTags(entry), [
    'kind/timer',
    'repo/999-multibots-telegraf',
    'host/vibee-render',
    'every/minutes',
    'health/ok',
  ])

  const order = sortEntries([
    { kind: 'timer', repo: 'a', name: 'b' },
    { kind: 'inngest', repo: 'z', name: 'a' },
    { kind: 'timer', repo: 'a', name: 'a' },
  ])
  assert.deepEqual(order.map((e) => `${e.kind}/${e.repo}/${e.name}`), [
    'inngest/z/a', 'timer/a/a', 'timer/a/b',
  ])
})

test('masking comments keeps every line where it was', () => {
  const source = 'const a = 1 // note\n/* two\n   lines */\nconst b = 2\n'
  const masked = maskComments(source)
  assert.equal(masked.length, source.length)
  assert.equal(masked.split('\n').length, source.split('\n').length)
  assert.equal(masked.split('\n')[3], 'const b = 2')
  // A string that looks like a comment survives.
  assert.equal(maskComments("const u = 'https://t27.ai/'\n").trim(), "const u = 'https://t27.ai/'")
})
