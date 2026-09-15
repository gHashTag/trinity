// The Queen's TRI tab: the app at app.t27.ai inside the game, one screen per address.
//
// Pure, no browser. Holds src/lib/triScreens.ts to the rules the tab depends on:
// every frame URL keeps the app's origin whatever the address says; the address
// round-trips screen= and path= and the shell's tab write and TRI's screen write
// keep each other's keys; only the app's own messages from TRI's own frame are
// heard; the nesting guard knows when the game already runs inside the app; and
// the tab is wired into the rail, the modules and the copy at the key r.
//
//   node --experimental-strip-types qa/tri-screens-contract.mjs

import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import {
  APP_ORIGIN,
  TRI_SCREENS,
  TRI_BUTTONS,
  DEFAULT_TRI_SCREEN,
  triScreenOf,
  triFrameSrc,
  triPathOf,
  appScreenUrl,
  screenOfAppPath,
  acceptAppMessage,
  insidePlayer,
  hashParamsOf,
  tabAddress,
  triAddress,
} from '../src/lib/triScreens.ts'
import { HUD_VIEWS, HUD_KEYS, HUD_CODES, hudKeyIndex } from '../src/components/queenHud.ts'
import { MODULES } from '../src/lib/queenModules.ts'

const read = (rel) => readFileSync(new URL(`../${rel}`, import.meta.url), 'utf8')

// ---- 1. Every frame URL stays on the app's origin ----
// The checker proves it can fail before it reads the real table.
function originProblems(table) {
  const problems = []
  for (const { screen, route } of table) {
    const url = `${APP_ORIGIN}${route}?embed=1&lang=en`
    let origin = null
    try { origin = new URL(url).origin } catch { /* unparseable is a problem too */ }
    if (!route.startsWith('/') || route.startsWith('//') || origin !== APP_ORIGIN) problems.push(`${screen}: ${url}`)
  }
  return problems
}
assert.ok(originProblems([{ screen: 'x', route: '@evil.example/feed' }]).length === 1, 'self-test: a route that moves the origin must be caught')
assert.ok(originProblems([{ screen: 'x', route: '.evil.example/feed' }]).length === 1, 'self-test: a route that extends the host must be caught')
assert.deepEqual(originProblems(TRI_SCREENS), [], 'every TRI route keeps the app origin')

for (const { screen, route } of TRI_SCREENS) {
  for (const lang of ['en', 'ru', 'de', 'zh', 'es']) {
    const src = new URL(triFrameSrc(screen, lang))
    assert.equal(src.origin, APP_ORIGIN, `${screen}/${lang}: frame origin`)
    assert.equal(src.pathname, route, `${screen}/${lang}: frame route`)
    assert.equal(src.searchParams.get('embed'), '1', `${screen}: embed=1`)
    assert.equal(src.searchParams.get('lang'), lang, `${screen}: lang`)
  }
}
assert.equal(triFrameSrc('video', 'ru'), 'https://app.t27.ai/generate/video?embed=1&lang=ru')
assert.equal(triFrameSrc('feed', 'en'), 'https://app.t27.ai/feed?embed=1&lang=en')
{
  // lang is one query value: it cannot add a parameter of its own.
  const hostile = new URL(triFrameSrc('feed', 'en&x=1'))
  assert.equal(hostile.searchParams.get('x'), null, 'a lang with & adds no parameter')
  assert.equal(hostile.searchParams.get('lang'), 'en&x=1', 'lang is encoded as one value')
  assert.equal(hostile.searchParams.get('embed'), '1')
}
// The CRM is addressed at its list: client ids are customers' Telegram ids.
assert.equal(triFrameSrc('crm', 'en', '/crm/42'), 'https://app.t27.ai/crm?embed=1&lang=en', 'no CRM client in the frame URL from the address')
assert.equal(triFrameSrc('crm', 'en', '/crm/42/chat'), 'https://app.t27.ai/crm?embed=1&lang=en')
assert.equal(triFrameSrc('profile', 'en', '/durov'), 'https://app.t27.ai/durov?embed=1&lang=en', 'one profile is addressable')
for (const [screen, hostile] of [['crm', '//evil.example'], ['crm', '/crm/../../x'], ['crm', '/crm/1?x=1'], ['feed', '/crm/42'], ['profile', '/hive'], ['profile', '/templates'], ['profile', '@evil.example'], ['profile', '/a/b']]) {
  const src = triFrameSrc(screen, 'en', hostile)
  assert.equal(new URL(src).origin, APP_ORIGIN, `${screen} + ${hostile}: origin`)
  assert.equal(new URL(src).pathname, TRI_SCREENS.find((s) => s.screen === screen).route, `${screen} + ${hostile}: falls back to the screen root`)
}
assert.equal(appScreenUrl('chat'), 'https://app.t27.ai/chat')
assert.equal(appScreenUrl('crm', '/crm/7'), 'https://app.t27.ai/crm', 'the link out names no CRM client either')
assert.equal(appScreenUrl('profile', '/durov/'), 'https://app.t27.ai/durov')
assert.equal(appScreenUrl('crm', '//evil.example'), 'https://app.t27.ai/crm')

