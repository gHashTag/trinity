// The contract of the one task view (gHashTag/t27 specs/queen/tasks.t27, epic
// gHashTag/t27#7718): what the board and the game may do with GET
// /queen/public-tasks, and with the board when that route does not answer.
//
//   1. THE FILTER IS THE SPEC'S. src/lib/queenTasks.ts mirrors task_matches; it
//      is run here against the spec's own test vectors, and a deliberately
//      broken mirror must fail them, so the vectors are known to bite.
//   2. THE WIRE IS CHECKED. A recorded answer of the live route (2026-10-08,
//      trimmed) parses; a row of a kind or state this build has not met is
//      dropped, as the spec says it matches nothing; a body that is not the
//      contract is refused, which is the board's cue to fall back.
//   3. THE FALLBACK SAYS WHAT IT IS. Built from the public board and the
//      activity feed: every card an issue in its column, one bee per running
//      card, working only if heard within BEE_QUIET_SECONDS, `source: "board"`.
//   4. A FILTER CAN ONLY HIDE, and its address round-trips: what the board
//      writes into its address is what a reader opening that link gets.
//   5. THE GAME. A running issue the dated atlas does not hold becomes a cell,
//      joined across the atlas's lower-case spelling; and the ship every bee is
//      drawn as is the vendored Kenney file, read and checked here.
//   6. NO REBUILD PER BEE. The scene's signature carries the presence of live
//      bees, never the bees, and the catalog gives the scene no worker slots.

import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

import {
  BEE_QUIET_SECONDS,
  BEE_STATES,
  TASK_KINDS,
  TASK_PAGE_MAX,
  TASK_STATES,
  beeBadge,
  beeLabel,
  filterTasks,
  kindIndex,
  maskOf,
  observeRunning,
  parseTasksFeed,
  stateIndex,
  taskFilterFromParams,
  taskFilterIsEmpty,
  taskFilterKey,
  taskMatches,
  tasksFromBoard,
  tasksUrl,
  withEarliestSince,
  writeTaskFilter,
} from '../src/lib/queenTasks.ts'
import { readShipGlb, shipTint } from '../src/components/queenShipModel.ts'
import { catalogUniverse, liveIssueRows } from '../src/components/queenCatalogData.ts'

let checks = 0
const A = (cond, message) => {
  checks += 1
  assert.ok(cond, message)
}
const EQ = (actual, expected, message) => {
  checks += 1
  assert.deepEqual(actual, expected, message)
}

// ---- 1. the spec, and its vectors -------------------------------------------
EQ([...TASK_KINDS], ['issue', 'review', 'job'], 'KIND_NAMES in the spec order (TK_ISSUE 0, TK_REVIEW 1, TK_JOB 2)')
EQ([...TASK_STATES], ['backlog', 'blocked', 'running', 'review', 'done', 'dropped', 'failed'], 'STATE_NAMES in the spec order (TS_BACKLOG 0 .. TS_FAILED 6)')
EQ([...BEE_STATES], ['queued', 'working', 'quiet'], 'BEE_STATE_NAMES')
EQ([BEE_QUIET_SECONDS, TASK_PAGE_MAX], [180, 2000], 'BEE_QUIET_SECONDS and TASK_PAGE_MAX')

