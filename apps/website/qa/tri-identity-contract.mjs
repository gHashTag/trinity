// Who is playing on t27.ai, without the player's session: src/lib/triIdentity.ts.
//
// Pure, no browser. The client runs against a fake environment (a fake parent,
// a fake bridge frame, fake timers, a fake fetch) while storage, cookies, the
// console and the real window are trapped, and holds it to:
//   1  active on https://t27.ai only
//   2  replies only from https://app.t27.ai, only from the window asked (the
//      bridge frame, or the parent in the Hive), only with the open nonce or null
//   3  the game token in memory only: never storage, a URL, a log, a message
//      or the published snapshot
//   4  whoami: POST <render>/mcp, credentials 'omit', exactly Content-Type and
//      Authorization, never X-Agent-Key (the console's agent-key path stays as it is)
//   5  asked again 30 s before expiry; a proactive signed-out forgets the token
//   6  the sign-in link: the player's login, returning to a fixed Queen route
//   7  wired into the Queen: the chip in the tools row, not in a preview, en/ru copy
//
//   node --experimental-strip-types qa/tri-identity-contract.mjs

import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import ts from 'typescript'
import {
  GAME_ORIGIN,
  APP_ORIGIN,
  BRIDGE_URL,
  RENDER_BASE,
  RENEW_BEFORE_S,
  IDENTITY_ANSWER_MS,
  IDENTITY_STATES,
  identityActiveOn,
  framedByPlayer,
  acceptIdentityMessage,
  renewDelayMs,
  whoamiProfile,
  signInHref,
  createTriIdentity,
} from '../src/lib/triIdentity.ts'
import { APP_ORIGIN as TRI_APP_ORIGIN } from '../src/lib/triScreens.ts'
import { RENDER_BASE as CRM_RENDER_BASE } from '../src/lib/crmClient.ts'
import { HUD_VIEWS } from '../src/components/queenHud.ts'

const read = (rel) => readFileSync(new URL(`../${rel}`, import.meta.url), 'utf8')
let checks = 0
const ok = (value, message) => { checks++; assert.ok(value, message) }
const eq = (a, b, message) => { checks++; assert.deepEqual(a, b, message) }

eq(GAME_ORIGIN, 'https://t27.ai', 'the game origin')
eq(APP_ORIGIN, TRI_APP_ORIGIN, 'one app origin with the TRI tab')
eq(BRIDGE_URL, 'https://app.t27.ai/bridge', 'the bridge address, with no query')
eq(RENDER_BASE, CRM_RENDER_BASE, 'one render service with the console')

// ---- 1. The origin gate ----
ok(identityActiveOn('https://t27.ai'), 'active on t27.ai')
for (const origin of ['https://www.t27.ai', 'http://t27.ai', 'https://app.t27.ai', 'https://t27.ai.evil.example', 'https://ghashtag.github.io', 'http://127.0.0.1:4173', 'null', '']) {
  ok(!identityActiveOn(origin), `not active on ${JSON.stringify(origin)}`)
}

// ---- 2. Who is the player ----
ok(framedByPlayer({ isTop: false, ancestorOrigins: [APP_ORIGIN], referrer: '' }), 'the Hive frames the game')
ok(framedByPlayer({ isTop: false, ancestorOrigins: [APP_ORIGIN, 'https://web.telegram.org'], referrer: '' }), 'Telegram Web > player > game')
ok(!framedByPlayer({ isTop: false, ancestorOrigins: ['https://evil.example', APP_ORIGIN], referrer: '' }), 'a stranger between the player and the game is not the player')
ok(!framedByPlayer({ isTop: true, ancestorOrigins: [], referrer: `${APP_ORIGIN}/` }), 'top level is never framed')
ok(!framedByPlayer({ isTop: false, ancestorOrigins: ['https://t27.ai'], referrer: '' }), 'the landing is not the player')
ok(framedByPlayer({ isTop: false, referrer: `${APP_ORIGIN}/hive` }), 'no ancestorOrigins: the referrer')
ok(!framedByPlayer({ isTop: false, referrer: 'https://app.t27.ai.evil.example/' }), 'a look-alike referrer')
ok(!framedByPlayer({ isTop: false, referrer: 'not a url' }), 'an unparseable referrer')

