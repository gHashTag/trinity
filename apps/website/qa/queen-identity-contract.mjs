// The Queen's identity chip in a real browser, with the player stubbed.
//
// Builds the site (unless --no-build; --dist <dir> serves another build) and
// drives the installed Chrome over CDP. The build is served AS https://t27.ai
// through CDP Fetch, so the page runs on the one origin where identity is
// active. Nothing reaches the real hosts: t27.ai, app.t27.ai, the render
// service and evil.example are mapped to 127.0.0.1 (where nothing listens on
// 443), and every request to them is answered by CDP Fetch:
//   https://app.t27.ai/bridge     a stub bridge answering {v:1,type:'tri-identity'}
//                                 in the mode this harness sets per page load
//   https://app.t27.ai/impostor   the right origin, the wrong window
//   https://evil.example/impostor the wrong origin (loaded into the bridge's own
//                                 frame, so only the origin check can refuse it)
//   https://app.t27.ai/hive-host  the player framing the game (its Hive tab)
//   <render>/mcp                  a stub whoami that records every header it got
// Site isolation is switched off so framed documents' requests pass through the
// page's Fetch.
//
// Checks, at 1440x900:
//   1  signed-out: the chip is "Sign in", a top-level link to the player's login
//      returning to the current view; it follows a view change; the bridge frame
//      is hidden and was asked once with {v:1, type, 32-hex nonce}
//   2  the same in Russian
//   3  consent-required: the bridge frame is shown and no chip; a real click in the
//      frame answers the waiting request's own nonce (as bridge.js does), which
//      signs in and hides it again
//   4  signed-in: name and role from the stubbed whoami, as text; whoami carried
//      the game token as Bearer and no X-Agent-Key (though the console's agent
//      key sits in this tab's sessionStorage), no cookie; the token is in no
//      storage, address, cookie or markup
//   5  a message from app.t27.ai but another window is ignored
//   6  a message from the bridge's window but another origin is ignored
//   7  a proactive signed-out from the bridge clears the chip to "Sign in"
//   8  unavailable with game_token_parent_not_web: "Sign in again in TRI"
//   9  embedded (embed=1): no chip, no bridge, nothing asked of app.t27.ai
//  10  inside the player (app.t27.ai framing the game): the parent is asked, no
//      bridge is mounted, and the chip shows the person
//
// Exits 0 on pass, 1 on a failed check, 2 when it could not run (never read as a pass).
//
//   node qa/queen-identity-contract.mjs [--no-build] [--dist <dir>] [--only 1,2,...]

import { execSync, spawn } from 'node:child_process'
import { readFileSync, existsSync, mkdtempSync, rmSync } from 'node:fs'
import { join, extname, normalize, resolve } from 'node:path'
import { tmpdir } from 'node:os'

const ROOT = new URL('..', import.meta.url).pathname
const argAt = (name) => { const i = process.argv.indexOf(name); return i >= 0 ? process.argv[i + 1] : null }
const DIST = resolve(argAt('--dist') ?? join(ROOT, 'dist'))
const ONLY = argAt('--only') ? new Set(argAt('--only').split(',').map(Number)) : null
const runs = (n) => !ONLY || ONLY.has(n)
const GAME = 'https://t27.ai'
const APP = 'https://app.t27.ai'
const RENDER = 'https://vibee-render-production.up.railway.app'
const EVIL = 'https://evil.example'
const TOKEN = 'stubheader.stubclaims.stubsignature'
const IMPOSTOR_TOKEN = 'impostorheader.impostorclaims.impostorsignature'
const AGENT_KEY = 'fake-agent-key-for-the-identity-contract'
const EVAL_TIMEOUT_MS = Number(process.env.IDENTITY_EVAL_TIMEOUT_MS || 60000)

const CHROME = [process.env.CHROME_PATH, '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/usr/bin/google-chrome', '/usr/bin/chromium-browser', '/usr/bin/chromium'].filter(Boolean).find((p) => existsSync(p))
if (!CHROME) {
  console.log('  no Chrome found — skipping the identity check. Set CHROME_PATH to force it.')
  process.exit(0)
}
if (!process.argv.includes('--no-build') && !argAt('--dist')) {
  console.log('  building…')
  execSync('npx vite build', { cwd: ROOT, stdio: ['ignore', 'ignore', 'inherit'] })
}
if (!existsSync(join(DIST, 'index.html'))) {
  console.error(`  ${DIST}/index.html missing — nothing to open.`)
  process.exit(2)
}