const K = Object.fromEntries(TASK_KINDS.map((name, i) => [name, i]))
const S = Object.fromEntries(TASK_STATES.map((name, i) => [name, i]))
// specs/queen/tasks.t27, test a_filter_narrows_and_zero_means_any, in its order
const VECTORS = [
  [0, 0, K.issue, S.running, true],
  [1 << K.issue, 0, K.issue, S.done, true],
  [1 << K.job, 0, K.issue, S.done, false],
  [0, 1 << S.running, K.review, S.running, true],
  [0, 1 << S.running, K.review, S.backlog, false],
  [(1 << K.issue) | (1 << K.job), (1 << S.running) | (1 << S.review), K.job, S.review, true],
  [0, 0, TASK_KINDS.length, S.done, false],
  [0, 0, K.issue, TASK_STATES.length, false],
]
const passes = (fn) => VECTORS.every(([km, sm, k, s, want]) => fn(km, sm, k, s) === want)
for (const [km, sm, k, s, want] of VECTORS) EQ(taskMatches(km, sm, k, s), want, `task_matches(${km}, ${sm}, ${k}, ${s}) == ${want}`)
// the vectors bite: three plausible wrong mirrors each fail at least one
A(!passes((km, sm, k, s) => (km & (1 << k)) !== 0 && (sm & (1 << s)) !== 0), 'a mirror that reads a mask of 0 as "none" fails the vectors')
A(!passes((km, sm, k, s) => (km === 0 || (km & (1 << k)) !== 0) && (sm === 0 || (sm & (1 << s)) !== 0)), 'a mirror with no range check fails the vectors')
A(!passes((km, sm, k, s) => k < 3 && s < 7 && (km === 0 || (km & (1 << s)) !== 0) && (sm === 0 || (sm & (1 << k)) !== 0)), 'a mirror with the masks swapped fails the vectors')
// a name this build has not met is out of range, as a u8 past the table is
EQ([kindIndex('epic'), stateIndex('open')], [-1, -1], 'an unknown name has no index')
EQ([taskMatches(0, 0, -1, S.done), taskMatches(0, 0, K.issue, 2.5)], [false, false], 'a negative or fractional index matches nothing')
EQ(maskOf(['issue', 'job', 'nope'], TASK_KINDS), 0b101, 'a mask is the named members; an unknown name adds nothing')

// ---- 2. the wire -------------------------------------------------------------
const recorded = JSON.parse(readFileSync(new URL('./fixtures/queen-public-tasks.json', import.meta.url), 'utf8'))
const feed = parseTasksFeed(recorded)
A(feed !== null, 'the recorded answer of the live route is the contract')
EQ(feed.source, 'tasks', 'a parsed answer says it came from the route')
EQ(feed.tasks.length, recorded.tasks.length, 'every recorded task is kept')
EQ(feed.bees.length, recorded.bees.length, 'every recorded bee is kept')
A(feed.tasks.every((task) => kindIndex(task.kind) >= 0 && stateIndex(task.state) >= 0), 'every kept task has a known kind and state')
A(feed.tasks.some((task) => task.kind === 'review') && feed.tasks.some((task) => task.kind === 'job'), 'the recording carries all three kinds')
A(feed.bees.every((bee) => feed.tasks.some((task) => task.key === bee.task && task.bee === bee.id)), 'each recorded bee names a task that names it back')
A(feed.tasks.every((task) => task.url === null || task.url.startsWith('https://github.com/')), 'a task links to GitHub or to nothing')
const odd = parseTasksFeed({
  ...recorded,
  tasks: [...recorded.tasks, { ...recorded.tasks[0], key: 'x#1', kind: 'epic' }, { ...recorded.tasks[0], key: 'x#2', state: 'open' }, { ...recorded.tasks[0], key: 'x#3', url: 'https://evil.example/x' }],
  bees: [...recorded.bees, { ...recorded.bees[0], id: 'bx', state: 'busy' }],
})
EQ(odd.tasks.length, recorded.tasks.length + 1, 'a task of an unknown kind or state is dropped (it matches nothing)')
EQ(odd.tasks.at(-1).url, null, 'a link off GitHub is not kept')
EQ(odd.bees.length, recorded.bees.length, 'a bee in an unknown state is dropped')
for (const body of [null, [], {}, { tasks: [] }, { tasks: {}, bees: [] }, 'html']) EQ(parseTasksFeed(body), null, `not the contract: ${JSON.stringify(body)}`)
EQ(tasksUrl('https://q', 'all'), 'https://q/queen/public-tasks?limit=2000', 'the board asks for every task, up to the page limit')
EQ(tasksUrl('https://q', 'running'), 'https://q/queen/public-tasks?state=running&limit=2000', 'the game asks for the running ones; the bees come with any filter')