// ---- 3. The message filter ----
const bridge = { name: 'bridge' }
const TOKEN = 'eyJhbGciOiJIUzI1NiJ9.eyJ2IjoyfQ.c2lnbmF0dXJl'
const signedIn = (nonce) => ({ v: 1, type: 'tri-identity', nonce, state: 'signed-in', game_token: TOKEN, expires_in: 300, telegram_id: '144022504' })
const msg = (data, over = {}) => ({ origin: APP_ORIGIN, source: bridge, data, ...over })
const N = 'a'.repeat(32)
eq(acceptIdentityMessage(msg(signedIn(N)), bridge, N), { state: 'signed-in', nonce: N, gameToken: TOKEN, expiresIn: 300, telegramId: '144022504' }, 'the answer to the open request')
eq(acceptIdentityMessage(msg({ v: 1, type: 'tri-identity', nonce: null, state: 'signed-out' }), bridge, null), { state: 'signed-out', nonce: null }, 'a push with nonce null')
eq(acceptIdentityMessage(msg({ v: 1, type: 'tri-identity', nonce: null, state: 'unavailable', code: 'game_token_parent_not_web' }), bridge, N)?.code, 'game_token_parent_not_web', 'a code')
eq(acceptIdentityMessage(msg({ ...signedIn(N), telegram_id: 144022504 }), bridge, N)?.telegramId, '144022504', 'a numeric telegram_id')
const refused = [
  ['wrong origin', msg(signedIn(N), { origin: 'https://evil.example' }), bridge, N],
  ['the game origin itself', msg(signedIn(N), { origin: GAME_ORIGIN }), bridge, N],
  ['a look-alike origin', msg(signedIn(N), { origin: 'https://app.t27.ai.evil.example' }), bridge, N],
  ['wrong source', msg(signedIn(N), { source: { name: 'impostor' } }), bridge, N],
  ['no source asked', msg(signedIn(N)), null, N],
  ['a null source against a null expectation', msg(signedIn(N), { source: null }), null, N],
  ['wrong nonce', msg(signedIn('b'.repeat(32))), bridge, N],
  ['a nonce when none is open', msg(signedIn(N)), bridge, null],
  ['a numeric nonce', msg({ ...signedIn(N), nonce: 7 }), bridge, N],
  ['no nonce field', msg((({ nonce, ...rest }) => rest)(signedIn(N))), bridge, N],
  ['v 2', msg({ ...signedIn(N), v: 2 }), bridge, N],
  ['another type', msg({ ...signedIn(N), type: 't27-app' }), bridge, N],
  ['an unknown state', msg({ ...signedIn(N), state: 'admin' }), bridge, N],
  ['a JSON string', msg(JSON.stringify(signedIn(N))), bridge, N],
  ['an array', msg([signedIn(N)]), bridge, N],
  ['null data', msg(null), bridge, N],
  ['a token with markup', msg({ ...signedIn(N), game_token: '<img src=x>' }), bridge, N],
  ['a token that is not a string', msg({ ...signedIn(N), game_token: { t: 1 } }), bridge, N],
  ['an expiry of NaN', msg({ ...signedIn(N), expires_in: Number.NaN }), bridge, N],
  ['a negative expiry', msg({ ...signedIn(N), expires_in: -1 }), bridge, N],
  ['a day-long expiry', msg({ ...signedIn(N), expires_in: 86400 }), bridge, N],
  ['a telegram_id that is not digits', msg({ ...signedIn(N), telegram_id: '../1' }), bridge, N],
]
for (const [name, event, source, open] of refused) eq(acceptIdentityMessage(event, source, open), null, `refused: ${name}`)

