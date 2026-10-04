// MY RUNNERS: the cabinet that mints runner tokens for the person signed in.
//
// Calls the decisions in src/lib/queenRunners.ts with real inputs and a fetch
// that records what it was asked. Each rule below is one a wrong edit would
// break quietly: a session token sent with cookies or an extra header, a
// runner token kept past the one answer that carries it, a provider key field
// slipping into a page that promises it has none.
//
//   node --experimental-strip-types qa/queen-runners-contract.mjs

import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import {
  CABINET_HOME,
  CABINET_PATH,
  RUNNER_TOKEN,
  cabinetOf,
  callRunners,
  runnerOf,
  RUNNER_SCRIPT_URL,
  setupLines,
} from '../src/lib/queenRunners.ts'

const BASE = 'https://queen.invalid/'
const TOKEN = `qr_${'A'.repeat(43)}`
const RUNNER = {
  id: 3,
  label: 'laptop',
  lane: 100000003,
  tokenHint: 'AAAA',
  createdAt: '2026-10-01T00:00:00Z',
  lastSeenAt: null,
  state: 'never-seen',
}

/** A fetch that answers from a script and records every request. */
function recorder(script) {
  const asked = []
  const fetch = async (url, init) => {
    asked.push({ url, ...init })
    const next = script.shift()
    assert.ok(next, `unexpected request ${init.method} ${url}`)
    return { ok: next.status >= 200 && next.status < 300, status: next.status, json: async () => next.body ?? {} }
  }
  return { asked, fetch }
}

const env = (fetch, token = 'session-token') => ({ base: BASE, fetch, token: () => token })

// 1. Nobody signed in: no request at all.
{
  const { asked, fetch } = recorder([])
  assert.deepEqual(await callRunners(env(fetch, null), { kind: 'list' }), { state: 'signin' })
  assert.equal(asked.length, 0)
}

// 2. Every request: credentials omitted, exactly two headers, bearer is the session.
{
  const { asked, fetch } = recorder([{ status: 200, body: { runners: [RUNNER], limit: 5 } }])
  const view = await callRunners(env(fetch), { kind: 'list' })
  assert.equal(view.state, 'ready')
  assert.equal(view.cabinet.runners[0].label, 'laptop')
  const [req] = asked
  assert.equal(req.url, `https://queen.invalid${CABINET_PATH}`)
  assert.equal(req.credentials, 'omit')
  assert.deepEqual(Object.keys(req.headers).sort(), ['Authorization', 'Content-Type'])
  assert.equal(req.headers.Authorization, 'Bearer session-token')
}

// 3. A refused session is "sign in", a server failure is "unavailable".
{
  const a = recorder([{ status: 401 }])
  assert.deepEqual(await callRunners(env(a.fetch), { kind: 'list' }), { state: 'signin' })
  const b = recorder([{ status: 503 }])
  assert.deepEqual(await callRunners(env(b.fetch), { kind: 'list' }), { state: 'unavailable' })
}

// 3b. A Queen without the cabinet yet answers its path 404. That is "not here
//     yet", not "she did not answer": the panel must not report an outage for
//     a server that is up, and it must not offer a create form it cannot serve.
{
  const a = recorder([{ status: 404 }])
  assert.deepEqual(await callRunners(env(a.fetch), { kind: 'list' }), { state: 'pending' })
  const b = recorder([{ status: 404 }])
  assert.deepEqual(
    await callRunners(env(b.fetch), { kind: 'create', label: 'laptop' }, { runners: [], limit: 5 }),
    { state: 'pending' },
  )
  const page = readFileSync(new URL('../src/components/QueenRunners.tsx', import.meta.url), 'utf8')
  assert.ok(page.includes("view?.state === 'pending'"), 'the panel renders the pending state')
}

// 4. Create: the token is shown once, only in `minted`, and only when it is a
//    runner token as minted; the list is re-read after.
{
  const { asked, fetch } = recorder([
    { status: 201, body: { runner: RUNNER, token: TOKEN } },
    { status: 200, body: { runners: [RUNNER], limit: 5 } },
  ])
  const view = await callRunners(env(fetch), { kind: 'create', label: '  my   laptop ' })
  assert.equal(view.state, 'minted')
  assert.equal(view.token, TOKEN)
  assert.equal(JSON.parse(asked[0].body).label, 'my laptop')
  assert.equal(asked[1].method, 'GET')

  const bad = recorder([{ status: 201, body: { runner: RUNNER, token: 'sk-live-something' } }])
  assert.deepEqual(await callRunners(env(bad.fetch), { kind: 'create', label: 'x' }), { state: 'unavailable' })
}

