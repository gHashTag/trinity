// ONLY REGISTERED PEOPLE WRITE TO THE QUEEN.
//
// The owner's rule, given 2026-09-20. Until it was written, POST /chat on the
// proxy answered anybody who could reach it: the only thing in front of it was
// the CORS allowlist, and an Origin header is a string the caller types, not a
// credential. This repository has already paid for that confusion once -- the
// note that an extension Origin was "a password anyone could type".
//
// The rule has two halves and this gate holds both, because either one alone is
// a story rather than a rule:
//
//   the proxy     refuses a question from a caller it cannot identify, and its
//                 refusal distinguishes "you are not signed in" from "we could
//                 not check" -- those send the person to two different places
//   the website   knows before it asks, so a signed-out visitor reads a
//                 sentence with a link instead of typing into a box that was
//                 always going to be refused
//
// Both halves are exercised here rather than read for reassuring lines: the
// decision table runs, the verifier runs against a fake network, and the parts
// that can only be asserted about source -- that /chat calls the gate before it
// calls the model, that the preflight admits the header the gate needs -- are
// asserted about the bytes that ship.
//
//   node --experimental-strip-types qa/queen-chat-gate-contract.mjs

import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { bearerFrom, callerVerdict, verifyCaller, VERIFIER_URL } from '../../queen-proxy/caller.mjs'
import { queenCaller } from '../src/services/queenModel.ts'
import { sendMessage, NotSignedIn } from '../src/services/chatApi.ts'

const GOOD = 'aaa.bbb.ccc' // three segments; the shape, never a real token

// ── 1. The proxy's decision, in every shape the verifier can answer in ───────
// The rows that matter are the refusals. A gate is judged by what it turns
// away, and the two kinds of refusal are not interchangeable.
const rows = [
  { name: 'no header at all', in: { token: '', status: 0 }, status: 401 },
  { name: 'not a token', in: { token: 'hello', status: 0 }, status: 401 },
  { name: 'two segments', in: { token: 'aaa.bbb', status: 0 }, status: 401 },
  { name: 'verified', in: { token: GOOD, status: 200 }, status: 200, ok: true },
  { name: 'verified, error in the envelope', in: { token: GOOD, status: 200, body: { error: { code: -32000 } } }, status: 401 },
  { name: 'expired or revoked', in: { token: GOOD, status: 401 }, status: 401 },
  { name: 'forbidden', in: { token: GOOD, status: 403 }, status: 401 },
  { name: 'verifier broken', in: { token: GOOD, status: 500 }, status: 503 },
  { name: 'verifier unreachable', in: { token: GOOD, status: 0 }, status: 503 },
]
for (const row of rows) {
  const verdict = callerVerdict(row.in)
  assert.equal(verdict.status, row.status, `${row.name}: expected ${row.status}, got ${verdict.status}`)
  assert.equal(verdict.ok === true, row.ok === true, `${row.name}: ok should be ${row.ok === true}`)
  if (!verdict.ok) assert.ok(verdict.error?.trim(), `${row.name}: a refusal has to say something`)
}

// The 503 is not a 401 wearing a different number: it has to read as "we could
// not check", or a person who is signed in is told to sign in again and does it
// for ever while the verifier is down.
const unreachable = callerVerdict({ token: GOOD, status: 0 })
assert.match(unreachable.error, /not a refusal/i, 'the 503 must say it is not a refusal')
assert.doesNotMatch(unreachable.error, /sign in$/i, 'the 503 must not end by telling a signed-in person to sign in')

// ── 2. The header, spelled every way a caller may spell it ───────────────────
assert.equal(bearerFrom(`Bearer ${GOOD}`), GOOD)
assert.equal(bearerFrom(`bearer ${GOOD}`), GOOD, 'RFC 7235 makes the scheme case-insensitive; a capital letter is not a credential')
assert.equal(bearerFrom(`  BEARER   ${GOOD}  `), GOOD)
assert.equal(bearerFrom(GOOD), '', 'a bare token is not an Authorization header')
assert.equal(bearerFrom(`Basic ${GOOD}`), '', 'another scheme is not this one')
assert.equal(bearerFrom(undefined), '')
assert.equal(bearerFrom(null), '')

// ── 3. The verifier call itself, against a fake network ──────────────────────
// No token and junk never leave the process: the answer is the same either way,
// and a gate that forwards every guess is a gate that helps somebody guess.
let calls = 0
const counting = async () => { calls += 1; return new Response('{}', { status: 200 }) }
assert.equal((await verifyCaller('', counting)).status, 401)
assert.equal((await verifyCaller('Bearer nonsense', counting)).status, 401)
assert.equal(calls, 0, 'a caller with no usable token must not reach the verifier')

