// The BROWSER view: the person's own remote browser inside the Queen.
//
// Calls the decisions in src/lib/queenBrowser.ts with real inputs and a fetch
// that records what it was asked. Each rule below is one a wrong edit would
// break quietly: a preview that wakes a pod, a token in a URL, a frame of an
// address whose cookie is third-party.
//
//   node --experimental-strip-types qa/queen-browser-contract.mjs

import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import {
  BROKER_BASE,
  callBroker,
  frameSrcOf,
  panelMode,
  viewOf,
  agentMessages,
  askBrowserAgent,
  readAgentStream,
  readAgentBody,
  AgentSignedOut,
  HISTORY_TURNS,
  frameStateOf,
  shouldReread,
  WINDOW_EVENT,
  readJournal,
  journalLine,
  setWheel,
  shouldRenewWheel,
  WHEEL_RENEW_MS,
} from '../src/lib/queenBrowser.ts'
import { HUD_VIEWS, hudKeyOf, RAIL_VIEWS, railViewOf, BOARD_VIEWS, PROJECT_VIEWS } from '../src/components/queenHud.ts'
import { MODULES } from '../src/lib/queenModules.ts'

const APP = 'https://app.t27.ai'
const signedIn = { source: 'app-session', state: 'signed-in', token: 'tok-123', expiresAt: 1 }
const signedOut = { source: 'app-session', state: 'signed-out', code: 'no_session' }
const bridge = { source: 'bridge' }

// 1. The panel's mode. A preview never becomes ready, even signed in: the
//    homepage renders many previews and none may touch a person's browser.
assert.equal(panelMode({ embedded: true, nested: false, session: signedIn }), 'preview')
assert.equal(panelMode({ embedded: false, nested: true, session: signedIn }), 'nested')
assert.equal(panelMode({ embedded: false, nested: false, session: signedIn }), 'ready')
assert.equal(panelMode({ embedded: false, nested: false, session: signedOut }), 'signin')
// Off the app's origin there is no first-party /live/, whatever else is true.
assert.equal(panelMode({ embedded: false, nested: false, session: bridge }), 'signin')

// 2. The broker call: one header, credentials omitted, the token nowhere else.
function recorder(status, body) {
  const calls = []
  return {
    calls,
    env: {
      token: () => 'tok-123',
      fetch: async (url, init) => {
        calls.push({ url, init })
        return { ok: status >= 200 && status < 300, status, json: async () => body }
      },
    },
  }
}

{
  const r = recorder(200, { ok: true, state: 'live', sessionId: 's1', viewUrl: '/live/s1?t=v' })
  const view = await callBroker(r.env, 'read')
  assert.deepEqual(view, { state: 'live', sessionId: 's1', viewUrl: '/live/s1?t=v' })
  assert.equal(r.calls.length, 1)
  const [{ url, init }] = r.calls
  assert.equal(url, `${BROKER_BASE}/api/browser/session`)
  assert.equal(init.method, 'GET', 'reading never opens a browser')
  assert.equal(init.credentials, 'omit')
  assert.equal(init.headers.Authorization, 'Bearer tok-123')
  assert.ok(!url.includes('tok-123'), 'the token never rides in a URL')
}

{
  const r = recorder(200, { state: 'starting' })
  await callBroker(r.env, 'open')
  assert.equal(r.calls[0].init.method, 'POST')
  const c = recorder(200, { state: 'none' })
  await callBroker(c.env, 'close')
  assert.equal(c.calls[0].init.method, 'DELETE', 'close keeps the logins: the session door, not the profile door')
  assert.ok(!c.calls[0].url.includes('/profile'), 'this view never wipes a profile')
}

// No token: nothing is sent at all.
{
  const r = recorder(200, {})
  r.env.token = () => null
  assert.deepEqual(await callBroker(r.env, 'open'), { state: 'signin' })
  assert.equal(r.calls.length, 0)
}

// The two by-design refusals are states; anything else is a failure.
assert.deepEqual(await callBroker(recorder(401, {}).env, 'read'), { state: 'signin' })
assert.deepEqual(await callBroker(recorder(503, {}).env, 'read'), { state: 'unavailable' })
await assert.rejects(callBroker(recorder(500, {}).env, 'read'))

// 3. The broker's words, narrowed: an unknown state is `none`, never a blank.
assert.deepEqual(viewOf({ state: 'hibernating' }), { state: 'none' })
assert.deepEqual(viewOf(null), { state: 'none' })
assert.deepEqual(viewOf({ state: 'live', viewUrl: 42 }), { state: 'live' })

