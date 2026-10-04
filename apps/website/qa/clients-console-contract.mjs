// The security contract of the owner's console.
//
// The console reads one person's whole correspondence in a browser tab. Four
// properties keep that from becoming a leak, and none of them is visible by
// reading the page: they live in how the client talks to the service. So they
// are asserted here, against the real module, with a fetch that records every
// call.
//
//   1. The render service's own key never reaches a browser. `X-Api-Key` names
//      the SERVICE and can act for anybody; the string must not occur anywhere
//      under src/.
//   2. Exactly one identity header per request. Two would let the server pick.
//   3. Only three endpoints are ever called, and only the read-shaped tools —
//      nothing that sends a message, mints an invoice or spends money.
//   4. A credential never travels in a URL, a hash or a query string, and no
//      request carries cookies.

import assert from 'node:assert/strict'
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { join } from 'node:path'

// The module reads window.sessionStorage through a guarded accessor; give it a
// real one so the credential paths are exercised rather than silently skipped.
const bag = new Map()
globalThis.window = {
  sessionStorage: {
    getItem: (k) => (bag.has(k) ? bag.get(k) : null),
    setItem: (k, v) => bag.set(k, String(v)),
    removeItem: (k) => bag.delete(k),
  },
}

const { callTool, credentialKind, forgetCredentials, rememberAgentKey, signInWithWidget, RENDER_BASE, TOOL_ALLOWLIST, CrmError } =
  await import('../src/lib/crmClient.ts')

const ALLOWED_PATHS = new Set([`${RENDER_BASE}/mcp`, `${RENDER_BASE}/api/auth/widget`, `${RENDER_BASE}/api/auth/refresh`])
const IDENTITY_HEADERS = ['authorization', 'x-agent-key', 'x-telegram-init-data', 'x-api-key']

const calls = []
function install(reply) {
  globalThis.fetch = async (url, options = {}) => {
    const headers = Object.fromEntries(Object.entries(options.headers ?? {}).map(([k, v]) => [k.toLowerCase(), v]))
    calls.push({ url: String(url), options, headers })
    assert.ok(ALLOWED_PATHS.has(String(url)), `the console called an endpoint it may not call: ${url}`)
    assert.equal(options.method, 'POST', 'every call is a POST')
    assert.equal(options.credentials, 'omit', 'no cookie may ride along with an origin-* CORS policy')
    const present = IDENTITY_HEADERS.filter((h) => headers[h] !== undefined)
    if (String(url).endsWith('/mcp')) {
      assert.equal(present.length, 1, `exactly one identity header per request, saw ${present.join(', ') || 'none'}`)
      assert.ok(headers['x-api-key'] === undefined, 'the service key must never be sent from a browser')
    }
    assert.ok(!String(url).includes('?') && !String(url).includes('#'), 'no credential or id in the address')
    return reply(String(url), JSON.parse(options.body ?? '{}'), headers)
  }
}

// ── 1. the service key appears nowhere in the sources ────────────────────────
function walk(dir) {
  const out = []
  for (const name of readdirSync(dir)) {
    const path = join(dir, name)
    if (statSync(path).isDirectory()) out.push(...walk(path))
    else if (/\.(ts|tsx|js|jsx)$/.test(name)) out.push(path)
  }
  return out
}
const KEY_HEADER = ['X', 'Api', 'Key'].join('-')
for (const file of walk('src')) {
  const text = readFileSync(file, 'utf8')
  assert.ok(!text.includes(KEY_HEADER), `${file} mentions the service key header; a browser must never hold it`)
}

// ── 2. the allowlist refuses everything that reaches a person ────────────────
for (const forbidden of ['crm_offer', 'crm_deliver_photo', 'crm_ingest_chats', 'tg_send', 'tg_forward', 'feed_publish', 'soul_get']) {
  assert.ok(!TOOL_ALLOWLIST.has(forbidden), `${forbidden} must not be callable from a browser`)
}
for (const allowed of ['whoami', 'crm_leads', 'crm_summary', 'crm_lead_context', 'crm_history', 'crm_waiting', 'crm_touch']) {
  assert.ok(TOOL_ALLOWLIST.has(allowed), `${allowed} is what the console is for`)
}