// The states, spelled exactly as the player sends them. The bridge page
// (gHashTag/999-multibots-telegraf apps/vibee-editor/player/public/bridge/bridge.js)
// sends signed-out, consent-required, signed-in and unavailable; the Hive
// (player src/lib/hive.ts) the same minus consent-required. A state spelled
// otherwise here is dropped as unknown, and the frame never shows.
const PLAYER_STATES = ['signed-in', 'signed-out', 'consent-required', 'unavailable']
eq([...IDENTITY_STATES].sort(), [...PLAYER_STATES].sort(), "the game's states are the player's")
for (const state of PLAYER_STATES) eq(acceptIdentityMessage(msg({ v: 1, type: 'tri-identity', nonce: N, state }), bridge, N)?.state, state, `the player's ${state} is accepted`)
eq(acceptIdentityMessage(msg({ v: 1, type: 'tri-identity', nonce: N, state: 'consent-needed' }), bridge, N), null, 'refused: consent-needed, a spelling the player never sends')
eq(acceptIdentityMessage(msg({ v: 1, type: 'tri-identity', nonce: null, state: 'signed-out', code: 'Drop Table' }), bridge, null), { state: 'signed-out', nonce: null }, 'a code of another shape is dropped')

// ---- whoami's answer ----
const WHOAMI = { jsonrpc: '2.0', id: 1, result: { structuredContent: { telegram_id: '144022504', role: 'owner', профиль: { display_name: 'Ada', first_name: 'A', username: 'ada' }, аватар: 'https://cdn.example/ada.jpg' } } }
eq(whoamiProfile(WHOAMI), { name: 'Ada', avatar: 'https://cdn.example/ada.jpg', role: 'owner' }, 'structured whoami')
eq(whoamiProfile({ result: { content: [{ type: 'text', text: JSON.stringify(WHOAMI.result.structuredContent) }] } }), { name: 'Ada', avatar: 'https://cdn.example/ada.jpg', role: 'owner' }, 'text whoami')
eq(whoamiProfile({ result: { structuredContent: { role: 'god', профиль: { first_name: ' ', username: 'bee' }, аватар: 'javascript:alert(1)' } } }), { name: 'bee', avatar: undefined, role: undefined }, 'an unknown role, a script avatar and a blank name are dropped')
eq(whoamiProfile({ result: { structuredContent: { аватар: 'http://cdn.example/a.jpg' } } }).avatar, undefined, 'an http avatar is dropped')
eq(whoamiProfile({ error: { code: -32001 } }), {}, 'an error has no profile')
eq(whoamiProfile('nope'), {}, 'not an object')

// ---- 5 (pure part). Renewal ----
eq(RENEW_BEFORE_S, 30)
eq(renewDelayMs(300), 270000, '300 s token: ask again at 270 s')
eq(renewDelayMs(20), 5000, 'never sooner than 5 s')

// ---- 6. The sign-in link ----
const returns = new Set()
for (const view of HUD_VIEWS) {
  const href = new URL(signInHref(view, HUD_VIEWS))
  eq(href.origin + href.pathname, `${APP_ORIGIN}/`, `${view}: the player's login`)
  eq([...href.searchParams.keys()], ['return'], `${view}: one parameter`)
  const back = href.searchParams.get('return')
  eq(back, view === 'comb' ? `${GAME_ORIGIN}/#/queen` : `${GAME_ORIGIN}/#/queen?tab=${view}`, `${view}: returns to its view`)
  returns.add(back)
}
// A view of another shape is refused even when a caller's list admits it.
for (const hostile of ['tri&screen=crm', 'kanban&embed=1', 'profile/144022504', '../', '', 'KANBAN']) {
  eq(new URL(signInHref(hostile, [...HUD_VIEWS, hostile])).searchParams.get('return'), `${GAME_ORIGIN}/#/queen`, `a view ${JSON.stringify(hostile)} returns to the comb`)
}
eq(new URL(signInHref('constructor', HUD_VIEWS)).searchParams.get('return'), `${GAME_ORIGIN}/#/queen`, 'an object key is not a view')
eq(new URL(signInHref('nope', HUD_VIEWS)).searchParams.get('return'), `${GAME_ORIGIN}/#/queen`, 'an unknown view returns to the comb')
ok([...returns].every((r) => r.startsWith(`${GAME_ORIGIN}/#/queen`) && !/embed|screen|path|lead|\d/.test(r.slice(GAME_ORIGIN.length))), 'no return route carries embed, a screen, a path or an id')
eq(returns.size, HUD_VIEWS.length, 'one fixed route per view')

