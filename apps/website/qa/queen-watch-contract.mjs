// INVITE TO WATCH: the board's half of the render's read-only watch links.
//
// Calls the decisions in src/lib/queenWatch.ts with a fetch that records what
// it was asked and answers what the render answers (gHashTag/999-multibots-
// telegraf render/src/browser/routes.ts, /api/browser/watch-links). Each rule
// below is one a wrong edit would break quietly: a token in a URL, an address
// of the wrong shape rendered as a link, a minted link nobody can see left
// live, a sixth link asked for when the server holds five.
//
//   node --experimental-strip-types qa/queen-watch-contract.mjs

import assert from 'node:assert/strict'
import { BROKER_BASE, journalLine } from '../src/lib/queenBrowser.ts'
import {
  WATCH_DEFAULT_HOURS,
  WATCH_MAX_HOURS,
  WATCH_MAX_ACTIVE,
  WATCH_LABEL_MAX,
  WATCH_HOURS_CHOICES,
  clampHours,
  cleanLabel,
  watchUrlOf,
  refusalOf,
  listWatchLinks,
  createWatchLink,
  revokeWatchLink,
  liveLinks,
  watchingNow,
  canMint,
  shouldPollWatch,
  timeLeft,
} from '../src/lib/queenWatch.ts'

const TOKEN = 'tok-abc'
const GOOD_TOKEN = 'A'.repeat(43) // base64url of 32 bytes is 43 characters
const NOW = Date.parse('2026-10-04T12:00:00Z')
const LATER = new Date(NOW + 3_600_000).toISOString()
const EARLIER = new Date(NOW - 60_000).toISOString()

/** A fetch that answers from a queue and keeps every call it was asked. */
function server(...answers) {
  const calls = []
  return {
    calls,
    env: {
      token: () => TOKEN,
      fetch: async (url, init) => {
        calls.push({ url, init })
        const a = answers.shift() ?? { status: 500, body: {} }
        if (a.throws) throw new Error('offline')
        return { ok: a.status >= 200 && a.status < 300, status: a.status, json: async () => a.body }
      },
    },
  }
}

function sentRight(call, method) {
  assert.equal(call.init.method, method)
  assert.equal(call.init.credentials, 'omit')
  assert.equal(call.init.headers.Authorization, `Bearer ${TOKEN}`)
  assert.ok(call.url.startsWith(`${BROKER_BASE}/api/browser/watch-links`))
  assert.ok(!call.url.includes(TOKEN), 'the session token never rides in a URL')
}

// 1. What the panel offers is what the server accepts.
assert.deepEqual([...WATCH_HOURS_CHOICES], [1, 24, 72])
for (const h of WATCH_HOURS_CHOICES) assert.equal(clampHours(h), h)
assert.equal(clampHours(undefined), WATCH_DEFAULT_HOURS)
assert.equal(clampHours('nope'), WATCH_DEFAULT_HOURS)
assert.equal(clampHours(0), WATCH_DEFAULT_HOURS)
assert.equal(clampHours(-5), WATCH_DEFAULT_HOURS)
assert.equal(clampHours(1000), WATCH_MAX_HOURS)
assert.equal(clampHours(Infinity), WATCH_DEFAULT_HOURS)
assert.equal(cleanLabel('  for Masha  '), 'for Masha')
assert.equal(cleanLabel('   '), null)
assert.equal(cleanLabel(42), null)
assert.equal(cleanLabel('x'.repeat(200)).length, WATCH_LABEL_MAX)
assert.equal(cleanLabel('a\nb\u0007c'), 'a b c')

// 2. The only address shown: https, /watch/<token>, nothing else in it.
const good = `https://vibee-render-production.up.railway.app/watch/${GOOD_TOKEN}`
assert.equal(watchUrlOf(good), good)
assert.equal(watchUrlOf(`https://render.example/watch/${GOOD_TOKEN}`), `https://render.example/watch/${GOOD_TOKEN}`)
for (const bad of [
  `http://vibee-render-production.up.railway.app/watch/${GOOD_TOKEN}`,
  `javascript:alert(1)//watch/${GOOD_TOKEN}`,
  `data:text/html,/watch/${GOOD_TOKEN}`,
  `https://user:pw@render.example/watch/${GOOD_TOKEN}`,
  `https://render.example/watch/${GOOD_TOKEN}?t=1`,
  `https://render.example/watch/${GOOD_TOKEN}#x`,
  `https://render.example/live/${GOOD_TOKEN}`,
  `https://render.example/watch/short`,
  `https://render.example/watch/${GOOD_TOKEN}/more`,
  'not a url',
  null,
  42,
]) {
  assert.equal(watchUrlOf(bad), null, `refused: ${String(bad)}`)
}