// ---- 2. The screen table and the app's paths ----
assert.equal(DEFAULT_TRI_SCREEN, 'feed')
assert.deepEqual([...TRI_BUTTONS], ['feed', 'chat', 'script', 'profile', 'crm'])
assert.equal(new Set(TRI_SCREENS.map((s) => s.screen)).size, TRI_SCREENS.length, 'screens are unique')
for (const s of ['hive', 'search', 'learn', 'blog', 'home', 'templates']) assert.ok(!TRI_SCREENS.some((x) => x.screen === s), `${s} is not a TRI screen`)
assert.equal(triScreenOf('chat'), 'chat')
assert.equal(triScreenOf('nope'), 'feed')
assert.equal(triScreenOf(null), 'feed')
assert.equal(triScreenOf(undefined), 'feed')
assert.equal(triScreenOf('constructor'), 'feed', 'an object key is not a screen')
const pathCases = [
  ['/feed', 'feed'], ['/feed/', 'feed'], ['/chat', 'chat'], ['/generate', 'script'], ['/generate/script', 'script'],
  ['/generate/audio', 'audio'], ['/generate/image', 'image'], ['/generate/avatar', 'avatar'], ['/generate/video', 'video'],
  ['/generate/editor', 'editor'], ['/editor', 'editor'], ['/generate/nope', null], ['/profile', 'profile'],
  ['/crm', 'crm'], ['/crm/123', 'crm'], ['/crm/123/chat', 'crm'], ['/crm/123/other', null],
  ['/someone', 'profile'], ['/hive', null], ['/templates', null], ['/blog', null], ['/home', null], ['/search', null],
  ['/learn', null], ['/privacy-policy', null], ['/instagram/callback', null], ['//evil.example/crm', null], ['crm', null], ['', null],
]
for (const [path, expected] of pathCases) assert.equal(screenOfAppPath(path), expected, `screenOfAppPath(${JSON.stringify(path)})`)
for (const raw of ['/crm/42', '/crm/42/', '/crm/42/chat', '/crm', '/crm/..', '/crm/a.b', '/crm/a@b', '/crm/a:b']) {
  assert.equal(triPathOf('crm', raw), null, `triPathOf('crm', ${JSON.stringify(raw)}): no CRM client id in the address`)
}
assert.equal(screenOfAppPath('/crm/42/'), 'crm', 'a trailing slash keeps the screen')
assert.equal(triPathOf('profile', '/profile'), null, 'the root is not a deep path')
assert.equal(triPathOf('profile', '/someone'), '/someone')
assert.equal(triPathOf('profile', '/someone/'), '/someone', 'a trailing slash keeps the profile path')
assert.equal(triPathOf('profile', '/profile/'), null)
for (const raw of ['/..', '/a.b', '/a@b', '/a:b', '/a%2Fb', '//someone', '/hive/', '/someone//']) {
  assert.equal(triPathOf('profile', raw), null, `triPathOf('profile', ${JSON.stringify(raw)})`)
}
assert.equal(triPathOf('chat', '/someone'), null, 'a path belongs to its own screen only')
assert.equal(triPathOf('profile', null), null)

