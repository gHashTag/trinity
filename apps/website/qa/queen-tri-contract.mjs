// The Queen's TRI tab in a real browser: the app inside the game, one screen
// per address.
//
// Builds the site (unless --no-build; --dist <dir> serves another build), serves
// it on 127.0.0.1, and drives the installed Chrome over CDP. Nothing reaches
// app.t27.ai: every request to it is answered by CDP Fetch with a stub page that
// behaves like the app in embed mode -- it posts {type:'t27-app', kind:'ready'}
// to its parent, and posts a 'route' when this harness asks it to (the harness
// talks to the stub; the game itself never posts into the frame). Site isolation
// is switched off so the stub frame's requests pass through the page's Fetch.
//
// Checks, at 1440x900 unless stated:
//   1  key r opens TRI on the feed: tab=tri, no screen=, frame src is the app URL
//   2  a screen click writes screen=; a reload keeps it; an answering app shows no strip
//   3  an address set from outside moves the screen and the frame
//   4  a route message from the app, with the main thread janked so the address
//      write lags, moves screen= without reloading the frame (no new request)
//   5  a CRM client route (/crm/42) leaves no client id in the address; a
//      profile route (/durov) writes path=, survives a reload, and a click on
//      the active screen returns the frame to the screen's root
//   6  two writes inside one janked transition keep each other's keys
//   7  screen clicks add no history entries: one Back leaves TRI
//   8  leaving TRI drops screen= and path=
//   9  a silent app gets the "did not answer" strip and a link out
//  10  inside the app (an app.t27.ai page framing the game) TRI frames nothing;
//      inside another host it does (control)
//  11  390x844: a deep link to TRI shows its rail button, no sideways page scroll
//  12  the app pushes two pages inside the frame, then a screen click: every
//      Back shows the frame's previous page with screen= following it, and the
//      third leaves TRI (a fresh frame element per screen stranded those
//      entries: Back did nothing twice)
//  13  control for 12, the player's embed contract: an app that REPLACES its
//      in-frame pages leaves TRI on one Back after a screen click
//  14  an embedded Queen (a landing preview, embed=1) pressed with r shows TRI
//      without a frame and asks app.t27.ai for nothing
//
// Checks 15-20 press with TRUSTED input only (CDP Input mouse, touch and key
// events), because element.click() passes on a control the pointer cannot reach:
//  15  every TRI screen button is the element under the pointer, and a real
//      click (1440x900) or tap (390x844) on Agent moves the frame and address
//  16  at the rail's rest position every command is the element under its
//      centre (1440x900, 1440x813, 1366x768, 1280x800, 1280x720), a click on
//      TRI opens it, and the collapsed rail lists TRI and opens it too
//  17  a hung app document (never loads): from TRI's mount, the link out shows
//      beside the spinner after about 3 s, the "did not answer" strip after about 8 s
//  18  an app that posts {kind:'error', code} gets an error strip with the link
//  19  the key r on a Russian layout (key 'к', code KeyR) opens TRI, and on Dvorak
//      the typed p (code KeyR) opens Project and r (code KeyO) TRI; turned off
//      in the menu the digit keys do nothing, also after a reload
//  20  inactive toggles (a layer off, shortcuts off) keep text contrast >= 4.5:1
//  21  the open HUD menu: every item is the element under the pointer at
//      1440x900 and 1280x720 (mouse) and 390x844 (touch)
//
// The frame's src attribute is its first URL only; checks read data-src (where
// TRI sent the frame) and the frame tree (where the frame really is).
//
// Exits 0 on pass, 1 on a failed check, 2 when it could not run (never read as a pass).
//
//   node qa/queen-tri-contract.mjs [--no-build] [--dist <dir>] [--only 1,2,...]

import { execSync, spawn } from 'node:child_process'
import { createServer } from 'node:http'
import { readFileSync, existsSync, mkdtempSync, rmSync } from 'node:fs'
import { join, extname, normalize, resolve } from 'node:path'
import { tmpdir } from 'node:os'

const ROOT = new URL('..', import.meta.url).pathname
const argAt = (name) => { const i = process.argv.indexOf(name); return i >= 0 ? process.argv[i + 1] : null }
const DIST = resolve(argAt('--dist') ?? join(ROOT, 'dist'))
const ONLY = argAt('--only') ? new Set(argAt('--only').split(',').map(Number)) : null
const runs = (n) => !ONLY || ONLY.has(n)
const APP = 'https://app.t27.ai'
const EVAL_TIMEOUT_MS = Number(process.env.TRI_EVAL_TIMEOUT_MS || 60000)
const HUD_VIEW_COUNT = (readFileSync(join(ROOT, 'src/components/queenHud.ts'), 'utf8')
  .match(/export const HUD_VIEWS[^=]*=\s*\[([\s\S]*?)\]\s*as const/)?.[1]
  .match(/^\s*"[a-z]+",/gm) ?? []).length