// 3. Refusals become words the panel has.
assert.equal(refusalOf(401), 'signin')
assert.equal(refusalOf(403), 'person')
assert.equal(refusalOf(409), 'full')
assert.equal(refusalOf(400), 'bad')
assert.equal(refusalOf(404), 'gone')
assert.equal(refusalOf(502), 'failed')

// 4. Signed out: nothing is sent at all.
{
  let asked = 0
  const env = { token: () => null, fetch: async () => (asked++, { ok: true, status: 200, json: async () => ({}) }) }
  assert.deepEqual(await listWatchLinks(env), { ok: false, why: 'signin' })
  assert.deepEqual(await createWatchLink(env, {}), { ok: false, why: 'signin' })
  assert.deepEqual(await revokeWatchLink(env, 'abcdef012345'), { ok: false, why: 'signin' })
  assert.equal(asked, 0)
}

// 5. The list: one header, malformed rows dropped, no token in any row.
{
  const row = (over = {}) => ({
    id: 'abcdef012345',
    label: 'for Masha',
    createdAt: EARLIER,
    expiresAt: LATER,
    revoked: false,
    live: true,
    views: 3,
    watchingNow: 1,
    lastViewAt: EARLIER,
    ...over,
  })
  const s = server({
    status: 200,
    body: { ok: true, links: [row(), row({ id: 'NOT-AN-ID' }), null, row({ id: '0123456789ab', watchingNow: -4 })] },
  })
  const r = await listWatchLinks(s.env)
  assert.equal(r.ok, true)
  assert.equal(r.value.length, 2)
  assert.equal(r.value[1].watchingNow, 0, 'a negative count is no count')
  for (const l of r.value) assert.ok(!('url' in l) && !('token' in l))
  sentRight(s.calls[0], 'GET')
  assert.equal(s.calls[0].init.body, undefined)

  const wrong = server({ status: 200, body: { ok: true, links: 'nope' } })
  assert.deepEqual(await listWatchLinks(wrong.env), { ok: false, why: 'failed' })
  const offline = server({ throws: true })
  assert.deepEqual(await listWatchLinks(offline.env), { ok: false, why: 'failed' })
  const agent = server({ status: 403, body: { ok: false } })
  assert.deepEqual(await listWatchLinks(agent.env), { ok: false, why: 'person' })
}

// 6. Minting: clamped hours, cleaned label, JSON body, the address checked.
{
  const s = server({ status: 200, body: { ok: true, id: 'abcdef012345', url: good, expiresAt: LATER } })
  const r = await createWatchLink(s.env, { hours: 500, label: '  for Masha ' })
  assert.deepEqual(r, { ok: true, value: { id: 'abcdef012345', url: good, expiresAt: LATER } })
  sentRight(s.calls[0], 'POST')
  assert.equal(s.calls[0].init.headers['Content-Type'], 'application/json')
  assert.deepEqual(JSON.parse(s.calls[0].init.body), { hours: WATCH_MAX_HOURS, label: 'for Masha' })

  const noLabel = server({ status: 200, body: { ok: true, id: 'abcdef012345', url: good, expiresAt: LATER } })
  await createWatchLink(noLabel.env, { label: '   ' })
  assert.deepEqual(JSON.parse(noLabel.calls[0].init.body), { hours: WATCH_DEFAULT_HOURS })

  const full = server({ status: 409, body: { ok: false, error: '5 links are live already' } })
  assert.deepEqual(await createWatchLink(full.env, {}), { ok: false, why: 'full' })
}

