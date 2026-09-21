// The access contract of the clients lane: who sees what, and what a control
// on the page can do about it.
//
// The owner asked for two things in one sentence — "the super-admin sees
// everything, clients see only their own" — and they are answered in two
// different places, which is the whole reason this gate exists separately from
// qa/hive-board-contract.mjs.
//
//   WHO SEES WHAT is the SERVER'S answer and only the server's. A keeper is
//   sent the whole platform, an owner is sent the bots they answer for, a bee
//   is sent nothing. The browser cannot check that and must not try: the rows
//   it never received are the proof, and they are not here to be counted.
//
//   WHAT THE CONTROL CAN DO is this page's answer, and it is the part that can
//   be got wrong here. A filter that narrows to several clients is one keystroke
//   away in design from a filter that ASKS for several clients, and the moment
//   it asks, the set of rows on screen stops being a subset of what the server
//   decided to send. So every assertion below is a variation on one property:
//
//       for every input, the cards drawn are a SUBSET of the cards that arrived
//
//   including inputs that are somebody else's bot name, somebody else's client
//   id, an empty selection, a search for a single letter, and a search for a
//   string nobody typed. A subset cannot be a leak, whatever the control does.
//
// The lane is driven through the REAL module with a REAL signed-in identity
// through the real handshake, because the second property — that narrowing and
// typing ask the hive NOTHING — can only be observed on the wire.

import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import ts from 'typescript'

import { TRAPPED, trapGlobals, fakeWorld, signIn, settleAll } from './fixtures/identity-world.mjs'
import { clientsLane, loadHiveBoard } from '../src/lib/hiveBoard.ts'

let checks = 0
const A = (cond, message) => {
  checks += 1
  assert.ok(cond, message)
}
const EQ = (actual, expected, message) => {
  checks += 1
  assert.deepEqual(actual, expected, message)
}

// ── a keeper's board: three clients, six people, one shared first name ───────
//
// A keeper is the one role that is sent other people's clients, so it is the
// only role on which a filter can do damage. Counts are 999 for the reason the
// sibling gate gives: no number describing rows that did not arrive may reach
// the screen.
const card = (id, name, bot, stage) => ({
  id,
  name,
  bot,
  stage,
  paid: false,
  waiting_for_reply: false,
  quiet_days: 1,
  last_touch_at: null,
})

const KEEPER_BOARD = {
  scope: { role: 'keeper', label: 'Хранитель', bots: ['alpha_bot', 'beta_bot', 'gamma_bot'] },
  clients: {
    columns: [
      { key: 'new', title: 'Новые', count: 999 },
      { key: 'talking', title: 'Говорим', count: 999 },
      { key: 'client', title: 'Клиенты', count: 999 },
    ],
    cards: [
      card('a-1', 'Ada', 'alpha_bot', 'new'),
      card('a-2', 'Alan', 'alpha_bot', 'talking'),
      card('b-1', 'Grace', 'beta_bot', 'talking'),
      card('b-2', 'ADA LOVELACE', 'beta_bot', 'client'),
      card('g-1', 'Lin', 'gamma_bot', 'client'),
      card('g-2', '', 'gamma_bot', 'new'),
    ],
  },
  filter: {
    available: [
      { key: 'alpha_bot', label: '@alpha_bot', count: 999 },
      { key: 'beta_bot', label: '@beta_bot', count: 999 },
      { key: 'gamma_bot', label: '@gamma_bot', count: 999 },
    ],
    applied: null,
  },
  how_to_read: 'Колонки — этапы.',
}

// What a bee is sent: their own, and no option naming anybody else's bot.
const BEE_BOARD = {
  scope: { role: 'bee', label: 'Пчела · @alpha_bot', bots: ['alpha_bot'] },
  clients: { columns: KEEPER_BOARD.clients.columns, cards: [card('a-1', 'Ada', 'alpha_bot', 'new')] },
  filter: { available: [{ key: 'alpha_bot', label: '@alpha_bot', count: 999 }], applied: 'alpha_bot' },
  how_to_read: null,
}