const CHROME = [process.env.CHROME_PATH, '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/usr/bin/google-chrome', '/usr/bin/chromium-browser', '/usr/bin/chromium'].filter(Boolean).find((p) => existsSync(p))
if (!CHROME) {
  console.log('  no Chrome found — skipping the TRI check. Set CHROME_PATH to force it.')
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
// The dist file for a path, the way Pages serves it (unknown paths get index.html).
const distFile = (pathname) => {
  const p = normalize(decodeURIComponent(pathname)).replace(/^(\.\.[/\\])+/, '')
  const file = join(DIST, p)
  return !file.startsWith(DIST) || !existsSync(file) || p === '/' ? join(DIST, 'index.html') : file
}
const server = createServer((req, res) => {
  const file = distFile(req.url.split('?')[0])
  try { res.writeHead(200, { 'Content-Type': MIME[extname(file)] || 'application/octet-stream' }); res.end(readFileSync(file)) } catch { res.writeHead(404).end() }
})
// Check 10 frames the game from https host pages. A public https page may not
// frame http://127.0.0.1, so there the same dist is served as https://game.test
// through CDP Fetch.
const GAME = 'https://game.test'
await new Promise((r) => server.listen(0, '127.0.0.1', r))
const ORIGIN = `http://127.0.0.1:${server.address().port}`

// ---- The stub app ----
let stubMode = 'answer' // 'answer' | 'silent' | 'error' | 'hang' (the app page never answers the request)
const requests = [] // every app.t27.ai URL the page asked for
const STUB = (mode) => `<!doctype html><meta charset="utf-8"><title>app stub</title>
<body style="background:#123;color:#fff;font:14px monospace">stub <span id="where"></span>
<script>
  document.getElementById('where').textContent = location.pathname + location.search;
  const post = (kind, path) => parent.postMessage({ type: 't27-app', kind, path }, '*');
  ${mode === 'answer' || mode === 'error' ? "post('ready', location.pathname);" : ''}
  ${mode === 'error' ? "setTimeout(() => parent.postMessage({ type: 't27-app', kind: 'error', code: 'boundary' }, '*'), 300);" : ''}
  // The harness (not the game) asks for a route message this way, or for an
  // in-app navigation that pushes or replaces a history entry, as the app's
  // router does. Back inside the frame reports its route too.
  const here = () => { document.getElementById('where').textContent = location.pathname + location.search; };
  addEventListener('message', (e) => {
    if (typeof e.data !== 'string') return;
    if (e.data.startsWith('harness-route:')) post('route', e.data.slice(14));
    const nav = e.data.match(/^harness-(push|replace):(.*)$/);
    if (nav) { history[nav[1] + 'State']({}, '', nav[2] + location.search); here(); post('route', location.pathname); }
  });
  addEventListener('popstate', () => { here(); post('route', location.pathname); });
</script>`
const HOST = (target) => `<!doctype html><meta charset="utf-8"><title>host</title>
<body style="margin:0"><iframe id="game" src="${target}" style="width:1200px;height:800px;border:0" referrerpolicy="strict-origin-when-cross-origin"></iframe>`

const profile = mkdtempSync(join(tmpdir(), 'queen-tri-'))
const chrome = spawn(CHROME, [
  '--headless=new', '--remote-debugging-port=0', `--user-data-dir=${profile}`,
  '--no-first-run', '--no-default-browser-check', '--disable-extensions', '--disable-background-networking', '--disable-sync', '--mute-audio',
  '--window-size=1440,900',
  '--disable-site-isolation-trials', '--disable-features=IsolateOrigins,site-per-process',
  ...(process.platform === 'linux' ? ['--no-sandbox', '--disable-dev-shm-usage'] : []),
  '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', 'about:blank',
], { stdio: ['ignore', 'ignore', 'pipe'] })
const cleanup = () => { try { chrome.kill('SIGKILL') } catch { /* gone */ } server.close(); try { rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 }) } catch { /* ignored */ } }

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
  listeners.push((m) => {
    if (m.sessionId !== sessionId) return
    if (m.method === 'Runtime.exceptionThrown') errors.push(m.params.exceptionDetails.exception?.description?.split('\n')[0] ?? m.params.exceptionDetails.text)
    if (m.method === 'Fetch.requestPaused') {
      const { requestId, request } = m.params
      const url = new URL(request.url)
      let body
      let type = 'text/html; charset=utf-8'
      if (url.origin === GAME) {
        const file = distFile(url.pathname)
        body = readFileSync(file)
        type = MIME[extname(file)] || 'application/octet-stream'
      } else if (url.origin === APP && url.pathname === '/hive-host') body = HOST(`${GAME}/?lang=en#/queen?tab=tri`)
      else if (url.origin === 'https://t27.ai' && url.pathname === '/host') body = HOST(`${GAME}/?lang=en#/queen?tab=tri`)
      else {
        requests.push(request.url)
        if (stubMode === 'hang' && !url.pathname.startsWith('/bridge')) return // left paused: the document never arrives
        body = STUB(stubMode)
      }
      send('Fetch.fulfillRequest', { requestId, responseCode: 200, responseHeaders: [{ name: 'Content-Type', value: type }], body: Buffer.from(body).toString('base64') }, sessionId).catch(() => {})
    }
  })
  await call('Runtime.enable')
  await call('Page.enable')
  await call('Fetch.enable', { patterns: [{ urlPattern: `${APP}/*` }, { urlPattern: 'https://t27.ai/host*' }, { urlPattern: `${GAME}/*` }] })

  const evaluate = async (expression, contextId) => {
    const r = await call('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true, ...(contextId ? { contextId } : {}) })
    if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || r.exceptionDetails.text)
    return r.result.value
  }
  const until = async (expr, ms, contextId) => { const start = Date.now(); while (Date.now() - start < ms) { try { const v = await evaluate(expr, contextId); if (v) return v } catch { /* not yet */ } await wait(200) } return null }
  const load = async (url) => {
    const loaded = new Promise((r) => { const t = setTimeout(r, 60000); listeners.push((m) => { if (m.sessionId === sessionId && m.method === 'Page.loadEventFired') { clearTimeout(t); r() } }) })
    await call('Page.navigate', { url })
    await loaded
  }
  const railReady = `document.querySelectorAll('button.queen27-hud-cmd[data-view]').length > 0 && !!document.querySelector('main[data-view]')`
  const STATE = `(() => { const q = new URLSearchParams(location.hash.split('?')[1] ?? ''); const f = document.querySelector('iframe.queen27-tri-frame');
    return { view: document.querySelector('main[data-view]')?.getAttribute('data-view') ?? null, tab: q.get('tab'), screen: q.get('screen'), path: q.get('path'), hash: location.hash,
      src: f?.dataset.src ?? null, shown: document.querySelector('.queen27-tri')?.getAttribute('data-screen') ?? null,
      pressed: [...document.querySelectorAll('.queen27-tri-screen[aria-pressed="true"]')].map((b) => b.dataset.screen),
      noanswer: !!document.querySelector('.queen27-tri-noanswer'), loading: !!document.querySelector('.queen27-tri-loading'), history: history.length } })()`
  const state = () => evaluate(STATE)
  const clickScreen = (s) => evaluate(`document.querySelector('.queen27-tri-screen[data-screen="${s}"]').click()`)
  const clickRail = (v) => evaluate(`document.querySelector('button.queen27-hud-cmd[data-view="${v}"]').click()`)
  const askRoute = (p) => evaluate(`document.querySelector('iframe.queen27-tri-frame').contentWindow.postMessage(${JSON.stringify(`harness-route:${p}`)}, '*')`)
  const askNav = (mode, p) => evaluate(`document.querySelector('iframe.queen27-tri-frame').contentWindow.postMessage(${JSON.stringify(`harness-${mode}:`)} + ${JSON.stringify(p)}, '*')`)
  // Where the app frame really is (the src attribute stays its first URL).
  const appFrameUrl = async () => ((await call('Page.getFrameTree')).frameTree.childFrames ?? []).map((f) => f.frame.url).find((u) => u.startsWith(APP)) ?? null
  // Long tasks back to back, the shape of the hive's work on t27.ai: React's
  // transition (the address) waits, a message handler still runs between them.
  const jank = (on) => evaluate(on
    ? `window.__jank = setInterval(() => { const t = performance.now(); while (performance.now() - t < 250); }, 5)`
    : `clearInterval(window.__jank)`)
  const frameUrl = (route) => `${APP}${route}?embed=1&lang=en`
  const count = (url) => requests.filter((u) => u === url).length
  // A fresh search on every open: a URL that differs only in its hash is a
  // same-document navigation, which fires no load event and keeps the old page.
  let opens = 0
  const open = async (hash) => { await load(`${ORIGIN}/?lang=en&open=${++opens}${hash}`); if (!(await until(railReady, 90000))) throw new Error(`the Queen shell never rendered at ${hash}`) }

  await call('Emulation.setDeviceMetricsOverride', { width: 1440, height: 900, deviceScaleFactor: 1, mobile: false })

  if (runs(1) || runs(2) || runs(3) || runs(4) || runs(5) || runs(6)) {
    await open('#/queen?tab=kanban')
    await evaluate(`document.activeElement?.blur?.(); window.dispatchEvent(new KeyboardEvent('keydown', { key: 'r' }))`)
    await until(`document.querySelector('main[data-view]')?.getAttribute('data-view') === 'tri' && !!document.querySelector('iframe.queen27-tri-frame')`, 20000)
    const rail = await evaluate(`({ buttons: document.querySelectorAll('.queen27-hud-command button.queen27-hud-cmd').length, views: Number(document.querySelector('.queen27-hud-command')?.dataset.views) })`)
    await until(`new URLSearchParams(location.hash.split('?')[1] ?? '').get('tab') === 'tri'`, 20000)
    let s = await state()
    record(1, 'key r opens TRI on the feed with the app URL in the frame', s.view === 'tri' && s.tab === 'tri' && s.screen === null && s.src === frameUrl('/feed') && s.pressed.join() === 'feed' && rail.buttons === HUD_VIEW_COUNT && rail.views === HUD_VIEW_COUNT, { s, rail, HUD_VIEW_COUNT })

    if (runs(2)) {
      await clickScreen('chat')
      await until(`new URLSearchParams(location.hash.split('?')[1] ?? '').get('screen') === 'chat'`, 20000)
      s = await state()
      const clicked = s.screen === 'chat' && s.tab === 'tri' && s.src === frameUrl('/chat') && s.pressed.join() === 'chat'
      await call('Page.reload', {})
      await until(`${railReady} && !!document.querySelector('iframe.queen27-tri-frame')`, 90000)
      await wait(TRI_WAIT())
      const after = await state()
      after.frame = await appFrameUrl()
      record(2, 'a screen click writes screen=chat, a reload keeps it, an answering app shows no strip', clicked && after.view === 'tri' && after.screen === 'chat' && after.src === frameUrl('/chat') && after.frame === frameUrl('/chat') && !after.noanswer && !after.loading, { clicked: s, after })
    }

    if (runs(3)) {
      await evaluate(`location.hash = '#/queen?tab=tri&screen=crm'`)
      await until(`document.querySelector('iframe.queen27-tri-frame')?.dataset.src ===${JSON.stringify(frameUrl('/crm'))}`, 20000)
      s = await state()
      s.frame = await appFrameUrl()
      for (let i = 0; i < 50 && s.frame !== frameUrl('/crm'); i++) { await wait(200); s.frame = await appFrameUrl() }
      record(3, 'an outside hash moves the screen and the frame to crm', s.view === 'tri' && s.screen === 'crm' && s.pressed.join() === 'crm' && s.src === frameUrl('/crm') && s.frame === frameUrl('/crm'), s)
    }

    if (runs(4)) {
      await evaluate(`location.hash = '#/queen?tab=tri&screen=crm'`)
      await until(`document.querySelector('iframe.queen27-tri-frame')?.dataset.src ===${JSON.stringify(frameUrl('/crm'))}`, 20000)
      await wait(1500)
      const crmBefore = count(frameUrl('/crm'))
      const videoBefore = count(frameUrl('/generate/video'))
      await jank(true)
      await askRoute('/generate/video')
      await until(`new URLSearchParams(location.hash.split('?')[1] ?? '').get('screen') === 'video' && document.querySelector('.queen27-tri')?.dataset.screen === 'video'`, 30000)
      await wait(3000)
      await jank(false)
      await wait(1500)
      s = await state()
      record(4, 'a janked route message moves screen= to video without reloading the frame', s.screen === 'video' && s.shown === 'video' && s.pressed.join() === 'script' && s.src === frameUrl('/crm') && count(frameUrl('/generate/video')) === videoBefore && count(frameUrl('/crm')) === crmBefore, { s, crm: [crmBefore, count(frameUrl('/crm'))], video: [videoBefore, count(frameUrl('/generate/video'))] })
    }

    if (runs(5)) {
      await clickScreen('crm')
      await until(`document.querySelector('.queen27-tri')?.dataset.screen === 'crm'`, 20000)
      await wait(1500)
      // One CRM client: the screen stays crm and its id never reaches the address.
      await askRoute('/crm/42')
      await wait(2500)
      const client = await state()
      // One profile: path= carries it through a reload.
      await clickScreen('profile')
      await until(`document.querySelector('.queen27-tri')?.dataset.screen === 'profile'`, 20000)
      await wait(1500)
      await askRoute('/durov')
      await until(`new URLSearchParams(location.hash.split('?')[1] ?? '').get('path') === '/durov'`, 20000)
      const deep = await state()
      await call('Page.reload', {})
      await until(`${railReady} && !!document.querySelector('iframe.queen27-tri-frame')`, 90000)
      const reloaded = await state()
      reloaded.frame = await appFrameUrl()
      const rootBefore = count(frameUrl('/profile'))
      await clickScreen('profile')
      await until(`document.querySelector('iframe.queen27-tri-frame')?.dataset.src === ${JSON.stringify(frameUrl('/profile'))}`, 20000)
      await wait(1500)
      const back = await state()
      record(5, 'a CRM client route leaves no id in the address; a profile route writes path=/durov, survives a reload, and a click on Profile returns to its root',
        client.screen === 'crm' && client.path === null && !/42/.test(client.hash) &&
        deep.screen === 'profile' && deep.path === '/durov' && reloaded.src === frameUrl('/durov') && reloaded.frame === frameUrl('/durov') && reloaded.path === '/durov' &&
        back.src === frameUrl('/profile') && back.path === null && back.screen === 'profile' && count(frameUrl('/profile')) === rootBefore + 1, { client, deep, reloaded, back })
    }

    if (runs(6)) {
      await clickRail('kanban')
      await until(`new URLSearchParams(location.hash.split('?')[1] ?? '').get('tab') === 'kanban'`, 20000)
      await wait(1000)
      await jank(true)
      // TRI rail, then Agent, before the tab=tri navigation commits. The shell
      // mounts TRI from the click's own update (flushed in a microtask), while
      // the address waits in the janked transition.
      const pressedBoth = await evaluate(`(async () => {
        document.querySelector('button.queen27-hud-cmd[data-view="tri"]').click();
        for (let i = 0; i < 200 && !document.querySelector('.queen27-tri-screen[data-screen="chat"]'); i++) await (i < 20 ? Promise.resolve() : new Promise((r) => setTimeout(r, 0)));
        const agent = document.querySelector('.queen27-tri-screen[data-screen="chat"]');
        if (!agent) return false;
        agent.click();
        return true;
      })()`)
      if (!pressedBoth) throw new Error('step 6: TRI never mounted after the rail click')
      await wait(3000)
      await jank(false)
      await until(`new URLSearchParams(location.hash.split('?')[1] ?? '').get('screen') === 'chat'`, 20000)
      await wait(2000)
      const a = await state()
      // Agent, then the TRI rail again: the shell's write must keep screen=chat.
      await clickScreen('feed')
      await until(`!new URLSearchParams(location.hash.split('?')[1] ?? '').get('screen')`, 20000)
      await wait(1000)
      await jank(true)
      await evaluate(`document.querySelector('.queen27-tri-screen[data-screen="chat"]').click(); document.querySelector('button.queen27-hud-cmd[data-view="tri"]').click()`)
      await wait(3000)
      await jank(false)
      await wait(3000)
      const b = await state()
      record(6, 'two writes in one janked transition keep each other (tab=tri&screen=chat both ways)', a.view === 'tri' && a.tab === 'tri' && a.screen === 'chat' && a.shown === 'chat' && b.view === 'tri' && b.tab === 'tri' && b.screen === 'chat' && b.shown === 'chat' && b.src === frameUrl('/chat'), { a, b })
    }
  }

  if (runs(7) || runs(8)) {
    await open('#/queen?tab=kanban')
    await evaluate(`location.hash = '#/queen?tab=tri'`)
    await until(`!!document.querySelector('.queen27-tri-screen[data-screen="chat"]')`, 20000)
    await wait(1500)
    const before = await state()
    for (const screen of ['chat', 'crm', 'script']) { await clickScreen(screen); await wait(1200) }
    await until(`new URLSearchParams(location.hash.split('?')[1] ?? '').get('screen') === 'script'`, 20000)
    const clicked = await state()
    if (runs(7)) {
      await evaluate(`history.back()`)
      await until(`new URLSearchParams(location.hash.split('?')[1] ?? '').get('tab') === 'kanban'`, 20000)
      await wait(1500)
      const back = await state()
      record(7, 'three screen clicks add no history entry; one Back leaves TRI for kanban', clicked.history === before.history && back.tab === 'kanban' && back.view === 'kanban' && back.screen === null, { before, clicked, back })
      await evaluate(`history.forward()`)
      await until(`document.querySelector('main[data-view]')?.getAttribute('data-view') === 'tri'`, 20000)
    }
    if (runs(8)) {
      await evaluate(`location.hash = '#/queen?tab=tri&screen=profile&path=/durov&layers=foundation'`)
      await until(`document.querySelector('iframe.queen27-tri-frame')?.dataset.src === ${JSON.stringify(frameUrl('/durov'))}`, 20000)
      await clickRail('kanban')
      await until(`new URLSearchParams(location.hash.split('?')[1] ?? '').get('tab') === 'kanban'`, 20000)
      await wait(1000)
      const left = await state()
      record(8, 'leaving TRI drops screen= and path= and keeps other keys', left.view === 'kanban' && left.screen === null && left.path === null && /layers=foundation/.test(left.hash), left)
    }
  }

  if (runs(9)) {
    stubMode = 'silent'
    await open('#/queen?tab=tri&screen=chat')
    await until(`!!document.querySelector('iframe.queen27-tri-frame')`, 20000)
    const strip = await until(`(() => { const s = document.querySelector('.queen27-tri-noanswer'); return s ? { href: s.querySelector('a')?.getAttribute('href'), target: s.querySelector('a')?.getAttribute('target') } : null })()`, 30000)
    record(9, 'a silent app gets the "did not answer" strip with a link out to the same screen', strip && strip.href === `${APP}/chat` && strip.target === '_blank', strip)
    stubMode = 'answer'
  }

  if (runs(10)) {
    const inFrame = async (hostUrl) => {
      await load(hostUrl)
      const tree = await call('Page.getFrameTree')
      const child = tree.frameTree.childFrames?.find((f) => f.frame.url.startsWith(GAME))
      if (!child) return { error: 'no game frame', tree: tree.frameTree.childFrames?.map((f) => f.frame.url) }
      const { executionContextId } = await call('Page.createIsolatedWorld', { frameId: child.frame.id, worldName: 'tri-contract' })
      const ready = await until(`!!document.querySelector('.queen27-tri')`, 90000, executionContextId)
      return ready ? evaluate(`({ nested: !!document.querySelector('.queen27-tri.is-nested'), frames: document.querySelectorAll('iframe.queen27-tri-frame').length, ancestors: [...(location.ancestorOrigins ?? [])] })`, executionContextId) : { error: 'TRI never rendered in the frame' }
    }
    const inside = await inFrame(`${APP}/hive-host`)
    const other = await inFrame('https://t27.ai/host')
    record(10, 'inside an app.t27.ai page TRI frames nothing and says so; inside t27.ai it frames the app', inside.nested === true && inside.frames === 0 && other.nested === false && other.frames === 1, { inside, other })
  }

  if (runs(11)) {
    await call('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 1, mobile: true })
    await open('#/queen?tab=tri')
    await until(`!!document.querySelector('.queen27-hud-command.is-compact button[data-view="tri"].is-active')`, 30000)
    await wait(1500)
    const phone = await evaluate(`(() => { const rail = document.querySelector('.queen27-hud-command.is-compact'); const b = rail?.querySelector('button[data-view="tri"]'); if (!rail || !b) return null;
      const r = rail.getBoundingClientRect(), x = b.getBoundingClientRect(); const de = document.scrollingElement;
      return { inside: x.left >= r.left - 0.5 && x.right <= r.right + 0.5 && x.width > 0, rail: [Math.round(r.left), Math.round(r.right)], button: [Math.round(x.left), Math.round(x.right)], sideways: de.scrollWidth > de.clientWidth + 1 } })()`)
    record(11, '390x844: the TRI rail button is in view after a deep link, no sideways page scroll', phone && phone.inside && !phone.sideways, phone)
    await call('Emulation.setDeviceMetricsOverride', { width: 1440, height: 900, deviceScaleFactor: 1, mobile: false })
  }

  // 12 and 13: the app navigates inside the frame (mode 'push' or 'replace'),
  // then a screen click, then Back up to three times.
  const backWalk = async (mode) => {
    await open('#/queen?tab=kanban')
    await evaluate(`location.hash = '#/queen?tab=tri&screen=script'`)
    await until(`document.querySelector('.queen27-tri')?.dataset.screen === 'script' && !document.querySelector('.queen27-tri-loading')`, 30000)
    await wait(1500)
    const start = await state()
    for (const [route, screen] of [['/generate/video', 'video'], ['/generate/editor', 'editor']]) {
      await askNav(mode, route)
      await until(`new URLSearchParams(location.hash.split('?')[1] ?? '').get('screen') === ${JSON.stringify(screen)}`, 20000)
      await wait(800)
    }
    await clickScreen('chat')
    await until(`new URLSearchParams(location.hash.split('?')[1] ?? '').get('screen') === 'chat'`, 20000)
    for (let i = 0; i < 50 && (await appFrameUrl()) !== frameUrl('/chat'); i++) await wait(200)
    await wait(1500)
    const clicked = { ...(await state()), frame: await appFrameUrl() }
    const steps = []
    for (let i = 0; i < 3; i++) {
      const prev = steps.at(-1) ?? clicked
      await evaluate('history.back()')
      // Wait for anything to change; a dead Back entry changes nothing.
      const t0 = Date.now()
      let now = { ...(await state()), frame: await appFrameUrl() }
      while (Date.now() - t0 < 10000 && now.view === prev.view && now.hash === prev.hash && now.frame === prev.frame) { await wait(250); now = { ...(await state()), frame: await appFrameUrl() } }
      await wait(1500)
      now = { ...(await state()), frame: await appFrameUrl() }
      steps.push(now)
      if (now.view !== 'tri') break
    }
    return { start, clicked, steps: steps.map(({ view, screen, shown, frame, history: h }) => ({ view, screen, shown, frame, history: h })) }
  }

  if (runs(12)) {
    const w = await backWalk('push')
    const [b1, b2, b3] = w.steps
    record(12, 'after two pages pushed inside the frame and a screen click, each Back shows the previous page with screen= following, the third leaves TRI',
      w.clicked.history === w.start.history + 2 &&
      b1?.view === 'tri' && b1.screen === 'video' && b1.shown === 'video' && b1.frame === frameUrl('/generate/video') &&
      b2?.view === 'tri' && b2.screen === 'script' && b2.shown === 'script' && b2.frame === frameUrl('/generate/script') &&
      b3?.view === 'kanban' && b3.screen === null, w)
  }

  if (runs(13)) {
    const w = await backWalk('replace')
    const [b1] = w.steps
    record(13, 'control: an app that replaces its in-frame pages leaves TRI on one Back after a screen click',
      w.clicked.history === w.start.history && b1?.view === 'kanban' && b1.screen === null, w)
  }

  if (runs(14)) {
    // The landing's previews frame the Queen with embed=1 and hide its rail,
    // but the digit and letter keys still reach it.
    const before = requests.length
    await load(`${ORIGIN}/?lang=en&open=${++opens}#/queen?tab=kanban&embed=1`)
    await until(`document.querySelector('main[data-view]')?.getAttribute('data-view') === 'kanban'`, 90000)
    await wait(1500)
    await evaluate(`document.activeElement?.blur?.(); window.dispatchEvent(new KeyboardEvent('keydown', { key: 'r' }))`)
    const shown = await until(`document.querySelector('main[data-view]')?.getAttribute('data-view') === 'tri' && !!document.querySelector('.queen27-tri')`, 20000)
    await wait(2500)
    const preview = await evaluate(`({ preview: !!document.querySelector('.queen27-tri.is-preview'), frames: document.querySelectorAll('iframe.queen27-tri-frame').length })`)
    record(14, 'an embedded Queen pressed with r shows TRI without a frame and asks app.t27.ai for nothing',
      shown && preview.preview && preview.frames === 0 && requests.length === before, { shown, preview, requests: requests.slice(before) })
  }

  // ---- Trusted input for 15-20: CDP Input events, never element.click() ----
  const press = async (x, y, touch = false) => {
    if (touch) {
      await call('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y }] })
      await call('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] })
    } else for (const type of ['mouseMoved', 'mousePressed', 'mouseReleased']) await call('Input.dispatchMouseEvent', { type, x, y, button: 'left', buttons: type === 'mousePressed' ? 1 : 0, clickCount: 1 })
  }
  const key = async (k, code, vk) => { for (const type of ['keyDown', 'keyUp']) await call('Input.dispatchKeyEvent', { type, key: k, code, windowsVirtualKeyCode: vk, ...(type === 'keyDown' ? { text: k } : {}) }) }
  // Every match: its centre, and whether it is the element under that point.
  const HIT = (sel) => `[...document.querySelectorAll(${JSON.stringify(sel)})].map((e) => { const r = e.getBoundingClientRect(); const x = r.left + r.width / 2, y = r.top + r.height / 2; const u = document.elementFromPoint(x, y);
    return { id: e.dataset.view ?? e.dataset.screen ?? e.dataset.setting ?? null, x: Math.round(x), y: Math.round(y), self: !!u && (u === e || e.contains(u)), under: u ? (u.tagName.toLowerCase() + '.' + String(u.className).trim().split(/\\s+/).join('.')).slice(0, 70) : null } })`
  const setSize = async (w, h, touch = false) => {
    await call('Emulation.setDeviceMetricsOverride', { width: w, height: h, deviceScaleFactor: 1, mobile: touch })
    await call('Emulation.setTouchEmulationEnabled', { enabled: touch, maxTouchPoints: touch ? 5 : 1 })
  }
  const viewIs = (v, ms = 6000) => until(`document.querySelector('main[data-view]')?.getAttribute('data-view') === ${JSON.stringify(v)}`, ms)
  const viewNow = () => evaluate(`document.querySelector('main[data-view]')?.getAttribute('data-view')`)

  if (runs(15)) {
    const out = {}
    let ok = true
    for (const [w, h, touch] of [[1440, 900, false], [390, 844, true]]) {
      await setSize(w, h, touch)
      await open('#/queen?tab=tri')
      await until(`!!document.querySelector('.queen27-tri-screen[data-screen="chat"]')`, 20000)
      await wait(1500)
      const hits = await evaluate(HIT('.queen27-tri-screen'))
      const agent = hits.find((b) => b.id === 'chat')
      if (agent) await press(agent.x, agent.y, touch)
      const moved = await until(`new URLSearchParams(location.hash.split('?')[1] ?? '').get('screen') === 'chat' && document.querySelector('iframe.queen27-tri-frame')?.dataset.src === ${JSON.stringify(frameUrl('/chat'))}`, 5000)
      out[`${w}x${h}`] = { covered: hits.filter((b) => !b.self), moved: !!moved }
      ok = ok && hits.length === 5 && hits.every((b) => b.self) && !!moved
    }
    await setSize(1440, 900)
    record(15, 'trusted input: every TRI screen button is under the pointer, and a real click (1440x900) or tap (390x844) on Agent moves the frame and the address', ok, out)
  }

  if (runs(16)) {
    const out = {}
    let ok = true
    for (const [w, h] of [[1440, 900], [1440, 813], [1366, 768], [1280, 800], [1280, 720]]) {
      await setSize(w, h)
      await open('#/queen?tab=kanban')
      await wait(1000)
      const rest = await evaluate(`({ top: document.querySelector('.queen27-hud-command').scrollTop, hits: ${HIT('.queen27-hud-command > .queen27-hud-cmd')} })`)
      const tri = rest.hits.find((b) => b.id === 'tri')
      if (tri) await press(tri.x, tri.y)
      const opened = !!(await viewIs('tri'))
      const collapse = (await evaluate(HIT('.queen27-hud-command > .queen27-hud-cmd-collapse')))[0]
      if (collapse) await press(collapse.x, collapse.y)
      await until(`!!document.querySelector('.queen27-hud-command.is-collapsed')`, 4000)
      await wait(600)
      const folded = await evaluate(HIT('.queen27-hud-command.is-collapsed > .queen27-hud-cmd'))
      const fk = folded.find((b) => b.id === 'kanban')
      const ft = folded.find((b) => b.id === 'tri')
      let foldedOpens = false
      if (fk && ft) {
        await press(fk.x, fk.y)
        const k = !!(await viewIs('kanban'))
        await press(ft.x, ft.y)
        foldedOpens = k && !!(await viewIs('tri'))
      }
      out[`${w}x${h}`] = { top: rest.top, count: rest.hits.length, covered: rest.hits.filter((b) => !b.self), opened, folded: folded.length, foldedCovered: folded.filter((b) => !b.self), foldedOpens }
      ok = ok && rest.top === 0 && rest.hits.length === HUD_VIEW_COUNT && rest.hits.every((b) => b.self) && opened &&
        folded.length === HUD_VIEW_COUNT && folded.every((b) => b.self) && foldedOpens
    }
    await setSize(1440, 900)
    record(16, 'trusted input: at rest every rail command is under the pointer at five desktop sizes, TRI opens by click, and the collapsed rail lists TRI and opens it', ok, out)
  }

  if (runs(17)) {
    stubMode = 'hang'
    await open('#/queen?tab=kanban')
    // Timed on the page's own clock from the moment TRI mounts its frame (the
    // loading overlay appears): the answer clock starts there, and a busy main
    // thread can take seconds between the address write and the mount.
    await evaluate(`(() => { const t = window.__tri17 = {}; const seen = () => { const n = performance.now();
      if (t.mount === undefined && document.querySelector('.queen27-tri-loading')) t.mount = n;
      if (t.link === undefined && document.querySelector('.queen27-tri-loading a')) t.link = n;
      if (t.strip === undefined && document.querySelector('.queen27-tri-noanswer')) t.strip = n; };
      new MutationObserver(seen).observe(document.body, { childList: true, subtree: true }); return true })()`)
    await evaluate(`location.hash = '#/queen?tab=tri&screen=chat'`)
    await until(`window.__tri17?.strip !== undefined`, 20000)
    const t = await evaluate(`window.__tri17`)
    const found = await evaluate(`(() => { const a = document.querySelector('.queen27-tri-loading a'); const s = document.querySelector('.queen27-tri-noanswer a'); return { link: a && { href: a.getAttribute('href'), target: a.getAttribute('target') }, strip: s && { href: s.getAttribute('href'), target: s.getAttribute('target') } } })()`)
    const s = await state()
    const linkMs = t.link !== undefined && t.mount !== undefined ? Math.round(t.link - t.mount) : null
    const stripMs = t.strip !== undefined && t.mount !== undefined ? Math.round(t.strip - t.mount) : null
    // 8 s is the design; up to 3 s more is timer and render delay on a loaded machine, not a missed clock.
    record(17, 'a hung app document: from the mount, the link out shows beside the spinner after about 3 s and the "did not answer" strip after about 8 s',
      found.link?.href === `${APP}/chat` && found.link.target === '_blank' && found.strip?.href === `${APP}/chat` && s.loading &&
      linkMs !== null && linkMs >= 2500 && stripMs !== null && stripMs >= 7500 && stripMs <= 11000 && linkMs < stripMs,
      { linkMs, stripMs, found, loading: s.loading })
    stubMode = 'answer'
  }

  if (runs(18)) {
    stubMode = 'error'
    await open('#/queen?tab=tri&screen=chat')
    const err = await until(`(() => { const s = document.querySelector('.queen27-tri-noanswer.is-error'); return s ? { code: s.dataset.code, role: s.getAttribute('role'), href: s.querySelector('a')?.getAttribute('href'), text: s.innerText } : null })()`, 20000)
    await wait(TRI_WAIT())
    const s = await state()
    const silent = await evaluate(`document.querySelectorAll('.queen27-tri-noanswer:not(.is-error)').length`)
    record(18, 'an app that posts {kind:"error", code:"boundary"} gets an error strip naming the code with the link out, and no "did not answer" strip',
      err && err.code === 'boundary' && err.role === 'alert' && err.href === `${APP}/chat` && /boundary/.test(err.text) && silent === 0 && !s.loading, { err, silent, loading: s.loading })
    stubMode = 'answer'
  }

  if (runs(19)) {
    const blur = () => evaluate(`document.activeElement?.blur?.(); true`)
    await open('#/queen?tab=kanban')
    await blur()
    await key('к', 'KeyR', 82)
    const russian = !!(await viewIs('tri'))
    // Dvorak: p is typed on the physical R key, r on the physical O key.
    await key('p', 'KeyR', 80)
    const dvorakP = !!(await viewIs('project'))
    await key('r', 'KeyO', 82)
    const dvorakR = !!(await viewIs('tri'))
    const toggleShortcuts = async () => {
      const menu = (await evaluate(HIT('.queen27-hud-menu-btn')))[0]
      await press(menu.x, menu.y)
      await until(`!!document.querySelector('[data-setting="key-shortcuts"]')`, 4000)
      const t = (await evaluate(HIT('[data-setting="key-shortcuts"]')))[0]
      if (t?.self) await press(t.x, t.y)
      await wait(400)
      const pressed = await evaluate(`document.querySelector('[data-setting="key-shortcuts"]')?.getAttribute('aria-pressed') ?? null`)
      await press(menu.x, menu.y)
      await wait(300)
      return { reachable: !!t?.self, pressed }
    }
    const off = await toggleShortcuts()
    await blur()
    await key('3', 'Digit3', 51)
    await wait(1500)
    const offView = await viewNow()
    await call('Page.reload', {})
    await until(railReady, 90000)
    await wait(1500)
    await blur()
    await key('3', 'Digit3', 51)
    await wait(1500)
    const reloadedView = await viewNow()
    const on = await toggleShortcuts()
    await blur()
    await key('3', 'Digit3', 51)
    const onAgain = !!(await viewIs('kanban'))
    record(19, 'key к with code KeyR opens TRI; on Dvorak the typed p (code KeyR) opens Project and r (code KeyO) TRI; shortcuts turned off in the menu leave the view alone, also after a reload; turned on, 3 opens kanban again',
      russian && dvorakP && dvorakR && off.reachable && off.pressed === 'false' && offView === 'tri' && reloadedView === 'tri' && on.pressed === 'true' && onAgain, { russian, dvorakP, dvorakR, off, offView, reloadedView, on, onAgain })
  }

  if (runs(20)) {
    // Text contrast of a control over its ground: every background from the
    // field veil (rgba(2,8,6,.62) over the black sky) outwards in, the text
    // colour with its alpha and every ancestor's opacity on top.
    const CONTRAST = (sel) => `(() => {
      const parse = (c) => { const m = String(c).match(/rgba?\\(([^)]+)\\)/); if (!m) return [0, 0, 0, 0]; const p = m[1].split(/[\\s,/]+/).filter(Boolean).map(Number); return [p[0], p[1], p[2], p.length > 3 ? p[3] : 1] };
      const over = (top, bottom) => [0, 1, 2].map((i) => top[i] * top[3] + bottom[i] * (1 - top[3])).concat(1);
      const lum = (c) => { const [r, g, b] = c.slice(0, 3).map((v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4 }); return 0.2126 * r + 0.7152 * g + 0.0722 * b };
      return [...document.querySelectorAll(${JSON.stringify(sel)})].map((e) => {
        const texts = [e, ...e.querySelectorAll('span, b, i')].filter((t) => { const r = t.getBoundingClientRect(); return r.width > 0 && r.height > 0 && t.textContent.trim() });
        const ratios = texts.map((t) => {
          const chain = []; let opacity = 1;
          for (let p = t; p; p = p.parentElement) { const cs = getComputedStyle(p); chain.unshift(parse(cs.backgroundColor)); opacity *= Number(cs.opacity) }
          let bg = over([2, 8, 6, 0.62], [0, 0, 0, 1]); for (const c of chain) bg = over(c, bg);
          const fc = parse(getComputedStyle(t).color); const fg = over([fc[0], fc[1], fc[2], fc[3] * opacity], bg);
          const a = lum(fg), b = lum(bg); return Math.round(((Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05)) * 100) / 100 });
        return { text: e.textContent.trim().slice(0, 30), min: ratios.length ? Math.min(...ratios) : null } }) })()`
    await open('#/queen')
    await until(`!!document.querySelector('.queen27-hud-vp-tools button[data-layer]')`, 30000)
    await wait(1500)
    const layer = (await evaluate(HIT('.queen27-hud-vp-tools button[data-layer][aria-pressed="true"]')))[0]
    if (layer?.self) await press(layer.x, layer.y)
    await until(`!!document.querySelector('.queen27-hud-vp-tools button[data-layer][aria-pressed="false"]')`, 4000)
    const away = async () => { await call('Input.dispatchMouseEvent', { type: 'mouseMoved', x: 2, y: 450 }); await wait(300) } // no :hover colour on what is measured
    await away()
    const layerOff = await evaluate(CONTRAST('.queen27-hud-vp-tools button[data-layer][aria-pressed="false"]'))
    const menu = (await evaluate(HIT('.queen27-hud-menu-btn')))[0]
    await press(menu.x, menu.y)
    const t = (await until(`(() => { const r = ${HIT('[data-setting="key-shortcuts"]')}; return r.length ? r : null })()`, 4000))?.[0]
    if (t?.self) await press(t.x, t.y)
    await until(`document.querySelector('[data-setting="key-shortcuts"]')?.getAttribute('aria-pressed') === 'false'`, 4000)
    await call('Input.dispatchMouseEvent', { type: 'mouseMoved', x: menu.x, y: menu.y })
    await wait(300)
    const shortcutsOff = await evaluate(CONTRAST('[data-setting="key-shortcuts"][aria-pressed="false"]'))
    if (t?.self) await press(t.x, t.y) // back on for whatever runs next in this profile
    const all = [...layerOff, ...shortcutsOff]
    record(20, 'inactive toggles (a layer off, key shortcuts off) keep text contrast at least 4.5:1', layerOff.length > 0 && shortcutsOff.length > 0 && all.every((x) => x.min !== null && x.min >= 4.5), { layerOff, shortcutsOff })
  }

  if (runs(21)) {
    const out = {}
    let ok = true
    for (const [w, h, touch] of [[1440, 900, false], [1280, 720, false], [390, 844, true]]) {
      await setSize(w, h, touch)
      await open('#/queen?tab=tri')
      await wait(1500)
      const btn = (await evaluate(HIT('.queen27-hud-menu-btn')))[0]
      if (btn?.self) await press(btn.x, btn.y, touch)
      await until(`!!document.querySelector('#queen-hud-menu')`, 4000)
      await wait(500)
      const items = await evaluate(HIT('#queen-hud-menu > li > button, #queen-hud-menu > li > a'))
      out[`${w}x${h}`] = { menuButton: !!btn?.self, items: items.length, covered: items.filter((x) => !x.self) }
      ok = ok && !!btn?.self && items.length >= 4 && items.every((x) => x.self)
    }
    await setSize(1440, 900)
    record(21, 'trusted input: every item of the open HUD menu is under the pointer (1440x900, 1280x720) and the finger (390x844)', ok, out)
  }

  const failed = checks.filter((c) => !c.ok)
  if (errors.length) console.log(`  uncaught exceptions: ${JSON.stringify(errors.slice(0, 5))}`)
  console.log(`\n  Queen TRI contract: ${failed.length ? 'FAIL' : 'PASS'} (${checks.length - failed.length}/${checks.length})`)
  cleanup()
  process.exit(failed.length ? 1 : 0)
} catch (e) {
  console.log(`  could not run: ${e?.message ?? e} (checks so far: ${checks.filter((c) => c.ok).length}/${checks.length} passed)`)
  cleanup()
  process.exit(2)
}

function TRI_WAIT() { return 9500 } // longer than the component's 8 s answer window