// ---- 3. The address: both writers build from the live hash ----
const params = (p) => Object.fromEntries(p)
assert.deepEqual(params(hashParamsOf('#/queen?tab=tri&screen=chat')), { tab: 'tri', screen: 'chat' })
assert.deepEqual(params(hashParamsOf('#/queen')), {})
assert.deepEqual(params(tabAddress('#/queen?tab=tri&screen=chat&path=/crm/1&layers=foundation', 'kanban')), { tab: 'kanban', layers: 'foundation' }, 'leaving TRI drops its screen and path, keeps other keys')
assert.deepEqual(params(tabAddress('#/queen?tab=kanban', 'comb')), {}, 'the comb carries no tab')
assert.deepEqual(params(tabAddress('#/queen?screen=chat', 'tri')), { screen: 'chat', tab: 'tri' }, 'entering TRI keeps a pending screen')
assert.deepEqual(params(triAddress('#/queen?tab=tri&layers=x', 'chat', null)), { tab: 'tri', layers: 'x', screen: 'chat' })
assert.deepEqual(params(triAddress('#/queen?tab=tri&screen=chat&path=/crm/1', 'feed', null)), { tab: 'tri' }, 'the feed carries no screen')
assert.deepEqual(params(triAddress('#/queen?tab=tri', 'crm', '/crm/42')), { tab: 'tri', screen: 'crm' }, 'a CRM client id is never written to the address')
assert.deepEqual(params(triAddress('#/queen?tab=tri&screen=crm&path=/crm/42', 'crm', null)), { tab: 'tri', screen: 'crm' }, 'an old client path is dropped on the next write')
assert.deepEqual(params(triAddress('#/queen?tab=tri', 'profile', '/durov/')), { tab: 'tri', screen: 'profile', path: '/durov' })
assert.deepEqual(params(triAddress('#/queen?tab=tri', 'profile', '//evil.example')), { tab: 'tri', screen: 'profile' }, 'an unchecked path is not written')
// Two writes inside one pending transition (click TRI, then Agent): the live
// form keeps both keys. The control builds the second write from the stale
// render-time params, as React Router's updater does, and loses the tab.
{
  let hash = '#/queen'
  const navigate = (p) => { const q = String(p); hash = q ? `#/queen?${q}` : '#/queen' }
  navigate(tabAddress(hash, 'tri'))
  navigate(triAddress(hash, 'chat', null))
  assert.deepEqual(params(hashParamsOf(hash)), { tab: 'tri', screen: 'chat' }, 'live writes: tab=tri&screen=chat')
  const stale = '#/queen'
  hash = stale
  navigate(tabAddress(stale, 'tri'))
  const control = hashParamsOf(stale); control.set('screen', 'chat'); navigate(control)
  assert.equal(hashParamsOf(hash).get('tab'), null, 'control: render-time params erase the tab (the failure the live form avoids)')
}

