// The security contract of the Queen's second lane.
//
// The kanban used to show one board: the public task board, the same for
// everybody, signed in or not. It now shows a second lane next to it — the
// clients a signed-in visitor is actually responsible for — and that lane is
// the first thing on this page that is DIFFERENT PER PERSON. Four properties
// keep that from becoming a leak, and not one of them can be seen by reading
// the page:
//
//   1. The lane travels on the game token and nothing else. Exactly one
//      identity header goes out, it is `Authorization`, and it is never
//      `X-Agent-Key` — the console's credential, which names a person with far
//      more authority than a player has. The two credential paths in this app
//      must never meet, and a page that could pick between them at runtime is a
//      page where someone will eventually pick wrong.
//   2. No cookie rides along: the service answers CORS with origin `*`, which
//      is only safe while `credentials:'omit'` is true of every request.
//   3. Identity is the SERVER'S, from the token. The tool takes a `client`
//      argument and the browser never sends it; narrowing is done here, on
//      rows that have already arrived, so the control on the page can only ever
//      hide and never ask.
//   4. Signed out, nothing client-scoped is rendered at all. Not an empty lane,
//      not a locked one, not a count of what is behind it — the markup is the
//      markup the public board has always had.
//
// Everything below runs the REAL modules: the real identity client through the
// real handshake (qa/fixtures/identity-world.mjs), the real board reader, and
// the real page source parsed with the real TypeScript parser. A gate that
// tests a description of the code proves that the description is consistent.

import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import ts from 'typescript'

import { TOKEN, TRAPPED, trapGlobals, fakeWorld, signIn, settleAll } from './fixtures/identity-world.mjs'
import { RENDER_BASE, PLAYER_TOOLS } from '../src/lib/triIdentity.ts'
import { HIVE_BOARD_TOOL, clientsLane, loadHiveBoard, readHiveBoard } from '../src/lib/hiveBoard.ts'

let checks = 0
const A = (cond, message) => {
  checks += 1
  assert.ok(cond, message)
}
const EQ = (actual, expected, message) => {
  checks += 1
  assert.deepEqual(actual, expected, message)
}

// The header this file exists to keep out of the browser's game path. Spelled
// in pieces so that the gate's own source cannot be what a search for it finds.
const AGENT_HEADER = ['X', 'Agent', 'Key'].join('-')

// ── A board as the hive sends one, counts and all ───────────────────────────
//
// Every count here is 999, on purpose. A bee may see their own clients and
// NOTHING about anybody else's — not a list, not a total, not "17 elsewhere",
// which is a leak with a smaller vocabulary rather than a safe summary. So the
// wire counts are absurd, and the gate asserts no 999 survives into anything
// the page can draw.
const BOARD = {
  scope: { role: 'bee', label: 'Пчела · @somebot', bots: ['somebot'] },
  clients: {
    columns: [
      { key: 'new', title: 'Новые', count: 999 },
      { key: 'talking', title: 'Говорим', count: 999 },
      { key: 'client', title: 'Клиенты', count: 999 },
      // A stage this build has never heard of, with the hive's own word for it.
      { key: 'sleeping', title: 'Спят', count: 999 },
    ],
    cards: [
      { id: 'c-1', name: 'Ada', bot: 'somebot', stage: 'talking', paid: false, waiting_for_reply: true, quiet_days: 3, last_touch_at: '2026-09-18T10:00:00Z' },
      { id: 'c-2', name: 'Grace', bot: 'somebot', stage: 'client', paid: true, waiting_for_reply: false, quiet_days: 0, last_touch_at: null },
      { id: 'c-3', name: 'Lin', bot: 'otherbot', stage: 'sleeping', paid: false, waiting_for_reply: false, last_touch_at: null },
    ],
  },
  tasks: { repo: 'gHashTag/trinity', reachable: true, columns: [], cards: [] },
  filter: { available: [{ key: 'somebot', label: '@somebot', count: 999 }, { key: 'otherbot', label: '@otherbot', count: 999 }], applied: null },
  how_to_read: 'Колонки — этапы.',
}

