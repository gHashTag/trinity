import { existsSync, mkdtempSync, rmSync } from 'node:fs'
import { spawn } from 'node:child_process'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)
const WebSocketImpl = globalThis.WebSocket || (() => {
  try { return require('ws') }
  catch { return null }
})()

export const ROUTES = [
  '', 'gft', 'start', 'select', 'verification', 'ip', 'proof', 'blog',
  'cases', 'course', 'resources', 'formats', 'ladder', 'theorems', 'bounds',
  'landscape', 'reproduce', 'about', 'queen', 'dashboard', 'tree', 'play',
  'chat', 'quantum', 'lab', 'canvas', 'wasm', 'specs',
]

const CHROME_CANDIDATES = [
  process.env.CHROME_PATH,
  '/usr/bin/google-chrome', '/usr/bin/chromium', '/usr/bin/chromium-browser',
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
].filter(Boolean)

function wait(ms) { return new Promise(resolve => setTimeout(resolve, ms)) }

function openWebSocket(url) {
  if (!WebSocketImpl) throw new Error('WebSocket недоступен: нужен Node 22 или пакет ws')
  const ws = new WebSocketImpl(url)
  return new Promise((resolve, reject) => {
    if (typeof ws.on === 'function') {
      ws.once('open', () => resolve(ws))
      ws.once('error', () => reject(new Error('Не удалось открыть CDP-соединение')))
    } else {
      ws.onopen = () => resolve(ws)
      ws.onerror = () => reject(new Error('Не удалось открыть CDP-соединение'))
    }
  })
}

/**
 * Drive every route once and return whatever `expression` evaluates to on each.
 *
 * The Chrome spawn, the CDP session and -- most importantly -- the settle loop
 * live here ONCE. A second audit that copied this plumbing would eventually
 * copy an older settle, and the whole point of the settle is that two audits
 * cannot disagree about which route they are looking at.
 *
 * `windowSize` sets Chrome's REAL window size. Emulation.setDeviceMetricsOverride
 * was tried first and silently did not take: the page kept laying out at 980px,
 * the no-viewport-meta fallback, and a 900px probe injected into every route was
 * not detected. The negative control caught that; nothing else would have.
 */