// ---- 4. Messages: the app's own, from TRI's own frame ----
const frame = { name: 'frame' }
const ok = { origin: APP_ORIGIN, source: frame, data: { type: 't27-app', kind: 'route', path: '/generate/video' } }
assert.deepEqual(acceptAppMessage(ok, frame), { kind: 'route', path: '/generate/video' })
assert.deepEqual(acceptAppMessage({ ...ok, data: { type: 't27-app', kind: 'ready', path: '/feed' } }, frame), { kind: 'ready', path: '/feed' })
assert.equal(acceptAppMessage({ ...ok, origin: 'https://evil.example' }, frame), null, 'wrong origin')
assert.equal(acceptAppMessage({ ...ok, origin: 'https://t27.ai' }, frame), null, 'the host itself is not the app')
assert.equal(acceptAppMessage({ ...ok, source: { name: 'other' } }, frame), null, 'wrong source')
assert.equal(acceptAppMessage(ok, null), null, 'no frame, no message')
assert.equal(acceptAppMessage({ ...ok, data: '{"eventType":"iframe_ready"}' }, frame), null, 'telegram-web-app.js JSON string')
assert.equal(acceptAppMessage({ ...ok, data: JSON.stringify(ok.data) }, frame), null, 'a JSON string is never parsed, even one shaped like the app message')
assert.equal(acceptAppMessage({ ...ok, data: { eventType: 'iframe_ready' } }, frame), null, 'a Telegram-shaped object')
assert.equal(acceptAppMessage({ ...ok, data: { type: 't27-app', kind: 'other', path: '/feed' } }, frame), null, 'unknown kind')
assert.equal(acceptAppMessage({ ...ok, data: { type: 't27-app', kind: 'route', path: 'x' } }, frame), null, 'relative path')
assert.equal(acceptAppMessage({ ...ok, data: { type: 't27-app', kind: 'route', path: '//evil.example' } }, frame), null, 'protocol-relative path')
assert.equal(acceptAppMessage({ ...ok, data: [1] }, frame), null, 'array')
assert.equal(acceptAppMessage({ ...ok, data: null }, frame), null, 'null')
// The app failing inside the frame: {type:'t27-app', kind:'error', code}, same origin and source rules.
const failed = { ...ok, data: { type: 't27-app', kind: 'error', code: 'boundary' } }
assert.deepEqual(acceptAppMessage(failed, frame), { kind: 'error', code: 'boundary' })
assert.deepEqual(acceptAppMessage({ ...ok, data: { type: 't27-app', kind: 'error', code: 'storage_blocked' } }, frame), { kind: 'error', code: 'storage_blocked' })
assert.equal(acceptAppMessage({ ...failed, origin: 'https://t27.ai' }, frame), null, 'error: wrong origin')
assert.equal(acceptAppMessage({ ...failed, source: { name: 'other' } }, frame), null, 'error: wrong source')
for (const code of [undefined, 42, '', 'Boundary', 'x'.repeat(65), '<b>', 'a b', ['boundary']]) {
  assert.equal(acceptAppMessage({ ...ok, data: { type: 't27-app', kind: 'error', code } }, frame), null, `error code ${JSON.stringify(code)} is not a code`)
}
assert.equal(acceptAppMessage({ ...ok, data: { type: 'other', kind: 'error', code: 'boundary' } }, frame), null, 'error: wrong type')

// ---- 5. The nesting guard ----
assert.equal(insidePlayer({ isTop: false, ancestorOrigins: [APP_ORIGIN], referrer: '', ownOrigin: 'https://t27.ai' }), true, 'the app frames the game')
assert.equal(insidePlayer({ isTop: false, ancestorOrigins: ['https://web.telegram.org', APP_ORIGIN], referrer: '', ownOrigin: 'https://t27.ai' }), true, 'Telegram Web > app > game')
assert.equal(insidePlayer({ isTop: true, ancestorOrigins: [], referrer: `${APP_ORIGIN}/`, ownOrigin: 'https://t27.ai' }), false, 'top level')
assert.equal(insidePlayer({ isTop: false, ancestorOrigins: [APP_ORIGIN], referrer: '', ownOrigin: APP_ORIGIN }), false, 'the game served from the app origin (/game/)')
assert.equal(insidePlayer({ isTop: false, ancestorOrigins: ['https://t27.ai'], referrer: '', ownOrigin: 'https://t27.ai' }), false, 'the landing frames the game')
assert.equal(insidePlayer({ isTop: false, referrer: `${APP_ORIGIN}/`, ownOrigin: 'https://t27.ai' }), true, 'no ancestorOrigins: the referrer')
assert.equal(insidePlayer({ isTop: false, referrer: 'https://t27.ai/', ownOrigin: 'https://t27.ai' }), false)
assert.equal(insidePlayer({ isTop: false, referrer: 'not a url', ownOrigin: 'https://t27.ai' }), false)

