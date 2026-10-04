// The security contract of the Queen's mail lane.
//
// The kanban's third board is the owner's MAIL, CRM and open work by client,
// with whose move it is (src/lib/ballBoard.ts). It is the most private thing
// this page has ever drawn: somebody's correspondence. Who may see it is the
// render service's decision (gHashTag/t27 specs/automation/ball-grants.t27) --
// the owner, and whoever the owner granted it to. What this gate holds is that
// the page neither widens that decision nor leaks around it:
//
//   1. The wire: one Authorization header, no cookie, the tool `ball_board`,
//      and NO ARGUMENTS -- a page that sends nothing has nothing to widen the
//      server's answer with.
//   2. No number the server sent survives the reader: a count of rows that
//      were not sent is a description of somebody else's mail.
//   3. A board that came without the mail (`not_yours`) is NO lane -- not an
//      empty one, not a locked one. Signed out, nothing is even asked.
//   4. The only link a card may carry is github.com over https.
//   5. On the page, the lane, its heading and its chip are all behind the
//      `ball` panel, and the public task board is still behind nothing.
//
// Real modules, real handshake (qa/fixtures/identity-world.mjs), real parser.

import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import ts from 'typescript'

import { TOKEN, TRAPPED, trapGlobals, fakeWorld, signIn, settleAll } from './fixtures/identity-world.mjs'
import { RENDER_BASE, PLAYER_TOOLS } from '../src/lib/triIdentity.ts'
import { BALL_BOARD_TOOL, BALLS, ballLane, loadBallBoard, readBallBoard, safeLink } from '../src/lib/ballBoard.ts'

let checks = 0
const A = (cond, message) => {
  checks += 1
  assert.ok(cond, message)
}
const EQ = (actual, expected, message) => {
  checks += 1
  assert.deepEqual(actual, expected, message)
}

const AGENT_HEADER = ['X', 'Agent', 'Key'].join('-')

// ── A board as render's ball_board sends one, counts and all (999 each) ─────
const BOARD = {
  total: 999,
  counts: { ours: 999, due: 999, theirs: 999, none: 999 },
  sources: {
    crm: { status: 'ok', cards: 999 },
    mail: { status: 'ok', cards: 999, age_h: 999 },
    github: { status: 'not_yours', cards: 999 },
  },
  clients: [
    {
      key: 'acme',
      name: 'Acme',
      ball: 'ours',
      hidden: 999,
      cards: [
        { source: 'mail', ref: 'Acme hiring', title: 'Acme hiring', ball: 'ours', days: 2, because: 'interview', link: null },
        { source: 'mail', ref: 'Acme old', title: 'Acme old', ball: 'ours', days: 9, because: null, link: 'javascript:alert(1)' },
        { source: 'github', ref: 'o/r#1', title: 'PR', ball: 'theirs', days: 0, because: null, link: 'https://github.com/o/r/pull/1' },
        // A ball this build has never heard of keeps a column of its own.
        { source: 'mail', ref: 'Acme parked', title: 'Acme parked', ball: 'parked', days: null, because: null, link: 'https://evil.example/x' },
      ],
    },
  ],
  clients_total: 999,
}

const answer = (payload, status = 200) => ({ ok: status >= 200 && status < 300, status, json: async () => payload })
const rpc = (payload) => ({ jsonrpc: '2.0', id: 1, result: { structuredContent: payload } })
const toolName = (init) => JSON.parse(init.body ?? '{}').params?.name
const worldWith = (board, status = 200) =>
  fakeWorld({
    whoami: (_u, init) =>
      toolName(init) === 'whoami' ? answer(rpc({ telegram_id: '144022504', role: 'owner' })) : answer(board === null ? {} : rpc(board), status),
  })