// 5. Refusals keep the list on screen and send nothing when there is no name.
{
  const kept = { runners: [runnerOf(RUNNER)], limit: 5 }
  const empty = recorder([])
  const noName = await callRunners(env(empty.fetch), { kind: 'create', label: '   ' }, kept)
  assert.deepEqual(noName, { state: 'refused', cabinet: kept, reason: 'label' })
  assert.equal(empty.asked.length, 0)
  const full = recorder([{ status: 409 }])
  const limit = await callRunners(env(full.fetch), { kind: 'create', label: 'one more' }, kept)
  assert.deepEqual(limit, { state: 'refused', cabinet: kept, reason: 'limit' })
}

// 6. Revoke: DELETE by id, then the list; a nonsense id never reaches the wire.
{
  const { asked, fetch } = recorder([{ status: 204 }, { status: 200, body: { runners: [], limit: 5 } }])
  const view = await callRunners(env(fetch), { kind: 'revoke', id: 3 })
  assert.equal(view.state, 'ready')
  assert.equal(asked[0].method, 'DELETE')
  assert.equal(asked[0].url, `https://queen.invalid${CABINET_PATH}/3`)
  const n = recorder([{ status: 200, body: { runners: [], limit: 5 } }])
  await callRunners(env(n.fetch), { kind: 'revoke', id: -1 })
  assert.equal(n.asked.length, 1)
  assert.equal(n.asked[0].method, 'GET')
}

// 7. The wire is data: malformed runners are dropped, labels are capped.
{
  assert.equal(runnerOf({ ...RUNNER, state: 'pwned' }), null)
  assert.equal(runnerOf({ ...RUNNER, tokenHint: '<img>' }), null)
  assert.equal(runnerOf({ ...RUNNER, label: 'x'.repeat(200) }).label.length, 40)
  assert.deepEqual(cabinetOf({ runners: [RUNNER, null, 7], limit: 'x' }).runners.length, 1)
  assert.equal(cabinetOf(null).limit, 5)
  assert.ok(RUNNER_TOKEN.test(TOKEN))
}

// 8. The setup lines name the provider key nowhere; they carry the runner
//    token and the Queen's address and nothing else.
{
  const lines = setupLines(TOKEN, 'https://queen.invalid').join('\n')
  assert.ok(lines.includes(TOKEN))
  // A provider KEY, in any spelling. Not the bare word: the production branch
  // the script is downloaded from is named fix/queen-worker-provider-and-...
  const providerKey = /API_KEY|\bsk-|provider[_ -]?key/i
  assert.ok(!providerKey.test(lines))
  // ...and the narrower pattern still catches what it is for.
  for (const leak of ['export ANTHROPIC_API_KEY=x', 'sk-abc', 'PROVIDER_KEY=x', 'your provider key']) {
    assert.ok(providerKey.test(leak), leak)
  }
  // ...and they run the runner, which pushes to the person's own public fork.
  assert.ok(lines.includes('TRIOS_RUNNER_REMOTE=https://github.com/'))
  assert.ok(lines.includes('node queen-runner.mjs'))
  // The production branch, the one the deployed Queen is built from.
  assert.ok(
    RUNNER_SCRIPT_URL.startsWith(
      'https://raw.githubusercontent.com/gHashTag/BrowserOS/fix/queen-worker-provider-and-prompt-size/',
    ),
  )
  assert.ok(RUNNER_SCRIPT_URL.endsWith('/queen-runner.mjs'))
  assert.ok(CABINET_HOME.startsWith('https://app.t27.ai/queen/'))
}

// 9. The page has no field for a provider key and never stores the token.
{
  const page = readFileSync(new URL('../src/components/QueenRunners.tsx', import.meta.url), 'utf8')
  const lib = readFileSync(new URL('../src/lib/queenRunners.ts', import.meta.url), 'utf8')
  for (const forbidden of ['localStorage', 'sessionStorage', 'document.cookie', 'type="password"', 'apiKey', 'api_key']) {
    assert.ok(!page.includes(forbidden) && !lib.includes(forbidden), `runners cabinet must not use ${forbidden}`)
  }
  assert.ok(!lib.includes("credentials: 'include'"))
}

console.log('queen-runners contract: ok')