// ---- The client, against fakes ----
const TRAPPED = []
function trapGlobals() {
  const names = ['window', 'document', 'localStorage', 'sessionStorage', 'indexedDB', 'location', 'history', 'navigator']
  const saved = names.map((name) => [name, Object.getOwnPropertyDescriptor(globalThis, name)])
  for (const name of names) {
    Object.defineProperty(globalThis, name, { configurable: true, get() { TRAPPED.push(name); throw new Error(`triIdentity touched ${name}`) } })
  }
  const consoleSaved = {}
  for (const level of ['log', 'info', 'warn', 'error', 'debug']) {
    consoleSaved[level] = console[level]
    console[level] = (...args) => { TRAPPED.push(`console.${level}:${args.map(String).join(' ')}`) }
  }
  return () => {
    for (const [name, descriptor] of saved) {
      if (descriptor) Object.defineProperty(globalThis, name, descriptor)
      else delete globalThis[name]
    }
    Object.assign(console, consoleSaved)
  }
}

function fakeWorld({ origin = GAME_ORIGIN, isTop = true, ancestorOrigins = [], referrer = '', whoami = () => ({ ok: true, status: 200, json: async () => WHOAMI }) } = {}) {
  const log = { bridgePosts: [], parentPosts: [], mounts: [], fetches: [], visible: [], snapshots: [] }
  const bridgeWindow = { postMessage: (m, t) => log.bridgePosts.push({ m, t }) }
  const parent = { postMessage: (m, t) => log.parentPosts.push({ m, t }) }
  const timers = new Map()
  let nextTimer = 1
  let handler = null
  let onLoad = null
  let visible = false
  let n = 0
  const env = {
    origin, isTop, ancestorOrigins, referrer, parent,
    mountBridge(src, load) { log.mounts.push(src); onLoad = load; return { target: () => bridgeWindow, setVisible: (v) => { visible = v; log.visible.push(v) } } },
    onMessage(h) { handler = h },
    fetch: async (url, init) => { log.fetches.push({ url, init }); return whoami(url, init) },
    setTimeout(fn, ms) { const id = nextTimer++; timers.set(id, { fn, ms }); return id },
    clearTimeout(id) { timers.delete(id) },
    nonce: () => (++n).toString(16).padStart(32, '0'),
  }
  const client = createTriIdentity(env)
  const settle = async () => { for (let i = 0; i < 5; i++) await new Promise((r) => setImmediate(r)) }
  return {
    log, bridgeWindow, parent, client,
    start: () => client.subscribe(() => log.snapshots.push(client.getSnapshot())),
    load: () => onLoad?.(),
    deliver: async (data, over = {}) => { handler?.({ origin: APP_ORIGIN, source: bridgeWindow, data, ...over }); await settle() },
    timer: (ms) => [...timers.values()].filter((t) => t.ms === ms),
    fire: async (ms) => { for (const [id, t] of [...timers]) if (t.ms === ms) { timers.delete(id); t.fn() } await settle() },
    get visible() { return visible },
    get handler() { return handler },
    lastNonce: (posts) => posts.at(-1)?.m?.nonce ?? null,
  }
}