const answer = (payload, status = 200) => ({
  ok: status >= 200 && status < 300,
  status,
  json: async () => payload,
})
const rpc = (payload) => ({ jsonrpc: '2.0', id: 1, result: { structuredContent: payload } })

/** Every fetch a world made after the whoami of its handshake. */
const afterHandshake = (world) => world.log.fetches.filter((call) => JSON.parse(call.init.body ?? '{}').params?.name !== 'whoami')

// ── 1. the wire: one header, one tool, no arguments, no cookies ─────────────
const undoTraps = trapGlobals()
try {
  const world = await signIn(
    fakeWorld({
      whoami: (_url, init) => {
        const body = JSON.parse(init.body ?? '{}')
        return answer(body.params?.name === 'whoami' ? { jsonrpc: '2.0', id: 1, result: { structuredContent: { telegram_id: '144022504', role: 'bee' } } } : rpc(BOARD))
      },
    }),
  )
  const before = world.log.fetches.length
  const got = await loadHiveBoard(world.client)
  await settleAll()

  A(got.ok, 'a signed-in person gets their board')
  const calls = world.log.fetches.slice(before)
  EQ(calls.length, 1, 'one board is one request')
  const [call] = calls
  EQ(call.url, `${RENDER_BASE}/mcp`, 'the board is asked for on /mcp at the render service')
  A(!call.url.includes('?') && !call.url.includes('#'), 'no identity and no id travels in an address')
  EQ(call.init.method, 'POST', 'a tool call is a POST')
  EQ(call.init.credentials, 'omit', 'no cookie may ride along with an origin-* CORS policy')

  const headerNames = Object.keys(call.init.headers ?? {})
  const identity = headerNames.filter((name) => /^(authorization|x-agent-key|x-telegram-init-data|x-api-key)$/i.test(name))
  EQ(identity.length, 1, `exactly one identity header, saw ${identity.join(', ') || 'none'}`)
  EQ(identity[0].toLowerCase(), 'authorization', 'the game token travels as a Bearer and as nothing else')
  A(!headerNames.some((name) => name.toLowerCase() === AGENT_HEADER.toLowerCase()), 'the console credential must never appear on the game path')
  EQ(call.init.headers.Authorization, `Bearer ${TOKEN}`, 'the bearer is the token the game already holds')
  EQ(headerNames.sort(), ['Authorization', 'Content-Type'], 'nothing else identifies, describes or tags the caller')

  const body = JSON.parse(call.init.body)
  EQ(body.method, 'tools/call', 'the board is a tool call')
  EQ(body.params.name, HIVE_BOARD_TOOL, 'and the tool is hive_board')
  EQ(body.params.arguments, {}, 'NO ARGUMENTS: identity is the server\'s, and a filter that re-asks is a filter that can ask for someone else')
  A(!Object.prototype.hasOwnProperty.call(body.params.arguments, 'client'), 'the client argument is never sent from a browser')
  A(!JSON.stringify(body).includes(TOKEN), 'the token is a header, never a value in a body somebody may log')

  // ── 2. what the page may draw: no number the server sent ──────────────────
  const drawn = JSON.stringify(got.board)
  A(!drawn.includes('999'), 'a count of rows that were not sent is a description of other people\'s clients')
  A(!drawn.includes('count'), 'no count field survives the reader at all, so none can be printed by accident')
  EQ(got.board.scope.role, 'bee', 'the scope is read as the hive stated it')
  EQ(got.board.cards.length, 3, 'every card that arrived is kept: a dropped card is a person who vanished from the board of whoever owes them an answer')
  EQ(got.board.cards[1].quietDays, 0, 'zero days quiet is a measurement and is kept')
  EQ(got.board.cards[2].quietDays, null, 'an unmeasured silence is null and never zero')

  // ── 3. narrowing is local, is a subset, and cannot be widened ─────────────
  const all = clientsLane(got.board, null, 'ru')
  const one = clientsLane(got.board, 'somebot', 'ru')
  const invented = clientsLane(got.board, 'a-key-the-hive-never-offered', 'ru')
  EQ(all.shown, 3, 'unnarrowed, the lane shows what arrived')
  EQ(one.shown, 2, 'narrowed, the lane shows a subset of what arrived')
  A(one.shown <= all.shown, 'a narrowing narrows: there is no key that adds a row')
  EQ(invented.narrow, null, 'a key the hive never offered is not a narrowing')
  EQ(invented.shown, all.shown, 'and an unoffered key shows what already arrived, never more')
  EQ(afterHandshake(world).length, 1, 'narrowing three times asked the hive nothing')
  A(all.groups.some((group) => group.column.key === 'sleeping'), 'a stage this build has never met still gets a column')
  EQ(all.groups.find((group) => group.column.key === 'sleeping').column.title, 'Спят', 'an unknown stage keeps the hive\'s own title, which beats a bare key')
  EQ(all.groups.find((group) => group.column.key === 'talking').column.title, 'в разговоре', 'a stage we know is titled in OUR words, the same ones the console uses')
  A(!JSON.stringify(all).includes('999'), 'and no count reaches the lane either')

  // ── 4. the four failures are four different sentences ─────────────────────
  for (const [status, reason] of [[401, 'refused'], [403, 'refused'], [500, 'offline']]) {
    const w = await signIn(fakeWorld({ whoami: (_u, init) => (JSON.parse(init.body ?? '{}').params?.name === 'whoami' ? answer(rpc({ telegram_id: '1', role: 'bee' })) : answer({}, status)) }))
    const out = await loadHiveBoard(w.client)
    EQ(out, { ok: false, reason }, `HTTP ${status} reads as ${reason}`)
  }
  const junk = await signIn(fakeWorld({ whoami: (_u, init) => (JSON.parse(init.body ?? '{}').params?.name === 'whoami' ? answer(rpc({ telegram_id: '1', role: 'bee' })) : answer({ jsonrpc: '2.0', id: 1, result: { content: [{ type: 'text', text: 'not a board' }] } })) }))
  EQ(await loadHiveBoard(junk.client), { ok: false, reason: 'unreadable' }, 'an answer this page cannot read is not an empty board')
  EQ(readHiveBoard({ jsonrpc: '2.0', id: 1, error: { code: -32000, message: 'no' }, result: { structuredContent: BOARD } }), null, 'an error in the envelope is not a board, whatever else is in it')

  // ── 5. SIGNED OUT: nothing is asked, and nothing is drawable ──────────────
  const stranger = fakeWorld()
  stranger.start()
  stranger.load()
  await settleAll()
  const fetchesBefore = stranger.log.fetches.length
  const refusedOut = await loadHiveBoard(stranger.client)
  EQ(refusedOut, { ok: false, reason: 'signed-out' }, 'no token, no board — and the reason is not a refusal')
  EQ(stranger.log.fetches.length, fetchesBefore, 'a signed-out visitor makes NO request for a board that is about a person')
  EQ(clientsLane(null, 'somebot', 'en'), null, 'and with no board there is no lane, not an empty one')
  EQ(clientsLane(null, null, 'ru'), null, 'in either language')

  // ── 6. a tool outside the allowlist is refused before the network ─────────
  const before6 = world.log.fetches.length
  EQ(await world.client.callAsPlayer('crm_history'), { ok: false, reason: 'refused' }, 'a tool the token may not ask for is refused')
  EQ(world.log.fetches.length, before6, 'and refused BEFORE a request is made')
  EQ([...PLAYER_TOOLS], ['hive_board'], 'the game token asks for exactly one tool')
} finally {
  undoTraps()
}
EQ(TRAPPED, [], 'the board path touched no storage, no document and no console')