const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.svg': 'image/svg+xml', '.png': 'image/png', '.wasm': 'application/wasm', '.woff2': 'font/woff2' }
const distFile = (pathname) => {
  const p = normalize(decodeURIComponent(pathname)).replace(/^(\.\.[/\\])+/, '')
  const file = join(DIST, p)
  return !file.startsWith(DIST) || !existsSync(file) || p === '/' ? join(DIST, 'index.html') : file
}

// ---- Stubs ----
// The states as the player's bridge.js sends them.
let bridgeMode = 'signed-out' // 'signed-out' | 'consent-required' | 'signed-in' | 'parent-not-web'
const appRequests = [] // every app.t27.ai URL asked for
const mcpCalls = [] // every request to the render service
const identityMessage = (nonce, mode) => mode === 'signed-in'
  ? `{ v: 1, type: 'tri-identity', nonce: ${nonce}, state: 'signed-in', game_token: ${JSON.stringify(TOKEN)}, expires_in: 300, telegram_id: '144' }`
  : mode === 'parent-not-web'
    ? `{ v: 1, type: 'tri-identity', nonce: ${nonce}, state: 'unavailable', code: 'game_token_parent_not_web' }`
    : `{ v: 1, type: 'tri-identity', nonce: ${nonce}, state: ${JSON.stringify(mode)} }`
const BRIDGE = (mode) => `<!doctype html><meta charset="utf-8"><title>bridge stub</title>
<body style="margin:0;background:#021;color:#9fc;font:13px monospace" data-asked="[]">bridge stub <button id="go" style="margin:12px;padding:10px 16px">Continue as Ada</button>
<script>
  // As bridge.js: the request waiting for the click, answered with its own nonce.
  let pendingNonce = null;
  const answer = (nonce, mode) => {
    const messages = { 'signed-in': ${identityMessage('nonce', 'signed-in')}, 'signed-out': ${identityMessage('nonce', 'signed-out')}, 'consent-required': ${identityMessage('nonce', 'consent-required')}, 'parent-not-web': ${identityMessage('nonce', 'parent-not-web')} };
    parent.postMessage(messages[mode], 'https://t27.ai');
  };
  addEventListener('message', (e) => {
    if (e.source !== parent || e.origin !== 'https://t27.ai') return;
    const d = e.data;
    if (d && typeof d === 'object' && d.type === 'tri-identity-request') {
      document.body.dataset.asked = JSON.stringify([...JSON.parse(document.body.dataset.asked), d]);
      if (${JSON.stringify(mode)} === 'consent-required') pendingNonce = d.nonce;
      answer(d.nonce, ${JSON.stringify(mode)});
    }
    if (typeof d === 'string' && d.startsWith('harness-push:')) answer(null, d.slice(13));
  });
  document.getElementById('go').addEventListener('click', (e) => {
    if (!e.isTrusted || pendingNonce === null) return;
    const nonce = pendingNonce;
    pendingNonce = null;
    answer(nonce, 'signed-in');
  });
</script>`
const IMPOSTOR = `<!doctype html><meta charset="utf-8"><title>impostor</title><body>impostor
<script>
  setTimeout(() => {
    parent.postMessage({ v: 1, type: 'tri-identity', nonce: null, state: 'signed-in', game_token: ${JSON.stringify(IMPOSTOR_TOKEN)}, expires_in: 300, telegram_id: '666' }, '*');
    parent.postMessage({ v: 1, type: 'tri-identity', nonce: null, state: 'signed-out' }, '*');
    document.body.dataset.posted = '1';
  }, 300);
</script>`
const HIVE_HOST = `<!doctype html><meta charset="utf-8"><title>hive host</title>
<body style="margin:0" data-asked="0"><iframe id="game" src="${GAME}/?lang=en&hive=1#/queen?tab=kanban" style="width:1400px;height:860px;border:0"></iframe>
<script>
  const game = document.getElementById('game');
  addEventListener('message', (e) => {
    if (e.source !== game.contentWindow || e.origin !== 'https://t27.ai') return;
    const d = e.data;
    if (!d || d.type !== 'tri-identity-request') return;
    document.body.dataset.asked = String(Number(document.body.dataset.asked) + 1);
    const nonce = d.nonce;
    game.contentWindow.postMessage(${identityMessage('nonce', 'signed-in')}, 'https://t27.ai');
  });
</script>`
const WHOAMI = JSON.stringify({ jsonrpc: '2.0', id: 1, result: { structuredContent: { telegram_id: '144', role: 'owner', профиль: { display_name: 'Ada <b>Stub</b>', first_name: 'Ada', username: 'ada' }, аватар: `${GAME}/stub-avatar.svg` } } })
const AVATAR = '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18"><circle cx="9" cy="9" r="9" fill="#6c6"/></svg>'