// the route re-stamps `since` on every answer; the page keeps the earliest it was told per bee
{
  const at = (iso) => ({ ...feed, bees: feed.bees.map((bee, i) => (i === 0 ? { ...bee, since: iso } : bee)) })
  const first = at('2026-10-08T08:00:00.000Z'), later = at('2026-10-08T08:05:00.000Z')
  EQ(withEarliestSince(first, later).bees[0].since, '2026-10-08T08:00:00.000Z', 'a later re-stamp does not reset a bee\'s age')
  EQ(withEarliestSince(later, first).bees[0].since, '2026-10-08T08:00:00.000Z', 'an earlier statement is taken as it is')
  EQ(withEarliestSince(null, later), later, 'the first answer is taken as it is')
  EQ(withEarliestSince(first, { ...later, bees: later.bees.slice(1) }).bees.some((bee) => bee.id === feed.bees[0].id), false, 'a bee that left the answer is forgotten, not kept')
  const same = withEarliestSince(first, first)
  A(same === first, 'an answer with nothing to correct is passed through untouched')
}

// ---- 3. the fallback ---------------------------------------------------------
const now = Date.parse('2026-10-08T08:00:00Z')
const iso = (secondsAgo) => new Date(now - secondsAgo * 1000).toISOString()
const board = [
  { number: 7513, title: 'heard a minute ago', column: 'running', criteria: 6 },
  { number: 7514, title: 'silent for four minutes', column: 'running' },
  { number: 7515, title: 'never heard', column: 'running' },
  { number: 7400, title: 'done', column: 'done', verdict: 'accept' },
  { number: 7401, title: 'a column this build has not met', column: 'limbo' },
  { number: -3, title: 'not an issue', column: 'backlog' },
]
const events = [
  { issue: 7513, at: iso(60) },
  { issue: 7514, at: iso(BEE_QUIET_SECONDS + 60) },
  { issue: 7514, at: iso(BEE_QUIET_SECONDS + 1) },
  { issue: null, at: iso(1) },
]
const firstSeen = observeRunning(new Map([[7513, iso(600)], [9999, iso(900)]]), [7513, 7514, 7515], iso(0))
EQ([...firstSeen], [[7513, iso(600)], [7514, iso(0)], [7515, iso(0)]], 'first seen running: kept, added now, and dropped once it stops running')
const derived = tasksFromBoard('gHashTag/t27', board, events, firstSeen, now)
EQ(derived.source, 'board', 'a derived feed says it was derived')
EQ(derived.tasks.map((task) => [task.key, task.kind, task.state]), [
  ['gHashTag/t27#7513', 'issue', 'running'],
  ['gHashTag/t27#7514', 'issue', 'running'],
  ['gHashTag/t27#7515', 'issue', 'running'],
  ['gHashTag/t27#7400', 'issue', 'done'],
], 'every card an issue in its column; a column outside the states and a non-issue number are left out')
EQ(derived.bees.map((bee) => [bee.id, bee.lane, bee.state, bee.since]), [
  ['b7513', null, 'working', iso(600)],
  ['b7514', null, 'quiet', iso(0)],
  ['b7515', null, 'quiet', iso(0)],
], 'one bee per running card, no lane, working only when heard within BEE_QUIET_SECONDS')
EQ(derived.bees[1].lastEventAt, iso(BEE_QUIET_SECONDS + 1), 'the newest event is the one that counts')
A(derived.tasks.filter((task) => task.bee).every((task) => derived.bees.some((bee) => bee.id === task.bee && bee.task === task.key)), 'a running card names its bee and the bee names it back')
EQ(derived.tasks.find((task) => task.number === 7400).verdict, 'accept', 'a verdict the board carried is kept')