const answer = (payload) => ({ ok: true, status: 200, json: async () => payload })
const rpc = (payload) => ({ jsonrpc: '2.0', id: 1, result: { structuredContent: payload } })
const worldFor = (board, telegramId, role) =>
  fakeWorld({
    whoami: (_url, init) =>
      answer(
        JSON.parse(init.body ?? '{}').params?.name === 'whoami'
          ? rpc({ telegram_id: telegramId, role })
          : rpc(board),
      ),
  })

const ids = (lane) => lane.groups.flatMap((group) => group.cards.map((c) => c.id)).sort()

const undoTraps = trapGlobals()
try {
  const keeper = await signIn(worldFor(KEEPER_BOARD, '144022504', 'keeper'))
  const got = await loadHiveBoard(keeper.client)
  await settleAll()
  A(got.ok, 'a keeper gets a board')
  const board = got.board
  const ARRIVED = board.cards.map((c) => c.id).sort()
  EQ(ARRIVED.length, 6, 'the keeper was sent every row the hive decided to send')

  // ── 1. the super-admin sees everything, by default and by asking ───────────
  const all = clientsLane(board, [], 'ru')
  EQ(ids(all), ARRIVED, 'with nothing chosen the lane shows everything that arrived')
  EQ(all.narrow, [], 'and says so: no key is applied')
  EQ(ids(clientsLane(board, null, 'ru')), ARRIVED, 'a null selection is the same question as an empty one')
  EQ(
    ids(clientsLane(board, ['alpha_bot', 'beta_bot', 'gamma_bot'], 'ru')),
    ARRIVED,
    'choosing every client is choosing all of them, not a different board',
  )

  // ── 2. "или по избранным": several at once, and it is still a subset ───────
  const two = clientsLane(board, ['alpha_bot', 'gamma_bot'], 'ru')
  EQ(ids(two), ['a-1', 'a-2', 'g-1', 'g-2'], 'two chosen clients show the union of their people')
  EQ(two.narrow, ['alpha_bot', 'gamma_bot'], 'and the lane reports back exactly what is being watched')
  EQ(two.shown, 4, 'the count on screen counts what is on screen')
  A(two.shown < all.shown, 'a narrowing narrows')
  const one = clientsLane(board, ['beta_bot'], 'ru')
  EQ(ids(one), ['b-1', 'b-2'], 'one chosen client shows that client and nobody else')
  EQ(ids(clientsLane(board, 'beta_bot', 'ru')), ids(one), 'one key on its own is a list of one, not a list of its letters')
  EQ(
    clientsLane(board, ['beta_bot', 'beta_bot'], 'ru').narrow,
    ['beta_bot'],
    'the same client twice is one client, not a second helping of them',
  )

  // ── 3. a stray key drops alone, and never widens the board ────────────────
  //
  // The dangerous shape is a selection that throws itself away when one member
  // is unrecognised: a key from anywhere at all would then reset a narrowed
  // board back out to the whole platform.
  const strayed = clientsLane(board, ['beta_bot', 'delta_bot_that_does_not_exist'], 'ru')
  EQ(ids(strayed), ids(one), 'an unoffered key is dropped on its own; the offered one beside it still narrows')
  EQ(strayed.narrow, ['beta_bot'], 'and the dropped key is not reported as applied')
  EQ(ids(clientsLane(board, ['delta_bot_that_does_not_exist'], 'ru')), ARRIVED, 'a selection of nothing offered is not a selection')

  // ── 4. the find box: over what is in hand, never a question ───────────────
  EQ(ids(clientsLane(board, [], 'ru', 'ada')), ['a-1', 'b-2'], 'a search matches a name in any case, across clients')
  EQ(ids(clientsLane(board, [], 'ru', '  ADA  ')), ['a-1', 'b-2'], 'and is trimmed and folded before it matches')
  EQ(ids(clientsLane(board, [], 'ru', 'gamma_bot')), ['g-1', 'g-2'], 'a search may name a client as well as a person')
  EQ(ids(clientsLane(board, [], 'ru', 'b-1')), ['b-1'], 'and may be an id, which is how one person is found among thousands')
  EQ(ids(clientsLane(board, [], 'ru', 'nobody-by-that-name')), [], 'a search that matches nothing shows nothing, which is a true statement about the board')
  EQ(clientsLane(board, [], 'ru', 'ADA').search, 'ada', 'the applied search is the folded one')
  EQ(clientsLane(board, [], 'ru', 'x'.repeat(200)).search.length, 64, 'a search is capped before it is compared against every card')

  // ── 5. the two controls compose as an intersection, never a union ─────────
  EQ(
    ids(clientsLane(board, ['alpha_bot'], 'ru', 'ada')),
    ['a-1'],
    'chips and typing narrow together: the search cannot reach a client that is filtered out',
  )
  A(
    ids(clientsLane(board, ['alpha_bot'], 'ru', 'ada')).length <= ids(clientsLane(board, ['alpha_bot'], 'ru')).length,
    'adding a search never adds a row',
  )

  // ── 6. THE PROPERTY: no input produces a row that did not arrive ──────────
  //
  // The assertions above are examples. This is the rule they are examples of,
  // run over every hostile input anybody has thought of — other people's bots,
  // other people's ids, empties, a single letter that matches almost anything,
  // and the shapes that go looking for a query to break out of.
  const HOSTILE = [
    '',
    ' ',
    'a',
    '%',
    '*',
    "' OR 1=1 --",
    '../../etc/passwd',
    'alpha_bot',
    'somebody_elses_bot',
    'a-1',
    'z-9',
    '999',
    'ada',
    'x'.repeat(500),
  ]
  const SELECTIONS = [null, [], ['alpha_bot'], ['alpha_bot', 'beta_bot'], HOSTILE, ['%'], ['*']]
  let probes = 0
  for (const selection of SELECTIONS) {
    for (const search of HOSTILE) {
      const lane = clientsLane(board, selection, 'ru', search)
      const drawn = ids(lane)
      probes += 1
      assert.ok(
        drawn.every((id) => ARRIVED.includes(id)),
        `a control produced a row the hive never sent: ${JSON.stringify({ selection, search })}`,
      )
      assert.ok(drawn.length <= ARRIVED.length, 'and no control may show more rows than arrived')
      assert.ok(
        lane.narrow.every((key) => board.filter.available.some((option) => option.key === key)),
        'nor report a narrowing the hive never offered',
      )
      // Everything but the search the caller typed: `999` is one of the
      // hostile searches above, and a control echoing back what was typed into
      // it is not the hive's count of rows it declined to send.
      const { search: _typed, ...drawable } = lane
      assert.ok(!JSON.stringify(drawable).includes('999'), 'nor smuggle a count of rows that did not arrive')
    }
  }
  checks += 1
  EQ(probes, SELECTIONS.length * HOSTILE.length, 'every combination was actually tried, not skipped by a short loop')

  // ── 7. a bee's own board: the same controls reach nothing further ─────────
  const bee = await signIn(worldFor(BEE_BOARD, '777', 'bee'))
  const beeGot = await loadHiveBoard(bee.client)
  A(beeGot.ok, 'a bee gets a board of their own')
  EQ(beeGot.board.cards.length, 1, "a bee is sent their own people and nobody else's")
  for (const selection of [['beta_bot'], ['gamma_bot'], ['alpha_bot', 'beta_bot'], HOSTILE]) {
    const lane = clientsLane(beeGot.board, selection, 'ru')
    A(
      ids(lane).every((id) => id === 'a-1'),
      'no key names a row into existence: what a bee may not see was never sent to be filtered',
    )
  }
  EQ(
    beeGot.board.filter.applied,
    'alpha_bot',
    "the hive's own narrowing is reported, because a board that is a subset and does not say so reads as the whole of somebody's work",
  )
  EQ(clientsLane(beeGot.board, [], 'ru').applied, 'alpha_bot', 'and it survives into the lane, where the page says it out loud')

  // ── 8. NOTHING IS ASKED: the wire after all of that ───────────────────────
  //
  // The reason the whole design holds. Every narrowing and every keystroke
  // above happened after the board arrived, so the request count must not have
  // moved — and no typed string may appear anywhere in anything that was sent.
  const asked = keeper.log.fetches.filter((call) => JSON.parse(call.init.body ?? '{}').params?.name !== 'whoami')
  EQ(asked.length, 1, 'one board is one request, however many times it was filtered afterwards')
  EQ(JSON.parse(asked[0].init.body).params.arguments, {}, 'and that request names no client: identity is the server\'s')
  const wire = JSON.stringify(keeper.log.fetches)
  for (const typed of ['ada', 'beta_bot', 'delta_bot_that_does_not_exist', "' OR 1=1 --"]) {
    A(!wire.toLowerCase().includes(typed.toLowerCase()), `"${typed}" was typed into a control and must never reach the network`)
  }
} finally {
  undoTraps()
}
EQ(TRAPPED, [], 'filtering wrote nothing down, logged nothing, and read no storage')

