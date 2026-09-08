// The Queen's proxy.
//
// It exists for one reason: a model key cannot live in the website. Everything
// under VITE_ is compiled into the public bundle, so the browser talks to this
// service and this service holds the key. Nothing here is Trinity logic — it
// translates one contract into another and forwards.
//
// The website's contract (chatApi.ts):
//   GET  /health -> 200 when a model is reachable
//   POST /chat   {message} -> {response, source, confidence, latency_us}
//
// The provider's contract is OpenAI-compatible chat completions, which is what
// OpenRouter, Groq, Together, DeepSeek and Google's compat endpoint all speak.
// Choosing a provider is three environment variables, never a code change.
import { createServer } from 'node:http'

const PORT = Number(process.env.PORT || 8080)
const PROVIDER_URL = process.env.QUEEN_PROVIDER_URL || 'https://openrouter.ai/api/v1/chat/completions'
const MODEL = process.env.QUEEN_MODEL || ''
const KEY = process.env.QUEEN_API_KEY || ''
// A model on our own network needs no key, and demanding one would keep the
// proxy permanently unconfigured in exactly the setup that has no secret to
// hold. Anything off-network does need one.
const INTERNAL = /(^https?:\/\/)(localhost|127\.0\.0\.1|[^/]*\.railway\.internal)/.test(PROVIDER_URL)
const KEY_REQUIRED = !INTERNAL
// The site is the only origin that needs this; a proxy open to everyone is a
// key open to everyone.
const ORIGINS = (process.env.QUEEN_ALLOWED_ORIGINS || 'https://t27.ai').split(',').map((s) => s.trim()).filter(Boolean)

// The hive she works through. Without these she can still answer; with them she
// can see what the bees are carrying and open or close a task herself.
const BEES_URL = (process.env.QUEEN_BEES_URL || '').replace(/\/$/, '')
const BEES_TOKEN = process.env.QUEEN_BEES_TOKEN || ''

const SYSTEM = [
  'You are the Queen of the Trinity hive.',
  'You answer about .t27 specs, the repositories on the shared map, and the GitHub issues the board is working through.',
  'The bracketed prefix of a message is the context the operator is looking at.',
  'Answer briefly and concretely. Say plainly when you do not know.',
  '',
  'You direct the bees. To act, end your reply with one directive on its own line:',
  'DIRECTIVE {"action":"open_task","name":"<what the bee is to do>","bee":"<bee id>"}',
  'DIRECTIVE {"action":"close_task","id":"<session id>"}',
  'Open a task only when the work is named concretely enough for a bee to start.',
  'Close one only after reviewing it and saying what you reviewed.',
  'No directive is the right answer when nothing needs to change.',
].join('\n')

// What the bees are carrying, so a review is of the board rather than of memory.
async function hiveQueue() {
  if (!BEES_URL || !BEES_TOKEN) return null
  try {
    const res = await fetch(`${BEES_URL}/api/sessions`, {
      headers: { Authorization: `Bearer ${BEES_TOKEN}` },
      signal: AbortSignal.timeout(8000),
    })
    if (!res.ok) return { error: `bees ${res.status}` }
    return await res.json()
  } catch (error) {
    return { error: String(error?.message || error) }
  }
}

// Her decisions reach the hive here, and only in these two shapes. Anything else
// in the reply is prose: the proxy never forwards what it did not recognise.
async function runDirective(text) {
  const line = /^DIRECTIVE\s+(\{.*\})\s*$/m.exec(text || '')
  if (!line) return null
  if (!BEES_URL || !BEES_TOKEN) return { ok: false, error: 'the hive is not configured' }
  let directive
  try { directive = JSON.parse(line[1]) } catch { return { ok: false, error: 'unreadable directive' } }

  const call = async (path, init) => {
    const res = await fetch(`${BEES_URL}${path}`, {
      ...init,
      headers: { Authorization: `Bearer ${BEES_TOKEN}`, 'Content-Type': 'application/json', ...(init?.headers || {}) },
      signal: AbortSignal.timeout(15000),
    })
    const body = await res.text()
    return { ok: res.ok, status: res.status, body: body.slice(0, 400) }
  }

  if (directive.action === 'open_task') {
    if (!directive.name || !directive.bee) return { ok: false, error: 'open_task needs name and bee' }
    return { action: 'open_task', ...(await call('/api/sessions', { method: 'POST', body: JSON.stringify({ name: directive.name, service_id: directive.bee }) })) }
  }
  if (directive.action === 'close_task') {
    if (!directive.id) return { ok: false, error: 'close_task needs id' }
    return { action: 'close_task', ...(await call(`/api/sessions/${encodeURIComponent(directive.id)}`, { method: 'DELETE' })) }
  }
  return { ok: false, error: `unknown action ${directive.action}` }
}

