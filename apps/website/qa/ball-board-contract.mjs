// The ALL lane: what may reach the screen from a ball_board answer.
//
// The board is the person's own -- CRM, mail, code work and their AI-browser
// session, by whose move it is (t27 specs/automation/ball-board.t27, host
// render src/agent/ball-board.ts). This gate feeds lib/ballBoard.ts a hostile
// answer and asserts what survives: links only to places this app already
// sends people, spec paths that are spec paths, no key on a browser card, no
// request with arguments, and nothing written down or logged. Pure, no browser.

import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

import { PLAYER_TOOLS } from '../src/lib/triIdentity.ts'
import {
  BALL_BOARD_TOOL,
  BROWSER_VIEW_PATH,
  ballLane,
  loadBallBoard,
  readBallBoard,
  safeLink,
  specPath,
} from '../src/lib/ballBoard.ts'

let checks = 0
const A = (cond, message) => {
  checks += 1
  assert.ok(cond, message)
}
const EQ = (actual, expected, message) => {
  checks += 1
  assert.deepEqual(actual, expected, message)
}

const envelope = (payload) => ({ jsonrpc: '2.0', id: 1, result: { structuredContent: payload } })

// ── 1. the tool is one the player may ask for, and asked with no arguments ──
EQ(BALL_BOARD_TOOL, 'ball_board', 'the tool is ball_board')
A(PLAYER_TOOLS.includes(BALL_BOARD_TOOL), 'and it is on the player allowlist, so it compiles and is not refused')

const calls = []
const caller = (answer) => ({
  async callAsPlayer(tool, args) {
    calls.push({ tool, args })
    return answer
  },
})

// ── 2. links: only https to github.com / t27.ai, or exactly the browser view ─
EQ(safeLink('https://github.com/gHashTag/t27/pull/5375'), 'https://github.com/gHashTag/t27/pull/5375', 'a GitHub link is kept')
EQ(safeLink('https://app.t27.ai/game/specs'), 'https://app.t27.ai/game/specs', 'a t27.ai subdomain is kept')
EQ(safeLink(BROWSER_VIEW_PATH), '/game/browser', 'the app browser view is kept, as the bare path')
for (const hostile of [
  'javascript:alert(1)',
  'http://github.com/x',
  'https://github.com.evil.example/x',
  'https://evilt27.ai/x',
  'https://user:pass@github.com/x',
  '//github.com/x',
  '/game/browser?token=abc',
  '/live/abc',
  'data:text/html,hi',
  42,
  null,
]) {
  EQ(safeLink(hostile), null, `a link that is not ours is dropped, not rewritten: ${String(hostile)}`)
}

// ── 3. spec paths: specs/…/*.t27 and nothing that climbs out ────────────────
EQ(specPath('specs/automation/ball-board.t27'), 'specs/automation/ball-board.t27', 'a spec path is kept')
for (const hostile of ['specs/../../etc/passwd.t27', '/specs/a.t27', 'specs/a.ts', 'https://x/specs/a.t27', 'specs/a b.t27', 7]) {
  EQ(specPath(hostile), null, `not a spec path: ${String(hostile)}`)
}

// ── 4. a hostile answer: what reaches the lane ──────────────────────────────
const HOSTILE = {
  total: 6,
  counts: { ours: 2, due: -1, theirs: 'x', none: 0 },
  unspecced: 1,
  sources: {
    crm: { status: 'ok', cards: 2 },
    mail: { status: 'stale', age_h: 30, cards: 1 },
    browser: { status: 'ok', cards: 1, view_token: 'SECRET' },
    evil: { status: 'ok' },
  },
  clients: [
    {
      key: 'client:arxiv',
      name: 'arXiv',
      ball: 'ours',
      hidden: 0,
      cards: [
        { source: 'mail', ref: 'm1', title: 'Reply', ball: 'ours', days: 2, because: null, link: 'javascript:alert(1)', spec: 'specs/automation/mail-push.t27' },
        { source: 'github', ref: 'gHashTag/t27#1', title: 'PR', ball: 'theirs', days: null, because: 'review asked', link: 'https://github.com/gHashTag/t27/pull/1', spec: '../x.t27' },
        { source: 'nope', ref: 'z', title: 'unknown source', ball: 'ours' },
        { source: 'crm', ref: '', title: 'no ref' },
      ],
    },
    {
      key: 'name:browser',
      name: 'browser',
      ball: 'theirs',
      cards: [
        {
          source: 'browser',
          ref: 'browser:me',
          title: 'browser_open example.com/login',
          ball: 'theirs',
          days: 0,
          because: 'live',
          link: 'https://vibee-browser.example/live/abc?token=SECRET',
          spec: 'specs/automation/browser-sign-in.t27',
          view_token: 'SECRET',
          endpoint: 'wss://SECRET',
        },
      ],
    },
    { key: '', name: 'no key', cards: [{ source: 'crm', ref: 'c', title: 'x' }] },
    'not a client',
  ],
  clients_total: 2,
}

