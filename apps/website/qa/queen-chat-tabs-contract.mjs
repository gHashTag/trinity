// THREE TABS: THE CONVERSATION, THE LOG, AND THE AGENTS' NETWORK.
//
// The owner's ask, 2026-09-21: "сделай в чате фильтр с логами в отдельном табе,
// в основном табе диалог с королевой, и третий чат агентная сеть a2a для
// коллаборации агентов".
//
// Two of the three tabs are arithmetic over the feed, and arithmetic is what
// this gate runs. The third is a conversation, and what can be held about it is
// that it is the tab she opens on and the only one carrying an input — which is
// asserted about the bytes that ship.
//
// The reason this gate exists at all is the ceiling on what the A2A tab is
// allowed to claim. Measured against the live swarm on 2026-09-21:
//
//   /queen/public-activity   {id, kind, issue, title, at, state} — no worker,
//                            agent, bee or slot identifier anywhere
//   /a2a 403 · /queen/agents 404 · /queen/a2a 404 · /queen/network 404
//
// A network drawn from that cannot name a single agent. It can name issues,
// because every row carries one, and it can count each message in the direction
// it travelled. An A2A tab that quietly invented names would be the most
// believable false thing on the board, so the honesty is held here rather than
// left to whoever edits the component next.
//
//   node --experimental-strip-types qa/queen-chat-tabs-contract.mjs

import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import {
  a2aNetwork, CHAT_TABS, eventDirection, filterEvents, KIND_ORDER, kindCounts, NO_FILTER,
} from '../src/components/queenChatNetwork.ts'

const at = (iso) => `2026-09-21T${iso}Z`
const ev = (id, kind, issue, title, when, state = null) => ({ id, kind, issue, title, at: at(when), state })

// Shaped like the live window read on 2026-09-21: finished and review rows,
// every one of them carrying an issue, several issues appearing more than once.
const FEED = [
  ev('d-1', 'dispatch', 4395, 'Port tools/corpus_figures.py to a .t27 spec', '10:40:00'),
  ev('p-1', 'progress', 4395, 'Reading the Python source', '10:41:00'),
  ev('f-1', 'finished', 4395, 'Port tools/corpus_figures.py to a .t27 spec', '10:43:23', 'finished'),
  ev('r-1', 'review', 4395, 'Port tools/corpus_figures.py to a .t27 spec', '10:43:30', 'empty'),
  ev('d-2', 'dispatch', 4400, 'Wire the kanban filter to the client lane', '10:44:00'),
  ev('f-2', 'finished', 4400, 'Wire the kanban filter to the client lane', '10:50:00', 'finished'),
  ev('r-2', 'review', 4400, 'Wire the kanban filter to the client lane', '10:51:00', 'accept'),
  ev('f-3', 'finished', 4412, 'Rotate the archive credential', '10:52:00', 'finished'),
  ev('r-3', 'review', 4412, 'Rotate the archive credential', '10:53:00', 'sendBack'),
  ev('e-1', 'error', 4412, 'The worktree volume was full', '10:53:30', null),
  ev('u-1', 'usage', null, 'Daily cap reached on the paid key', '10:54:00', null),
]

// ── 1. The tabs ──────────────────────────────────────────────────────────────
assert.deepEqual([...CHAT_TABS], ['queen', 'logs', 'a2a'])
assert.equal(CHAT_TABS[0], 'queen', 'the conversation is the main tab and the one she opens on')

// ── 2. The filter ────────────────────────────────────────────────────────────
// NOTHING SELECTED IS NO RESTRICTION. The other reading of an empty chip row --
// nothing lit, so nothing shown -- opens the tab on an empty list and tells the
// reader the board is idle. It is not.
assert.equal(filterEvents(FEED, NO_FILTER).length, FEED.length, 'no chip lit keeps every row')
assert.equal(filterEvents(FEED, { kinds: [], text: '' }).length, FEED.length)

