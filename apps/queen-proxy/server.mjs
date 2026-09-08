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
import { randomUUID } from 'node:crypto'

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

// The Queen the hive already runs. trios-agent-server holds the repository, the
// bees and the model keys, and it already speaks this contract: POST /chat with
// {message}, GET /health. Its /chat answers 403 to anyone without a token,
// which is the whole reason it is reached from here — the token lives in this
// service's environment, and the website's bundle, which is public, never sees
// it. Set QUEEN_TRIOS_URL and she is the Queen who answers; leave it unset and
// the provider below is.
const TRIOS_URL = (process.env.QUEEN_TRIOS_URL || '').replace(/\/$/, '')
const TRIOS_TOKEN = process.env.QUEEN_TRIOS_TOKEN || ''
// Which header carries it is the server's choice, not ours to guess in code.
const TRIOS_HEADER = process.env.QUEEN_TRIOS_AUTH_HEADER || 'Authorization'
const TRIOS_SCHEME = process.env.QUEEN_TRIOS_AUTH_SCHEME ?? 'Bearer '
// Her /chat asks for the provider and the model by name — it is one server in
// front of many backends, not one model. These are the two her worker runs on
// (TRIOS_QUEEN_WORKER_MODEL); a change there is a change here, not a rebuild.
const TRIOS_PROVIDER = process.env.QUEEN_TRIOS_PROVIDER || 'zai'
const TRIOS_MODEL = process.env.QUEEN_TRIOS_MODEL || 'glm-5.3'
// Her /chat carries the provider's key per request rather than holding one:
// it is one server in front of many people's backends. So the key lives here,
// in this service's environment, which is the same reason the token does — the
// website's bundle is public and must never carry either.
const TRIOS_API_KEY = process.env.QUEEN_TRIOS_API_KEY || ''
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

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

// Her answer comes back under one of several names depending on which route
// served it. The proxy reads what is there rather than insisting on one, and
// says so plainly when there is nothing.
function answerText(body) {
  if (typeof body === 'string') return body
  return (
    body?.response ??
    body?.reply ??
    body?.answer ??
    body?.message?.content ??
    (typeof body?.message === 'string' ? body.message : null) ??
    body?.content ??
    body?.text ??
    body?.choices?.[0]?.message?.content ??
    ''
  )
}

// Her /chat does not answer in one shape. It has been a JSON object; it is a
// stream of SSE frames when the model streams; a run of JSON lines when it does
// not. Reading the body as text once and trying each in turn costs one string
// and removes the failure this proxy actually had: `.json()` threw on a stream,
// the answer became null, and the website reported the Queen absent while she
// was answering. Nothing here invents an answer — an unreadable body is still
// an error, and it is quoted.
// A frame that carries a reason rather than an answer. Her stream names it
// `errorText`; other shapes say `error` or `detail`. Anything found here is her
// words, and they are passed on unchanged.
function failureText(value) {
  if (!value || typeof value !== 'object') return ''
  if (value.type !== 'error' && !value.error && !value.errorText && !value.detail) return ''
  const said =
    value.errorText ??
    value.detail ??
    (typeof value.error === 'string' ? value.error : value.error?.message) ??
    value.message
  return typeof said === 'string' && said.trim() ? said.trim() : ''
}

async function readAnswer(upstream) {
  const raw = await upstream.text()
  const trimmed = raw.trim()
  if (!trimmed) return { text: '', failure: '', raw }
  try {
    const one = JSON.parse(trimmed)
    return { text: answerText(one), failure: failureText(one), raw }
  } catch {
    // not one object; it may be many
  }
  // SSE frames and JSON lines differ by a prefix and nothing else.
  const frames = trimmed
    .split('\n')
    .map((line) => line.trim())
    .map((line) => (line.startsWith('data:') ? line.slice(5).trim() : line))
    .filter((line) => line && line !== '[DONE]')
  let out = ''
  let read = false
  let failure = ''
  for (const frame of frames) {
    let value
    try {
      value = JSON.parse(frame)
    } catch {
      continue
    }
    read = true
    // She reports a refusal inside the stream, not as a status: the response is
    // 200 and the reason is a frame in it. Dropped, the website said she had
    // not answered — when she had said precisely why she could not. Measured
    // 2026-09-08: "[1310] Weekly/Monthly Limit Exhausted" arrived this way and
    // reached the operator as silence.
    const said = failureText(value)
    if (said) {
      failure ||= said
      continue
    }
    out += value?.choices?.[0]?.delta?.content ?? answerText(value) ?? ''
  }
  if (read) return { text: out, failure, raw }
  // A 2xx body that is not JSON at all is her answer in plain words, and a
  // readable answer is better than reporting her silent.
  return { text: trimmed, failure: '', raw }
}