// ── 7. the module itself holds no credential and no second path ─────────────
const reader = readFileSync('src/lib/hiveBoard.ts', 'utf8')
const transport = readFileSync('src/lib/triIdentity.ts', 'utf8')

// Not named, not even in a comment saying not to use it. The literal's absence
// is a rule with no judgement in it: a search either finds it or it does not,
// and nobody has to decide whether this particular occurrence was harmless.
// Both files, because the one that asks and the one that sends are two places
// the console's credential could be reached for.
for (const [path, text] of [['src/lib/hiveBoard.ts', reader], ['src/lib/triIdentity.ts', transport]]) {
  A(!text.includes(AGENT_HEADER), `${path} names the console credential; the game path must not know it exists`)
  A(!/'include'/.test(text), `${path} may carry no cookie on any path through it`)
}
// The wire above already proved one call went out with cookies omitted; this
// proves the omission is written down rather than defaulted into.
A(/credentials:\s*'omit'/.test(transport), 'the transport omits cookies, in so many words')

A(!/\bfetch\s*\(/.test(reader), 'the reader does not fetch: the token belongs to triIdentity and stays there')
// An import, not a mention: the header explains at length why the console's
// module is a different path, and naming it there is the explanation working.
A(!/^\s*import[^\n]*crmClient/m.test(reader), 'the two credential paths do not meet')
A(!/(localStorage|sessionStorage|document\.cookie|indexedDB)/.test(reader), 'nothing about a person is written down in a browser')
A(!/\bconsole\.\w+\(/.test(reader), 'and nothing about a person is logged')
A(!/\.count\b/.test(reader), 'the reader never reads a count, which is why none can be printed')

// ── 8. the page: everything client-scoped is behind ONE gate ────────────────
//
// Read with the real parser rather than a regular expression, because the
// question is structural: is this markup INSIDE a conditional on the signed-in
// panel, or merely near one? A `{clients && ...}` three lines above an
// unguarded lane would satisfy any text search and leak the lane to everybody.
const pagePath = 'src/pages/Queen.tsx'
const page = readFileSync(pagePath, 'utf8')
const source = ts.createSourceFile(pagePath, page, ts.ScriptTarget.Latest, /* setParentNodes */ true, ts.ScriptKind.TSX)

/** Every JSX opening element whose className mentions `name`. */
function elementsWithClass(name) {
  const found = []
  const visit = (node) => {
    if (ts.isJsxOpeningLikeElement(node)) {
      for (const attribute of node.attributes.properties) {
        if (!ts.isJsxAttribute(attribute) || attribute.name.getText(source) !== 'className') continue
        if (attribute.initializer && attribute.initializer.getText(source).includes(name)) found.push(node)
      }
    }
    ts.forEachChild(node, visit)
  }
  visit(source)
  return found
}

/** Is this node inside `{clients && …}` or `{clients ? … : …}`? */
function guardedByClients(node) {
  for (let at = node.parent; at; at = at.parent) {
    if (!ts.isJsxExpression(at) || !at.expression) continue
    const expression = at.expression
    const test =
      ts.isBinaryExpression(expression) && expression.operatorToken.kind === ts.SyntaxKind.AmpersandAmpersandToken
        ? expression.left
        : ts.isConditionalExpression(expression)
          ? expression.condition
          : null
    if (test && /\bclients\b/.test(test.getText(source))) return true
  }
  return false
}

const lane = elementsWithClass('queen27-clients-lane')
EQ(lane.length, 1, 'the clients lane is drawn in exactly one place')
A(guardedByClients(lane[0]), 'the clients lane is inside a conditional on the signed-in panel')

const heads = elementsWithClass('queen27-lane-head')
A(heads.length > 0, 'the lanes are labelled once there are two of them')
for (const head of heads) A(guardedByClients(head), 'a lane heading is itself client-scoped: one lane needs no label')

// The other half of the same contract, and the half that is easy to lose: the
// PUBLIC board must NOT be behind that gate. A refactor that tidied both lanes
// into one conditional would pass every assertion above and would blank the
// task board for every visitor who is not signed in.
const publicBoard = elementsWithClass('queen27-kanban').filter((node) => !elementsWithClass('queen27-clients-lane').includes(node))
EQ(publicBoard.length, 1, 'there is one public task board')
A(!guardedByClients(publicBoard[0]), 'and it is drawn for everybody, signed in or not, exactly as it was')

A(!page.includes(AGENT_HEADER), 'the page names no credential at all')

console.log(`Hive board contract: PASS (${checks} checks, 1 identity header, 0 counts, 0 requests signed out)`)