// One chip keeps one kind; two chips keep both, rather than nothing.
assert.deepEqual(filterEvents(FEED, { kinds: ['review'], text: '' }).map((e) => e.id), ['r-1', 'r-2', 'r-3'])
assert.deepEqual(
  filterEvents(FEED, { kinds: ['error', 'usage'], text: '' }).map((e) => e.id),
  ['e-1', 'u-1'],
  'chips are a union, not an intersection -- an intersection of two kinds is always empty',
)

// A number is a question about an issue. Matching it against titles too would
// answer "4400" with every card that happens to have 4400 in its text.
assert.deepEqual(filterEvents(FEED, { kinds: [], text: '4400' }).map((e) => e.id), ['d-2', 'f-2', 'r-2'])
assert.deepEqual(
  filterEvents(FEED, { kinds: [], text: '#4400' }).map((e) => e.id),
  ['d-2', 'f-2', 'r-2'],
  'the # is how people write an issue and must not change the answer',
)
assert.deepEqual(
  filterEvents(FEED, { kinds: [], text: '44' }).map((e) => e.issue),
  [4400, 4400, 4400, 4412, 4412, 4412],
  'a partial number narrows as it is typed',
)
assert.equal(filterEvents(FEED, { kinds: [], text: '9999' }).length, 0)

// Words match the title, the kind and the state -- the three things a row says.
assert.deepEqual(filterEvents(FEED, { kinds: [], text: 'kanban' }).map((e) => e.id), ['d-2', 'f-2', 'r-2'])
assert.deepEqual(filterEvents(FEED, { kinds: [], text: 'KANBAN' }).map((e) => e.id), ['d-2', 'f-2', 'r-2'], 'case is not a filter')
assert.deepEqual(filterEvents(FEED, { kinds: [], text: 'sendback' }).map((e) => e.id), ['r-3'], 'the state is searchable: it is the word people remember')
assert.deepEqual(filterEvents(FEED, { kinds: [], text: '  kanban  ' }).map((e) => e.id), ['d-2', 'f-2', 'r-2'], 'surrounding space is not a term')

// Both halves at once, and neither one alone.
assert.deepEqual(filterEvents(FEED, { kinds: ['review'], text: '4412' }).map((e) => e.id), ['r-3'])

// The counts are of the WHOLE window. A chip counted after its own filter reads
// 0 for every kind currently hidden, so pressing it looks like it would add
// nothing and nobody presses it.
const counts = kindCounts(FEED)
assert.deepEqual(
  counts,
  [
    { kind: 'dispatch', count: 2 },
    { kind: 'progress', count: 1 },
    { kind: 'usage', count: 1 },
    { kind: 'review', count: 3 },
    { kind: 'finished', count: 3 },
    { kind: 'error', count: 1 },
  ],
  'present kinds only, in the fixed order, counted over everything',
)
assert.equal(counts.reduce((n, c) => n + c.count, 0), FEED.length, 'every row is under exactly one chip')
// Fixed order, so a chip does not move out from under a thumb as counts change.
const order = counts.map((c) => KIND_ORDER.indexOf(c.kind))
assert.deepEqual([...order].sort((a, b) => a - b), order, 'chips keep KIND_ORDER regardless of how many of each arrived')
assert.deepEqual(kindCounts([]), [], 'an empty window has no chips, not eight zeroes')

// A kind this file has never heard of still gets a chip. Dropping it would hide
// its rows behind a filter that does not admit they exist.
const strange = kindCounts([...FEED, ev('x-1', 'handshake', 77, 'something new on the wire', '10:55:00')])
assert.ok(strange.some((c) => c.kind === 'handshake' && c.count === 1), 'an unknown kind is still offered')
assert.equal(strange[strange.length - 1].kind, 'handshake', 'and it goes at the end rather than in the middle of the known ones')