// ---- 4. the filter, and its address -------------------------------------------
const pool = [...feed.tasks, ...derived.tasks]
const filters = [
  { kinds: [], states: [], repos: [], q: '' },
  { kinds: ['issue'], states: [], repos: [], q: '' },
  { kinds: ['review', 'job'], states: ['failed', 'backlog'], repos: [], q: '' },
  { kinds: [], states: ['running'], repos: ['GHASHTAG/T27'], q: '' },
  { kinds: [], states: [], repos: ['gHashTag/trinity'], q: 'review' },
  { kinds: [], states: [], repos: [], q: '#7513' },
  { kinds: ['job'], states: ['done'], repos: ['nobody/none'], q: 'x' },
]
for (const filter of filters) {
  const kept = filterTasks(pool, filter)
  A(kept.every((task) => pool.includes(task)), `a filter only hides: ${JSON.stringify(filter)}`)
  A(kept.every((task, i) => i === 0 || pool.indexOf(kept[i - 1]) < pool.indexOf(task)), 'and keeps the order things arrived in')
  const back = taskFilterFromParams(writeTaskFilter(new URLSearchParams('tab=kanban&world=ghashtag/t27'), filter))
  EQ(filterTasks(pool, back), kept, `the address round-trips: ${JSON.stringify(filter)}`)
}
EQ(filterTasks(pool, filters[0]).length, pool.length, 'the empty filter is every task')
EQ(filterTasks(pool, filters[3]).every((task) => task.repo === 'gHashTag/t27' && task.state === 'running'), true, 'a repository is matched without regard to case')
EQ(filterTasks(pool, filters[5]).map((task) => task.number), [7513], '#7513 finds the issue numbered 7513 and no other')
EQ(filterTasks(pool, { ...filters[0], q: '75' }).some((task) => task.number === 7513), false, 'digits are not a number unless they are the whole number')
const written = writeTaskFilter(new URLSearchParams('tab=kanban&world=ghashtag/t27&task=7&q=old'), { kinds: ['job', 'issue'], states: ['failed'], repos: ['gHashTag/t27'], q: ' port ' })
EQ(written.toString(), 'tab=kanban&world=ghashtag%2Ft27&task=7&q=port&kinds=issue%2Cjob&states=failed&repos=gHashTag%2Ft27', 'the other keys are kept; lists are in the spec order; text is trimmed')
const cleared = writeTaskFilter(new URLSearchParams(written), { kinds: [], states: [], repos: [], q: '' })
EQ(cleared.toString(), 'tab=kanban&world=ghashtag%2Ft27&task=7', 'an empty filter leaves no key behind')
EQ(taskFilterFromParams(new URLSearchParams('kinds=issue,epic,issue&states=open,done&repos=a/b,../x,c/d&q=' + 'x'.repeat(300))), {
  kinds: ['issue'], states: ['done'], repos: ['a/b', 'c/d'], q: 'x'.repeat(200),
}, 'an address is read, not trusted: unknown names and malformed repositories are dropped, text is capped')
A(taskFilterIsEmpty(taskFilterFromParams(new URLSearchParams('tab=kanban&repo=a/b&task=3'))), 'the universe\'s own repo= and task= are not the board\'s filter')
EQ(taskFilterKey({ kinds: ['job', 'issue'], states: [], repos: [], q: '' }), taskFilterKey({ kinds: ['issue', 'job'], states: [], repos: [], q: '' }), 'one filter, one key, whatever order it was picked in')

// ---- words -------------------------------------------------------------------
EQ(beeLabel({ number: 7513, state: 'working', since: iso(12 * 60 + 5) }, now, 'en'), '#7513 · working · 12 min', 'the game\'s label over a bee')
EQ(beeLabel({ number: 7513, state: 'quiet', since: null }, now, 'en'), '#7513 · quiet', 'no moment, no duration')
EQ(beeLabel({ number: null, state: 'queued', since: iso(30) }, now, 'ru'), 'в очереди · 30 с', 'a bee with no issue number is still named by its state')
EQ(beeBadge({ ...derived.bees[0], lane: 3 }, now, 'en'), 'working · 10 min · heard 1 min · lane 3', 'the board\'s badge: state, how long, last heard, lane')
EQ(beeBadge(derived.bees[2], now, 'en'), 'quiet · 0 s · not heard yet', 'a bee nobody has heard says so')