async function askTrios(message, conversation) {
  const started = Date.now()
  const upstream = await fetch(`${TRIOS_URL}/chat`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(TRIOS_TOKEN ? { [TRIOS_HEADER]: `${TRIOS_SCHEME}${TRIOS_TOKEN}` } : {}),
    },
    // She keeps a conversation per id, and validates it as a UUID. A caller
    // that sends none — or sends something that is not one — gets a thread of
    // its own rather than someone else's, or a 400 it cannot read.
    body: JSON.stringify({
      provider: TRIOS_PROVIDER,
      model: TRIOS_MODEL,
      ...(TRIOS_API_KEY ? { apiKey: TRIOS_API_KEY } : {}),
      conversationId: UUID.test(conversation || '') ? conversation : randomUUID(),
      message,
    }),
    // She reads the board and the repository before she answers; a proxy that
    // gives up at thirty seconds would report her absent while she works.
    signal: AbortSignal.timeout(180000),
  })
  if (!upstream.ok) {
    // Her server's own words, at length: a 400 from it is a schema complaint
    // that names the field, and 200 characters cut it off mid-sentence.
    throw new Error(`queen ${upstream.status}: ${(await upstream.text()).slice(0, 900)}`)
  }
  const { text, failure, raw } = await readAnswer(upstream)
  // Her own reason, in her own words, ahead of anything this proxy would say
  // about the shape of the body it could not read.
  if (!text && failure) throw new Error(failure)
  // What came back instead, so a shape we do not read yet is reported rather
  // than guessed at. Status and content-type with it: "no message" and "not
  // reachable" look the same from the website, and they are not the same fault.
  if (!text) {
    const kind = upstream.headers.get('content-type') || 'no content-type'
    throw new Error(`the Queen answered ${upstream.status} ${kind} with nothing readable: ${raw.slice(0, 500) || '(empty body)'}`)
  }
  return {
    response: text,
    source: `${TRIOS_PROVIDER}/${TRIOS_MODEL}`,
    // Not a measurement: her server reports none, and a number here would read
    // as a fact the way a sample does.
    confidence: 0,
    latency_us: (Date.now() - started) * 1000,
  }
}

async function ask(message, conversation) {
  if (TRIOS_URL) return askTrios(message, conversation)
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
    // With her server in front, its health is the answer to this question.
    if (TRIOS_URL) {
      // Her /chat is 403 to a caller without a token, so a proxy that has none
      // is not healthy however well her server is running: the panel would read
      // LIVE and every question would fail on send.
      if (!TRIOS_TOKEN) return json(res, 503, { ok: false, model: 'trios-agent-server', provider: `${TRIOS_URL}/chat`, error: 'QUEEN_TRIOS_TOKEN is not set' })
      // Her provider answers "requires apiKey" to a request without one, so a
      // proxy missing it is not healthy either, however well she is running.
      if (!TRIOS_API_KEY) return json(res, 503, { ok: false, model: `${TRIOS_PROVIDER}/${TRIOS_MODEL}`, provider: `${TRIOS_URL}/chat`, error: 'QUEEN_TRIOS_API_KEY is not set' })
      try {
        const probe = await fetch(`${TRIOS_URL}/health`, { signal: AbortSignal.timeout(8000) })
        return json(res, probe.ok ? 200 : 503, { ok: probe.ok, model: `${TRIOS_PROVIDER}/${TRIOS_MODEL}`, provider: `${TRIOS_URL}/chat`, token: true })
      } catch (error) {
        return json(res, 503, { ok: false, model: 'trios-agent-server', provider: `${TRIOS_URL}/chat`, error: String(error?.message || error) })
      }
    }
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
    if (!TRIOS_URL && (!MODEL || (KEY_REQUIRED && !KEY))) return json(res, 503, { error: KEY_REQUIRED ? 'QUEEN_MODEL and QUEEN_API_KEY are required for an off-network provider' : 'QUEEN_MODEL is not set' })
    let raw = ''
    for await (const chunk of req) raw += chunk
    try {
      const { message, conversation_id: conversation } = JSON.parse(raw || '{}')
      if (!message) return json(res, 400, { error: 'message is required' })
      return json(res, 200, await ask(message, conversation))
    } catch (error) {
      return json(res, 502, { error: String(error?.message || error) })
    }
  }

  return json(res, 404, { error: 'not found' })
}).listen(PORT, () => {
  console.log(TRIOS_URL
    ? `queen-proxy on ${PORT} -> the Queen at ${TRIOS_URL}/chat (token ${TRIOS_TOKEN ? 'set' : 'MISSING'})`
    : `queen-proxy on ${PORT} -> ${MODEL || '(no model set)'} at ${PROVIDER_URL}`)
  if (!TRIOS_URL) ensureModel()
})
