// Who is playing on t27.ai, without the player's session: src/lib/triIdentity.ts.
//
// Pure, no browser. The client runs against a fake environment (a fake parent,
// a fake bridge frame, fake timers and clock, a fake fetch, fake visibility)
// while storage, cookies, the console and the real window are trapped, and
// holds it to:
//   1  active on https://t27.ai only
//   2  messages only from https://app.t27.ai, only from the window asked (the
//      bridge frame, or the parent in the Hive), only with the open nonce or
//      null; a dismiss only with the nonce waiting for its click
//   3  the game token in memory only: never storage, a URL, a log, a message
//      or the published snapshot
//   4  whoami: POST <render>/mcp, credentials 'omit', exactly Content-Type and
//      Authorization, never X-Agent-Key (the console's agent-key path stays as it is)
//   5  asked again 30 s before expiry; a proactive signed-out forgets the token;
//      nobody looking or a hidden page asks nothing; failures that may pass
//      back off 5 s, 15 s, 60 s, 300 s; whoami has a deadline and one silent retry
//   6  the sign-in link: the player's login, returning to a fixed Queen route
//      the player accepts (a copy of its returnTarget rules)
//   7  the chip: a next step for every code the client can receive
//   8  wired into the Queen: the chip in the tools row, not in a preview, en/ru
//      copy; the page primes the bridge on the Queen's address only
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
  WHOAMI_TIMEOUT_MS,
  RETRY_BACKOFF_S,
  IDENTITY_STATES,
  identityActiveOn,
  framedByPlayer,
  bridgeUrl,
  acceptIdentityMessage,
  acceptDismissMessage,
  renewDelayMs,
  retriesByItself,
  retryDelayMs,
  chipOf,
  whoamiProfile,
  signInHref,
  PLAYER_VIEWS,
  createTriIdentity,
} from '../src/lib/triIdentity.ts'
import { APP_ORIGIN as TRI_APP_ORIGIN, TRI_SCREENS } from '../src/lib/triScreens.ts'
import { RENDER_BASE as CRM_RENDER_BASE } from '../src/lib/crmClient.ts'
import { HUD_VIEWS } from '../src/components/queenHud.ts'
import { TOKEN, signedIn, WHOAMI, TRAPPED, trapGlobals, fakeWorld, settleAll } from './fixtures/identity-world.mjs'

const read = (rel) => readFileSync(new URL(`../${rel}`, import.meta.url), 'utf8')
let checks = 0
const ok = (value, message) => { checks++; assert.ok(value, message) }
const eq = (a, b, message) => { checks++; assert.deepEqual(a, b, message) }

eq(GAME_ORIGIN, 'https://t27.ai', 'the game origin')
eq(APP_ORIGIN, TRI_APP_ORIGIN, 'one app origin with the TRI tab')
eq(BRIDGE_URL, 'https://app.t27.ai/bridge', 'the bridge address')
eq(RENDER_BASE, CRM_RENDER_BASE, 'one render service with the console')

// The bridge in the game's language. bridge.js: /(?:^\?|&)lang=ru(?:&|$)/i is
// Russian, anything else English; nginx `location = /bridge` ignores the query.
eq(bridgeUrl('ru'), 'https://app.t27.ai/bridge?lang=ru', 'Russian')
for (const lang of ['en', 'de', 'zh', 'es', '', 'RU', 'ru&x=1', '../']) eq(bridgeUrl(lang), 'https://app.t27.ai/bridge?lang=en', `${JSON.stringify(lang)} is English`)

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
// sends signed-out, expired (an access token and its expiry still stored, the
// expiry passed: consent kept, nothing minted), consent-required, signed-in and
// unavailable; the Hive (player src/lib/hive.ts) signed-out, signed-in and
// unavailable. A state spelled otherwise here is dropped as unknown.
const PLAYER_STATES = ['signed-in', 'signed-out', 'expired', 'consent-required', 'unavailable']
eq([...IDENTITY_STATES].sort(), [...PLAYER_STATES].sort(), "the game's states are the player's")
for (const state of PLAYER_STATES) eq(acceptIdentityMessage(msg({ v: 1, type: 'tri-identity', nonce: N, state }), bridge, N)?.state, state, `the player's ${state} is accepted`)
eq(acceptIdentityMessage(msg({ v: 1, type: 'tri-identity', nonce: null, state: 'expired' }), bridge, null), { state: 'expired', nonce: null }, "bridge.js's unprompted expired (nonce null) is accepted")
eq(acceptIdentityMessage(msg({ v: 1, type: 'tri-identity', nonce: N, state: 'consent-needed' }), bridge, N), null, 'refused: consent-needed, a spelling the player never sends')
eq(acceptIdentityMessage(msg({ v: 1, type: 'tri-identity', nonce: N, state: 'session-expired' }), bridge, N), null, 'refused: session-expired, a spelling the player never sends')
eq(acceptIdentityMessage(msg({ v: 1, type: 'tri-identity', nonce: null, state: 'signed-out', code: 'Drop Table' }), bridge, null), { state: 'signed-out', nonce: null }, 'a code of another shape is dropped')

// Not now: bridge.js dismissed() posts {v:1, type:'tri-identity-dismiss', nonce:<its pendingNonce>}.
const dismiss = (nonce) => ({ v: 1, type: 'tri-identity-dismiss', nonce })
eq(acceptDismissMessage(msg(dismiss(N)), bridge, N), N, 'a dismiss for the waiting request')
for (const [name, event, source, open] of [
  ['wrong origin', msg(dismiss(N), { origin: 'https://evil.example' }), bridge, N],
  ['the game origin', msg(dismiss(N), { origin: GAME_ORIGIN }), bridge, N],
  ['wrong source', msg(dismiss(N), { source: { name: 'impostor' } }), bridge, N],
  ['no source asked', msg(dismiss(N)), null, N],
  ['wrong nonce', msg(dismiss('b'.repeat(32))), bridge, N],
  ['nothing waiting', msg(dismiss(N)), bridge, null],
  ['nonce null', msg(dismiss(null)), bridge, N],
  ['v 2', msg({ ...dismiss(N), v: 2 }), bridge, N],
  ['the identity type', msg({ ...dismiss(N), type: 'tri-identity' }), bridge, N],
  ['a JSON string', msg(JSON.stringify(dismiss(N))), bridge, N],
]) eq(acceptDismissMessage(event, source, open), null, `dismiss refused: ${name}`)