const board = readBallBoard(envelope(HOSTILE))
A(board, 'a board was read')
EQ(board.counts, { ours: 2, due: null, theirs: null, none: 0 }, 'a count that is not a count is null, never zero')
EQ(Object.keys(board.sources).sort(), ['browser', 'crm', 'mail'], 'only known sources are read')
EQ(board.sources.mail, { status: 'stale', cards: 1, ageH: 30 }, 'a source state is status, cards and age only')
EQ(board.clients.map((client) => client.key), ['client:arxiv', 'name:browser'], 'a client with no key or no readable card is dropped')
const cards = board.clients.flatMap((client) => client.cards)
EQ(cards.map((card) => card.ref), ['m1', 'gHashTag/t27#1', 'browser:me'], 'a card with an unknown source or no ref is dropped')
EQ(cards[0].link, null, 'a javascript: link never reaches a card')
EQ(cards[1].spec, null, 'a path that climbs is not a spec')
const browser = cards[2]
EQ(browser.link, null, 'a browser card cannot carry the stream URL, even if the host sent one')
EQ(
  Object.keys(browser).sort(),
  ['ball', 'because', 'days', 'link', 'ref', 'source', 'spec', 'title'],
  'a card is these fields and no others: no token, no endpoint',
)
A(!JSON.stringify(board).includes('SECRET'), 'nothing the host should not have sent survives the reader')

// ── 5. not a board is not an empty board ────────────────────────────────────
EQ(readBallBoard({ jsonrpc: '2.0', id: 1, error: { message: 'no' } }), null, 'an envelope error is not a board')
EQ(readBallBoard(envelope({ total: 0 })), null, 'an answer with no clients list is not a board')
EQ(readBallBoard(envelope({ clients: [] }))?.clients, [], 'an empty clients list IS an empty board')

// ── 6. the lane: search can only hide, null draws nothing ──────────────────
EQ(ballLane(null), null, 'no board, no lane')
const all = ballLane(board)
EQ(all.shown, 3, 'every readable card is drawn')
EQ(all.groups.map((group) => group.ball), ['ours', 'due', 'theirs', 'none'], 'the columns run ours, due, theirs, none')
EQ(all.browser?.ref, 'browser:me', 'the lane knows which card is the browser, so the head can offer to open it')
for (const needle of ['arxiv', 'ARXIV', 'pr', 'zzz', '', '   ', 'x'.repeat(500)]) {
  const lane = ballLane(board, needle)
  const drawn = lane.groups.flatMap((group) => group.cards.map((card) => card.ref))
  A(drawn.every((ref) => cards.some((card) => card.ref === ref)), `search "${needle.slice(0, 12)}" draws a subset of what arrived`)
  EQ(lane.shown, drawn.length, 'and the count is of what is drawn')
}

// ── 7. the request: one tool, no arguments, failures keep their reason ─────
EQ(await loadBallBoard(caller({ ok: true, body: envelope(HOSTILE) })).then((a) => a.ok), true, 'a board loads')
EQ(calls.at(-1), { tool: 'ball_board', args: undefined }, 'asked with no arguments: identity is the token, not the page')
for (const reason of ['signed-out', 'refused', 'offline']) {
  EQ(await loadBallBoard(caller({ ok: false, reason })), { ok: false, reason }, `${reason} stays ${reason}`)
}
EQ(await loadBallBoard(caller({ ok: true, body: { nonsense: true } })), { ok: false, reason: 'unreadable' }, 'nonsense is unreadable, not empty')

// ── 8. the module holds no credential and writes nothing down ──────────────
const reader = readFileSync('src/lib/ballBoard.ts', 'utf8')
A(!/\bfetch\s*\(/.test(reader), 'the reader does not fetch')
A(!/(localStorage|sessionStorage|document\.cookie|indexedDB)/.test(reader), 'nothing is written down in a browser')
A(!/\bconsole\.\w+\(/.test(reader), 'nothing is logged')
A(!/^\s*import[^\n]*crmClient/m.test(reader), 'the console credential path is not imported')
A(!/dangerouslySetInnerHTML/.test(readFileSync('src/pages/Queen.tsx', 'utf8').split('function BallLaneView')[1]?.split('\nfunction ')[0] ?? 'missing'), 'the lane builds no markup from text')

console.log(`Ball board contract: PASS (${checks} checks)`)