const profile = mkdtempSync(join(tmpdir(), 'queen-identity-'))
const chrome = spawn(CHROME, [
  '--headless=new', '--remote-debugging-port=0', `--user-data-dir=${profile}`,
  '--no-first-run', '--no-default-browser-check', '--disable-extensions', '--disable-background-networking', '--disable-sync', '--mute-audio',
  '--window-size=1440,900',
  '--disable-site-isolation-trials', '--disable-features=IsolateOrigins,site-per-process',
  '--host-resolver-rules=MAP t27.ai 127.0.0.1, MAP app.t27.ai 127.0.0.1, MAP vibee-render-production.up.railway.app 127.0.0.1, MAP evil.example 127.0.0.1',
  ...(process.platform === 'linux' ? ['--no-sandbox', '--disable-dev-shm-usage'] : []),
  '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', 'about:blank',
], { stdio: ['ignore', 'ignore', 'pipe'] })
const cleanup = () => { try { chrome.kill('SIGKILL') } catch { /* gone */ } try { rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 }) } catch { /* ignored */ } }

const checks = []
const record = (n, name, ok, detail) => { checks.push({ n, name, ok: !!ok, detail }); console.log(`  ${ok ? 'PASS' : 'FAIL'}  ${n}. ${name}${ok ? '' : `  ${JSON.stringify(detail)}`}`) }
const wait = (ms) => new Promise((r) => setTimeout(r, ms))