// The token is carried in the header, to the service that holds the signing
// key, and nothing else about the caller is sent.
let seen = null
const capturing = async (url, init) => {
  seen = { url, init }
  return new Response(JSON.stringify({ jsonrpc: '2.0', id: 1, result: { content: [] } }), { status: 200 })
}
const good = await verifyCaller(`Bearer ${GOOD}`, capturing)
assert.equal(good.ok, true, 'a verified session is let through')
assert.equal(seen.init.headers.Authorization, `Bearer ${GOOD}`)
assert.equal(seen.init.method, 'POST')
assert.match(seen.url, /^https:\/\//, 'the verifier is reached over TLS')
assert.equal(seen.url, VERIFIER_URL)
const probe = JSON.parse(seen.init.body)
assert.equal(probe.params.name, 'whoami', 'the cheapest question that requires a session')

// Fails closed: a verifier that throws refuses, and says which kind of refusal.
const broken = await verifyCaller(`Bearer ${GOOD}`, async () => { throw new Error('ECONNREFUSED') })
assert.equal(broken.ok, false)
assert.equal(broken.status, 503, 'an unreachable verifier refuses -- it never opens the gate')

// THE SIGNING KEY IS NOT IN THIS SERVICE AND MUST NOT ARRIVE.
// One verifier, one place (apps/vibee-editor/render/session.ts in
// gHashTag/999-multibots-telegraf). A second implementation here would be a
// second set of rules about expiry and revocation, agreeing right up until one
// of them is edited.
const proxySource = readFileSync(new URL('../../queen-proxy/caller.mjs', import.meta.url), 'utf8')
assert.doesNotMatch(proxySource, /createHmac|jsonwebtoken|JWT_SECRET|SESSION_SECRET/, 'the proxy must not verify signatures itself')

// ── 4. The proxy asks before it answers ──────────────────────────────────────
const server = readFileSync(new URL('../../queen-proxy/server.mjs', import.meta.url), 'utf8')
const chatRoute = server.slice(server.indexOf("req.url === '/chat'"))
assert.ok(chatRoute, 'the /chat route is still there')
const gateAt = chatRoute.indexOf('verifyCaller')
const askAt = chatRoute.indexOf('await ask(')
assert.ok(gateAt > -1, '/chat must call the gate')
assert.ok(askAt > gateAt, 'the gate must run before the Queen is asked, not after')
assert.match(chatRoute, /if \(!who\.ok\) return json\(res, who\.status/, 'a refusal must end the request')

// The preflight has to admit the header the gate asks for. Without this line
// the browser never sends the token and every signed-in person is refused as if
// they were signed out -- the exact failure that took the chat down on
// 2026-09-20, in a smaller costume.
assert.match(server, /Access-Control-Allow-Headers', 'Content-Type, Authorization'/, 'the preflight must allow Authorization')

// /health stays open on purpose: whether the Queen is up is not a secret, and a
// signed-out visitor still has to tell "she is down" from "you are not signed in".
const healthRoute = server.slice(server.indexOf("req.url === '/health'"), server.indexOf("req.url === '/chat'"))
assert.doesNotMatch(healthRoute, /verifyCaller/, '/health must not require a session')

// ── 5. The website knows before it asks ──────────────────────────────────────
assert.deepEqual(queenCaller({ source: 'bridge' }), { signedIn: false, why: 'elsewhere' })
assert.deepEqual(queenCaller({ source: 'app-session', state: 'signed-out', code: 'no_session' }), { signedIn: false, why: 'no_session' })
assert.deepEqual(queenCaller({ source: 'app-session', state: 'signed-out', code: 'expired' }), { signedIn: false, why: 'expired' })
assert.deepEqual(queenCaller({ source: 'app-session', state: 'signed-out', code: 'no_storage' }), { signedIn: false, why: 'no_storage' })
assert.deepEqual(
  queenCaller({ source: 'app-session', state: 'signed-in', token: GOOD, expiresAt: 2e12 }),
  { signedIn: true, authorization: `Bearer ${GOOD}` },
)

// A question with nobody behind it is refused here, not sent to be refused.
await assert.rejects(() => sendMessage({ message: 'hello' }), NotSignedIn)

// With a caller, the header travels and the body still carries the thread.
const realFetch = globalThis.fetch
let sent = null
globalThis.fetch = async (url, init) => {
  sent = { url, init }
  return new Response(JSON.stringify({ response: 'ok', source: 't', confidence: 0, latency_us: 1 }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })
}
try {
  await sendMessage({ message: 'hello' }, `Bearer ${GOOD}`)
} finally {
  globalThis.fetch = realFetch
}
assert.equal(sent.init.headers.Authorization, `Bearer ${GOOD}`)
assert.match(sent.url, /\/chat$/)
assert.ok(JSON.parse(sent.init.body).conversation_id, 'the thread id still travels')

// ── 6. The panel, and what it is not allowed to hold ─────────────────────────
const panel = readFileSync(new URL('../src/components/QueenChat.tsx', import.meta.url), 'utf8')
assert.match(panel, /signedIn \? \(\s*<ChatInput/, 'the input is shown only to a signed-in caller')
assert.match(panel, /queen-chat-signin/, 'and a sentence with somewhere to go stands in its place')
assert.match(panel, /signInHref\(/, 'which uses the one sign-in address in this bundle, not a second one')
assert.match(panel, /error instanceof NotSignedIn/, 'signed out must not be reported as the Queen failing')
// The component is handed a boolean, never the token: a rule kept by one file
// is a rule; a rule kept by everyone who imports the token is nobody's.
assert.doesNotMatch(panel, /appSessionFromWindow|ACCESS_KEY|sessionStorage\.getItem/, 'the panel must not read the session store')
assert.doesNotMatch(panel, /\.authorization/, 'the panel must never touch the token')

const css = readFileSync(new URL('../src/components/QueenChat.css', import.meta.url), 'utf8')
assert.match(css, /\.queen-chat-signin \{[^}]*min-height: 44px/s, 'the sign-in row holds the same height band as the input, so the panel does not jump')

console.log(
  `queen-chat-gate: ${rows.length} proxy verdicts, ${2} kinds of refusal (401 signed-out, 503 uncheckable), ` +
    `1 verifier and no second one, panel holds a boolean and no token`,
)