export async function forEachRoute(baseUrl, expression, { windowSize } = {}) {
  const chromePath = CHROME_CANDIDATES.find(path => existsSync(path))
  if (!chromePath) throw new Error('Chrome/Chromium не найден; задайте CHROME_PATH')

  const profile = mkdtempSync(join(tmpdir(), 't27-language-audit-'))
  const chrome = spawn(chromePath, [
    '--headless=new', '--remote-debugging-port=0', `--user-data-dir=${profile}`,
    '--no-first-run', '--no-default-browser-check', '--disable-extensions',
    '--disable-background-networking', '--disable-sync', '--mute-audio',
    `--window-size=${windowSize ? `${windowSize.width},${windowSize.height}` : '1440,900'}`, '--disable-dev-shm-usage',
    ...(process.platform === 'linux' ? ['--no-sandbox'] : []),
    '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
    'about:blank',
  ], { stdio: ['ignore', 'ignore', 'pipe'] })

  let ws
  try {
    const debuggingUrl = await new Promise((resolve, reject) => {
      let stderr = ''
      const timer = setTimeout(() => reject(new Error('Chrome не объявил CDP-порт')), 30000)
      chrome.stderr.on('data', chunk => {
        stderr += chunk.toString()
        const match = stderr.match(/DevTools listening on (ws:\/\/\S+)/)
        if (match) { clearTimeout(timer); resolve(match[1]) }
      })
      chrome.once('exit', code => {
        clearTimeout(timer)
        reject(new Error(`Chrome завершился до запуска CDP (код ${code})`))
      })
    })
    ws = await openWebSocket(debuggingUrl)
    let nextId = 0
    const pending = new Map()
    const send = (method, params = {}, sessionId) => new Promise((resolve, reject) => {
      const id = ++nextId
      pending.set(id, { resolve, reject })
      ws.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }))
    })
    const handleMessage = data => {
      const message = JSON.parse(data.toString())
      if (message.id === undefined || !pending.has(message.id)) return
      const { resolve, reject } = pending.get(message.id)
      pending.delete(message.id)
      if (message.error) reject(new Error(message.error.message))
      else resolve(message.result)
    }
    if (typeof ws.on === 'function') ws.on('message', handleMessage)
    else ws.onmessage = event => handleMessage(event.data)

    const { targetId } = await send('Target.createTarget', { url: 'about:blank' })
    const { sessionId } = await send('Target.attachToTarget', { targetId, flatten: true })
    const call = (method, params = {}) => send(method, params, sessionId)
    await call('Runtime.enable')
    await call('Page.enable')
    // --window-size alone bottoms out at 500px in headless Chrome, which is a
    // small tablet, not a phone. The metrics override takes it the rest of the
    // way; both are applied because the override alone leaves the window at its
    // default and some layouts read window.outerWidth.
    if (windowSize) {
      await call('Emulation.setDeviceMetricsOverride', {
        width: windowSize.width,
        height: windowSize.height,
        deviceScaleFactor: 2,
        mobile: true,
      })
    }

    const result = {}
    for (const route of ROUTES) {
      const url = `${baseUrl.replace(/#.*$/, '')}#/${route}`
      await call('Page.navigate', { url })

      // Wait for the ROUTE, not for a duration.
      //
      // This used to be a flat `await wait(700)`. Page.navigate to a hash-only
      // URL does not reload -- it fires hashchange and the SPA re-renders
      // asynchronously -- so on a heavy route (Queen, /dashboard with its
      // motion sections) 700ms often expired while the PREVIOUS route's DOM was
      // still mounted. The harness then stored route A's text under route B's
      // key. That is not slowness, it is misattribution, and it fails in both
      // directions: a translated page captured under an untranslated route's
      // name passes it, and vice versa. It is why /dashboard failed the RU
      // audit on some branches and passed on others while nothing about
      // /dashboard changed.
      //
      // Now: require the SPA to have committed the hash, then require the body
      // text to stop changing for two consecutive samples. Falls through after
      // the budget so a genuinely animating page still gets audited rather than
      // hanging the run.
      const settleExpr = `(() => ({
        hash: location.hash,
        len: document.body ? document.body.innerText.length : -1,
      }))()`
      let previousLen = -2
      let settledFor = 0
      for (let attempt = 0; attempt < 40; attempt++) {
        await wait(150)
        const probe = await call('Runtime.evaluate', { expression: settleExpr, returnByValue: true })
        const state = probe.result?.value
        if (!state) continue
        const hashMatches = state.hash === `#/${route}` || (route === '' && (state.hash === '#/' || state.hash === ''))
        if (!hashMatches) { previousLen = -2; settledFor = 0; continue }
        if (state.len > 0 && state.len === previousLen) settledFor += 1
        else settledFor = 0
        previousLen = state.len
        if (settledFor >= 2) break
      }

      const evaluated = await call('Runtime.evaluate', { expression, returnByValue: true })
      if (evaluated.exceptionDetails) throw new Error(`Не удалось прочитать /${route}`)
      result[route] = evaluated.result?.value
    }
    await send('Target.closeTarget', { targetId })
    ws.close()
    chrome.kill('SIGTERM')
    chrome.unref()
    try { rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 }) } catch {}
    return result
  } catch (error) {
    try { ws?.close() } catch {}
    chrome.kill('SIGTERM')
    chrome.unref()
    try { rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 }) } catch {}
    throw error
  }
}

/**
 * The language audits' view: the page's visible text.
 *
 * Elements marked data-lang-exempt hold quoted source, not UI copy -- /specs
 * renders .t27 files whose comments are in whatever language their author used,
 * and translating those would misrepresent the files. The surrounding UI is
 * still audited, so this narrows the gate rather than switching it off.
 *
 * `language` is unused and kept for call-site compatibility: the locale is
 * carried in baseUrl's query string, which is where the app reads it from.
 */
export async function collectRouteText(language, baseUrl) {
  const texts = await forEachRoute(baseUrl, `(() => {
    if (!document.body) return "";
    const clone = document.body.cloneNode(true);
    clone.querySelectorAll('[data-lang-exempt]').forEach((n) => n.remove());
    return clone.innerText;
  })()`)
  const out = {}
  for (const [route, value] of Object.entries(texts)) out[route] = String(value || '')
  return out
}