// 7. A minted link whose address the panel will not show is revoked at once:
//    a live link its owner cannot see is a door nobody knows is open.
{
  const s = server(
    { status: 200, body: { ok: true, id: 'abcdef012345', url: 'javascript:alert(1)', expiresAt: LATER } },
    { status: 200, body: { ok: true, revoked: true } },
  )
  assert.deepEqual(await createWatchLink(s.env, {}), { ok: false, why: 'failed' })
  assert.equal(s.calls.length, 2)
  sentRight(s.calls[1], 'DELETE')
  assert.ok(s.calls[1].url.endsWith('?id=abcdef012345'))

  // No id in the answer: nothing to revoke, and nothing is asked.
  const noId = server({ status: 200, body: { ok: true, url: good, expiresAt: LATER } })
  assert.deepEqual(await createWatchLink(noId.env, {}), { ok: false, why: 'failed' })
  assert.equal(noId.calls.length, 1)
}

// 8. Revoking: only an id is ever sent; a stale id is "gone", not an error.
{
  const s = server({ status: 200, body: { ok: true, revoked: true } })
  assert.deepEqual(await revokeWatchLink(s.env, 'abcdef012345'), { ok: true, value: true })
  sentRight(s.calls[0], 'DELETE')

  const nothing = server()
  assert.deepEqual(await revokeWatchLink(nothing.env, `${GOOD_TOKEN}`), { ok: false, why: 'bad' })
  assert.deepEqual(await revokeWatchLink(nothing.env, 'abc&x=1'), { ok: false, why: 'bad' })
  assert.equal(nothing.calls.length, 0, 'a token or a smuggled query is never sent as an id')

  const gone = server({ status: 404, body: { ok: false, revoked: false } })
  assert.deepEqual(await revokeWatchLink(gone.env, 'abcdef012345'), { ok: false, why: 'gone' })
}

// 9. Presence and the cap, from the list alone.
{
  const l = (id, over) => ({
    id,
    label: null,
    createdAt: EARLIER,
    expiresAt: LATER,
    revoked: false,
    live: true,
    views: 0,
    watchingNow: 0,
    lastViewAt: null,
    ...over,
  })
  const links = [
    l('000000000001', { watchingNow: 2 }),
    l('000000000002', { watchingNow: 1 }),
    l('000000000003', { revoked: true, live: false, watchingNow: 5 }),
    l('000000000004', { expiresAt: EARLIER, watchingNow: 7 }), // the server said live; the clock says ended
  ]
  assert.equal(liveLinks(links, NOW).length, 2)
  assert.equal(watchingNow(links, NOW), 3, 'only live links count')
  assert.equal(canMint(links, NOW), true)
  assert.equal(shouldPollWatch(links, NOW), true)
  assert.equal(shouldPollWatch([], NOW), false, 'nothing live: no polling')
  const five = Array.from({ length: WATCH_MAX_ACTIVE }, (_, i) => l(`00000000001${i}`, {}))
  assert.equal(canMint(five, NOW), false, 'a sixth is never asked for')
}

// 10. What is left, short.
assert.equal(timeLeft(LATER, NOW, 'en'), '1 h', 'an hour is an hour, not 60 min')
assert.equal(timeLeft(new Date(NOW + 45 * 60_000).toISOString(), NOW, 'en'), '45 min')
assert.equal(timeLeft(new Date(NOW + 61 * 60_000).toISOString(), NOW, 'en'), '1 h')
assert.equal(timeLeft(new Date(NOW + 23.6 * 3_600_000).toISOString(), NOW, 'ru'), '24 ч')
assert.equal(timeLeft(new Date(NOW + 90_000).toISOString(), NOW, 'ru'), '2 мин')
assert.equal(timeLeft(EARLIER, NOW, 'en'), null)
assert.equal(timeLeft('garbage', NOW, 'en'), null)

// 11. The owner learns of an audience in the journal: the link id, never a token.
{
  const step = { at: EARLIER, tool: 'watch_link', ok: true, ms: 0, detail: { link: 'abcdef012345', event: 'opened' } }
  assert.equal(journalLine(step, 'en').verb, 'watch link opened')
  assert.equal(journalLine(step, 'ru').verb, 'открыли ссылку')
  assert.equal(journalLine(step, 'en').text, 'abcdef012345')
}

console.log('queen-watch contract: ok')
