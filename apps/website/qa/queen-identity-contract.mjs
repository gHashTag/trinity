// The Queen's identity chip in a real browser, with the player stubbed.
//
// Builds the site (unless --no-build; --dist <dir> serves another build) and
// drives the installed Chrome over CDP. The build is served AS https://t27.ai
// through CDP Fetch, so the page runs on the one origin where identity is
// active. Nothing reaches the real hosts: t27.ai, app.t27.ai, the render
// service and evil.example are mapped to 127.0.0.1 (where nothing listens on
// 443), and every request to them is answered by CDP Fetch:
//   https://app.t27.ai/bridge     a stub bridge answering {v:1,type:'tri-identity'}
//                                 in the mode this harness sets per page load; its
//                                 Not now posts {v:1,type:'tri-identity-dismiss',nonce}
//                                 as bridge.js does. The harness can hold it or refuse it.
//   https://app.t27.ai/impostor   the right origin, the wrong window
//   https://evil.example/impostor the wrong origin (loaded into the bridge's own
//                                 frame, so only the origin check can refuse it)
//   https://app.t27.ai/hive-host  the player framing the game (its Hive tab),
//                                 answering signed-in or (?mode=signed-out) signed-out
//   <render>/mcp                  a stub whoami that records every header it got
// Site isolation is switched off so framed documents' requests pass through the
// page's Fetch.
//
// Checks, at 1440x900 unless stated. Every press a user is claimed to make is
// trusted CDP input after a hit test (checks 3, 13, 15, 16), because a script
// click passes on a control the pointer cannot reach:
//   1  signed-out: the chip is "Sign in", a top-level link to the player's login
//      returning to the current view; it follows a view change; the bridge frame
//      (?lang=en) is hidden and was asked once with {v:1, type, 32-hex nonce}
//   2  the same in Russian, with the bridge loaded once, in Russian
//   3  consent-required: the bridge frame is shown and the chip says "Confirm in
//      TRI"; a real click in the frame answers the waiting request's own nonce
//      (as bridge.js does), which signs in and hides it again
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
//  11  (runs with 3) while the click is awaited, another route of the site hides
//      the consent frame, and coming back to the Queen shows it again
//  12  390x844, the bridge's answer held: the chip is there at once as a pending
//      polite status region (lang en), and keeps its box when "Sign in" comes;
//      the link's hit area is at least 24 px tall
//  13  Not now in the bridge (trusted click): the frame hides, the point under it
//      is the page again, the chip keeps "Confirm in TRI"; a trusted click on the
//      chip asks again and the prompt comes back
//  14  expired: "Resume in TRI", a top-level link returning to the view
//  15  the bridge refused: within the answer deadline "TRI did not answer" with
//      Retry; a trusted click on Retry, the bridge reachable again, gives "Sign in"
//  16  inside the player and signed out: the chip is a button, and a trusted
//      click posts {v:1,type:'t27-app',kind:'sign-in'} to the player; the tab stays
//      (the stub player then opens its login modal over the game, as the Hive does)
//  17  leaving the Queen blanks the bridge frame; back within the token's life the
//      person is still shown and the bridge is not loaded again
//  18  on the TRI tab, Sign in returns to the same screen (tab=tri&screen=crm)
//  19  the consent prompt shown: at 390x844 the rail's TRI command is still the
//      element under its centre; at 1440x900, 1280x720, 1200x800 and 1024x768 (comb,
//      kanban, tri) no control box of the rail, the Queen's column, the quick
//      commands, the tools row or the map's control row overlaps it, and a trusted
//      press on the composer input focuses it
//  20  (runs with 16) a trusted click on the stub player's login widget signs in and
//      closes its modal, telling the game nothing; the pointer coming back over the
//      game asks again and the chip shows the person, with no navigation or reload
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
let bridgeMode = 'signed-out' // 'signed-out' | 'consent-required' | 'signed-in' | 'parent-not-web' | 'expired'
let bridgeHoldMs = 0 // hold the bridge document this long
let bridgeBlocked = false // refuse the bridge document
const appRequests = [] // every app.t27.ai URL asked for
const mcpCalls = [] // every request to the render service
const identityMessage = (nonce, mode) => mode === 'signed-in'
  ? `{ v: 1, type: 'tri-identity', nonce: ${nonce}, state: 'signed-in', game_token: ${JSON.stringify(TOKEN)}, expires_in: 300, telegram_id: '144' }`
  : mode === 'parent-not-web'
    ? `{ v: 1, type: 'tri-identity', nonce: ${nonce}, state: 'unavailable', code: 'game_token_parent_not_web' }`
    : `{ v: 1, type: 'tri-identity', nonce: ${nonce}, state: ${JSON.stringify(mode)} }`
