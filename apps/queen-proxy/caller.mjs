// Who may ask the Queen.
//
// Until this file existed, POST /chat answered anybody. The only thing standing
// in front of it was the CORS allowlist, and an Origin header is not a
// credential: it is a string the caller types. This repository has already paid
// for that mistake once, in the note that an extension Origin was "a password
// anyone could type". So the gate is a signed session, checked on the server,
// on every message.
//
// THE SIGNING KEY IS NOT HERE, AND MUST NOT BE COPIED HERE.
//
// The app session is minted and verified by the render service
// (gHashTag/999-multibots-telegraf, apps/vibee-editor/render/session.ts:
// signAccessToken / verifyAppSession). That service owns the secret, the
// algorithm pin, the expiry and the revocation list. A second verifier in this
// process would be a second set of rules that agree right up until one of them
// is edited — and the one that is not edited is the one that keeps letting a
// revoked session in. So this file holds no key and decodes no JWT. It asks the
// service that already answers the question, and believes the answer.
//
// The cost is one round trip per message, against a model call that measured
// 14.5 seconds on 2026-09-20. It is not worth caching: a cache is a window in
// which a session that was revoked still works, bought with time nobody here
// can feel.
//
// The gate FAILS CLOSED. If the verifier cannot be reached, nobody is let
// through — but the refusal says so in its own words and carries 503, because
// "we could not check who you are" and "you are not signed in" send the person
// at the keyboard to two different places.

/** The service that holds the signing key. One verifier, one place. */
export const VERIFIER_URL =
  process.env.QUEEN_SESSION_VERIFY_URL || 'https://vibee-render-production.up.railway.app/mcp'

/**
 * The cheapest question that requires a session. whoami is the same call the
 * website's own identity chip makes (apps/website/src/lib/triIdentity.ts), so
 * the page and the proxy agree about who is signed in rather than each holding
 * an opinion. Measured 2026-09-20: no token and a junk token both answer 401.
 */
const PROBE = {
  jsonrpc: '2.0',
  id: 1,
  method: 'tools/call',
  params: { name: 'whoami', arguments: {} },
}

/** Three dot-separated segments. Anything else never had a signature to check. */
const JWT_SHAPE = /^[\w-]+\.[\w-]+\.[\w-]+$/

/**
 * The token out of an Authorization header, or '' when there is none.
 *
 * Case is not ours to insist on: Node lowercases header names, but the scheme
 * inside the value is the caller's spelling, and RFC 7235 makes it
 * case-insensitive. A gate that refused `bearer x` would be refusing a signed-in
 * person over a capital letter.
 */
export function bearerFrom(header) {
  if (typeof header !== 'string') return ''
  const match = /^\s*bearer\s+(\S+)\s*$/i.exec(header)
  return match ? match[1] : ''
}

/**
 * The decision, with nothing in it that talks to a network.
 *
 * Kept separate from the call so it can be driven by a test in every shape the
 * verifier can answer in — including the ones that are hard to produce on
 * purpose, like a 500 from a service that is up but broken.
 *
 * `status` is the verifier's HTTP status, or 0 when the request never landed.
 */
export function callerVerdict({ token, status, body }) {
  if (!token) return { ok: false, status: 401, error: 'sign in to ask the Queen' }
  if (!JWT_SHAPE.test(token)) return { ok: false, status: 401, error: 'that is not a session token' }
  if (status === 200) {
    // A 200 that carries a JSON-RPC error is a refusal in a success envelope.
    // MCP answers this way for a tool that threw, and a gate that read only the
    // status would let it through.
    if (body && typeof body === 'object' && body.error) {
      return { ok: false, status: 401, error: 'the session was refused' }
    }
    return { ok: true, status: 200 }
  }
  if (status === 401 || status === 403) {
    return { ok: false, status: 401, error: 'the session has expired or was revoked — sign in again' }
  }
  return {
    ok: false,
    status: 503,
    error: `the sign-in service did not answer (${status || 'no reply'}) — this is not a refusal, try again`,
  }
}

/**
 * Ask the verifier about this caller.
 *
 * `fetchImpl` and `url` are arguments rather than imports so the contract test
 * can drive every branch without a network and without a secret.
 */
export async function verifyCaller(header, fetchImpl = fetch, url = VERIFIER_URL) {
  const token = bearerFrom(header)
  // Junk never reaches the verifier: the decision is the same either way, and a
  // gate that forwards every guess is a gate that helps somebody guess. Both of
  // these answer 401 without a status, which is why the call is skipped.
  if (!token || !JWT_SHAPE.test(token)) return callerVerdict({ token, status: 0 })

  let status = 0
  let body = null
  try {
    const res = await fetchImpl(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: JSON.stringify(PROBE),
      signal: AbortSignal.timeout(8000),
    })
    status = res.status
    // The body is read only far enough to see a refusal. whoami answers with
    // the person's name, their avatar and how much they have published; none of
    // that is this service's business, none of it is logged, and none of it is
    // forwarded.
    if (status === 200) {
      try { body = await res.json() } catch { body = null }
    }
  } catch {
    status = 0
  }
  return callerVerdict({ token, status, body })
}