const undoTraps = trapGlobals()
try {
  // ── 1. the wire ────────────────────────────────────────────────────────────
  const world = await signIn(worldWith(BOARD))
  const before = world.log.fetches.length
  const got = await loadBallBoard(world.client)
  await settleAll()
  A(got.ok, 'the owner, signed in, gets the board')
  const calls = world.log.fetches.slice(before)
  EQ(calls.length, 1, 'one board is one request')
  const [call] = calls
  EQ(call.url, `${RENDER_BASE}/mcp`, 'asked on /mcp at the render service')
  A(!call.url.includes('?') && !call.url.includes('#'), 'no identity and no id travels in an address')
  EQ(call.init.credentials, 'omit', 'no cookie rides along')
  const headerNames = Object.keys(call.init.headers ?? {})
  EQ(headerNames.sort(), ['Authorization', 'Content-Type'], 'one identity header, and it is Authorization')
  A(!headerNames.some((name) => name.toLowerCase() === AGENT_HEADER.toLowerCase()), 'the console credential never appears')
  EQ(call.init.headers.Authorization, `Bearer ${TOKEN}`, 'the bearer is the session the page already holds')
  const body = JSON.parse(call.init.body)
  EQ(body.params.name, BALL_BOARD_TOOL, 'the tool is ball_board')
  EQ(BALL_BOARD_TOOL, 'ball_board', 'by that name')
  EQ(body.params.arguments, {}, 'NO ARGUMENTS: who sees what is the server\'s, and there is nothing to widen it with')
  A(!JSON.stringify(body).includes(TOKEN), 'the token is a header, never a value in a body')
  A(PLAYER_TOOLS.includes('ball_board'), 'the transport allows the tool')

  // ── 2. no number the server sent, and only safe links ─────────────────────
  const drawn = JSON.stringify(got.board)
  A(!drawn.includes('999'), 'no count the server sent survives the reader')
  EQ(got.board.cards.length, 4, 'every card that arrived is kept')
  EQ(got.board.cards[0].days, 2, 'days are read')
  EQ(got.board.cards[2].days, 0, 'zero days is a measurement and is kept')
  EQ(got.board.cards[3].days, null, 'an unmeasured wait is null, never zero')
  EQ(got.board.cards[1].link, null, 'javascript: is an address too, and it is dropped')
  EQ(got.board.cards[3].link, null, 'a link off github is dropped')
  EQ(got.board.cards[2].link, 'https://github.com/o/r/pull/1', 'a github link over https is kept')
  EQ(safeLink('http://github.com/o/r'), null, 'plain http is dropped')
  EQ(safeLink('https://user:pw@github.com/o/r'), null, 'credentials in a link are dropped')
  EQ(safeLink('https://github.com.evil.example/o'), null, 'a look-alike host is dropped')

  const lane = ballLane(got.board)
  A(lane, 'with the mail sent, there is a lane')
  EQ(lane.shown, 4, 'the lane counts the cards on screen, and only those')
  EQ(lane.groups.map((g) => g.ball), [...BALLS, 'parked'], 'columns in ball order, an unknown ball last but present')
  EQ(lane.groups[0].cards.map((c) => c.ref), ['Acme old', 'Acme hiring'], 'the longest wait first')
  A(!JSON.stringify(lane).includes('999'), 'no count reaches the lane either')

  // ── 3. without the mail there is no lane at all ───────────────────────────
  const refusedMail = { ...BOARD, sources: { ...BOARD.sources, mail: { status: 'not_yours', cards: 0 } }, clients: [] }
  const noGrant = readBallBoard(rpc(refusedMail))
  A(noGrant, 'a viewer with no grant still gets a readable answer')
  EQ(ballLane(noGrant), null, 'but the mail was not theirs, so there is no lane -- not an empty one')
  EQ(ballLane(readBallBoard(rpc({ ...BOARD, sources: {} }))), null, 'a board that does not say it sent the mail draws no lane')
  EQ(ballLane(readBallBoard(rpc({ ...BOARD, sources: { mail: { status: 'something-new' } } }))), null, 'nor does a mail status this build cannot read')
  EQ(ballLane(null), null, 'no board, no lane')
  const empty = ballLane(readBallBoard(rpc({ ...BOARD, sources: { mail: { status: 'empty' } }, clients: [] })))
  EQ(empty?.shown, 0, 'an owner with nothing waiting sees an empty lane, which is a true statement to them')

  EQ(readBallBoard({ jsonrpc: '2.0', id: 1, error: { code: -32000, message: 'no' }, result: { structuredContent: BOARD } }), null, 'an error envelope is not a board')
  EQ(readBallBoard(rpc({ ...BOARD, clients: 'x' })), null, 'clients that are not a list are not a board')

  for (const [status, reason] of [[401, 'refused'], [403, 'refused'], [500, 'offline']]) {
    const w = await signIn(worldWith(null, status))
    EQ(await loadBallBoard(w.client), { ok: false, reason }, `HTTP ${status} reads as ${reason}`)
  }

  // ── 4. signed out: nothing is asked ───────────────────────────────────────
  const stranger = fakeWorld()
  stranger.start()
  stranger.load()
  await settleAll()
  const fetchesBefore = stranger.log.fetches.length
  EQ(await loadBallBoard(stranger.client), { ok: false, reason: 'signed-out' }, 'no session, no board')
  EQ(stranger.log.fetches.length, fetchesBefore, 'a signed-out visitor makes NO request for somebody\'s mail')
} finally {
  undoTraps()
}
EQ(TRAPPED, [], 'the mail path touched no storage, no document and no console')