try {
  const wsUrl = await new Promise((res, rej) => {
    const t = setTimeout(() => rej(new Error('Chrome never announced a debugging port')), 60000)
    let buf = ''
    chrome.stderr.on('data', (d) => { buf += d; const m = buf.match(/DevTools listening on (ws:\/\/\S+)/); if (m) { clearTimeout(t); res(m[1]) } })
    chrome.on('exit', (c) => { clearTimeout(t); rej(new Error(`Chrome exited (${c}) before listening`)) })
  })
  const ws = new WebSocket(wsUrl)
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = () => rej(new Error('CDP socket refused')) })
  let id = 0
  const pending = new Map()
  const listeners = []
  ws.onmessage = (ev) => { const m = JSON.parse(ev.data); if (m.id && pending.has(m.id)) { const p = pending.get(m.id); pending.delete(m.id); m.error ? p.reject(new Error(m.error.message)) : p.resolve(m.result) } else if (m.method) listeners.forEach((f) => f(m)) }
  const send = (method, params = {}, sessionId) => new Promise((res, rej) => { const i = ++id; pending.set(i, { resolve: res, reject: rej }); ws.send(JSON.stringify({ id: i, method, params, ...(sessionId ? { sessionId } : {}) })) })
  const { targetId } = await send('Target.createTarget', { url: 'about:blank' })
  const { sessionId } = await send('Target.attachToTarget', { targetId, flatten: true })
  const call = (m, p) => Promise.race([send(m, p, sessionId), new Promise((_, rej) => setTimeout(() => rej(new Error(`${m} timed out`)), EVAL_TIMEOUT_MS))])

  const errors = []
  const fulfill = (requestId, status, headers, body) => send('Fetch.fulfillRequest', { requestId, responseCode: status, responseHeaders: Object.entries(headers).map(([name, value]) => ({ name, value })), body: Buffer.from(body).toString('base64') }, sessionId).catch(() => {})
  listeners.push((m) => {
    if (m.sessionId !== sessionId) return
    if (m.method === 'Runtime.exceptionThrown') errors.push(m.params.exceptionDetails.exception?.description?.split('\n')[0] ?? m.params.exceptionDetails.text)
    if (m.method !== 'Fetch.requestPaused') return
    const { requestId, request } = m.params
    const url = new URL(request.url)
    const html = { 'Content-Type': 'text/html; charset=utf-8' }
    if (url.origin === GAME) {
      if (url.pathname === '/__blank') return fulfill(requestId, 200, html, '<!doctype html><title>blank</title>')
      if (url.pathname === '/stub-avatar.svg') return fulfill(requestId, 200, { 'Content-Type': 'image/svg+xml' }, AVATAR)
      const file = distFile(url.pathname)
      return fulfill(requestId, 200, { 'Content-Type': MIME[extname(file)] || 'application/octet-stream' }, readFileSync(file))
    }
    if (url.origin === APP) {
      appRequests.push(request.url)
      if (url.pathname === '/bridge') return fulfill(requestId, 200, html, BRIDGE(bridgeMode))
      if (url.pathname === '/impostor') return fulfill(requestId, 200, html, IMPOSTOR)
      if (url.pathname === '/hive-host') return fulfill(requestId, 200, html, HIVE_HOST)
      return fulfill(requestId, 200, html, '<!doctype html><title>app stub</title>')
    }
    if (url.origin === EVIL) return fulfill(requestId, 200, html, IMPOSTOR)
    if (url.origin === RENDER) {
      mcpCalls.push({ method: request.method, path: url.pathname, headers: request.headers, body: request.postData ?? null })
      const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' }
      if (request.method === 'OPTIONS') return fulfill(requestId, 204, cors, '')
      if (url.pathname === '/mcp') return fulfill(requestId, 200, { ...cors, 'Content-Type': 'application/json' }, WHOAMI)
      return fulfill(requestId, 404, { ...cors, 'Content-Type': 'application/json' }, '{}')
    }
    return send('Fetch.continueRequest', { requestId }, sessionId).catch(() => {})
  })
  await call('Runtime.enable')
  await call('Page.enable')
  await call('Fetch.enable', { patterns: [{ urlPattern: `${GAME}/*` }, { urlPattern: `${APP}/*` }, { urlPattern: `${RENDER}/*` }, { urlPattern: `${EVIL}/*` }] })

  const evaluate = async (expression, contextId) => {
    const r = await call('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true, ...(contextId ? { contextId } : {}) })
    if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || r.exceptionDetails.text)
    return r.result.value
  }
  const until = async (expr, ms, contextId) => { const start = Date.now(); while (Date.now() - start < ms) { try { const v = await evaluate(expr, contextId); if (v) return v } catch { /* not yet */ } await wait(250) } return null }
  const load = async (url) => {
    const loaded = new Promise((r) => { const t = setTimeout(r, 60000); listeners.push((m) => { if (m.sessionId === sessionId && m.method === 'Page.loadEventFired') { clearTimeout(t); r() } }) })
    await call('Page.navigate', { url })
    await loaded
  }
  // A context in the first frame (depth-first) whose URL starts with prefix.
  const frameContext = async (prefix) => {
    const find = (node) => node.frame.url.startsWith(prefix) ? node : (node.childFrames ?? []).map(find).find(Boolean)
    const tree = (await call('Page.getFrameTree')).frameTree
    const node = (tree.childFrames ?? []).map(find).find(Boolean)
    if (!node) return null
    return (await call('Page.createIsolatedWorld', { frameId: node.frame.id, worldName: 'identity-contract' })).executionContextId
  }
  const inFrame = async (prefix, expr, ms = 20000) => {
    const start = Date.now()
    while (Date.now() - start < ms) {
      try { const ctx = await frameContext(prefix); if (ctx) { const v = await evaluate(expr, ctx); if (v) return v } } catch { /* navigating */ }
      await wait(300)
    }
    return null
  }

  const railReady = `document.querySelectorAll('button.queen27-hud-cmd[data-view]').length > 0 && !!document.querySelector('main[data-view]')`
  const CHIP = `(() => { const chip = document.querySelector('[data-tool="identity"]'); const frames = [...document.querySelectorAll('iframe.queen27-identity-bridge')]; const f = frames[0];
    const r = f && !f.hidden ? f.getBoundingClientRect() : null;
    return { state: chip?.dataset.identity ?? null, text: chip?.textContent ?? null, href: chip?.getAttribute('href') ?? null, target: chip?.getAttribute('target') ?? null,
      name: chip?.querySelector('.queen27-identity-name')?.textContent ?? null, role: chip?.querySelector('.queen27-identity-role')?.textContent ?? null,
      avatar: chip?.querySelector('img')?.getAttribute('src') ?? null, markup: chip ? chip.querySelectorAll('b').length : null,
      frames: frames.length, frameSrc: f?.getAttribute('src') ?? null, frameHidden: f ? f.hidden : null,
      frameBox: r ? [Math.round(r.left), Math.round(r.top), Math.round(r.width), Math.round(r.height)] : null } })()`
  const chip = () => evaluate(CHIP)
  let opens = 0
  const open = async (hash, { lang = 'en', mode } = {}) => {
    if (mode) bridgeMode = mode
    await load(`${GAME}/?lang=${lang}&open=${++opens}${hash}`)
    if (!(await until(railReady, 120000))) throw new Error(`the Queen shell never rendered at ${hash}`)
  }
  const pushFromBridge = (state) => evaluate(`document.querySelector('iframe.queen27-identity-bridge').contentWindow.postMessage(${JSON.stringify(`harness-push:${state}`)}, '*')`)
  const returnTo = (view) => `${APP}/?return=${encodeURIComponent(`${GAME}/#/queen?tab=${view}`)}`

  await call('Emulation.setDeviceMetricsOverride', { width: 1440, height: 900, deviceScaleFactor: 1, mobile: false })

  if (runs(1)) {
    await open('#/queen?tab=kanban', { mode: 'signed-out' })
    await until(`document.querySelector('[data-tool="identity"]')?.dataset.identity === 'signed-out'`, 30000)
    const s = await chip()
    const asked = await inFrame(`${APP}/bridge`, `(() => { const a = JSON.parse(document.body.dataset.asked || '[]'); return a.length ? a : null })()`)
    const request = asked?.[0]
    await evaluate(`document.querySelector('button.queen27-hud-cmd[data-view="map"]').click()`)
    await until(`document.querySelector('[data-tool="identity"]')?.getAttribute('href') === ${JSON.stringify(returnTo('map'))}`, 20000)
    const afterClick = await chip()
    record(1, 'signed-out: "Sign in" links top-level to the player login returning to the view (and follows a view change); the bridge is hidden and was asked once',
      s.state === 'signed-out' && s.text === 'Sign in' && s.href === returnTo('kanban') && s.target === '_top' &&
      s.frames === 1 && s.frameSrc === `${APP}/bridge` && s.frameHidden === true &&
      asked?.length === 1 && request.v === 1 && request.type === 'tri-identity-request' && /^[0-9a-f]{32}$/.test(request.nonce) && Object.keys(request).sort().join() === 'nonce,type,v' &&
      afterClick.href === returnTo('map'), { s, asked, afterClick })
  }

  if (runs(2)) {
    await open('#/queen?tab=kanban', { lang: 'ru', mode: 'signed-out' })
    const text = await until(`document.querySelector('[data-tool="identity"][data-identity="signed-out"]')?.textContent`, 30000)
    record(2, 'signed-out in Russian: "Войти"', text === 'Войти', { text })
  }

  if (runs(3)) {
    await open('#/queen?tab=kanban', { mode: 'consent-required' })
    await until(`(() => { const f = document.querySelector('iframe.queen27-identity-bridge'); return f && !f.hidden })()`, 30000)
    await wait(500)
    const shown = await chip()
    // A real click inside the bridge frame, at its button.
    const button = await inFrame(`${APP}/bridge`, `(() => { const r = document.getElementById('go')?.getBoundingClientRect(); return r && r.width ? { x: r.left + r.width / 2, y: r.top + r.height / 2 } : null })()`)
    let clicked = null
    if (shown.frameBox && button) {
      const x = shown.frameBox[0] + 1 + button.x
      const y = shown.frameBox[1] + 1 + button.y
      for (const type of ['mousePressed', 'mouseReleased']) await call('Input.dispatchMouseEvent', { type, x, y, button: 'left', clickCount: 1 })
      await until(`document.querySelector('[data-tool="identity"]')?.dataset.identity === 'signed-in'`, 30000)
      clicked = await chip()
    }
    record(3, 'consent-required: the bridge frame is shown and no chip; a real click in it signs in and hides it',
      shown.state === null && shown.frameHidden === false && shown.frameBox && shown.frameBox[2] > 100 && shown.frameBox[3] > 50 &&
      shown.frameBox[0] >= 0 && shown.frameBox[0] + shown.frameBox[2] <= 1440 && shown.frameBox[1] + shown.frameBox[3] <= 900 &&
      clicked?.state === 'signed-in' && clicked.frameHidden === true, { shown, button, clicked })
  }

  if (runs(4) || runs(5) || runs(6) || runs(7)) {
    // The console's agent key in this tab: the identity path must still never send it.
    await load(`${GAME}/__blank`)
    await evaluate(`sessionStorage.setItem('t27.crm.key', ${JSON.stringify(AGENT_KEY)})`)
    const callsBefore = mcpCalls.length
    await open('#/queen?tab=kanban', { mode: 'signed-in' })
    await until(`document.querySelector('[data-tool="identity"]')?.dataset.identity === 'signed-in' && !!document.querySelector('.queen27-identity-name')`, 30000)
    const s = await chip()
    const posts = mcpCalls.slice(callsBefore).filter((c) => c.method === 'POST')
    const headerNames = posts.flatMap((c) => Object.keys(c.headers).map((h) => h.toLowerCase()))
    const leaks = await evaluate(`(() => { const t = ${JSON.stringify(TOKEN)}; const values = (s) => Object.keys(s).map((k) => s.getItem(k));
      return { localStorage: values(localStorage).some((v) => v.includes(t)), sessionStorage: values(sessionStorage).some((v) => v.includes(t)), address: location.href.includes(t), cookie: document.cookie.includes(t), markup: document.documentElement.outerHTML.includes(t), agentKeyStillThere: sessionStorage.getItem('t27.crm.key') === ${JSON.stringify(AGENT_KEY)} } })()`)
    if (runs(4)) {
      const whoami = posts[0]
      record(4, 'signed-in: name and role from whoami as text; whoami carried the game token as Bearer, no X-Agent-Key, no cookie; the token is in no storage, address, cookie or markup',
        s.state === 'signed-in' && s.name === 'Ada <b>Stub</b>' && s.markup === 0 && s.role === 'Owner' && s.avatar === `${GAME}/stub-avatar.svg` && s.frameHidden === true &&
        posts.length === 1 && whoami.path === '/mcp' && whoami.headers.Authorization === `Bearer ${TOKEN}` &&
        !headerNames.includes('x-agent-key') && !headerNames.includes('cookie') &&
        JSON.parse(whoami.body).params?.name === 'whoami' &&
        !leaks.localStorage && !leaks.sessionStorage && !leaks.address && !leaks.cookie && !leaks.markup && leaks.agentKeyStillThere,
      { s, posts, leaks })
    }

    if (runs(5)) {
      const before = mcpCalls.length
      await evaluate(`(() => { const f = document.createElement('iframe'); f.className = 'contract-impostor'; f.src = ${JSON.stringify(`${APP}/impostor`)}; document.body.appendChild(f) })()`)
      const posted = await inFrame(`${APP}/impostor`, `document.body.dataset.posted === '1'`)
      await wait(2000)
      const after = await chip()
      record(5, 'a message from app.t27.ai but another window is ignored', posted && after.state === 'signed-in' && after.name === 'Ada <b>Stub</b>' &&
        !mcpCalls.slice(before).some((c) => JSON.stringify(c.headers).includes(IMPOSTOR_TOKEN)), { posted, after, calls: mcpCalls.slice(before) })
    }

    if (runs(6)) {
      // The bridge's own window goes to another origin: the source still matches,
      // so only the origin check stands between its messages and the chip.
      const before = mcpCalls.length
      await evaluate(`document.querySelector('iframe.queen27-identity-bridge').contentWindow.location.href = ${JSON.stringify(`${EVIL}/impostor`)}`)
      const posted = await inFrame(`${EVIL}/impostor`, `document.body.dataset.posted === '1'`)
      await wait(2000)
      const after = await chip()
      record(6, "a message from the bridge's window but another origin is ignored", posted && after.state === 'signed-in' && after.name === 'Ada <b>Stub</b>' &&
        !mcpCalls.slice(before).some((c) => JSON.stringify(c.headers).includes(IMPOSTOR_TOKEN)), { posted, after, calls: mcpCalls.slice(before) })
      // Back to the real bridge for check 7.
      await evaluate(`document.querySelector('iframe.queen27-identity-bridge').contentWindow.location.href = ${JSON.stringify(`${APP}/bridge`)}`)
      await inFrame(`${APP}/bridge`, `JSON.parse(document.body.dataset.asked || '[]').length > 0`)
      await wait(1000)
    }

    if (runs(7)) {
      const before = await chip()
      await pushFromBridge('signed-out')
      await until(`document.querySelector('[data-tool="identity"]')?.dataset.identity === 'signed-out'`, 20000)
      const after = await chip()
      record(7, 'a proactive signed-out from the bridge clears the chip to "Sign in"', before.state === 'signed-in' && after.state === 'signed-out' && after.text === 'Sign in' && after.name === null, { before, after })
    }
  }

  if (runs(8)) {
    await open('#/queen?tab=kanban', { mode: 'parent-not-web' })
    const s = await until(`(() => { const c = document.querySelector('[data-tool="identity"]'); return c?.dataset.identity === 'sign-in-again' ? c.textContent : null })()`, 30000)
    record(8, 'unavailable with game_token_parent_not_web says "Sign in again in TRI"', s === 'Sign in again in TRI', { s, chip: await chip() })
  }

  if (runs(9)) {
    const before = appRequests.length
    await open('#/queen?tab=kanban&embed=1', { mode: 'signed-in' })
    await wait(4000)
    const s = await chip()
    record(9, 'embedded (embed=1): no chip, no bridge, nothing asked of app.t27.ai', s.state === null && s.frames === 0 && appRequests.length === before, { s, requests: appRequests.slice(before) })
  }

  if (runs(10)) {
    const callsBefore = mcpCalls.length
    await load(`${APP}/hive-host`)
    const inside = await inFrame(`${GAME}/`, `(() => { const c = document.querySelector('[data-tool="identity"]'); return c?.dataset.identity === 'signed-in' && c.querySelector('.queen27-identity-name')
      ? { name: c.querySelector('.queen27-identity-name').textContent, role: c.querySelector('.queen27-identity-role')?.textContent ?? null, bridges: document.querySelectorAll('iframe.queen27-identity-bridge').length, ancestors: [...(location.ancestorOrigins ?? [])] } : null })()`, 150000)
    const asked = await evaluate(`Number(document.body.dataset.asked)`)
    const posts = mcpCalls.slice(callsBefore).filter((c) => c.method === 'POST')
    record(10, 'inside the player: the parent is asked, no bridge is mounted, the chip shows the person',
      inside?.name === 'Ada <b>Stub</b>' && inside.role === 'Owner' && inside.bridges === 0 && asked >= 1 &&
      posts.length >= 1 && posts.every((c) => c.headers.Authorization === `Bearer ${TOKEN}` && !Object.keys(c.headers).some((h) => h.toLowerCase() === 'x-agent-key')),
    { inside, asked, posts })
  }

  const failed = checks.filter((c) => !c.ok)
  if (errors.length) console.log(`  uncaught exceptions: ${JSON.stringify(errors.slice(0, 5))}`)
  console.log(`\n  Queen identity contract: ${failed.length ? 'FAIL' : 'PASS'} (${checks.length - failed.length}/${checks.length})`)
  cleanup()
  process.exit(failed.length ? 1 : 0)
} catch (e) {
  console.log(`  could not run: ${e?.message ?? e} (checks so far: ${checks.filter((c) => c.ok).length}/${checks.length} passed)`)
  cleanup()
  process.exit(2)
}