const BRIDGE = (mode) => `<!doctype html><meta charset="utf-8"><title>bridge stub</title>
<body style="margin:0;background:#021;color:#9fc;font:13px monospace" data-asked="[]">bridge stub <button id="go" style="margin:12px;padding:10px 16px">Continue as Ada</button><button id="no" style="margin:12px 0;padding:10px 16px">Not now</button>
<script>
  // As bridge.js: the request waiting for the click, answered with its own nonce.
  let pendingNonce = null;
  const answer = (nonce, mode) => {
    const messages = { 'signed-in': ${identityMessage('nonce', 'signed-in')}, 'signed-out': ${identityMessage('nonce', 'signed-out')}, 'consent-required': ${identityMessage('nonce', 'consent-required')}, 'parent-not-web': ${identityMessage('nonce', 'parent-not-web')}, 'expired': ${identityMessage('nonce', 'expired')} };
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
  // As bridge.js dismissed(): Not now drops the waiting request and tells the game.
  document.getElementById('no').addEventListener('click', (e) => {
    if (!e.isTrusted || pendingNonce === null) return;
    const nonce = pendingNonce;
    pendingNonce = null;
    parent.postMessage({ v: 1, type: 'tri-identity-dismiss', nonce }, 'https://t27.ai');
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
const HIVE_HOST = (mode) => `<!doctype html><meta charset="utf-8"><title>hive host</title>
<body style="margin:0" data-asked="0" data-app="[]"><iframe id="game" src="${GAME}/?lang=en&hive=1#/queen?tab=kanban" style="width:1400px;height:860px;border:0;display:block"></iframe>
<div id="modal" style="display:none;position:fixed;inset:0;background:rgba(0,0,0,.6);align-items:center;justify-content:center"><button id="widget" style="padding:16px 24px">Log in with Telegram</button></div>
<script>
  // As the player's Hive (src/lib/hive.ts, pages/Hive.tsx): each request is answered from the
  // session held at that moment; a sign-in request opens the login modal over the game, and the
  // widget signs in and closes it, telling the game nothing.
  const game = document.getElementById('game');
  const modal = document.getElementById('modal');
  let mode = ${JSON.stringify(mode)};
  const messages = (nonce) => ({ 'signed-in': ${identityMessage('nonce', 'signed-in')}, 'signed-out': ${identityMessage('nonce', 'signed-out')} })[mode];
  document.getElementById('widget').addEventListener('click', (e) => {
    if (!e.isTrusted) return;
    mode = 'signed-in';
    modal.style.display = 'none';
  });
  addEventListener('message', (e) => {
    if (e.source !== game.contentWindow || e.origin !== 'https://t27.ai') return;
    const d = e.data;
    if (d && d.type === 't27-app') { document.body.dataset.app = JSON.stringify([...JSON.parse(document.body.dataset.app), d]); if (d.kind === 'sign-in') modal.style.display = 'flex'; return; }
    if (!d || d.type !== 'tri-identity-request') return;
    document.body.dataset.asked = String(Number(document.body.dataset.asked) + 1);
    game.contentWindow.postMessage(messages(d.nonce), 'https://t27.ai');
  });
