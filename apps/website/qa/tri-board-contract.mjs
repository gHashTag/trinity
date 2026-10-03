// WHO EARNED TRI: src/lib/triBoard.ts, lib/triTokenCopy.ts, QueenToken.tsx.
//
// Owner, 2026-10-03: the tokens are counted by the leaderboard. The TOKEN tab
// had ranked a third source (the earnings ledger: one lender, 377 acceptances)
// while the leaderboard showed four spec authors and 595 accepted lane specs.
// This contract holds the tab to the leaderboard's own units:
//   1  TRI = (spec commits + accepted lane specs) x the ledger's rate, one row
//      per GitHub account, the live figures of 2026-10-03 reproduced exactly
//   2  logins merge case-insensitively; an unclaimed lane, a lane without a
//      login, and an author that is not a login are credited to nobody
//   3  no valid rate (missing, zero, negative, fractional, NaN, Infinity) means
//      no TRI is printed anywhere, and the units still stand
//   4  the copy says where the count comes from, both roads, and the honest
//      status, in both languages; English has no Cyrillic
//   5  the component reads the leaderboard's two sources and the minter, ranks
//      with triBoard, and no longer ranks the ledger's earners
//
//   node --experimental-strip-types qa/tri-board-contract.mjs

import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { triBoard, validRate } from '../src/lib/triBoard.ts'
import { TOKEN_COPY } from '../src/lib/triTokenCopy.ts'

const read = (rel) => readFileSync(new URL(`../${rel}`, import.meta.url), 'utf8')
let checks = 0
const eq = (a, b, m) => { checks++; assert.deepEqual(a, b, m) }
const ok = (v, m) => { checks++; assert.ok(v, m) }

// 1  the live counts of 2026-10-03
const AUTHORS = [
  { login: 'gHashTag', commits: 3235 },
  { login: 'mxfill77', commits: 74 },
  { login: 'dmitrii-f-t27', commits: 36 },
  { login: 'Karim13014', commits: 1 },
]
const LANES = [
  { name: '@dmitrii-f-t27', claimed: true, github: 'dmitrii-f-t27', keys: [-2, 0, 1], specs: 595 },
  { name: 'key #24', claimed: false, keys: [24], specs: 0 },
]
const live = triBoard(AUTHORS, LANES, 27, 47)
eq(live.rows.map((r) => [r.login, r.specCommits, r.laneSpecs, r.tri]), [
  ['gHashTag', 3235, 0, 87345],
  ['dmitrii-f-t27', 36, 595, 17037],
  ['mxfill77', 74, 0, 1998],
  ['Karim13014', 1, 0, 27],
], 'the leaderboard ranked in TRI: both roads summed per account')
eq(live.nobody, { specCommits: 47, laneSpecs: 0, tri: 1269 }, 'unattributed commits are credited to nobody')
eq(live.total, (3235 + 74 + 36 + 1 + 595 + 47) * 27, 'the total is every unit, credited or not')

// 2  who is a row
const merged = triBoard([{ login: 'Dmitrii-F-T27', commits: 2 }], [{ name: 'x', claimed: true, github: 'dmitrii-f-t27', keys: [1], specs: 3 }], 27)
eq(merged.rows.map((r) => [r.specCommits, r.laneSpecs, r.tri]), [[2, 3, 135]], 'one login, one row, whatever the case')
const stray = triBoard(
  [{ login: 'Claude Code (agent)', commits: 5 }],
  [
    { name: 'key #7', claimed: false, github: 'someone', keys: [7], specs: 4 },
    { name: 'Bob', claimed: true, keys: [8], specs: 6 },
    { name: 'bad', claimed: true, github: '-bad-', keys: [9], specs: 1 },
  ],
  27,
)
eq(stray.rows, [], 'no GitHub account, no row')
eq(stray.nobody, { specCommits: 5, laneSpecs: 11, tri: 16 * 27 }, 'and every such unit is counted under the list')
eq(triBoard([{ login: 'a', commits: -4 }, { login: 'b', commits: Number.NaN }], [], 27).rows, [], 'negative or NaN units count as nothing')

// 3  no rate, no TRI
for (const bad of [undefined, null, 0, -27, 2.5, Number.NaN, Number.POSITIVE_INFINITY, '27']) {
  const b = triBoard(AUTHORS, LANES, bad, 47)
  ok(!validRate(bad), `rate ${String(bad)} is not a rate`)
  ok(b.rows.every((r) => r.tri === null) && b.nobody.tri === null && b.total === null, `rate ${String(bad)} prints no TRI`)
  eq(b.rows.map((r) => r.specCommits + r.laneSpecs), [3235, 631, 74, 1], `rate ${String(bad)}: the units still stand`)
}

// 4  the words
for (const lang of ['en', 'ru']) {
  const c = TOKEN_COPY[lang]
  const lead = c.boardLead(27)
  ok(lead.includes('27 TRI'), `${lang}: the lead quotes the rate it was given`)
  ok(/leaderboard|лидерборд/.test(lead), `${lang}: the lead says the count is the leaderboard's`)
  ok(/GitHub/.test(lead) && /proof of compute/.test(lead), `${lang}: both roads, the author's login and proof of compute`)
  ok(/NOT trustless|НЕ trustless/.test(c.status) && /testnet/i.test(c.status), `${lang}: testnet only, not trustless`)
  ok(c.total('1', '2').includes('2 TRI'), `${lang}: the total sits next to what the chain minted`)
}
ok(!/[Ѐ-ӿ]/.test(JSON.stringify(Object.values(TOKEN_COPY.en).map((v) => (typeof v === 'function' ? v(1, 2, 3) : v)))), 'English copy has no Cyrillic')

// 5  the component
const tab = read('src/components/QueenToken.tsx')
ok(tab.includes("'roadmap/spec-authors.json'") && tab.includes('/queen/public-leaderboard'), 'the tab reads the leaderboard’s two sources')
ok(/triBoard\(/.test(tab), 'the tab ranks with triBoard')
ok(!/rankByGithub|\.earners\b/.test(tab), 'the ledger’s earners no longer rank anybody')
ok(/readMinterState\(/.test(tab), 'the tab still reads the minter')
ok(!/\b27\b/.test(tab), 'no rate typed in by hand')

console.log(`tri-board contract: ${checks} checks OK`)