// ── 3. Who is speaking ───────────────────────────────────────────────────────
// She dispatches work and returns a verdict on it. Everything else on this wire
// is a worker reporting back.
for (const kind of ['dispatch', 'review']) assert.equal(eventDirection(kind), 'to-worker', `${kind} is the Queen speaking`)
for (const kind of ['progress', 'tool', 'result', 'usage', 'error', 'finished']) {
  assert.equal(eventDirection(kind), 'to-queen', `${kind} is a worker reporting`)
}
assert.equal(KIND_ORDER.length, 8, 'every kind the feed declares has a direction and a chip')
for (const kind of KIND_ORDER) assert.match(eventDirection(kind), /^to-(queen|worker)$/)

// ── 4. The network ───────────────────────────────────────────────────────────
const net = a2aNetwork(FEED)

assert.equal(net.messages, FEED.length, 'nothing is dropped from the total')
assert.equal(net.toWorker + net.toQueen, FEED.length, 'every message travelled in one of the two directions')
assert.equal(net.toWorker, 5, 'two dispatches and three reviews')
assert.equal(net.toQueen, 6)

// A row with no issue belongs to no link -- and is COUNTED, not quietly
// dropped. A panel that silently loses rows is a panel that has been lying
// about a total ever since.
assert.equal(net.unattributed, 1)
assert.deepEqual(net.links.map((l) => l.issue).sort((a, b) => a - b), [4395, 4400, 4412])

const byIssue = Object.fromEntries(net.links.map((l) => [l.issue, l]))
assert.equal(byIssue[4395].messages, 4)
assert.equal(byIssue[4395].toWorker, 2, 'the dispatch and the review')
assert.equal(byIssue[4395].toQueen, 2, 'the progress and the finished')
assert.equal(byIssue[4395].toWorker + byIssue[4395].toQueen, byIssue[4395].messages)
assert.equal(byIssue[4412].title, 'Rotate the archive credential', 'the link carries the work, not the last error line')

// Newest first: the tab is read by looking, not by following.
assert.deepEqual(net.links.map((l) => l.issue), [4412, 4400, 4395])

// WHOSE TURN IT IS, and the one thing the wire actually settles.
assert.equal(byIssue[4400].stance, 'accepted', 'an accepted review is the message that closes a loop')
assert.equal(byIssue[4412].stance, 'with-queen', 'an error is the last word here, and the ball is hers')
assert.equal(byIssue[4395].stance, 'with-worker', 'her review was the last word, so the work is back with a worker')

// A send-back is not an accept. This is the distinction the whole stance is
// for: 148 of 153 send-backs in this swarm were finished work returned, and a
// panel that read them as done would show a board of finished issues that are
// still running.
const sentBack = a2aNetwork([
  ev('d', 'dispatch', 9, 'x', '10:00:00'),
  ev('f', 'finished', 9, 'x', '10:01:00', 'finished'),
  ev('r', 'review', 9, 'x', '10:02:00', 'sendBack'),
])
assert.equal(sentBack.links[0].stance, 'with-worker', 'sent back is live again, never settled')

// "Last" is the latest timestamp, not the last row read: the feed is not
// promised in order, and read as arrival order an accepted issue looked live
// whenever two rows shared a second.
const jumbled = a2aNetwork([
  ev('r', 'review', 9, 'x', '10:02:00', 'accept'),
  ev('f', 'finished', 9, 'x', '10:01:00', 'finished'),
])
assert.equal(jumbled.links[0].last.id, 'r')
assert.equal(jumbled.links[0].stance, 'accepted')

// Empty is empty, not a shape with zeroes pretending to be a swarm.
assert.deepEqual(a2aNetwork([]), { links: [], unattributed: 0, messages: 0, toQueen: 0, toWorker: 0 })

// ── 5. The panel, in the bytes that ship ─────────────────────────────────────
const panel = readFileSync(new URL('../src/components/QueenChat.tsx', import.meta.url), 'utf8')