// ---- 6. Wired into the rail, the modules, the copy and the landing ----
const at = HUD_VIEWS.indexOf('tri')
assert.ok(at >= 0, 'HUD_VIEWS includes tri')
assert.equal(HUD_KEYS[at], 'r', 'TRI opens on r')
assert.equal(HUD_KEYS.slice(0, HUD_VIEWS.length).join(''), '1234567890tpr')
// The physical key decides (KeyboardEvent.code), so r opens TRI on a Russian layout too.
assert.equal(HUD_CODES.length, HUD_KEYS.length, 'every key has its physical code')
assert.equal(hudKeyIndex({ code: 'KeyR', key: 'к' }), at, 'Russian layout: code KeyR, key к opens TRI')
assert.equal(hudKeyIndex({ code: 'KeyR', key: 'r' }), at)
assert.equal(hudKeyIndex({ code: 'KeyT', key: 'е' }), HUD_VIEWS.indexOf('tools'))
assert.equal(hudKeyIndex({ code: 'KeyP', key: 'з' }), HUD_VIEWS.indexOf('project'))
assert.equal(hudKeyIndex({ code: 'Digit1', key: '!' }), 0, 'a shifted digit is still its digit')
assert.equal(hudKeyIndex({ code: 'Digit0', key: '0' }), 9)
assert.equal(hudKeyIndex({ code: 'Numpad2', key: '2' }), 1, 'a keypad digit stays its digit')
assert.equal(hudKeyIndex({ code: 'KeyO', key: 'r' }), -1, 'Dvorak: the key printed r on another physical key is not the shortcut')
assert.equal(hudKeyIndex({ code: 'KeyK', key: 'к' }), -1)
assert.equal(hudKeyIndex({ code: '', key: 'r' }), at, 'no code (a scripted event): the character decides')
assert.equal(hudKeyIndex({ code: '', key: 'к' }), -1)
assert.equal(hudKeyIndex({ key: 'R' }), at)
const tri = MODULES.find((m) => m.tab === 'tri')
assert.ok(tri, 'MODULES has tri')
assert.equal(tri.key, 'r')
assert.ok(tri.en.hint.includes('(key r)'), 'en hint names the key')
assert.ok(tri.ru.hint.includes('(клавиша r)'), 'ru hint names the key')
const queen = read('src/pages/Queen.tsx')
const hints = [...queen.matchAll(/^\s*triHint: "([^"]*)",$/gm)].map((m) => m[1])
assert.deepEqual(hints, [tri.en.hint, tri.ru.hint], 'COPY triHint (en, ru) equals the module hints')
assert.match(queen, /view: "tri" as const/, 'the rail lists TRI')
assert.match(queen, /boardView === "tri" \? \(\s*<QueenTri/, 'the view body renders QueenTri')
assert.match(queen, /tabAddress\(window\.location\.hash, next\)/, 'the shell writes its tab from the live hash')
assert.match(read('src/App.tsx'), /module\.tab !== 'tri'/, 'the landing renders no TRI preview (it would load the whole app for every visitor)')
const component = read('src/components/QueenTri.tsx')
assert.doesNotMatch(component, /\.postMessage\(/, 'TRI never posts into the app frame')
assert.match(component, /triAddress\(window\.location\.hash/, 'TRI writes its screen from the live hash')

console.log(`TRI screens contract: PASS (${TRI_SCREENS.length} screens, ${pathCases.length} app paths, key r at position ${at + 1})`)