function cors(req, res) {
  const origin = req.headers.origin
  if (origin && ORIGINS.includes(origin)) res.setHeader('Access-Control-Allow-Origin', origin)
  res.setHeader('Vary', 'Origin')
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type')
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS')
}

function json(res, code, body) {
  res.writeHead(code, { 'Content-Type': 'application/json' })
  res.end(JSON.stringify(body))
}

async function ask(message) {
  const started = Date.now()
  const queue = await hiveQueue()
  const upstream = await fetch(PROVIDER_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${KEY}` },
    body: JSON.stringify({
      model: MODEL,
      messages: [
        { role: 'system', content: SYSTEM },
        ...(queue ? [{ role: 'system', content: `The hive right now: ${JSON.stringify(queue)}` }] : []),
        { role: 'user', content: message },
      ],
    }),
  })
  if (!upstream.ok) {
    // The provider's own words, not a guess at what went wrong.
    throw new Error(`provider ${upstream.status}: ${(await upstream.text()).slice(0, 200)}`)
  }
  const body = await upstream.json()
  const text = body?.choices?.[0]?.message?.content
  if (!text) throw new Error('provider returned no message')

  // Carry out what she decided, and report the outcome rather than the
  // intention: a directive that failed must not read as work that happened.
  const acted = await runDirective(text)

  return {
    response: acted ? `${text}\n\n[hive] ${JSON.stringify(acted)}` : text,
    acted,
    source: MODEL,
    // Not a measurement: no provider reports one, and a number here would read
    // as a fact the way a sample does.
    confidence: 0,
    latency_us: (Date.now() - started) * 1000,
  }
}

// Ollama starts empty, and a volume that survives a restart does not survive a
// provider losing the disk. Rather than a shell step in the image, the proxy
// makes sure the model is there: it asks once on boot and again whenever a
// health check finds it missing, so a wiped host heals itself without anyone
// logging in.
const OLLAMA_ROOT = PROVIDER_URL.replace(/\/v1\/chat\/completions$/, '')
let pulling = null

async function modelPresent() {
  const res = await fetch(`${OLLAMA_ROOT}/api/tags`, { signal: AbortSignal.timeout(5000) })
  if (!res.ok) return false
  const body = await res.json()
  return (body.models ?? []).some((m) => m.name === MODEL || m.name?.split(':')[0] === MODEL.split(':')[0])
}

function ensureModel() {
  if (!INTERNAL || !MODEL || pulling) return pulling
  pulling = (async () => {
    try {
      if (await modelPresent()) return
      console.log(`pulling ${MODEL}…`)
      const res = await fetch(`${OLLAMA_ROOT}/api/pull`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: MODEL, stream: false }),
      })
      console.log(`pull ${MODEL}: ${res.status}`)
    } catch (error) {
      console.log(`pull ${MODEL} failed: ${error?.message || error}`)
    } finally {
      pulling = null
    }
  })()
  return pulling
}

createServer(async (req, res) => {
  cors(req, res)
  if (req.method === 'OPTIONS') { res.writeHead(204); return res.end() }

  if (req.url === '/health') {
    // Configured is not the same as answering, but an unconfigured proxy must
    // never report itself healthy — the panel would show LIVE and fail on send.
    const configured = Boolean(MODEL) && (KEY || !KEY_REQUIRED)
    if (!configured) return json(res, 503, { ok: false, model: MODEL || null, provider: PROVIDER_URL })
    if (!INTERNAL) return json(res, 200, { ok: true, model: MODEL, provider: PROVIDER_URL })
    // On our own network the model is a fact we can check rather than assume.
    let present = false
    try { present = await modelPresent() } catch { present = false }
    if (!present) ensureModel()
    return json(res, present ? 200 : 503, { ok: present, model: MODEL, provider: PROVIDER_URL, pulling: !present })
  }

  if (req.url === '/chat' && req.method === 'POST') {
    if (!MODEL || (KEY_REQUIRED && !KEY)) return json(res, 503, { error: KEY_REQUIRED ? 'QUEEN_MODEL and QUEEN_API_KEY are required for an off-network provider' : 'QUEEN_MODEL is not set' })
    let raw = ''
    for await (const chunk of req) raw += chunk
    try {
      const { message } = JSON.parse(raw || '{}')
      if (!message) return json(res, 400, { error: 'message is required' })
      return json(res, 200, await ask(message))
    } catch (error) {
      return json(res, 502, { error: String(error?.message || error) })
    }
  }

  return json(res, 404, { error: 'not found' })
}).listen(PORT, () => {
  console.log(`queen-proxy on ${PORT} -> ${MODEL || '(no model set)'} at ${PROVIDER_URL}`)
  ensureModel()
})