const restore = trapGlobals()
let world
try {
  // 1. Another origin asks nobody.
  world = fakeWorld({ origin: 'https://ghashtag.github.io' })
  world.start()
  eq([world.log.mounts.length, world.log.bridgePosts.length, world.log.parentPosts.length, world.log.fetches.length, world.handler], [0, 0, 0, 0, null], 'another origin mounts no bridge, posts nothing, fetches nothing, listens to nothing')
  eq(world.client.getSnapshot(), { state: 'unavailable', code: 'not_t27' })

  // 2-5. Top level on t27.ai: the bridge.
  world = fakeWorld()
  world.start()
  eq(world.log.mounts, [BRIDGE_URL], 'one bridge frame at the bridge address')
  eq(world.log.bridgePosts.length, 0, 'nothing is posted before the bridge loads')
  world.load()
  eq(world.log.bridgePosts.length, 1, 'one request once the bridge loads')
  const first = world.log.bridgePosts[0]
  eq(first.t, APP_ORIGIN, 'the request names the app origin as its target')
  eq(Object.keys(first.m).sort(), ['nonce', 'type', 'v'], 'the request carries v, type and nonce only')
  eq([first.m.v, first.m.type], [1, 'tri-identity-request'])
  ok(/^[0-9a-f]{32}$/.test(first.m.nonce), 'a 32-hex nonce')
  eq(world.log.parentPosts.length, 0, 'the parent is not asked at top level')
  eq(world.timer(IDENTITY_ANSWER_MS).length, 1, 'an answer deadline is set')

  // Ignored: a wrong origin, a wrong source (the parent), a wrong nonce.
  await world.deliver(signedIn(first.m.nonce), { origin: 'https://evil.example' })
  await world.deliver(signedIn(first.m.nonce), { source: world.parent })
  await world.deliver(signedIn(first.m.nonce), { source: { postMessage() {} } })
  await world.deliver(signedIn('f'.repeat(32)))
  eq([world.client.getSnapshot().state, world.log.fetches.length], ['pending', 0], 'a wrong origin, a wrong source and a wrong nonce change nothing and fetch nothing')

  // consent-required shows the frame.
  await world.deliver({ v: 1, type: 'tri-identity', nonce: first.m.nonce, state: 'consent-required' })
  eq([world.client.getSnapshot().state, world.visible], ['consent-required', true], 'consent-required shows the bridge frame')
  eq(world.timer(IDENTITY_ANSWER_MS).length, 0, 'an answer clears the deadline')
  await world.deliver(signedIn('f'.repeat(32)))
  eq([world.client.getSnapshot().state, world.visible, world.log.fetches.length], ['consent-required', true, 0], 'while the click is awaited another nonce is still refused')

  // The click in the bridge: bridge.js answers the waiting request's own nonce
  // (its pendingNonce) with the token. It never pushes signed-in with nonce null.
  await world.deliver(signedIn(first.m.nonce))
  eq(world.visible, false, 'signed in hides the frame')
  eq(world.log.fetches.length, 1, 'one whoami')
  const [{ url, init }] = world.log.fetches
  eq(url, `${RENDER_BASE}/mcp`, 'whoami goes to /mcp')
  eq(init.method, 'POST')
  eq(init.credentials, 'omit', "credentials 'omit'")
  eq(Object.keys(init.headers).sort(), ['Authorization', 'Content-Type'], 'exactly two headers')
  ok(!Object.keys(init.headers).some((h) => h.toLowerCase() === 'x-agent-key'), 'never X-Agent-Key')
  eq(init.headers.Authorization, `Bearer ${TOKEN}`, 'the game token as Bearer')
  const rpc = JSON.parse(init.body)
  eq([rpc.method, rpc.params.name, rpc.params.arguments], ['tools/call', 'whoami', {}], 'the call is whoami')
  eq(world.client.getSnapshot(), { state: 'signed-in', name: 'Ada', avatar: 'https://cdn.example/ada.jpg', role: 'owner' }, 'the snapshot: name, avatar, role, and no token')

  // Renewal 30 s before expiry, with a fresh nonce; the old answer is spent.
  eq(world.timer(270000).length, 1, 'renewal is scheduled at 270 s')
  await world.fire(270000)
  eq(world.log.bridgePosts.length, 2, 'the renewal asks again')
  const second = world.log.bridgePosts[1].m.nonce
  ok(second !== first.m.nonce, 'a fresh nonce per request')
  await world.deliver(signedIn(first.m.nonce))
  eq(world.log.fetches.length, 1, 'a replayed answer to the old nonce is refused')
  await world.deliver(signedIn(second))
  eq(world.log.fetches.length, 1, 'the same person renewed: no second whoami')
  await world.deliver({ ...signedIn(null), telegram_id: '42' })
  eq(world.log.fetches.length, 2, 'another person: whoami again')

  // A proactive signed-out forgets everything.
  await world.deliver({ v: 1, type: 'tri-identity', nonce: null, state: 'signed-out' })
  eq(world.client.getSnapshot(), { state: 'signed-out' }, 'a proactive signed-out clears the identity')
  eq(world.timer(270000).length, 0, 'and cancels the renewal')

  // unavailable with the server's code.
  await world.deliver({ v: 1, type: 'tri-identity', nonce: null, state: 'unavailable', code: 'game_token_parent_not_web' })
  eq(world.client.getSnapshot(), { state: 'unavailable', code: 'game_token_parent_not_web' })

  // 3. The token went nowhere but the Authorization header.
  const elsewhere = JSON.stringify([world.log.bridgePosts, world.log.parentPosts, world.log.mounts, world.log.snapshots, world.log.fetches.map((f) => ({ url: f.url, body: f.body }))])
  ok(!elsewhere.includes(TOKEN) && !elsewhere.includes('eyJ'), 'the token is in no message, frame address, snapshot, URL or body')
  eq(TRAPPED, [], 'no window, document, storage, location, history or console was touched')

  // No answer: unavailable.
  world = fakeWorld()
  world.start()
  world.load()
  await world.fire(IDENTITY_ANSWER_MS)
  eq(world.client.getSnapshot(), { state: 'unavailable', code: 'no_answer' }, 'a silent bridge is unavailable')

  // An answer that says signed in without a token is not an identity.
  world = fakeWorld()
  world.start()
  world.load()
  await world.deliver({ v: 1, type: 'tri-identity', nonce: world.lastNonce(world.log.bridgePosts), state: 'signed-in' })
  eq([world.client.getSnapshot(), world.log.bridgePosts.length], [{ state: 'unavailable', code: 'no_token' }, 1], 'no token in an answer: unavailable, no loop')
  await world.deliver({ v: 1, type: 'tri-identity', nonce: null, state: 'signed-in' })
  eq(world.log.bridgePosts.length, 2, 'a tokenless push asks once')

  // A newer request replaces the one waiting for the click, as in bridge.js.
  world = fakeWorld()
  world.start()
  world.load()
  const waiting = world.lastNonce(world.log.bridgePosts)
  await world.deliver({ v: 1, type: 'tri-identity', nonce: waiting, state: 'consent-required' })
  await world.deliver({ v: 1, type: 'tri-identity', nonce: null, state: 'signed-in' })
  const newer = world.lastNonce(world.log.bridgePosts)
  ok(newer !== waiting, 'a push while the click is awaited asks again with a fresh nonce')
  await world.deliver(signedIn(waiting))
  eq(world.log.fetches.length, 0, 'the replaced nonce is refused')
  await world.deliver(signedIn(newer))
  eq([world.client.getSnapshot().state, world.log.fetches.length], ['signed-in', 1], 'the newer nonce is heard')

  // The consent frame is fixed above every route: it shows only while someone
  // subscribes (the Queen's chip), so leaving the Queen hides it.
  world = fakeWorld()
  const leaveChip = world.start()
  const leaveOther = world.client.subscribe(() => {})
  world.load()
  const clickFor = world.lastNonce(world.log.bridgePosts)
  await world.deliver({ v: 1, type: 'tri-identity', nonce: clickFor, state: 'consent-required' })
  eq(world.visible, true, 'consent-required with a subscriber shows the frame')
  leaveOther()
  eq(world.visible, true, 'one of two subscribers leaving keeps it')
  leaveChip()
  eq(world.visible, false, 'the last subscriber leaving hides it')
  const backChip = world.start()
  eq(world.visible, true, 'a subscriber coming back while the click is awaited shows it again')
  await world.deliver(signedIn(clickFor))
  eq([world.client.getSnapshot().state, world.visible], ['signed-in', false], 'the click then signs in and hides it')
  backChip()
  world.start()
  eq(world.visible, false, 'signed in, a new subscriber does not show it')

  world = fakeWorld()
  const leftEarly = world.start()
  world.load()
  leftEarly()
  await world.deliver({ v: 1, type: 'tri-identity', nonce: world.lastNonce(world.log.bridgePosts), state: 'consent-required' })
  eq([world.client.getSnapshot().state, world.visible], ['consent-required', false], 'consent that arrives after the last subscriber left does not show the frame')
  world.start()
  eq(world.visible, true, 'it shows when a subscriber returns')

  // whoami refused: the token is dropped.
  world = fakeWorld({ whoami: () => ({ ok: false, status: 401, json: async () => ({}) }) })
  world.start()
  world.load()
  await world.deliver(signedIn(world.lastNonce(world.log.bridgePosts)))
  eq([world.client.getSnapshot(), world.timer(270000).length], [{ state: 'unavailable', code: 'whoami_rejected' }, 0], 'a refused token is forgotten')

  // whoami offline: signed in, no name.
  world = fakeWorld({ whoami: () => { throw new Error('offline') } })
  world.start()
  world.load()
  await world.deliver(signedIn(world.lastNonce(world.log.bridgePosts)))
  eq(world.client.getSnapshot(), { state: 'signed-in' }, 'offline whoami: signed in without a name')

  // 2. In the Hive: the parent, and only the parent.
  world = fakeWorld({ isTop: false, ancestorOrigins: [APP_ORIGIN] })
  world.start()
  eq([world.log.mounts.length, world.log.parentPosts.length], [0, 1], 'in the Hive no bridge is mounted and the parent is asked at once')
  eq(world.log.parentPosts[0].t, APP_ORIGIN, 'the parent is asked with the app origin as target')
  const hiveNonce = world.lastNonce(world.log.parentPosts)
  await world.deliver(signedIn(hiveNonce), { source: world.bridgeWindow })
  eq(world.client.getSnapshot().state, 'pending', 'in the Hive a window other than the parent is not heard')
  await world.deliver(signedIn(hiveNonce), { source: world.parent, origin: GAME_ORIGIN })
  eq(world.client.getSnapshot().state, 'pending', 'in the Hive the parent must be on the app origin')
  await world.deliver(signedIn(hiveNonce), { source: world.parent })
  eq(world.client.getSnapshot().state, 'signed-in', 'in the Hive the parent is heard')
  eq(TRAPPED, [], 'still nothing trapped')
} finally {
  restore()
}