// ---- 5. the game ---------------------------------------------------------------
const atlas = JSON.parse(readFileSync(new URL('../public/t27/universe-atlas.json', import.meta.url), 'utf8'))
const world = atlas.worlds.find((w) => w.repo === 'ghashtag/t27')
A(world && world.specCount > 0, 'the atlas spells the board\'s repository in lower case')
const inAtlas = atlas.issues.find((issue) => issue.repo === 'ghashtag/t27')
const liveFeed = {
  at: iso(0), source: 'tasks', truncated: false,
  tasks: [
    { key: 'gHashTag/t27#999001', kind: 'issue', repo: 'gHashTag/t27', number: 999001, title: 'beyond the atlas', state: 'running', criteria: 6, needs: [], verdict: null, url: null, bee: 'b1', updatedAt: null },
    { key: `gHashTag/t27#${inAtlas.number}`, kind: 'issue', repo: 'gHashTag/t27', number: inAtlas.number, title: inAtlas.title, state: 'running', criteria: 6, needs: [], verdict: null, url: null, bee: 'b2', updatedAt: null },
    { key: 'gHashTag/t27#999002', kind: 'issue', repo: 'gHashTag/t27', number: 999002, title: 'in review, with a bee', state: 'review', criteria: 6, needs: [], verdict: null, url: null, bee: 'b3', updatedAt: null },
    { key: 'gHashTag/t27#999003', kind: 'issue', repo: 'gHashTag/t27', number: 999003, title: 'backlog, no bee', state: 'backlog', criteria: 0, needs: [], verdict: null, url: null, bee: null, updatedAt: null },
    { key: 'someone/elsewhere#4', kind: 'issue', repo: 'someone/elsewhere', number: 4, title: 'not a world on this map', state: 'running', criteria: 6, needs: [], verdict: null, url: null, bee: 'b4', updatedAt: null },
    { key: 'gHashTag/t27#999004@abc', kind: 'review', repo: 'gHashTag/t27', number: 999004, title: 'review of abc', state: 'running', criteria: null, needs: [], verdict: null, url: null, bee: null, updatedAt: null },
  ],
  bees: [
    { id: 'b1', lane: 1, kind: 'runner', task: 'gHashTag/t27#999001', repo: 'gHashTag/t27', number: 999001, state: 'working', since: iso(60), lastEventAt: iso(5) },
    { id: 'b2', lane: 2, kind: 'runner', task: `gHashTag/t27#${inAtlas.number}`, repo: 'gHashTag/t27', number: inAtlas.number, state: 'quiet', since: iso(900), lastEventAt: iso(400) },
    { id: 'b3', lane: null, kind: 'worker', task: 'gHashTag/t27#999002', repo: 'gHashTag/t27', number: 999002, state: 'queued', since: iso(10), lastEventAt: null },
    { id: 'b4', lane: 4, kind: 'runner', task: 'someone/elsewhere#4', repo: 'someone/elsewhere', number: 4, state: 'working', since: iso(10), lastEventAt: iso(1) },
  ],
}
const rows = liveIssueRows(atlas, liveFeed, {})
EQ(rows.map((row) => [row.key, row.state]), [['ghashtag/t27#999001', 'open']],
  'a running issue beyond the atlas becomes one row, in the atlas\'s spelling and its word `open`; one the atlas holds, one only a queued bee is on, a backlog issue, a review and a repository with no world do not')
const claimedFeed = { ...liveFeed, bees: liveFeed.bees.map((bee) => (bee.id === 'b3' ? { ...bee, state: 'quiet' } : bee)) }
EQ(liveIssueRows(atlas, claimedFeed, {}).map((row) => row.key), ['ghashtag/t27#999001', 'ghashtag/t27#999002'], 'an issue a bee has claimed gets a cell whatever its column')
EQ(liveIssueRows(atlas, liveFeed, { 'ghashtag/t27#999001': { key: 'ghashtag/t27#999001' } }), [], 'a row GitHub was already read for is not overwritten')
EQ(liveIssueRows(atlas, null, {}), [], 'no feed, no live rows')
const before = catalogUniverse(atlas, [], [])
const after = catalogUniverse(atlas, liveIssueRows(atlas, claimedFeed, {}), [])
const cell = (map, key) => map.displays.findIndex((row) => row?.key === key)
A(cell(before, 'ghashtag/t27#999001') < 0 && cell(after, 'ghashtag/t27#999001') >= 0, 'an issue beyond the atlas gets a cell')
EQ(after.displays.filter(Boolean).length, before.displays.filter(Boolean).length + 2, 'two new cells, nothing else moves in or out')
EQ(after.displays[cell(after, `ghashtag/t27#${inAtlas.number}`)].state, 'open', 'a running issue the atlas holds keeps its cell and its paint: the bee says it is worked')
// Indices of later repositories shift by the cells appended before them; positions do not.
const placeOf = (map, key) => map.map.positions[cell(map, key)]
A(before.displays.every((row) => !row || JSON.stringify(placeOf(before, row.key)) === JSON.stringify(placeOf(after, row.key))), 'every cell the atlas placed keeps its place on the map')
A(after.displays.every((row) => !row || ['open', 'closed', 'dropped'].includes(row.state)), 'no live cell is painted with a live state, so no bee ever repaints the map')