</script>`
const WHOAMI = JSON.stringify({ jsonrpc: '2.0', id: 1, result: { structuredContent: { telegram_id: '144', role: 'owner', профиль: { display_name: 'Ada <b>Stub</b>', first_name: 'Ada', username: 'ada' }, аватар: `${GAME}/stub-avatar.svg` } } })
const AVATAR = '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18"><circle cx="9" cy="9" r="9" fill="#6c6"/></svg>'
// Every chip state the page shows, with its box, from the first render (a poll can miss a short pending).
const CHIP_LOG = `(() => {
  if (location.hostname !== 't27.ai' || window.top !== window) return;
  const log = []; Object.defineProperty(window, '__chipLog', { value: log });
  let last = null;
  new MutationObserver(() => {
    const c = document.querySelector('[data-tool="identity"]');
    const s = c ? c.dataset.identity : null;
    if (s === last) return;
    last = s;
    const r = c ? c.getBoundingClientRect() : null;
    // The agent button beside it: the whole row moves while the page mounts, the chip within it must not.
    const a = document.querySelector('[data-tool="agent"]');
    const ar = a ? a.getBoundingClientRect() : null;
    log.push({ t: Math.round(performance.now()), state: s, text: c ? c.textContent : null, role: c ? c.getAttribute('role') : null, live: c ? c.getAttribute('aria-live') : null, lang: c ? c.getAttribute('lang') : null, box: r ? [r.left, r.top, r.width, r.height].map(Math.round) : null, agent: ar ? [ar.left, ar.top].map(Math.round) : null });
  }).observe(document, { subtree: true, childList: true, attributes: true, attributeFilter: ['data-identity'] });
})();`

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
      if (url.pathname === '/bridge') {
        if (bridgeBlocked) return send('Fetch.failRequest', { requestId, errorReason: 'ConnectionRefused' }, sessionId).catch(() => {})
        const mode = bridgeMode
        if (bridgeHoldMs) return void setTimeout(() => fulfill(requestId, 200, html, BRIDGE(mode)), bridgeHoldMs)
        return fulfill(requestId, 200, html, BRIDGE(mode))
      }
      if (url.pathname === '/impostor') return fulfill(requestId, 200, html, IMPOSTOR)
      if (url.pathname === '/hive-host') return fulfill(requestId, 200, html, HIVE_HOST(url.searchParams.get('mode') === 'signed-out' ? 'signed-out' : 'signed-in'))
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
  await call('Page.addScriptToEvaluateOnNewDocument', { source: CHIP_LOG })
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
  // A trusted press: mouse moved, pressed and released at top-level coordinates.
  const mouse = async (x, y) => { for (const type of ['mouseMoved', 'mousePressed', 'mouseReleased']) await call('Input.dispatchMouseEvent', { type, x, y, button: 'left', clickCount: 1 }) }

  const railReady = `document.querySelectorAll('button.queen27-hud-cmd[data-view]').length > 0 && !!document.querySelector('main[data-view]')`
  const CHIP = `(() => { const chip = document.querySelector('[data-tool="identity"]'); const action = chip ? chip.querySelector('.queen27-identity-action') : null; const frames = [...document.querySelectorAll('iframe.queen27-identity-bridge')]; const f = frames[0];
    const r = f && !f.hidden ? f.getBoundingClientRect() : null; const cr = chip ? chip.getBoundingClientRect() : null; const ar = action ? action.getBoundingClientRect() : null;
    return { state: chip?.dataset.identity ?? null, code: chip?.dataset.code ?? null, text: chip?.textContent ?? null, aria: chip?.getAttribute('role') ?? null, live: chip?.getAttribute('aria-live') ?? null, lang: chip?.getAttribute('lang') ?? null,
      action: action ? action.tagName.toLowerCase() : null, href: (action ?? chip)?.getAttribute('href') ?? null, target: (action ?? chip)?.getAttribute('target') ?? null,
      name: chip?.querySelector('.queen27-identity-name')?.textContent ?? null, role: chip?.querySelector('.queen27-identity-role')?.textContent ?? null,
      avatar: chip?.querySelector('img')?.getAttribute('src') ?? null, markup: chip ? chip.querySelectorAll('b').length : null,
      chipBox: cr ? [cr.left, cr.top, cr.width, cr.height].map(Math.round) : null, actionBox: ar ? [ar.left, ar.top, ar.width, ar.height].map(Math.round) : null,
      frames: frames.length, frameSrc: f?.getAttribute('src') ?? null, frameHidden: f ? f.hidden : null,
      frameBox: r ? [Math.round(r.left), Math.round(r.top), Math.round(r.width), Math.round(r.height)] : null } })()`
  const chip = () => evaluate(CHIP)
  // The chip's action, with what is under its centre.
  const HIT_ACTION = `(() => { const a = document.querySelector('[data-tool="identity"] .queen27-identity-action') ?? document.querySelector('a[data-tool="identity"]'); if (!a) return null; const r = a.getBoundingClientRect(); const x = r.left + r.width / 2, y = r.top + r.height / 2; const u = document.elementFromPoint(x, y);
    return { x, y, tag: a.tagName, text: a.textContent, href: a.getAttribute('href'), target: a.getAttribute('target'), hit: !!u && (u === a || a.contains(u)), under: u ? u.tagName + '.' + String(u.className).slice(0, 50) : null } })()`
  const frameShown = `(() => { const f = document.querySelector('iframe.queen27-identity-bridge'); return f && !f.hidden })()`
  const bridgeDocs = () => appRequests.filter((u) => new URL(u).pathname === '/bridge').length
  let opens = 0
  const open = async (hash, { lang = 'en', mode } = {}) => {
    if (mode) bridgeMode = mode
    await load(`${GAME}/?lang=${lang}&open=${++opens}${hash}`)
    if (!(await until(railReady, 120000))) throw new Error(`the Queen shell never rendered at ${hash}`)
  }
  const pushFromBridge = (state) => evaluate(`document.querySelector('iframe.queen27-identity-bridge').contentWindow.postMessage(${JSON.stringify(`harness-push:${state}`)}, '*')`)
  const returnTo = (view) => `${APP}/?return=${encodeURIComponent(`${GAME}/#/queen?tab=${view}`)}`
  const desktop = () => call('Emulation.setDeviceMetricsOverride', { width: 1440, height: 900, deviceScaleFactor: 1, mobile: false })
  const phone = () => call('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 1, mobile: true })

  await desktop()

  if (runs(1)) {
    await open('#/queen?tab=kanban', { mode: 'signed-out' })
    await until(`document.querySelector('[data-tool="identity"]')?.dataset.identity === 'signed-out'`, 30000)
    const s = await chip()
    const asked = await inFrame(`${APP}/bridge`, `(() => { const a = JSON.parse(document.body.dataset.asked || '[]'); return a.length ? a : null })()`)
    const request = asked?.[0]
    await evaluate(`document.querySelector('button.queen27-hud-cmd[data-view="map"]').click()`)
    await until(`(document.querySelector('[data-tool="identity"] a') ?? document.querySelector('a[data-tool="identity"]'))?.getAttribute('href') === ${JSON.stringify(returnTo('map'))}`, 20000)
    const afterClick = await chip()
    record(1, 'signed-out: "Sign in" links top-level to the player login returning to the view (and follows a view change); the bridge (?lang=en) is hidden and was asked once',
      s.state === 'signed-out' && s.text === 'Sign in' && s.href === returnTo('kanban') && s.target === '_top' &&
      s.frames === 1 && s.frameSrc === `${APP}/bridge?lang=en` && s.frameHidden === true &&
      asked?.length === 1 && request.v === 1 && request.type === 'tri-identity-request' && /^[0-9a-f]{32}$/.test(request.nonce) && Object.keys(request).sort().join() === 'nonce,type,v' &&
      afterClick.href === returnTo('map'), { s, asked, afterClick })
  }

  if (runs(2)) {
    const docs = bridgeDocs()
    await open('#/queen?tab=kanban', { lang: 'ru', mode: 'signed-out' })
    const text = await until(`document.querySelector('[data-tool="identity"][data-identity="signed-out"]')?.textContent`, 30000)
    const s = await chip()
    await wait(1000)
    record(2, 'signed-out in Russian: "Войти", the chip in lang ru, the bridge loaded once and in Russian (?lang=ru)',
      text === 'Войти' && s.lang === 'ru' && s.frameSrc === `${APP}/bridge?lang=ru` && bridgeDocs() - docs === 1, { text, s, docs: appRequests.slice(-4) })
  }

  if (runs(3) || runs(11)) {
    await open('#/queen?tab=kanban', { mode: 'consent-required' })
    await until(frameShown, 30000)
    await wait(500)
    const shown = await chip()
    // 11: another route of the same page while the click is awaited, then back.
    await evaluate(`location.hash = '#/about'`)
    await until(`!document.querySelector('button.queen27-hud-cmd[data-view]')`, 30000)
    await wait(1000)
    const away = await chip()
    await evaluate(`location.hash = '#/queen?tab=kanban'`)
    await until(railReady, 120000)
    await until(frameShown, 30000)
    await wait(500)
    const back = await chip()
    if (runs(11)) {
      record(11, 'while the click is awaited another route hides the consent frame, and the Queen shows it again',
        shown.frameHidden === false && away.state === null && away.frames === 1 && away.frameHidden === true && away.frameBox === null &&
        back.frames === 1 && back.frameHidden === false && back.frameBox && back.frameBox[2] > 100, { shown, away, back })
    }
    // A real click inside the bridge frame, at its button.
    const button = await inFrame(`${APP}/bridge`, `(() => { const r = document.getElementById('go')?.getBoundingClientRect(); return r && r.width ? { x: r.left + r.width / 2, y: r.top + r.height / 2 } : null })()`)
    let clicked = null
    if (back.frameBox && button) {
      const x = back.frameBox[0] + 1 + button.x
      const y = back.frameBox[1] + 1 + button.y
      await mouse(x, y)
      await until(`document.querySelector('[data-tool="identity"]')?.dataset.identity === 'signed-in'`, 30000)
      clicked = await chip()
    }
    if (runs(3)) record(3, 'consent-required: the bridge frame is shown and the chip says "Confirm in TRI"; a real click in it signs in and hides it',
      shown.state === 'consent-required' && /^Confirm in TRI/.test(shown.text) && shown.frameHidden === false && shown.frameBox && shown.frameBox[2] > 100 && shown.frameBox[3] > 50 &&
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
      await inFrame(`${APP}/bridge`, `JSON.parse(document.body.dataset.asked || '[]').length > 0 || document.readyState === 'complete'`)
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

  if (runs(12)) {
    await phone()
    bridgeHoldMs = 6000
    try {
      await open('#/queen?tab=kanban', { mode: 'signed-out' })
      await until(`document.querySelector('[data-tool="identity"]')?.dataset.identity === 'signed-out'`, 40000)
      await wait(300)
    } finally {
      bridgeHoldMs = 0
    }
    const log = await evaluate('window.__chipLog ? JSON.parse(JSON.stringify(window.__chipLog)) : null')
    const s = await chip()
    await desktop()
    const first = log?.find((e) => e.state)
    const out = log?.find((e) => e.state === 'signed-out')
    // The row moves while the page mounts (measured: chip and agent button together, 113 -> 156 px),
    // so the chip keeps its size and its place beside the agent button.
    const offset = (e) => (e?.box && e.agent ? [e.box[0] - e.agent[0], e.box[1] - e.agent[1]] : null)
    record(12, '390x844, the answer held: the chip appears at once as a pending polite status (lang en) and keeps its size and place in the row when "Sign in" comes; the link is at least 24 px tall',
      first?.state === 'pending' && first.role === 'status' && first.live === 'polite' && first.lang === 'en' && /Checking TRI/.test(first.text) &&
      !!out && out.t - first.t > 1000 && first.box[2] === out.box[2] && first.box[3] === out.box[3] && !!offset(first) && JSON.stringify(offset(first)) === JSON.stringify(offset(out)) &&
      s.aria === 'status' && s.actionBox && s.actionBox[3] >= 24, { log, s })
  }

  if (runs(13)) {
    await open('#/queen?tab=kanban', { mode: 'consent-required' })
    await until(frameShown, 30000)
    await wait(800)
    const shown = await chip()
    const noButton = await inFrame(`${APP}/bridge`, `(() => { const r = document.getElementById('no')?.getBoundingClientRect(); return r && r.width ? { x: r.left + r.width / 2, y: r.top + r.height / 2 } : null })()`)
    const askedBefore = await inFrame(`${APP}/bridge`, `JSON.parse(document.body.dataset.asked || '[]').length`)
    let press = null
    let hidden = null
    let after = null
    let under = null
    if (shown.frameBox && noButton) {
      const x = shown.frameBox[0] + 1 + noButton.x
      const y = shown.frameBox[1] + 1 + noButton.y
      press = { x, y, topHit: await evaluate(`document.elementFromPoint(${x}, ${y})?.className ?? null`) }
      await mouse(x, y)
      hidden = await until(`(() => { const f = document.querySelector('iframe.queen27-identity-bridge'); return f && f.hidden })()`, 15000)
      await wait(500)
      after = await chip()
      under = await evaluate(`(() => { const e = document.elementFromPoint(${x}, ${y}); return e ? e.tagName + '.' + String(e.className).slice(0, 50) : null })()`)
    }
    const hit = hidden ? await evaluate(HIT_ACTION) : null
    if (hit?.hit) await mouse(hit.x, hit.y)
    const again = hit?.hit ? await until(frameShown, 20000) : null
    // The request arrives in the bridge a message later than the click: wait for it.
    const askedAfter = await inFrame(`${APP}/bridge`, `(() => { const n = JSON.parse(document.body.dataset.asked || '[]').length; return n > ${Number(askedBefore)} ? n : null })()`, 15000)
    const final = await chip()
    record(13, 'Not now in the bridge (trusted click): the frame hides and the point under it is the page again; the chip keeps "Confirm in TRI", and a trusted click on it asks again and shows the prompt',
      shown.state === 'consent-required' && String(press?.topHit).includes('queen27-identity-bridge') &&
      !!hidden && after?.state === 'consent-required' && /^Confirm in TRI/.test(after.text) && !String(under).startsWith('IFRAME') &&
      hit?.hit === true && !!again && askedAfter === askedBefore + 1 && final.frameHidden === false, { shown, press, after, under, hit, askedBefore, askedAfter, final })
  }

  if (runs(14)) {
    await open('#/queen?tab=kanban', { mode: 'expired' })
    const seen = await until(`document.querySelector('[data-tool="identity"]')?.dataset.identity === 'expired'`, 30000)
    const e = await chip()
    record(14, 'expired: "Resume in TRI", a top-level link to the player login returning to the view; the frame stays hidden',
      !!seen && e.text === 'Resume in TRI' && e.action === 'a' && e.href === returnTo('kanban') && e.target === '_top' && e.frameHidden === true, { e })
  }

  if (runs(15)) {
    bridgeBlocked = true
    let unavailable = null
    let u = null
    try {
      await open('#/queen?tab=kanban', { mode: 'signed-out' })
      unavailable = await until(`document.querySelector('[data-tool="identity"]')?.dataset.identity === 'unavailable'`, 30000)
      u = await chip()
    } finally {
      bridgeBlocked = false
    }
    const docs = bridgeDocs()
    const retry = unavailable ? await evaluate(HIT_ACTION) : null
    if (retry?.hit) await mouse(retry.x, retry.y)
    const back = retry?.hit ? await until(`document.querySelector('[data-tool="identity"]')?.dataset.identity === 'signed-out'`, 30000) : null
    record(15, 'the bridge refused: within the answer deadline the chip says "TRI did not answer" with Retry; a trusted click on Retry loads the bridge again and gives "Sign in"',
      !!unavailable && u.code === 'no_answer' && /TRI did not answer/.test(u.text) && retry?.hit === true && retry.text === 'Retry' && !!back && bridgeDocs() > docs, { u, retry, back, docs: bridgeDocs() - docs })
  }

  if (runs(16) || runs(20)) {
    const host = `${APP}/hive-host?mode=signed-out`
    await load(host)
    const target = await inFrame(`${GAME}/`, `(() => { const c = document.querySelector('[data-tool="identity"]'); if (!c || c.dataset.identity !== 'signed-out') return null; const a = c.querySelector('.queen27-identity-action') ?? c; const r = a.getBoundingClientRect(); const x = r.left + r.width / 2, y = r.top + r.height / 2; const u = document.elementFromPoint(x, y);
      return { tag: a.tagName, href: a.getAttribute('href'), target: a.getAttribute('target'), x, y, hit: !!u && (u === a || a.contains(u)) } })()`, 150000)
    const gameAt = await evaluate(`(() => { const r = document.getElementById('game').getBoundingClientRect(); return [r.left, r.top] })()`)
    let topHit = null
    if (target?.hit) {
      const x = gameAt[0] + target.x
      const y = gameAt[1] + target.y
      topHit = await evaluate(`document.elementFromPoint(${x}, ${y})?.tagName ?? null`)
      await mouse(x, y)
    }
    await wait(2500)
    const app = await evaluate(`JSON.parse(document.body.dataset.app || '[]')`).catch((e) => String(e))
    const where = await evaluate('location.href').catch((e) => String(e))
    if (runs(16)) record(16, 'inside the player and signed out: the chip is a button, and a trusted click posts {v:1, type:"t27-app", kind:"sign-in"} to the player; the tab stays',
      target?.tag === 'BUTTON' && target.hit && topHit === 'IFRAME' && Array.isArray(app) && app.length === 1 && app[0].v === 1 && app[0].type === 't27-app' && app[0].kind === 'sign-in' && where === host,
      { target, topHit, app, where })

    if (runs(20)) {
      // The player's login modal now covers the game (the stub opened it on the sign-in request).
      const widget = await evaluate(`(() => { const b = document.getElementById('widget'); const r = b.getBoundingClientRect(); const x = r.left + r.width / 2, y = r.top + r.height / 2; return r.width ? { x, y, hit: document.elementFromPoint(x, y) === b } : null })()`)
      const askedBefore = await evaluate(`Number(document.body.dataset.asked)`)
      // A mark on the game document: signing in must neither navigate nor reload it.
      const marked = await inFrame(`${GAME}/`, `(() => { document.documentElement.dataset.contractMark = 'kept'; return true })()`)
      if (widget?.hit) await mouse(widget.x, widget.y)
      const closed = widget?.hit ? await until(`getComputedStyle(document.getElementById('modal')).display === 'none'`, 10000) : null
      // The pointer comes back over the game, away from where the widget was.
      if (closed) for (const d of [0, 40]) await call('Input.dispatchMouseEvent', { type: 'mouseMoved', x: gameAt[0] + 300 + d, y: gameAt[1] + 300 + d })
      const shown = closed ? await inFrame(`${GAME}/`, `(() => { const c = document.querySelector('[data-tool="identity"]'); return c?.dataset.identity === 'signed-in' && c.querySelector('.queen27-identity-name') ? { name: c.querySelector('.queen27-identity-name').textContent, mark: document.documentElement.dataset.contractMark ?? null } : null })()`, 20000) : null
      const askedAfter = await evaluate(`Number(document.body.dataset.asked)`)
      const whereAfter = await evaluate('location.href').catch((e) => String(e))
      record(20, "inside the player: the player's modal signs the person in (a trusted click on its widget) and tells the game nothing; the pointer coming back over the game asks again and the chip shows the person, with no navigation or reload",
        !!marked && !!widget?.hit && !!closed && shown?.name === 'Ada <b>Stub</b>' && shown.mark === 'kept' && askedAfter > askedBefore && whereAfter === host,
        { widget, closed, shown, askedBefore, askedAfter, whereAfter })
    }
  }

  if (runs(17)) {
    await open('#/queen?tab=kanban', { mode: 'signed-in' })
    await until(`!!document.querySelector('.queen27-identity-name')`, 30000)
    await wait(1000)
    const before = await chip()
    const docs = bridgeDocs()
    await evaluate(`location.hash = '#/about'`)
    await until(`!document.querySelector('button.queen27-hud-cmd[data-view]')`, 30000)
    await wait(1500)
    const away = await chip()
    await evaluate(`location.hash = '#/queen?tab=kanban'`)
    await until(railReady, 120000)
    await until(`!!document.querySelector('.queen27-identity-name')`, 30000)
    await wait(1500)
    const back = await chip()
    record(17, 'leaving the Queen blanks the bridge frame; back within the token life the person is still shown and the bridge is not loaded again',
      String(before.frameSrc).startsWith(`${APP}/bridge`) && away.frameSrc === 'about:blank' && back.state === 'signed-in' && back.name === 'Ada <b>Stub</b>' && bridgeDocs() === docs,
      { before: before.frameSrc, away: away.frameSrc, back, docs: bridgeDocs() - docs })
  }

  if (runs(18)) {
    await open('#/queen?tab=tri&screen=crm', { mode: 'signed-out' })
    const href = await until(`(() => { const c = document.querySelector('[data-tool="identity"]'); if (c?.dataset.identity !== 'signed-out') return null; const a = c.querySelector('a') ?? c; return a.getAttribute('href') })()`, 30000)
    const expected = `${APP}/?return=${encodeURIComponent(`${GAME}/#/queen?tab=tri&screen=crm`)}`
    record(18, 'on the TRI tab Sign in returns to the same screen (tab=tri&screen=crm), in the form the player accepts', href === expected, { href, expected })
  }

  if (runs(19)) {
    await phone()
    let hit = null
    try {
      await open('#/queen?tab=tri', { mode: 'consent-required' })
      await until(frameShown, 30000)
      await wait(1500)
      hit = await evaluate(`(() => { const b = document.querySelector('button.queen27-hud-cmd[data-view="tri"]'); const f = document.querySelector('iframe.queen27-identity-bridge'); if (!b || !f) return null; const r = b.getBoundingClientRect(); const x = r.left + r.width / 2, y = r.top + r.height / 2; const u = document.elementFromPoint(x, y); const fr = f.getBoundingClientRect();
        return { box: [r.left, r.top, r.width, r.height].map(Math.round), inView: x >= 0 && x <= innerWidth && y >= 0 && y <= innerHeight, hit: !!u && (u === b || b.contains(u)), under: u ? u.tagName + '.' + String(u.className).slice(0, 50) : null, frame: [fr.left, fr.top, fr.width, fr.height].map(Math.round), frameHidden: f.hidden } })()`)
    } finally {
      await desktop()
    }
    // Desktops: no control of the rail, the Queen's column (its composer), the quick
    // commands, the tools row or the map's control row lies under the prompt (box
    // overlap, not only the centre), and a trusted press on the composer input focuses it.
    const HUD = '.queen27-hud-command, .queen27-hud-intel, .queen27-hud-commands, .queen27-hud-top, .queen27-hud-vp-tools, .queen-catalog-tools, .queen-catalog-search-toggle'
    const desk = {}
    let deskOk = true
    try {
      for (const [w, h] of [[1440, 900], [1280, 720], [1200, 800], [1024, 768]]) {
        await call('Emulation.setDeviceMetricsOverride', { width: w, height: h, deviceScaleFactor: 1, mobile: false })
        for (const view of ['comb', 'kanban', 'tri']) {
          await open(`#/queen?tab=${view}`, { mode: 'consent-required' })
          await until(frameShown, 30000)
          await wait(1500)
          const m = await evaluate(`(() => { const f = document.querySelector('iframe.queen27-identity-bridge'); if (!f || f.hidden) return null; const fr = f.getBoundingClientRect(); const covered = []; let checked = 0;
            for (const el of document.querySelectorAll('button, a[href], input, textarea, select, [role=button]')) {
              if (!el.closest(${JSON.stringify(HUD)})) continue; const r = el.getBoundingClientRect(); if (!r.width || !r.height) continue;
              const cs = getComputedStyle(el); if (cs.visibility === 'hidden') continue; if (r.right <= 0 || r.bottom <= 0 || r.left >= innerWidth || r.top >= innerHeight) continue;
              checked++;
              if (r.left < fr.right && r.right > fr.left && r.top < fr.bottom && r.bottom > fr.top) covered.push(el.tagName.toLowerCase() + ' "' + (el.textContent || el.getAttribute('placeholder') || el.getAttribute('aria-label') || '').trim().slice(0, 24) + '"');
            }
            const input = [...document.querySelectorAll('.queen27-hud-intel input, .queen27-hud-intel textarea')].find((e) => { const r = e.getBoundingClientRect(); return r.width > 0 && r.height > 0 && r.left < innerWidth && r.right > 0 && r.top < innerHeight && r.bottom > 0 });
            const ir = input ? input.getBoundingClientRect() : null;
            return { frame: [fr.left, fr.top, fr.width, fr.height].map(Math.round), checked, covered, input: ir ? { x: ir.left + ir.width / 2, y: ir.top + ir.height / 2 } : null } })()`)
          let composer = null
          if (m?.input) {
            await evaluate('document.activeElement?.blur?.(); true')
            await mouse(m.input.x, m.input.y)
            await wait(300)
            composer = await evaluate(`(() => { const a = document.activeElement; return !!a && !!a.closest('.queen27-hud-intel') && (a.tagName === 'INPUT' || a.tagName === 'TEXTAREA') })()`)
          }
          desk[`${w}x${h}/${view}`] = { frame: m?.frame ?? null, checked: m?.checked ?? 0, covered: m?.covered ?? null, composer }
          deskOk = deskOk && !!m && m.checked > 0 && m.covered.length === 0 && (m.input ? composer === true : w <= 1100)
        }
      }
    } finally {
      await desktop()
    }
    record(19, "the consent prompt shown: at 390x844 the rail's TRI command is still under its centre; at 1440x900, 1280x720, 1200x800 and 1024x768 no control of the rail, the Queen's column, the quick commands, the tools row or the map's control row lies under it, and a trusted press on the composer input focuses it",
      hit?.frameHidden === false && hit.inView && hit.hit && deskOk, { hit, desk })
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