// The conversation is the main tab and the only one you can type into. Putting
// the input under every tab would make the log a place to talk from, which is
// what having three tabs was meant to stop.
assert.match(panel, /useState<ChatTab>\('queen'\)/, 'the panel opens on the conversation')
assert.match(panel, /\{tab === 'queen' && \(signedIn \? \(/, 'the input belongs to the conversation tab')
assert.match(panel, /\{tab === 'queen' && \(\s*<p className="queen-chat-context"/, 'so does the line saying what she is looking at')

// Either derived tab hands its row to the conversation: setting the subject and
// staying put would leave the answer on a tab with no way to ask for it.
assert.match(panel, /const ask = useCallback\(\(event: HudEvent\) => \{ setSubject\(event\); setTab\('queen'\) \}/, '"Ask about this" returns to the conversation with the subject set')

// The tabs are a tablist, not three buttons that look like one.
assert.match(panel, /role="tablist"/)
assert.match(panel, /role="tab"\n/)
assert.match(panel, /aria-selected=\{tab === name\}/)
assert.match(panel, /role="tabpanel"/)
assert.match(panel, /aria-controls=\{`queen-chat-panel-\$\{name\}`\}/)

// THE A2A TAB MAY NOT INVENT AN AGENT. There is no name on the wire to draw, so
// the note that says so ships beside the list, in both languages.
assert.match(panel, /netNote: 'The feed carries an issue on every row and no worker name anywhere/)
assert.match(panel, /\/a2a answers 403, \/queen\/agents 404 \(measured 2026-09-21\)/)
// In both dictionaries. A claim made only in English is a claim half the
// readers of this board never see, and the Russian tab would then be the one
// that quietly implies the agents have names.
const ru = panel.slice(panel.indexOf('  ru: {'), panel.indexOf('} as const'))
assert.match(ru, /netNote:/, 'the Russian dictionary carries the note too')
assert.match(ru, /\/a2a отвечает 403, \/queen\/agents — 404 \(измерено 2026-09-21\)/, 'with the same measurement, not a softer sentence')
// The busy figure is the swarm's own and is never derived from the feed.
assert.match(panel, /workers\?: \{ capacity: number; active: number; idle: number \} \| null/)
assert.match(panel, /netScope/, 'and the panel says the two numbers count different things')

const page = readFileSync(new URL('../src/pages/Queen.tsx', import.meta.url), 'utf8')
assert.match(page, /workers=\{data\?\.workers \?\? workers\}/, 'the live slot counts reach the panel')

// ── 6. The layout that the third tab broke ───────────────────────────────────
const css = readFileSync(new URL('../src/components/QueenChat.css', import.meta.url), 'utf8')
const panelRule = css.slice(css.indexOf('.queen-chat {'), css.indexOf('}', css.indexOf('.queen-chat {')))
assert.match(panelRule, /flex-direction: column/, 'a column, so the growing row is the body on every tab')
assert.doesNotMatch(
  panelRule,
  /grid-template-rows/,
  'named rows put the 1fr on whichever child came third, and each tab has a different third child',
)
assert.match(css, /\.queen-chat-body \{[^}]*flex: 1 1 auto/s, 'the body is the one part that grows')
assert.match(css, /\.queen-chat-body \{[^}]*min-height: 0/s, 'and it may shrink, or its scroller never scrolls')
assert.match(css, /\.queen-chat-chips \{[^}]*overflow-x: auto/s, 'eight chips hold one line rather than wrapping onto four')
assert.match(css, /\.queen-chat-net \{[^}]*overflow-y: auto/s)
assert.match(css, /\.queen-chat-signin \{[^}]*min-height: 44px/s, 'unchanged: the sign-in row still holds the input\'s height band')

// A scroll owner nobody declared is content the reader cannot reach, and the
// viewport gate is where this board declares them.
const viewport = readFileSync(new URL('./queen-viewport-contract.mjs', import.meta.url), 'utf8')
for (const owner of ['.queen-chat-log', '.queen-chat-net', '.queen-chat-chips']) {
  assert.ok(viewport.includes(`'${owner}'`), `${owner} must be declared as a scroll owner`)
}

console.log(
  `queen-chat-tabs: 3 tabs (conversation first), ${counts.length} filter chips counted over the whole window, ` +
    `${net.links.length} links from ${net.messages} messages (${net.toWorker} down, ${net.toQueen} up, ${net.unattributed} with no issue), ` +
    `0 agent names invented`,
)