// 4. What may be framed: our own origin, under /live/, and nothing else.
assert.equal(frameSrcOf('/live/s1?t=v', APP), `${APP}/live/s1?t=v`)
assert.equal(frameSrcOf(`${APP}/live/s1`, APP), `${APP}/live/s1`)
assert.equal(frameSrcOf('https://vibee-render-production.up.railway.app/live/s1', APP), null, 'a third-party cookie forgets the person')
assert.equal(frameSrcOf('//evil.example/live/x', APP), null)
assert.equal(frameSrcOf('/queen/', APP), null, 'only a viewer window is framed')
assert.equal(frameSrcOf('/live/../api/browser/profile', APP), null, 'a path that climbs out of /live/ is not a viewer')
assert.equal(frameSrcOf('javascript:alert(1)', APP), null)
assert.equal(frameSrcOf(undefined, APP), null)

// 5. The view is a real module: in the rail, on its key, on the homepage.
assert.ok(HUD_VIEWS.includes('browser'))
assert.equal(hudKeyOf('browser'), 'w')
const mod = MODULES.find((m) => m.tab === 'browser')
assert.ok(mod, 'a module entry, so the homepage and ?tab= know it')
assert.equal(mod.key, 'w')

// 6. The panel paints ABOVE the hive. The scene is an absolutely positioned
//    layer and paints over unpositioned content; shipped without this, the
//    comb covered the live window on app.t27.ai. A stylesheet is the only
//    place this lives, so the stylesheet is what is checked -- the rule for
//    the panel itself, not any line that merely mentions it.
{
  const css = readFileSync(new URL('../src/components/QueenBrowser.css', import.meta.url), 'utf8')
    .replace(/\/\*[\s\S]*?\*\//g, '')
  const panel = /\.queen27-page\.is-shell \.queen27-browser\s*\{([^}]*)\}/.exec(css)
  assert.ok(panel, 'the panel has its own rule')
  assert.match(panel[1], /position:\s*relative/, 'the panel is positioned, or the hive paints over it')
  const z = /z-index:\s*(\d+)/.exec(panel[1])
  assert.ok(z && Number(z[1]) >= 1, 'the panel stacks above the scene holder')
  const live = /\.queen27-browser\.is-live\s*\{([^}]*)\}/.exec(css)
  assert.ok(live && /background:\s*#000/.test(live[1]), 'the live window sits on an opaque ground')
  const hide = /\[data-view="browser"\][^{]*\.queen-scene-holder[^{]*\{([^}]*)\}/.exec(css)
  assert.ok(hide && /visibility:\s*hidden/.test(hide[1]), 'on this view the hive scene is hidden, not drawn over the window')
}

// 7. The Queen drives the browser: the question reaches the person's own
//    agent WITH the tab it was asked from, and its stream is read right.
{
  const msgs = agentMessages([], 'open t27.ai', 'en')
  assert.equal(msgs.length, 1)
  assert.match(msgs[0].content, /BROWSER tab/, 'the agent is told which tab the person is on')
  assert.match(msgs[0].content, /browser_\*/, 'and that the browser tools are the ones to use')
  assert.match(msgs[0].content, /open t27\.ai$/, 'the question itself is last, untouched')
  assert.match(agentMessages([], 'x', 'ru')[0].content, /вкладки BROWSER/)

  const long = Array.from({ length: 20 }, (_, i) => ({ role: i % 2 ? 'assistant' : 'user', content: `turn ${i}` }))
  const withHistory = agentMessages([...long, { role: 'assistant', content: '  ' }], 'and now click it', 'en')
  assert.equal(withHistory.length, HISTORY_TURNS + 1, 'earlier turns ride along, bounded')
  assert.equal(withHistory[0].content, `turn ${20 - HISTORY_TURNS}`, 'the most recent ones')

  const stream = [
    '{"тип":"ход","id":"1"}',
    '{"тип":"провайдер","id":"zai","model":"glm-5.3"}',
    '{"тип":"размышление","текст":"let me look"}',
    '{"тип":"инструмент","имя":"browser_status","аргументы":"{}"}',
    'not json',
    '{"тип":"текст","текст":"Three tabs "}',
    '{"тип":"текст","текст":"are open."}',
    '{"тип":"готово","витков":2}',
  ].join('\n')
  const a = readAgentStream(stream)
  assert.equal(a.text, 'Three tabs are open.', 'thinking is not part of the answer')
  assert.deepEqual(a.tools, ['browser_status'])
  assert.equal(a.model, 'zai/glm-5.3')
  assert.equal(readAgentStream('{"тип":"ошибка","текст":"provider 429"}').error, 'provider 429')

  const calls = []
  const env = (status, body) => ({
    token: () => 'tok-9',
    fetch: async (url, init) => { calls.push({ url, init }); return { ok: status < 300, status, text: async () => body } },
  })
  const got = await askBrowserAgent(env(200, stream), [], 'which tabs?', 'en')
  assert.equal(got.text, 'Three tabs are open.')
  const [{ url, init }] = calls
  assert.equal(url, `${BROKER_BASE}/api/agent/chat`)
  assert.equal(init.credentials, 'omit')
  assert.equal(init.headers.Authorization, 'Bearer tok-9')
  assert.ok(!init.body.includes('tok-9'), 'the token rides in the header only')
  assert.match(JSON.parse(init.body).messages.at(-1).content, /BROWSER tab[\s\S]*which tabs\?$/)
  await assert.rejects(askBrowserAgent(env(401, ''), [], 'x', 'en'), AgentSignedOut)
  await assert.rejects(askBrowserAgent({ ...env(200, stream), token: () => null }, [], 'x', 'en'), AgentSignedOut)
  await assert.rejects(askBrowserAgent(env(200, '{"тип":"ошибка","текст":"provider 429"}'), [], 'x', 'en'), /provider 429/)
}

// 9. The steps are seen as they happen: the stream is read as it arrives,
//    even when a chunk ends mid-line or mid-letter.
{
  const lines = [
    '{"тип":"провайдер","id":"zai","model":"glm-5.3"}',
    '{"тип":"инструмент","имя":"browser_open","аргументы":"{}"}',
    '{"тип":"инструмент","имя":"browser_click","аргументы":"{}"}',
    '{"тип":"текст","текст":"Открыла t27.ai"}',
    '{"тип":"готово"}',
  ].join('\n') + '\n'
  const bytes = new TextEncoder().encode(lines)
  // Cut into 7-byte chunks: Cyrillic letters are 2 bytes, so some split.
  const chunks = []
  for (let i = 0; i < bytes.length; i += 7) chunks.push(bytes.slice(i, i + 7))
  const body = () => new ReadableStream({ start(c) { chunks.forEach((x) => c.enqueue(x)); c.close() } })
  const seen = []
  const a = await readAgentBody(body(), (soFar) => seen.push(soFar))
  assert.equal(a.text, 'Открыла t27.ai', 'no letter broken by a chunk boundary')
  assert.deepEqual(a.tools, ['browser_open', 'browser_click'])
  const firstTool = seen.findIndex((p) => p.tools.length === 1)
  const firstText = seen.findIndex((p) => p.text !== '')
  assert.ok(firstTool >= 0 && firstTool < firstText, 'the step is shown before the answer arrives')
  seen[firstTool].tools.push('mutated')
  assert.deepEqual(a.tools, ['browser_open', 'browser_click'], 'progress hands out copies')

  const progress = []
  const env = {
    token: () => 't',
    fetch: async () => ({ ok: true, status: 200, text: async () => { throw new Error('read as a whole') }, body: body() }),
  }
  const got = await askBrowserAgent(env, [], 'q', 'ru', (p) => progress.push(p.tools.length))
  assert.equal(got.text, 'Открыла t27.ai', 'a response with a body is streamed, not read whole')
  assert.ok(progress.includes(2))
}

// 8. The rail as the owner laid it out, 2026-09-21: TECH TREE inside KANBAN,
//    PASSPORT inside PROJECT. Both stay valid addresses; the rail lights the
//    family's door for them.
assert.ok(BOARD_VIEWS.includes('research'))
assert.deepEqual([...PROJECT_VIEWS], ['project', 'passport'])
for (const folded of ['research', 'passport']) {
  assert.ok(HUD_VIEWS.includes(folded), `${folded} is still an address`)
  assert.ok(!RAIL_VIEWS.includes(folded), `${folded} is not its own rail button`)
}
assert.equal(railViewOf('research'), 'kanban')
assert.equal(railViewOf('passport'), 'project')
assert.ok(RAIL_VIEWS.includes('browser') && RAIL_VIEWS.includes('project') && RAIL_VIEWS.includes('tri'))

// 10. The window's word about its connection: from our frame and origin only.
{
  const APPO = 'https://app.t27.ai'
  const fw = {}
  const e = (o = {}) => ({ origin: APPO, source: fw, data: { source: WINDOW_EVENT, state: 'stuck' }, ...o })
  assert.equal(frameStateOf(e(), fw, APPO), 'stuck')
  assert.equal(frameStateOf(e({ origin: 'https://evil.example' }), fw, APPO), null, 'another origin is ignored')
  assert.equal(frameStateOf(e({ source: {} }), fw, APPO), null, 'another frame is ignored')
  assert.equal(frameStateOf(e({ data: { source: 'x', state: 'stuck' } }), fw, APPO), null)
  assert.equal(frameStateOf(e({ data: { source: WINDOW_EVENT, state: 'boom' } }), fw, APPO), null)
  assert.equal(shouldReread('reconnecting'), true)
  assert.equal(shouldReread('stuck'), true)
  assert.equal(shouldReread('connected'), false)
  assert.equal(WINDOW_EVENT, 't27-browser', 'the name the window posts (render skin.ts)')
}

// 11. What the agent did, under the window: read with the token in one
//     header, never throwing, and said in the person's language.
{
  const calls = []
  const env = (status, body, token = 'tok-j') => ({
    token: () => token,
    fetch: async (url, init) => { calls.push({ url, init }); return { ok: status < 300, status, json: async () => body } },
  })
  const steps = [{ at: '2026-09-22T09:00:05Z', tool: 'browser_screenshot', ok: true, ms: 1300, detail: { seen: 'Google sign-in' } }]
  assert.deepEqual(await readJournal(env(200, { ok: true, steps })), steps)
  assert.equal(calls[0].url, `${BROKER_BASE}/api/browser/journal?limit=6`)
  assert.equal(calls[0].init.method, 'GET')
  assert.equal(calls[0].init.credentials, 'omit')
  assert.equal(calls[0].init.headers.Authorization, 'Bearer tok-j')
  assert.equal(await readJournal(env(401, {})), null, 'a refusal is no journal, not an error')
  const before = calls.length
  assert.equal(await readJournal(env(200, {}, null)), null)
  assert.equal(calls.length, before, 'no token: nothing is asked')
  assert.equal(await readJournal({ token: () => 't', fetch: async () => { throw new Error('down') } }), null)

  const line = (tool, detail, ok = true, lang = 'ru') => journalLine({ at: '2026-09-22T09:00:05Z', tool, ok, ms: 1, detail }, lang)
  assert.equal(line('browser_screenshot', { seen: 'Google sign-in' }).text, 'Google sign-in')
  assert.equal(line('browser_screenshot', { seen: 'x' }).verb, 'посмотрел')
  assert.equal(line('browser_screenshot', { seen: 'x' }, true, 'en').verb, 'looked')
  assert.equal(line('browser_screenshot', { seenPending: true }).text, 'описание готовится')
  assert.equal(line('browser_open', { url: 'https://t27.ai/' }).text, 'https://t27.ai/')
  assert.equal(line('browser_type', { chars: 15 }).text, '15 симв.')
  assert.equal(line('browser_type', { chars: 15 }, true, 'en').text, '15 chars')
  const failed = line('browser_click', { x: 1, y: 2, error: 'needs permission' }, false)
  assert.equal(failed.ok, false)
  assert.equal(failed.text, 'needs permission', 'the error is what matters on a failed step')
  assert.equal(line('browser_unknown', {}).verb, 'browser_unknown', 'an unknown tool keeps its own name')
  assert.match(line('browser_status', { pages: 5 }).time, /^\d\d:\d\d:\d\d$/)
}

// 12. The wheel from the board: the person's token, one header, POST.
{
  const calls = []
  const env = (status, token = 'tok-w') => ({
    token: () => token,
    fetch: async (url, init) => { calls.push({ url, init }); return { ok: status < 300, status, json: async () => ({}) } },
  })
  assert.equal(await setWheel(env(200), 'person'), true)
  assert.equal(calls[0].url, `${BROKER_BASE}/api/browser/wheel?holder=person`)
  assert.equal(calls[0].init.method, 'POST')
  assert.equal(calls[0].init.credentials, 'omit')
  assert.equal(calls[0].init.headers.Authorization, 'Bearer tok-w')
  assert.equal(await setWheel(env(200), 'agent'), true)
  assert.match(calls[1].url, /holder=agent$/)
  assert.equal(await setWheel(env(403), 'person'), false, 'a refusal is false, not an error')
  const n = calls.length
  assert.equal(await setWheel(env(200, null), 'person'), false)
  assert.equal(calls.length, n, 'no token: nothing is asked')
  assert.equal(await setWheel({ token: () => 't', fetch: async () => { throw new Error('down') } }, 'person'), false)
  assert.equal(shouldRenewWheel(null, 5), true)
  assert.equal(shouldRenewWheel(5, 5 + WHEEL_RENEW_MS - 1), false)
  assert.equal(shouldRenewWheel(5, 5 + WHEEL_RENEW_MS), true)
}

console.log('queen-browser contract: ok')