// ---- whoami's answer ----
eq(whoamiProfile(WHOAMI), { name: 'Ada', avatar: 'https://cdn.example/ada.jpg', role: 'owner' }, 'structured whoami')
eq(whoamiProfile({ result: { content: [{ type: 'text', text: JSON.stringify(WHOAMI.result.structuredContent) }] } }), { name: 'Ada', avatar: 'https://cdn.example/ada.jpg', role: 'owner' }, 'text whoami')
eq(whoamiProfile({ result: { structuredContent: { role: 'god', профиль: { first_name: ' ', username: 'bee' }, аватар: 'javascript:alert(1)' } } }), { name: 'bee', avatar: undefined, role: undefined }, 'an unknown role, a script avatar and a blank name are dropped')
eq(whoamiProfile({ result: { structuredContent: { аватар: 'http://cdn.example/a.jpg' } } }).avatar, undefined, 'an http avatar is dropped')
eq(whoamiProfile({ error: { code: -32001 } }), {}, 'an error has no profile')
eq(whoamiProfile('nope'), {}, 'not an object')

// ---- 5 (pure part). Renewal and retries ----
eq(RENEW_BEFORE_S, 30)
eq(renewDelayMs(300), 270000, '300 s token: ask again at 270 s')
eq(renewDelayMs(20), 5000, 'never sooner than 5 s')
eq(WHOAMI_TIMEOUT_MS, 5000, 'whoami deadline 5 s')
eq([...RETRY_BACKOFF_S], [5, 15, 60, 300], 'back off 5 s, 15 s, 60 s, capped at 5 min')
eq([0, 1, 2, 3, 4, 9, -1].map(retryDelayMs), [5000, 15000, 60000, 300000, 300000, 300000, 5000], 'the pause after each failure, capped')
for (const code of ['network', 'no_answer', 'game_token_rate_limited', 'http_429', 'http_500', 'http_502', 'http_503', 'http_599']) ok(retriesByItself(code), `${code} is asked again by itself`)
for (const code of [undefined, '', 'game_token_credential_rejected', 'game_token_parent_not_web', 'game_token_launch_bots_unset', 'whoami_rejected', 'no_token', 'bad_response', 'not_t27', 'http_401', 'http_404', 'http_5000', 'http_50']) ok(!retriesByItself(code), `${JSON.stringify(code)} waits for a person`)

// ---- 6. The sign-in link ----
// The player's half of this, from gHashTag/999-multibots-telegraf
// apps/vibee-editor/player/src/lib/returnTarget.ts on `main` (what is deployed):
// the only returns it follows. PLAYER_VIEWS is IMPORTED from triIdentity.ts and
// no longer restated here -- a third copy of a list that already exists in two
// repositories is how they drift without anyone being told.
const PLAYER_SHAPE = /^https:\/\/t27\.ai\/#\/queen(?:\?tab=([a-z]{1,16})(?:&screen=([a-z]{1,16}))?)?$/
const PLAYER_SCREENS = ['feed', 'chat', 'script', 'audio', 'image', 'avatar', 'video', 'editor', 'profile', 'crm']
const playerReturnTargetOf = (raw) => {
  if (typeof raw !== 'string' || raw.length > 128) return null
  const match = PLAYER_SHAPE.exec(raw)
  if (!match) return null
  const [, tab, screen] = match
  const queen = 'https://t27.ai/#/queen'
  if (tab === undefined) return queen
  const view = PLAYER_VIEWS.find((known) => known === tab)
  if (!view) return null
  if (screen === undefined) return `${queen}?tab=${view}`
  if (view !== 'tri') return null
  const id = PLAYER_SCREENS.find((known) => known === screen)
  return id ? `${queen}?tab=${view}&screen=${id}` : null
}
const SCREEN_IDS = TRI_SCREENS.map((entry) => entry.screen)
// The two lists are no longer required to be EQUAL, and that is a repair, not a
// relaxation. Equality could only ever be restored by editing the copy this file
// used to hold -- which would have turned the gate green while the deployed
// player still refused the new view, and refused it by answering null: the
// person is not returned to the game at all. What is actually required:
//
//   1. The player never knows a view the Queen does not have. That direction is
//      a real defect and still fails here.
//   2. The views the player does NOT know are named, below, with what it costs.
//      A new one appearing unannounced fails this gate exactly as before.
const UNKNOWN_TO_PLAYER = HUD_VIEWS.filter((view) => !PLAYER_VIEWS.includes(view))
eq(PLAYER_VIEWS.filter((view) => !HUD_VIEWS.includes(view)), [], 'the player follows no view the Queen does not have')
// BROWSER costs the same as PASSPORT: signing in from it returns to the comb,
// one press away from the browser. Its own sign-in link points into the app
// directly (lib/queenBrowser.ts APP_BROWSER_URL), so the person who wants the
// browser has a way there that does not depend on the return.
eq([...UNKNOWN_TO_PLAYER], ['passport', 'browser'], 'the views the deployed player has not been told about, and no others')
eq([...SCREEN_IDS].sort(), [...PLAYER_SCREENS].sort(), "the player's copy of the TRI screens is the Queen's table")