const glb = readFileSync(new URL('../public/queen/models/craft_speederA.glb', import.meta.url))
const ship = readShipGlb(glb.buffer.slice(glb.byteOffset, glb.byteOffset + glb.byteLength))
EQ(ship.parts, 4, 'the ship is the kit\'s four parts')
A(ship.indices.length % 3 === 0 && ship.indices.length > 300, 'the ship is triangles')
A(ship.indices.every((i) => i < ship.positions.length / 3), 'every index names a vertex')
EQ([ship.positions.length, ship.normals.length, ship.colors.length / 4 * 3], [ship.positions.length, ship.positions.length, ship.positions.length], 'one normal and one colour per vertex')
A(Math.abs(ship.size.x - 2) < 0.01 && Math.abs(ship.size.y - 0.8) < 0.01 && Math.abs(ship.size.z - 2.1) < 0.01, `the ship's extent is the kit's 2 x 0.8 x 2.1 (${JSON.stringify(ship.size)})`)
const centre = [0, 1, 2].map((k) => { let lo = Infinity, hi = -Infinity; for (let i = k; i < ship.positions.length; i += 3) { lo = Math.min(lo, ship.positions[i]); hi = Math.max(hi, ship.positions[i]) } return (lo + hi) / 2 })
A(centre.every((v) => Math.abs(v) < 1e-5), 'the ship is centred on itself, so it turns about its middle')
// The scene turns a ship to face where it flies, assuming its nose is +z: the narrow end.
const halfWidth = (test) => { let w = 0; for (let i = 0; i < ship.positions.length; i += 3) if (test(ship.positions[i + 2])) w = Math.max(w, Math.abs(ship.positions[i])); return w }
A(halfWidth((z) => z > 0.6) < 0.5 * halfWidth((z) => z < -0.3), 'the ship\'s nose is +z (narrow) and its wings are at -z, as the scene turns it')
EQ(new Set(Array.from({ length: ship.colors.length / 4 }, (_, i) => ship.colors.slice(i * 4, i * 4 + 3).join())).size, 4, 'four palette colours, one per part, in the vertices')
assert.throws(() => readShipGlb(new TextEncoder().encode('not a glb at all, not even close').buffer), /glTF 2 binary/, 'a file that is not a GLB is refused with its reason')
checks += 1
const [wr, wg, wb] = shipTint(3, false), [qr, qg, qb] = shipTint(3, true)
A(qr < wr && qg < wg && qb < wb, 'a quiet bee is drawn darker than a working one')
EQ(shipTint(-2, false), shipTint(4, false), 'a negative lane still has a hue, the same as its residue')
EQ(shipTint(null, false), [1, 1, 1, 1], 'a bee with no lane is untinted')

// ---- 6. no rebuild per bee -------------------------------------------------------
const comb = readFileSync(new URL('../src/components/QueenCombBabylon.tsx', import.meta.url), 'utf8')
const signature = comb.slice(comb.indexOf('const signature = JSON.stringify(['), comb.indexOf(']);', comb.indexOf('const signature = JSON.stringify([')))
A(/liveBees \? "live-bees"/.test(signature) && !/liveBees\.|liveBees\)/.test(signature), 'the signature carries the presence of live bees, never a bee')
A(/liveBeesRef\.current/.test(comb) && /flyShips\(nowMs, dt\)/.test(comb), 'the ships are moved every frame from a ref')
const hive = readFileSync(new URL('../src/components/QueenCatalogHive.tsx', import.meta.url), 'utf8')
A(/workers=\{null\} liveBees=\{liveBees\}/.test(hive), 'the catalog gives the scene live bees and no worker slots')

console.log(`Queen tasks contract: PASS (${checks} checks: spec vectors, wire, board fallback, filter + address, live cells, ship, no rebuild per bee)`)