// ── 9. the control on the page is the control this file describes ───────────
//
// Parsed, not searched. The question is structural: is the filter inside the
// signed-in conditional, and can it express more than one client at a time? A
// dropdown answers "this one" and cannot answer "these three", so its return
// would silently undo the feature while every assertion above still passed.
const pagePath = 'src/pages/Queen.tsx'
const page = readFileSync(pagePath, 'utf8')
const source = ts.createSourceFile(pagePath, page, ts.ScriptTarget.Latest, true, ts.ScriptKind.TSX)

const attributeOf = (node, name) => {
  for (const attribute of node.attributes.properties) {
    if (ts.isJsxAttribute(attribute) && attribute.name.getText(source) === name) return attribute
  }
  return null
}

function elementsWithClass(name) {
  const found = []
  const visit = (node) => {
    if (ts.isJsxOpeningLikeElement(node)) {
      const className = attributeOf(node, 'className')
      if (className?.initializer?.getText(source).includes(name)) found.push(node)
    }
    ts.forEachChild(node, visit)
  }
  visit(source)
  return found
}

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

const filters = elementsWithClass('queen27-lane-filter')
EQ(filters.length, 1, 'the filter is built in exactly one place')
A(guardedByClients(filters[0]), 'and it is inside the signed-in conditional: a signed-out visitor is offered no way to filter clients, because there are none on their page')

const group = filters[0].parent
const within = []
const collect = (node) => {
  if (ts.isJsxOpeningLikeElement(node)) within.push(node)
  ts.forEachChild(node, collect)
}
collect(group)
const tag = (node) => node.tagName.getText(source)
const pressable = within.filter((node) => attributeOf(node, 'aria-pressed'))
A(pressable.length >= 2, 'the control is made of toggles — at least "all" and one client — so several clients can be watched at once')
A(pressable.every((node) => tag(node) === 'button'), 'and they are buttons, whose pressed state is the state a screen reader reads')
A(!within.some((node) => tag(node) === 'select'), 'no dropdown: a dropdown can answer "this one" and cannot answer "these three"')
const search = within.find((node) => tag(node) === 'input')
A(search, 'a keeper is offered one chip per client on the platform, so there is a find box beside them')
A(attributeOf(search, 'aria-label'), 'and the find box says what it is to somebody who cannot see the row it sits in')

console.log(`Clients filter contract: PASS (${checks} checks, ${7 * 14} hostile combinations, 1 request, 0 filters asked of the hive)`)
