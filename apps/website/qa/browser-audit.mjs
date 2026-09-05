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

export async function collectRouteText(language, baseUrl) {
  const chromePath = CHROME_CANDIDATES.find(path => existsSync(path))
  if (!chromePath) throw new Error('Chrome/Chromium не найден; задайте CHROME_PATH')

  const profile = mkdtempSync(join(tmpdir(), 't27-language-audit-'))
  const chrome = spawn(chromePath, [
    '--headless=new', '--remote-debugging-port=0', `--user-data-dir=${profile}`,
    '--no-first-run', '--no-default-browser-check', '--disable-extensions',
    '--disable-background-networking', '--disable-sync', '--mute-audio',
    '--window-size=1440,900', '--disable-dev-shm-usage',
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

    const result = {}
    for (const route of ROUTES) {
      const url = `${baseUrl.replace(/#.*$/, '')}#/${route}`
      await call('Page.navigate', { url })
      await wait(700)
      const evaluated = await call('Runtime.evaluate', {
        // Elements marked data-lang-exempt hold quoted source, not UI copy --
        // the /specs page renders .t27 files whose comments are written in
        // whatever language their author used. Translating them would
        // misrepresent the files. The surrounding UI is still audited, so this
        // narrows the gate rather than switching it off for the route.
        expression: `(() => {
          if (!document.body) return "";
          const clone = document.body.cloneNode(true);
          clone.querySelectorAll('[data-lang-exempt]').forEach((n) => n.remove());
          return clone.innerText;
        })()`,
        returnByValue: true,
      })
      if (evaluated.exceptionDetails) throw new Error(`Не удалось прочитать /${route}`)
      result[route] = String(evaluated.result?.value || '')
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