install(() => {
  throw new Error('a refused tool must never reach the network')
})
rememberAgentKey('test-key')
await assert.rejects(() => callTool('crm_offer', {}), (e) => e instanceof CrmError && e.reason === 'refused')
assert.equal(calls.length, 0, 'a refused tool is refused BEFORE a request is made')

// ── 3. the agent key is the only identity when it is the credential ─────────
install(async () => new Response(JSON.stringify({ jsonrpc: '2.0', id: 1, result: { structuredContent: { telegram_id: '1' } } }), { status: 200 }))
const me = await callTool('whoami')
assert.deepEqual(me, { telegram_id: '1' })
assert.equal(calls.at(-1).headers['x-agent-key'], 'test-key')
assert.equal(calls.at(-1).headers.authorization, undefined)
assert.equal(credentialKind(), 'key')

// ── 4. a widget sign-in becomes a Bearer session, and the key is dropped ────
forgetCredentials()
calls.length = 0
install(async (url) => {
  if (url.endsWith('/api/auth/widget')) {
    return new Response(JSON.stringify({ access_token: 'access-1', refresh_token: 'refresh-1', expires_in: 600, telegram_id: '7' }), { status: 200 })
  }
  return new Response(JSON.stringify({ jsonrpc: '2.0', id: 1, result: { structuredContent: { ok: true } } }), { status: 200 })
})
await signInWithWidget({ id: 7, hash: 'signed' })
assert.equal(credentialKind(), 'session')
await callTool('crm_leads', { limit: 5 })
assert.equal(calls.at(-1).headers.authorization, 'Bearer access-1')
assert.equal(calls.at(-1).headers['x-agent-key'], undefined, 'a session and a key must never travel together')

// ── 5. an expired session refreshes once, then gives up and forgets ─────────
let mcpCalls = 0
install(async (url) => {
  if (url.endsWith('/api/auth/refresh')) {
    return new Response(JSON.stringify({ access_token: 'access-2', refresh_token: 'refresh-2', expires_in: 600 }), { status: 200 })
  }
  mcpCalls += 1
  if (mcpCalls === 1) return new Response(JSON.stringify({ error: 'unauthorized' }), { status: 401 })
  return new Response(JSON.stringify({ jsonrpc: '2.0', id: 1, result: { structuredContent: { ok: true } } }), { status: 200 })
})
await callTool('crm_summary', {})
assert.equal(mcpCalls, 2, 'a 401 is retried exactly once, after a refresh')
assert.equal(calls.at(-1).headers.authorization, 'Bearer access-2')

install(async (url) => {
  if (url.endsWith('/api/auth/refresh')) return new Response('{}', { status: 401 })
  return new Response(JSON.stringify({ jsonrpc: '2.0', error: { code: -32001, message: 'нужна подпись' } }), { status: 200 })
})
await assert.rejects(() => callTool('crm_summary', {}), (e) => e instanceof CrmError && e.reason === 'expired')
assert.equal(credentialKind(), null, 'a rejected identity is forgotten, not retried forever')

// ── 6. the owner-only refusal is recognised as such, not as a network fault ─
rememberAgentKey('someone-elses-key')
install(async () => new Response(JSON.stringify({ jsonrpc: '2.0', error: { code: -32000, message: 'только владелец' } }), { status: 200 }))
await assert.rejects(() => callTool('crm_leads', {}), (e) => e instanceof CrmError && e.reason === 'ownerOnly')

// ── 7. the page itself sends nothing and indexes nothing ───────────────────
const page = readFileSync('src/pages/ClientsConsole.tsx', 'utf8')
assert.ok(page.includes('noindex'), 'the console must ask not to be indexed')
assert.ok(!/dangerouslySetInnerHTML/.test(page), 'third-party words are text nodes, never markup')
for (const sender of ['crm_offer', 'tg_send', 'tokens_invoice']) {
  assert.ok(!page.includes(`'${sender}'`), `${sender} has no place on a page that cannot send`)
}
assert.ok(page.includes('crm-prep-'), 'the only path to a message is the bot, through a start payload')

forgetCredentials()
console.log(`Clients console: PASS (${calls.length} recorded calls, one identity header each, ${TOOL_ALLOWLIST.size} tools allowed)`)