const returns = new Set()
for (const view of HUD_VIEWS) {
  const href = new URL(signInHref(view, HUD_VIEWS))
  eq(href.origin + href.pathname, `${APP_ORIGIN}/`, `${view}: the player's login`)
  eq([...href.searchParams.keys()], ['return'], `${view}: one parameter`)
  const back = href.searchParams.get('return')
  const carried = view !== 'comb' && PLAYER_VIEWS.includes(view)
  eq(back, carried ? `${GAME_ORIGIN}/#/queen?tab=${view}` : `${GAME_ORIGIN}/#/queen`,
    carried ? `${view}: returns to its view` : `${view}: the player cannot follow it, so it returns to the comb`)
  eq(playerReturnTargetOf(back), back, `${view}: the player accepts the return as it is`)
  returns.add(back)
}
for (const screen of SCREEN_IDS) {
  const back = new URL(signInHref('tri', HUD_VIEWS, screen, SCREEN_IDS)).searchParams.get('return')
  eq(back, screen === SCREEN_IDS[0] ? `${GAME_ORIGIN}/#/queen?tab=tri` : `${GAME_ORIGIN}/#/queen?tab=tri&screen=${screen}`, `tri/${screen}: returns to its screen (none for the first, as the Queen's address)`)
  eq(playerReturnTargetOf(back), back, `tri/${screen}: the player accepts the return as it is`)
  for (const view of HUD_VIEWS.filter((v) => v !== 'tri')) {
    eq(new URL(signInHref(view, HUD_VIEWS, screen, SCREEN_IDS)).searchParams.get('return').includes('screen='), false, `${view}: a screen is never carried off the TRI tab`)
  }
}
// A screen of another shape is refused even when a caller's list admits it.
for (const hostile of ['crm&embed=1', 'CRM', '../', '', 'crm/42', 'a'.repeat(17), null, undefined, 42]) {
  eq(new URL(signInHref('tri', HUD_VIEWS, hostile, [...SCREEN_IDS, hostile])).searchParams.get('return'), `${GAME_ORIGIN}/#/queen?tab=tri`, `a screen ${JSON.stringify(hostile)} is dropped`)
}
for (const unknown of ['nope', 'constructor', 'hive', 'blog']) {
  eq(new URL(signInHref('tri', HUD_VIEWS, unknown, SCREEN_IDS)).searchParams.get('return'), `${GAME_ORIGIN}/#/queen?tab=tri`, `a screen ${JSON.stringify(unknown)} not in the table is dropped`)
}
eq(new URL(signInHref('tri', HUD_VIEWS, 'crm')).searchParams.get('return'), `${GAME_ORIGIN}/#/queen?tab=tri`, 'no screen list, no screen')
// A view of another shape is refused even when a caller's list admits it.
for (const hostile of ['tri&screen=crm', 'kanban&embed=1', 'profile/144022504', '../', '', 'KANBAN']) {
  eq(new URL(signInHref(hostile, [...HUD_VIEWS, hostile])).searchParams.get('return'), `${GAME_ORIGIN}/#/queen`, `a view ${JSON.stringify(hostile)} returns to the comb`)
}
eq(new URL(signInHref('constructor', HUD_VIEWS)).searchParams.get('return'), `${GAME_ORIGIN}/#/queen`, 'an object key is not a view')
eq(new URL(signInHref('nope', HUD_VIEWS)).searchParams.get('return'), `${GAME_ORIGIN}/#/queen`, 'an unknown view returns to the comb')
ok([...returns].every((r) => r.startsWith(`${GAME_ORIGIN}/#/queen`) && !/embed|screen|path|lead|\d/.test(r.slice(GAME_ORIGIN.length))), 'no view return carries embed, a screen, a path or an id')
// One route per view the PLAYER knows -- the views it does not know share the
// comb's return, so the count follows its list, not ours.
eq(returns.size, PLAYER_VIEWS.length, 'one fixed route per view the player follows')

// ---- 7. The chip: one next step for every code ----
// The codes the client can receive: the render server's /api/auth/game-token
// errors (session-routes.ts), relayed by bridge.js and hive.ts, their
// http_<status>, bad_response and network, and this file's no_answer, no_token,
// whoami_rejected and not_t27. Anything else falls to unavailable with a Retry.
const CHIPS = [
  [{ state: 'pending' }, { kind: 'pending' }],
  [{ state: 'signed-in' }, { kind: 'signed-in' }],
  [{ state: 'consent-required' }, { kind: 'consent-required' }],
  [{ state: 'signed-out' }, { kind: 'signed-out' }],
  [{ state: 'expired' }, { kind: 'expired' }],
  ['game_token_parent_not_web', { kind: 'sign-in-again' }],
  ['game_token_launch_bots_unset', { kind: 'web-only' }],
  ['game_token_bot_not_allowed', { kind: 'web-only' }],
  ['not_t27', { kind: 'off-site' }],
  ['network', { kind: 'unavailable', reason: 'offline' }],
  ['no_answer', { kind: 'unavailable', reason: 'no_answer' }],
  ['game_token_rate_limited', { kind: 'unavailable', reason: 'busy' }],
  ['http_429', { kind: 'unavailable', reason: 'busy' }],
  ['game_token_credential_rejected', { kind: 'unavailable', reason: 'refused' }],
  ['game_token_credential_required', { kind: 'unavailable', reason: 'refused' }],
  ['whoami_rejected', { kind: 'unavailable', reason: 'refused' }],
  ['http_401', { kind: 'unavailable', reason: 'refused' }],
  ['http_403', { kind: 'unavailable', reason: 'refused' }],
  ['http_500', { kind: 'unavailable', reason: 'server' }],
  ['http_503', { kind: 'unavailable', reason: 'server' }],
  ['http_404', { kind: 'unavailable', reason: 'server' }],
  ['bad_response', { kind: 'unavailable', reason: 'server' }],
  ['no_token', { kind: 'unavailable', reason: 'server' }],
  ['game_token_origin_refused', { kind: 'unavailable', reason: 'server' }],
  ['game_token_audience_refused', { kind: 'unavailable', reason: 'server' }],
  ['game_token_bad_request', { kind: 'unavailable', reason: 'server' }],
  ['a_code_from_next_year', { kind: 'unavailable', reason: 'server' }],
  [{ state: 'unavailable' }, { kind: 'unavailable', reason: 'server' }],
]
for (const [input, expected] of CHIPS) {
  const identity = typeof input === 'string' ? { state: 'unavailable', code: input } : input
  eq(chipOf(identity), expected, `chip for ${JSON.stringify(identity)}`)
}
for (const state of ['pending', ...IDENTITY_STATES]) ok(chipOf({ state }).kind, `every state has a chip: ${state}`)