// ── 5. the module ───────────────────────────────────────────────────────────
const reader = readFileSync('src/lib/ballBoard.ts', 'utf8')
A(!reader.includes(AGENT_HEADER), 'the reader does not name the console credential')
A(!/'include'/.test(reader), 'no cookie on any path through it')
A(!/\bfetch\s*\(/.test(reader), 'the reader does not fetch: the session belongs to triIdentity')
A(!/(localStorage|sessionStorage|document\.cookie|indexedDB)/.test(reader), 'nothing about anybody\'s mail is written down in a browser')
A(!/\bconsole\.\w+\(/.test(reader), 'and nothing is logged')
A(!/\.(counts|total|clients_total|hidden|age_h)\b/.test(reader), 'the reader never reads a count')
A(!/callAsPlayer\([^)]*,/.test(reader), 'the call carries no arguments')

// ── 6. the page: the lane, its heading and its chip are behind `ball` ───────
const pagePath = 'src/pages/Queen.tsx'
const page = readFileSync(pagePath, 'utf8')
const source = ts.createSourceFile(pagePath, page, ts.ScriptTarget.Latest, true, ts.ScriptKind.TSX)

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

/** The leftmost operand of an `&&` chain. */
const leftmost = (expression) => {
  let at = expression
  while (ts.isBinaryExpression(at) && at.operatorToken.kind === ts.SyntaxKind.AmpersandAmpersandToken) at = at.left
  return at
}

/**
 * Inside `{ball && …}`? Strictly: the chain must START with the panel itself.
 * `{board === "ball" && …}` names the word and guards nothing.
 */
function guardedByBall(node) {
  for (let at = node.parent; at; at = at.parent) {
    if (!ts.isJsxExpression(at) || !at.expression) continue
    const first = leftmost(at.expression)
    if (ts.isIdentifier(first) && first.text === 'ball') return true
  }
  return false
}

const lanes = elementsWithClass('queen27-ball-lane')
EQ(lanes.length, 1, 'the mail lane is drawn in exactly one place')
A(guardedByBall(lanes[0]), 'the mail lane is inside {ball && …}')

const heads = elementsWithClass('queen27-lane-head').filter((node) => guardedByBall(node))
EQ(heads.length, 1, 'the mail lane has one heading, and it is behind {ball && …}')

// The chip that opens the lane says what is behind it ("MAIL"); a chip for a
// person the mail was refused to is a statement that there is mail to refuse.
const chips = []
const findChips = (node) => {
  if (ts.isJsxElement(node) && node.children.some((child) => ts.isJsxExpression(child) && child.expression?.getText(source) === 'c.laneBall')) chips.push(node)
  ts.forEachChild(node, findChips)
}
findChips(source)
A(chips.length >= 2, 'the word MAIL appears on the chip and on the heading')
for (const chip of chips) A(guardedByBall(chip.openingElement), 'every place the word MAIL is drawn is behind {ball && …}')

A(!page.includes(AGENT_HEADER), 'the page names no credential')
const links = page.match(/href=\{card\.link\}/g) ?? []
EQ(links.length, 1, 'one link on a mail card, and it is the reader\'s safeLink output')
A(/href=\{card\.link\} target="_blank" rel="noopener noreferrer"/.test(page), 'opened with no opener and no referrer')

console.log(`Ball board contract: PASS (${checks} checks, no arguments, 0 counts, no lane without the mail)`)