// ---- Static: the rules in the source, comments removed ----
const code = (rel) => ts.createPrinter({ removeComments: true }).printFile(ts.createSourceFile(rel, read(rel), ts.ScriptTarget.Latest, true, rel.endsWith('x') ? ts.ScriptKind.TSX : ts.ScriptKind.TS))
const lib = code('src/lib/triIdentity.ts')
for (const [pattern, rule] of [
  [/localStorage|sessionStorage|indexedDB|\.cookie\b|caches\./, 'no storage or cookies'],
  [/\bconsole\./, 'no logging'],
  [/x-agent-key|agentkey/i, 'no agent key'],
  [/credentials:\s*["']include/, "no credentials 'include'"],
  [/crmClient/, 'does not import the console client'],
  [/location\.(href|hash|search)\s*=|\.assign\(|history\./, 'writes no address'],
]) ok(!pattern.test(lib), `triIdentity.ts: ${rule}`)
ok(/credentials:\s*["']omit["']/.test(lib), "triIdentity.ts: credentials 'omit'")

// The console's agent-key path is left as it was (an owner decision, not this change's).
const crm = read('src/lib/crmClient.ts')
ok(crm.includes("const AGENT_KEY = 't27.crm.key'") && crm.includes("if (key) return { 'X-Agent-Key': key }"), 'crmClient keeps its agent-key path unchanged')

// ---- 7. Wired into the Queen ----
const chip = code('src/components/QueenIdentity.tsx')
ok(!/dangerouslySetInnerHTML|innerHTML/.test(chip), 'the chip renders text nodes only')
ok(/useSyncExternalStore\(identity\.subscribe, identity\.getSnapshot\)/.test(chip), 'the chip reads the store')
ok(/signInHref\(view, HUD_VIEWS\)/.test(chip) && /target="_top"/.test(chip), 'Sign in is a top-level link to a fixed route')
ok(/game_token_parent_not_web/.test(chip), 'a non-web parent asks to sign in again in TRI')
const queen = read('src/pages/Queen.tsx')
ok(/\{!embedded && \(\s*<QueenIdentity/.test(queen), 'the Queen renders the chip only when not embedded')
ok(/<QueenIdentity[\s\S]{0,700}<\/?button\s+type="button"\s+data-tool="agent"/.test(queen), 'the chip sits in the tools row, before the agent button')
for (const key of ['identitySignIn', 'identitySignInTitle', 'identitySignInAgain', 'identitySignedIn', 'identityRoleKeeper', 'identityRoleOwner', 'identityRoleBee']) {
  eq([...queen.matchAll(new RegExp(`^\\s*${key}: "[^"]+",$`, 'gm'))].length, 2, `COPY has ${key} in en and ru`)
}
ok(/^\s*identitySignInAgain: "Sign in again in TRI",$/m.test(queen), 'the English copy says "Sign in again in TRI"')

console.log(`TRI identity contract: PASS (${checks} checks)`)