// ---- The client, against fakes ----
// The world itself is qa/fixtures/identity-world.mjs: the same fake parent,
// bridge, timers, clock and fetch are what qa/hive-board-contract.mjs needs to
// reach a signed-in person, and a second copy of a handshake is a second
// version of it. This gate still owns every assertion about it.
const ask = (world) => world.lastNonce(world.log.bridgePosts)
const answer = (nonce, state, extra = {}) => ({ v: 1, type: 'tri-identity', nonce, state, ...extra })

const restore = trapGlobals()
let world
try {
  // 1. Another origin asks nobody.
  world = fakeWorld({ origin: 'https://ghashtag.github.io' })
  world.start()
  eq([world.log.mounts.length, world.log.bridgePosts.length, world.log.parentPosts.length, world.log.fetches.length, world.handler], [0, 0, 0, 0, null], 'another origin mounts no bridge, posts nothing, fetches nothing, listens to nothing')
  eq(world.client.getSnapshot(), { state: 'unavailable', code: 'not_t27' })
  world.client.retry()
  world.client.signIn()
  eq([world.log.mounts.length, world.log.bridgePosts.length, world.log.parentPosts.length], [0, 0, 0], 'Retry and sign-in on another origin do nothing')

  // 2-5. Top level on t27.ai: the bridge.
  world = fakeWorld()
  world.start()
  eq(world.log.mounts, [bridgeUrl('en')], 'one bridge frame at the bridge address, in English by default')
  eq(world.log.bridgePosts.length, 0, 'nothing is posted before the bridge loads')
  eq(world.timer(IDENTITY_ANSWER_MS).length, 1, 'the pending chip has a deadline from the mount, not from the load')
  eq(world.client.inPlayer(), false, 'top level is not the player')
  world.load()
  eq(world.log.bridgePosts.length, 1, 'one request once the bridge loads')
  const first = world.log.bridgePosts[0]
  eq(first.t, APP_ORIGIN, 'the request names the app origin as its target')
  eq(Object.keys(first.m).sort(), ['nonce', 'type', 'v'], 'the request carries v, type and nonce only')
  eq([first.m.v, first.m.type], [1, 'tri-identity-request'])
  ok(/^[0-9a-f]{32}$/.test(first.m.nonce), 'a 32-hex nonce')
  eq(world.log.parentPosts.length, 0, 'the parent is not asked at top level')
  eq(world.timer(IDENTITY_ANSWER_MS).length, 1, 'one answer deadline is set')

  // Ignored: a wrong origin, a wrong source (the parent), a wrong nonce.
  await world.deliver(signedIn(first.m.nonce), { origin: 'https://evil.example' })
  await world.deliver(signedIn(first.m.nonce), { source: world.parent })
  await world.deliver(signedIn(first.m.nonce), { source: { postMessage() {} } })
  await world.deliver(signedIn('f'.repeat(32)))
  eq([world.client.getSnapshot().state, world.log.fetches.length], ['pending', 0], 'a wrong origin, a wrong source and a wrong nonce change nothing and fetch nothing')

  // consent-required shows the frame.
  await world.deliver(answer(first.m.nonce, 'consent-required'))
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
  ok(init.signal && typeof init.signal.aborted === 'boolean', 'whoami carries an abort signal')
  const rpc = JSON.parse(init.body)
  eq([rpc.method, rpc.params.name, rpc.params.arguments], ['tools/call', 'whoami', {}], 'the call is whoami')
  eq(world.client.getSnapshot(), { state: 'signed-in', name: 'Ada', avatar: 'https://cdn.example/ada.jpg', role: 'owner' }, 'the snapshot: name, avatar, role, and no token')
  eq(world.timer(WHOAMI_TIMEOUT_MS).length, 0, 'an answered whoami leaves no deadline behind')

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
  await world.deliver(answer(null, 'signed-out'))
  eq(world.client.getSnapshot(), { state: 'signed-out' }, 'a proactive signed-out clears the identity')
  eq(world.timer(270000).length, 0, 'and cancels the renewal')

  // unavailable with the server's code.
  await world.deliver(answer(null, 'unavailable', { code: 'game_token_parent_not_web' }))
  eq(world.client.getSnapshot(), { state: 'unavailable', code: 'game_token_parent_not_web' })
  eq(world.timerCount(), 0, 'a refusal is not asked again by itself')

  // 3. The token went nowhere but the Authorization header.
  const elsewhere = JSON.stringify([world.log.bridgePosts, world.log.parentPosts, world.log.mounts, world.log.srcs, world.log.snapshots, world.log.fetches.map((f) => ({ url: f.url, body: f.body }))])
  ok(!elsewhere.includes(TOKEN) && !elsewhere.includes('eyJ'), 'the token is in no message, frame address, snapshot, URL or body')
  eq(TRAPPED, [], 'no window, document, storage, location, history or console was touched')

  // expired: the bridge's "the tab never signed out, nothing refreshed it".
  world = fakeWorld()
  world.start()
  world.load()
  await world.deliver(signedIn(ask(world)))
  await world.deliver(answer(null, 'expired'))
  eq([world.client.getSnapshot(), world.visible, world.timer(270000).length, world.timerCount()], [{ state: 'expired' }, false, 0, 0], 'expired forgets the token, hides the frame, renews nothing and retries nothing')
  eq(world.log.fetches.length, 1, 'expired calls nothing')

  // No answer: unavailable, a late answer refused, and the frame is loaded again next time.
  world = fakeWorld()
  world.start()
  world.load()
  const silent = ask(world)
  await world.fire(IDENTITY_ANSWER_MS)
  eq(world.client.getSnapshot(), { state: 'unavailable', code: 'no_answer' }, 'a silent bridge is unavailable')
  await world.deliver(signedIn(silent))
  eq([world.client.getSnapshot().state, world.log.fetches.length], ['unavailable', 0], 'an answer after the deadline is refused')
  eq(world.timer(5000).length, 1, 'no answer is asked again after 5 s')
  await world.fire(5000)
  eq([world.log.srcs, world.log.bridgePosts.length], [[bridgeUrl('en')], 1], 'the next try loads the bridge frame again (it may hold an error page) and waits for its load')
  world.load()
  eq(world.log.bridgePosts.length, 2, 'then asks')

  // The bridge never loads: pending ends at the deadline counted from the mount.
  world = fakeWorld()
  world.start()
  await world.fire(IDENTITY_ANSWER_MS)
  eq([world.client.getSnapshot(), world.log.bridgePosts.length], [{ state: 'unavailable', code: 'no_answer' }, 0], 'a bridge that never loads ends the pending chip after 10 s')

  // A slow bridge is not a broken one (a cold visit on a slow link: its document
  // takes longer than the deadline). The chip says so, but the frame is not
  // reloaded by the retry or by Retry, and it is asked as soon as it loads.
  world = fakeWorld()
  world.start()
  await world.fire(IDENTITY_ANSWER_MS)
  eq(world.client.getSnapshot(), { state: 'unavailable', code: 'no_answer' }, 'a bridge still loading at the deadline: no answer on the chip')
  world.load()
  eq(world.log.bridgePosts.length, 1, 'the slow bridge is asked as soon as it loads, not at the next retry')
  await world.deliver(answer(ask(world), 'signed-out'))
  eq([world.client.getSnapshot(), world.log.mounts.length, world.log.srcs, world.timerCount()], [{ state: 'signed-out' }, 1, [], 0], 'and its answer is heard: one load, nothing left running')
  world = fakeWorld()
  world.start()
  await world.fire(IDENTITY_ANSWER_MS)
  await world.fire(5000)
  world.client.retry()
  eq([world.log.mounts.length, world.log.srcs, world.log.bridgePosts.length], [1, [], 0], 'the retry and Retry leave a loading bridge loading: no reload')
  world.load()
  eq(world.log.bridgePosts.length, 1, 'and it is asked once it loads')

  // Back off on failures that may pass: 5 s, 15 s, 60 s, 300 s, 300 s.
  world = fakeWorld()
  world.start()
  world.load()
  for (const [i, code] of ['network', 'http_503', 'game_token_rate_limited', 'network', 'no_answer_is_not_this'].entries()) {
    if (i === 4) break
    await world.deliver(answer(ask(world), 'unavailable', { code }))
    eq(world.client.getSnapshot(), { state: 'unavailable', code }, `failure ${i + 1}: ${code} is shown`)
    const pause = [5000, 15000, 60000, 300000][i]
    eq(world.timer(pause).length, 1, `failure ${i + 1}: asked again after ${pause / 1000} s`)
    const posts = world.log.bridgePosts.length
    await world.fire(pause)
    eq(world.log.bridgePosts.length, posts + 1, `failure ${i + 1}: the pause over, one request`)
  }
  await world.deliver(answer(ask(world), 'unavailable', { code: 'http_500' }))
  eq(world.timer(300000).length, 1, 'the pause is capped at 5 min')
  await world.fire(300000)
  await world.deliver(answer(ask(world), 'signed-out'))
  eq(world.timerCount(), 0, 'an answer ends the back-off')
  await world.deliver(answer(null, 'unavailable', { code: 'network' }))
  eq(world.timer(5000).length, 1, 'and the next failure starts again at 5 s')

  // A refusal is not retried by itself; Retry asks at once.
  world = fakeWorld()
  world.start()
  world.load()
  await world.deliver(answer(ask(world), 'unavailable', { code: 'game_token_credential_rejected' }))
  eq(world.timerCount(), 0, 'credential_rejected waits for a person')
  world.client.retry()
  eq(world.log.bridgePosts.length, 2, 'Retry asks at once')

  // Coming back online asks at once; a hidden page asks nothing until visible.
  world = fakeWorld()
  world.start()
  world.load()
  await world.deliver(answer(ask(world), 'unavailable', { code: 'network' }))
  await world.online()
  eq([world.log.bridgePosts.length, world.timer(5000).length], [2, 0], 'online: asked at once, the pending pause dropped')
  await world.deliver(signedIn(ask(world)))
  await world.setHidden(true)
  await world.fire(270000)
  eq(world.log.bridgePosts.length, 2, 'the renewal of a hidden page asks nothing')
  await world.setHidden(false)
  eq(world.log.bridgePosts.length, 3, 'becoming visible asks what was owed')
  await world.setHidden(true)
  await world.setHidden(false)
  eq(world.log.bridgePosts.length, 3, 'a visibility change with nothing owed asks nothing')

  // Nobody looking: timers stop, the frame is blanked; back: ask only when needed.
  world = fakeWorld()
  const chipA = world.start()
  world.load()
  await world.deliver(signedIn(ask(world)))
  chipA()
  eq([world.timer(270000).length, world.log.srcs], [0, [null]], 'the last subscriber leaving stops the renewal and blanks the bridge frame')
  world.advance(100000)
  const chipB = world.start()
  eq([world.log.bridgePosts.length, world.log.srcs.length], [1, 1], 'back with 200 s left: nothing asked, nothing loaded')
  eq(world.timer(170000).length, 1, 'the renewal resumes at 30 s before expiry')
  chipB()
  world.advance(180000)
  world.start()
  eq(world.log.srcs.at(-1), bridgeUrl('en'), 'back with 20 s left: the bridge loads again')
  world.load()
  eq(world.log.bridgePosts.length, 2, 'and is asked once loaded')
  eq(world.client.getSnapshot().state, 'signed-in', 'the chip keeps the person meanwhile')

  world = fakeWorld()
  const chipC = world.start()
  world.load()
  await world.deliver(answer(ask(world), 'unavailable', { code: 'network' }))
  chipC()
  eq(world.timerCount(), 0, 'a pending retry stops when nobody looks')

  // A newer request replaces the one waiting for the click, as in bridge.js.
  world = fakeWorld()
  world.start()
  world.load()
  const waiting = ask(world)
  await world.deliver(answer(waiting, 'consent-required'))
  await world.deliver(answer(null, 'signed-in'))
  const newer = ask(world)
  ok(newer !== waiting, 'a push while the click is awaited asks again with a fresh nonce')
  await world.deliver(signedIn(waiting))
  eq(world.log.fetches.length, 0, 'the replaced nonce is refused')
  await world.deliver(signedIn(newer))
  eq([world.client.getSnapshot().state, world.log.fetches.length], ['signed-in', 1], 'the newer nonce is heard')

  // An answer that says signed in without a token is not an identity.
  world = fakeWorld()
  world.start()
  world.load()
  await world.deliver(answer(ask(world), 'signed-in'))
  eq([world.client.getSnapshot(), world.log.bridgePosts.length], [{ state: 'unavailable', code: 'no_token' }, 1], 'no token in an answer: unavailable, no loop')
  await world.deliver(answer(null, 'signed-in'))
  eq(world.log.bridgePosts.length, 2, 'a tokenless push asks once')

  // The consent frame is fixed above every route: it shows only while someone
  // subscribes (the Queen's chip), so leaving the Queen hides it; a prompt
  // waiting for its click keeps its frame loaded.
  world = fakeWorld()
  const leaveChip = world.start()
  const leaveOther = world.client.subscribe(() => {})
  world.load()
  const clickFor = ask(world)
  await world.deliver(answer(clickFor, 'consent-required'))
  eq(world.visible, true, 'consent-required with a subscriber shows the frame')
  leaveOther()
  eq(world.visible, true, 'one of two subscribers leaving keeps it')
  leaveChip()
  eq([world.visible, world.log.srcs], [false, []], 'the last subscriber leaving hides it, and keeps the waiting prompt loaded')
  const backChip = world.start()
  eq([world.visible, world.log.bridgePosts.length], [true, 1], 'a subscriber coming back while the click is awaited shows it again, asking nothing')
  await world.deliver(signedIn(clickFor))
  eq([world.client.getSnapshot().state, world.visible], ['signed-in', false], 'the click then signs in and hides it')
  backChip()
  world.start()
  eq(world.visible, false, 'signed in, a new subscriber does not show it')

  world = fakeWorld()
  const leftEarly = world.start()
  world.load()
  const early = ask(world)
  leftEarly()
  eq(world.log.srcs, [null], 'the last subscriber leaving before the answer blanks the frame')
  await world.deliver(answer(early, 'consent-required'))
  eq([world.client.getSnapshot().state, world.visible], ['pending', false], 'an answer to the request dropped with the frame is refused')
  world.start()
  eq([world.log.srcs.at(-1), world.log.bridgePosts.length], [bridgeUrl('en'), 1], 'a subscriber coming back loads the bridge again and waits for it')
  world.load()
  await world.deliver(answer(ask(world), 'consent-required'))
  eq([world.client.getSnapshot().state, world.visible], ['consent-required', true], 'the new answer shows the frame')

  // Not now in the bridge: the frame hides for the tab, the chip keeps "Confirm in TRI".
  world = fakeWorld()
  const dismissChip = world.start()
  world.load()
  const prompt = ask(world)
  await world.deliver(answer(prompt, 'consent-required'))
  await world.deliver(dismiss(prompt), { source: world.parent })
  await world.deliver(dismiss(prompt), { origin: GAME_ORIGIN })
  await world.deliver(dismiss('e'.repeat(32)))
  eq([world.visible, world.client.getSnapshot()], [true, { state: 'consent-required' }], 'a dismiss from another window, another origin or for another request changes nothing')
  await world.deliver(dismiss(prompt))
  eq([world.visible, world.client.getSnapshot(), world.log.bridgePosts.length], [false, { state: 'consent-required', dismissed: true }, 1], 'Not now hides the frame, keeps consent-required, asks nothing')
  await world.deliver(signedIn(prompt))
  eq(world.log.fetches.length, 0, 'the dismissed request is spent: a token for it is refused')
  dismissChip()
  world.start()
  eq([world.visible, world.log.bridgePosts.length], [false, 1], 'leaving and coming back does not ask again after Not now')
  world.client.retry()
  eq([world.log.bridgePosts.length, world.client.getSnapshot().dismissed], [2, true], '"Confirm in TRI" asks the bridge again')
  eq(world.visible, false, 'and the frame stays hidden until the bridge answers (its prompt was hidden by Not now)')
  await world.deliver(answer(ask(world), 'consent-required'))
  eq([world.visible, world.client.getSnapshot()], [true, { state: 'consent-required' }], 'and the prompt is shown again')
  world = fakeWorld()
  world.start()
  world.load()
  await world.deliver(signedIn(ask(world)))
  await world.deliver(dismiss(ask(world)))
  eq(world.client.getSnapshot().state, 'signed-in', 'a dismiss when no prompt waits changes nothing')

  // whoami: signed in at once, then the name; a deadline; one silent retry on 401.
  world = fakeWorld({ whoami: (u, i) => new Promise((_, reject) => i.signal.addEventListener('abort', () => reject(new Error('aborted')))) })
  world.start()
  world.load()
  await world.deliver(signedIn(ask(world)))
  eq(world.client.getSnapshot(), { state: 'signed-in' }, 'signed in as soon as the token is here, before whoami answers')
  eq(world.timer(WHOAMI_TIMEOUT_MS).length, 1, 'whoami has a 5 s deadline')
  await world.fire(WHOAMI_TIMEOUT_MS)
  eq([world.log.fetches[0].init.signal.aborted, world.client.getSnapshot()], [true, { state: 'signed-in' }], 'a hung whoami is abandoned: signed in, name unknown')
  eq(world.timer(270000).length, 1, 'and the renewal still stands')

  let whoamiStatus = 401
  world = fakeWorld({ whoami: () => ({ ok: whoamiStatus === 200, status: whoamiStatus, json: async () => WHOAMI }) })
  world.start()
  world.load()
  await world.deliver(signedIn(ask(world)))
  eq([world.log.bridgePosts.length, world.client.getSnapshot().state, world.timer(270000).length], [2, 'signed-in', 0], 'whoami refused once: the token is dropped and the player asked again, silently')
  await world.deliver(signedIn(ask(world)))
  eq([world.client.getSnapshot(), world.timer(270000).length, world.log.bridgePosts.length], [{ state: 'unavailable', code: 'whoami_rejected' }, 0, 2], 'refused twice: whoami_rejected, no loop')
  whoamiStatus = 200
  world.client.retry()
  await world.deliver(signedIn(ask(world)))
  eq(world.client.getSnapshot().name, 'Ada', 'Retry then works again')

  // whoami refused after the last subscriber left (rule 5): the silent retry
  // waits for someone looking; nothing is loaded, asked or fetched before.
  let refuse = null
  world = fakeWorld({ whoami: () => new Promise((resolve) => { refuse = () => resolve({ ok: false, status: 401, json: async () => ({}) }) }) })
  const leaving = world.start()
  world.load()
  await world.deliver(signedIn(ask(world)))
  eq(world.log.fetches.length, 1, 'whoami in flight')
  leaving()
  eq(world.log.srcs, [null], 'the last subscriber left while whoami was out: the frame is blanked')
  refuse()
  await settleAll()
  eq([world.log.srcs, world.log.bridgePosts.length, world.log.fetches.length, world.timerCount()], [[null], 1, 1, 0], 'whoami refused with nobody looking: no bridge load, no request, no second whoami, no timer')
  world.start()
  eq(world.log.srcs.at(-1), bridgeUrl('en'), 'someone looks again: the bridge loads')
  world.load()
  eq(world.log.bridgePosts.length, 2, 'and the player is asked for a fresh token')

  // whoami offline: signed in, no name.
  world = fakeWorld({ whoami: () => { throw new Error('offline') } })
  world.start()
  world.load()
  await world.deliver(signedIn(ask(world)))
  eq(world.client.getSnapshot(), { state: 'signed-in' }, 'offline whoami: signed in without a name')

  // The bridge speaks the page's language.
  world = fakeWorld()
  world.client.setLanguage('ru')
  world.start()
  eq(world.log.mounts, [bridgeUrl('ru')], 'a Russian page mounts the Russian bridge')
  world.load()
  await world.deliver(answer(ask(world), 'signed-out'))
  world.client.setLanguage('ru')
  eq(world.log.srcs, [], 'the same language loads nothing')
  world.client.setLanguage('en')
  world.load()
  eq([world.log.srcs, world.log.bridgePosts.length], [[bridgeUrl('en')], 1], 'switching to English reloads the bridge, asking nothing when nothing waits')
  await world.deliver(answer(null, 'signed-in'))
  await world.deliver(answer(ask(world), 'consent-required'))
  world.client.setLanguage('ru')
  eq([world.log.srcs.at(-1), world.log.bridgePosts.length], [bridgeUrl('ru'), 2], 'switching while a prompt waits reloads the bridge in that language')
  world.load()
  eq(world.log.bridgePosts.length, 3, 'and asks again, so the prompt comes back in it')

  // Primed at the page's entry: the answer is ready before the chip subscribes.
  world = fakeWorld()
  world.client.prime()
  eq(world.log.mounts, [bridgeUrl('en')], 'prime mounts the bridge without a subscriber')
  world.load()
  await world.deliver(answer(ask(world), 'consent-required'))
  eq([world.client.getSnapshot().state, world.visible], ['consent-required', false], 'a prompt with nobody looking stays hidden')
  world.start()
  eq([world.visible, world.log.bridgePosts.length, world.log.mounts.length], [true, 1, 1], 'the chip subscribing shows it, asking and mounting nothing more')

  // 2. In the Hive: the parent, and only the parent.
  world = fakeWorld({ isTop: false, ancestorOrigins: [APP_ORIGIN] })
  world.start()
  eq([world.log.mounts.length, world.log.parentPosts.length], [0, 1], 'in the Hive no bridge is mounted and the parent is asked at once')
  eq(world.log.parentPosts[0].t, APP_ORIGIN, 'the parent is asked with the app origin as target')
  eq(world.client.inPlayer(), true, 'in the Hive the player frames the game')
  const hiveNonce = world.lastNonce(world.log.parentPosts)
  await world.deliver(signedIn(hiveNonce), { source: world.bridgeWindow })
  eq(world.client.getSnapshot().state, 'pending', 'in the Hive a window other than the parent is not heard')
  await world.deliver(signedIn(hiveNonce), { source: world.parent, origin: GAME_ORIGIN })
  eq(world.client.getSnapshot().state, 'pending', 'in the Hive the parent must be on the app origin')
  await world.deliver(answer(hiveNonce, 'signed-out'), { source: world.parent })
  eq(world.client.getSnapshot().state, 'signed-out', 'in the Hive the parent is heard')
  world.client.signIn()
  eq(world.log.parentPosts.at(-1), { m: { v: 1, type: 't27-app', kind: 'sign-in' }, t: APP_ORIGIN }, "signing in inside the Hive asks the player (hive.ts isSignInRequest), targeting the app's origin")
  // The player signs the person in in its own modal and tells the game nothing
  // (hive.ts only answers requests): the game asks again when the person comes back to it.
  const hiveAsks = () => world.log.parentPosts.filter((p) => p.m.type === 'tri-identity-request').length
  const hiveAnswer = async (state) => world.deliver(state === 'signed-in' ? signedIn(world.lastNonce(world.log.parentPosts.filter((p) => p.m.type === 'tri-identity-request'))) : answer(world.lastNonce(world.log.parentPosts.filter((p) => p.m.type === 'tri-identity-request')), state), { source: world.parent })
  await world.comeBack()
  eq(hiveAsks(), 2, 'after Sign in, the person coming back to the game asks the player again')
  await world.comeBack()
  eq(hiveAsks(), 2, 'a second return while that request is open asks nothing more')
  await hiveAnswer('signed-out')
  await world.setHidden(true)
  await world.comeBack()
  await world.setHidden(false)
  eq(hiveAsks(), 2, 'a hidden page asks nothing on a return')
  await world.comeBack()
  eq(hiveAsks(), 3, 'still signed out (the modal was only closed): the next return asks again')
  await hiveAnswer('signed-in')
  eq([world.client.getSnapshot().state, world.log.fetches.length], ['signed-in', 1], 'signed in inside the player: the chip shows the person')
  await world.comeBack()
  eq(hiveAsks(), 3, 'once signed in, coming back asks nothing')
  world = fakeWorld({ isTop: false, ancestorOrigins: [APP_ORIGIN] })
  world.start()
  await world.deliver(answer(world.lastNonce(world.log.parentPosts), 'signed-out'), { source: world.parent })
  await world.comeBack()
  eq(world.log.parentPosts.length, 1, 'in the Hive without Sign in, coming back asks nothing')
  world = fakeWorld()
  world.start()
  world.client.signIn()
  eq(world.log.parentPosts.length, 0, 'at top level signing in posts nothing to the parent')
  eq(world.returnHandler, null, 'at top level nothing listens for a return')
  eq(TRAPPED, [], 'still nothing trapped')
} finally {
  restore()
}
await settleAll()

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
  [/postMessage\([^)]*["']\*["']/, "never posts to '*'"],
]) ok(!pattern.test(lib), `triIdentity.ts: ${rule}`)
ok(/credentials:\s*["']omit["']/.test(lib), "triIdentity.ts: credentials 'omit'")

// The console's agent-key path is left as it was (an owner decision, not this change's).
const crm = read('src/lib/crmClient.ts')
ok(crm.includes("const AGENT_KEY = 't27.crm.key'") && crm.includes("if (key) return { 'X-Agent-Key': key }"), 'crmClient keeps its agent-key path unchanged')

// ---- 8. Wired into the Queen ----
const chip = code('src/components/QueenIdentity.tsx')
ok(!/dangerouslySetInnerHTML|innerHTML/.test(chip), 'the chip renders text nodes only')
ok(/useSyncExternalStore\(identity\.subscribe, identity\.getSnapshot\)/.test(chip), 'the chip reads the store')
ok(/role="status"/.test(chip) && /aria-live="polite"/.test(chip) && /lang=\{/.test(chip), 'the chip is a polite status region with its language')
ok(/signInHref\(view, HUD_VIEWS, screen, SCREEN_IDS\)/.test(chip) && /target="_top"/.test(chip), 'Sign in is a top-level link to a fixed route')
ok(/identity\.inPlayer\(\)/.test(chip) && /identity\.signIn\(\)/.test(chip), 'inside the Hive Sign in asks the player')
ok(/const chip = chipOf\(me\)/.test(chip), 'the chip derives its kind from chipOf')
for (const kind of ['pending', 'signed-in', 'consent-required', 'signed-out', 'expired', 'sign-in-again', 'unavailable', 'web-only', 'off-site']) {
  ok(new RegExp(`case ["']${kind}["']`).test(chip), `the chip renders ${kind}`)
}
ok(!/return null/.test(chip), 'the chip never renders nothing')
const queen = read('src/pages/Queen.tsx')
ok(/\{!embedded && \(\s*<QueenIdentity/.test(queen), 'the Queen renders the chip only when not embedded')
ok(/<QueenIdentity[\s\S]{0,700}<\/?button\s+type="button"\s+data-tool="agent"/.test(queen), 'the chip sits in the tools row, before the agent button')
ok(/<QueenIdentity\s+view=\{view\}\s+screen=\{view === "tri" \? hashParams\.get\("screen"\) : null\}\s+lang=\{lang\}/.test(queen), 'the Queen hands the chip its view, the TRI screen and the language')
for (const key of ['identitySignIn', 'identitySignInTitle', 'identitySignInAgain', 'identitySignedIn', 'identityRoleKeeper', 'identityRoleOwner', 'identityRoleBee',
  'identityPending', 'identityConfirm', 'identityConfirmTitle', 'identityConfirmAgainTitle', 'identityResume', 'identityResumeTitle', 'identityRetry',
  'identityOffline', 'identityNoAnswer', 'identityBusy', 'identityRefused', 'identityUnavailable', 'identityWebOnly', 'identityOffSite']) {
  eq([...queen.matchAll(new RegExp(`^\\s*${key}: "[^"]+",$`, 'gm'))].length, 2, `COPY has ${key} in en and ru`)
}
ok(/^\s*identitySignInAgain: "Sign in again in TRI",$/m.test(queen), 'the English copy says "Sign in again in TRI"')
ok(/^\s*identityConfirm: "Confirm in TRI",$/m.test(queen) && /^\s*identityResume: "Resume in TRI",$/m.test(queen), 'the English copy says "Confirm in TRI" and "Resume in TRI"')
const main = code('src/main.tsx')
ok(main.includes('triIdentity().prime()') && main.includes("params.get('embed') !== '1'") && main.includes('/^#\\/queen(?:\\?|$)/'), 'the entry primes the bridge on the Queen address only, never for an embedded preview')

console.log(`TRI identity contract: PASS (${checks} checks)`)
